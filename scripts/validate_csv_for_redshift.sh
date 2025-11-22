#!/bin/bash
# =============================================================================
# CSV Data Validation Script for Redshift
# Validates CSV files before uploading to S3 and loading to Redshift
# =============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CSV_DIR="${1:-csv_output_20251121_085849}"
SCHEMA_FILE="../sql/redshift_schema.sql"

echo "=========================================="
echo "CSV DATA VALIDATION FOR REDSHIFT"
echo "=========================================="
echo "Directory: $CSV_DIR"
echo ""

# Counter for issues
TOTAL_ISSUES=0

# =============================================================================
# 1. Check Line Endings
# =============================================================================
echo "1️⃣  Checking line endings (must be Unix \\n)..."
for file in "$CSV_DIR"/*.csv; do
    if [ ! -f "$file" ]; then
        continue
    fi
    
    filename=$(basename "$file")
    
    # Check for Windows line endings
    if od -c "$file" | grep -q '\\r'; then
        echo -e "${RED}❌ $filename has Windows line endings (\\r\\n)${NC}"
        TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
    else
        echo -e "${GREEN}✅ $filename${NC}"
    fi
done
echo ""

# =============================================================================
# 2. Check Column Counts
# =============================================================================
echo "2️⃣  Checking column counts (must be consistent)..."

check_columns() {
    local file=$1
    local expected=$2
    local filename=$(basename "$file")
    
    if [ ! -f "$file" ]; then
        return
    fi
    
    # Check header column count
    header_count=$(head -1 "$file" | awk -F'|' '{print NF}')
    
    if [ "$header_count" -ne "$expected" ]; then
        echo -e "${RED}❌ $filename: Expected $expected columns, found $header_count${NC}"
        TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
    else
        # Check first data row
        data_count=$(sed -n '2p' "$file" | awk -F'|' '{print NF}')
        if [ "$data_count" -ne "$expected" ]; then
            echo -e "${RED}❌ $filename: Data row has $data_count columns (expected $expected)${NC}"
            TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
        else
            echo -e "${GREEN}✅ $filename ($expected columns)${NC}"
        fi
    fi
}

check_columns "$CSV_DIR/users.csv" 8
check_columns "$CSV_DIR/consumers.csv" 7
check_columns "$CSV_DIR/sellers.csv" 10
check_columns "$CSV_DIR/verticals.csv" 4
check_columns "$CSV_DIR/seller_vertical.csv" 4
check_columns "$CSV_DIR/address_books.csv" 15
check_columns "$CSV_DIR/commodities.csv" 22
check_columns "$CSV_DIR/cards.csv" 12
check_columns "$CSV_DIR/orders.csv" 26
check_columns "$CSV_DIR/order_commodities.csv" 7
check_columns "$CSV_DIR/transactions.csv" 15
check_columns "$CSV_DIR/reviews.csv" 13

echo ""

# =============================================================================
# 3. Check Numeric Precision (4 decimals for monetary fields)
# =============================================================================
echo "3️⃣  Checking numeric precision for monetary fields..."

# Check sellers.total_sales (column 9)
file="$CSV_DIR/sellers.csv"
if [ -f "$file" ]; then
    four_decimal_count=$(awk -F'|' 'NR>1 {split($9, a, "."); if (length(a[2]) == 4) count++} END {print count+0}' "$file")
    total_rows=$(($(wc -l < "$file") - 1))
    
    if [ "$four_decimal_count" -eq "$total_rows" ]; then
        echo -e "${GREEN}✅ sellers.total_sales: All $total_rows rows have 4 decimals${NC}"
    else
        echo -e "${RED}❌ sellers.total_sales: Only $four_decimal_count/$total_rows have 4 decimals${NC}"
        TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
    fi
fi

# Check consumers.total_spent (column 6) - accepts 2-4 decimals
file="$CSV_DIR/consumers.csv"
if [ -f "$file" ]; then
    valid_decimal_count=$(awk -F'|' 'NR>1 {split($6, a, "."); decimals=length(a[2]); if (decimals >= 2 && decimals <= 4) count++} END {print count+0}' "$file")
    total_rows=$(($(wc -l < "$file") - 1))
    
    if [ "$valid_decimal_count" -eq "$total_rows" ]; then
        echo -e "${GREEN}✅ consumers.total_spent: All $total_rows rows have 2-4 decimals${NC}"
    else
        echo -e "${RED}❌ consumers.total_spent: Only $valid_decimal_count/$total_rows have valid decimals (2-4)${NC}"
        TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
    fi
fi
echo ""

# =============================================================================
# 4. Check VARCHAR Length Constraints
# =============================================================================
echo "4️⃣  Checking VARCHAR length constraints..."

# Check country fields (max 60 chars)
for file in "$CSV_DIR/sellers.csv" "$CSV_DIR/address_books.csv"; do
    if [ ! -f "$file" ]; then
        continue
    fi
    
    filename=$(basename "$file")
    
    if [ "$filename" == "sellers.csv" ]; then
        col=7  # country column
    else
        col=7  # country column in address_books
    fi
    
    max_length=$(awk -F'|' -v col=$col 'NR>1 {if (length($col) > max) max=length($col)} END {print max+0}' "$file")
    
    if [ "$max_length" -gt 60 ]; then
        echo -e "${RED}❌ $filename country: Max length $max_length exceeds VARCHAR(60)${NC}"
        TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
    else
        echo -e "${GREEN}✅ $filename country: Max length $max_length (within VARCHAR(60))${NC}"
    fi
done
echo ""

# =============================================================================
# 5. Check for NULL/Empty Required Fields
# =============================================================================
echo "5️⃣  Checking for empty required fields..."

# Check sellers.id (column 1) and type (column 2)
file="$CSV_DIR/sellers.csv"
if [ -f "$file" ]; then
    empty_ids=$(awk -F'|' 'NR>1 && ($1 == "" || length($1) == 0) {count++} END {print count+0}' "$file")
    empty_types=$(awk -F'|' 'NR>1 && ($2 == "" || length($2) == 0) {count++} END {print count+0}' "$file")
    
    if [ "$empty_ids" -eq 0 ]; then
        echo -e "${GREEN}✅ sellers.id: No empty values${NC}"
    else
        echo -e "${RED}❌ sellers.id: Found $empty_ids empty values${NC}"
        TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
    fi
    
    if [ "$empty_types" -eq 0 ]; then
        echo -e "${GREEN}✅ sellers.type: No empty values${NC}"
    else
        echo -e "${RED}❌ sellers.type: Found $empty_types empty values${NC}"
        TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
    fi
fi
echo ""

# =============================================================================
# 6. Check UUID Format
# =============================================================================
echo "6️⃣  Checking UUID format (must be 36 chars)..."

for file in "$CSV_DIR"/*.csv; do
    if [ ! -f "$file" ]; then
        continue
    fi
    
    filename=$(basename "$file")
    
    # Check first column (usually ID)
    invalid_uuids=$(awk -F'|' 'NR>1 && $1 !~ /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/ {count++} END {print count+0}' "$file")
    
    if [ "$invalid_uuids" -eq 0 ]; then
        echo -e "${GREEN}✅ $filename: All UUIDs valid${NC}"
    else
        echo -e "${RED}❌ $filename: Found $invalid_uuids invalid UUIDs${NC}"
        TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
    fi
done
echo ""

# =============================================================================
# 7. Check File Sizes
# =============================================================================
echo "7️⃣  Checking file sizes..."

for file in "$CSV_DIR"/*.csv; do
    if [ ! -f "$file" ]; then
        continue
    fi
    
    filename=$(basename "$file")
    size=$(du -h "$file" | cut -f1)
    rows=$(($(wc -l < "$file") - 1))
    
    echo "📊 $filename: $size ($rows rows)"
done
echo ""

# =============================================================================
# Summary
# =============================================================================
echo "=========================================="
if [ "$TOTAL_ISSUES" -eq 0 ]; then
    echo -e "${GREEN}✅ ALL VALIDATIONS PASSED${NC}"
    echo "CSV files are ready for Redshift COPY"
    exit 0
else
    echo -e "${RED}❌ FOUND $TOTAL_ISSUES ISSUES${NC}"
    echo "Please fix the issues before loading to Redshift"
    exit 1
fi

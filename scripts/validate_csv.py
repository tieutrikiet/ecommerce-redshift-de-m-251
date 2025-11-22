#!/usr/bin/env python3
"""
CSV Data Validation Script
Validates the generated CSV files before loading to Redshift
"""

import os
import csv
import sys
from collections import defaultdict
from pathlib import Path

def validate_csv_file(filepath, required_fields, table_name):
    """Validate a single CSV file"""
    print(f"\n📋 Validating {table_name}...")
    
    if not os.path.exists(filepath):
        print(f"❌ File not found: {filepath}")
        return False
    
    errors = []
    warnings = []
    row_count = 0
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f, delimiter='|')
            
            # Check headers
            if set(reader.fieldnames) != set(required_fields):
                missing = set(required_fields) - set(reader.fieldnames)
                extra = set(reader.fieldnames) - set(required_fields)
                if missing:
                    errors.append(f"Missing fields: {missing}")
                if extra:
                    warnings.append(f"Extra fields: {extra}")
            
            # Validate rows
            for i, row in enumerate(reader, start=1):
                row_count = i
                
                # Check for required fields
                for field in required_fields:
                    if field not in row or row[field] == '':
                        # Allow empty values for certain fields
                        if field not in ['parent_id', 'level', 'description', 'rating_avg', 
                                       'address_line_2', 'technical_info', 'guarantee_info',
                                       'manufacturer_name', 'confirmed_at', 'paid_at',
                                       'shipped_at', 'delivered_at', 'completed_at',
                                       'days_to_ship', 'days_to_deliver', 'authorized_at',
                                       'completed_at', 'comment', 'introduction', 'first_order_date']:
                            errors.append(f"Row {i}: Empty required field '{field}'")
                
                # Check for pipe characters in data (would break delimiter)
                for field, value in row.items():
                    if value and '|' in value:
                        errors.append(f"Row {i}: Pipe character found in {field}")
                
                # Stop after 100 errors to avoid spam
                if len(errors) >= 100:
                    errors.append("... (more than 100 errors, stopping validation)")
                    break
        
        # Summary
        print(f"   Rows: {row_count:,}")
        
        if errors:
            print(f"   ❌ {len(errors)} errors found:")
            for error in errors[:10]:  # Show first 10 errors
                print(f"      • {error}")
            if len(errors) > 10:
                print(f"      ... and {len(errors) - 10} more errors")
            return False
        
        if warnings:
            print(f"   ⚠️  {len(warnings)} warnings:")
            for warning in warnings:
                print(f"      • {warning}")
        
        print(f"   ✅ Valid")
        return True
    
    except Exception as e:
        print(f"   ❌ Error reading file: {e}")
        return False

def validate_referential_integrity(output_dir):
    """Validate foreign key relationships"""
    print("\n🔗 Validating referential integrity...")
    
    errors = []
    
    try:
        # Load all IDs
        ids = defaultdict(set)
        
        # Users
        with open(f"{output_dir}/users.csv", 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f, delimiter='|')
            for row in reader:
                ids['users'].add(row['id'])
        
        # Verticals
        with open(f"{output_dir}/verticals.csv", 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f, delimiter='|')
            for row in reader:
                ids['verticals'].add(row['id'])
        
        # Sellers
        with open(f"{output_dir}/sellers.csv", 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f, delimiter='|')
            for row in reader:
                ids['sellers'].add(row['id'])
        
        # Consumers
        with open(f"{output_dir}/consumers.csv", 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f, delimiter='|')
            for row in reader:
                ids['consumers'].add(row['id'])
        
        # Commodities
        with open(f"{output_dir}/commodities.csv", 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f, delimiter='|')
            for row in reader:
                ids['commodities'].add(row['id'])
        
        # Orders
        with open(f"{output_dir}/orders.csv", 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f, delimiter='|')
            for row in reader:
                ids['orders'].add(row['id'])
        
        # Cards
        with open(f"{output_dir}/cards.csv", 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f, delimiter='|')
            for row in reader:
                ids['cards'].add(row['id'])
        
        # Validate seller_vertical references
        print("   Checking seller_vertical...")
        with open(f"{output_dir}/seller_vertical.csv", 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f, delimiter='|')
            for i, row in enumerate(reader, start=1):
                if row['seller_id'] not in ids['sellers']:
                    errors.append(f"seller_vertical row {i}: Invalid seller_id {row['seller_id']}")
                if row['vertical_id'] not in ids['verticals']:
                    errors.append(f"seller_vertical row {i}: Invalid vertical_id {row['vertical_id']}")
        
        # Validate commodities references
        print("   Checking commodities...")
        with open(f"{output_dir}/commodities.csv", 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f, delimiter='|')
            for i, row in enumerate(reader, start=1):
                if row['seller_id'] not in ids['sellers']:
                    errors.append(f"commodities row {i}: Invalid seller_id {row['seller_id']}")
                if row['vertical_id'] not in ids['verticals']:
                    errors.append(f"commodities row {i}: Invalid vertical_id {row['vertical_id']}")
        
        # Validate orders references
        print("   Checking orders...")
        with open(f"{output_dir}/orders.csv", 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f, delimiter='|')
            for i, row in enumerate(reader, start=1):
                if row['consumer_id'] not in ids['consumers']:
                    errors.append(f"orders row {i}: Invalid consumer_id {row['consumer_id']}")
                if row['seller_id'] not in ids['sellers']:
                    errors.append(f"orders row {i}: Invalid seller_id {row['seller_id']}")
        
        # Validate order_commodities references
        print("   Checking order_commodities...")
        with open(f"{output_dir}/order_commodities.csv", 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f, delimiter='|')
            for i, row in enumerate(reader, start=1):
                if row['order_id'] not in ids['orders']:
                    errors.append(f"order_commodities row {i}: Invalid order_id")
                if row['commodity_id'] not in ids['commodities']:
                    errors.append(f"order_commodities row {i}: Invalid commodity_id")
        
        # Validate transactions references
        print("   Checking transactions...")
        with open(f"{output_dir}/transactions.csv", 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f, delimiter='|')
            for i, row in enumerate(reader, start=1):
                if row['order_id'] not in ids['orders']:
                    errors.append(f"transactions row {i}: Invalid order_id")
                if row['card_id'] not in ids['cards']:
                    errors.append(f"transactions row {i}: Invalid card_id")
        
        if errors:
            print(f"   ❌ {len(errors)} referential integrity errors:")
            for error in errors[:10]:
                print(f"      • {error}")
            if len(errors) > 10:
                print(f"      ... and {len(errors) - 10} more errors")
            return False
        
        print("   ✅ All references valid")
        return True
    
    except Exception as e:
        print(f"   ❌ Error: {e}")
        return False

def main():
    """Main validation"""
    print("=" * 60)
    print("🔍 CSV DATA VALIDATION")
    print("=" * 60)
    
    # Find latest output directory
    script_dir = Path(__file__).parent
    output_dirs = sorted([d for d in script_dir.glob("csv_output_*") if d.is_dir()])
    
    if not output_dirs:
        print("❌ No CSV output directories found")
        sys.exit(1)
    
    output_dir = output_dirs[-1]
    print(f"Validating: {output_dir.name}")
    
    # Define schema
    schemas = {
        'users.csv': ['id', 'username', 'phone', 'name', 'email', 'status', 'created_at', 'updated_at'],
        'consumers.csv': ['id', 'birthday', 'gender', 'first_order_date', 'total_orders', 'total_spent', 'customer_segment'],
        'sellers.csv': ['id', 'type', 'introduction', 'address', 'city', 'province', 'country', 'rating_avg', 'total_sales', 'total_orders'],
        'verticals.csv': ['id', 'name', 'description', 'status'],
        'seller_vertical.csv': ['seller_id', 'vertical_id', 'created_at', 'updated_at'],
        'address_books.csv': ['id', 'user_id', 'address_line_1', 'address_line_2', 'city', 'province', 'country', 'postal_code', 'phone', 'receiver_name', 'is_default', 'latitude', 'longitude', 'created_at', 'updated_at'],
        'commodities.csv': ['id', 'seller_id', 'sku', 'name', 'price', 'cost_price', 'quantity', 'reserved_quantity', 'reorder_level', 'reorder_quantity', 'weight_kg', 'description', 'technical_info', 'guarantee_info', 'manufacturer_name', 'vertical_id', 'status', 'rating_avg', 'review_count', 'total_sold', 'created_at', 'updated_at'],
        'cards.csv': ['id', 'consumer_id', 'tk', 'provider', 'last4', 'card_holder', 'exp_year', 'exp_month', 'status', 'is_default', 'created_at', 'updated_at'],
        'orders.csv': ['id', 'consumer_id', 'seller_id', 'status', 'delivery_address', 'delivery_postal_code', 'delivery_receiver', 'delivery_phone', 'delivery_city', 'delivery_country', 'delivery_latitude', 'delivery_longitude', 'subtotal_amount', 'tax_amount', 'shipping_fee', 'discount_amount', 'total_amount', 'created_at', 'confirmed_at', 'paid_at', 'shipped_at', 'delivered_at', 'completed_at', 'updated_at', 'days_to_ship', 'days_to_deliver'],
        'order_commodities.csv': ['order_id', 'commodity_id', 'quantity', 'unit_price', 'unit_cost', 'line_total', 'discount_applied'],
        'transactions.csv': ['id', 'order_id', 'card_id', 'payment_method', 'transaction_type', 'amount', 'status', 'created_at', 'authorized_at', 'completed_at', 'gateway_transaction_id', 'gateway_response_code', 'gateway_response_message', 'ip_address', 'user_agent'],
        'reviews.csv': ['id', 'order_id', 'commodity_id', 'consumer_id', 'seller_id', 'rate', 'comment', 'status', 'is_verified_purchase', 'helpful_count', 'created_at', 'updated_at', 'published_at'],
    }
    
    # Validate each file
    all_valid = True
    for filename, fields in schemas.items():
        filepath = output_dir / filename
        table_name = filename.replace('.csv', '')
        if not validate_csv_file(filepath, fields, table_name):
            all_valid = False
    
    # Validate referential integrity
    if not validate_referential_integrity(output_dir):
        all_valid = False
    
    # Summary
    print("\n" + "=" * 60)
    if all_valid:
        print("✅ ALL VALIDATIONS PASSED")
        print("=" * 60)
        print(f"📁 CSV files in: {output_dir}")
        print("🚀 Ready to load to Redshift!")
        sys.exit(0)
    else:
        print("❌ VALIDATION FAILED")
        print("=" * 60)
        print("Please fix the errors and regenerate data")
        sys.exit(1)

if __name__ == '__main__':
    main()

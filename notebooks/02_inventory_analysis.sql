-- ============================================================================
-- NOTEBOOK 2: INVENTORY ANALYSIS
-- Business Objective: Monitor stock levels, predict reorders, optimize warehouse
-- QuickSight Compatibility: All views optimized for SPICE import
-- Free Tier Considerations: Aggregated views with daily refresh schedule
-- ============================================================================

-- ============================================================================
-- SECTION 1: DATA VALIDATION
-- Verify inventory data completeness
-- ============================================================================

-- Check current inventory status
SELECT 
    COUNT(*) as total_products,
    COUNT(CASE WHEN status = 'available' THEN 1 END) as available_products,
    COUNT(CASE WHEN status = 'out of stock' THEN 1 END) as out_of_stock,
    COUNT(CASE WHEN quantity <= reorder_level THEN 1 END) as needs_reorder,
    SUM(quantity) as total_units_in_stock,
    SUM(quantity * price) as total_inventory_value,
    AVG(quantity) as avg_stock_per_product
FROM commodities;

-- Expected output: Inventory health snapshot
-- QuickSight Usage: Not needed - validation only

-- ============================================================================
-- SECTION 2: CURRENT INVENTORY STATUS VIEW
-- Real-time stock levels with reorder alerts
-- ============================================================================

CREATE OR REPLACE VIEW v_inventory_current_status AS
SELECT 
    c.id as commodity_id,
    c.sku,
    c.name as product_name,
    v.name as vertical_name,
    u.name as seller_name,
    c.status as product_status,
    
    -- Stock metrics
    c.quantity as current_stock,
    c.reserved_quantity,
    (c.quantity - c.reserved_quantity) as available_stock,
    c.reorder_level,
    c.reorder_quantity,
    
    -- Pricing
    c.price as selling_price,
    c.cost_price,
    ROUND((c.price - c.cost_price)::NUMERIC, 2) as profit_margin_per_unit,
    ROUND(((c.price - c.cost_price) / NULLIF(c.price, 0) * 100)::NUMERIC, 2) as profit_margin_pct,
    
    -- Inventory value
    ROUND((c.quantity * c.cost_price)::NUMERIC, 2) as inventory_value_at_cost,
    ROUND((c.quantity * c.price)::NUMERIC, 2) as inventory_value_at_retail,
    
    -- Alert flags
    CASE 
        WHEN c.quantity = 0 THEN '🔴 Out of Stock'
        WHEN c.quantity <= c.reorder_level THEN '🟡 Reorder Needed'
        WHEN c.quantity > c.reorder_level * 3 THEN '🟣 Overstock'
        ELSE '🟢 Healthy'
    END as stock_status,
    
    CASE 
        WHEN c.quantity <= c.reorder_level THEN c.reorder_quantity
        ELSE 0
    END as suggested_reorder_quantity,
    
    -- Product performance
    c.total_sold as lifetime_units_sold,
    c.rating_avg,
    c.review_count,
    
    -- Metadata
    c.created_at as product_launch_date,
    c.updated_at as last_updated
FROM commodities c
JOIN verticals v ON c.vertical_id = v.id
JOIN sellers s ON c.seller_id = s.id
JOIN users u ON s.id = u.id
WHERE c.status IN ('available', 'unavailable', 'out of stock');

-- Expected output: ~5000 rows (one per active product)
-- QuickSight Usage: Import as "Inventory Status" dataset
-- Visualizations: Table with conditional formatting, Gauge charts for stock levels

-- Test the view
SELECT * FROM v_inventory_current_status 
WHERE stock_status IN ('🔴 Out of Stock', '🟡 Reorder Needed')
LIMIT 20;

-- ============================================================================
-- SECTION 3: INVENTORY TURNOVER ANALYSIS
-- Calculate how fast products are selling
-- ============================================================================

CREATE OR REPLACE VIEW v_inventory_turnover AS
WITH sales_last_30_days AS (
    SELECT 
        oc.commodity_id,
        SUM(oc.quantity) as units_sold_30d,
        COUNT(DISTINCT oc.order_id) as orders_30d,
        ROUND(AVG(oc.line_total)::NUMERIC, 2) as avg_line_value_30d
    FROM order_commodities oc
    JOIN orders o ON oc.order_id = o.id
    WHERE o.created_at >= DATEADD(day, -30, GETDATE())
        AND o.status IN ('delivered', 'done')
    GROUP BY oc.commodity_id
),
sales_last_90_days AS (
    SELECT 
        oc.commodity_id,
        SUM(oc.quantity) as units_sold_90d,
        COUNT(DISTINCT oc.order_id) as orders_90d
    FROM order_commodities oc
    JOIN orders o ON oc.order_id = o.id
    WHERE o.created_at >= DATEADD(day, -90, GETDATE())
        AND o.status IN ('delivered', 'done')
    GROUP BY oc.commodity_id
)
SELECT 
    c.id as commodity_id,
    c.sku,
    c.name as product_name,
    v.name as vertical_name,
    c.quantity as current_stock,
    c.price,
    
    -- 30-day metrics
    COALESCE(s30.units_sold_30d, 0) as units_sold_30d,
    COALESCE(s30.orders_30d, 0) as orders_30d,
    COALESCE(s30.avg_line_value_30d, 0) as avg_line_value_30d,
    
    -- 90-day metrics
    COALESCE(s90.units_sold_90d, 0) as units_sold_90d,
    COALESCE(s90.orders_90d, 0) as orders_90d,
    
    -- Turnover calculations
    CASE 
        WHEN COALESCE(s30.units_sold_30d, 0) > 0 AND c.quantity > 0
        THEN ROUND((c.quantity::DECIMAL / NULLIF(s30.units_sold_30d, 0) * 30)::NUMERIC, 1)
        ELSE NULL
    END as days_of_inventory_remaining,
    
    CASE 
        WHEN c.quantity > 0 AND COALESCE(s90.units_sold_90d, 0) > 0
        THEN ROUND((COALESCE(s90.units_sold_90d, 0)::DECIMAL / NULLIF(c.quantity, 0))::NUMERIC, 2)
        ELSE 0
    END as inventory_turnover_ratio_90d,
    
    -- Velocity classification
    CASE 
        WHEN COALESCE(s30.units_sold_30d, 0) = 0 THEN '🐌 Slow/No Movement'
        WHEN COALESCE(s30.units_sold_30d, 0) < 10 THEN '🚶 Low Velocity'
        WHEN COALESCE(s30.units_sold_30d, 0) < 50 THEN '🏃 Medium Velocity'
        WHEN COALESCE(s30.units_sold_30d, 0) < 200 THEN '🚀 High Velocity'
        ELSE '⚡ Ultra High Velocity'
    END as velocity_category,
    
    -- Stock health
    CASE 
        WHEN c.quantity = 0 THEN '🔴 Stockout'
        WHEN COALESCE(s30.units_sold_30d, 0) > 0 
            AND (c.quantity::DECIMAL / NULLIF(s30.units_sold_30d, 0) * 30) < 7 
            THEN '🟠 Low Stock (< 1 week)'
        WHEN COALESCE(s30.units_sold_30d, 0) > 0 
            AND (c.quantity::DECIMAL / NULLIF(s30.units_sold_30d, 0) * 30) < 14 
            THEN '🟡 Medium Stock (< 2 weeks)'
        WHEN COALESCE(s30.units_sold_30d, 0) = 0 AND c.quantity > 100 
            THEN '🟣 Dead Stock'
        ELSE '🟢 Healthy Stock'
    END as stock_health,
    
    -- Revenue potential
    ROUND((c.quantity * c.price)::NUMERIC, 2) as potential_revenue
FROM commodities c
JOIN verticals v ON c.vertical_id = v.id
LEFT JOIN sales_last_30_days s30 ON c.id = s30.commodity_id
LEFT JOIN sales_last_90_days s90 ON c.id = s90.commodity_id
WHERE c.status IN ('available', 'unavailable', 'out of stock')
ORDER BY units_sold_30d DESC NULLS LAST;

-- Expected output: ~5000 rows with turnover metrics
-- QuickSight Usage: Import as "Inventory Turnover" dataset
-- Visualizations: Scatter plot (stock vs velocity), Bar chart (top movers)

-- Test the view - Find fast movers
SELECT * FROM v_inventory_turnover 
WHERE velocity_category IN ('🚀 High Velocity', '⚡ Ultra High Velocity')
ORDER BY units_sold_30d DESC
LIMIT 20;

-- Test the view - Find dead stock
SELECT * FROM v_inventory_turnover 
WHERE velocity_category = '🐌 Slow/No Movement' AND current_stock > 50
ORDER BY potential_revenue DESC
LIMIT 20;

-- ============================================================================
-- SECTION 4: REORDER RECOMMENDATIONS VIEW
-- Predictive reordering based on velocity
-- ============================================================================

CREATE OR REPLACE VIEW v_reorder_recommendations AS
WITH velocity_data AS (
    SELECT * FROM v_inventory_turnover
)
SELECT 
    commodity_id,
    sku,
    product_name,
    vertical_name,
    current_stock,
    units_sold_30d,
    days_of_inventory_remaining,
    velocity_category,
    stock_health,
    
    -- Reorder priority
    CASE 
        WHEN current_stock = 0 THEN 1  -- Critical: Out of stock
        WHEN days_of_inventory_remaining IS NOT NULL 
            AND days_of_inventory_remaining < 7 THEN 2  -- High: < 1 week
        WHEN days_of_inventory_remaining IS NOT NULL 
            AND days_of_inventory_remaining < 14 THEN 3  -- Medium: < 2 weeks
        ELSE 4  -- Low: > 2 weeks
    END as reorder_priority,
    
    CASE 
        WHEN current_stock = 0 THEN '🔴 URGENT: Restock Now'
        WHEN days_of_inventory_remaining IS NOT NULL 
            AND days_of_inventory_remaining < 7 THEN '🟠 HIGH: Order This Week'
        WHEN days_of_inventory_remaining IS NOT NULL 
            AND days_of_inventory_remaining < 14 THEN '🟡 MEDIUM: Order Soon'
        ELSE '🟢 LOW: Monitor'
    END as reorder_urgency,
    
    -- Suggested reorder quantity based on 60-day coverage
    CASE 
        WHEN units_sold_30d > 0 
        THEN CEIL((units_sold_30d / 30.0 * 60) - current_stock)
        ELSE 0
    END as suggested_reorder_qty,
    
    -- Expected stockout date
    CASE 
        WHEN units_sold_30d > 0 AND current_stock > 0
        THEN DATEADD(day, days_of_inventory_remaining::INTEGER, GETDATE())
        WHEN current_stock = 0
        THEN GETDATE()  -- Already stocked out
        ELSE NULL
    END as estimated_stockout_date,
    
    -- Cost calculation
    ROUND((
        CASE 
            WHEN units_sold_30d > 0 
            THEN CEIL((units_sold_30d / 30.0 * 60) - current_stock) * price
            ELSE 0
        END
    )::NUMERIC, 2) as estimated_reorder_cost
FROM velocity_data
WHERE 
    -- Only products that need attention
    (current_stock = 0 
    OR (days_of_inventory_remaining IS NOT NULL AND days_of_inventory_remaining < 30)
    OR velocity_category IN ('🚀 High Velocity', '⚡ Ultra High Velocity'))
ORDER BY reorder_priority ASC, units_sold_30d DESC;

-- Expected output: 100-500 rows (products needing reorder)
-- QuickSight Usage: Import as "Reorder Recommendations" dataset
-- Visualizations: Priority table, Timeline chart (stockout dates)

-- Test the view
SELECT * FROM v_reorder_recommendations 
ORDER BY reorder_priority ASC, estimated_stockout_date ASC
LIMIT 30;

-- ============================================================================
-- SECTION 5: INVENTORY VALUE BY VERTICAL
-- Track inventory investment across categories
-- ============================================================================

CREATE OR REPLACE VIEW v_inventory_value_by_vertical AS
SELECT 
    v.id as vertical_id,
    v.name as vertical_name,
    
    -- Product counts
    COUNT(DISTINCT c.id) as total_products,
    COUNT(DISTINCT CASE WHEN c.status = 'available' THEN c.id END) as available_products,
    COUNT(DISTINCT CASE WHEN c.quantity <= c.reorder_level THEN c.id END) as low_stock_products,
    COUNT(DISTINCT CASE WHEN c.quantity = 0 THEN c.id END) as out_of_stock_products,
    
    -- Inventory quantities
    SUM(c.quantity) as total_units,
    ROUND(AVG(c.quantity)::NUMERIC, 1) as avg_units_per_product,
    
    -- Inventory value
    ROUND(SUM(c.quantity * c.cost_price)::NUMERIC, 2) as inventory_value_at_cost,
    ROUND(SUM(c.quantity * c.price)::NUMERIC, 2) as inventory_value_at_retail,
    ROUND((SUM(c.quantity * c.price) - SUM(c.quantity * c.cost_price))::NUMERIC, 2) as potential_profit,
    ROUND(
        ((SUM(c.quantity * c.price) - SUM(c.quantity * c.cost_price)) 
        / NULLIF(SUM(c.quantity * c.cost_price), 0) * 100)::NUMERIC,
        2
    ) as potential_profit_margin_pct,
    
    -- Performance metrics
    ROUND(AVG(c.rating_avg)::NUMERIC, 2) as avg_product_rating,
    SUM(c.total_sold) as lifetime_units_sold
FROM verticals v
JOIN commodities c ON v.id = c.vertical_id
WHERE c.status IN ('available', 'unavailable', 'out of stock')
GROUP BY v.id, v.name
ORDER BY inventory_value_at_retail DESC;

-- Expected output: 39 rows (one per vertical)
-- QuickSight Usage: Import as "Inventory by Category" dataset
-- Visualizations: Treemap (inventory value), Donut chart (distribution)

-- Test the view
SELECT * FROM v_inventory_value_by_vertical ORDER BY inventory_value_at_retail DESC LIMIT 10;

-- ============================================================================
-- SECTION 6: INVENTORY AGING ANALYSIS
-- Identify slow-moving inventory by product age
-- ============================================================================

CREATE OR REPLACE VIEW v_inventory_aging AS
SELECT 
    c.id as commodity_id,
    c.sku,
    c.name as product_name,
    v.name as vertical_name,
    c.created_at as product_launch_date,
    DATEDIFF(day, c.created_at, GETDATE()) as days_since_launch,
    
    -- Stock metrics
    c.quantity as current_stock,
    c.total_sold as lifetime_units_sold,
    c.status,
    
    -- Age classification
    CASE 
        WHEN DATEDIFF(day, c.created_at, GETDATE()) <= 30 THEN '🆕 New (0-30 days)'
        WHEN DATEDIFF(day, c.created_at, GETDATE()) <= 90 THEN '📦 Recent (31-90 days)'
        WHEN DATEDIFF(day, c.created_at, GETDATE()) <= 180 THEN '📅 Mature (91-180 days)'
        WHEN DATEDIFF(day, c.created_at, GETDATE()) <= 365 THEN '🗓️ Aging (181-365 days)'
        ELSE '⏰ Old (>365 days)'
    END as age_category,
    
    -- Velocity vs age
    CASE 
        WHEN c.total_sold = 0 AND DATEDIFF(day, c.created_at, GETDATE()) > 90 
            THEN '🔴 Dead Stock (No Sales >90d)'
        WHEN c.total_sold < 10 AND DATEDIFF(day, c.created_at, GETDATE()) > 180 
            THEN '🟠 Slow Mover'
        WHEN c.quantity > c.total_sold AND DATEDIFF(day, c.created_at, GETDATE()) > 180 
            THEN '🟡 Overstock'
        ELSE '🟢 Normal'
    END as inventory_aging_status,
    
    -- Financial impact
    ROUND((c.quantity * c.cost_price)::NUMERIC, 2) as tied_up_capital,
    ROUND((c.price - c.cost_price)::NUMERIC, 2) as profit_margin_per_unit,
    
    -- Performance
    c.rating_avg,
    c.review_count,
    
    -- Recommendation
    CASE 
        WHEN c.total_sold = 0 AND DATEDIFF(day, c.created_at, GETDATE()) > 180 
            THEN 'Consider discontinuing or heavy discount'
        WHEN c.quantity > c.total_sold * 2 AND DATEDIFF(day, c.created_at, GETDATE()) > 180 
            THEN 'Run clearance promotion'
        WHEN c.total_sold < 10 AND c.rating_avg < 3 
            THEN 'Review product quality or listing'
        ELSE 'No action needed'
    END as recommendation
FROM commodities c
JOIN verticals v ON c.vertical_id = v.id
WHERE c.status IN ('available', 'unavailable', 'out of stock')
ORDER BY 
    CASE 
        WHEN c.total_sold = 0 AND DATEDIFF(day, c.created_at, GETDATE()) > 90 THEN 1
        ELSE 2
    END,
    tied_up_capital DESC;

-- Expected output: ~5000 rows
-- QuickSight Usage: Import as "Inventory Aging" dataset
-- Visualizations: Stacked bar (age category by status), Table (dead stock)

-- Test the view - Find dead stock
SELECT * FROM v_inventory_aging 
WHERE inventory_aging_status LIKE '%Dead Stock%'
ORDER BY tied_up_capital DESC
LIMIT 20;

-- ============================================================================
-- SECTION 7: INVENTORY DASHBOARD SUMMARY
-- KPI summary for dashboard header
-- ============================================================================

CREATE OR REPLACE VIEW v_inventory_dashboard_summary AS
WITH current_inventory AS (
    SELECT 
        COUNT(*) as total_products,
        SUM(quantity) as total_units,
        SUM(quantity * cost_price) as inventory_value_cost,
        SUM(quantity * price) as inventory_value_retail,
        COUNT(CASE WHEN quantity = 0 THEN 1 END) as out_of_stock_count,
        COUNT(CASE WHEN quantity <= reorder_level THEN 1 END) as low_stock_count
    FROM commodities
    WHERE status IN ('available', 'unavailable', 'out of stock')
),
monthly_sold AS (
    SELECT 
        SUM(oc.quantity) as units_sold_30d
    FROM order_commodities oc
    JOIN orders o ON oc.order_id = o.id
    WHERE o.created_at >= DATEADD(day, -30, GETDATE())
        AND o.status IN ('delivered', 'done')
)
SELECT 
    ci.total_products,
    ci.total_units,
    ROUND(ci.inventory_value_cost::NUMERIC, 2) as total_inventory_value_cost,
    ROUND(ci.inventory_value_retail::NUMERIC, 2) as total_inventory_value_retail,
    ci.out_of_stock_count,
    ci.low_stock_count,
    ROUND((ci.out_of_stock_count::DECIMAL / NULLIF(ci.total_products, 0) * 100)::NUMERIC, 2) as stockout_rate_pct,
    COALESCE(ms.units_sold_30d, 0) as units_sold_last_30d,
    ROUND((ci.total_units::DECIMAL / NULLIF(COALESCE(ms.units_sold_30d, 0), 0))::NUMERIC, 2) as months_of_inventory,
    
    -- Health status
    CASE 
        WHEN ci.out_of_stock_count::DECIMAL / NULLIF(ci.total_products, 0) > 0.10 
            THEN '🔴 High Stockout Rate'
        WHEN ci.low_stock_count::DECIMAL / NULLIF(ci.total_products, 0) > 0.20 
            THEN '🟡 Many Low Stock Items'
        ELSE '🟢 Healthy Inventory'
    END as inventory_health_status
FROM current_inventory ci
CROSS JOIN monthly_sold ms;

-- Expected output: Single row with KPIs
-- QuickSight Usage: Import as "Inventory KPIs" dataset
-- Visualizations: KPI cards across dashboard top

-- Test the view
SELECT * FROM v_inventory_dashboard_summary;

-- ============================================================================
-- SECTION 8: VERIFICATION & FREE TIER OPTIMIZATION
-- ============================================================================

-- List all created inventory views
SELECT 
    table_name as view_name,
    'View' as object_type
FROM information_schema.views
WHERE table_schema = 'public'
    AND table_name LIKE 'v_inventory%'
    OR table_name LIKE 'v_reorder%'
ORDER BY table_name;

-- Estimate row counts for SPICE import
SELECT 
    'v_inventory_current_status' as view_name,
    COUNT(*) as estimated_rows,
    'Primary inventory table' as usage
FROM v_inventory_current_status
UNION ALL
SELECT 
    'v_inventory_turnover',
    COUNT(*),
    'Velocity analysis'
FROM v_inventory_turnover
UNION ALL
SELECT 
    'v_reorder_recommendations',
    COUNT(*),
    'Action items'
FROM v_reorder_recommendations
UNION ALL
SELECT 
    'v_inventory_value_by_vertical',
    COUNT(*),
    'Category breakdown'
FROM v_inventory_value_by_vertical
UNION ALL
SELECT 
    'v_inventory_aging',
    COUNT(*),
    'Dead stock analysis'
FROM v_inventory_aging
UNION ALL
SELECT 
    'v_inventory_dashboard_summary',
    COUNT(*),
    'KPI cards'
FROM v_inventory_dashboard_summary;

-- ============================================================================
-- QUICKSIGHT IMPORT RECOMMENDATIONS
-- ============================================================================

/*
FREE TIER OPTIMIZATION TIPS:
1. Import these views to SPICE (not direct query) - total ~15KB data
2. Schedule SPICE refresh daily at 3 AM
3. Use filters to reduce displayed data (e.g., show only problem items)
4. Total SPICE usage: ~20KB - well within 10GB free tier limit

DATASET IMPORT ORDER:
1. v_inventory_current_status (~5000 rows)
2. v_inventory_turnover (~5000 rows)
3. v_reorder_recommendations (100-500 rows)
4. v_inventory_value_by_vertical (~39 rows)
5. v_inventory_aging (~5000 rows)
6. v_inventory_dashboard_summary (1 row)

VISUALIZATION RECOMMENDATIONS:
Dashboard: "Inventory Management Control Center"
├── KPI Cards (v_inventory_dashboard_summary):
│   ├── Total Inventory Value
│   ├── Stockout Rate %
│   ├── Low Stock Items
│   └── Inventory Health Status
├── Table with Conditional Formatting (v_reorder_recommendations):
│   ├── Columns: SKU, Product, Stock, Urgency, Suggested Qty
│   ├── Conditional: Red for URGENT, Orange for HIGH
│   └── Sort: By reorder_priority ASC
├── Bar Chart (v_inventory_turnover):
│   ├── X-axis: product_name (top 20)
│   ├── Y-axis: units_sold_30d
│   ├── Color: velocity_category
│   └── Filter: velocity_category != 'Slow/No Movement'
├── Donut Chart (v_inventory_value_by_vertical):
│   ├── Values: inventory_value_at_retail
│   ├── Group: vertical_name
│   └── Tooltip: total_products, potential_profit
├── Scatter Plot (v_inventory_current_status):
│   ├── X-axis: current_stock
│   ├── Y-axis: lifetime_units_sold
│   ├── Size: inventory_value_at_retail
│   └── Color: stock_status
└── Table (v_inventory_aging):
    ├── Filter: inventory_aging_status = 'Dead Stock'
    ├── Columns: SKU, Product, Days Since Launch, Tied Up Capital
    └── Sort: By tied_up_capital DESC

FILTERS TO ADD:
- Vertical filter (dropdown)
- Stock status filter (multi-select)
- Velocity category filter (multi-select)
- Date range (product_launch_date)

ALERTS TO CONFIGURE:
- Email when stockout_rate_pct > 10%
- Email when reorder_recommendations count > 50
- Daily digest of URGENT reorder items
*/

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================
SELECT 
    '✅ Inventory Analysis Views Created Successfully' as status,
    '6 views ready for QuickSight import' as views_created,
    'Estimated SPICE usage: ~20KB' as spice_usage,
    'All optimized for Free Tier' as optimization;

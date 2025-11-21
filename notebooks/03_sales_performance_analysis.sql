-- ============================================================================
-- NOTEBOOK 3: SALES PERFORMANCE ANALYSIS
-- Business Objective: Track seller performance, product rankings, conversion rates
-- QuickSight Compatibility: All views optimized for SPICE import
-- Free Tier Considerations: Aggregated metrics with minimal data volume
-- ============================================================================

-- ============================================================================
-- SECTION 1: DATA VALIDATION
-- Verify sales data completeness
-- ============================================================================

-- Overall sales snapshot
SELECT 
    COUNT(DISTINCT s.id) as total_sellers,
    COUNT(DISTINCT c.id) as total_products,
    COUNT(DISTINCT o.id) as total_orders,
    COUNT(DISTINCT CASE WHEN o.status IN ('delivered', 'done') THEN o.id END) as completed_orders,
    ROUND(SUM(CASE WHEN o.status IN ('delivered', 'done') THEN o.total_amount ELSE 0 END)::NUMERIC, 2) as total_revenue,
    ROUND(AVG(CASE WHEN o.status IN ('delivered', 'done') THEN o.total_amount END)::NUMERIC, 2) as avg_order_value
FROM sellers s
LEFT JOIN orders o ON s.id = o.seller_id
LEFT JOIN commodities c ON s.id = c.seller_id;

-- Expected output: High-level sales metrics
-- QuickSight Usage: Not needed - validation only

-- ============================================================================
-- SECTION 2: SELLER PERFORMANCE LEADERBOARD
-- Rank sellers by revenue, orders, and customer satisfaction
-- ============================================================================

CREATE OR REPLACE VIEW v_seller_performance AS
WITH seller_orders AS (
    SELECT 
        o.seller_id,
        COUNT(DISTINCT o.id) as total_orders,
        COUNT(DISTINCT CASE WHEN o.status IN ('delivered', 'done') THEN o.id END) as completed_orders,
        COUNT(DISTINCT CASE WHEN o.status IN ('cancelled', 'abandoned') THEN o.id END) as cancelled_orders,
        SUM(CASE WHEN o.status IN ('delivered', 'done') THEN o.total_amount ELSE 0 END) as total_revenue,
        SUM(CASE WHEN o.status IN ('delivered', 'done') THEN o.subtotal_amount ELSE 0 END) as subtotal_revenue,
        AVG(CASE WHEN o.status IN ('delivered', 'done') THEN o.total_amount END) as avg_order_value,
        COUNT(DISTINCT o.consumer_id) as unique_customers,
        MIN(o.created_at) as first_sale_date,
        MAX(o.created_at) as last_sale_date
    FROM orders o
    GROUP BY o.seller_id
),
seller_products AS (
    SELECT 
        c.seller_id,
        COUNT(DISTINCT c.id) as total_products,
        COUNT(DISTINCT CASE WHEN c.status = 'available' THEN c.id END) as active_products,
        AVG(c.rating_avg) as avg_product_rating,
        SUM(c.review_count) as total_reviews,
        SUM(c.total_sold) as total_units_sold
    FROM commodities c
    GROUP BY c.seller_id
)
SELECT 
    s.id as seller_id,
    u.name as seller_name,
    u.username as seller_username,
    s.type as seller_type,
    s.city,
    s.country,
    
    -- Order metrics
    COALESCE(so.total_orders, 0) as total_orders,
    COALESCE(so.completed_orders, 0) as completed_orders,
    COALESCE(so.cancelled_orders, 0) as cancelled_orders,
    ROUND(
        (COALESCE(so.completed_orders, 0)::DECIMAL / NULLIF(COALESCE(so.total_orders, 0), 0) * 100)::NUMERIC,
        2
    ) as order_completion_rate_pct,
    
    -- Revenue metrics
    ROUND(COALESCE(so.total_revenue, 0)::NUMERIC, 2) as total_revenue,
    ROUND(COALESCE(so.subtotal_revenue, 0)::NUMERIC, 2) as subtotal_revenue,
    ROUND(COALESCE(so.avg_order_value, 0)::NUMERIC, 2) as avg_order_value,
    
    -- Customer metrics
    COALESCE(so.unique_customers, 0) as unique_customers,
    ROUND(
        (COALESCE(so.completed_orders, 0)::DECIMAL / NULLIF(COALESCE(so.unique_customers, 0), 0))::NUMERIC,
        2
    ) as avg_orders_per_customer,
    
    -- Product metrics
    COALESCE(sp.total_products, 0) as total_products,
    COALESCE(sp.active_products, 0) as active_products,
    COALESCE(sp.total_units_sold, 0) as total_units_sold,
    ROUND(
        (COALESCE(sp.total_units_sold, 0)::DECIMAL / NULLIF(COALESCE(sp.total_products, 0), 0))::NUMERIC,
        2
    ) as avg_units_per_product,
    
    -- Quality metrics
    ROUND(COALESCE(sp.avg_product_rating, 0)::NUMERIC, 2) as avg_product_rating,
    COALESCE(sp.total_reviews, 0) as total_reviews,
    s.rating_avg as seller_rating_avg,
    
    -- Activity metrics
    so.first_sale_date,
    so.last_sale_date,
    CASE 
        WHEN so.last_sale_date >= DATEADD(day, -30, GETDATE()) THEN '🟢 Active'
        WHEN so.last_sale_date >= DATEADD(day, -90, GETDATE()) THEN '🟡 Inactive (< 90d)'
        ELSE '🔴 Dormant (> 90d)'
    END as seller_status,
    
    -- Performance tier
    CASE 
        WHEN COALESCE(so.total_revenue, 0) >= 100000 AND COALESCE(sp.avg_product_rating, 0) >= 4.0 
            THEN '⭐⭐⭐ Elite Seller'
        WHEN COALESCE(so.total_revenue, 0) >= 50000 AND COALESCE(sp.avg_product_rating, 0) >= 3.5 
            THEN '⭐⭐ Top Seller'
        WHEN COALESCE(so.total_revenue, 0) >= 10000 
            THEN '⭐ Regular Seller'
        ELSE '📦 New/Small Seller'
    END as performance_tier,
    
    -- Rankings (calculated in outer query)
    RANK() OVER (ORDER BY COALESCE(so.total_revenue, 0) DESC) as revenue_rank,
    RANK() OVER (ORDER BY COALESCE(so.completed_orders, 0) DESC) as orders_rank,
    RANK() OVER (ORDER BY COALESCE(sp.avg_product_rating, 0) DESC NULLS LAST) as rating_rank
FROM sellers s
JOIN users u ON s.id = u.id
LEFT JOIN seller_orders so ON s.id = so.seller_id
LEFT JOIN seller_products sp ON s.id = sp.seller_id
WHERE u.status = 'active'
ORDER BY total_revenue DESC;

-- Expected output: ~100 rows (one per seller)
-- QuickSight Usage: Import as "Seller Performance" dataset
-- Visualizations: Leaderboard table, Bar chart (top sellers), Scatter (revenue vs rating)

-- Test the view - Top 10 sellers
SELECT * FROM v_seller_performance ORDER BY total_revenue DESC LIMIT 10;

-- Test the view - Elite sellers
SELECT * FROM v_seller_performance WHERE performance_tier = '⭐⭐⭐ Elite Seller';

-- ============================================================================
-- SECTION 3: PRODUCT PERFORMANCE RANKINGS
-- Best and worst performing products
-- ============================================================================

CREATE OR REPLACE VIEW v_product_performance AS
WITH product_sales AS (
    SELECT 
        oc.commodity_id,
        COUNT(DISTINCT oc.order_id) as total_orders,
        SUM(oc.quantity) as total_units_sold,
        SUM(oc.line_total) as total_revenue,
        AVG(oc.unit_price) as avg_selling_price,
        MIN(o.created_at) as first_sale_date,
        MAX(o.created_at) as last_sale_date
    FROM order_commodities oc
    JOIN orders o ON oc.order_id = o.id
    WHERE o.status IN ('delivered', 'done')
    GROUP BY oc.commodity_id
),
product_sales_30d AS (
    SELECT 
        oc.commodity_id,
        SUM(oc.quantity) as units_sold_30d,
        SUM(oc.line_total) as revenue_30d,
        COUNT(DISTINCT oc.order_id) as orders_30d
    FROM order_commodities oc
    JOIN orders o ON oc.order_id = o.id
    WHERE o.created_at >= DATEADD(day, -30, GETDATE())
        AND o.status IN ('delivered', 'done')
    GROUP BY oc.commodity_id
)
SELECT 
    c.id as commodity_id,
    c.sku,
    c.name as product_name,
    v.name as vertical_name,
    u.name as seller_name,
    c.status as product_status,
    
    -- Pricing
    c.price as current_price,
    c.cost_price,
    ROUND((c.price - c.cost_price)::NUMERIC, 2) as profit_margin_per_unit,
    ROUND(((c.price - c.cost_price) / NULLIF(c.price, 0) * 100)::NUMERIC, 2) as profit_margin_pct,
    
    -- Lifetime sales
    COALESCE(ps.total_orders, 0) as total_orders,
    COALESCE(ps.total_units_sold, 0) as total_units_sold,
    ROUND(COALESCE(ps.total_revenue, 0)::NUMERIC, 2) as total_revenue,
    ROUND(
        (COALESCE(ps.total_revenue, 0) - (COALESCE(ps.total_units_sold, 0) * c.cost_price))::NUMERIC,
        2
    ) as total_profit,
    
    -- Recent performance (30 days)
    COALESCE(p30.units_sold_30d, 0) as units_sold_30d,
    ROUND(COALESCE(p30.revenue_30d, 0)::NUMERIC, 2) as revenue_30d,
    COALESCE(p30.orders_30d, 0) as orders_30d,
    
    -- Quality metrics
    c.rating_avg,
    c.review_count,
    
    -- Inventory
    c.quantity as current_stock,
    
    -- Activity dates
    c.created_at as product_launch_date,
    ps.first_sale_date,
    ps.last_sale_date,
    DATEDIFF(day, c.created_at, GETDATE()) as days_since_launch,
    
    -- Velocity classification
    CASE 
        WHEN COALESCE(p30.units_sold_30d, 0) = 0 THEN '🐌 No Sales (30d)'
        WHEN COALESCE(p30.units_sold_30d, 0) < 10 THEN '🚶 Low Sales'
        WHEN COALESCE(p30.units_sold_30d, 0) < 50 THEN '🏃 Medium Sales'
        WHEN COALESCE(p30.units_sold_30d, 0) < 200 THEN '🚀 High Sales'
        ELSE '⚡ Best Seller'
    END as sales_velocity,
    
    -- Performance tier
    CASE 
        WHEN COALESCE(ps.total_revenue, 0) >= 50000 AND c.rating_avg >= 4.5 
            THEN '⭐⭐⭐ Star Product'
        WHEN COALESCE(ps.total_revenue, 0) >= 20000 AND c.rating_avg >= 4.0 
            THEN '⭐⭐ Top Product'
        WHEN COALESCE(ps.total_revenue, 0) >= 5000 
            THEN '⭐ Regular Product'
        WHEN DATEDIFF(day, c.created_at, GETDATE()) < 30 
            THEN '🆕 New Product'
        ELSE '📦 Low Performer'
    END as performance_tier,
    
    -- Rankings
    RANK() OVER (ORDER BY COALESCE(ps.total_revenue, 0) DESC) as revenue_rank,
    RANK() OVER (ORDER BY COALESCE(ps.total_units_sold, 0) DESC) as units_rank,
    RANK() OVER (ORDER BY c.rating_avg DESC NULLS LAST) as rating_rank,
    RANK() OVER (PARTITION BY v.id ORDER BY COALESCE(ps.total_revenue, 0) DESC) as revenue_rank_in_vertical
FROM commodities c
JOIN verticals v ON c.vertical_id = v.id
JOIN sellers s ON c.seller_id = s.id
JOIN users u ON s.id = u.id
LEFT JOIN product_sales ps ON c.id = ps.commodity_id
LEFT JOIN product_sales_30d p30 ON c.id = p30.commodity_id
WHERE c.status IN ('available', 'unavailable', 'out of stock')
ORDER BY total_revenue DESC NULLS LAST;

-- Expected output: ~5000 rows (one per product)
-- QuickSight Usage: Import as "Product Performance" dataset
-- Visualizations: Top 100 table, Category comparison, Profit margin analysis

-- Test the view - Top 20 products by revenue
SELECT * FROM v_product_performance ORDER BY total_revenue DESC LIMIT 20;

-- Test the view - Star products
SELECT * FROM v_product_performance WHERE performance_tier = '⭐⭐⭐ Star Product';

-- Test the view - Top products per vertical
SELECT * FROM v_product_performance WHERE revenue_rank_in_vertical <= 5 ORDER BY vertical_name, revenue_rank_in_vertical;

-- ============================================================================
-- SECTION 4: CONVERSION FUNNEL ANALYSIS
-- Track order progression through statuses
-- ============================================================================

CREATE OR REPLACE VIEW v_sales_conversion_funnel AS
WITH order_counts AS (
    SELECT 
        COUNT(DISTINCT CASE WHEN status IN ('draft', 'inprogress', 'pending', 'shipped', 'delivered', 'done', 'cancelled', 'abandoned') THEN id END) as total_orders_created,
        COUNT(DISTINCT CASE WHEN status IN ('inprogress', 'pending', 'shipped', 'delivered', 'done') THEN id END) as orders_confirmed,
        COUNT(DISTINCT CASE WHEN paid_at IS NOT NULL THEN id END) as orders_paid,
        COUNT(DISTINCT CASE WHEN status = 'shipped' THEN id END) as orders_shipped,
        COUNT(DISTINCT CASE WHEN status = 'delivered' THEN id END) as orders_delivered,
        COUNT(DISTINCT CASE WHEN status = 'done' THEN id END) as orders_completed,
        COUNT(DISTINCT CASE WHEN status IN ('cancelled', 'abandoned') THEN id END) as orders_dropped,
        
        SUM(CASE WHEN status IN ('delivered', 'done') THEN total_amount ELSE 0 END) as total_revenue
    FROM orders
),
order_counts_30d AS (
    SELECT 
        COUNT(DISTINCT CASE WHEN status IN ('draft', 'inprogress', 'pending', 'shipped', 'delivered', 'done', 'cancelled', 'abandoned') THEN id END) as total_orders_created_30d,
        COUNT(DISTINCT CASE WHEN status IN ('inprogress', 'pending', 'shipped', 'delivered', 'done') THEN id END) as orders_confirmed_30d,
        COUNT(DISTINCT CASE WHEN paid_at IS NOT NULL THEN id END) as orders_paid_30d,
        COUNT(DISTINCT CASE WHEN status = 'shipped' THEN id END) as orders_shipped_30d,
        COUNT(DISTINCT CASE WHEN status = 'delivered' THEN id END) as orders_delivered_30d,
        COUNT(DISTINCT CASE WHEN status = 'done' THEN id END) as orders_completed_30d,
        COUNT(DISTINCT CASE WHEN status IN ('cancelled', 'abandoned') THEN id END) as orders_dropped_30d
    FROM orders
    WHERE created_at >= DATEADD(day, -30, GETDATE())
)
SELECT 
    -- Lifetime funnel
    oc.total_orders_created,
    oc.orders_confirmed,
    oc.orders_paid,
    oc.orders_shipped,
    oc.orders_delivered,
    oc.orders_completed,
    oc.orders_dropped,
    
    -- Lifetime conversion rates
    ROUND((oc.orders_confirmed::DECIMAL / NULLIF(oc.total_orders_created, 0) * 100)::NUMERIC, 2) as confirm_rate_pct,
    ROUND((oc.orders_paid::DECIMAL / NULLIF(oc.total_orders_created, 0) * 100)::NUMERIC, 2) as payment_rate_pct,
    ROUND((oc.orders_shipped::DECIMAL / NULLIF(oc.orders_paid, 0) * 100)::NUMERIC, 2) as ship_rate_pct,
    ROUND((oc.orders_delivered::DECIMAL / NULLIF(oc.orders_shipped, 0) * 100)::NUMERIC, 2) as delivery_rate_pct,
    ROUND((oc.orders_completed::DECIMAL / NULLIF(oc.total_orders_created, 0) * 100)::NUMERIC, 2) as overall_completion_rate_pct,
    ROUND((oc.orders_dropped::DECIMAL / NULLIF(oc.total_orders_created, 0) * 100)::NUMERIC, 2) as drop_rate_pct,
    
    -- 30-day funnel
    oc30.total_orders_created_30d,
    oc30.orders_confirmed_30d,
    oc30.orders_paid_30d,
    oc30.orders_shipped_30d,
    oc30.orders_delivered_30d,
    oc30.orders_completed_30d,
    oc30.orders_dropped_30d,
    
    -- 30-day conversion rates
    ROUND((oc30.orders_confirmed_30d::DECIMAL / NULLIF(oc30.total_orders_created_30d, 0) * 100)::NUMERIC, 2) as confirm_rate_pct_30d,
    ROUND((oc30.orders_completed_30d::DECIMAL / NULLIF(oc30.total_orders_created_30d, 0) * 100)::NUMERIC, 2) as completion_rate_pct_30d,
    
    -- Revenue metrics
    ROUND(oc.total_revenue::NUMERIC, 2) as total_revenue,
    ROUND((oc.total_revenue / NULLIF(oc.orders_completed, 0))::NUMERIC, 2) as avg_revenue_per_completed_order
FROM order_counts oc
CROSS JOIN order_counts_30d oc30;

-- Expected output: 1 row with funnel metrics
-- QuickSight Usage: Import as "Sales Funnel" dataset
-- Visualizations: Funnel chart, Conversion rate KPI cards

-- Test the view
SELECT * FROM v_sales_conversion_funnel;

-- ============================================================================
-- SECTION 5: MONTHLY SALES TRENDS BY SELLER TYPE
-- Compare vendor vs authorized sellers over time
-- ============================================================================

CREATE OR REPLACE VIEW v_sales_by_seller_type AS
SELECT 
    DATE_TRUNC('month', o.created_at) as month,
    TO_CHAR(o.created_at, 'YYYY-MM') as year_month,
    s.type as seller_type,
    
    -- Order metrics
    COUNT(DISTINCT o.id) as total_orders,
    COUNT(DISTINCT CASE WHEN o.status IN ('delivered', 'done') THEN o.id END) as completed_orders,
    
    -- Revenue metrics
    ROUND(SUM(CASE WHEN o.status IN ('delivered', 'done') THEN o.total_amount ELSE 0 END)::NUMERIC, 2) as total_revenue,
    ROUND(AVG(CASE WHEN o.status IN ('delivered', 'done') THEN o.total_amount END)::NUMERIC, 2) as avg_order_value,
    
    -- Customer metrics
    COUNT(DISTINCT o.consumer_id) as unique_customers,
    
    -- Seller count
    COUNT(DISTINCT o.seller_id) as active_sellers
FROM orders o
JOIN sellers s ON o.seller_id = s.id
GROUP BY 1, 2, 3
ORDER BY 1 DESC, 3;

-- Expected output: ~48 rows (24 months × 2 seller types)
-- QuickSight Usage: Import as "Sales by Seller Type" dataset
-- Visualizations: Stacked area chart, Comparison table

-- Test the view
SELECT * FROM v_sales_by_seller_type ORDER BY month DESC, seller_type LIMIT 20;

-- ============================================================================
-- SECTION 6: DAILY SALES VELOCITY (Last 90 Days)
-- Track daily sales patterns
-- ============================================================================

CREATE OR REPLACE VIEW v_daily_sales_velocity AS
SELECT 
    DATE_TRUNC('day', o.created_at) as sale_date,
    TO_CHAR(o.created_at, 'YYYY-MM-DD') as date_label,
    EXTRACT(DOW FROM o.created_at) as day_of_week_num,
    CASE EXTRACT(DOW FROM o.created_at)
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END as day_of_week_name,
    
    -- Daily metrics
    COUNT(DISTINCT o.id) as total_orders,
    COUNT(DISTINCT CASE WHEN o.status IN ('delivered', 'done') THEN o.id END) as completed_orders,
    ROUND(SUM(CASE WHEN o.status IN ('delivered', 'done') THEN o.total_amount ELSE 0 END)::NUMERIC, 2) as total_revenue,
    COUNT(DISTINCT o.consumer_id) as unique_customers,
    COUNT(DISTINCT o.seller_id) as active_sellers,
    
    -- Average metrics
    ROUND(AVG(CASE WHEN o.status IN ('delivered', 'done') THEN o.total_amount END)::NUMERIC, 2) as avg_order_value,
    
    -- Completion rate
    ROUND(
        (COUNT(DISTINCT CASE WHEN o.status IN ('delivered', 'done') THEN o.id END)::DECIMAL 
        / NULLIF(COUNT(DISTINCT o.id), 0) * 100)::NUMERIC,
        2
    ) as completion_rate_pct
FROM orders o
WHERE o.created_at >= DATEADD(day, -90, GETDATE())
GROUP BY 1, 2, 3, 4
ORDER BY 1 DESC;

-- Expected output: ~90 rows (one per day)
-- QuickSight Usage: Import as "Daily Sales" dataset
-- Visualizations: Line chart (daily revenue), Bar chart (by day of week)

-- Test the view
SELECT * FROM v_daily_sales_velocity ORDER BY sale_date DESC LIMIT 30;

-- ============================================================================
-- SECTION 7: SALES DASHBOARD SUMMARY
-- KPI summary for dashboard header
-- ============================================================================

CREATE OR REPLACE VIEW v_sales_dashboard_summary AS
WITH current_month AS (
    SELECT 
        COUNT(DISTINCT seller_id) as active_sellers,
        COUNT(DISTINCT id) as total_orders,
        COUNT(DISTINCT CASE WHEN status IN ('delivered', 'done') THEN id END) as completed_orders,
        SUM(CASE WHEN status IN ('delivered', 'done') THEN total_amount ELSE 0 END) as total_revenue,
        COUNT(DISTINCT consumer_id) as unique_customers
    FROM orders
    WHERE created_at >= DATE_TRUNC('month', GETDATE())
),
previous_month AS (
    SELECT 
        SUM(CASE WHEN status IN ('delivered', 'done') THEN total_amount ELSE 0 END) as prev_month_revenue,
        COUNT(DISTINCT CASE WHEN status IN ('delivered', 'done') THEN id END) as prev_month_orders
    FROM orders
    WHERE created_at >= DATEADD(month, -1, DATE_TRUNC('month', GETDATE()))
        AND created_at < DATE_TRUNC('month', GETDATE())
),
today AS (
    SELECT 
        COUNT(DISTINCT id) as orders_today,
        SUM(CASE WHEN status IN ('delivered', 'done') THEN total_amount ELSE 0 END) as revenue_today
    FROM orders
    WHERE DATE_TRUNC('day', created_at) = DATE_TRUNC('day', GETDATE())
)
SELECT 
    cm.active_sellers,
    cm.total_orders as orders_this_month,
    cm.completed_orders as completed_orders_this_month,
    ROUND(cm.total_revenue::NUMERIC, 2) as revenue_this_month,
    cm.unique_customers as customers_this_month,
    ROUND((cm.total_revenue / NULLIF(cm.completed_orders, 0))::NUMERIC, 2) as avg_order_value_this_month,
    
    -- MoM Growth
    ROUND(
        ((cm.total_revenue - pm.prev_month_revenue) / NULLIF(pm.prev_month_revenue, 0) * 100)::NUMERIC,
        2
    ) as mom_revenue_growth_pct,
    
    -- Today's metrics
    t.orders_today,
    ROUND(COALESCE(t.revenue_today, 0)::NUMERIC, 2) as revenue_today,
    
    -- Health status
    CASE 
        WHEN ((cm.total_revenue - pm.prev_month_revenue) / NULLIF(pm.prev_month_revenue, 0) * 100) > 10 
            THEN '🟢 Strong Growth'
        WHEN ((cm.total_revenue - pm.prev_month_revenue) / NULLIF(pm.prev_month_revenue, 0) * 100) > 0 
            THEN '🟡 Moderate Growth'
        ELSE '🔴 Declining'
    END as sales_health_status
FROM current_month cm
CROSS JOIN previous_month pm
CROSS JOIN today t;

-- Expected output: 1 row with KPIs
-- QuickSight Usage: Import as "Sales KPIs" dataset
-- Visualizations: KPI cards across dashboard top

-- Test the view
SELECT * FROM v_sales_dashboard_summary;

-- ============================================================================
-- SECTION 8: VERIFICATION & FREE TIER OPTIMIZATION
-- ============================================================================

-- List all created sales views
SELECT 
    table_name as view_name,
    'View' as object_type
FROM information_schema.views
WHERE table_schema = 'public'
    AND (table_name LIKE 'v_seller%'
    OR table_name LIKE 'v_product_performance%'
    OR table_name LIKE 'v_sales%')
ORDER BY table_name;

-- Estimate row counts for SPICE import
SELECT 
    'v_seller_performance' as view_name,
    COUNT(*) as estimated_rows,
    'Seller leaderboard' as usage
FROM v_seller_performance
UNION ALL
SELECT 
    'v_product_performance',
    COUNT(*),
    'Product rankings'
FROM v_product_performance
UNION ALL
SELECT 
    'v_sales_conversion_funnel',
    COUNT(*),
    'Funnel analysis'
FROM v_sales_conversion_funnel
UNION ALL
SELECT 
    'v_sales_by_seller_type',
    COUNT(*),
    'Seller type trends'
FROM v_sales_by_seller_type
UNION ALL
SELECT 
    'v_daily_sales_velocity',
    COUNT(*),
    'Daily patterns'
FROM v_daily_sales_velocity
UNION ALL
SELECT 
    'v_sales_dashboard_summary',
    COUNT(*),
    'KPI cards'
FROM v_sales_dashboard_summary;

-- ============================================================================
-- QUICKSIGHT IMPORT RECOMMENDATIONS
-- ============================================================================

/*
FREE TIER OPTIMIZATION TIPS:
1. Import top performers only (filter top 100 sellers/products) to reduce data
2. Use SPICE for all datasets - estimated total: ~30KB
3. Schedule refresh daily during off-peak hours
4. Apply filters in QuickSight to show relevant data only

DATASET IMPORT ORDER:
1. v_seller_performance (~100 rows)
2. v_product_performance (filter: revenue_rank <= 100, ~100 rows)
3. v_sales_conversion_funnel (1 row)
4. v_sales_by_seller_type (~48 rows)
5. v_daily_sales_velocity (~90 rows)
6. v_sales_dashboard_summary (1 row)

VISUALIZATION RECOMMENDATIONS:
Dashboard: "Sales Performance Analytics"
├── KPI Cards (v_sales_dashboard_summary):
│   ├── Revenue This Month
│   ├── MoM Growth %
│   ├── Active Sellers
│   └── Sales Health Status
├── Leaderboard Table (v_seller_performance):
│   ├── Columns: Rank, Seller Name, Revenue, Orders, Rating, Tier
│   ├── Conditional: Color by performance_tier
│   └── Filter: Top 20 by revenue_rank
├── Bar Chart (v_product_performance):
│   ├── X-axis: product_name (top 20)
│   ├── Y-axis: total_revenue
│   ├── Color: performance_tier
│   └── Filter: revenue_rank <= 20
├── Funnel Chart (v_sales_conversion_funnel):
│   ├── Stages: Created → Confirmed → Paid → Shipped → Delivered → Completed
│   └── Show conversion rates between stages
├── Stacked Area Chart (v_sales_by_seller_type):
│   ├── X-axis: year_month
│   ├── Y-axis: total_revenue
│   ├── Stack: seller_type
│   └── Filter: Last 12 months
├── Line Chart (v_daily_sales_velocity):
│   ├── X-axis: sale_date
│   ├── Y-axis: total_revenue
│   ├── Tooltip: total_orders, completion_rate_pct
│   └── Filter: Last 30 days
└── Scatter Plot (v_seller_performance):
    ├── X-axis: total_revenue
    ├── Y-axis: avg_product_rating
    ├── Size: total_orders
    └── Color: performance_tier

FILTERS TO ADD:
- Date range (month)
- Seller type (vendor vs authorized)
- Performance tier
- Country/City

PARAMETERS TO CREATE:
- Top N filter (default 20, for showing top sellers/products)
- Date range selector (7d, 30d, 90d, 1y, All Time)
*/

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================
SELECT 
    '✅ Sales Performance Views Created Successfully' as status,
    '6 views ready for QuickSight import' as views_created,
    'Estimated SPICE usage: ~30KB' as spice_usage,
    'All optimized for Free Tier' as optimization;

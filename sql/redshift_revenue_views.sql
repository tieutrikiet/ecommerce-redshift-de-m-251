-- ============================================================================
-- REVENUE ANALYTICS VIEWS FOR YoY/MoM ANALYSIS
-- Execute in Redshift Query Editor v2 after data is loaded
-- ============================================================================

-- ============================================================================
-- VIEW 1: Monthly Revenue Summary
-- Primary view for MoM analysis and trend visualization
-- ============================================================================
CREATE OR REPLACE VIEW v_monthly_revenue AS
SELECT 
    DATE_TRUNC('month', o.created_at) as month,
    EXTRACT(YEAR FROM o.created_at) as year,
    EXTRACT(MONTH FROM o.created_at) as month_num,
    TO_CHAR(o.created_at, 'YYYY-MM') as year_month,
    TO_CHAR(o.created_at, 'Mon YYYY') as month_label,
    
    -- Order metrics
    COUNT(DISTINCT o.id) as total_orders,
    COUNT(DISTINCT CASE WHEN o.status IN ('delivered', 'done') 
          THEN o.id END) as completed_orders,
    COUNT(DISTINCT CASE WHEN o.status IN ('cancelled', 'abandoned') 
          THEN o.id END) as failed_orders,
    
    -- Revenue metrics (only completed orders count toward revenue)
    SUM(CASE WHEN o.status IN ('delivered', 'done') 
        THEN o.total_amount ELSE 0 END) as total_revenue,
    SUM(CASE WHEN o.status IN ('delivered', 'done') 
        THEN o.subtotal_amount ELSE 0 END) as subtotal_revenue,
    SUM(CASE WHEN o.status IN ('delivered', 'done') 
        THEN o.tax_amount ELSE 0 END) as total_tax,
    SUM(CASE WHEN o.status IN ('delivered', 'done') 
        THEN o.shipping_fee ELSE 0 END) as total_shipping,
    SUM(CASE WHEN o.status IN ('delivered', 'done') 
        THEN o.discount_amount ELSE 0 END) as total_discounts,
    
    -- Average metrics
    AVG(CASE WHEN o.status IN ('delivered', 'done') 
        THEN o.total_amount END) as avg_order_value,
    PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY CASE WHEN o.status IN ('delivered', 'done') 
                 THEN o.total_amount END
    ) as median_order_value,
    
    -- Customer metrics
    COUNT(DISTINCT o.consumer_id) as unique_customers,
    COUNT(DISTINCT CASE WHEN o.status IN ('delivered', 'done') 
          THEN o.consumer_id END) as paying_customers,
    
    -- Conversion rate
    ROUND(
        COUNT(DISTINCT CASE WHEN o.status IN ('delivered', 'done') THEN o.id END)::DECIMAL 
        / NULLIF(COUNT(DISTINCT o.id), 0) * 100, 
        2
    ) as order_completion_rate_pct
FROM orders o
GROUP BY 1, 2, 3, 4, 5
ORDER BY 1 DESC;

-- Test the view
SELECT * FROM v_monthly_revenue ORDER BY month DESC LIMIT 12;

-- ============================================================================
-- VIEW 2: Year-over-Year (YoY) Revenue Comparison
-- Compare same month across different years
-- ============================================================================
CREATE OR REPLACE VIEW v_yoy_revenue_comparison AS
WITH monthly_data AS (
    SELECT * FROM v_monthly_revenue
)
SELECT 
    m1.month_num,
    TO_CHAR(TO_DATE(m1.month_num::TEXT, 'MM'), 'Month') as month_name,
    
    -- Current year data
    m1.year as current_year,
    m1.month_label as current_month_label,
    m1.total_revenue as current_year_revenue,
    m1.total_orders as current_year_orders,
    m1.unique_customers as current_year_customers,
    m1.avg_order_value as current_year_aov,
    
    -- Previous year data
    m2.year as previous_year,
    m2.month_label as previous_month_label,
    m2.total_revenue as previous_year_revenue,
    m2.total_orders as previous_year_orders,
    m2.unique_customers as previous_year_customers,
    m2.avg_order_value as previous_year_aov,
    
    -- YoY Growth calculations - Revenue
    ROUND(
        ((m1.total_revenue - m2.total_revenue) / NULLIF(m2.total_revenue, 0) * 100)::NUMERIC,
        2
    ) as revenue_growth_pct,
    ROUND((m1.total_revenue - m2.total_revenue)::NUMERIC, 2) as revenue_growth_amount,
    
    -- YoY Growth calculations - Orders
    ROUND(
        ((m1.total_orders - m2.total_orders)::DECIMAL / NULLIF(m2.total_orders, 0) * 100)::NUMERIC,
        2
    ) as order_growth_pct,
    (m1.total_orders - m2.total_orders) as order_growth_count,
    
    -- YoY Growth calculations - Customers
    ROUND(
        ((m1.unique_customers - m2.unique_customers)::DECIMAL / NULLIF(m2.unique_customers, 0) * 100)::NUMERIC,
        2
    ) as customer_growth_pct,
    
    -- YoY Growth calculations - AOV
    ROUND(
        ((m1.avg_order_value - m2.avg_order_value) / NULLIF(m2.avg_order_value, 0) * 100)::NUMERIC,
        2
    ) as aov_growth_pct
FROM monthly_data m1
LEFT JOIN monthly_data m2 
    ON m1.month_num = m2.month_num 
    AND m1.year = m2.year + 1
WHERE m2.year IS NOT NULL  -- Only show months with YoY comparison
ORDER BY m1.year DESC, m1.month_num DESC;

-- Test the view
SELECT * FROM v_yoy_revenue_comparison LIMIT 12;

-- ============================================================================
-- VIEW 3: Month-over-Month (MoM) Revenue Comparison
-- Sequential month comparison
-- ============================================================================
CREATE OR REPLACE VIEW v_mom_revenue_comparison AS
WITH monthly_data AS (
    SELECT * FROM v_monthly_revenue
),
with_previous AS (
    SELECT 
        *,
        LAG(total_revenue, 1) OVER (ORDER BY month) as prev_month_revenue,
        LAG(total_orders, 1) OVER (ORDER BY month) as prev_month_orders,
        LAG(unique_customers, 1) OVER (ORDER BY month) as prev_month_customers,
        LAG(avg_order_value, 1) OVER (ORDER BY month) as prev_month_aov,
        LAG(month_label, 1) OVER (ORDER BY month) as prev_month_label,
        LAG(completed_orders, 1) OVER (ORDER BY month) as prev_completed_orders
    FROM monthly_data
)
SELECT 
    month,
    month_label,
    year,
    month_num,
    
    -- Current month metrics
    total_revenue,
    total_orders,
    completed_orders,
    unique_customers,
    avg_order_value,
    order_completion_rate_pct,
    
    -- Previous month metrics
    prev_month_label,
    prev_month_revenue,
    prev_month_orders,
    prev_month_customers,
    prev_month_aov,
    
    -- MoM Growth calculations - Revenue
    ROUND(
        ((total_revenue - prev_month_revenue) / NULLIF(prev_month_revenue, 0) * 100)::NUMERIC,
        2
    ) as revenue_growth_pct,
    ROUND((total_revenue - prev_month_revenue)::NUMERIC, 2) as revenue_growth_amount,
    
    -- MoM Growth calculations - Orders
    ROUND(
        ((total_orders - prev_month_orders)::DECIMAL / NULLIF(prev_month_orders, 0) * 100)::NUMERIC,
        2
    ) as order_growth_pct,
    (total_orders - prev_month_orders) as order_growth_count,
    
    -- MoM Growth calculations - Customers
    ROUND(
        ((unique_customers - prev_month_customers)::DECIMAL / NULLIF(prev_month_customers, 0) * 100)::NUMERIC,
        2
    ) as customer_growth_pct,
    
    -- MoM Growth calculations - AOV
    ROUND(
        ((avg_order_value - prev_month_aov) / NULLIF(prev_month_aov, 0) * 100)::NUMERIC,
        2
    ) as aov_growth_pct,
    
    -- Trend indicator
    CASE 
        WHEN ((total_revenue - prev_month_revenue) / NULLIF(prev_month_revenue, 0) * 100) > 0 
            THEN '📈 Growing'
        WHEN ((total_revenue - prev_month_revenue) / NULLIF(prev_month_revenue, 0) * 100) < 0 
            THEN '📉 Declining'
        ELSE '➡️ Flat'
    END as revenue_trend
FROM with_previous
WHERE prev_month_revenue IS NOT NULL  -- Only show months with MoM comparison
ORDER BY month DESC;

-- Test the view
SELECT * FROM v_mom_revenue_comparison LIMIT 12;

-- ============================================================================
-- VIEW 4: Quarterly Revenue Trends (Seasonal Analysis)
-- ============================================================================
CREATE OR REPLACE VIEW v_quarterly_trends AS
SELECT 
    EXTRACT(YEAR FROM o.created_at) as year,
    EXTRACT(QUARTER FROM o.created_at) as quarter,
    'Q' || EXTRACT(QUARTER FROM o.created_at) || ' ' || EXTRACT(YEAR FROM o.created_at) as quarter_label,
    DATE_TRUNC('quarter', o.created_at) as quarter_start,
    
    -- Order metrics
    COUNT(DISTINCT o.id) as total_orders,
    COUNT(DISTINCT CASE WHEN o.status IN ('delivered', 'done') 
          THEN o.id END) as completed_orders,
    
    -- Revenue metrics
    SUM(CASE WHEN o.status IN ('delivered', 'done') 
        THEN o.total_amount ELSE 0 END) as total_revenue,
    AVG(CASE WHEN o.status IN ('delivered', 'done') 
        THEN o.total_amount END) as avg_order_value,
    
    -- Customer metrics
    COUNT(DISTINCT o.consumer_id) as unique_customers,
    
    -- Product metrics
    COUNT(DISTINCT oc.commodity_id) as unique_products_sold,
    SUM(oc.quantity) as total_items_sold,
    
    -- Geographic diversity
    COUNT(DISTINCT o.delivery_country) as countries_served,
    COUNT(DISTINCT o.delivery_city) as cities_served
FROM orders o
JOIN order_commodities oc ON o.id = oc.order_id
GROUP BY 1, 2, 3, 4
ORDER BY 1 DESC, 2 DESC;

-- Test the view
SELECT * FROM v_quarterly_trends;

-- QoQ (Quarter-over-Quarter) comparison
WITH quarterly_data AS (
    SELECT * FROM v_quarterly_trends
)
SELECT 
    q1.quarter_label,
    q1.total_revenue as current_quarter_revenue,
    q2.quarter_label as prev_quarter_label,
    q2.total_revenue as prev_quarter_revenue,
    ROUND(
        ((q1.total_revenue - q2.total_revenue) / NULLIF(q2.total_revenue, 0) * 100)::NUMERIC,
        2
    ) as qoq_growth_pct
FROM quarterly_data q1
LEFT JOIN quarterly_data q2 
    ON q1.year = q2.year 
    AND q1.quarter = q2.quarter + 1
ORDER BY q1.year DESC, q1.quarter DESC;

-- ============================================================================
-- VIEW 5: Temporal Patterns (Day of Week & Hour Analysis)
-- ============================================================================
CREATE OR REPLACE VIEW v_temporal_patterns AS
SELECT 
    EXTRACT(DOW FROM created_at) as day_of_week_num,
    CASE EXTRACT(DOW FROM created_at)
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END as day_of_week_name,
    EXTRACT(HOUR FROM created_at) as hour_of_day,
    
    -- Order metrics
    COUNT(DISTINCT id) as order_count,
    
    -- Revenue metrics
    SUM(CASE WHEN status IN ('delivered', 'done') 
        THEN total_amount ELSE 0 END) as total_revenue,
    AVG(CASE WHEN status IN ('delivered', 'done') 
        THEN total_amount END) as avg_order_value,
    
    -- Completion rate
    ROUND(
        COUNT(DISTINCT CASE WHEN status IN ('delivered', 'done') THEN id END)::DECIMAL 
        / NULLIF(COUNT(DISTINCT id), 0) * 100,
        2
    ) as completion_rate_pct
FROM orders
GROUP BY 
    EXTRACT(DOW FROM created_at),
    EXTRACT(HOUR FROM created_at)
ORDER BY 1, 3;

-- Peak hours analysis
SELECT 
    hour_of_day,
    SUM(order_count) as total_orders,
    SUM(total_revenue) as total_revenue,
    ROUND(AVG(avg_order_value)::NUMERIC, 2) as avg_order_value
FROM v_temporal_patterns
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10;

-- Best performing days
SELECT 
    day_of_week_name,
    day_of_week_num,
    SUM(order_count) as total_orders,
    SUM(total_revenue) as total_revenue
FROM v_temporal_patterns
GROUP BY 1, 2
ORDER BY 4 DESC;

-- ============================================================================
-- VIEW 6: Customer Segment Revenue Analysis
-- ============================================================================
CREATE OR REPLACE VIEW v_segment_revenue_analysis AS
SELECT 
    c.customer_segment,
    DATE_TRUNC('month', o.created_at) as month,
    
    -- Customer metrics
    COUNT(DISTINCT c.id) as unique_customers,
    
    -- Order metrics
    COUNT(DISTINCT o.id) as total_orders,
    ROUND(COUNT(DISTINCT o.id)::DECIMAL / NULLIF(COUNT(DISTINCT c.id), 0), 2) as orders_per_customer,
    
    -- Revenue metrics
    SUM(CASE WHEN o.status IN ('delivered', 'done') 
        THEN o.total_amount ELSE 0 END) as total_revenue,
    ROUND(
        SUM(CASE WHEN o.status IN ('delivered', 'done') THEN o.total_amount ELSE 0 END)::DECIMAL 
        / NULLIF(COUNT(DISTINCT c.id), 0),
        2
    ) as revenue_per_customer,
    ROUND(AVG(CASE WHEN o.status IN ('delivered', 'done') THEN o.total_amount END)::NUMERIC, 2) as avg_order_value
FROM consumers c
JOIN orders o ON c.id = o.consumer_id
GROUP BY 1, 2
ORDER BY 2 DESC, 4 DESC;

-- Test the view
SELECT * FROM v_segment_revenue_analysis WHERE month >= DATEADD(month, -12, GETDATE());

-- ============================================================================
-- VIEW 7: Top Products by Revenue (Monthly)
-- ============================================================================
CREATE OR REPLACE VIEW v_top_products_monthly AS
SELECT 
    DATE_TRUNC('month', o.created_at) as month,
    TO_CHAR(o.created_at, 'Mon YYYY') as month_label,
    c.id as commodity_id,
    c.name as product_name,
    v.name as category,
    
    -- Sales metrics
    COUNT(DISTINCT o.id) as order_count,
    SUM(oc.quantity) as units_sold,
    SUM(oc.line_total) as total_revenue,
    ROUND(AVG(oc.unit_price)::NUMERIC, 2) as avg_selling_price,
    
    -- Ranking
    RANK() OVER (PARTITION BY DATE_TRUNC('month', o.created_at) ORDER BY SUM(oc.line_total) DESC) as revenue_rank
FROM orders o
JOIN order_commodities oc ON o.id = oc.order_id
JOIN commodities c ON oc.commodity_id = c.id
JOIN verticals v ON c.vertical_id = v.id
WHERE o.status IN ('delivered', 'done')
GROUP BY 1, 2, 3, 4, 5
ORDER BY 1 DESC, 8 DESC;

-- Top 10 products this month
SELECT * 
FROM v_top_products_monthly 
WHERE month = DATE_TRUNC('month', GETDATE())
    AND revenue_rank <= 10
ORDER BY revenue_rank;

-- ============================================================================
-- COMPREHENSIVE DASHBOARD SUMMARY VIEW
-- ============================================================================
CREATE OR REPLACE VIEW v_dashboard_summary AS
WITH current_month AS (
    SELECT * FROM v_monthly_revenue 
    WHERE month = DATE_TRUNC('month', GETDATE())
),
previous_month AS (
    SELECT * FROM v_monthly_revenue 
    WHERE month = DATEADD(month, -1, DATE_TRUNC('month', GETDATE()))
),
same_month_last_year AS (
    SELECT * FROM v_monthly_revenue 
    WHERE month = DATEADD(year, -1, DATE_TRUNC('month', GETDATE()))
)
SELECT 
    -- Current month metrics
    cm.total_revenue as current_month_revenue,
    cm.total_orders as current_month_orders,
    cm.avg_order_value as current_month_aov,
    cm.unique_customers as current_month_customers,
    
    -- MoM comparison
    pm.total_revenue as previous_month_revenue,
    ROUND(
        ((cm.total_revenue - pm.total_revenue) / NULLIF(pm.total_revenue, 0) * 100)::NUMERIC,
        2
    ) as mom_revenue_growth_pct,
    
    -- YoY comparison
    ly.total_revenue as same_month_last_year_revenue,
    ROUND(
        ((cm.total_revenue - ly.total_revenue) / NULLIF(ly.total_revenue, 0) * 100)::NUMERIC,
        2
    ) as yoy_revenue_growth_pct,
    
    -- Year-to-date
    (SELECT SUM(total_revenue) FROM v_monthly_revenue 
     WHERE year = EXTRACT(YEAR FROM GETDATE())) as ytd_revenue,
    
    -- Last 12 months total
    (SELECT SUM(total_revenue) FROM v_monthly_revenue 
     WHERE month >= DATEADD(month, -12, GETDATE())) as trailing_12m_revenue
FROM current_month cm
CROSS JOIN previous_month pm
CROSS JOIN same_month_last_year ly;

-- Test the summary
SELECT * FROM v_dashboard_summary;

-- ============================================================================
-- VERIFICATION & TESTING
-- ============================================================================

-- List all created views
SELECT 
    table_name as view_name,
    'View' as object_type
FROM information_schema.views
WHERE table_schema = 'public'
    AND table_name LIKE 'v_%'
ORDER BY table_name;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================
SELECT 
    '🎉 All revenue analytics views created successfully!' as status,
    '7 views ready for QuickSight' as views_created,
    'v_monthly_revenue, v_yoy_revenue_comparison, v_mom_revenue_comparison' as key_views,
    'Connect these views in QuickSight for dashboard' as next_step;

-- ============================================================================
-- NOTEBOOK 1: REVENUE ANALYSIS (YoY & MoM)
-- Business Objective: Track revenue trends, growth patterns, and business health
-- QuickSight Compatibility: All views optimized for SPICE import
-- Free Tier Considerations: Uses aggregated views to minimize query costs
-- ============================================================================

-- ============================================================================
-- SECTION 1: DATA VALIDATION
-- Verify data completeness before creating views
-- ============================================================================

-- Check date range of available data
SELECT 
    MIN(created_at) as earliest_order,
    MAX(created_at) as latest_order,
    COUNT(*) as total_orders,
    COUNT(DISTINCT consumer_id) as unique_customers,
    SUM(CASE WHEN status IN ('delivered', 'done') THEN 1 ELSE 0 END) as completed_orders,
    ROUND(SUM(CASE WHEN status IN ('delivered', 'done') THEN total_amount ELSE 0 END)::NUMERIC, 2) as total_revenue
FROM orders;

-- Expected output: Date range, order counts, revenue summary
-- QuickSight Usage: Not needed - validation only

-- ============================================================================
-- SECTION 2: MONTHLY REVENUE SUMMARY VIEW
-- Core view for all MoM and trend analysis
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
    
    -- Revenue metrics (only completed orders)
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

-- Expected output: One row per month with revenue KPIs
-- QuickSight Usage: Import to SPICE as "Monthly Revenue" dataset
-- Visualizations: Line chart (total_revenue by month_label), KPI cards

-- Test the view
SELECT * FROM v_monthly_revenue ORDER BY month DESC LIMIT 12;

-- ============================================================================
-- SECTION 3: YEAR-OVER-YEAR (YoY) COMPARISON VIEW
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
WHERE m2.year IS NOT NULL
ORDER BY m1.year DESC, m1.month_num DESC;

-- Expected output: Side-by-side year comparison with growth percentages
-- QuickSight Usage: Import as "YoY Comparison" dataset
-- Visualizations: Combo chart (current vs previous year revenue), Table (growth metrics)

-- Test the view
SELECT * FROM v_yoy_revenue_comparison LIMIT 12;

-- ============================================================================
-- SECTION 4: MONTH-OVER-MONTH (MoM) COMPARISON VIEW
-- Sequential month comparison with growth indicators
-- ============================================================================

CREATE OR REPLACE VIEW v_mom_revenue_comparison AS
WITH monthly_data AS (
    SELECT * FROM v_monthly_revenue
),
with_previous AS (
    SELECT 
        *,
        LAG(month_label, 1) OVER (ORDER BY month) as prev_month_label,
        LAG(total_revenue, 1) OVER (ORDER BY month) as prev_month_revenue,
        LAG(total_orders, 1) OVER (ORDER BY month) as prev_month_orders,
        LAG(unique_customers, 1) OVER (ORDER BY month) as prev_month_customers,
        LAG(avg_order_value, 1) OVER (ORDER BY month) as prev_month_aov,
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
WHERE prev_month_revenue IS NOT NULL
ORDER BY month DESC;

-- Expected output: Monthly progression with MoM growth rates
-- QuickSight Usage: Import as "MoM Comparison" dataset
-- Visualizations: Line chart with dual axis (revenue + growth %), Waterfall chart

-- Test the view
SELECT * FROM v_mom_revenue_comparison ORDER BY month DESC LIMIT 12;

-- ============================================================================
-- SECTION 5: QUARTERLY TRENDS VIEW
-- Seasonal analysis and QoQ comparison
-- ============================================================================

CREATE OR REPLACE VIEW v_quarterly_trends AS
SELECT 
    EXTRACT(YEAR FROM o.created_at) as year,
    EXTRACT(QUARTER FROM o.created_at) as quarter,
    'Q' || EXTRACT(QUARTER FROM o.created_at) || ' ' || EXTRACT(YEAR FROM o.created_at) as quarter_label,
    DATE_TRUNC('quarter', o.created_at) as quarter_start_date,
    
    -- Order metrics
    COUNT(DISTINCT o.id) as total_orders,
    COUNT(DISTINCT CASE WHEN o.status IN ('delivered', 'done') THEN o.id END) as completed_orders,
    
    -- Revenue metrics
    ROUND(SUM(CASE WHEN o.status IN ('delivered', 'done') 
        THEN o.total_amount ELSE 0 END)::NUMERIC, 2) as total_revenue,
    ROUND(AVG(CASE WHEN o.status IN ('delivered', 'done') 
        THEN o.total_amount END)::NUMERIC, 2) as avg_order_value,
    
    -- Product metrics
    COUNT(DISTINCT oc.commodity_id) as unique_products_sold,
    SUM(oc.quantity) as total_units_sold,
    
    -- Customer metrics
    COUNT(DISTINCT o.consumer_id) as unique_customers,
    COUNT(DISTINCT o.delivery_city) as cities_served
FROM orders o
JOIN order_commodities oc ON o.id = oc.order_id
GROUP BY 1, 2, 3, 4
ORDER BY 1 DESC, 2 DESC;

-- Expected output: Quarterly aggregated metrics
-- QuickSight Usage: Import as "Quarterly Trends" dataset
-- Visualizations: Bar chart (revenue by quarter), Heatmap (seasonality)

-- Test the view
SELECT * FROM v_quarterly_trends;

-- QoQ Growth Analysis
WITH quarterly_data AS (
    SELECT * FROM v_quarterly_trends
)
SELECT 
    q1.quarter_label,
    q1.total_revenue as current_quarter_revenue,
    q2.total_revenue as previous_quarter_revenue,
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
-- SECTION 6: COMPREHENSIVE DASHBOARD SUMMARY
-- Single-row KPI summary for dashboard header
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
    cm.month_label as current_month,
    cm.total_revenue as current_month_revenue,
    cm.total_orders as current_month_orders,
    cm.unique_customers as current_month_customers,
    cm.avg_order_value as current_month_aov,
    
    -- MoM comparison
    ROUND(
        ((cm.total_revenue - pm.total_revenue) / NULLIF(pm.total_revenue, 0) * 100)::NUMERIC,
        2
    ) as mom_revenue_growth_pct,
    
    -- YoY comparison
    ROUND(
        ((cm.total_revenue - ly.total_revenue) / NULLIF(ly.total_revenue, 0) * 100)::NUMERIC,
        2
    ) as yoy_revenue_growth_pct,
    
    -- Status indicator
    CASE 
        WHEN ((cm.total_revenue - pm.total_revenue) / NULLIF(pm.total_revenue, 0) * 100) > 5 
            THEN '🟢 Strong Growth'
        WHEN ((cm.total_revenue - pm.total_revenue) / NULLIF(pm.total_revenue, 0) * 100) > 0 
            THEN '🟡 Moderate Growth'
        ELSE '🔴 Declining'
    END as health_status
FROM current_month cm
CROSS JOIN previous_month pm
CROSS JOIN same_month_last_year ly;

-- Expected output: Single row with KPIs
-- QuickSight Usage: Import as "Dashboard KPIs" dataset
-- Visualizations: KPI cards across top of dashboard

-- Test the summary
SELECT * FROM v_dashboard_summary;

-- ============================================================================
-- SECTION 7: VERIFICATION & FREE TIER OPTIMIZATION
-- ============================================================================

-- List all created views
SELECT 
    table_name as view_name,
    'View' as object_type
FROM information_schema.views
WHERE table_schema = 'public'
    AND table_name LIKE 'v_%revenue%'
    OR table_name LIKE 'v_%dashboard%'
    OR table_name LIKE 'v_%quarterly%'
    OR table_name LIKE 'v_%mom%'
    OR table_name LIKE 'v_%yoy%'
ORDER BY table_name;

-- Estimate row counts for SPICE import
SELECT 
    'v_monthly_revenue' as view_name,
    COUNT(*) as estimated_rows
FROM v_monthly_revenue
UNION ALL
SELECT 
    'v_yoy_revenue_comparison',
    COUNT(*)
FROM v_yoy_revenue_comparison
UNION ALL
SELECT 
    'v_mom_revenue_comparison',
    COUNT(*)
FROM v_mom_revenue_comparison
UNION ALL
SELECT 
    'v_quarterly_trends',
    COUNT(*)
FROM v_quarterly_trends
UNION ALL
SELECT 
    'v_dashboard_summary',
    COUNT(*)
FROM v_dashboard_summary;

-- ============================================================================
-- QUICKSIGHT IMPORT RECOMMENDATIONS
-- ============================================================================

/*
FREE TIER OPTIMIZATION TIPS:
1. Import these views to SPICE (not direct query) to minimize Redshift compute
2. Schedule SPICE refresh daily (not real-time) during off-peak hours
3. Row counts should be minimal (< 1000 rows per view) - perfect for free tier
4. Total SPICE usage: ~5KB - well within 10GB free tier limit

DATASET IMPORT ORDER:
1. v_monthly_revenue (Primary dataset - 12-24 rows)
2. v_mom_revenue_comparison (12-23 rows)
3. v_yoy_revenue_comparison (12-24 rows)
4. v_quarterly_trends (8-12 rows)
5. v_dashboard_summary (1 row - KPI cards)

VISUALIZATION RECOMMENDATIONS:
Dashboard: "Revenue Performance Overview"
├── KPI Cards (v_dashboard_summary):
│   ├── Current Month Revenue
│   ├── MoM Growth %
│   ├── YoY Growth %
│   └── Health Status
├── Line Chart (v_monthly_revenue):
│   ├── X-axis: month_label
│   ├── Y-axis: total_revenue
│   └── Tooltip: total_orders, avg_order_value
├── Combo Chart (v_mom_revenue_comparison):
│   ├── X-axis: month_label
│   ├── Primary Y-axis: total_revenue (bars)
│   └── Secondary Y-axis: revenue_growth_pct (line)
├── Pivot Table (v_yoy_revenue_comparison):
│   ├── Rows: month_name
│   ├── Columns: current_year, previous_year
│   └── Values: revenue, orders, growth_pct
└── Bar Chart (v_quarterly_trends):
    ├── X-axis: quarter_label
    ├── Y-axis: total_revenue
    └── Color: year

FILTERS TO ADD:
- Date range filter (month >= DATEADD(month, -12, GETDATE()))
- Year selector (for YoY comparison)
- Status toggle (show all vs completed only)
*/

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================
SELECT 
    '✅ Revenue Analysis Views Created Successfully' as status,
    '5 views ready for QuickSight import' as views_created,
    'All optimized for Free Tier usage' as optimization,
    'Proceed to QuickSight dataset creation' as next_step;

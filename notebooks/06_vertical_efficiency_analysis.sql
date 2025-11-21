-- ============================================================================
-- NOTEBOOK 6: VERTICAL EFFICIENCY ANALYSIS
-- Business Objective: Track category performance, identify trends, optimize product mix
-- QuickSight Compatibility: Optimized for category comparison and trend analysis
-- Free Tier Considerations: Aggregated by vertical, minimal data volume
-- ============================================================================

-- ============================================================================
-- SECTION 1: DATA VALIDATION
-- Verify vertical (category) data completeness
-- ============================================================================

-- Check vertical coverage
SELECT 
    COUNT(*) as total_verticals,
    COUNT(CASE WHEN status = 'active' THEN 1 END) as active_verticals,
    COUNT(CASE WHEN level = 1 THEN 1 END) as top_level_categories,
    COUNT(CASE WHEN level = 2 THEN 1 END) as subcategories
FROM verticals;

-- Expected output: Vertical hierarchy metrics
-- QuickSight Usage: Not needed - validation only

-- Check category-product distribution
SELECT 
    v.name as vertical_name,
    COUNT(DISTINCT c.id) as product_count,
    COUNT(DISTINCT c.seller_id) as seller_count
FROM verticals v
LEFT JOIN commodities c ON v.id = c.vertical_id
WHERE v.status = 'active'
GROUP BY v.name
ORDER BY product_count DESC
LIMIT 10;

-- ============================================================================
-- SECTION 2: VERTICAL REVENUE PERFORMANCE
-- Track sales and revenue by category
-- ============================================================================

CREATE OR REPLACE VIEW v_vertical_revenue_performance AS
WITH vertical_sales AS (
    SELECT 
        c.vertical_id,
        COUNT(DISTINCT oc.order_id) as total_orders,
        SUM(oc.quantity) as total_units_sold,
        SUM(oc.line_total) as total_revenue,
        AVG(oc.unit_price) as avg_selling_price,
        COUNT(DISTINCT c.id) as products_sold,
        COUNT(DISTINCT o.consumer_id) as unique_customers
    FROM order_commodities oc
    JOIN commodities c ON oc.commodity_id = c.id
    JOIN orders o ON oc.order_id = o.id
    WHERE o.status IN ('delivered', 'done')
    GROUP BY c.vertical_id
),
vertical_sales_30d AS (
    SELECT 
        c.vertical_id,
        SUM(oc.quantity) as units_sold_30d,
        SUM(oc.line_total) as revenue_30d,
        COUNT(DISTINCT oc.order_id) as orders_30d
    FROM order_commodities oc
    JOIN commodities c ON oc.commodity_id = c.id
    JOIN orders o ON oc.order_id = o.id
    WHERE o.created_at >= DATEADD(day, -30, GETDATE())
        AND o.status IN ('delivered', 'done')
    GROUP BY c.vertical_id
),
vertical_inventory AS (
    SELECT 
        c.vertical_id,
        COUNT(DISTINCT c.id) as total_products,
        COUNT(DISTINCT CASE WHEN c.status = 'available' THEN c.id END) as available_products,
        SUM(c.quantity) as total_stock,
        SUM(c.quantity * c.price) as inventory_value,
        AVG(c.rating_avg) as avg_product_rating,
        SUM(c.review_count) as total_reviews
    FROM commodities c
    GROUP BY c.vertical_id
)
SELECT 
    v.id as vertical_id,
    v.name as vertical_name,
    v.level as vertical_level,
    COALESCE(pv.name, 'Top Level') as parent_vertical_name,
    v.status as vertical_status,
    
    -- Product metrics
    COALESCE(vi.total_products, 0) as total_products,
    COALESCE(vi.available_products, 0) as available_products,
    COALESCE(vi.total_stock, 0) as total_stock,
    ROUND(COALESCE(vi.inventory_value, 0)::NUMERIC, 2) as inventory_value,
    
    -- Sales metrics (lifetime)
    COALESCE(vs.total_orders, 0) as total_orders,
    COALESCE(vs.total_units_sold, 0) as total_units_sold,
    ROUND(COALESCE(vs.total_revenue, 0)::NUMERIC, 2) as total_revenue,
    ROUND(COALESCE(vs.avg_selling_price, 0)::NUMERIC, 2) as avg_selling_price,
    COALESCE(vs.products_sold, 0) as products_sold,
    COALESCE(vs.unique_customers, 0) as unique_customers,
    
    -- Recent performance (30 days)
    COALESCE(vs30.units_sold_30d, 0) as units_sold_30d,
    ROUND(COALESCE(vs30.revenue_30d, 0)::NUMERIC, 2) as revenue_30d,
    COALESCE(vs30.orders_30d, 0) as orders_30d,
    
    -- Performance metrics
    ROUND(
        (COALESCE(vs.total_revenue, 0) / NULLIF(COALESCE(vi.total_products, 0), 0))::NUMERIC,
        2
    ) as revenue_per_product,
    ROUND(
        (COALESCE(vs.total_units_sold, 0)::DECIMAL / NULLIF(COALESCE(vi.total_products, 0), 0))::NUMERIC,
        2
    ) as units_sold_per_product,
    ROUND(
        (COALESCE(vs.products_sold, 0)::DECIMAL / NULLIF(COALESCE(vi.total_products, 0), 0) * 100)::NUMERIC,
        2
    ) as product_penetration_pct,
    
    -- Inventory turnover (annualized estimate)
    ROUND(
        CASE 
            WHEN COALESCE(vi.inventory_value, 0) > 0
            THEN (COALESCE(vs30.revenue_30d, 0) * 12 / NULLIF(COALESCE(vi.inventory_value, 0), 0))
            ELSE 0
        END::NUMERIC,
        2
    ) as inventory_turnover_ratio,
    
    -- Quality metrics
    ROUND(COALESCE(vi.avg_product_rating, 0)::NUMERIC, 2) as avg_product_rating,
    COALESCE(vi.total_reviews, 0) as total_reviews,
    
    -- Performance tier
    CASE 
        WHEN COALESCE(vs.total_revenue, 0) >= 100000 THEN '🏆 Top Performer (>$100K)'
        WHEN COALESCE(vs.total_revenue, 0) >= 50000 THEN '⭐ High Performer ($50K-$100K)'
        WHEN COALESCE(vs.total_revenue, 0) >= 10000 THEN '✅ Medium Performer ($10K-$50K)'
        WHEN COALESCE(vs.total_revenue, 0) > 0 THEN '📦 Low Performer (<$10K)'
        ELSE '⚠️ No Sales'
    END as performance_tier,
    
    -- Growth indicator
    CASE 
        WHEN COALESCE(vs30.revenue_30d, 0) > (COALESCE(vs.total_revenue, 0) / 12.0) 
            THEN '📈 Above Average Growth'
        WHEN COALESCE(vs30.revenue_30d, 0) > (COALESCE(vs.total_revenue, 0) / 24.0) 
            THEN '📊 Average Growth'
        WHEN COALESCE(vs30.revenue_30d, 0) > 0 
            THEN '📉 Below Average Growth'
        ELSE '🚫 No Recent Sales'
    END as growth_indicator,
    
    -- Rankings
    RANK() OVER (ORDER BY COALESCE(vs.total_revenue, 0) DESC) as revenue_rank,
    RANK() OVER (ORDER BY COALESCE(vs.total_units_sold, 0) DESC) as volume_rank,
    RANK() OVER (ORDER BY COALESCE(vi.avg_product_rating, 0) DESC NULLS LAST) as quality_rank
FROM verticals v
LEFT JOIN verticals pv ON v.parent_id = pv.id
LEFT JOIN vertical_sales vs ON v.id = vs.vertical_id
LEFT JOIN vertical_sales_30d vs30 ON v.id = vs30.vertical_id
LEFT JOIN vertical_inventory vi ON v.id = vi.vertical_id
WHERE v.status = 'active'
ORDER BY COALESCE(vs.total_revenue, 0) DESC;

-- Expected output: ~39 rows (one per active vertical)
-- QuickSight Usage: Import as "Vertical Performance" dataset
-- Visualizations: Treemap (revenue by vertical), Bar chart (top categories)

-- Test the view - Top 10 categories
SELECT * FROM v_vertical_revenue_performance ORDER BY total_revenue DESC LIMIT 10;

-- Test the view - Underperforming categories
SELECT * FROM v_vertical_revenue_performance 
WHERE performance_tier IN ('📦 Low Performer (<$10K)', '⚠️ No Sales')
ORDER BY total_products DESC;

-- ============================================================================
-- SECTION 3: VERTICAL TRENDS OVER TIME
-- Track category performance month-over-month
-- ============================================================================

CREATE OR REPLACE VIEW v_vertical_revenue_trends AS
SELECT 
    DATE_TRUNC('month', o.created_at) as month,
    TO_CHAR(o.created_at, 'YYYY-MM') as year_month,
    v.id as vertical_id,
    v.name as vertical_name,
    v.level as vertical_level,
    
    -- Monthly metrics
    COUNT(DISTINCT oc.order_id) as total_orders,
    SUM(oc.quantity) as total_units_sold,
    ROUND(SUM(oc.line_total)::NUMERIC, 2) as total_revenue,
    ROUND(AVG(oc.unit_price)::NUMERIC, 2) as avg_selling_price,
    COUNT(DISTINCT c.id) as products_sold,
    COUNT(DISTINCT o.consumer_id) as unique_customers,
    
    -- Average order metrics
    ROUND((SUM(oc.line_total) / NULLIF(COUNT(DISTINCT oc.order_id), 0))::NUMERIC, 2) as avg_revenue_per_order,
    ROUND((SUM(oc.quantity)::DECIMAL / NULLIF(COUNT(DISTINCT oc.order_id), 0))::NUMERIC, 2) as avg_units_per_order
FROM orders o
JOIN order_commodities oc ON o.id = oc.order_id
JOIN commodities c ON oc.commodity_id = c.id
JOIN verticals v ON c.vertical_id = v.id
WHERE o.status IN ('delivered', 'done')
    AND v.status = 'active'
GROUP BY 1, 2, 3, 4, 5
ORDER BY 1 DESC, 6 DESC;

-- Expected output: ~468 rows (12 months × 39 verticals)
-- QuickSight Usage: Import as "Vertical Trends" dataset
-- Visualizations: Line chart (revenue by category over time), Area chart (stacked)

-- Test the view - Last 6 months
SELECT * FROM v_vertical_revenue_trends 
WHERE month >= DATEADD(month, -6, GETDATE())
ORDER BY month DESC, total_revenue DESC
LIMIT 50;

-- ============================================================================
-- SECTION 4: VERTICAL MARKET SHARE ANALYSIS
-- Calculate each category's share of total business
-- ============================================================================

CREATE OR REPLACE VIEW v_vertical_market_share AS
WITH vertical_metrics AS (
    SELECT 
        v.id as vertical_id,
        v.name as vertical_name,
        SUM(oc.line_total) as total_revenue,
        SUM(oc.quantity) as total_units_sold,
        COUNT(DISTINCT oc.order_id) as total_orders
    FROM verticals v
    JOIN commodities c ON v.id = c.vertical_id
    JOIN order_commodities oc ON c.id = oc.commodity_id
    JOIN orders o ON oc.order_id = o.id
    WHERE o.status IN ('delivered', 'done')
        AND v.status = 'active'
    GROUP BY v.id, v.name
),
total_metrics AS (
    SELECT 
        SUM(total_revenue) as overall_revenue,
        SUM(total_units_sold) as overall_units,
        SUM(total_orders) as overall_orders
    FROM vertical_metrics
)
SELECT 
    vm.vertical_id,
    vm.vertical_name,
    ROUND(vm.total_revenue::NUMERIC, 2) as total_revenue,
    vm.total_units_sold,
    vm.total_orders,
    
    -- Market share calculations
    ROUND((vm.total_revenue / NULLIF(tm.overall_revenue, 0) * 100)::NUMERIC, 2) as revenue_market_share_pct,
    ROUND((vm.total_units_sold::DECIMAL / NULLIF(tm.overall_units, 0) * 100)::NUMERIC, 2) as volume_market_share_pct,
    ROUND((vm.total_orders::DECIMAL / NULLIF(tm.overall_orders, 0) * 100)::NUMERIC, 2) as order_market_share_pct,
    
    -- Cumulative market share
    ROUND(
        (SUM(vm.total_revenue) OVER (ORDER BY vm.total_revenue DESC) 
        / NULLIF(tm.overall_revenue, 0) * 100)::NUMERIC,
        2
    ) as cumulative_revenue_share_pct,
    
    -- Market share tier
    CASE 
        WHEN (vm.total_revenue / NULLIF(tm.overall_revenue, 0) * 100) >= 10 
            THEN '🔥 Dominant Category (≥10%)'
        WHEN (vm.total_revenue / NULLIF(tm.overall_revenue, 0) * 100) >= 5 
            THEN '⭐ Major Category (5-10%)'
        WHEN (vm.total_revenue / NULLIF(tm.overall_revenue, 0) * 100) >= 2 
            THEN '✅ Mid-Tier Category (2-5%)'
        ELSE '📦 Niche Category (<2%)'
    END as market_share_tier,
    
    -- Concentration indicator (for 80/20 rule)
    CASE 
        WHEN SUM(vm.total_revenue) OVER (ORDER BY vm.total_revenue DESC) 
            / NULLIF(tm.overall_revenue, 0) <= 0.80 
            THEN '🎯 Top 80% Revenue Generator'
        ELSE '📊 Long Tail Category'
    END as pareto_classification,
    
    -- Rankings
    RANK() OVER (ORDER BY vm.total_revenue DESC) as revenue_rank
FROM vertical_metrics vm
CROSS JOIN total_metrics tm
ORDER BY vm.total_revenue DESC;

-- Expected output: ~39 rows (one per vertical)
-- QuickSight Usage: Import as "Vertical Market Share" dataset
-- Visualizations: Pie/Donut chart (market share), Pareto chart (80/20 rule)

-- Test the view
SELECT * FROM v_vertical_market_share ORDER BY total_revenue DESC;

-- Test the view - 80/20 analysis
SELECT 
    pareto_classification,
    COUNT(*) as category_count,
    ROUND(SUM(total_revenue)::NUMERIC, 2) as combined_revenue,
    ROUND(SUM(revenue_market_share_pct)::NUMERIC, 2) as combined_market_share_pct
FROM v_vertical_market_share
GROUP BY pareto_classification;

-- ============================================================================
-- SECTION 5: VERTICAL PRODUCT MIX EFFICIENCY
-- Analyze product diversity and efficiency within categories
-- ============================================================================

CREATE OR REPLACE VIEW v_vertical_product_mix_efficiency AS
WITH vertical_product_stats AS (
    SELECT 
        c.vertical_id,
        COUNT(DISTINCT c.id) as total_products,
        COUNT(DISTINCT CASE WHEN c.status = 'available' THEN c.id END) as available_products,
        COUNT(DISTINCT CASE WHEN c.quantity > 0 THEN c.id END) as in_stock_products,
        COUNT(DISTINCT CASE WHEN c.total_sold > 0 THEN c.id END) as products_with_sales,
        AVG(c.price) as avg_product_price,
        STDDEV(c.price) as price_std_dev,
        MIN(c.price) as min_price,
        MAX(c.price) as max_price
    FROM commodities c
    GROUP BY c.vertical_id
),
vertical_seller_diversity AS (
    SELECT 
        c.vertical_id,
        COUNT(DISTINCT c.seller_id) as unique_sellers,
        COUNT(DISTINCT sv.vertical_id) as seller_commitments
    FROM commodities c
    LEFT JOIN seller_vertical sv ON c.seller_id = sv.seller_id AND c.vertical_id = sv.vertical_id
    GROUP BY c.vertical_id
)
SELECT 
    v.id as vertical_id,
    v.name as vertical_name,
    
    -- Product mix metrics
    vps.total_products,
    vps.available_products,
    vps.in_stock_products,
    vps.products_with_sales,
    ROUND(
        (vps.products_with_sales::DECIMAL / NULLIF(vps.total_products, 0) * 100)::NUMERIC,
        2
    ) as product_sales_penetration_pct,
    
    -- Seller diversity
    vsd.unique_sellers,
    ROUND(
        (vps.total_products::DECIMAL / NULLIF(vsd.unique_sellers, 0))::NUMERIC,
        2
    ) as products_per_seller,
    
    -- Price range analysis
    ROUND(vps.avg_product_price::NUMERIC, 2) as avg_product_price,
    ROUND(vps.price_std_dev::NUMERIC, 2) as price_std_dev,
    ROUND(vps.min_price::NUMERIC, 2) as min_price,
    ROUND(vps.max_price::NUMERIC, 2) as max_price,
    ROUND((vps.max_price - vps.min_price)::NUMERIC, 2) as price_range,
    ROUND(
        (vps.price_std_dev / NULLIF(vps.avg_product_price, 0) * 100)::NUMERIC,
        2
    ) as price_coefficient_of_variation_pct,
    
    -- Mix efficiency indicators
    CASE 
        WHEN vps.products_with_sales::DECIMAL / NULLIF(vps.total_products, 0) >= 0.7 
            THEN '🟢 Efficient Mix (≥70% products selling)'
        WHEN vps.products_with_sales::DECIMAL / NULLIF(vps.total_products, 0) >= 0.5 
            THEN '🟡 Moderate Efficiency (50-70%)'
        WHEN vps.products_with_sales::DECIMAL / NULLIF(vps.total_products, 0) >= 0.3 
            THEN '🟠 Low Efficiency (30-50%)'
        ELSE '🔴 Very Low Efficiency (<30%)'
    END as mix_efficiency_status,
    
    CASE 
        WHEN vps.price_std_dev / NULLIF(vps.avg_product_price, 0) > 1.0 
            THEN '📊 High Price Diversity'
        WHEN vps.price_std_dev / NULLIF(vps.avg_product_price, 0) > 0.5 
            THEN '📈 Moderate Price Diversity'
        ELSE '📉 Low Price Diversity'
    END as price_diversity_status,
    
    CASE 
        WHEN vsd.unique_sellers >= 20 THEN '🌟 High Seller Competition'
        WHEN vsd.unique_sellers >= 10 THEN '✅ Good Seller Competition'
        WHEN vsd.unique_sellers >= 5 THEN '⚠️ Limited Competition'
        ELSE '🔴 Low Competition'
    END as competition_status
FROM verticals v
JOIN vertical_product_stats vps ON v.id = vps.vertical_id
JOIN vertical_seller_diversity vsd ON v.id = vsd.vertical_id
WHERE v.status = 'active'
ORDER BY vps.total_products DESC;

-- Expected output: ~39 rows (one per vertical)
-- QuickSight Usage: Import as "Vertical Product Mix" dataset
-- Visualizations: Scatter plot (products vs efficiency), Box plot (price distribution)

-- Test the view
SELECT * FROM v_vertical_product_mix_efficiency ORDER BY total_products DESC;

-- Test the view - Inefficient categories
SELECT * FROM v_vertical_product_mix_efficiency 
WHERE mix_efficiency_status LIKE '%Low Efficiency%'
ORDER BY product_sales_penetration_pct ASC;

-- ============================================================================
-- SECTION 6: VERTICAL PROFITABILITY ANALYSIS
-- Calculate profit margins and contribution by category
-- ============================================================================

CREATE OR REPLACE VIEW v_vertical_profitability_analysis AS
WITH vertical_financials AS (
    SELECT 
        c.vertical_id,
        SUM(oc.quantity * c.price) as total_revenue,
        SUM(oc.quantity * c.cost_price) as total_cost,
        SUM(oc.quantity * (c.price - c.cost_price)) as total_profit,
        COUNT(DISTINCT oc.order_id) as total_orders
    FROM order_commodities oc
    JOIN commodities c ON oc.commodity_id = c.id
    JOIN orders o ON oc.order_id = o.id
    WHERE o.status IN ('delivered', 'done')
    GROUP BY c.vertical_id
),
overall_financials AS (
    SELECT 
        SUM(total_revenue) as overall_revenue,
        SUM(total_profit) as overall_profit
    FROM vertical_financials
)
SELECT 
    v.id as vertical_id,
    v.name as vertical_name,
    
    -- Financial metrics
    ROUND(COALESCE(vf.total_revenue, 0)::NUMERIC, 2) as total_revenue,
    ROUND(COALESCE(vf.total_cost, 0)::NUMERIC, 2) as total_cost,
    ROUND(COALESCE(vf.total_profit, 0)::NUMERIC, 2) as total_profit,
    
    -- Margin calculations
    ROUND(
        (COALESCE(vf.total_profit, 0) / NULLIF(COALESCE(vf.total_revenue, 0), 0) * 100)::NUMERIC,
        2
    ) as profit_margin_pct,
    ROUND(
        (COALESCE(vf.total_profit, 0) / NULLIF(COALESCE(vf.total_orders, 0), 0))::NUMERIC,
        2
    ) as profit_per_order,
    
    -- Contribution to business
    ROUND(
        (COALESCE(vf.total_revenue, 0) / NULLIF(of.overall_revenue, 0) * 100)::NUMERIC,
        2
    ) as revenue_contribution_pct,
    ROUND(
        (COALESCE(vf.total_profit, 0) / NULLIF(of.overall_profit, 0) * 100)::NUMERIC,
        2
    ) as profit_contribution_pct,
    
    -- Profitability tier
    CASE 
        WHEN COALESCE(vf.total_profit, 0) / NULLIF(COALESCE(vf.total_revenue, 0), 0) >= 0.30 
            THEN '💎 High Margin (≥30%)'
        WHEN COALESCE(vf.total_profit, 0) / NULLIF(COALESCE(vf.total_revenue, 0), 0) >= 0.20 
            THEN '💰 Good Margin (20-30%)'
        WHEN COALESCE(vf.total_profit, 0) / NULLIF(COALESCE(vf.total_revenue, 0), 0) >= 0.10 
            THEN '✅ Fair Margin (10-20%)'
        WHEN COALESCE(vf.total_profit, 0) / NULLIF(COALESCE(vf.total_revenue, 0), 0) > 0 
            THEN '⚠️ Low Margin (<10%)'
        ELSE '🔴 No Profit/Loss'
    END as profitability_tier,
    
    -- Strategic classification (BCG Matrix style)
    CASE 
        WHEN COALESCE(vf.total_revenue, 0) / NULLIF(of.overall_revenue, 0) >= 0.10 
            AND COALESCE(vf.total_profit, 0) / NULLIF(COALESCE(vf.total_revenue, 0), 0) >= 0.20 
            THEN '⭐ Star Category (High Revenue, High Margin)'
        WHEN COALESCE(vf.total_revenue, 0) / NULLIF(of.overall_revenue, 0) >= 0.10 
            AND COALESCE(vf.total_profit, 0) / NULLIF(COALESCE(vf.total_revenue, 0), 0) < 0.20 
            THEN '🐄 Cash Cow (High Revenue, Low Margin)'
        WHEN COALESCE(vf.total_revenue, 0) / NULLIF(of.overall_revenue, 0) < 0.10 
            AND COALESCE(vf.total_profit, 0) / NULLIF(COALESCE(vf.total_revenue, 0), 0) >= 0.20 
            THEN '❓ Question Mark (Low Revenue, High Margin)'
        ELSE '🐕 Dog (Low Revenue, Low Margin)'
    END as strategic_classification,
    
    -- Rankings
    RANK() OVER (ORDER BY COALESCE(vf.total_profit, 0) DESC) as profit_rank,
    RANK() OVER (ORDER BY COALESCE(vf.total_profit, 0) / NULLIF(COALESCE(vf.total_revenue, 0), 0) DESC) as margin_rank
FROM verticals v
LEFT JOIN vertical_financials vf ON v.id = vf.vertical_id
CROSS JOIN overall_financials of
WHERE v.status = 'active'
ORDER BY COALESCE(vf.total_profit, 0) DESC;

-- Expected output: ~39 rows (one per vertical)
-- QuickSight Usage: Import as "Vertical Profitability" dataset
-- Visualizations: BCG matrix (scatter), Waterfall chart (profit contribution)

-- Test the view
SELECT * FROM v_vertical_profitability_analysis ORDER BY total_profit DESC;

-- Test the view - BCG matrix segments
SELECT 
    strategic_classification,
    COUNT(*) as category_count,
    ROUND(SUM(total_revenue)::NUMERIC, 2) as combined_revenue,
    ROUND(SUM(total_profit)::NUMERIC, 2) as combined_profit
FROM v_vertical_profitability_analysis
GROUP BY strategic_classification;

-- ============================================================================
-- SECTION 7: VERTICAL DASHBOARD SUMMARY
-- KPI summary for vertical analytics dashboard
-- ============================================================================

CREATE OR REPLACE VIEW v_vertical_dashboard_summary AS
WITH overall_metrics AS (
    SELECT 
        COUNT(DISTINCT v.id) as total_verticals,
        COUNT(DISTINCT c.id) as total_products,
        COUNT(DISTINCT c.seller_id) as total_sellers
    FROM verticals v
    LEFT JOIN commodities c ON v.id = c.vertical_id
    WHERE v.status = 'active'
),
top_vertical AS (
    SELECT 
        v.name as vertical_name,
        SUM(oc.line_total) as revenue
    FROM verticals v
    JOIN commodities c ON v.id = c.vertical_id
    JOIN order_commodities oc ON c.id = oc.commodity_id
    JOIN orders o ON oc.order_id = o.id
    WHERE o.status IN ('delivered', 'done')
        AND v.status = 'active'
    GROUP BY v.name
    ORDER BY revenue DESC
    LIMIT 1
),
concentration_metrics AS (
    SELECT 
        SUM(CASE 
            WHEN revenue_rank <= 5 THEN total_revenue 
            ELSE 0 
        END) as top_5_revenue,
        SUM(total_revenue) as total_revenue
    FROM v_vertical_revenue_performance
)
SELECT 
    om.total_verticals,
    om.total_products,
    om.total_sellers,
    tv.vertical_name as top_vertical_by_revenue,
    ROUND(tv.revenue::NUMERIC, 2) as top_vertical_revenue,
    ROUND((cm.top_5_revenue / NULLIF(cm.total_revenue, 0) * 100)::NUMERIC, 2) as top_5_concentration_pct,
    
    -- Diversification status
    CASE 
        WHEN (cm.top_5_revenue / NULLIF(cm.total_revenue, 0) * 100) >= 70 
            THEN '🔴 High Concentration (≥70% in top 5)'
        WHEN (cm.top_5_revenue / NULLIF(cm.total_revenue, 0) * 100) >= 50 
            THEN '🟡 Moderate Concentration (50-70%)'
        ELSE '🟢 Well Diversified (<50%)'
    END as diversification_status,
    
    -- Product mix health
    CASE 
        WHEN om.total_products::DECIMAL / NULLIF(om.total_verticals, 0) >= 100 
            THEN '🟢 Rich Product Mix (≥100 products/vertical)'
        WHEN om.total_products::DECIMAL / NULLIF(om.total_verticals, 0) >= 50 
            THEN '🟡 Good Product Mix (50-100)'
        ELSE '🔴 Limited Product Mix (<50)'
    END as product_mix_health
FROM overall_metrics om
CROSS JOIN top_vertical tv
CROSS JOIN concentration_metrics cm;

-- Expected output: 1 row with vertical KPIs
-- QuickSight Usage: Import as "Vertical KPIs" dataset
-- Visualizations: KPI cards across dashboard top

-- Test the view
SELECT * FROM v_vertical_dashboard_summary;

-- ============================================================================
-- SECTION 8: VERIFICATION & FREE TIER OPTIMIZATION
-- ============================================================================

-- List all created vertical views
SELECT 
    table_name as view_name,
    'View' as object_type
FROM information_schema.views
WHERE table_schema = 'public'
    AND table_name LIKE 'v_vertical%'
ORDER BY table_name;

-- Estimate row counts for SPICE import
SELECT 
    'v_vertical_revenue_performance' as view_name,
    COUNT(*) as estimated_rows,
    'Core vertical metrics' as usage
FROM v_vertical_revenue_performance
UNION ALL
SELECT 
    'v_vertical_revenue_trends',
    COUNT(*),
    'Monthly trends by category'
FROM v_vertical_revenue_trends
UNION ALL
SELECT 
    'v_vertical_market_share',
    COUNT(*),
    'Market share analysis'
FROM v_vertical_market_share
UNION ALL
SELECT 
    'v_vertical_product_mix_efficiency',
    COUNT(*),
    'Product mix health'
FROM v_vertical_product_mix_efficiency
UNION ALL
SELECT 
    'v_vertical_profitability_analysis',
    COUNT(*),
    'Profitability metrics'
FROM v_vertical_profitability_analysis
UNION ALL
SELECT 
    'v_vertical_dashboard_summary',
    COUNT(*),
    'KPI cards'
FROM v_vertical_dashboard_summary;

-- ============================================================================
-- QUICKSIGHT IMPORT RECOMMENDATIONS
-- ============================================================================

/*
FREE TIER OPTIMIZATION TIPS:
1. Import all vertical views to SPICE - total ~20KB data
2. Schedule SPICE refresh daily at 3 AM
3. Filter trends view to last 12 months to reduce data
4. Total SPICE usage: ~25KB - well within 10GB free tier limit

DATASET IMPORT ORDER:
1. v_vertical_dashboard_summary (1 row)
2. v_vertical_revenue_performance (~39 rows)
3. v_vertical_market_share (~39 rows)
4. v_vertical_profitability_analysis (~39 rows)
5. v_vertical_product_mix_efficiency (~39 rows)
6. v_vertical_revenue_trends (filter: last 12 months, ~468 rows)

VISUALIZATION RECOMMENDATIONS:
Dashboard: "Category Performance & Strategic Analysis"
├── KPI Cards (v_vertical_dashboard_summary):
│   ├── Total Verticals
│   ├── Top Category
│   ├── Top 5 Concentration %
│   └── Diversification Status
├── Treemap (v_vertical_revenue_performance):
│   ├── Group: vertical_name
│   ├── Size: total_revenue
│   ├── Color: performance_tier
│   └── Tooltip: revenue, orders, growth_indicator
├── Donut Chart (v_vertical_market_share):
│   ├── Values: revenue_market_share_pct
│   ├── Group: vertical_name
│   ├── Filter: Show top 10 only
│   └── Tooltip: total_revenue, cumulative_share
├── BCG Matrix (v_vertical_profitability_analysis):
│   ├── Scatter plot type
│   ├── X-axis: revenue_contribution_pct
│   ├── Y-axis: profit_margin_pct
│   ├── Size: total_profit
│   ├── Color: strategic_classification
│   └── Quadrant lines at 10% revenue, 20% margin
├── Waterfall Chart (v_vertical_profitability_analysis):
│   ├── Category: vertical_name (top 10)
│   ├── Value: total_profit
│   ├── Sort: By total_profit DESC
│   └── Show running total
├── Stacked Area Chart (v_vertical_revenue_trends):
│   ├── X-axis: year_month
│   ├── Y-axis: total_revenue
│   ├── Stack: vertical_name (top 5 only)
│   ├── Filter: Last 12 months
│   └── Legend: Show top 5 + "Others"
└── Table (v_vertical_product_mix_efficiency):
    ├── Columns: Vertical, Products, Efficiency %, Competition Status
    ├── Conditional: Color by mix_efficiency_status
    ├── Filter: Show all
    └── Sort: By product_sales_penetration_pct DESC

FILTERS TO ADD:
- Vertical multi-select
- Performance tier filter
- Date range (month)
- Strategic classification filter

CALCULATED FIELDS TO CREATE:
- Revenue Growth Rate = (current_revenue - prev_revenue) / prev_revenue * 100
- Profit per Unit = total_profit / total_units_sold
- Efficiency Score = product_sales_penetration_pct * profit_margin_pct

PARAMETERS TO CREATE:
- Top N filter (default 10, for showing top categories)
- BCG matrix thresholds (revenue %, margin %)
- Concentration threshold (default 70%)

ADVANCED ANALYTICS TO ADD:
- Forecast: Revenue by vertical (next 3 months)
- Clustering: Group similar verticals by performance
- What-if analysis: Impact of price changes on profitability
*/

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================
SELECT 
    '✅ Vertical Efficiency Analysis Views Created Successfully' as status,
    '6 views ready for QuickSight import' as views_created,
    'Estimated SPICE usage: ~25KB' as spice_usage,
    'Includes BCG matrix and Pareto analysis' as features;

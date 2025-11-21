-- ============================================================================
-- NOTEBOOK 4: GEOGRAPHY ANALYSIS & REPORTING
-- Business Objective: Track sales by region, identify growth markets, logistics insights
-- QuickSight Compatibility: Optimized for heat maps and geographic visualizations
-- Free Tier Considerations: Aggregated by city/country, minimal data volume
-- ============================================================================

-- ============================================================================
-- SECTION 1: DATA VALIDATION
-- Verify geographic data completeness
-- ============================================================================

-- Check geographic coverage
SELECT 
    COUNT(DISTINCT delivery_country) as unique_countries,
    COUNT(DISTINCT delivery_city) as unique_cities,
    COUNT(*) as total_orders,
    COUNT(CASE WHEN delivery_latitude IS NOT NULL THEN 1 END) as orders_with_coordinates,
    ROUND(
        (COUNT(CASE WHEN delivery_latitude IS NOT NULL THEN 1 END)::DECIMAL / COUNT(*) * 100)::NUMERIC,
        2
    ) as coordinate_coverage_pct
FROM orders;

-- Expected output: Geographic data completeness metrics
-- QuickSight Usage: Not needed - validation only

-- Top countries by order volume
SELECT 
    delivery_country,
    COUNT(*) as order_count,
    COUNT(DISTINCT delivery_city) as cities
FROM orders
GROUP BY delivery_country
ORDER BY order_count DESC
LIMIT 10;

-- ============================================================================
-- SECTION 2: REVENUE BY COUNTRY
-- Track sales performance across countries
-- ============================================================================

CREATE OR REPLACE VIEW v_revenue_by_country AS
WITH country_sales AS (
    SELECT 
        o.delivery_country as country,
        COUNT(DISTINCT o.id) as total_orders,
        COUNT(DISTINCT CASE WHEN o.status IN ('delivered', 'done') THEN o.id END) as completed_orders,
        SUM(CASE WHEN o.status IN ('delivered', 'done') THEN o.total_amount ELSE 0 END) as total_revenue,
        AVG(CASE WHEN o.status IN ('delivered', 'done') THEN o.total_amount END) as avg_order_value,
        COUNT(DISTINCT o.consumer_id) as unique_customers,
        COUNT(DISTINCT o.seller_id) as unique_sellers,
        COUNT(DISTINCT o.delivery_city) as cities_served,
        MIN(o.created_at) as first_order_date,
        MAX(o.created_at) as last_order_date
    FROM orders o
    GROUP BY o.delivery_country
),
country_sales_30d AS (
    SELECT 
        o.delivery_country as country,
        SUM(CASE WHEN o.status IN ('delivered', 'done') THEN o.total_amount ELSE 0 END) as revenue_30d,
        COUNT(DISTINCT CASE WHEN o.status IN ('delivered', 'done') THEN o.id END) as orders_30d
    FROM orders o
    WHERE o.created_at >= DATEADD(day, -30, GETDATE())
    GROUP BY o.delivery_country
)
SELECT 
    cs.country,
    cs.total_orders,
    cs.completed_orders,
    ROUND(cs.total_revenue::NUMERIC, 2) as total_revenue,
    ROUND(cs.avg_order_value::NUMERIC, 2) as avg_order_value,
    cs.unique_customers,
    cs.unique_sellers,
    cs.cities_served,
    
    -- Completion rate
    ROUND(
        (cs.completed_orders::DECIMAL / NULLIF(cs.total_orders, 0) * 100)::NUMERIC,
        2
    ) as order_completion_rate_pct,
    
    -- Recent performance (30 days)
    ROUND(COALESCE(cs30.revenue_30d, 0)::NUMERIC, 2) as revenue_30d,
    COALESCE(cs30.orders_30d, 0) as orders_30d,
    
    -- Activity status
    CASE 
        WHEN cs.last_order_date >= DATEADD(day, -7, GETDATE()) THEN '🟢 Active'
        WHEN cs.last_order_date >= DATEADD(day, -30, GETDATE()) THEN '🟡 Moderate'
        ELSE '🔴 Inactive'
    END as market_activity_status,
    
    -- Market tier
    CASE 
        WHEN cs.total_revenue >= 100000 THEN '⭐⭐⭐ Tier 1 Market'
        WHEN cs.total_revenue >= 50000 THEN '⭐⭐ Tier 2 Market'
        WHEN cs.total_revenue >= 10000 THEN '⭐ Tier 3 Market'
        ELSE '🌱 Emerging Market'
    END as market_tier,
    
    -- Rankings
    RANK() OVER (ORDER BY cs.total_revenue DESC) as revenue_rank,
    RANK() OVER (ORDER BY cs.unique_customers DESC) as customer_rank,
    
    -- Dates
    cs.first_order_date,
    cs.last_order_date
FROM country_sales cs
LEFT JOIN country_sales_30d cs30 ON cs.country = cs30.country
ORDER BY cs.total_revenue DESC;

-- Expected output: ~30 rows (one per country with orders)
-- QuickSight Usage: Import as "Revenue by Country" dataset
-- Visualizations: World map (heat map), Bar chart (top countries), KPI cards

-- Test the view
SELECT * FROM v_revenue_by_country ORDER BY total_revenue DESC LIMIT 10;

-- ============================================================================
-- SECTION 3: REVENUE BY CITY
-- Detailed city-level sales analysis
-- ============================================================================

CREATE OR REPLACE VIEW v_revenue_by_city AS
WITH city_sales AS (
    SELECT 
        o.delivery_country as country,
        o.delivery_city as city,
        AVG(o.delivery_latitude) as avg_latitude,
        AVG(o.delivery_longitude) as avg_longitude,
        COUNT(DISTINCT o.id) as total_orders,
        COUNT(DISTINCT CASE WHEN o.status IN ('delivered', 'done') THEN o.id END) as completed_orders,
        SUM(CASE WHEN o.status IN ('delivered', 'done') THEN o.total_amount ELSE 0 END) as total_revenue,
        AVG(CASE WHEN o.status IN ('delivered', 'done') THEN o.total_amount END) as avg_order_value,
        COUNT(DISTINCT o.consumer_id) as unique_customers,
        COUNT(DISTINCT o.seller_id) as unique_sellers
    FROM orders o
    GROUP BY o.delivery_country, o.delivery_city
),
city_sales_30d AS (
    SELECT 
        o.delivery_country as country,
        o.delivery_city as city,
        SUM(CASE WHEN o.status IN ('delivered', 'done') THEN o.total_amount ELSE 0 END) as revenue_30d,
        COUNT(DISTINCT CASE WHEN o.status IN ('delivered', 'done') THEN o.id END) as orders_30d
    FROM orders o
    WHERE o.created_at >= DATEADD(day, -30, GETDATE())
    GROUP BY o.delivery_country, o.delivery_city
)
SELECT 
    cs.country,
    cs.city,
    ROUND(cs.avg_latitude::NUMERIC, 6) as latitude,
    ROUND(cs.avg_longitude::NUMERIC, 6) as longitude,
    cs.total_orders,
    cs.completed_orders,
    ROUND(cs.total_revenue::NUMERIC, 2) as total_revenue,
    ROUND(cs.avg_order_value::NUMERIC, 2) as avg_order_value,
    cs.unique_customers,
    cs.unique_sellers,
    
    -- Completion rate
    ROUND(
        (cs.completed_orders::DECIMAL / NULLIF(cs.total_orders, 0) * 100)::NUMERIC,
        2
    ) as order_completion_rate_pct,
    
    -- Recent performance
    ROUND(COALESCE(cs30.revenue_30d, 0)::NUMERIC, 2) as revenue_30d,
    COALESCE(cs30.orders_30d, 0) as orders_30d,
    
    -- City tier classification
    CASE 
        WHEN cs.total_revenue >= 50000 THEN '🏙️ Tier 1 City'
        WHEN cs.total_revenue >= 20000 THEN '🌆 Tier 2 City'
        WHEN cs.total_revenue >= 5000 THEN '🏘️ Tier 3 City'
        ELSE '🏡 Small Market'
    END as city_tier,
    
    -- Growth potential
    CASE 
        WHEN COALESCE(cs30.revenue_30d, 0) > (cs.total_revenue / 12.0) 
            THEN '📈 High Growth'
        WHEN COALESCE(cs30.revenue_30d, 0) > (cs.total_revenue / 24.0) 
            THEN '📊 Moderate Growth'
        ELSE '📉 Stable/Declining'
    END as growth_indicator,
    
    -- Rankings within country
    RANK() OVER (PARTITION BY cs.country ORDER BY cs.total_revenue DESC) as city_rank_in_country,
    RANK() OVER (ORDER BY cs.total_revenue DESC) as global_city_rank
FROM city_sales cs
LEFT JOIN city_sales_30d cs30 ON cs.country = cs30.country AND cs.city = cs30.city
ORDER BY cs.total_revenue DESC;

-- Expected output: ~200-500 rows (one per city with orders)
-- QuickSight Usage: Import as "Revenue by City" dataset
-- Visualizations: Heat map (latitude/longitude), Bar chart (top cities), Geo chart

-- Test the view - Top 20 cities
SELECT * FROM v_revenue_by_city ORDER BY total_revenue DESC LIMIT 20;

-- Test the view - Top 5 cities per country
SELECT * FROM v_revenue_by_city WHERE city_rank_in_country <= 5 ORDER BY country, city_rank_in_country;

-- ============================================================================
-- SECTION 4: GEOGRAPHIC REVENUE TRENDS (Monthly)
-- Track how geographic distribution changes over time
-- ============================================================================

CREATE OR REPLACE VIEW v_geographic_revenue_trends AS
SELECT 
    DATE_TRUNC('month', o.created_at) as month,
    TO_CHAR(o.created_at, 'YYYY-MM') as year_month,
    o.delivery_country as country,
    
    -- Monthly metrics
    COUNT(DISTINCT o.id) as total_orders,
    COUNT(DISTINCT CASE WHEN o.status IN ('delivered', 'done') THEN o.id END) as completed_orders,
    ROUND(SUM(CASE WHEN o.status IN ('delivered', 'done') THEN o.total_amount ELSE 0 END)::NUMERIC, 2) as total_revenue,
    ROUND(AVG(CASE WHEN o.status IN ('delivered', 'done') THEN o.total_amount END)::NUMERIC, 2) as avg_order_value,
    COUNT(DISTINCT o.consumer_id) as unique_customers,
    COUNT(DISTINCT o.delivery_city) as cities_served
FROM orders o
GROUP BY 1, 2, 3
ORDER BY 1 DESC, 4 DESC;

-- Expected output: ~360 rows (12 months × 30 countries)
-- QuickSight Usage: Import as "Geographic Trends" dataset
-- Visualizations: Line chart (revenue by country over time), Area chart (stacked)

-- Test the view
SELECT * FROM v_geographic_revenue_trends 
WHERE month >= DATEADD(month, -6, GETDATE())
ORDER BY month DESC, total_revenue DESC
LIMIT 30;

-- ============================================================================
-- SECTION 5: SHIPPING DISTANCE & COST ANALYSIS
-- Analyze logistics efficiency using coordinates
-- ============================================================================

CREATE OR REPLACE VIEW v_shipping_distance_analysis AS
WITH order_with_seller_location AS (
    SELECT 
        o.id as order_id,
        o.delivery_country,
        o.delivery_city,
        o.delivery_latitude as delivery_lat,
        o.delivery_longitude as delivery_lon,
        s.city as seller_city,
        s.country as seller_country,
        o.shipping_fee,
        o.total_amount,
        o.status,
        o.created_at,
        o.delivered_at,
        
        -- Approximate distance calculation (haversine simplified for small distances)
        -- For demonstration - in production use proper geospatial functions
        CASE 
            WHEN o.delivery_latitude IS NOT NULL 
                AND o.delivery_longitude IS NOT NULL
            THEN ABS(o.delivery_latitude) + ABS(o.delivery_longitude)  -- Placeholder
            ELSE NULL
        END as approximate_distance_index
    FROM orders o
    JOIN sellers s ON o.seller_id = s.id
    WHERE o.status IN ('delivered', 'done')
)
SELECT 
    delivery_country,
    delivery_city,
    seller_country,
    
    -- Order metrics
    COUNT(*) as total_deliveries,
    
    -- Shipping cost analysis
    ROUND(AVG(shipping_fee)::NUMERIC, 2) as avg_shipping_fee,
    ROUND(MIN(shipping_fee)::NUMERIC, 2) as min_shipping_fee,
    ROUND(MAX(shipping_fee)::NUMERIC, 2) as max_shipping_fee,
    ROUND(SUM(shipping_fee)::NUMERIC, 2) as total_shipping_revenue,
    
    -- Shipping fee as % of order value
    ROUND(
        (AVG(shipping_fee / NULLIF(total_amount, 0)) * 100)::NUMERIC,
        2
    ) as avg_shipping_pct_of_order,
    
    -- Delivery time analysis (in hours)
    ROUND(
        AVG(DATEDIFF(hour, created_at, delivered_at))::NUMERIC,
        2
    ) as avg_delivery_time_hours,
    ROUND(
        AVG(DATEDIFF(day, created_at, delivered_at))::NUMERIC,
        2
    ) as avg_delivery_time_days,
    
    -- Same country shipping
    CASE 
        WHEN seller_country = delivery_country THEN '🇱🇳 Domestic'
        ELSE '🌍 International'
    END as shipping_type,
    
    -- Logistics efficiency
    CASE 
        WHEN AVG(DATEDIFF(day, created_at, delivered_at)) <= 2 THEN '⚡ Express (≤2d)'
        WHEN AVG(DATEDIFF(day, created_at, delivered_at)) <= 5 THEN '🚀 Fast (3-5d)'
        WHEN AVG(DATEDIFF(day, created_at, delivered_at)) <= 10 THEN '📦 Standard (6-10d)'
        ELSE '🐌 Slow (>10d)'
    END as delivery_speed_category
FROM order_with_seller_location
GROUP BY 
    delivery_country, 
    delivery_city, 
    seller_country,
    CASE WHEN seller_country = delivery_country THEN '🇱🇳 Domestic' ELSE '🌍 International' END
HAVING COUNT(*) >= 5  -- Only cities with 5+ deliveries
ORDER BY total_deliveries DESC;

-- Expected output: ~200 rows (city pairs with significant volume)
-- QuickSight Usage: Import as "Shipping Analysis" dataset
-- Visualizations: Scatter plot (delivery time vs shipping fee), Table (logistics KPIs)

-- Test the view
SELECT * FROM v_shipping_distance_analysis ORDER BY total_deliveries DESC LIMIT 30;

-- ============================================================================
-- SECTION 6: REGIONAL MARKET PENETRATION
-- Identify underserved markets and expansion opportunities
-- ============================================================================

CREATE OR REPLACE VIEW v_regional_market_penetration AS
WITH country_metrics AS (
    SELECT 
        o.delivery_country as country,
        COUNT(DISTINCT o.delivery_city) as cities_with_orders,
        COUNT(DISTINCT o.consumer_id) as unique_customers,
        SUM(CASE WHEN o.status IN ('delivered', 'done') THEN o.total_amount ELSE 0 END) as total_revenue,
        COUNT(DISTINCT o.seller_id) as sellers_serving_country,
        MAX(o.created_at) as last_order_date
    FROM orders o
    GROUP BY o.delivery_country
),
city_counts_per_country AS (
    SELECT 
        delivery_country as country,
        COUNT(DISTINCT delivery_city) as total_cities_in_data
    FROM orders
    GROUP BY delivery_country
)
SELECT 
    cm.country,
    cm.cities_with_orders,
    cm.unique_customers,
    ROUND(cm.total_revenue::NUMERIC, 2) as total_revenue,
    cm.sellers_serving_country,
    
    -- Market penetration metrics
    ROUND((cm.total_revenue / NULLIF(cm.cities_with_orders, 0))::NUMERIC, 2) as revenue_per_city,
    ROUND((cm.unique_customers::DECIMAL / NULLIF(cm.cities_with_orders, 0))::NUMERIC, 2) as customers_per_city,
    ROUND((cm.total_revenue / NULLIF(cm.unique_customers, 0))::NUMERIC, 2) as revenue_per_customer,
    
    -- Market maturity
    CASE 
        WHEN cm.unique_customers >= 500 AND cm.sellers_serving_country >= 20 
            THEN '🟢 Mature Market'
        WHEN cm.unique_customers >= 100 AND cm.sellers_serving_country >= 5 
            THEN '🟡 Growing Market'
        WHEN cm.unique_customers >= 20 
            THEN '🟠 Emerging Market'
        ELSE '🔴 New Market'
    END as market_maturity,
    
    -- Expansion opportunity
    CASE 
        WHEN cm.sellers_serving_country < 10 AND cm.total_revenue > 10000 
            THEN '🎯 High Potential - Need More Sellers'
        WHEN cm.cities_with_orders < 5 AND cm.total_revenue > 5000 
            THEN '🌟 Geographic Expansion Opportunity'
        WHEN DATEDIFF(day, cm.last_order_date, GETDATE()) > 30 
            THEN '⚠️ Declining - Needs Attention'
        ELSE '✅ Stable'
    END as opportunity_status,
    
    cm.last_order_date,
    DATEDIFF(day, cm.last_order_date, GETDATE()) as days_since_last_order
FROM country_metrics cm
JOIN city_counts_per_country cpc ON cm.country = cpc.country
ORDER BY cm.total_revenue DESC;

-- Expected output: ~30 rows (one per country)
-- QuickSight Usage: Import as "Market Penetration" dataset
-- Visualizations: Matrix (country metrics), Opportunity quadrant chart

-- Test the view
SELECT * FROM v_regional_market_penetration ORDER BY total_revenue DESC;

-- ============================================================================
-- SECTION 7: GEOGRAPHIC DASHBOARD SUMMARY
-- KPI summary for geographic dashboard
-- ============================================================================

CREATE OR REPLACE VIEW v_geographic_dashboard_summary AS
WITH overall_metrics AS (
    SELECT 
        COUNT(DISTINCT delivery_country) as total_countries,
        COUNT(DISTINCT delivery_city) as total_cities,
        COUNT(DISTINCT id) as total_orders,
        COUNT(DISTINCT CASE WHEN status IN ('delivered', 'done') THEN id END) as completed_orders,
        SUM(CASE WHEN status IN ('delivered', 'done') THEN total_amount ELSE 0 END) as total_revenue,
        SUM(CASE WHEN status IN ('delivered', 'done') THEN shipping_fee ELSE 0 END) as total_shipping_revenue,
        AVG(CASE 
            WHEN status IN ('delivered', 'done') AND delivered_at IS NOT NULL 
            THEN DATEDIFF(day, created_at, delivered_at) 
        END) as avg_delivery_time_days
    FROM orders
),
top_country AS (
    SELECT 
        delivery_country,
        SUM(CASE WHEN status IN ('delivered', 'done') THEN total_amount ELSE 0 END) as revenue
    FROM orders
    GROUP BY delivery_country
    ORDER BY revenue DESC
    LIMIT 1
),
recent_expansion AS (
    SELECT 
        COUNT(DISTINCT delivery_city) as new_cities_30d
    FROM orders
    WHERE created_at >= DATEADD(day, -30, GETDATE())
        AND delivery_city NOT IN (
            SELECT DISTINCT delivery_city
            FROM orders
            WHERE created_at < DATEADD(day, -30, GETDATE())
        )
)
SELECT 
    om.total_countries,
    om.total_cities,
    om.total_orders,
    om.completed_orders,
    ROUND(om.total_revenue::NUMERIC, 2) as total_revenue,
    ROUND(om.total_shipping_revenue::NUMERIC, 2) as total_shipping_revenue,
    ROUND(om.avg_delivery_time_days::NUMERIC, 2) as avg_delivery_time_days,
    tc.delivery_country as top_country_by_revenue,
    ROUND(tc.revenue::NUMERIC, 2) as top_country_revenue,
    re.new_cities_30d,
    
    -- Health indicators
    CASE 
        WHEN om.avg_delivery_time_days <= 5 THEN '🟢 Fast Delivery'
        WHEN om.avg_delivery_time_days <= 10 THEN '🟡 Moderate Delivery'
        ELSE '🔴 Slow Delivery'
    END as logistics_health_status,
    
    CASE 
        WHEN re.new_cities_30d >= 5 THEN '🚀 Rapid Expansion'
        WHEN re.new_cities_30d >= 2 THEN '📈 Growing'
        ELSE '➡️ Stable'
    END as expansion_status
FROM overall_metrics om
CROSS JOIN top_country tc
CROSS JOIN recent_expansion re;

-- Expected output: 1 row with geographic KPIs
-- QuickSight Usage: Import as "Geographic KPIs" dataset
-- Visualizations: KPI cards across dashboard top

-- Test the view
SELECT * FROM v_geographic_dashboard_summary;

-- ============================================================================
-- SECTION 8: VERIFICATION & FREE TIER OPTIMIZATION
-- ============================================================================

-- List all created geographic views
SELECT 
    table_name as view_name,
    'View' as object_type
FROM information_schema.views
WHERE table_schema = 'public'
    AND (table_name LIKE 'v_revenue_by_%'
    OR table_name LIKE 'v_geographic%'
    OR table_name LIKE 'v_shipping%'
    OR table_name LIKE 'v_regional%')
ORDER BY table_name;

-- Estimate row counts for SPICE import
SELECT 
    'v_revenue_by_country' as view_name,
    COUNT(*) as estimated_rows,
    'Country-level revenue' as usage
FROM v_revenue_by_country
UNION ALL
SELECT 
    'v_revenue_by_city',
    COUNT(*),
    'City-level revenue'
FROM v_revenue_by_city
UNION ALL
SELECT 
    'v_geographic_revenue_trends',
    COUNT(*),
    'Monthly trends by country'
FROM v_geographic_revenue_trends
UNION ALL
SELECT 
    'v_shipping_distance_analysis',
    COUNT(*),
    'Logistics efficiency'
FROM v_shipping_distance_analysis
UNION ALL
SELECT 
    'v_regional_market_penetration',
    COUNT(*),
    'Market maturity analysis'
FROM v_regional_market_penetration
UNION ALL
SELECT 
    'v_geographic_dashboard_summary',
    COUNT(*),
    'KPI cards'
FROM v_geographic_dashboard_summary;

-- ============================================================================
-- QUICKSIGHT IMPORT RECOMMENDATIONS
-- ============================================================================

/*
FREE TIER OPTIMIZATION TIPS:
1. Filter v_revenue_by_city to show only top 100 cities to reduce SPICE usage
2. Use SPICE for all datasets - estimated total: ~50KB
3. Schedule refresh daily during off-peak hours
4. Apply geographic filters to show relevant regions only

DATASET IMPORT ORDER:
1. v_revenue_by_country (~30 rows)
2. v_revenue_by_city (filter: global_city_rank <= 100, ~100 rows)
3. v_geographic_revenue_trends (filter: last 12 months, ~360 rows)
4. v_shipping_distance_analysis (~200 rows)
5. v_regional_market_penetration (~30 rows)
6. v_geographic_dashboard_summary (1 row)

VISUALIZATION RECOMMENDATIONS:
Dashboard: "Geographic Performance & Market Insights"
├── KPI Cards (v_geographic_dashboard_summary):
│   ├── Total Countries
│   ├── Total Cities
│   ├── Avg Delivery Time
│   ├── Top Country
│   └── Expansion Status
├── Heat Map (v_revenue_by_city):
│   ├── Geospatial type: Point
│   ├── Latitude: latitude field
│   ├── Longitude: longitude field
│   ├── Size: total_revenue
│   ├── Color: city_tier
│   └── Tooltip: city, country, revenue, orders
├── Filled Map (v_revenue_by_country):
│   ├── Geospatial type: Country/Region
│   ├── Country field: country
│   ├── Color: total_revenue (gradient)
│   └── Tooltip: revenue, orders, customers, market_tier
├── Bar Chart (v_revenue_by_country):
│   ├── X-axis: country
│   ├── Y-axis: total_revenue
│   ├── Color: market_tier
│   ├── Sort: By total_revenue DESC
│   └── Filter: Top 10
├── Stacked Area Chart (v_geographic_revenue_trends):
│   ├── X-axis: year_month
│   ├── Y-axis: total_revenue
│   ├── Stack: country (top 5 only)
│   └── Filter: Last 12 months
├── Scatter Plot (v_regional_market_penetration):
│   ├── X-axis: unique_customers
│   ├── Y-axis: total_revenue
│   ├── Size: cities_with_orders
│   ├── Color: market_maturity
│   └── Tooltip: country, opportunity_status
└── Table (v_shipping_distance_analysis):
    ├── Columns: Delivery City, Shipping Type, Avg Shipping Fee, Delivery Speed
    ├── Conditional: Color by delivery_speed_category
    └── Filter: total_deliveries >= 10

FILTERS TO ADD:
- Country multi-select
- City tier filter
- Market maturity filter
- Date range (month)
- Shipping type (Domestic vs International)

CALCULATED FIELDS TO CREATE:
- Revenue per capita (if you add population data)
- Market share % = revenue / SUM(revenue)
- Growth rate = (current_revenue - prev_revenue) / prev_revenue

SPECIAL QUICKSIGHT FEATURES:
- Enable Geospatial Auto-Narrative for automatic insights
- Add drill-down: Country → City → Customer
- Create geographic hierarchies (Country > City)
- Use conditional formatting for opportunity flags

FREE TIER GEOGRAPHIC LIMITS:
- QuickSight supports unlimited geospatial charts in Enterprise
- Use lat/long instead of geocoding API to save costs
- Cache geographic boundaries in SPICE
- Limit to top 100 cities to stay under SPICE limits
*/

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================
SELECT 
    '✅ Geographic Analysis Views Created Successfully' as status,
    '6 views ready for QuickSight import' as views_created,
    'Estimated SPICE usage: ~50KB' as spice_usage,
    'Optimized for heat maps and geo visualizations' as features;

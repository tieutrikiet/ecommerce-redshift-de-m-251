-- ============================================================================
-- NOTEBOOK 5: PRODUCT REVIEWS ANALYSIS
-- Business Objective: Monitor product quality, seller reputation, customer sentiment
-- QuickSight Compatibility: Optimized for rating distributions and trend analysis
-- Free Tier Considerations: Aggregated metrics, minimal data volume
-- NOTE: This notebook may need adjustment if reviews table is not loaded
-- ============================================================================

-- ============================================================================
-- SECTION 1: DATA VALIDATION
-- Verify reviews data availability and completeness
-- ============================================================================

-- Check reviews data status
SELECT 
    COUNT(*) as total_reviews,
    COUNT(CASE WHEN status = 'published' THEN 1 END) as published_reviews,
    COUNT(CASE WHEN status = 'deleted' THEN 1 END) as deleted_reviews,
    COUNT(CASE WHEN status = 'flagged' THEN 1 END) as flagged_reviews,
    COUNT(CASE WHEN is_verified_purchase THEN 1 END) as verified_purchase_reviews,
    ROUND(AVG(rate)::NUMERIC, 2) as overall_avg_rating,
    COUNT(CASE WHEN comment IS NOT NULL AND comment != '' THEN 1 END) as reviews_with_comments
FROM reviews;

-- Expected output: Reviews data completeness metrics
-- QuickSight Usage: Not needed - validation only
-- If this returns 0 rows, skip this notebook or use commodity/seller rating fields

-- Rating distribution
SELECT 
    rate as rating,
    COUNT(*) as review_count,
    ROUND((COUNT(*)::DECIMAL / (SELECT COUNT(*) FROM reviews WHERE status = 'published') * 100)::NUMERIC, 2) as percentage
FROM reviews
WHERE status = 'published'
GROUP BY rate
ORDER BY rate DESC;

-- ============================================================================
-- SECTION 2: PRODUCT RATING ANALYSIS
-- Track product quality and customer satisfaction
-- ============================================================================

CREATE OR REPLACE VIEW v_product_rating_analysis AS
WITH product_reviews AS (
    SELECT 
        r.commodity_id,
        COUNT(*) as total_reviews,
        COUNT(CASE WHEN r.status = 'published' THEN 1 END) as published_reviews,
        COUNT(CASE WHEN r.is_verified_purchase THEN 1 END) as verified_reviews,
        AVG(CASE WHEN r.status = 'published' THEN r.rate END) as avg_rating,
        COUNT(CASE WHEN r.status = 'published' AND r.rate >= 4 THEN 1 END) as positive_reviews,
        COUNT(CASE WHEN r.status = 'published' AND r.rate <= 2 THEN 1 END) as negative_reviews,
        COUNT(CASE WHEN r.status = 'published' AND r.rate = 3 THEN 1 END) as neutral_reviews,
        SUM(r.helpful_count) as total_helpful_votes,
        MIN(r.created_at) as first_review_date,
        MAX(r.created_at) as last_review_date
    FROM reviews r
    WHERE r.status != 'deleted'
    GROUP BY r.commodity_id
),
recent_reviews AS (
    SELECT 
        r.commodity_id,
        COUNT(*) as reviews_30d,
        AVG(r.rate) as avg_rating_30d
    FROM reviews r
    WHERE r.created_at >= DATEADD(day, -30, GETDATE())
        AND r.status = 'published'
    GROUP BY r.commodity_id
)
SELECT 
    c.id as commodity_id,
    c.sku,
    c.name as product_name,
    v.name as vertical_name,
    u.name as seller_name,
    
    -- Review volume metrics
    COALESCE(pr.total_reviews, 0) as total_reviews,
    COALESCE(pr.published_reviews, 0) as published_reviews,
    COALESCE(pr.verified_reviews, 0) as verified_reviews,
    ROUND(
        (COALESCE(pr.verified_reviews, 0)::DECIMAL / NULLIF(COALESCE(pr.published_reviews, 0), 0) * 100)::NUMERIC,
        2
    ) as verified_purchase_pct,
    
    -- Rating metrics
    ROUND(COALESCE(pr.avg_rating, 0)::NUMERIC, 2) as avg_rating,
    ROUND(COALESCE(rr.avg_rating_30d, 0)::NUMERIC, 2) as avg_rating_30d,
    
    -- Sentiment distribution
    COALESCE(pr.positive_reviews, 0) as positive_reviews,
    COALESCE(pr.neutral_reviews, 0) as neutral_reviews,
    COALESCE(pr.negative_reviews, 0) as negative_reviews,
    ROUND(
        (COALESCE(pr.positive_reviews, 0)::DECIMAL / NULLIF(COALESCE(pr.published_reviews, 0), 0) * 100)::NUMERIC,
        2
    ) as positive_review_pct,
    ROUND(
        (COALESCE(pr.negative_reviews, 0)::DECIMAL / NULLIF(COALESCE(pr.published_reviews, 0), 0) * 100)::NUMERIC,
        2
    ) as negative_review_pct,
    
    -- Engagement metrics
    COALESCE(pr.total_helpful_votes, 0) as total_helpful_votes,
    ROUND(
        (COALESCE(pr.total_helpful_votes, 0)::DECIMAL / NULLIF(COALESCE(pr.published_reviews, 0), 0))::NUMERIC,
        2
    ) as avg_helpful_votes_per_review,
    
    -- Recent activity
    COALESCE(rr.reviews_30d, 0) as reviews_30d,
    
    -- Product performance
    c.total_sold as units_sold,
    ROUND(
        (COALESCE(pr.published_reviews, 0)::DECIMAL / NULLIF(c.total_sold, 0) * 100)::NUMERIC,
        2
    ) as review_rate_pct,
    
    -- Quality tier
    CASE 
        WHEN COALESCE(pr.avg_rating, 0) >= 4.5 AND COALESCE(pr.published_reviews, 0) >= 50 
            THEN '⭐⭐⭐⭐⭐ Excellent (4.5+, 50+ reviews)'
        WHEN COALESCE(pr.avg_rating, 0) >= 4.0 AND COALESCE(pr.published_reviews, 0) >= 20 
            THEN '⭐⭐⭐⭐ Very Good (4.0+, 20+ reviews)'
        WHEN COALESCE(pr.avg_rating, 0) >= 3.5 
            THEN '⭐⭐⭐ Good (3.5+)'
        WHEN COALESCE(pr.avg_rating, 0) >= 3.0 
            THEN '⭐⭐ Fair (3.0-3.5)'
        WHEN COALESCE(pr.published_reviews, 0) = 0 
            THEN '🆕 No Reviews Yet'
        ELSE '⭐ Poor (<3.0)'
    END as quality_tier,
    
    -- Alert flags
    CASE 
        WHEN COALESCE(pr.avg_rating, 0) < 3.0 AND COALESCE(pr.published_reviews, 0) >= 10 
            THEN '🚨 Quality Issue - Low Rating'
        WHEN COALESCE(pr.negative_reviews, 0)::DECIMAL / NULLIF(COALESCE(pr.published_reviews, 0), 0) > 0.3 
            THEN '⚠️ Warning - High Negative Review Rate'
        WHEN COALESCE(rr.avg_rating_30d, 0) < COALESCE(pr.avg_rating, 0) - 0.5 
            THEN '📉 Declining Quality'
        ELSE '✅ Normal'
    END as quality_alert,
    
    -- Dates
    pr.first_review_date,
    pr.last_review_date,
    
    -- Rankings
    RANK() OVER (ORDER BY COALESCE(pr.avg_rating, 0) DESC, COALESCE(pr.published_reviews, 0) DESC) as quality_rank,
    RANK() OVER (PARTITION BY v.id ORDER BY COALESCE(pr.avg_rating, 0) DESC) as quality_rank_in_vertical
FROM commodities c
JOIN verticals v ON c.vertical_id = v.id
JOIN sellers s ON c.seller_id = s.id
JOIN users u ON s.id = u.id
LEFT JOIN product_reviews pr ON c.id = pr.commodity_id
LEFT JOIN recent_reviews rr ON c.id = rr.commodity_id
WHERE c.status IN ('available', 'unavailable', 'out of stock')
ORDER BY COALESCE(pr.published_reviews, 0) DESC, COALESCE(pr.avg_rating, 0) DESC;

-- Expected output: ~5000 rows (one per product)
-- QuickSight Usage: Import as "Product Ratings" dataset
-- Visualizations: Rating distribution, Top rated products, Quality alerts

-- Test the view - Top rated products
SELECT * FROM v_product_rating_analysis 
WHERE published_reviews >= 10
ORDER BY avg_rating DESC, published_reviews DESC
LIMIT 20;

-- Test the view - Products with quality issues
SELECT * FROM v_product_rating_analysis 
WHERE quality_alert LIKE '%Quality Issue%' OR quality_alert LIKE '%Warning%'
ORDER BY negative_review_pct DESC
LIMIT 20;

-- ============================================================================
-- SECTION 3: SELLER REPUTATION ANALYSIS
-- Track seller performance based on reviews
-- ============================================================================

CREATE OR REPLACE VIEW v_seller_reputation_analysis AS
WITH seller_reviews AS (
    SELECT 
        r.seller_id,
        COUNT(*) as total_reviews,
        COUNT(CASE WHEN r.status = 'published' THEN 1 END) as published_reviews,
        AVG(CASE WHEN r.status = 'published' THEN r.rate END) as avg_rating,
        COUNT(CASE WHEN r.status = 'published' AND r.rate >= 4 THEN 1 END) as positive_reviews,
        COUNT(CASE WHEN r.status = 'published' AND r.rate <= 2 THEN 1 END) as negative_reviews,
        COUNT(CASE WHEN r.status = 'flagged' THEN 1 END) as flagged_reviews,
        COUNT(CASE WHEN r.is_verified_purchase THEN 1 END) as verified_purchase_reviews
    FROM reviews r
    GROUP BY r.seller_id
),
seller_products AS (
    SELECT 
        c.seller_id,
        COUNT(DISTINCT c.id) as total_products,
        AVG(c.rating_avg) as avg_product_rating,
        SUM(c.review_count) as total_product_reviews
    FROM commodities c
    GROUP BY c.seller_id
),
seller_orders AS (
    SELECT 
        o.seller_id,
        COUNT(DISTINCT o.id) as total_orders,
        COUNT(DISTINCT CASE WHEN o.status IN ('delivered', 'done') THEN o.id END) as completed_orders,
        SUM(CASE WHEN o.status IN ('delivered', 'done') THEN o.total_amount ELSE 0 END) as total_revenue
    FROM orders o
    GROUP BY o.seller_id
)
SELECT 
    s.id as seller_id,
    u.name as seller_name,
    u.username as seller_username,
    s.type as seller_type,
    s.country,
    
    -- Product portfolio
    COALESCE(sp.total_products, 0) as total_products,
    ROUND(COALESCE(sp.avg_product_rating, 0)::NUMERIC, 2) as avg_product_rating,
    COALESCE(sp.total_product_reviews, 0) as total_product_reviews,
    
    -- Review metrics
    COALESCE(sr.total_reviews, 0) as total_reviews,
    COALESCE(sr.published_reviews, 0) as published_reviews,
    ROUND(COALESCE(sr.avg_rating, 0)::NUMERIC, 2) as avg_review_rating,
    
    -- Sentiment distribution
    COALESCE(sr.positive_reviews, 0) as positive_reviews,
    COALESCE(sr.negative_reviews, 0) as negative_reviews,
    ROUND(
        (COALESCE(sr.positive_reviews, 0)::DECIMAL / NULLIF(COALESCE(sr.published_reviews, 0), 0) * 100)::NUMERIC,
        2
    ) as positive_review_pct,
    
    -- Quality indicators
    COALESCE(sr.flagged_reviews, 0) as flagged_reviews,
    COALESCE(sr.verified_purchase_reviews, 0) as verified_purchase_reviews,
    ROUND(
        (COALESCE(sr.flagged_reviews, 0)::DECIMAL / NULLIF(COALESCE(sr.published_reviews, 0), 0) * 100)::NUMERIC,
        2
    ) as flagged_review_pct,
    
    -- Business metrics
    COALESCE(so.total_orders, 0) as total_orders,
    COALESCE(so.completed_orders, 0) as completed_orders,
    ROUND(COALESCE(so.total_revenue, 0)::NUMERIC, 2) as total_revenue,
    
    -- Review coverage
    ROUND(
        (COALESCE(sr.published_reviews, 0)::DECIMAL / NULLIF(COALESCE(so.completed_orders, 0), 0) * 100)::NUMERIC,
        2
    ) as review_coverage_pct,
    
    -- Reputation tier
    CASE 
        WHEN COALESCE(sr.avg_rating, 0) >= 4.5 AND COALESCE(sr.published_reviews, 0) >= 100 
            THEN '👑 Elite Reputation (4.5+, 100+ reviews)'
        WHEN COALESCE(sr.avg_rating, 0) >= 4.0 AND COALESCE(sr.published_reviews, 0) >= 50 
            THEN '⭐ Excellent Reputation (4.0+, 50+ reviews)'
        WHEN COALESCE(sr.avg_rating, 0) >= 3.5 
            THEN '✅ Good Reputation (3.5+)'
        WHEN COALESCE(sr.avg_rating, 0) >= 3.0 
            THEN '⚠️ Average Reputation (3.0-3.5)'
        WHEN COALESCE(sr.published_reviews, 0) = 0 
            THEN '🆕 New Seller - No Reviews'
        ELSE '🚨 Poor Reputation (<3.0)'
    END as reputation_tier,
    
    -- Risk flags
    CASE 
        WHEN COALESCE(sr.flagged_reviews, 0)::DECIMAL / NULLIF(COALESCE(sr.published_reviews, 0), 0) > 0.1 
            THEN '🚨 High Risk - Many Flagged Reviews (>10%)'
        WHEN COALESCE(sr.avg_rating, 0) < 3.0 AND COALESCE(sr.published_reviews, 0) >= 20 
            THEN '⚠️ Medium Risk - Low Rating'
        WHEN COALESCE(sr.negative_reviews, 0)::DECIMAL / NULLIF(COALESCE(sr.published_reviews, 0), 0) > 0.4 
            THEN '⚠️ Medium Risk - High Negative Rate'
        ELSE '✅ Low Risk'
    END as risk_level,
    
    -- Rankings
    RANK() OVER (ORDER BY COALESCE(sr.avg_rating, 0) DESC, COALESCE(sr.published_reviews, 0) DESC) as reputation_rank
FROM sellers s
JOIN users u ON s.id = u.id
LEFT JOIN seller_reviews sr ON s.id = sr.seller_id
LEFT JOIN seller_products sp ON s.id = sp.seller_id
LEFT JOIN seller_orders so ON s.id = so.seller_id
WHERE u.status = 'active'
ORDER BY COALESCE(sr.published_reviews, 0) DESC, COALESCE(sr.avg_rating, 0) DESC;

-- Expected output: ~100 rows (one per seller)
-- QuickSight Usage: Import as "Seller Reputation" dataset
-- Visualizations: Seller leaderboard, Reputation distribution, Risk matrix

-- Test the view - Top rated sellers
SELECT * FROM v_seller_reputation_analysis 
WHERE published_reviews >= 20
ORDER BY avg_review_rating DESC, published_reviews DESC
LIMIT 20;

-- Test the view - High risk sellers
SELECT * FROM v_seller_reputation_analysis 
WHERE risk_level LIKE '%Risk%' AND risk_level NOT LIKE '%Low Risk%'
ORDER BY flagged_review_pct DESC
LIMIT 20;

-- ============================================================================
-- SECTION 4: REVIEW TRENDS OVER TIME
-- Track how ratings change monthly
-- ============================================================================

CREATE OR REPLACE VIEW v_review_trends_monthly AS
SELECT 
    DATE_TRUNC('month', r.created_at) as month,
    TO_CHAR(r.created_at, 'YYYY-MM') as year_month,
    
    -- Review volume
    COUNT(*) as total_reviews,
    COUNT(CASE WHEN r.status = 'published' THEN 1 END) as published_reviews,
    COUNT(CASE WHEN r.is_verified_purchase THEN 1 END) as verified_purchase_reviews,
    
    -- Rating metrics
    ROUND(AVG(CASE WHEN r.status = 'published' THEN r.rate END)::NUMERIC, 2) as avg_rating,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY CASE WHEN r.status = 'published' THEN r.rate END
    )::NUMERIC, 2) as median_rating,
    
    -- Sentiment distribution
    COUNT(CASE WHEN r.status = 'published' AND r.rate = 5 THEN 1 END) as five_star_reviews,
    COUNT(CASE WHEN r.status = 'published' AND r.rate = 4 THEN 1 END) as four_star_reviews,
    COUNT(CASE WHEN r.status = 'published' AND r.rate = 3 THEN 1 END) as three_star_reviews,
    COUNT(CASE WHEN r.status = 'published' AND r.rate = 2 THEN 1 END) as two_star_reviews,
    COUNT(CASE WHEN r.status = 'published' AND r.rate = 1 THEN 1 END) as one_star_reviews,
    
    -- Engagement
    SUM(r.helpful_count) as total_helpful_votes,
    ROUND(
        (SUM(r.helpful_count)::DECIMAL / NULLIF(COUNT(CASE WHEN r.status = 'published' THEN 1 END), 0))::NUMERIC,
        2
    ) as avg_helpful_votes_per_review,
    
    -- Quality flags
    COUNT(CASE WHEN r.status = 'flagged' THEN 1 END) as flagged_reviews,
    ROUND(
        (COUNT(CASE WHEN r.status = 'flagged' THEN 1 END)::DECIMAL / NULLIF(COUNT(*), 0) * 100)::NUMERIC,
        2
    ) as flagged_review_pct
FROM reviews r
GROUP BY 1, 2
ORDER BY 1 DESC;

-- Expected output: ~24 rows (one per month for 2 years)
-- QuickSight Usage: Import as "Review Trends" dataset
-- Visualizations: Line chart (rating over time), Stacked bar (rating distribution)

-- Test the view
SELECT * FROM v_review_trends_monthly ORDER BY month DESC LIMIT 12;

-- ============================================================================
-- SECTION 5: VERIFIED PURCHASE ANALYSIS
-- Compare verified vs non-verified reviews
-- ============================================================================

CREATE OR REPLACE VIEW v_verified_purchase_analysis AS
WITH verified_stats AS (
    SELECT 
        is_verified_purchase,
        COUNT(*) as review_count,
        AVG(rate) as avg_rating,
        COUNT(CASE WHEN rate >= 4 THEN 1 END) as positive_reviews,
        COUNT(CASE WHEN rate <= 2 THEN 1 END) as negative_reviews,
        SUM(helpful_count) as total_helpful_votes
    FROM reviews
    WHERE status = 'published'
    GROUP BY is_verified_purchase
)
SELECT 
    CASE 
        WHEN is_verified_purchase THEN 'Verified Purchase'
        ELSE 'Not Verified'
    END as purchase_verification_status,
    review_count,
    ROUND(avg_rating::NUMERIC, 2) as avg_rating,
    positive_reviews,
    negative_reviews,
    ROUND((positive_reviews::DECIMAL / NULLIF(review_count, 0) * 100)::NUMERIC, 2) as positive_review_pct,
    ROUND((negative_reviews::DECIMAL / NULLIF(review_count, 0) * 100)::NUMERIC, 2) as negative_review_pct,
    total_helpful_votes,
    ROUND((total_helpful_votes::DECIMAL / NULLIF(review_count, 0))::NUMERIC, 2) as avg_helpful_votes_per_review,
    ROUND((review_count::DECIMAL / (SELECT SUM(review_count) FROM verified_stats) * 100)::NUMERIC, 2) as pct_of_total_reviews
FROM verified_stats
ORDER BY is_verified_purchase DESC;

-- Expected output: 2 rows (Verified vs Not Verified)
-- QuickSight Usage: Import as "Verified Analysis" dataset
-- Visualizations: Comparison table, Pie chart (distribution)

-- Test the view
SELECT * FROM v_verified_purchase_analysis;

-- ============================================================================
-- SECTION 6: REVIEW DASHBOARD SUMMARY
-- KPI summary for review analytics dashboard
-- ============================================================================

CREATE OR REPLACE VIEW v_review_dashboard_summary AS
WITH overall_stats AS (
    SELECT 
        COUNT(*) as total_reviews,
        COUNT(CASE WHEN status = 'published' THEN 1 END) as published_reviews,
        AVG(CASE WHEN status = 'published' THEN rate END) as avg_rating,
        COUNT(CASE WHEN status = 'published' AND rate >= 4 THEN 1 END) as positive_reviews,
        COUNT(CASE WHEN status = 'published' AND rate <= 2 THEN 1 END) as negative_reviews,
        COUNT(CASE WHEN status = 'flagged' THEN 1 END) as flagged_reviews,
        COUNT(CASE WHEN is_verified_purchase THEN 1 END) as verified_reviews
    FROM reviews
),
recent_stats AS (
    SELECT 
        COUNT(*) as reviews_30d,
        AVG(rate) as avg_rating_30d
    FROM reviews
    WHERE created_at >= DATEADD(day, -30, GETDATE())
        AND status = 'published'
),
previous_month_stats AS (
    SELECT 
        AVG(rate) as avg_rating_prev_month
    FROM reviews
    WHERE created_at >= DATEADD(day, -60, GETDATE())
        AND created_at < DATEADD(day, -30, GETDATE())
        AND status = 'published'
)
SELECT 
    os.total_reviews,
    os.published_reviews,
    ROUND(os.avg_rating::NUMERIC, 2) as avg_rating,
    os.positive_reviews,
    os.negative_reviews,
    ROUND((os.positive_reviews::DECIMAL / NULLIF(os.published_reviews, 0) * 100)::NUMERIC, 2) as positive_review_pct,
    ROUND((os.negative_reviews::DECIMAL / NULLIF(os.published_reviews, 0) * 100)::NUMERIC, 2) as negative_review_pct,
    os.flagged_reviews,
    os.verified_reviews,
    ROUND((os.verified_reviews::DECIMAL / NULLIF(os.total_reviews, 0) * 100)::NUMERIC, 2) as verified_purchase_pct,
    
    -- Recent trends
    rs.reviews_30d,
    ROUND(COALESCE(rs.avg_rating_30d, 0)::NUMERIC, 2) as avg_rating_30d,
    ROUND((COALESCE(rs.avg_rating_30d, 0) - pms.avg_rating_prev_month)::NUMERIC, 2) as rating_change_mom,
    
    -- Health status
    CASE 
        WHEN os.avg_rating >= 4.5 THEN '🟢 Excellent Customer Satisfaction'
        WHEN os.avg_rating >= 4.0 THEN '🟡 Good Customer Satisfaction'
        WHEN os.avg_rating >= 3.5 THEN '🟠 Fair Customer Satisfaction'
        ELSE '🔴 Poor Customer Satisfaction'
    END as satisfaction_health_status,
    
    CASE 
        WHEN os.flagged_reviews::DECIMAL / NULLIF(os.published_reviews, 0) > 0.05 
            THEN '🚨 High Flagged Review Rate (>5%)'
        WHEN os.flagged_reviews::DECIMAL / NULLIF(os.published_reviews, 0) > 0.02 
            THEN '⚠️ Moderate Flagged Review Rate (2-5%)'
        ELSE '✅ Low Flagged Review Rate (<2%)'
    END as moderation_status
FROM overall_stats os
CROSS JOIN recent_stats rs
CROSS JOIN previous_month_stats pms;

-- Expected output: 1 row with review KPIs
-- QuickSight Usage: Import as "Review KPIs" dataset
-- Visualizations: KPI cards across dashboard top

-- Test the view
SELECT * FROM v_review_dashboard_summary;

-- ============================================================================
-- SECTION 7: VERIFICATION & FREE TIER OPTIMIZATION
-- ============================================================================

-- List all created review views
SELECT 
    table_name as view_name,
    'View' as object_type
FROM information_schema.views
WHERE table_schema = 'public'
    AND (table_name LIKE 'v_%rating%'
    OR table_name LIKE 'v_%reputation%'
    OR table_name LIKE 'v_review%'
    OR table_name LIKE 'v_verified%')
ORDER BY table_name;

-- Estimate row counts for SPICE import
SELECT 
    'v_product_rating_analysis' as view_name,
    COUNT(*) as estimated_rows,
    'Product quality metrics' as usage
FROM v_product_rating_analysis
UNION ALL
SELECT 
    'v_seller_reputation_analysis',
    COUNT(*),
    'Seller reputation'
FROM v_seller_reputation_analysis
UNION ALL
SELECT 
    'v_review_trends_monthly',
    COUNT(*),
    'Rating trends over time'
FROM v_review_trends_monthly
UNION ALL
SELECT 
    'v_verified_purchase_analysis',
    COUNT(*),
    'Verified vs non-verified'
FROM v_verified_purchase_analysis
UNION ALL
SELECT 
    'v_review_dashboard_summary',
    COUNT(*),
    'KPI cards'
FROM v_review_dashboard_summary;

-- ============================================================================
-- QUICKSIGHT IMPORT RECOMMENDATIONS
-- ============================================================================

/*
FREE TIER OPTIMIZATION TIPS:
1. If reviews table is not loaded, use commodity.rating_avg and seller.rating_avg instead
2. Filter v_product_rating_analysis to show only products with reviews to reduce data
3. Use SPICE for all datasets - estimated total: ~30KB (if reviews loaded)
4. Schedule refresh daily during off-peak hours

ALTERNATIVE IF REVIEWS TABLE NOT LOADED:
- Use commodities.rating_avg for product ratings
- Use commodities.review_count for volume
- Use sellers.rating_avg for seller reputation
- Skip v_review_trends_monthly and v_verified_purchase_analysis

DATASET IMPORT ORDER:
1. v_review_dashboard_summary (1 row)
2. v_product_rating_analysis (filter: published_reviews > 0, ~2000 rows)
3. v_seller_reputation_analysis (~100 rows)
4. v_review_trends_monthly (~24 rows)
5. v_verified_purchase_analysis (2 rows)

VISUALIZATION RECOMMENDATIONS:
Dashboard: "Product Quality & Review Analytics"
├── KPI Cards (v_review_dashboard_summary):
│   ├── Total Reviews
│   ├── Avg Rating
│   ├── Positive Review %
│   ├── Verified Purchase %
│   └── Satisfaction Health Status
├── Histogram (v_product_rating_analysis):
│   ├── X-axis: avg_rating (bins: 1-2, 2-3, 3-4, 4-5)
│   ├── Y-axis: COUNT(commodity_id)
│   └── Title: "Rating Distribution"
├── Table (v_product_rating_analysis):
│   ├── Filter: quality_alert != '✅ Normal'
│   ├── Columns: Product, Avg Rating, Reviews, Quality Alert
│   ├── Conditional: Red for Quality Issue, Orange for Warning
│   └── Sort: By negative_review_pct DESC
├── Bar Chart (v_seller_reputation_analysis):
│   ├── X-axis: seller_name (top 20)
│   ├── Y-axis: avg_review_rating
│   ├── Color: reputation_tier
│   └── Filter: published_reviews >= 10
├── Line Chart (v_review_trends_monthly):
│   ├── X-axis: year_month
│   ├── Y-axis: avg_rating (primary), published_reviews (secondary)
│   ├── Filter: Last 12 months
│   └── Trend line: Enabled
├── Stacked Bar Chart (v_review_trends_monthly):
│   ├── X-axis: year_month
│   ├── Y-axis: COUNT
│   ├── Stack: five_star, four_star, three_star, two_star, one_star
│   └── Colors: Green gradient (5★) to Red (1★)
└── Pie Chart (v_verified_purchase_analysis):
    ├── Values: review_count
    ├── Group: purchase_verification_status
    └── Tooltip: avg_rating, positive_review_pct

FILTERS TO ADD:
- Vertical/Category filter
- Quality tier filter
- Date range (month)
- Verified purchase toggle

CALCULATED FIELDS TO CREATE:
- Net Promoter Score (NPS) = (5★ + 4★) - (1★ + 2★) / Total Reviews
- Review Velocity = reviews_30d / total_reviews
- Quality Score = avg_rating * LOG(review_count + 1)

ALERTS TO CONFIGURE:
- Email when avg_rating < 3.0 for any product with 20+ reviews
- Email when flagged_review_pct > 5%
- Daily digest of products with quality alerts
*/

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================
SELECT 
    '✅ Product Reviews Analysis Views Created Successfully' as status,
    '5 views ready for QuickSight import' as views_created,
    'Estimated SPICE usage: ~30KB' as spice_usage,
    'NOTE: Adjust if reviews table not loaded' as important_note;

-- ============================================================================
-- NOTEBOOK 8: REVIEWS PERFORMANCE COMPARISON (DIST/SORT KEYS vs NONE)
-- Purpose: Compare execution cost on keyed `reviews` (DISTKEY order_id, SORTKEY(created_at, rate))
--          versus a heap AUTO table clone without explicit distribution / sort.
-- ============================================================================

SET enable_result_cache_for_session TO off;

-- Tag queries with /* PERF:REVIEWS_* */ for STL inspection.
-- Capture timings:
-- SELECT query, starttime, endtime,
--        datediff(milliseconds,starttime,endtime) AS ms,
--        regexp_replace(querytxt,'\s+',' ') AS sql
-- FROM stl_query
-- WHERE querytxt LIKE '%PERF:REVIEWS_SIMPLE_KEYED%';

-- =========================================================================
-- SECTION 1: CREATE NO-KEY CLONE TABLE
-- =========================================================================
DROP TABLE IF EXISTS reviews_nokeys;
CREATE TABLE reviews_nokeys AS
SELECT * FROM reviews;
-- OPTIONAL STRUCTURE CHECK
-- SELECT * FROM svv_table_info WHERE table = 'reviews';
-- SELECT * FROM svv_table_info WHERE table = 'reviews_nokeys';

-- =========================================================================
-- SECTION 2: SIMPLE COMBINATION QUERY
-- Goal: Join reviews to commodity & seller context and aggregate recent ratings.
-- =========================================================================
/* PERF:REVIEWS_SIMPLE_KEYED */
SELECT r.commodity_id,
       COUNT(*) AS review_count,
       ROUND(AVG(r.rate)::NUMERIC,2) AS avg_rating,
       SUM(CASE WHEN r.is_verified_purchase THEN 1 ELSE 0 END) AS verified_count
FROM reviews r
JOIN commodities c ON r.commodity_id = c.id
WHERE r.created_at >= DATEADD(day, -30, GETDATE())
  AND r.status = 'published'
GROUP BY r.commodity_id
ORDER BY review_count DESC
LIMIT 50;

/* PERF:REVIEWS_SIMPLE_NOKEYS */
SELECT r.commodity_id,
       COUNT(*) AS review_count,
       ROUND(AVG(r.rate)::NUMERIC,2) AS avg_rating,
       SUM(CASE WHEN r.is_verified_purchase THEN 1 ELSE 0 END) AS verified_count
FROM reviews_nokeys r
JOIN commodities c ON r.commodity_id = c.id
WHERE r.created_at >= DATEADD(day, -30, GETDATE())
  AND r.status = 'published'
GROUP BY r.commodity_id
ORDER BY review_count DESC
LIMIT 50;

-- EXPECTATION: Keyed table leverages SORTKEY(created_at) for date pruning and DISTKEY(order_id) alignment for joins involving orders (not here yet).

-- =========================================================================
-- SECTION 3: COMPLEX COMBINATION QUERY
-- Features: Multi joins (orders, consumers, sellers, commodities, verticals), window ranking,
--           conditional aggregates, median, top-N segmentation.
-- =========================================================================
/* PERF:REVIEWS_COMPLEX_KEYED */
WITH recent_reviews AS (
    SELECT *
    FROM reviews r
    WHERE r.created_at >= DATEADD(month, -6, GETDATE())
      AND r.status = 'published'
), review_context AS (
    SELECT rr.*, o.consumer_id, o.seller_id, o.total_amount, c.vertical_id, c.price, c.cost_price
    FROM recent_reviews rr
    LEFT JOIN orders o ON rr.order_id = o.id
    LEFT JOIN commodities c ON rr.commodity_id = c.id
)
SELECT 
    rc.commodity_id,
    COUNT(*) AS reviews_6m,
    ROUND(AVG(rc.rate)::NUMERIC,2) AS avg_rating_6m,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rc.rate) AS median_rating_6m,
    SUM(CASE WHEN rc.is_verified_purchase THEN 1 ELSE 0 END) AS verified_reviews,
    ROUND(AVG(rc.total_amount)::NUMERIC,2) AS avg_order_value_linked,
    ROUND(SUM(CASE WHEN rc.total_amount IS NOT NULL THEN rc.total_amount ELSE 0 END)::NUMERIC,2) AS linked_revenue,
    COUNT(DISTINCT rc.consumer_id) AS unique_reviewing_consumers,
    COUNT(DISTINCT rc.seller_id) AS unique_sellers_in_reviews,
    COUNT(DISTINCT rc.vertical_id) AS vertical_diversity,
    RANK() OVER (ORDER BY COUNT(*) DESC) AS volume_rank,
    RANK() OVER (ORDER BY AVG(rc.rate) DESC) AS rating_rank
FROM review_context rc
GROUP BY rc.commodity_id
ORDER BY reviews_6m DESC
LIMIT 100;

/* PERF:REVIEWS_COMPLEX_NOKEYS */
WITH recent_reviews AS (
    SELECT *
    FROM reviews_nokeys r
    WHERE r.created_at >= DATEADD(month, -6, GETDATE())
      AND r.status = 'published'
), review_context AS (
    SELECT rr.*, o.consumer_id, o.seller_id, o.total_amount, c.vertical_id, c.price, c.cost_price
    FROM recent_reviews rr
    LEFT JOIN orders o ON rr.order_id = o.id
    LEFT JOIN commodities c ON rr.commodity_id = c.id
)
SELECT 
    rc.commodity_id,
    COUNT(*) AS reviews_6m,
    ROUND(AVG(rc.rate)::NUMERIC,2) AS avg_rating_6m,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rc.rate) AS median_rating_6m,
    SUM(CASE WHEN rc.is_verified_purchase THEN 1 ELSE 0 END) AS verified_reviews,
    ROUND(AVG(rc.total_amount)::NUMERIC,2) AS avg_order_value_linked,
    ROUND(SUM(CASE WHEN rc.total_amount IS NOT NULL THEN rc.total_amount ELSE 0 END)::NUMERIC,2) AS linked_revenue,
    COUNT(DISTINCT rc.consumer_id) AS unique_reviewing_consumers,
    COUNT(DISTINCT rc.seller_id) AS unique_sellers_in_reviews,
    COUNT(DISTINCT rc.vertical_id) AS vertical_diversity,
    RANK() OVER (ORDER BY COUNT(*) DESC) AS volume_rank,
    RANK() OVER (ORDER BY AVG(rc.rate) DESC) AS rating_rank
FROM review_context rc
GROUP BY rc.commodity_id
ORDER BY reviews_6m DESC
LIMIT 100;

-- PLAN & SCAN ANALYSIS
-- EXPLAIN /* PERF:REVIEWS_COMPLEX_KEYED */ SELECT ... (repeat body) to inspect sort pruning & distribution.
-- Example scan comparison:
-- SELECT q.query, q.starttime, datediff(ms,q.starttime,q.endtime) AS ms,
--        s.tbl, s.rows, s.max_blocks_read
-- FROM stl_query q
-- JOIN stl_scan s ON q.query = s.query
-- WHERE q.querytxt LIKE '%PERF:REVIEWS_COMPLEX_KEYED%';

-- CLEANUP (optional)
-- DROP TABLE IF EXISTS reviews_nokeys;
-- ============================================================================

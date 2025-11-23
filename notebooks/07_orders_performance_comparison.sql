-- ============================================================================
-- NOTEBOOK 7: ORDERS PERFORMANCE COMPARISON (DIST/SORT KEYS vs NONE)
-- Purpose: Empirically compare query execution performance between the original
--          keyed fact table `orders` (DISTKEY consumer_id, SORTKEY(created_at, status))
--          and a cloned version without explicit DISTKEY/SORTKEY definitions.
-- ============================================================================

-- SECTION 0: SESSION SETUP (Disable result cache for honest timing)
SET enable_result_cache_for_session TO off;

-- Tag format used for identifying queries in STL_QUERY: /* PERF:LABEL */
-- After running queries, capture timings:
-- SELECT query, starttime, endtime, datediff(milliseconds, starttime, endtime) AS ms,
--        regexp_replace(querytxt,'\s+',' ') AS sql
-- FROM stl_query
-- WHERE userid = current_user_id() AND querytxt LIKE '%PERF:ORDERS_SIMPLE_KEYED%'
-- ORDER BY starttime DESC LIMIT 5;

-- =========================================================================
-- SECTION 1: CREATE NO-KEY CLONE TABLE
-- Approach: CTAS without DISTSTYLE / SORTKEY clauses => Redshift AUTO distribution
--           and no sort key (heap). This isolates effect of defined keys.
-- NOTE: Ensure original `orders` already populated.
-- =========================================================================
DROP TABLE IF EXISTS orders_nokeys;
CREATE TABLE orders_nokeys AS
SELECT * FROM orders;
-- (Optional) COMPARE TABLE DEFINITIONS
-- SELECT * FROM svv_table_info WHERE table = 'orders';
-- SELECT * FROM svv_table_info WHERE table = 'orders_nokeys';

-- =========================================================================
-- SECTION 2: SIMPLE COMBINATION QUERY
-- Goal: Filter + single join + light aggregation over recent time window.
-- =========================================================================
/* PERF:ORDERS_SIMPLE_KEYED */
SELECT o.consumer_id,
       COUNT(*) AS order_count,
       ROUND(SUM(o.total_amount)::NUMERIC,2) AS total_revenue
FROM orders o
JOIN consumers c ON o.consumer_id = c.id
WHERE o.status IN ('delivered','done')
  AND o.created_at >= DATEADD(day, -30, GETDATE())
GROUP BY o.consumer_id
ORDER BY total_revenue DESC
LIMIT 50;

/* PERF:ORDERS_SIMPLE_NOKEYS */
SELECT o.consumer_id,
       COUNT(*) AS order_count,
       ROUND(SUM(o.total_amount)::NUMERIC,2) AS total_revenue
FROM orders_nokeys o
JOIN consumers c ON o.consumer_id = c.id
WHERE o.status IN ('delivered','done')
  AND o.created_at >= DATEADD(day, -30, GETDATE())
GROUP BY o.consumer_id
ORDER BY total_revenue DESC
LIMIT 50;

-- EXPECTATION: Keyed table benefits from SORTKEY(created_at) for range predicate and DISTKEY alignment with frequent join key consumer_id.

-- =========================================================================
-- SECTION 3: COMPLEX COMBINATION QUERY
-- Features: Multiple joins, window functions, conditional aggregates, date filtering.
-- =========================================================================
/* PERF:ORDERS_COMPLEX_KEYED */
WITH recent_orders AS (
    SELECT *
    FROM orders o
    WHERE o.created_at >= DATEADD(month, -6, GETDATE())
      AND o.status IN ('delivered','done')
), line_items AS (
    SELECT oc.order_id, oc.commodity_id, oc.quantity, oc.line_total
    FROM order_commodities oc
    JOIN recent_orders ro ON oc.order_id = ro.id
), commodity_info AS (
    SELECT c.id, c.vertical_id, c.price, c.cost_price
    FROM commodities c
), consumer_order_values AS (
    SELECT ro.consumer_id, ro.id AS order_id, ro.total_amount
    FROM recent_orders ro
), agg_core AS (
    SELECT 
        ro.consumer_id,
        COUNT(DISTINCT ro.id) AS orders_6m,
        SUM(li.quantity) AS units_6m,
        SUM(li.line_total) AS revenue_6m,
        SUM(li.quantity * (ci.price - ci.cost_price)) AS est_margin_6m,
        AVG(ro.total_amount) AS avg_order_value
    FROM recent_orders ro
    JOIN line_items li ON ro.id = li.order_id
    JOIN commodity_info ci ON li.commodity_id = ci.id
    GROUP BY ro.consumer_id
), median_per_consumer AS (
    SELECT DISTINCT consumer_id,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_amount)
          OVER (PARTITION BY consumer_id) AS median_order_value
    FROM consumer_order_values
), distinct_verticals AS (
    SELECT ro.consumer_id,
           COUNT(DISTINCT ci.vertical_id) AS distinct_verticals
    FROM recent_orders ro
    JOIN line_items li ON ro.id = li.order_id
    JOIN commodity_info ci ON li.commodity_id = ci.id
    GROUP BY ro.consumer_id
)
SELECT 
    a.consumer_id,
    a.orders_6m,
    a.units_6m,
    ROUND(a.revenue_6m::NUMERIC,2) AS revenue_6m,
    ROUND(a.est_margin_6m::NUMERIC,2) AS est_margin_6m,
    ROUND(a.avg_order_value::NUMERIC,2) AS avg_order_value,
    m.median_order_value,
    RANK() OVER (ORDER BY a.revenue_6m DESC) AS revenue_rank,
    d.distinct_verticals
FROM agg_core a
JOIN median_per_consumer m ON a.consumer_id = m.consumer_id
JOIN distinct_verticals d ON a.consumer_id = d.consumer_id
ORDER BY revenue_6m DESC
LIMIT 100;

/* PERF:ORDERS_COMPLEX_NOKEYS */
WITH recent_orders AS (
    SELECT *
    FROM orders_nokeys o
    WHERE o.created_at >= DATEADD(month, -6, GETDATE())
      AND o.status IN ('delivered','done')
), line_items AS (
    SELECT oc.order_id, oc.commodity_id, oc.quantity, oc.line_total
    FROM order_commodities oc
    JOIN recent_orders ro ON oc.order_id = ro.id
), commodity_info AS (
    SELECT c.id, c.vertical_id, c.price, c.cost_price
    FROM commodities c
), consumer_order_values AS (
    SELECT ro.consumer_id, ro.id AS order_id, ro.total_amount
    FROM recent_orders ro
), agg_core AS (
    SELECT 
        ro.consumer_id,
        COUNT(DISTINCT ro.id) AS orders_6m,
        SUM(li.quantity) AS units_6m,
        SUM(li.line_total) AS revenue_6m,
        SUM(li.quantity * (ci.price - ci.cost_price)) AS est_margin_6m,
        AVG(ro.total_amount) AS avg_order_value
    FROM recent_orders ro
    JOIN line_items li ON ro.id = li.order_id
    JOIN commodity_info ci ON li.commodity_id = ci.id
    GROUP BY ro.consumer_id
), median_per_consumer AS (
    SELECT DISTINCT consumer_id,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_amount)
          OVER (PARTITION BY consumer_id) AS median_order_value
    FROM consumer_order_values
), distinct_verticals AS (
    SELECT ro.consumer_id,
           COUNT(DISTINCT ci.vertical_id) AS distinct_verticals
    FROM recent_orders ro
    JOIN line_items li ON ro.id = li.order_id
    JOIN commodity_info ci ON li.commodity_id = ci.id
    GROUP BY ro.consumer_id
)
SELECT 
    a.consumer_id,
    a.orders_6m,
    a.units_6m,
    ROUND(a.revenue_6m::NUMERIC,2) AS revenue_6m,
    ROUND(a.est_margin_6m::NUMERIC,2) AS est_margin_6m,
    ROUND(a.avg_order_value::NUMERIC,2) AS avg_order_value,
    m.median_order_value,
    RANK() OVER (ORDER BY a.revenue_6m DESC) AS revenue_rank,
    d.distinct_verticals
FROM agg_core a
JOIN median_per_consumer m ON a.consumer_id = m.consumer_id
JOIN distinct_verticals d ON a.consumer_id = d.consumer_id
ORDER BY revenue_6m DESC
LIMIT 100;

-- NOTES:
-- 1. Expect higher scan / shuffle for no-key version.
-- 2. Use EXPLAIN for plan differences:
--    EXPLAIN /* PERF:ORDERS_COMPLEX_KEYED */ SELECT ... (repeat query body).
-- 3. Compare svl_qlog & stl_scan performance:
--    SELECT q.query, q.starttime, q.endtime, datediff(ms,q.starttime,q.endtime) AS ms,
--           s.tbl, s.rows, s.max_blocks_read
--    FROM stl_query q
--    JOIN stl_scan s ON q.query = s.query
--    WHERE q.querytxt LIKE '%PERF:ORDERS_COMPLEX_KEYED%';

-- CLEANUP (optional)
-- DROP TABLE IF EXISTS orders_nokeys;
-- ============================================================================

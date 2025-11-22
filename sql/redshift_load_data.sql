-- ============================================================================
-- REDSHIFT DATA LOADING SCRIPT
-- ============================================================================

-- Set session parameters for better error visibility
SET enable_result_cache_for_session TO OFF;

-- ============================================================================
-- TABLE 1: USERS (Base table - MUST load first)
-- ============================================================================
COPY users FROM 's3://amzn-s3-url/csv_time_stamp/users.csv'
IAM_ROLE 'arn:aws:iam::your_aws_id:role/redshift_IAM_role'
DELIMITER '|'
CSV
IGNOREHEADER 1
TIMEFORMAT 'auto'
DATEFORMAT 'auto'
EMPTYASNULL
BLANKSASNULL
MAXERROR 10
REGION 'ap-southeast-1';

-- Verify
SELECT 'users' as table_name, COUNT(*) as row_count FROM users;

-- ============================================================================
-- TABLE 2: CONSUMERS (Depends on users)
-- ============================================================================
COPY consumers FROM 's3://amzn-s3-url/csv_time_stamp/consumers.csv'
IAM_ROLE 'arn:aws:iam::your_aws_id:role/redshift_IAM_role'
DELIMITER '|'
CSV
IGNOREHEADER 1
DATEFORMAT 'auto'
EMPTYASNULL
BLANKSASNULL
MAXERROR 10
REGION 'ap-southeast-1';

-- Verify
SELECT 'consumers' as table_name, COUNT(*) as row_count FROM consumers;

-- ============================================================================
-- TABLE 3: SELLERS (Depends on users)
-- ============================================================================
COPY sellers FROM 's3://amzn-s3-url/csv_time_stamp/sellers.csv'
IAM_ROLE 'arn:aws:iam::your_aws_id:role/redshift_IAM_role'
DELIMITER '|'
CSV
IGNOREHEADER 1
EMPTYASNULL
BLANKSASNULL
MAXERROR 10
REGION 'ap-southeast-1';

-- Verify
SELECT 'sellers' as table_name, COUNT(*) as row_count FROM sellers;

-- ============================================================================
-- TABLE 4: VERTICALS (No dependencies)
-- ============================================================================
COPY verticals FROM 's3://amzn-s3-url/csv_time_stamp/verticals.csv'
IAM_ROLE 'arn:aws:iam::your_aws_id:role/redshift_IAM_role'
DELIMITER '|'
CSV
IGNOREHEADER 1
EMPTYASNULL
BLANKSASNULL
MAXERROR 10
REGION 'ap-southeast-1';

-- Verify
SELECT 'verticals' as table_name, COUNT(*) as row_count FROM verticals;

-- ============================================================================
-- TABLE 5: SELLER_VERTICAL (Junction table)
-- ============================================================================
COPY seller_vertical FROM 's3://amzn-s3-url/csv_time_stamp/seller_vertical.csv'
IAM_ROLE 'arn:aws:iam::your_aws_id:role/redshift_IAM_role'
DELIMITER '|'
CSV
IGNOREHEADER 1
TIMEFORMAT 'auto'
EMPTYASNULL
BLANKSASNULL
MAXERROR 10
REGION 'ap-southeast-1';

-- Verify
SELECT 'seller_vertical' as table_name, COUNT(*) as row_count FROM seller_vertical;

-- ============================================================================
-- TABLE 6: ADDRESS_BOOKS
-- ============================================================================
COPY address_books FROM 's3://amzn-s3-url/csv_time_stamp/address_books.csv'
IAM_ROLE 'arn:aws:iam::your_aws_id:role/redshift_IAM_role'
DELIMITER '|'
CSV
IGNOREHEADER 1
TIMEFORMAT 'auto'
EMPTYASNULL
BLANKSASNULL
MAXERROR 10
REGION 'ap-southeast-1';

-- Verify
SELECT 'address_books' as table_name, COUNT(*) as row_count FROM address_books;

-- ============================================================================
-- TABLE 7: CARDS
-- ============================================================================
COPY cards FROM 's3://amzn-s3-url/csv_time_stamp/cards.csv'
IAM_ROLE 'arn:aws:iam::your_aws_id:role/redshift_IAM_role'
DELIMITER '|'
CSV
IGNOREHEADER 1
TIMEFORMAT 'auto'
EMPTYASNULL
BLANKSASNULL
MAXERROR 10
REGION 'ap-southeast-1';

-- Verify
SELECT 'cards' as table_name, COUNT(*) as row_count FROM cards;

-- ============================================================================
-- TABLE 8: COMMODITIES (Products)
-- ============================================================================
COPY commodities FROM 's3://amzn-s3-url/csv_time_stamp/commodities.csv'
IAM_ROLE 'arn:aws:iam::your_aws_id:role/redshift_IAM_role'
DELIMITER '|'
CSV
IGNOREHEADER 1
TIMEFORMAT 'auto'
EMPTYASNULL
BLANKSASNULL
MAXERROR 10
REGION 'ap-southeast-1';

-- Verify
SELECT 'commodities' as table_name, COUNT(*) as row_count FROM commodities;

-- ============================================================================
-- TABLE 9: ORDERS (Critical fact table)
-- ============================================================================
COPY orders FROM 's3://amzn-s3-url/csv_time_stamp/orders.csv'
IAM_ROLE 'arn:aws:iam::your_aws_id:role/redshift_IAM_role'
DELIMITER '|'
CSV
IGNOREHEADER 1
TIMEFORMAT 'auto'
EMPTYASNULL
BLANKSASNULL
MAXERROR 10
REGION 'ap-southeast-1';

-- Verify
SELECT 'orders' as table_name, COUNT(*) as row_count FROM orders;

-- ============================================================================
-- TABLE 10: ORDER_COMMODITIES (Line items)
-- ============================================================================
COPY order_commodities FROM 's3://amzn-s3-url/csv_time_stamp/order_commodities.csv'
IAM_ROLE 'arn:aws:iam::your_aws_id:role/redshift_IAM_role'
DELIMITER '|'
CSV
IGNOREHEADER 1
EMPTYASNULL
BLANKSASNULL
MAXERROR 10
REGION 'ap-southeast-1';

-- Verify
SELECT 'order_commodities' as table_name, COUNT(*) as row_count FROM order_commodities;

-- ============================================================================
-- TABLE 11: TRANSACTIONS
-- ============================================================================
COPY transactions FROM 's3://amzn-s3-url/csv_time_stamp/transactions.csv'
IAM_ROLE 'arn:aws:iam::your_aws_id:role/redshift_IAM_role'
DELIMITER '|'
CSV
IGNOREHEADER 1
TIMEFORMAT 'auto'
EMPTYASNULL
BLANKSASNULL
MAXERROR 10
REGION 'ap-southeast-1';

-- Verify
SELECT 'transactions' as table_name, COUNT(*) as row_count FROM transactions;

-- ============================================================================
-- TABLE 12: REVIEWS
-- ============================================================================
COPY reviews FROM 's3://amzn-s3-url/csv_time_stamp/reviews.csv'
IAM_ROLE 'arn:aws:iam::your_aws_id:role/redshift_IAM_role'
DELIMITER '|'
CSV
IGNOREHEADER 1
TIMEFORMAT 'auto'
EMPTYASNULL
BLANKSASNULL
MAXERROR 10
REGION 'ap-southeast-1';

-- Verify
SELECT 'reviews' as table_name, COUNT(*) as row_count FROM reviews;

-- ============================================================================
-- FINAL VERIFICATION - All Tables
-- ============================================================================
SELECT 'users' as table_name, COUNT(*) as count FROM users
UNION ALL
SELECT 'consumers', COUNT(*) FROM consumers
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL
SELECT 'verticals', COUNT(*) FROM verticals
UNION ALL
SELECT 'seller_vertical', COUNT(*) FROM seller_vertical
UNION ALL
SELECT 'address_books', COUNT(*) FROM address_books
UNION ALL
SELECT 'commodities', COUNT(*) FROM commodities
UNION ALL
SELECT 'cards', COUNT(*) FROM cards
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_commodities', COUNT(*) FROM order_commodities
UNION ALL
SELECT 'transactions', COUNT(*) FROM transactions
UNION ALL
SELECT 'reviews', COUNT(*) FROM reviews
ORDER BY table_name;

-- ============================================================================
-- DATA QUALITY CHECKS
-- ============================================================================

-- Check for NULL consumer_ids in orders (should be 0)
SELECT 'NULL consumer check' as check_name, COUNT(*) as issue_count 
FROM orders 
WHERE consumer_id IS NULL;

-- Check for orphaned consumers (should be 0)
SELECT 'Orphaned consumers' as check_name, COUNT(*) as issue_count
FROM consumers c
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.id = c.id);

-- Check for orphaned orders (should be 0)
SELECT 'Orphaned orders' as check_name, COUNT(*) as issue_count
FROM orders o
WHERE NOT EXISTS (SELECT 1 FROM consumers c WHERE c.id = o.consumer_id);

-- Sample revenue data (should show actual numbers)
SELECT 
    DATE_TRUNC('month', created_at) as month,
    COUNT(*) as order_count,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_order_value
FROM orders
WHERE status IN ('delivered', 'done')
GROUP BY 1
ORDER BY 1 DESC
LIMIT 12;

-- ============================================================================
-- PERFORMANCE CHECK - Table Distribution
-- ============================================================================

-- Check how data is distributed across slices
SELECT 
    TRIM(name) as table_name,
    slice,
    COUNT(*) as rows_on_slice
FROM STV_BLOCKLIST
WHERE name IN ('orders', 'consumers', 'commodities')
GROUP BY 1, 2
ORDER BY 1, 2;

-- Check table sizes
SELECT 
    TRIM(name) as table_name,
    COUNT(DISTINCT slice) as num_slices,
    SUM(rows) as total_rows,
    SUM(bytes) / 1024 / 1024 as size_mb
FROM STV_BLOCKLIST
WHERE name IN ('users', 'consumers', 'sellers', 'orders', 'commodities')
GROUP BY 1
ORDER BY 4 DESC;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================

SELECT '🎉 DATA LOADING COMPLETED SUCCESSFULLY! 🎉' as status,
       'All tables loaded and verified' as message,
       'Ready for analytics queries' as next_step;

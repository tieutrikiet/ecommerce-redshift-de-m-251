-- ============================================================================
-- AWS REDSHIFT
-- E-Commerce Simulator
-- ============================================================================

-- ============================================================================
-- BASE TABLE: Users
-- ============================================================================

CREATE TABLE users (
    id VARCHAR(36) NOT NULL,
    username VARCHAR(255) NOT NULL ENCODE ZSTD,
    phone VARCHAR(15) NOT NULL ENCODE ZSTD,
    name VARCHAR(100) NOT NULL ENCODE ZSTD,
    email VARCHAR(255) NOT NULL ENCODE ZSTD,
    status VARCHAR(20) DEFAULT 'active' ENCODE BYTEDICT,
    created_at TIMESTAMP ENCODE ZSTD,
    updated_at TIMESTAMP ENCODE ZSTD,
    
    PRIMARY KEY (id),
    UNIQUE (username),
    UNIQUE (phone),
    UNIQUE (email)
)
DISTSTYLE ALL
SORTKEY (created_at);

COMMENT ON TABLE users IS 'Base user table - parent of consumers and sellers';

-- ============================================================================
-- DIMENSION TABLE: Consumers
-- ============================================================================

CREATE TABLE consumers (
    id VARCHAR(36) NOT NULL,
    birthday DATE ENCODE ZSTD,
    gender VARCHAR(20) ENCODE BYTEDICT,
    first_order_date DATE ENCODE ZSTD,
    total_orders INTEGER DEFAULT 0 ENCODE ZSTD,
    total_spent NUMERIC(12,2) DEFAULT 0.00 ENCODE ZSTD,
    customer_segment VARCHAR(20) ENCODE BYTEDICT,
    
    PRIMARY KEY (id),
    FOREIGN KEY (id) REFERENCES users(id)
)
DISTSTYLE ALL
SORTKEY (customer_segment, total_spent);

COMMENT ON TABLE consumers IS 'Consumer profile extending users table';

-- ============================================================================
-- DIMENSION TABLE: Sellers
-- ============================================================================

CREATE TABLE sellers (
    id VARCHAR(36) NOT NULL,
    type VARCHAR(20) NOT NULL ENCODE BYTEDICT,
    introduction TEXT ENCODE ZSTD,
    address VARCHAR(255) ENCODE ZSTD,
    city VARCHAR(50) ENCODE BYTEDICT,
    province VARCHAR(50) ENCODE BYTEDICT,
    country VARCHAR(30) ENCODE BYTEDICT,
    rating_avg NUMERIC(3,2) ENCODE ZSTD,
    total_sales NUMERIC(14,2) DEFAULT 0.00 ENCODE ZSTD,
    total_orders INTEGER DEFAULT 0 ENCODE ZSTD,
    
    PRIMARY KEY (id),
    FOREIGN KEY (id) REFERENCES users(id)
)
DISTSTYLE ALL
SORTKEY (total_sales);

COMMENT ON TABLE sellers IS 'Seller profile extending users table';

-- ============================================================================
-- DIMENSION TABLE: Verticals (Product Categories)
-- ============================================================================

CREATE TABLE verticals (
    id VARCHAR(36) NOT NULL,
    name VARCHAR(100) NOT NULL ENCODE ZSTD,
    description TEXT ENCODE ZSTD,
    status VARCHAR(20) NOT NULL DEFAULT 'active' ENCODE BYTEDICT,
    parent_id VARCHAR(36) ENCODE ZSTD,
    level INTEGER DEFAULT 1 ENCODE ZSTD,
    
    PRIMARY KEY (id),
    UNIQUE (name)
    -- Note: Self-referencing FK removed to allow loading from verticals_master.csv
    -- All parent_id values are NULL in current implementation (flat hierarchy)
    -- FOREIGN KEY (parent_id) REFERENCES verticals(id)
)
DISTSTYLE ALL
SORTKEY (name);

COMMENT ON TABLE verticals IS 'Product category hierarchy (currently flat, all parent_id are NULL)';

-- ============================================================================
-- JUNCTION TABLE: Seller-Vertical
-- ============================================================================

CREATE TABLE seller_vertical (
    seller_id VARCHAR(36) NOT NULL,
    vertical_id VARCHAR(36) NOT NULL,
    created_at TIMESTAMP ENCODE ZSTD,
    updated_at TIMESTAMP ENCODE ZSTD,
    
    PRIMARY KEY (seller_id, vertical_id),
    FOREIGN KEY (seller_id) REFERENCES sellers(id),
    FOREIGN KEY (vertical_id) REFERENCES verticals(id)
)
DISTSTYLE ALL;

COMMENT ON TABLE seller_vertical IS 'Many-to-many relationship between sellers and verticals';

-- ============================================================================
-- DIMENSION TABLE: Address Books
-- ============================================================================

CREATE TABLE address_books (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    address_line_1 VARCHAR(100) NOT NULL ENCODE ZSTD,
    address_line_2 VARCHAR(100) ENCODE ZSTD,
    city VARCHAR(50) NOT NULL ENCODE BYTEDICT,
    province VARCHAR(50) NOT NULL ENCODE BYTEDICT,
    country VARCHAR(30) NOT NULL ENCODE BYTEDICT,
    postal_code VARCHAR(10) ENCODE ZSTD,
    phone VARCHAR(15) NOT NULL ENCODE ZSTD,
    receiver_name VARCHAR(100) NOT NULL ENCODE ZSTD,
    is_default BOOLEAN DEFAULT FALSE ENCODE RAW,
    latitude NUMERIC(10,7) ENCODE ZSTD,
    longitude NUMERIC(10,7) ENCODE ZSTD,
    created_at TIMESTAMP ENCODE ZSTD,
    updated_at TIMESTAMP ENCODE ZSTD,
    
    PRIMARY KEY (id),
    FOREIGN KEY (user_id) REFERENCES users(id)
)
DISTKEY (user_id)
SORTKEY (user_id, country);

COMMENT ON TABLE address_books IS 'User shipping/billing addresses with geolocation';

-- ============================================================================
-- DIMENSION TABLE: Commodities (Products)
-- ============================================================================

CREATE TABLE commodities (
    id VARCHAR(36) NOT NULL,
    seller_id VARCHAR(36) NOT NULL,
    sku VARCHAR(50) NOT NULL ENCODE ZSTD,
    name VARCHAR(255) NOT NULL ENCODE ZSTD,
    price NUMERIC(10,2) NOT NULL ENCODE ZSTD,
    cost_price NUMERIC(10,2) ENCODE ZSTD,
    quantity INTEGER NOT NULL DEFAULT 0 ENCODE ZSTD,
    reserved_quantity INTEGER DEFAULT 0 ENCODE ZSTD,
    reorder_level INTEGER DEFAULT 10 ENCODE ZSTD,
    reorder_quantity INTEGER DEFAULT 100 ENCODE ZSTD,
    weight_kg NUMERIC(8,2) ENCODE ZSTD,
    description TEXT ENCODE ZSTD,
    technical_info TEXT ENCODE ZSTD,
    guarantee_info TEXT ENCODE ZSTD,
    manufacturer_name VARCHAR(100) ENCODE ZSTD,
    vertical_id VARCHAR(36) NOT NULL,
    status VARCHAR(20) DEFAULT 'available' ENCODE BYTEDICT,
    rating_avg NUMERIC(3,2) ENCODE ZSTD,
    review_count INTEGER DEFAULT 0 ENCODE ZSTD,
    total_sold INTEGER DEFAULT 0 ENCODE ZSTD,
    created_at TIMESTAMP ENCODE ZSTD,
    updated_at TIMESTAMP ENCODE ZSTD,
    
    PRIMARY KEY (id),
    UNIQUE (sku),
    FOREIGN KEY (seller_id) REFERENCES sellers(id),
    FOREIGN KEY (vertical_id) REFERENCES verticals(id)
)
DISTKEY (seller_id)
SORTKEY (vertical_id, created_at);

COMMENT ON TABLE commodities IS 'Product catalog with inventory and seller information';

-- ============================================================================
-- DIMENSION TABLE: Payment Cards
-- ============================================================================

CREATE TABLE cards (
    id VARCHAR(36) NOT NULL,
    consumer_id VARCHAR(36) NOT NULL,
    tk VARCHAR(255) NOT NULL ENCODE ZSTD,
    provider VARCHAR(20) NOT NULL ENCODE BYTEDICT,
    last4 VARCHAR(4) NOT NULL ENCODE ZSTD,
    card_holder VARCHAR(100) NOT NULL ENCODE ZSTD,
    exp_year INTEGER NOT NULL ENCODE ZSTD,
    exp_month INTEGER NOT NULL ENCODE ZSTD,
    status VARCHAR(20) NOT NULL DEFAULT 'active' ENCODE BYTEDICT,
    is_default BOOLEAN DEFAULT FALSE ENCODE RAW,
    created_at TIMESTAMP ENCODE ZSTD,
    updated_at TIMESTAMP ENCODE ZSTD,
    
    PRIMARY KEY (id),
    FOREIGN KEY (consumer_id) REFERENCES consumers(id)
)
DISTKEY (consumer_id)
SORTKEY (consumer_id, status);

COMMENT ON TABLE cards IS 'Consumer payment methods - must belong to actual consumers';

-- ============================================================================
-- FACT TABLE: Orders
-- ============================================================================

CREATE TABLE orders (
    id VARCHAR(36) NOT NULL,
    consumer_id VARCHAR(36) NOT NULL,
    seller_id VARCHAR(36) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' ENCODE BYTEDICT,
    delivery_address VARCHAR(255) NOT NULL ENCODE ZSTD,
    delivery_postal_code VARCHAR(10) ENCODE ZSTD,
    delivery_receiver VARCHAR(100) NOT NULL ENCODE ZSTD,
    delivery_phone VARCHAR(15) NOT NULL ENCODE ZSTD,
    delivery_city VARCHAR(50) NOT NULL ENCODE BYTEDICT,
    delivery_country VARCHAR(30) NOT NULL ENCODE BYTEDICT,
    delivery_latitude NUMERIC(10,7) ENCODE ZSTD,
    delivery_longitude NUMERIC(10,7) ENCODE ZSTD,
    subtotal_amount NUMERIC(10,2) NOT NULL ENCODE ZSTD,
    tax_amount NUMERIC(10,2) DEFAULT 0.00 ENCODE ZSTD,
    shipping_fee NUMERIC(10,2) DEFAULT 0.00 ENCODE ZSTD,
    discount_amount NUMERIC(10,2) DEFAULT 0.00 ENCODE ZSTD,
    total_amount NUMERIC(10,2) NOT NULL ENCODE ZSTD,
    created_at TIMESTAMP ENCODE ZSTD,
    confirmed_at TIMESTAMP ENCODE ZSTD,
    paid_at TIMESTAMP ENCODE ZSTD,
    shipped_at TIMESTAMP ENCODE ZSTD,
    delivered_at TIMESTAMP ENCODE ZSTD,
    completed_at TIMESTAMP ENCODE ZSTD,
    updated_at TIMESTAMP ENCODE ZSTD,
    days_to_ship INTEGER ENCODE ZSTD,
    days_to_deliver INTEGER ENCODE ZSTD,
    
    PRIMARY KEY (id),
    FOREIGN KEY (consumer_id) REFERENCES consumers(id),
    FOREIGN KEY (seller_id) REFERENCES sellers(id)
)
DISTKEY (consumer_id)
SORTKEY (created_at, status);

COMMENT ON TABLE orders IS 'Core order fact table with calculated amounts from line items';

-- ============================================================================
-- FACT TABLE: Order Line Items (Order-Commodity Junction)
-- ============================================================================

CREATE TABLE order_commodities (
    order_id VARCHAR(36) NOT NULL,
    commodity_id VARCHAR(36) NOT NULL,
    quantity INTEGER NOT NULL ENCODE ZSTD,
    unit_price NUMERIC(10,2) NOT NULL ENCODE ZSTD,
    unit_cost NUMERIC(10,2) ENCODE ZSTD,
    line_total NUMERIC(10,2) NOT NULL ENCODE ZSTD,
    discount_applied NUMERIC(10,2) DEFAULT 0.00 ENCODE ZSTD,
    
    PRIMARY KEY (order_id, commodity_id),
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (commodity_id) REFERENCES commodities(id)
)
DISTKEY (order_id)
SORTKEY (order_id);

COMMENT ON TABLE order_commodities IS 'Order line items - source of truth for order amounts';

-- ============================================================================
-- FACT TABLE: Transactions
-- ============================================================================

CREATE TABLE transactions (
    id VARCHAR(36) NOT NULL,
    order_id VARCHAR(36) NOT NULL,
    card_id VARCHAR(36),
    payment_method VARCHAR(20) NOT NULL ENCODE BYTEDICT,
    transaction_type VARCHAR(20) NOT NULL ENCODE BYTEDICT,
    amount NUMERIC(10,2) NOT NULL ENCODE ZSTD,
    status VARCHAR(20) DEFAULT 'pending' ENCODE BYTEDICT,
    created_at TIMESTAMP ENCODE ZSTD,
    authorized_at TIMESTAMP ENCODE ZSTD,
    completed_at TIMESTAMP ENCODE ZSTD,
    gateway_transaction_id VARCHAR(100) ENCODE ZSTD,
    gateway_response_code VARCHAR(50) ENCODE ZSTD,
    gateway_response_message VARCHAR(255) ENCODE ZSTD,
    ip_address VARCHAR(45) ENCODE ZSTD,
    user_agent VARCHAR(255) ENCODE ZSTD,
    
    PRIMARY KEY (id),
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (card_id) REFERENCES cards(id)
)
DISTKEY (order_id)
SORTKEY (created_at, status);

COMMENT ON TABLE transactions IS 'Payment transactions with gateway details';

-- ============================================================================
-- FACT TABLE: Reviews
-- ============================================================================

CREATE TABLE reviews (
    id VARCHAR(36) NOT NULL,
    order_id VARCHAR(36) NOT NULL,
    commodity_id VARCHAR(36),
    consumer_id VARCHAR(36) NOT NULL,
    seller_id VARCHAR(36) NOT NULL,
    rate INTEGER NOT NULL ENCODE ZSTD,
    comment TEXT ENCODE ZSTD,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' ENCODE BYTEDICT,
    is_verified_purchase BOOLEAN DEFAULT TRUE ENCODE RAW,
    helpful_count INTEGER DEFAULT 0 ENCODE ZSTD,
    created_at TIMESTAMP ENCODE ZSTD,
    updated_at TIMESTAMP ENCODE ZSTD,
    published_at TIMESTAMP ENCODE ZSTD,
    
    PRIMARY KEY (id),
    UNIQUE (order_id),
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (commodity_id) REFERENCES commodities(id),
    FOREIGN KEY (consumer_id) REFERENCES consumers(id),
    FOREIGN KEY (seller_id) REFERENCES sellers(id)
    -- Note: CHECK constraints not supported in Redshift
    -- Rate validation (1-5) should be enforced at application level
)
DISTKEY (order_id)
SORTKEY (created_at, rate);

COMMENT ON TABLE reviews IS 'Customer reviews tied to orders - rate should be 1-5 (enforced in app)';

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify table creation
SELECT 
    tablename, 
    'Created' as status
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;

-- ============================================================================
-- DATA LOADING NOTES
-- ============================================================================
-- 
-- CORRECT LOADING ORDER (respects foreign key dependencies):
-- 1. users (base table, no dependencies)
-- 2. consumers, sellers (depend on users)
-- 3. verticals (self-referencing, load parents first)
-- 4. seller_vertical (depends on sellers + verticals)
-- 5. address_books (depends on users)
-- 6. cards (depends on consumers)
-- 7. commodities (depends on sellers + verticals)
-- 8. orders (depends on consumers + sellers)
-- 9. order_commodities (depends on orders + commodities)
-- 10. transactions (depends on orders + cards)
-- 11. reviews (depends on orders + commodities + consumers + sellers)
--
-- ============================================================================
-- REDSHIFT COPY COMMAND TEMPLATE
-- ============================================================================
--
-- COPY users FROM 's3://your-bucket/data/users.csv'
-- IAM_ROLE 'arn:aws:iam::ACCOUNT:role/RedshiftS3ReadRole'
-- DELIMITER '|'
-- IGNOREHEADER 1
-- TIMEFORMAT 'auto'
-- EMPTYASNULL
-- BLANKSASNULL
-- REGION 'us-east-1';
--
-- Repeat for all tables in the order above.
-- Add EMPTYASNULL and BLANKSASNULL to handle empty strings as NULL.
-- ============================================================================
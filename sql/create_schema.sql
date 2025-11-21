-- ============================================================================
-- ENUMS
-- ============================================================================

CREATE TYPE "status" AS ENUM (
  'active',
  'inactive',
  'deleted'
);

CREATE TYPE "order_status" AS ENUM (
  'draft',
  'inprogress',
  'pending',
  'shipped',
  'delivered',
  'done',
  'cancelled',
  'abandoned'
);

CREATE TYPE "trans_status" AS ENUM (
  'draft',
  'authorized',
  'captured',
  'failed',
  'refunded',
  'cancelled'
);

CREATE TYPE "trans_type" AS ENUM (
  'payment',
  'refund',
  'adjustment',
  'installment'
);

CREATE TYPE "gender" AS ENUM (
  'male',
  'female',
  'prefer not to say',
  'undefined'
);

CREATE TYPE "seller_type" AS ENUM (
  'vendor',
  'authorized'
);

CREATE TYPE "commodity_status" AS ENUM (
  'available',
  'unavailable',
  'out of stock',
  'discontinued'
);

CREATE TYPE "review_status" AS ENUM (
  'draft',
  'published',
  'deleted',
  'flagged'
);

CREATE TYPE "card_provider" AS ENUM (
  'visa',
  'mastercard',
  'jcb',
  'diners',
  'american_express',
  'discover',
  'unionpay'
);

CREATE TYPE "card_status" AS ENUM (
  'active',
  'inactive',
  'expired',
  'anomaly',
  'fraud'
);

CREATE TYPE "payment_method" AS ENUM (
  'card',
  'cod',
  'apple_pay',
  'g_pay',
  's_pay',
  'paypal',
  'bank_transfer'
);

-- ============================================================================
-- TABLES (in dependency order)
-- ============================================================================

-- 1. Users (base table - no dependencies)
CREATE TABLE "users" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "username" varchar(255) UNIQUE NOT NULL,
  "phone" varchar(15) UNIQUE NOT NULL,
  "name" varchar(100) NOT NULL,
  "email" varchar(255) UNIQUE NOT NULL,
  "status" status DEFAULT 'active',
  "created_at" timestamp DEFAULT (now()),
  "updated_at" timestamp DEFAULT (now())
);

-- 2. Consumers (depends on users)
CREATE TABLE "consumers" (
  "id" uuid PRIMARY KEY,
  "birthday" date,
  "gender" gender DEFAULT 'undefined',
  "first_order_date" date,
  "total_orders" integer DEFAULT 0,
  "total_spent" decimal(12,2) DEFAULT 0,
  "customer_segment" varchar(20),
  CONSTRAINT "fk_consumer_user" FOREIGN KEY ("id") REFERENCES "users" ("id") ON DELETE CASCADE
);

-- 3. Sellers (depends on users)
CREATE TABLE "sellers" (
  "id" uuid PRIMARY KEY,
  "type" seller_type NOT NULL DEFAULT 'vendor',
  "introduction" text,
  "address" varchar(255),
  "city" varchar(50),
  "province" varchar(50),
  "country" varchar(30) NOT NULL DEFAULT 'USA',
  "rating_avg" decimal(3,2),
  "total_sales" decimal(14,2) DEFAULT 0,
  "total_orders" integer DEFAULT 0,
  CONSTRAINT "fk_seller_user" FOREIGN KEY ("id") REFERENCES "users" ("id") ON DELETE CASCADE
);

-- 4. Verticals (no dependencies)
CREATE TABLE "verticals" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "name" varchar(100) UNIQUE NOT NULL,
  "description" text,
  "status" status NOT NULL DEFAULT 'active',
  "parent_id" uuid,
  "level" integer DEFAULT 1,
  CONSTRAINT "fk_vertical_parent" FOREIGN KEY ("parent_id") REFERENCES "verticals" ("id") ON DELETE RESTRICT
);

-- 5. Seller-Vertical junction (depends on sellers, verticals)
CREATE TABLE "seller_vertical" (
  "seller_id" uuid,
  "vertical_id" uuid,
  "created_at" timestamp DEFAULT (now()),
  "updated_at" timestamp DEFAULT (now()),
  PRIMARY KEY ("seller_id", "vertical_id"),
  CONSTRAINT "fk_seller_vertical_seller" FOREIGN KEY ("seller_id") REFERENCES "sellers" ("id") ON DELETE CASCADE,
  CONSTRAINT "fk_seller_vertical_vertical" FOREIGN KEY ("vertical_id") REFERENCES "verticals" ("id") ON DELETE RESTRICT
);

-- 6. Address Books (depends on consumers)
CREATE TABLE "address_books" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "user_id" uuid NOT NULL,
  "address_line_1" varchar(100) NOT NULL,
  "address_line_2" varchar(100),
  "city" varchar(50) NOT NULL,
  "province" varchar(50) NOT NULL,
  "country" varchar(30) NOT NULL,
  "postal_code" varchar(10),
  "phone" varchar(15) NOT NULL,
  "receiver_name" varchar(100) NOT NULL,
  "is_default" boolean DEFAULT false,
  "latitude" decimal(10,7),
  "longitude" decimal(10,7),
  "created_at" timestamp DEFAULT (now()),
  "updated_at" timestamp DEFAULT (now()),
  CONSTRAINT "fk_address_consumer" FOREIGN KEY ("user_id") REFERENCES "consumers" ("id") ON DELETE CASCADE
);

-- 7. Commodities (depends on sellers, verticals)
CREATE TABLE "commodities" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "seller_id" uuid NOT NULL,
  "sku" varchar(50) UNIQUE NOT NULL,
  "name" varchar(255) NOT NULL,
  "price" decimal(10,2) NOT NULL DEFAULT 0,
  "cost_price" decimal(10,2),
  "quantity" integer NOT NULL DEFAULT 0,
  "reserved_quantity" integer DEFAULT 0,
  "reorder_level" integer DEFAULT 10,
  "reorder_quantity" integer DEFAULT 100,
  "weight_kg" decimal(8,2),
  "description" text,
  "technical_info" text,
  "guarantee_info" text,
  "manufacturer_name" varchar(100),
  "vertical_id" uuid NOT NULL,
  "status" commodity_status DEFAULT 'available',
  "rating_avg" decimal(3,2),
  "review_count" integer DEFAULT 0,
  "total_sold" integer DEFAULT 0,
  "created_at" timestamp DEFAULT (now()),
  "updated_at" timestamp DEFAULT (now()),
  CONSTRAINT "fk_commodity_seller" FOREIGN KEY ("seller_id") REFERENCES "sellers" ("id") ON DELETE RESTRICT,
  CONSTRAINT "fk_commodity_vertical" FOREIGN KEY ("vertical_id") REFERENCES "verticals" ("id") ON DELETE RESTRICT
);

-- 8. Cards (depends on consumers)
CREATE TABLE "cards" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "consumer_id" uuid NOT NULL,
  "tk" varchar(255) NOT NULL,
  "provider" card_provider NOT NULL,
  "last4" varchar(4) NOT NULL,
  "card_holder" varchar(100) NOT NULL,
  "exp_year" integer NOT NULL,
  "exp_month" integer NOT NULL,
  "status" card_status NOT NULL DEFAULT 'active',
  "is_default" boolean DEFAULT false,
  "created_at" timestamp DEFAULT (now()),
  "updated_at" timestamp DEFAULT (now()),
  CONSTRAINT "fk_card_consumer" FOREIGN KEY ("consumer_id") REFERENCES "consumers" ("id") ON DELETE CASCADE
);

-- 9. Orders (depends on consumers, sellers)
CREATE TABLE "orders" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "consumer_id" uuid NOT NULL,
  "seller_id" uuid NOT NULL,
  "status" order_status DEFAULT 'draft',
  "delivery_address" varchar(255) NOT NULL,
  "delivery_postal_code" varchar(10),
  "delivery_receiver" varchar(100) NOT NULL,
  "delivery_phone" varchar(15) NOT NULL,
  "delivery_city" varchar(50) NOT NULL,
  "delivery_country" varchar(30) NOT NULL,
  "delivery_latitude" decimal(10,7),
  "delivery_longitude" decimal(10,7),
  "subtotal_amount" decimal(10,2) NOT NULL,
  "tax_amount" decimal(10,2) DEFAULT 0,
  "shipping_fee" decimal(10,2) DEFAULT 0,
  "discount_amount" decimal(10,2) DEFAULT 0,
  "total_amount" decimal(10,2) NOT NULL,
  "created_at" timestamp DEFAULT (now()),
  "confirmed_at" timestamp,
  "paid_at" timestamp,
  "shipped_at" timestamp,
  "delivered_at" timestamp,
  "completed_at" timestamp,
  "updated_at" timestamp DEFAULT (now()),
  "days_to_ship" integer,
  "days_to_deliver" integer,
  CONSTRAINT "fk_order_consumer" FOREIGN KEY ("consumer_id") REFERENCES "consumers" ("id") ON DELETE RESTRICT,
  CONSTRAINT "fk_order_seller" FOREIGN KEY ("seller_id") REFERENCES "sellers" ("id") ON DELETE RESTRICT
);

-- 10. Order Commodities (depends on orders, commodities)
CREATE TABLE "order_commodities" (
  "order_id" uuid,
  "commodity_id" uuid,
  "quantity" integer NOT NULL DEFAULT 1,
  "unit_price" decimal(10,2) NOT NULL,
  "unit_cost" decimal(10,2),
  "line_total" decimal(10,2) NOT NULL,
  "discount_applied" decimal(10,2) DEFAULT 0,
  PRIMARY KEY ("order_id", "commodity_id"),
  CONSTRAINT "fk_order_commodity_order" FOREIGN KEY ("order_id") REFERENCES "orders" ("id") ON DELETE CASCADE,
  CONSTRAINT "fk_order_commodity_commodity" FOREIGN KEY ("commodity_id") REFERENCES "commodities" ("id") ON DELETE RESTRICT
);

-- 11. Transactions (depends on orders, cards)
CREATE TABLE "transactions" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "order_id" uuid NOT NULL,
  "card_id" uuid,
  "payment_method" payment_method NOT NULL DEFAULT 'cod',
  "transaction_type" trans_type NOT NULL DEFAULT 'payment',
  "amount" decimal(10,2) NOT NULL,
  "status" trans_status DEFAULT 'draft',
  "created_at" timestamp DEFAULT (now()),
  "authorized_at" timestamp,
  "completed_at" timestamp,
  "gateway_transaction_id" varchar(100),
  "gateway_response_code" varchar(50),
  "gateway_response_message" varchar(255),
  "ip_address" varchar(45),
  "user_agent" varchar(255),
  CONSTRAINT "fk_transaction_order" FOREIGN KEY ("order_id") REFERENCES "orders" ("id") ON DELETE CASCADE,
  CONSTRAINT "fk_transaction_card" FOREIGN KEY ("card_id") REFERENCES "cards" ("id") ON DELETE RESTRICT
);

-- 12. Reviews (depends on orders, commodities, consumers, sellers)
CREATE TABLE "reviews" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "order_id" uuid UNIQUE NOT NULL,
  "commodity_id" uuid,
  "consumer_id" uuid NOT NULL,
  "seller_id" uuid NOT NULL,
  "rate" integer NOT NULL DEFAULT 3,
  "comment" text,
  "status" review_status NOT NULL DEFAULT 'draft',
  "is_verified_purchase" boolean DEFAULT true,
  "helpful_count" integer DEFAULT 0,
  "created_at" timestamp DEFAULT (now()),
  "updated_at" timestamp DEFAULT (now()),
  "published_at" timestamp,
  CONSTRAINT "fk_review_order" FOREIGN KEY ("order_id") REFERENCES "orders" ("id") ON DELETE CASCADE,
  CONSTRAINT "fk_review_commodity" FOREIGN KEY ("commodity_id") REFERENCES "commodities" ("id") ON DELETE RESTRICT,
  CONSTRAINT "fk_review_consumer" FOREIGN KEY ("consumer_id") REFERENCES "consumers" ("id") ON DELETE RESTRICT,
  CONSTRAINT "fk_review_seller" FOREIGN KEY ("seller_id") REFERENCES "sellers" ("id") ON DELETE RESTRICT
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Users indexes
CREATE INDEX idx_users_username ON "users" ("username");
CREATE INDEX idx_users_email ON "users" ("email");
CREATE INDEX idx_users_phone ON "users" ("phone");
CREATE INDEX idx_users_status ON "users" ("status");
CREATE INDEX idx_users_created_at ON "users" ("created_at");

-- Consumers indexes
CREATE INDEX idx_consumers_birthday ON "consumers" ("birthday");
CREATE INDEX idx_consumers_segment ON "consumers" ("customer_segment");
CREATE INDEX idx_consumers_first_order ON "consumers" ("first_order_date");
CREATE INDEX idx_consumers_total_spent ON "consumers" ("total_spent");

-- Sellers indexes
CREATE INDEX idx_sellers_type ON "sellers" ("type");
CREATE INDEX idx_sellers_country ON "sellers" ("country");
CREATE INDEX idx_sellers_city ON "sellers" ("city");
CREATE INDEX idx_sellers_rating ON "sellers" ("rating_avg");
CREATE INDEX idx_sellers_total_sales ON "sellers" ("total_sales");

-- Verticals indexes
CREATE INDEX idx_verticals_name ON "verticals" ("name");
CREATE INDEX idx_verticals_status ON "verticals" ("status");
CREATE INDEX idx_verticals_parent ON "verticals" ("parent_id");

-- Address books indexes
CREATE INDEX idx_address_user ON "address_books" ("user_id");
CREATE INDEX idx_address_city_country ON "address_books" ("city", "country");
CREATE INDEX idx_address_country ON "address_books" ("country");
CREATE INDEX idx_address_default ON "address_books" ("is_default");

-- Commodities indexes
CREATE INDEX idx_commodity_seller ON "commodities" ("seller_id");
CREATE INDEX idx_commodity_sku ON "commodities" ("sku");
CREATE INDEX idx_commodity_vertical ON "commodities" ("vertical_id");
CREATE INDEX idx_commodity_status ON "commodities" ("status");
CREATE INDEX idx_commodity_name ON "commodities" ("name");
CREATE INDEX idx_commodity_price ON "commodities" ("price");
CREATE INDEX idx_commodity_rating ON "commodities" ("rating_avg");
CREATE INDEX idx_commodity_sold ON "commodities" ("total_sold");

-- Cards indexes
CREATE INDEX idx_card_consumer ON "cards" ("consumer_id");
CREATE INDEX idx_card_status ON "cards" ("status");
CREATE INDEX idx_card_expiry ON "cards" ("exp_year", "exp_month");
CREATE INDEX idx_card_default ON "cards" ("is_default");

-- Orders indexes
CREATE INDEX idx_order_consumer ON "orders" ("consumer_id");
CREATE INDEX idx_order_seller ON "orders" ("seller_id");
CREATE INDEX idx_order_status ON "orders" ("status");
CREATE INDEX idx_order_created ON "orders" ("created_at");
CREATE INDEX idx_order_confirmed ON "orders" ("confirmed_at");
CREATE INDEX idx_order_consumer_status ON "orders" ("consumer_id", "status");
CREATE INDEX idx_order_seller_status ON "orders" ("seller_id", "status");
CREATE INDEX idx_order_location ON "orders" ("delivery_country", "delivery_city");

-- Order commodities indexes
CREATE INDEX idx_order_commodity_order ON "order_commodities" ("order_id");
CREATE INDEX idx_order_commodity_commodity ON "order_commodities" ("commodity_id");

-- Transactions indexes
CREATE INDEX idx_transaction_order ON "transactions" ("order_id");
CREATE INDEX idx_transaction_card ON "transactions" ("card_id");
CREATE INDEX idx_transaction_status ON "transactions" ("status");
CREATE INDEX idx_transaction_method ON "transactions" ("payment_method");
CREATE INDEX idx_transaction_created ON "transactions" ("created_at");
CREATE INDEX idx_transaction_type ON "transactions" ("transaction_type");

-- Reviews indexes
CREATE INDEX idx_review_order ON "reviews" ("order_id");
CREATE INDEX idx_review_commodity ON "reviews" ("commodity_id");
CREATE INDEX idx_review_consumer ON "reviews" ("consumer_id");
CREATE INDEX idx_review_seller ON "reviews" ("seller_id");
CREATE INDEX idx_review_status ON "reviews" ("status");
CREATE INDEX idx_review_rate ON "reviews" ("rate");
CREATE INDEX idx_review_created ON "reviews" ("created_at");

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE "users" IS 'Base user table - both consumers and sellers';
COMMENT ON TABLE "consumers" IS 'Consumer profile with aggregated metrics';
COMMENT ON TABLE "sellers" IS 'Seller profile with performance metrics';
COMMENT ON TABLE "verticals" IS 'Product categories';
COMMENT ON TABLE "seller_vertical" IS 'Which verticals each seller operates in';
COMMENT ON TABLE "address_books" IS 'Customer saved addresses';
COMMENT ON TABLE "commodities" IS 'Product catalog';
COMMENT ON TABLE "cards" IS 'Stored payment methods';
COMMENT ON TABLE "orders" IS 'Core fact table for orders';
COMMENT ON TABLE "order_commodities" IS 'Order line items';
COMMENT ON TABLE "transactions" IS 'Payment transactions';
COMMENT ON TABLE "reviews" IS 'Product reviews';

-- ============================================================================
-- NOTES
-- ============================================================================
-- This schema uses CORRECT foreign key directions:
-- - users is parent of consumers and sellers
-- - All other tables reference their dependencies correctly
-- 
-- Insertion order must be:
-- 1. users
-- 2. consumers, sellers
-- 3. verticals
-- 4. seller_vertical, address_books, cards
-- 5. commodities
-- 6. orders
-- 7. order_commodities, transactions
-- 8. reviews

# DATA ENGINEERING REPORT LAYOUT

## I. Giới thiệu

> Trình bày **ngữ cảnh** của đề tài.<br>
> Trình bày **các bên liên quan** đến đề tài (đặc biệt là người dùng), cùng với **các yêu cầu nghiệp vụ** và **nhu cầu khai thác dữ liệu**, định hình ứng dụng khai thác dữ liệu từ lĩnh vực ứng dụng được yêu cầu. <br>

Theo [Statista](https://www.statista.com/statistics/379046/worldwide-retail-e-commerce-sales/), và nhiều trang đưa tin về các số liệu dự báo liên quan đến thị trường thương mại điện tử năm nay (2025) và những năm kế tiếp (đến 2030), ngành Thương mại điện tử (E-Commerce) nói chung và bán lẻ nói riêng sẽ đạt doanh thu lên đến 8 trăm tỉ đô.

Nên có thể nói, thị trường Thương mại điện tử vẫn còn là một thị trường lớn, chưa hạ nhiệt bất kể nền kinh tế thị trường toàn thế giới có nhiều biến động.

Do đó, với những giá trị doanh số ước tính đó, những doanh nghiệp trong ngành Thương mại điện tử cũng phải đối mặt với nhiều thách thức và vấn đề. Không chỉ liên quan đến vận hành các sàn giao dịch, điều phối logistic, giao nhận các đơn hàng, các chiến dịch địa phương,... Bên cạnh việc vận hành hệ thống cho các xử lý giao dịch, cập nhật dữ liệu liên tục, lớn, mà còn có thể gặp nhiều thách thức trong việc xử lý các dữ liệu lớn, để qua đó không ngừng cung cấp nhiều hoạt động khác cho khách hàng, tìm hiểu xu hướng thị trường, quản lý chất lượng sản phẩm, phát hiện và xử lý các bất thường trong giao dịch,... từ nguồn dữ liệu đến từ hệ thống được vận hành và chạy liên tục.

Qua đó, lấy bối cảnh là một doanh nghiệp vận hành một sàn thương mại điện tử, nơi có tốc độ data-scale lớn, các dữ liệu tập trung để phân tích nhiều, nên rất cần một hệ thống có thể đáp ứng được tốc độc truy vấn khổng lồ mà nhiều Hệ quản trị cơ sở dữ liệu quan hệ - Relational Database Management System (RDBMS) khó đáp ứng được - là một kho dữ liệu (Data Warehouse) như Amazon Redshift.

Amazon Redshift là một trong những lựa chọn tuyệt vời và thích hợp để xử lý bài toán phân tích dữ liệu lớn, hỗ trợ doanh nghiệp đưa ra các quyết định dựa trên dữ liệu (data-driven) với độ trễ thấp, độ ổn định cao, và khả năng truy vấn mạnh mẽ, đặc biệt khi xử lý hàng triệu, thậm chí hàng trăm triệu bản ghi.

Với bối cảnh đó, các bên liên quan (trực tiếp hoặc gián tiếp) tham gia vào hệ thống xử lý và phân tích dữ liệu trên sàn thương mại điện tử này (sau đây gọi tắt là hệ thống), bao gồm các bên với yêu cầu nghiệp vụ như bảng bên dưới:

| Stakeholders             | Vai trò                                             | Yêu cầu nghiệp vụ |
| ------------------------ | --------------------------------------------------- | ----------------- |
| Data Analysis            | Phân tích dữ liệu (chính)                           | xxx               |
| Business Manager         | Quyết định chiến lược                               | xxx               |
| Operation Team           | Vận kho, điều phối quản lý sản phẩm                 | xxx               |
| Khách hàng<br>(Consumer) | Người tham gia mua sắm<br>và thực hiện giao dịch    | xxx               |
| Nhà bán hàng<br>(Seller) | Đăng ký và cung cấp hàng hóa<br>cho nhu cầu mua sắm | xxx               |
| Developer team           | Phát triển và bảo trì hệ thống                      | xxx               |

Từ đó, hệ thống muốn trình bày và đưa ra một số nhu cầu liên quan đến khai thác dữ liệu, có liên quan và được sử dụng trực tiếp hoặc gián tiếp từ các bên liên quan kể trên như:

| #   | Nhu cầu KTDL                         | Mô tả |
| --- | ------------------------------------ | ----- |
| 1   | Phân tích doanh thu YoY hoặc MoM     | xxx   |
| 2   | Phân tích và quản lý tồn kho         | xxx   |
| 3   | Phân tích hiệu suất bán hàng         | xxx   |
| 4   | Phân tích và báo cáo theo địa lý     | xxx   |
| 5   | Phân tích đánh giá sản phẩm          | xxx   |
| 6   | Phân tích hiểu quả danh mục sản phẩm | xxx   |

## II. Nguồn dữ liệu

### 2.1. Nguồn dữ liệu dự kiến

#### 2.1.1. Tiêu chí lựa chọn

Để đảm bảo tính khả thi và hiệu quả của dự án, nguồn dữ liệu được lựa chọn dựa trên các tiêu chí sau:

1. **Tính đại diện (Representative)**: Dữ liệu phải phản ánh đầy đủ các hoạt động nghiệp vụ thực tế của một sàn thương mại điện tử, bao gồm:
   - Hoạt động của người dùng (consumers và sellers)
   - Giao dịch mua bán, thanh toán
   - Quản lý sản phẩm và tồn kho
   - Đánh giá và phản hồi từ khách hàng

2. **Tính toàn vẹn (Integrity)**: Dữ liệu phải đảm bảo tính toàn vẹn tham chiếu giữa các bảng, phù hợp với các ràng buộc nghiệp vụ thực tế.

3. **Khả năng mở rộng (Scalability)**: Có thể sinh dữ liệu với quy mô lớn để mô phỏng môi trường production thực tế và kiểm tra hiệu năng của Data Warehouse.

4. **Tính đa dạng (Diversity)**: Dữ liệu bao gồm nhiều loại sản phẩm (verticals), nhiều khu vực địa lý, nhiều phương thức thanh toán để phục vụ các phân tích đa chiều.

5. **Tính nhất quán thời gian (Temporal Consistency)**: Dữ liệu phải có các mốc thời gian hợp lý để phân tích xu hướng theo thời gian (time-series analysis).

#### 2.1.2. Nguồn dữ liệu

Dữ liệu cho dự án được **tự sinh tạo (synthetic data)** với các thư viện python:

- **Faker library**: Sinh dữ liệu giả lập thực tế cho tên, địa chỉ, email, số điện thoại, văn bản mô tả, v.v.
- **Random & UUID modules**: Tạo các giá trị ngẫu nhiên, UUID cho primary keys
- **Datetime modules**: Sinh các mốc thời gian trong khoảng 1-3 năm gần đây

**Lý do sử dụng dữ liệu tự sinh:**

- Không có sẵn dataset E-commerce thực tế công khai với đầy đủ các thuộc tính cần thiết
- Kiểm soát hoàn toàn về quy mô, phân phối và đặc tính của dữ liệu
- Đảm bảo tuân thủ các quy định về bảo mật và quyền riêng tư (không sử dụng dữ liệu thật)
- Khả năng tái tạo (reproducible) với seed cố định để đảm bảo tính nhất quán
- File này được tái sử dụng qua nhiều lần generate để đảm bảo tính nhất quán của các danh mục

---

### 2.2. Các đặc điểm dữ liệu

#### 2.2.1. Tính chất của bộ dữ liệu

Bộ dữ liệu được thiết kế theo mô hình **Star Schema** (biến thể) phù hợp với Data Warehouse:

1. **Dimension Tables (Bảng chiều):**
   - `users`, `consumers`, `sellers`: Thông tin về các actor trong hệ thống
   - `verticals`: Danh mục sản phẩm
   - `address_books`: Địa chỉ giao hàng
   - `cards`: Phương thức thanh toán
   - `commodities`: Catalog sản phẩm

2. **Fact Tables (Bảng sự kiện):**
   - `orders`: Đơn hàng - fact table trung tâm
   - `order_commodities`: Sản phẩm trong đơn hàng
   - `transactions`: Giao dịch thanh toán
   - `reviews`: Đánh giá sản phẩm

3. **Bridge Tables (Bảng cầu nối):**
   - `seller_vertical`: Quan hệ nhiều-nhiều giữa sellers và verticals

**Đặc điểm về phân phối dữ liệu:**

- **Skewed distribution**: Một số sellers/products sẽ có nhiều đơn hàng hơn (phản ánh thực tế)
- **Time-series data**: Dữ liệu được phân bố theo thời gian (1-3 năm gần đây)
- **Geographic diversity**: Dữ liệu địa lý đa dạng với nhiều quốc gia, thành phố
- **Status distribution**: Các trạng thái đơn hàng phân bố theo tỷ lệ thực tế (delivered > shipped > inprogress > cancelled)

#### 2.2.2. Các thực thể dữ liệu chính

Hệ thống bao gồm 13 thực thể chính được tổ chức theo các nhóm:

**A. Nhóm User Management (Quản lý người dùng):**

1. **users** - Bảng base cho tất cả người dùng
   - Vai trò: Lưu thông tin chung (username, email, phone, status)
   - Khóa chính: `id` (UUID)
   - Đặc điểm: Sử dụng inheritance pattern với consumers và sellers

2. **consumers** - Hồ sơ người mua
   - Vai trò: Thông tin mở rộng của consumer (birthday, gender, customer_segment)
   - Khóa chính: `id` (FK đến users.id, quan hệ 1:1)
   - Đặc điểm: Chứa các trường denormalized (total_orders, total_spent)

3. **sellers** - Hồ sơ người bán
   - Vai trò: Thông tin mở rộng của seller (type, địa chỉ kinh doanh, rating_avg)
   - Khóa chính: `id` (FK đến users.id, quan hệ 1:1)
   - Đặc điểm: Chứa metrics kinh doanh (total_sales, total_orders)

**B. Nhóm Product Management (Quản lý sản phẩm):**

4. **verticals** - Danh mục sản phẩm
   - Vai trò: Phân loại sản phẩm theo ngành hàng (Electronics, Fashion, Food,...)
   - Khóa chính: `id` (UUID)
   - Đặc điểm: Dimension table nhỏ, DISTSTYLE ALL trong Redshift

5. **commodities** - Catalog sản phẩm
   - Vai trò: Thông tin chi tiết sản phẩm (SKU, price, cost_price, quantity)
   - Khóa chính: `id` (UUID)
   - Đặc điểm: Large dimension table, chứa thông tin tồn kho và pricing

6. **seller_vertical** - Quan hệ Seller-Vertical
   - Vai trò: Xác định seller kinh doanh trong các verticals nào
   - Khóa chính: Composite (`seller_id`, `vertical_id`)
   - Đặc điểm: Many-to-Many bridge table

**C. Nhóm Order Processing (Xử lý đơn hàng):**

7. **orders** - Đơn hàng
   - Vai trò: Core fact table, lưu thông tin đơn hàng
   - Khóa chính: `id` (UUID)
   - Đặc điểm: 
     - Chứa denormalized fields cho delivery (city, country, coordinates)
     - Lưu timestamps cho funnel analysis (created_at, paid_at, shipped_at, delivered_at)
     - Chứa financial metrics (subtotal, tax, shipping, discount, total)

8. **order_commodities** - Chi tiết đơn hàng
   - Vai trò: Line items của order (quan hệ M:N giữa orders và commodities)
   - Khóa chính: Composite (`order_id`, `commodity_id`)
   - Đặc điểm: Lưu giá tại thời điểm đặt hàng (unit_price, unit_cost) cho historical accuracy

**D. Nhóm Payment Processing (Xử lý thanh toán):**

9. **cards** - Thẻ thanh toán
   - Vai trò: Lưu thông tin thẻ của consumers
   - Khóa chính: `id` (UUID)
   - Đặc điểm: Tokenized card data (tk field), hỗ trợ nhiều providers

10. **transactions** - Giao dịch thanh toán
    - Vai trò: Fact table cho payment transactions
    - Khóa chính: `id` (UUID)
    - Đặc điểm: 
      - Hỗ trợ nhiều payment methods (card, COD, e-wallet)
      - Lưu gateway response codes và messages
      - Chứa metadata (IP address, user agent)

**E. Nhóm Customer Experience (Trải nghiệm khách hàng):**

11. **address_books** - Sổ địa chỉ
    - Vai trò: Lưu địa chỉ giao hàng của consumers
    - Khóa chính: `id` (UUID)
    - Đặc điểm: 
      - Chứa coordinates (latitude, longitude) cho geo analysis
      - Support multiple addresses per consumer với is_default flag

12. **reviews** - Đánh giá sản phẩm
    - Vai trò: Fact table cho customer reviews
    - Khóa chính: `id` (UUID)
    - Đặc điểm:
      - One review per order (order_id UNIQUE)
      - Denormalized consumer_id và seller_id cho fast lookup
      - Rate từ 1-5 stars, support verified purchase flag


13. **Staging tables** - Bảng tạm cho ETL process

#### 2.2.3. 3Vs của dữ liệu

Phân tích theo mô hình **3Vs của Big Data** (Volume, Velocity, Variety):

**1. Volume (Khối lượng):**

- **Quy mô hiện tại (Demo):** ~500,000 bản ghi
- **Quy mô dự kiến (Production):** 
  - 1 triệu users (900K consumers, 100K sellers)
  - 5 triệu commodities
  - 100 triệu orders/năm
  - 300 triệu order line items/năm
  - 80 triệu transactions/năm
  - 30 triệu reviews/năm

- **Kích thước lưu trữ ước tính:**
  - Raw data: ~100GB/năm (uncompressed)
  - Compressed trong Redshift: ~20-30GB/năm (với compression)
  - Aggregated tables: ~5GB

- **Tốc độ tăng trưởng:** 
  - Orders: ~300,000 đơn/ngày (peak)
  - Data ingestion: ~2GB/ngày

**2. Velocity (Tốc độ):**

- **Batch processing:**
  - Orders data: Load hàng ngày (daily batch) từ OLTP database
  - Aggregations: Refresh mỗi 6-12 giờ
  
- **Near real-time processing:**
  - Inventory updates: Mỗi 15-30 phút
  - Sales dashboards: Refresh mỗi 5-10 phút
  
- **Stream processing (nếu mở rộng):**
  - Real-time order tracking
  - Fraud detection

- **Query velocity:**
  - Analytical queries: 1000-5000 queries/giờ
  - Dashboard queries: 100-500 concurrent users

**3. Variety (Đa dạng):**

- **Structured data (chiếm ~95%):**
  - Relational data phân bổ trong 13 bảng chính
  - Dữ liệu số: prices, quantities, ratings, metrics
  - Dữ liệu thời gian: timestamps cho lifecycle tracking
  - Dữ liệu địa lý: coordinates, cities, countries

- **Semi-structured data (chiếm ~5%):**
  - JSON fields trong gateway_response (có thể mở rộng)
  - Log data từ ETL processes

**Đánh giá chung:**
- Dự án hiện tại thuộc quy mô **Medium Data** (~500K records)
- Có tiềm năng scale lên **Big Data** (>100M records) trong production
- Redshift được chọn để chuẩn bị cho việc scale trong tương lai

#### 2.2.4. Giới hạn (ràng buộc) của giá trị

**A. Ràng buộc khóa (Key Constraints):**

1. **Primary Keys:**
   - Tất cả bảng có khóa chính (UUID hoặc composite key)
   - UUID v4 được sử dụng cho single-column primary keys
   - Composite keys cho junction tables (seller_vertical, order_commodities)

2. **Foreign Keys:**
   - Trong thiết kế logical: Đầy đủ FK constraints
   - Trong Redshift physical schema: **Một số FK được bỏ qua** (theo comment trong DBML lines 444-451)
   - Lý do: Redshift không enforce FK, và việc load data linh hoạt hơn
   - Giải pháp: Enforce referential integrity tại ETL layer

3. **Unique Constraints:**
   - `users.username`, `users.email`, `users.phone` - UNIQUE
   - `commodities.sku` - UNIQUE (mã SKU duy nhất)
   - `verticals.name` - UNIQUE
   - `reviews.order_id` - UNIQUE (một đơn hàng chỉ có một review)

**B. Ràng buộc giá trị (Value Constraints):**

1. **NOT NULL Constraints:**
   - Các trường bắt buộc: username, email, phone, name, price, quantity, order amounts
   - Một số trường optional: address_line_2, technical_info, guarantee_info, comment

2. **Default Values:**
   - Status fields: default 'active', 'draft' tùy theo context
   - Numeric fields: default 0 hoặc 0.0000
   - Boolean fields: default false
   - Timestamps: default `now()`

3. **Check Constraints (Logic - không enforce trong Redshift):**
   - `rate` trong reviews: 1-5
   - `exp_month` trong cards: 1-12
   - `exp_year` trong cards: >= 2024
   - `quantity`: >= 0
   - `price`: > 0
   - Financial amounts: >= 0

4. **Enum Constraints:**
   - Các trường enum được giới hạn trong danh sách giá trị cố định:
     - `status`: active, inactive, deleted
     - `order_status`: 8 giá trị (draft → done/cancelled/abandoned)
     - `trans_status`: 6 giá trị (draft → captured/failed/refunded)
     - `gender`: 4 giá trị
     - `commodity_status`: 4 giá trị
     - v.v. (xem section ENUMS trong DBML)

**C. Ràng buộc nghiệp vụ (Business Rules):**

1. **Order Lifecycle:**
   - `confirmed_at` >= `created_at`
   - `paid_at` >= `confirmed_at`
   - `shipped_at` >= `paid_at`
   - `delivered_at` >= `shipped_at`
   - `completed_at` >= `delivered_at`

2. **Financial Calculations:**
   - `total_amount` = `subtotal_amount` + `tax_amount` + `shipping_fee` - `discount_amount`
   - `line_total` = `quantity` * `unit_price` - `discount_applied`
   - `cost_price` < `price` (để có lợi nhuận)

3. **Inventory Rules:**
   - `reserved_quantity` <= `quantity`
   - `quantity` + `reserved_quantity` >= 0
   - Alert khi `quantity` < `reorder_level`

4. **Rating Aggregations:**
   - `consumers.total_spent` = SUM(orders.total_amount WHERE status IN ('delivered', 'done'))
   - `commodities.rating_avg` = AVG(reviews.rate WHERE commodity_id = X)
   - `sellers.rating_avg` = AVG(reviews.rate WHERE seller_id = X)

5. **Customer Segmentation:**
   - VIP: total_spent >= $5,000
   - Regular: $1,000 <= total_spent < $5,000
   - Occasional: $100 <= total_spent < $1,000
   - One-time: total_spent < $100

**D. Ràng buộc độ dài (Length Constraints):**

| Field Type       | Max Length | Example Fields                           |
| ---------------- | ---------- | ---------------------------------------- |
| UUID             | 36 chars   | All ID fields                            |
| VARCHAR(15)      | 15         | phone                                    |
| VARCHAR(50)      | 50         | city, province, SKU prefix               |
| VARCHAR(100)     | 100        | name, receiver_name, address_line_1      |
| VARCHAR(255)     | 255        | username, email, commodity.name          |
| VARCHAR(500)     | 500        | introduction                             |
| TEXT             | unlimited  | description, comment, technical_info     |
| DECIMAL(10,4)    | 10 digits  | prices, amounts                          |
| DECIMAL(12,4)    | 12 digits  | consumers.total_spent                    |
| DECIMAL(14,4)    | 14 digits  | sellers.total_sales                      |
| DECIMAL(3,2)     | 3 digits   | rating_avg (range: 0.00 - 5.00)          |

#### 2.2.5. Lưu ý về value của các dữ liệu

**A. Dữ liệu có thể NULL:**

1. **Consumer Profile:**
   - `birthday`: NULL cho users không cung cấp
   - `customer_segment`: NULL cho consumers chưa có đơn hàng

2. **Seller Profile:**
   - `introduction`: NULL nếu chưa viết
   - `address`, `city`, `province`: NULL cho sellers online-only
   - `rating_avg`: NULL nếu chưa có reviews

3. **Commodity Details:**
   - `cost_price`: NULL nếu không tracking (ảnh hưởng profit analysis)
   - `description`, `technical_info`, `guarantee_info`: NULL (optional fields)
   - `manufacturer_name`: NULL cho handmade/unknown brands
   - `weight_kg`: NULL (ảnh hưởng shipping calculation)
   - `rating_avg`: NULL nếu chưa có reviews

4. **Order Timestamps:**
   - `confirmed_at`: NULL cho orders với status = 'draft'
   - `paid_at`: NULL cho orders chưa thanh toán
   - `shipped_at`, `delivered_at`, `completed_at`: NULL tùy theo order status
   - `days_to_ship`, `days_to_deliver`: NULL (derived fields)

5. **Order Address:**
   - `delivery_postal_code`: NULL (một số quốc gia không có postal code)
   - `delivery_latitude`, `delivery_longitude`: NULL nếu không geocoding

6. **Transaction Fields:**
   - `card_id`: NULL cho non-card payments (COD, bank transfer)
   - `authorized_at`, `completed_at`: NULL tùy theo trans_status
   - `gateway_transaction_id`, `gateway_response_code`, `gateway_response_message`: NULL cho COD

7. **Review Fields:**
   - `commodity_id`: NULL nếu review cho cả order (không specific product)
   - `comment`: NULL (chỉ rating không có text)
   - `published_at`: NULL cho reviews với status != 'published'

**Impact của NULL values:**

- **Analytical queries:** Cần xử lý NULL bằng COALESCE, NULLIF, IS NULL/IS NOT NULL
- **Aggregations:** AVG, SUM tự động bỏ qua NULL (nhưng cần cẩn thận với COUNT)
- **Joins:** NULL không match được với bất kỳ giá trị nào (kể cả NULL khác)

**B. Dữ liệu đa giá trị (Multi-valued Attributes):**

Trong thiết kế hiện tại, **không có cột nào lưu đa giá trị** (tuân thủ 1NF - First Normal Form). 

Các quan hệ đa giá trị được normalize thành bảng riêng:

1. **Seller ↔ Verticals:** Một seller có thể bán nhiều verticals
   - Solution: Bảng `seller_vertical` (junction table)
   - Query: JOIN để lấy danh sách verticals của seller

2. **Order ↔ Commodities:** Một order có thể có nhiều commodities
   - Solution: Bảng `order_commodities` với quantity
   - Query: JOIN để lấy line items của order

3. **Consumer ↔ Addresses:** Một consumer có thể có nhiều addresses
   - Solution: Bảng `address_books` với is_default flag
   - Query: JOIN hoặc subquery để lấy default address

4. **Consumer ↔ Cards:** Một consumer có thể có nhiều cards
   - Solution: Bảng `cards` với is_default flag
   - Query: JOIN hoặc subquery để lấy default card

**C. Dữ liệu Denormalized:**

Để tối ưu query performance, một số metrics được denormalize:

1. **Trong `consumers`:**
   - `total_orders`: Computed từ orders table
   - `total_spent`: SUM(orders.total_amount)
   - `customer_segment`: Derived từ total_spent

2. **Trong `sellers`:**
   - `total_orders`: COUNT(orders)
   - `total_sales`: SUM(orders.total_amount)
   - `rating_avg`: AVG(reviews.rate)

3. **Trong `commodities`:**
   - `total_sold`: SUM(order_commodities.quantity)
   - `review_count`: COUNT(reviews)
   - `rating_avg`: AVG(reviews.rate)

4. **Trong `orders`:**
   - `delivery_city`, `delivery_country`: Copied từ address_books
   - `delivery_latitude`, `delivery_longitude`: Copied từ address_books

5. **Trong `reviews`:**
   - `consumer_id`, `seller_id`: Denormalized từ orders

**Ưu điểm và nhược điểm của Denormalization:**

- ✅ **Ưu:** Tăng tốc độ của truy vấn, ít phải gọi các lệnh JOIN
- ❌ **Nhược điểm:** dữ liệu có thể xuất hiện ở nhiều chỗ, có khả năng mất đồng bộ
- 🔄 **Solution:** Cập nhật các dữ liệu denormalized thường xuyên

**D. Dữ liệu có ràng buộc đặc biệt:**

1. **Encrypted/Hashed Data:**
   - `cards.tk`: chứa  đoạn hash của card number của người dùng (SHA-256)
   - Production cần thêm: Personal Identifiable Information (PII) encryption

2. **Temporal Data:**
   - Tất cả timestamps sử dụng format: `YYYY-MM-DD HH:MI:SS`
   - Dates sử dụng format: `YYYY-MM-DD`
   - Timezone: Giả định UTC trong demo (production cần timezone-aware)

3. **Geographic Data:**
   - Latitude: -90 đến 90
   - Longitude: -180 đến 180
   - Precision: 7 decimal places (~11mm accuracy)

4. **Financial Data:**
   - Currency: USD (mặc định)
   - Precision: 4 decimal places (0.0001)
   - Rounding: ROUND_HALF_UP

5. **Identifiers:**
   - UUID: Version 4 (random)
   - SKU: Format PREFIX-NNNNNN (e.g., ELEC-123456)
   - Transaction IDs: Format GTW-NNNNNNNNN

---

### 2.3. Trình bày về hệ quản trị cơ sở dữ liệu (DBMS)

#### 2.3.1. Các kỹ thuật dữ liệu được sử dụng

**A. Primary Keys (PK):**

1. **UUID-based Primary Keys:**
   - Hầu hết bảng sử dụng UUID v4 làm primary key
   - **Ưu điểm:**
     - Globally unique: Không conflict khi merge data từ nhiều sources
     - Generated client-side: Không phụ thuộc vào database sequence
     - Security: Không lộ thông tin về số lượng records
   - **Nhược điểm:**
     - Kích thước lớn (36 characters): Tốn storage và memory
     - Random: Không có locality, index fragmentation
     - Redshift: Sử dụng RAW hoặc LZO compression để giảm storage

2. **Composite Primary Keys:**
   - `seller_vertical`: (seller_id, vertical_id)
   - `order_commodities`: (order_id, commodity_id)
   - **Ưu điểm:**
     - Natural keys cho junction tables
     - Enforce uniqueness của relationship
   - **Lưu ý trong Redshift:**
     - PK không được enforce (chỉ metadata cho optimizer)
     - Cần ensure uniqueness tại ETL layer

**B. Foreign Keys (FK):**

1. **Trong Logical Design:**
   - Đầy đủ FK constraints được định nghĩa trong DBML
   - Cascade rules: DELETE CASCADE hoặc RESTRICT tùy theo business logic
   - Quan hệ 1:1, 1:N, M:N đều có FK

2. **Trong Redshift Physical Schema:**
   - FK **không được enforce** (Redshift limitation)
   - FK được define như metadata cho query optimizer
   - **Referential integrity được ensure bởi:**
     - Data validation trong ETL pipeline
     - Application-level checks
     - Periodic integrity check jobs

3. **Ví dụ FK relationships:**
   - `consumers.id` → `users.id` (1:1 inheritance)
   - `orders.consumer_id` → `consumers.id` (1:N)
   - `order_commodities.order_id` → `orders.id` (M:N via junction)

**C. Sort Keys (SORTKEY):**
   - Tương tự clustered index, dữ liệu được sắp xếp vật lý theo sort key
   - **Compound sort key:** Thứ tự cột quan trọng (dùng cho prefix matching)
   - **Interleaved sort key:** Equal weight cho mọi cột (dùng cho multi-column filtering)
   
   **Ví dụ trong schema:**
   - `orders`: SORTKEY (created_at, status)
     - Query WHERE created_at BETWEEN ... AND ... → Fast range scan
     - Query WHERE status = 'delivered' → Zone map filtering
   
   - `commodities`: SORTKEY (vertical_id, created_at)
     - Query: Browse products by category, sorted by newest → Fast
   
   - `transactions`: SORTKEY (created_at, status)
     - Time-series queries → Fast
   
   - `reviews`: SORTKEY (created_at, rate)
     - Recent reviews, filter by rating → Fast

**D. Distribution Keys (DISTKEY):**
   - Xác định cách data được phân tán trên các nodes
   - **DISTKEY strategies:**
   
   **a) DISTSTYLE KEY (phân tán theo column):**
   - `orders`: DISTKEY consumer_id
     - Reason: Most queries join với consumers
     - Orders của cùng consumer nằm cùng node → Local join
   
   - `transactions`: DISTKEY order_id
     - Reason: Collocate với orders table → Local join
   
   - `order_commodities`: DISTKEY order_id
     - Reason: Collocate với orders table → Local join
   
   - `commodities`: DISTKEY seller_id
     - Reason: Seller analytics queries → Local aggregation
   
   - `cards`: DISTKEY consumer_id
     - Reason: Collocate với consumers table → Local join
   
   - `address_books`: DISTKEY user_id
     - Reason: Collocate với consumers → Local join
   
   **b) DISTSTYLE ALL (replicate toàn bộ):**
   - `users`, `consumers`, `sellers`, `verticals`
   - Reason: Small dimension tables, full copy trên mọi node
   - Benefit: Joins không cần redistribution → Very fast
   
   **c) DISTSTYLE EVEN (round-robin):**
   - Default nếu không specify
   - Dữ liệu phân bố đều, dùng khi không có join pattern rõ ràng

**E. Partitioning:**

Redshift **không có native partitioning** như PostgreSQL. Strategies thay thế:

1. **Time-based table splitting:**
   - `orders_2024`, `orders_2025`, ...
   - Query: UNION ALL views
   - Trade-off: Query complexity vs performance

2. **External tables với S3:**
   - Partition data trong S3 (Hive-style partitioning)
   - Query qua Redshift Spectrum
   - Cost-effective cho cold data

3. **Date range filtering với Sort Key:**
   - Sort by date column
   - Zone maps automatically skip irrelevant blocks
   - Simpler than manual partitioning

**F. Denormalization Techniques:**

1. **Pre-aggregated Tables:**
   - Materialized aggregations cho common queries
   - Ví dụ: daily_sales_summary, monthly_revenue_by_vertical
   - Refresh: Scheduled jobs (dbt, Airflow)

2. **Flattened Dimensions:**
   - Copy frequently-used dimension attributes vào fact table
   - Ví dụ: delivery_city, delivery_country trong orders
   - Trade-off: Storage vs JOIN elimination

3. **Star Schema Design:**
   - Central fact table (orders) surrounded by dimensions
   - Optimized cho OLAP queries
   - Redshift optimizer ưu tiên star join patterns

#### 2.3.2. Phân tích EER (Enhanced Entity-Relationship)

**A. Phân loại thực thể theo độ mạnh:**

**1. Strong Entities (Thực thể mạnh):**

Tồn tại độc lập, có khóa chính riêng:

- **users** - Thực thể gốc cho tất cả người dùng
  - PK: `id` (UUID)
  - Tồn tại độc lập, không phụ thuộc thực thể khác

- **verticals** - Danh mục sản phẩm
  - PK: `id` (UUID)
  - Master data, tồn tại độc lập

- **orders** - Đơn hàng (Core fact table)
  - PK: `id` (UUID)
  - Có sử dụng FK đến consumers và sellers

- **transactions** - Giao dịch thanh toán
  - PK: `id` (UUID)
  - Có FK đến orders

- **reviews** - Đánh giá sản phẩm
  - PK: `id` (UUID)
  - Có FK đến orders

- **commodities** - Sản phẩm
  - PK: `id` (UUID)
  - Mặc dù thuộc về seller, nhưng tồn tại độc lập với lifecycle riêng

- **cards** - Thẻ thanh toán
  - PK: `id` (UUID)
  - Thuộc về consumer, tuy nhiên vẫn có identity riêng

- **address_books** - Địa chỉ
  - PK: `id` (UUID)
  - Thuộc về user nhưng có identity riêng

**2. Weak Entities (Thực thể yếu):**

Phụ thuộc vào thực thể khác, khóa chính bao gồm khóa ngoại:

- **consumers** - Hồ sơ người mua
  - PK: `id` (cũng là FK đến users.id)
  - **Phụ thuộc:** users (quan hệ ISA/inheritance)
  - **Existence dependency:** Không thể tồn tại nếu không có users
  - **Identifying relationship:** consumer_user (1:1)

- **sellers** - Hồ sơ người bán
  - PK: `id` (cũng là FK đến users.id)
  - **Phụ thuộc:** users (quan hệ ISA/inheritance)
  - **Existence dependency:** Không thể tồn tại nếu không có users
  - **Identifying relationship:** seller_user (1:1)

- **seller_vertical** - Junction table
  - PK: (`seller_id`, `vertical_id`) - Composite key gồm 2 FK
  - **Phụ thuộc:** sellers và verticals
  - **Existence dependency:** Phải có cả seller và vertical
  - **Identifying relationship:** M:N relationship

- **order_commodities** - Sản phẩm trong đơn hàng
  - PK: (`order_id`, `commodity_id`) - Composite key gồm 2 FK
  - **Phụ thuộc:** orders và commodities
  - **Existence dependency:** Phải có order
  - **Identifying relationship:** M:N relationship via junction

**B. Ràng buộc tham gia (Participation Constraints):**

**1. Total Participation (Mandatory, ký hiệu: double line):**

Entity bắt buộc phải tham gia vào relationship:

- **consumers** → **address_books**: Total participation
  - Mỗi consumer **PHẢI có ít nhất 1 địa chỉ** để đặt hàng
  - Business rule: Consumer phải setup address trước khi order
  - DB enforcement: Application-level check

- **orders** → **consumer**: Total participation
  - Mỗi order **PHẢI thuộc về 1 consumer**
  - `orders.consumer_id` NOT NULL

- **orders** → **seller**: Total participation
  - Mỗi order **PHẢI thuộc về 1 seller**
  - `orders.seller_id` NOT NULL

- **commodities** → **seller**: Total participation
  - Mỗi commodity **PHẢI thuộc về 1 seller**
  - `commodities.seller_id` NOT NULL

- **commodities** → **vertical**: Total participation
  - Mỗi commodity **PHẢI thuộc về 1 vertical**
  - `commodities.vertical_id` NOT NULL

- **transactions** → **order**: Total participation
  - Mỗi transaction **PHẢI liên kết với 1 order**
  - `transactions.order_id` NOT NULL

**2. Partial Participation (Optional, ký hiệu: single line):**

Entity có thể không tham gia vào relationship:

- **consumers** → **cards**: Partial participation
  - Consumer có thể không có thẻ (dùng COD, bank transfer)
  - Một số consumers chưa setup payment method

- **orders** → **transactions**: Partial participation
  - Orders với status='draft' chưa có transaction
  - Orders cancelled cũng có thể không có transaction

- **orders** → **reviews**: Partial participation
  - Không phải order nào cũng có review
  - Chỉ ~30% delivered orders có review

- **transactions** → **card**: Partial participation
  - Transactions không dùng card (COD, bank transfer) có `card_id` = NULL
  - `transactions.card_id` nullable

- **reviews** → **commodity**: Partial participation
  - Review có thể cho cả order (không specify commodity)
  - `reviews.commodity_id` nullable

**C. Ràng buộc cardinality (Cardinality Constraints):**

**1. One-to-One (1:1):**

- **users** ↔ **consumers**
  - Mỗi consumer là 1 user, mỗi user (consumer) chỉ có 1 consumer profile
  - Implementation: consumers.id = FK và PK

- **users** ↔ **sellers**
  - Mỗi seller là 1 user, mỗi user (seller) chỉ có 1 seller profile
  - Implementation: sellers.id = FK và PK

- **orders** ↔ **reviews**
  - Mỗi order có tối đa 1 review (order_id UNIQUE trong reviews)
  - Business rule: One review per order

**2. One-to-Many (1:N):**

- **consumers** → **address_books** (1:N)
  - Mỗi consumer có nhiều addresses
  - Mỗi address thuộc về 1 consumer
  - FK: address_books.user_id → consumers.id

- **consumers** → **cards** (1:N)
  - Mỗi consumer có nhiều cards
  - Mỗi card thuộc về 1 consumer
  - FK: cards.consumer_id → consumers.id

- **consumers** → **orders** (1:N)
  - Mỗi consumer có nhiều orders
  - Mỗi order của 1 consumer
  - FK: orders.consumer_id → consumers.id

- **sellers** → **orders** (1:N)
  - Mỗi seller nhận nhiều orders
  - Mỗi order từ 1 seller
  - FK: orders.seller_id → sellers.id

- **sellers** → **commodities** (1:N)
  - Mỗi seller có nhiều commodities
  - Mỗi commodity của 1 seller
  - FK: commodities.seller_id → sellers.id

- **verticals** → **commodities** (1:N)
  - Mỗi vertical có nhiều commodities
  - Mỗi commodity thuộc 1 vertical
  - FK: commodities.vertical_id → verticals.id

- **orders** → **transactions** (1:N)
  - Mỗi order có nhiều transactions (refunds, installments)
  - Mỗi transaction của 1 order
  - FK: transactions.order_id → orders.id

- **cards** → **transactions** (1:N)
  - Mỗi card dùng cho nhiều transactions
  - Mỗi transaction dùng 1 card
  - FK: transactions.card_id → cards.id

- **consumers** → **reviews** (1:N) [Denormalized]
  - FK: reviews.consumer_id → consumers.id

- **sellers** → **reviews** (1:N) [Denormalized]
  - FK: reviews.seller_id → sellers.id

- **commodities** → **reviews** (1:N)
  - FK: reviews.commodity_id → commodities.id

**3. Many-to-Many (M:N):**

- **sellers** ↔ **verticals** (M:N)
  - Mỗi seller bán trong nhiều verticals
  - Mỗi vertical có nhiều sellers
  - Bridge table: seller_vertical (seller_id, vertical_id)

- **orders** ↔ **commodities** (M:N)
  - Mỗi order có nhiều commodities (line items)
  - Mỗi commodity xuất hiện trong nhiều orders
  - Bridge table: order_commodities (order_id, commodity_id, quantity, ...)

**D. Ràng buộc đặc biệt (Specialized Constraints):**

**1. Disjoint Constraint (ISA hierarchy):**

- **users** có 2 subtypes: **consumers** và **sellers**
- **Disjoint:** Một user không thể vừa là consumer vừa là seller
  - (Trong thiết kế này - có thể thay đổi trong tương lai)
- **Total specialization:** Mỗi user phải là consumer HOẶC seller
  - Implementation: Application-level check

**Diagram:**

```
         users
        /     \
       /       \
consumers     sellers
   (disjoint, total)
```

**2. Aggregation (Ternary Relationship):**

- **reviews** aggregates relationship giữa (order, commodity, consumer)
  - Review không chỉ về commodity, mà về commodity trong context của order cụ thể
  - Denormalized consumer_id và seller_id để fast lookup

**3. Recursive Relationship:**

Không có trong schema hiện tại, nhưng có thể mở rộng:

- **users** → **users** (referral program)
- **verticals** → **verticals** (category hierarchy)

**E. Ràng buộc nghiệp vụ phức tạp:**

**1. Multi-table Constraints:**

- Order status lifecycle:
  ```
  IF orders.status = 'shipped' 
  THEN orders.shipped_at IS NOT NULL 
  AND orders.paid_at IS NOT NULL
  ```

- Transaction consistency:
  ```
  IF transactions.status = 'captured' 
  THEN orders.status IN ('inprogress', 'shipped', 'delivered', 'done')
  ```

**2. Derived Attributes:**

- `consumers.customer_segment` ← derived từ `total_spent`
- `orders.days_to_ship` ← derived từ `shipped_at - paid_at`
- `commodities.rating_avg` ← derived từ AVG(reviews.rate)

**3. Temporal Constraints:**

- Order timestamps phải có thứ tự logic
- Review timestamp phải sau order delivered_at
- Card expiration: `(exp_year, exp_month)` > current date

**F. ER Diagram Notation Summary:**

| Element                | Notation              | Example                    |
| ---------------------- | --------------------- | -------------------------- |
| Strong entity          | Rectangle             | users, orders              |
| Weak entity            | Double rectangle      | consumers, sellers         |
| Relationship           | Diamond               | places (consumer-order)    |
| Identifying relationship| Double diamond       | ISA (user-consumer)        |
| Attribute              | Oval                  | name, email                |
| Key attribute          | Underlined oval       | id                         |
| Derived attribute      | Dashed oval           | customer_segment           |
| Multi-valued attribute | Double oval           | (none in current design)   |
| Total participation    | Double line           | order → consumer           |
| Partial participation  | Single line           | order → review             |
| Cardinality            | 1, N, M               | consumer (1) → orders (N)  |

**Tham khảo ERD diagram:** [e_commerce_redshift.dbml](../dbml/e_commerce_redshift.dbml)

## III. Giải pháp kỹ thuật dữ liệu

> Trình bày các giải pháp kỹ thuật dữ liệu, liên quan và dựa trên các nhu cầu khai thác dữ liệu và đặc tính của dữ liệu ở 2 phần trên. <br>
> Dự đoán sẽ trình bày cách phân tích yêu cầu dữ liệu, để thiết kế các câu truy vấn. <br>
>
> Giới thiệu ít nhất 1 giải pháp thay thế (đối sánh). <br>

## IV. Công nghệ quản lý dữ liệu

> Trình bày công nghệ được phân công cho quản lý dữ liệu, công nghệ tự chọn cho xử lý dữ liệu, và các dự định khai thác công nghệ cho ứng dụng. <br>

## V. Triển khai

> Trình bày cách triển khai ứng dụng dựa trên để tài lựa chọn và công nghệ được giao. <br>
> Bối cảnh: E-Commerce. <br>
> Công nghệ: Data Warehouse - Amazon Redshift. <br>
> Flowchart: [Overall Flow](../flowcharts/overall_flow.mmd)

![alt text](../flowcharts/data_pipeline_project.png)

## VI. Đánh giá

> Tính đúng đắn của dữ liệu sau khi kỹ thuật dữ liệu được thực hiện. <br>
> Hiệu suất của giải pháp kỹ thuật dữ liệu. <br>
> Hiệu quả của việc hỗ trợ khai thác dữ liệu thông qua ứng dụng. <br>

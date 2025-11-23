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

| #   | Nhu cầu KTDL                         | Mô tả                                                                 |
| --- | ------------------------------------ | --------------------------------------------------------------------- |
| 1   | Phân tích doanh thu YoY hoặc MoM     | Theo dõi doanh thu ngày/tháng/năm để điều chỉnh chiến dịch marketing. |
| 2   | Phân tích và quản lý tồn kho         | Phát hiện sản phẩm sắp hết, tự động cảnh báo restock.                 |
| 3   | Phân tích hiệu suất bán hàng         | Đánh giá seller nào bán tốt để ưu tiên hiển thị.                      |
| 4   | Phân tích và báo cáo theo địa lý     | Xác định khu vực mua nhiều để tối ưu logistic & quảng cáo địa phương. |
| 5   | Phân tích đánh giá sản phẩm          | Phát hiện sản phẩm rating thấp để cải thiện chất lượng.               |
| 6   | Phân tích hiểu quả danh mục sản phẩm | Quyết định mở rộng danh mục nào.                                      |

## II. Nguồn dữ liệu

> Trình bày các nguồn dữ liệu dự kiến, các đặc điểm dữ liệu cần được lưu ý khi thực hiện kỹ thuật dữ liệu. <br>
> Có thể trình bày cách tổ chức dữ liệu, thiết kế dữ liệu, [ER Diagram](dbml/e_commerce_redshift.dbml). (tầng luận lý) <br> <br>
> Có cần trình bày thiết kế DB ở tầng ý niệm không ?

## III. Giải pháp kỹ thuật dữ liệu

> Trình bày các giải pháp kỹ thuật dữ liệu, liên quan và dựa trên các nhu cầu khai thác dữ liệu và đặc tính của dữ liệu ở 2 phần trên. <br>
> Dự đoán sẽ trình bày cách phân tích yêu cầu dữ liệu, để thiết kế các câu truy vấn. <br>
>
> Giới thiệu ít nhất 1 giải pháp thay thế (đối sánh). <br>

Giải pháp kỹ thuật dữ liệu được xây dựng trên nền tảng kho dữ liệu đám mây **Amazon Redshift**, một hệ thống quản lý dữ liệu phân tích được tối ưu hóa cho quy mô lớn. Theo nguyên tắc cơ bản của kỹ thuật dữ liệu, Redshift hỗ trợ mô hình data warehousing bằng cách tách biệt dữ liệu giao dịch (OLTP - Online Transaction Processing) khỏi dữ liệu phân tích (OLAP), giúp tránh tải nặng trên hệ thống vận hành hàng ngày. Lược đồ star schema trong tệp dbml – với bảng fact trung tâm như orders và transactions, kết nối với các bảng dimension như consumers, sellers, và commodities – thể hiện rõ nguyên tắc này: fact tables lưu trữ các chỉ số đo lường (metrics) như doanh thu và số lượng đơn hàng, trong khi dimension tables cung cấp ngữ cảnh (context) như thông tin khách hàng hoặc sản phẩm.

- **Quy trình ETL**: Dữ liệu được trích xuất (Extract) từ nguồn thô như file CSV trên S3, biến đổi (Transform) để làm sạch và denormalize (ví dụ: tính toán total_spent hoặc rating_avg để giảm join phức tạp), rồi tải (Load) vào Redshift qua lệnh COPY. Nguyên tắc ETL cơ bản đảm bảo dữ liệu nhất quán và sẵn sàng cho phân tích, tránh lỗi như duplicate records bằng cách sử dụng trigger hoặc lập lịch VACUUM/ANALYZE định kỳ.

- **Lưu trữ và phân bố dữ liệu**: Redshift áp dụng lưu trữ cột (columnar storage) – một kỹ thuật fundamental giúp truy vấn nhanh hơn bằng cách chỉ đọc cột cần thiết, thay vì toàn bộ hàng như trong RDBMS truyền thống. DISTKEY và SORTKEY được cấu hình để phân tán dữ liệu theo các trường thường join (như consumer_id), giảm thời gian shuffle dữ liệu trong truy vấn phân tán, phù hợp với nguyên tắc MPP (Massively Parallel Processing) để xử lý dữ liệu lớn.

- **Xử lý truy vấn OLAP**: Các truy vấn tổng hợp (aggregation) như SUM, COUNT, AVG được hỗ trợ hiệu quả nhờ SORTKEY trên created_at, cho phép phân tích thời gian (time-series analysis) mà không cần index phức tạp. Điều này phù hợp với nguyên tắc OLAP, nơi ưu tiên truy vấn đa chiều để hỗ trợ báo cáo kinh doanh, như phân tích doanh thu theo thời gian hoặc địa lý.

- **Tích hợp với mục tiêu tổ chức**: Trong ngữ cảnh thương mại điện tử, giải pháp này hỗ trợ data-driven decisions bằng cách cung cấp độ trễ thấp (low latency) cho các truy vấn phức tạp, giúp các bên liên quan như quản lý kinh doanh và đội ngũ vận hành khai thác dữ liệu thời gian thực. Ví dụ, denormalized fields giảm nhu cầu tính toán lặp lại, phù hợp với nguyên tắc data modeling để tối ưu hiệu suất.

Giải pháp này đảm bảo tính mở rộng (scalability) cho dữ liệu lên đến hàng trăm triệu bản ghi, với chi phí hợp lý dựa trên mô hình pay-per-use của AWS.

#### Giải Pháp Thay Thế: So Sánh Với Google BigQuery

Để đối sánh, một giải pháp thay thế là **Google BigQuery**, một kho dữ liệu đám mây không máy chủ (serverless) cũng tập trung vào phân tích dữ liệu lớn. BigQuery sử dụng kiến trúc columnar storage tương tự Redshift nhưng khác biệt ở mô hình tính toán: BigQuery tách biệt lưu trữ và tính toán, cho phép scale độc lập mà không cần quản lý cluster như Redshift.

- **Quy trình ETL**: BigQuery hỗ trợ tải dữ liệu qua lệnh LOAD DATA từ GCS (tương tự S3), nhưng tích hợp tốt hơn với Google Cloud ecosystem. So với Redshift's COPY, BigQuery tự động infer schema và xử lý lỗi tốt hơn, giảm công sức transform thủ công – phù hợp cho ETL fundamental khi dữ liệu thô đa dạng.

- **Lưu trữ và phân bố**: BigQuery không yêu cầu DISTKEY/SORTKEY thủ công; thay vào đó, sử dụng clustering và partitioning tự động dựa trên thời gian hoặc địa lý, giản hóa quản lý so với Redshift. Tuy nhiên, Redshift có lợi thế trong MPP cho truy vấn join nặng, trong khi BigQuery ưu tiên serverless để tránh downtime.

- **Xử lý truy vấn OLAP**: Cả hai hỗ trợ SQL chuẩn, nhưng BigQuery tích hợp ML qua BigQuery ML (ví dụ: CREATE MODEL cho dự báo doanh thu), dễ dàng hơn Redshift ML. Đối với time-series analysis, BigQuery's window functions hiệu quả tương đương, nhưng chi phí dựa trên byte scanned có thể cao hơn nếu truy vấn không tối ưu.

## IV. Công nghệ quản lý dữ liệu

> Trình bày công nghệ được phân công cho quản lý dữ liệu, công nghệ tự chọn cho xử lý dữ liệu, và các dự định khai thác công nghệ cho ứng dụng. <br>

### IV.1. Công nghệ quản lý dữ liệu

> Trình bày cơ bản về Redshift

### IV.2. Công nghệ xử lý dữ liệu

> Dữ liệu được xử lý bằng script và code python trước khi được xuất ra csv để upload lên S3 và ingest vào Redshift Database

### IV.3. Các dự định khai thác công nghệ cho ứng dụng

#### IV.3.1. Phân Tích Doanh Thu Theo Thời Gian

**Mục tiêu tổ chức**:
Theo dõi doanh thu theo ngày/tháng/năm để dự báo xu hướng và tối ưu hóa chiến dịch tiếp thị. <br>

**Kỹ thuật dữ liệu**:
Tổng hợp (SUM, COUNT, AVG) với nhóm theo thời gian; join bảng fact để lọc giao dịch hợp lệ. <br>

**Đầu vào**:

- Dữ liệu từ bảng orders (total_amount, created_at) và transactions (status).
- ETL: Sử dụng lệnh COPY tải file CSV từ S3, xử lý thời gian theo định dạng UTC.

**Đầu ra**:
Bảng kết quả với tháng, doanh thu, số đơn hàng, giá trị trung bình – xuất ra CSV cho công cụ BI. <br>

**Quy trình thực hiện**:

- ETL: COPY dữ liệu thô từ S3 vào bảng orders và transactions, sử dụng lệnh COPY với tùy chọn IGNOREHEADER.
- Thực hiện truy vấn SQL để tổng hợp.
- Sau xử lý: Sử dụng Redshift ML để dự báo xu hướng doanh thu.

```sql
-- Doanh thu theo tháng (2025)
SELECT
    DATE_TRUNC('month', o.created_at) AS month,
    SUM(o.total_amount) AS revenue,
    COUNT(DISTINCT o.id) AS total_orders,
    AVG(o.total_amount) AS avg_order_value
FROM orders o
JOIN transactions t ON o.id = t.order_id
WHERE t.status = 'captured'
  AND o.created_at >= '2025-01-01'
GROUP BY 1
ORDER BY 1;
```

#### IV.3.2. Phân Tích Và Quản Lý Tồn Kho

**Mục tiêu tổ chức**:
Phát hiện sản phẩm sắp hết hàng để tránh mất doanh thu và duy trì sự hài lòng khách hàng.

**Kỹ thuật dữ liệu**:
Phép toán trừ trên trường denormalized; lọc theo ngưỡng.

**Đầu vào**:

- Bảng commodities (quantity, reserved_quantity, reorder_level).
- ETL: COPY file CSV từ S3, cập nhật hàng giờ qua lập lịch.

**Đầu ra**:
Danh sách sản phẩm cần tái nhập – kích hoạt cảnh báo qua SNS.

**Quy trình thực hiện**:

- ETL: COPY dữ liệu thô từ S3, tính toán available_stock trong quy trình tải.
- Thực hiện truy vấn lọc và sắp xếp.
- Tích hợp: Kết nối với hệ thống backend để gửi thông báo tự động cho nhà bán hàng.

```sql
SELECT
    c.sku, c.name,
    c.quantity - c.reserved_quantity AS available_stock,
    c.reorder_level, c.reorder_quantity
FROM commodities c
WHERE c.status = 'available'
  AND (c.quantity - c.reserved_quantity) <= c.reorder_level
ORDER BY available_stock;
```

#### IV.3.3. Phân Tích Hiệu Suất Bán Hàng

**Mục tiêu tổ chức**:
Đánh giá nhà bán hàng để ưu tiên hiển thị và cấp huy hiệu (ví dụ: top seller).

**Kỹ thuật dữ liệu**:
Join đa bảng (orders, sellers, users, order_commodities); tổng hợp doanh thu và số lượng.

**Đầu vào**:

- Dữ liệu từ sellers (rating_avg), orders (status, paid_at), order_commodities (line_total).
- ETL: COPY CSV từ S3, đảm bảo tính nhất quán dữ liệu.

**Đầu ra**: Danh sách top nhà bán hàng – sử dụng cho báo cáo dashboard.

**Quy trình thực hiện**:

- ETL: COPY dữ liệu thô từ S3 vào các bảng liên quan, xử lý null trong line_total.
- Thực hiện truy vấn với join và nhóm.
- Sau xử lý: Tích hợp với công cụ trực quan hóa để hiển thị biểu đồ.

```sql
-- Top 10 seller theo doanh thu tháng
SELECT
    s.id, u.username,
    SUM(oc.line_total) AS revenue,
    COUNT(DISTINCT o.id) AS orders,
    s.rating_avg
FROM sellers s
JOIN users u ON s.id = u.id
JOIN orders o ON o.seller_id = s.id
JOIN order_commodities oc ON o.id = oc.order_id
WHERE o.status IN ('delivered', 'done')
  AND o.paid_at >= DATE_TRUNC('month', CURRENT_DATE)
GROUP BY 1, 2, 5
ORDER BY revenue DESC
LIMIT 10;
```

#### IV.3.4. Phân Tích Và Báo Cáo Theo Địa Lý

**Mục tiêu tổ chức**:
Xác định khu vực có nhu cầu cao để tối ưu hóa logistics và quảng cáo địa phương.

**Kỹ thuật dữ liệu**:
Nhóm theo địa lý (delivery_city, delivery_country); tổng hợp doanh thu và phí vận chuyển.

**Đầu vào**:

- Bảng orders (delivery_city, delivery_province, total_amount).
- ETL: COPY CSV từ S3, bao gồm tọa độ địa lý.

**Đầu ra**:
Báo cáo doanh thu theo tỉnh/thành – hỗ trợ phân tích không gian.

**Quy trình thực hiện**:

- ETL: COPY dữ liệu thô từ S3, chuẩn hóa tên địa danh.
- Thực hiện truy vấn nhóm và sắp xếp.
- Sau xử lý: Kết nối với GIS để vẽ bản đồ.

```sql
-- Doanh thu theo tỉnh/thành phố, ví dụ: USA
SELECT
    o.delivery_city, o.delivery_province,
    COUNT(o.id) AS orders,
    SUM(o.total_amount) AS revenue,
    AVG(o.shipping_fee) AS avg_shipping
FROM orders o
WHERE o.delivery_country = 'USA'
  AND o.status IN ('delivered', 'done')
GROUP BY 1, 2
ORDER BY revenue DESC
LIMIT 20;
```

#### IV.3.5. Phân Tích Đánh Giá Sản Phẩm

**Mục tiêu tổ chức**:
Phát hiện sản phẩm có đánh giá thấp để cải thiện chất lượng và quản lý danh mục.

**Kỹ thuật dữ liệu**:
Join với reviews; tổng hợp trung bình đánh giá, lọc theo ngưỡng.

**Đầu vào**:

- Bảng commodities (rating_avg, review_count), reviews (rate, status).
- ETL: COPY CSV từ S3, cập nhật đánh giá mới.

**Đầu ra**:
Danh sách sản phẩm cần cải thiện – sử dụng cho quản lý sản phẩm.

**Quy trình thực hiện**:

- ETL: COPY dữ liệu thô từ S3, tính toán rating_avg denormalized.
- Thực hiện truy vấn với điều kiện.
- Sau xử lý: Phân tích cảm xúc từ comment sử dụng công cụ NLP.

```sql
-- Sản phẩm rating thấp nhất (vd: có ít nhất 10 review)
SELECT
    c.sku, c.name,
    c.rating_avg, c.review_count,
    ROUND(AVG(r.rate), 2) AS calculated_avg
FROM commodities c
LEFT JOIN reviews r ON c.id = r.commodity_id AND r.status = 'published'
WHERE c.review_count >= 10
GROUP BY 1, 2, 3, 4
HAVING c.rating_avg < 3.5
ORDER BY c.rating_avg;
```

#### IV.3.6. Phân Tích Hiệu Quả Danh Mục Sản Phẩm

**Mục tiêu tổ chức**:
Quyết định mở rộng danh mục dựa trên doanh thu và số lượng bán.

**Kỹ thuật dữ liệu**:
Join đa bảng (verticals, commodities, order_commodities, orders); tổng hợp doanh thu theo danh mục.

**Đầu vào**:

- Bảng verticals (name), commodities (vertical_id), order_commodities (line_total, quantity).
- ETL: COPY CSV từ S3, liên kết danh mục.

**Đầu ra**:
Báo cáo hiệu quả danh mục – hỗ trợ chiến lược sản phẩm.

**Quy trình thực hiện**:

- ETL: COPY dữ liệu thô từ S3, đảm bảo tính toàn vẹn tham chiếu.
- Thực hiện truy vấn tổng hợp.
- Sau xử lý: Dự báo xu hướng danh mục sử dụng mô hình thời gian.

```sql
-- Doanh thu theo danh mục
SELECT
    v.name AS vertical,
    COUNT(DISTINCT c.id) AS products,
    SUM(oc.line_total) AS revenue,
    SUM(oc.quantity) AS units_sold
FROM verticals v
JOIN commodities c ON v.id = c.vertical_id
JOIN order_commodities oc ON c.id = oc.commodity_id
JOIN orders o ON oc.order_id = o.id
WHERE o.status IN ('delivered', 'done')
GROUP BY 1
ORDER BY revenue DESC;
```

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

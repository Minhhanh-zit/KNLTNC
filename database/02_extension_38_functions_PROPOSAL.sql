/* KNLTNC: Thiết kế mở rộng 38 chức năng, SQL Server 2022.
   CHẠY SAU database/01_cinema_management_schema_v4.sql trên DB TEST.
   Không sửa hoặc xóa dữ liệu/bảng V5. Các nghiệp vụ cần API, transaction, test riêng.
*/
USE CinemaManagementV5_DualChannel;
GO
IF OBJECT_ID(N'dbo.customer_support',N'U') IS NULL
BEGIN
  CREATE TABLE dbo.[customer_support] (
    [support_id] BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_customer_support PRIMARY KEY,
    [customer_id] INT NOT NULL,
    [assigned_to] INT,
    [subject] NVARCHAR(200) NOT NULL,
    [content] NVARCHAR(MAX) NOT NULL,
    [status] VARCHAR(20) NOT NULL,
    [created_at] DATETIME2(0) NOT NULL
  );
END;
GO
IF OBJECT_ID(N'dbo.employee_profiles',N'U') IS NULL
BEGIN
  CREATE TABLE dbo.[employee_profiles] (
    [employee_id] INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_employee_profiles PRIMARY KEY,
    [user_id] INT NOT NULL CONSTRAINT UQ_employee_profiles_user_id UNIQUE,
    [contract_number] VARCHAR(50),
    [contract_start] DATE,
    [contract_end] DATE,
    [base_salary] DECIMAL(14,2)
  );
END;
GO
IF OBJECT_ID(N'dbo.work_shifts',N'U') IS NULL
BEGIN
  CREATE TABLE dbo.[work_shifts] (
    [shift_id] BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_work_shifts PRIMARY KEY,
    [cinema_id] INT NOT NULL,
    [shift_name] NVARCHAR(80) NOT NULL,
    [starts_at] DATETIME2(0) NOT NULL,
    [ends_at] DATETIME2(0) NOT NULL,
    [status] VARCHAR(20) NOT NULL
  );
END;
GO
IF OBJECT_ID(N'dbo.shift_assignments',N'U') IS NULL
BEGIN
  CREATE TABLE dbo.[shift_assignments] (
    [assignment_id] BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_shift_assignments PRIMARY KEY,
    [shift_id] BIGINT NOT NULL,
    [employee_id] INT NOT NULL,
    [status] VARCHAR(20) NOT NULL
  );
END;
GO
IF OBJECT_ID(N'dbo.attendance_records',N'U') IS NULL
BEGIN
  CREATE TABLE dbo.[attendance_records] (
    [attendance_id] BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_attendance_records PRIMARY KEY,
    [assignment_id] BIGINT NOT NULL CONSTRAINT UQ_attendance_records_assignment_id UNIQUE,
    [check_in] DATETIME2(0),
    [check_out] DATETIME2(0),
    [status] VARCHAR(20) NOT NULL
  );
END;
GO
IF OBJECT_ID(N'dbo.leave_requests',N'U') IS NULL
BEGIN
  CREATE TABLE dbo.[leave_requests] (
    [leave_id] BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_leave_requests PRIMARY KEY,
    [employee_id] INT NOT NULL,
    [from_date] DATE NOT NULL,
    [to_date] DATE NOT NULL,
    [status] VARCHAR(20) NOT NULL,
    [approved_by] INT
  );
END;
GO
IF OBJECT_ID(N'dbo.payrolls',N'U') IS NULL
BEGIN
  CREATE TABLE dbo.[payrolls] (
    [payroll_id] BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_payrolls PRIMARY KEY,
    [employee_id] INT NOT NULL,
    [period_month] DATE NOT NULL,
    [base_amount] DECIMAL(14,2) NOT NULL,
    [allowance] DECIMAL(14,2) NOT NULL,
    [deduction] DECIMAL(14,2) NOT NULL,
    [net_amount] DECIMAL(14,2) NOT NULL,
    [status] VARCHAR(20) NOT NULL
  );
END;
GO
IF OBJECT_ID(N'dbo.maintenance_records',N'U') IS NULL
BEGIN
  CREATE TABLE dbo.[maintenance_records] (
    [maintenance_id] BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_maintenance_records PRIMARY KEY,
    [room_id] INT NOT NULL,
    [seat_id] INT,
    [reported_by] INT NOT NULL,
    [description] NVARCHAR(MAX) NOT NULL,
    [status] VARCHAR(20) NOT NULL,
    [created_at] DATETIME2(0) NOT NULL
  );
END;
GO
IF OBJECT_ID(N'dbo.products',N'U') IS NULL
BEGIN
  CREATE TABLE dbo.[products] (
    [product_id] INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_products PRIMARY KEY,
    [product_name] NVARCHAR(120) NOT NULL,
    [unit_price] DECIMAL(12,2) NOT NULL,
    [status] VARCHAR(20) NOT NULL
  );
END;
GO
IF OBJECT_ID(N'dbo.product_orders',N'U') IS NULL
BEGIN
  CREATE TABLE dbo.[product_orders] (
    [product_order_id] BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_product_orders PRIMARY KEY,
    [sale_id] BIGINT,
    [cashier_id] INT,
    [created_at] DATETIME2(0) NOT NULL,
    [status] VARCHAR(20) NOT NULL
  );
END;
GO
IF OBJECT_ID(N'dbo.product_order_items',N'U') IS NULL
BEGIN
  CREATE TABLE dbo.[product_order_items] (
    [item_id] BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_product_order_items PRIMARY KEY,
    [product_order_id] BIGINT NOT NULL,
    [product_id] INT NOT NULL,
    [quantity] INT NOT NULL,
    [unit_price] DECIMAL(12,2) NOT NULL
  );
END;
GO
IF OBJECT_ID(N'dbo.inventory_movements',N'U') IS NULL
BEGIN
  CREATE TABLE dbo.[inventory_movements] (
    [movement_id] BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_inventory_movements PRIMARY KEY,
    [cinema_id] INT NOT NULL,
    [product_id] INT NOT NULL,
    [quantity_delta] INT NOT NULL,
    [reason] VARCHAR(30) NOT NULL,
    [created_at] DATETIME2(0) NOT NULL
  );
END;
GO
IF OBJECT_ID(N'dbo.promotions',N'U') IS NULL
BEGIN
  CREATE TABLE dbo.[promotions] (
    [promotion_id] INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_promotions PRIMARY KEY,
    [code] VARCHAR(50) NOT NULL CONSTRAINT UQ_promotions_code UNIQUE,
    [discount_type] VARCHAR(15) NOT NULL,
    [discount_value] DECIMAL(12,2) NOT NULL,
    [starts_at] DATETIME2(0) NOT NULL,
    [ends_at] DATETIME2(0) NOT NULL,
    [usage_limit] INT
  );
END;
GO
IF OBJECT_ID(N'dbo.sale_promotions',N'U') IS NULL
BEGIN
  CREATE TABLE dbo.[sale_promotions] (
    [sale_id] BIGINT NOT NULL CONSTRAINT PK_sale_promotions PRIMARY KEY,
    [promotion_id] INT NOT NULL,
    [discount_amount] DECIMAL(12,2) NOT NULL
  );
END;
GO
IF OBJECT_ID(N'dbo.refund_requests',N'U') IS NULL
BEGIN
  CREATE TABLE dbo.[refund_requests] (
    [refund_id] BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_refund_requests PRIMARY KEY,
    [sale_id] BIGINT NOT NULL,
    [payment_id] BIGINT NOT NULL,
    [requested_amount] DECIMAL(12,2) NOT NULL,
    [refunded_amount] DECIMAL(12,2),
    [status] VARCHAR(25) NOT NULL,
    [reason] NVARCHAR(500),
    [requested_at] DATETIME2(0) NOT NULL
  );
END;
GO
IF OBJECT_ID(N'dbo.showtime_cancellations',N'U') IS NULL
BEGIN
  CREATE TABLE dbo.[showtime_cancellations] (
    [cancellation_id] BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_showtime_cancellations PRIMARY KEY,
    [showtime_id] BIGINT NOT NULL,
    [requested_by] INT NOT NULL,
    [reason] NVARCHAR(500) NOT NULL,
    [status] VARCHAR(25) NOT NULL,
    [created_at] DATETIME2(0) NOT NULL
  );
END;
GO
IF OBJECT_ID(N'dbo.notifications',N'U') IS NULL
BEGIN
  CREATE TABLE dbo.[notifications] (
    [notification_id] BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_notifications PRIMARY KEY,
    [user_id] INT NOT NULL,
    [sale_id] BIGINT,
    [channel] VARCHAR(20) NOT NULL,
    [recipient] NVARCHAR(160) NOT NULL,
    [status] VARCHAR(20) NOT NULL,
    [sent_at] DATETIME2(0)
  );
END;
GO
IF OBJECT_ID(N'dbo.reviews',N'U') IS NULL
BEGIN
  CREATE TABLE dbo.[reviews] (
    [review_id] BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_reviews PRIMARY KEY,
    [customer_id] INT NOT NULL,
    [movie_id] INT NOT NULL,
    [rating] INT NOT NULL,
    [comment] NVARCHAR(MAX),
    [created_at] DATETIME2(0) NOT NULL
  );
END;
GO
IF OBJECT_ID(N'dbo.audit_logs',N'U') IS NULL
BEGIN
  CREATE TABLE dbo.[audit_logs] (
    [audit_id] BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_audit_logs PRIMARY KEY,
    [actor_id] INT,
    [action] VARCHAR(80) NOT NULL,
    [entity_name] VARCHAR(80) NOT NULL,
    [entity_key] VARCHAR(80),
    [created_at] DATETIME2(0) NOT NULL
  );
END;
GO
IF OBJECT_ID(N'dbo.price_rules',N'U') IS NULL
BEGIN
  CREATE TABLE dbo.[price_rules] (
    [price_rule_id] INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_price_rules PRIMARY KEY,
    [cinema_id] INT,
    [seat_type_id] INT,
    [start_date] DATE,
    [end_date] DATE,
    [adjustment] DECIMAL(12,2) NOT NULL,
    [status] VARCHAR(20) NOT NULL
  );
END;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_customer_support_customer_id')
  ALTER TABLE dbo.[customer_support] ADD CONSTRAINT FK_customer_support_customer_id FOREIGN KEY ([customer_id]) REFERENCES dbo.[users]([user_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_customer_support_assigned_to')
  ALTER TABLE dbo.[customer_support] ADD CONSTRAINT FK_customer_support_assigned_to FOREIGN KEY ([assigned_to]) REFERENCES dbo.[users]([user_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_employee_profiles_user_id')
  ALTER TABLE dbo.[employee_profiles] ADD CONSTRAINT FK_employee_profiles_user_id FOREIGN KEY ([user_id]) REFERENCES dbo.[users]([user_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_work_shifts_cinema_id')
  ALTER TABLE dbo.[work_shifts] ADD CONSTRAINT FK_work_shifts_cinema_id FOREIGN KEY ([cinema_id]) REFERENCES dbo.[cinemas]([cinema_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_shift_assignments_shift_id')
  ALTER TABLE dbo.[shift_assignments] ADD CONSTRAINT FK_shift_assignments_shift_id FOREIGN KEY ([shift_id]) REFERENCES dbo.[work_shifts]([shift_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_shift_assignments_employee_id')
  ALTER TABLE dbo.[shift_assignments] ADD CONSTRAINT FK_shift_assignments_employee_id FOREIGN KEY ([employee_id]) REFERENCES dbo.[employee_profiles]([employee_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_attendance_records_assignment_id')
  ALTER TABLE dbo.[attendance_records] ADD CONSTRAINT FK_attendance_records_assignment_id FOREIGN KEY ([assignment_id]) REFERENCES dbo.[shift_assignments]([assignment_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_leave_requests_employee_id')
  ALTER TABLE dbo.[leave_requests] ADD CONSTRAINT FK_leave_requests_employee_id FOREIGN KEY ([employee_id]) REFERENCES dbo.[employee_profiles]([employee_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_leave_requests_approved_by')
  ALTER TABLE dbo.[leave_requests] ADD CONSTRAINT FK_leave_requests_approved_by FOREIGN KEY ([approved_by]) REFERENCES dbo.[users]([user_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_payrolls_employee_id')
  ALTER TABLE dbo.[payrolls] ADD CONSTRAINT FK_payrolls_employee_id FOREIGN KEY ([employee_id]) REFERENCES dbo.[employee_profiles]([employee_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_maintenance_records_room_id')
  ALTER TABLE dbo.[maintenance_records] ADD CONSTRAINT FK_maintenance_records_room_id FOREIGN KEY ([room_id]) REFERENCES dbo.[rooms]([room_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_maintenance_records_seat_id')
  ALTER TABLE dbo.[maintenance_records] ADD CONSTRAINT FK_maintenance_records_seat_id FOREIGN KEY ([seat_id]) REFERENCES dbo.[seats]([seat_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_maintenance_records_reported_by')
  ALTER TABLE dbo.[maintenance_records] ADD CONSTRAINT FK_maintenance_records_reported_by FOREIGN KEY ([reported_by]) REFERENCES dbo.[users]([user_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_product_orders_sale_id')
  ALTER TABLE dbo.[product_orders] ADD CONSTRAINT FK_product_orders_sale_id FOREIGN KEY ([sale_id]) REFERENCES dbo.[sales]([sale_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_product_orders_cashier_id')
  ALTER TABLE dbo.[product_orders] ADD CONSTRAINT FK_product_orders_cashier_id FOREIGN KEY ([cashier_id]) REFERENCES dbo.[users]([user_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_product_order_items_product_order_id')
  ALTER TABLE dbo.[product_order_items] ADD CONSTRAINT FK_product_order_items_product_order_id FOREIGN KEY ([product_order_id]) REFERENCES dbo.[product_orders]([product_order_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_product_order_items_product_id')
  ALTER TABLE dbo.[product_order_items] ADD CONSTRAINT FK_product_order_items_product_id FOREIGN KEY ([product_id]) REFERENCES dbo.[products]([product_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_inventory_movements_cinema_id')
  ALTER TABLE dbo.[inventory_movements] ADD CONSTRAINT FK_inventory_movements_cinema_id FOREIGN KEY ([cinema_id]) REFERENCES dbo.[cinemas]([cinema_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_inventory_movements_product_id')
  ALTER TABLE dbo.[inventory_movements] ADD CONSTRAINT FK_inventory_movements_product_id FOREIGN KEY ([product_id]) REFERENCES dbo.[products]([product_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_sale_promotions_sale_id')
  ALTER TABLE dbo.[sale_promotions] ADD CONSTRAINT FK_sale_promotions_sale_id FOREIGN KEY ([sale_id]) REFERENCES dbo.[sales]([sale_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_sale_promotions_promotion_id')
  ALTER TABLE dbo.[sale_promotions] ADD CONSTRAINT FK_sale_promotions_promotion_id FOREIGN KEY ([promotion_id]) REFERENCES dbo.[promotions]([promotion_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_refund_requests_sale_id')
  ALTER TABLE dbo.[refund_requests] ADD CONSTRAINT FK_refund_requests_sale_id FOREIGN KEY ([sale_id]) REFERENCES dbo.[sales]([sale_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_refund_requests_payment_id')
  ALTER TABLE dbo.[refund_requests] ADD CONSTRAINT FK_refund_requests_payment_id FOREIGN KEY ([payment_id]) REFERENCES dbo.[payments]([payment_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_showtime_cancellations_showtime_id')
  ALTER TABLE dbo.[showtime_cancellations] ADD CONSTRAINT FK_showtime_cancellations_showtime_id FOREIGN KEY ([showtime_id]) REFERENCES dbo.[showtimes]([showtime_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_showtime_cancellations_requested_by')
  ALTER TABLE dbo.[showtime_cancellations] ADD CONSTRAINT FK_showtime_cancellations_requested_by FOREIGN KEY ([requested_by]) REFERENCES dbo.[users]([user_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_notifications_user_id')
  ALTER TABLE dbo.[notifications] ADD CONSTRAINT FK_notifications_user_id FOREIGN KEY ([user_id]) REFERENCES dbo.[users]([user_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_notifications_sale_id')
  ALTER TABLE dbo.[notifications] ADD CONSTRAINT FK_notifications_sale_id FOREIGN KEY ([sale_id]) REFERENCES dbo.[sales]([sale_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_reviews_customer_id')
  ALTER TABLE dbo.[reviews] ADD CONSTRAINT FK_reviews_customer_id FOREIGN KEY ([customer_id]) REFERENCES dbo.[users]([user_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_reviews_movie_id')
  ALTER TABLE dbo.[reviews] ADD CONSTRAINT FK_reviews_movie_id FOREIGN KEY ([movie_id]) REFERENCES dbo.[movies]([movie_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_audit_logs_actor_id')
  ALTER TABLE dbo.[audit_logs] ADD CONSTRAINT FK_audit_logs_actor_id FOREIGN KEY ([actor_id]) REFERENCES dbo.[users]([user_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_price_rules_cinema_id')
  ALTER TABLE dbo.[price_rules] ADD CONSTRAINT FK_price_rules_cinema_id FOREIGN KEY ([cinema_id]) REFERENCES dbo.[cinemas]([cinema_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_price_rules_seat_type_id')
  ALTER TABLE dbo.[price_rules] ADD CONSTRAINT FK_price_rules_seat_type_id FOREIGN KEY ([seat_type_id]) REFERENCES dbo.[seat_types]([seat_type_id]);
GO

/* Quy tắc nghiệp vụ cần thực thi tại service / transaction:
 - Hủy suất có vé đã thanh toán: chặn hoặc tạo yêu cầu xử lý/hoàn tiền thủ công.
 - Chốt ca: sales.cashier_id đã có; cần gắn sale với shift_assignment_id ở migration riêng sau khi chốt quy tắc ca.
 - Hoàn tiền không đồng nghĩa xóa payment/ticket; doanh thu ròng phải trừ refund thành công.
 - Giá vé và khuyến mãi phải chốt giá tại thời điểm mua; chống sử dụng voucher vượt giới hạn.
 - Kho hàng dùng sổ biến động inventory_movements, kiểm soát số tồn bằng transaction.
 - Chấm công, lương, gửi email, nhật ký cần logic kiểm tra quyền và kiểm thử riêng.
*/

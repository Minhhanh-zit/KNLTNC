/* HỆ THỐNG QUẢN LÝ RẠP PHIM: BẢN HỢP NHẤT V4 + V5 (HAI KÊNH), SQL SERVER 2022
   Script chỉ dùng cho DB MỚI, KHÔNG phải migration. Thành viên nhóm đã báo cáo log 15/15 ca kiểm thử PASS trên SQL Server 2022; không thay thế kiểm thử toàn bộ hệ thống.
   Cổng thanh toán là mô phỏng; backend phải tự xác minh chữ ký và đối soát với cổng.
   Không cung cấp quyền cập nhật bảng nghiệp vụ trực tiếp cho tài khoản ứng dụng. */
IF DB_ID(N'CinemaManagementV5_DualChannel') IS NULL
BEGIN
    CREATE DATABASE CinemaManagementV5_DualChannel;
END;
GO
USE CinemaManagementV5_DualChannel;
GO

-- 01. Vai trò nhân viên
CREATE TABLE dbo.roles (
    role_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_roles PRIMARY KEY,
    role_code VARCHAR(30) NOT NULL CONSTRAINT UQ_roles_code UNIQUE,
    role_name NVARCHAR(80) NOT NULL
);
GO

-- 02. Rạp phim
CREATE TABLE dbo.cinemas (
    cinema_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_cinemas PRIMARY KEY,
    cinema_name NVARCHAR(150) NOT NULL,
    [address] NVARCHAR(255) NOT NULL,
    [status] VARCHAR(20) NOT NULL CONSTRAINT DF_cinemas_status DEFAULT ('ACTIVE'),
    CONSTRAINT CK_cinemas_status CHECK ([status] IN ('ACTIVE','INACTIVE'))
);
GO

-- 03. Nhân viên. Admin tổng có cinema_id NULL; nhân viên rạp cần được gắn rạp.
CREATE TABLE dbo.[users] (
    user_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_users PRIMARY KEY,
    role_id INT NOT NULL,
    cinema_id INT NULL,
    username VARCHAR(80) NOT NULL CONSTRAINT UQ_users_username UNIQUE,
    full_name NVARCHAR(120) NOT NULL,
    email NVARCHAR(160) NULL,
    phone VARCHAR(20) NULL,
    password_hash VARCHAR(255) NOT NULL,
    [status] VARCHAR(20) NOT NULL CONSTRAINT DF_users_status DEFAULT ('ACTIVE'),
    created_at DATETIME2(0) NOT NULL CONSTRAINT DF_users_created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_users_roles FOREIGN KEY (role_id) REFERENCES dbo.roles(role_id),
    CONSTRAINT FK_users_cinemas FOREIGN KEY (cinema_id) REFERENCES dbo.cinemas(cinema_id),
    CONSTRAINT CK_users_status CHECK ([status] IN ('ACTIVE','LOCKED'))
);
GO

-- 04. Phim
CREATE TABLE dbo.movies (
    movie_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_movies PRIMARY KEY,
    title NVARCHAR(250) NOT NULL,
    [description] NVARCHAR(MAX) NULL,
    duration_minutes INT NOT NULL,
    release_date DATE NULL,
    age_rating VARCHAR(10) NOT NULL,
    [status] VARCHAR(20) NOT NULL CONSTRAINT DF_movies_status DEFAULT ('DRAFT'),
    CONSTRAINT CK_movies_duration CHECK (duration_minutes > 0),
    CONSTRAINT CK_movies_status CHECK ([status] IN ('DRAFT','PUBLISHED','ARCHIVED')),
    CONSTRAINT CK_movies_age_rating CHECK (age_rating IN ('P','K','T13','T16','T18','C'))
);
GO

-- 05. Thể loại
CREATE TABLE dbo.genres (
    genre_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_genres PRIMARY KEY,
    genre_name NVARCHAR(80) NOT NULL CONSTRAINT UQ_genres_name UNIQUE,
    is_active BIT NOT NULL CONSTRAINT DF_genres_active DEFAULT (1)
);
GO

-- 06. Bảng trung gian N-N giữa phim và thể loại
CREATE TABLE dbo.movie_genres (
    movie_id INT NOT NULL,
    genre_id INT NOT NULL,
    CONSTRAINT PK_movie_genres PRIMARY KEY (movie_id, genre_id),
    CONSTRAINT FK_movie_genres_movies FOREIGN KEY (movie_id) REFERENCES dbo.movies(movie_id),
    CONSTRAINT FK_movie_genres_genres FOREIGN KEY (genre_id) REFERENCES dbo.genres(genre_id)
);
GO

-- 07. Phòng chiếu
CREATE TABLE dbo.rooms (
    room_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_rooms PRIMARY KEY,
    cinema_id INT NOT NULL,
    room_name NVARCHAR(80) NOT NULL,
    [status] VARCHAR(20) NOT NULL CONSTRAINT DF_rooms_status DEFAULT ('ACTIVE'),
    CONSTRAINT FK_rooms_cinemas FOREIGN KEY (cinema_id) REFERENCES dbo.cinemas(cinema_id),
    CONSTRAINT UQ_rooms_cinema_name UNIQUE (cinema_id, room_name),
    CONSTRAINT CK_rooms_status CHECK ([status] IN ('ACTIVE','MAINTENANCE'))
);
GO

-- 08. Loại ghế
CREATE TABLE dbo.seat_types (
    seat_type_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_seat_types PRIMARY KEY,
    type_name NVARCHAR(60) NOT NULL CONSTRAINT UQ_seat_types_name UNIQUE,
    price_surcharge DECIMAL(12,2) NOT NULL CONSTRAINT DF_seat_types_surcharge DEFAULT (0),
    is_active BIT NOT NULL CONSTRAINT DF_seat_types_active DEFAULT (1),
    CONSTRAINT CK_seat_types_surcharge CHECK (price_surcharge >= 0)
);
GO

-- 09. Ghế vật lý tại từng phòng
CREATE TABLE dbo.seats (
    seat_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_seats PRIMARY KEY,
    room_id INT NOT NULL,
    seat_type_id INT NOT NULL,
    row_label VARCHAR(5) NOT NULL,
    seat_number INT NOT NULL,
    is_active BIT NOT NULL CONSTRAINT DF_seats_active DEFAULT (1),
    CONSTRAINT FK_seats_rooms FOREIGN KEY (room_id) REFERENCES dbo.rooms(room_id),
    CONSTRAINT FK_seats_types FOREIGN KEY (seat_type_id) REFERENCES dbo.seat_types(seat_type_id),
    CONSTRAINT UQ_seats_position UNIQUE (room_id,row_label,seat_number),
    CONSTRAINT CK_seats_number CHECK (seat_number > 0)
);
GO

-- 10. Lịch chiếu
CREATE TABLE dbo.showtimes (
    showtime_id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_showtimes PRIMARY KEY,
    movie_id INT NOT NULL,
    room_id INT NOT NULL,
    starts_at DATETIMEOFFSET(0) NOT NULL,
    ends_at DATETIMEOFFSET(0) NOT NULL,
    base_price DECIMAL(12,2) NOT NULL,
    [status] VARCHAR(20) NOT NULL CONSTRAINT DF_showtimes_status DEFAULT ('DRAFT'),
    created_by INT NOT NULL,
    CONSTRAINT FK_showtimes_movies FOREIGN KEY (movie_id) REFERENCES dbo.movies(movie_id),
    CONSTRAINT FK_showtimes_rooms FOREIGN KEY (room_id) REFERENCES dbo.rooms(room_id),
    CONSTRAINT FK_showtimes_users FOREIGN KEY (created_by) REFERENCES dbo.[users](user_id),
    CONSTRAINT CK_showtimes_interval CHECK (ends_at > starts_at),
    CONSTRAINT CK_showtimes_price CHECK (base_price >= 0),
    CONSTRAINT CK_showtimes_status CHECK ([status] IN ('DRAFT','PUBLISHED','CANCELLED','FINISHED'))
);
GO
CREATE INDEX IX_showtimes_room_start ON dbo.showtimes(room_id, starts_at);
CREATE INDEX IX_showtimes_movie_start ON dbo.showtimes(movie_id, starts_at);
GO

-- 11. Ghế theo suất + giữ tạm: không thêm bảng riêng cho lượt giữ ghế.
CREATE TABLE dbo.showtime_seats (
    showtime_seat_id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_showtime_seats PRIMARY KEY,
    showtime_id BIGINT NOT NULL,
    seat_id INT NOT NULL,
    -- Một hóa đơn PENDING có thể giữ nhiều ghế; NULL nghĩa là không bị giữ.
    -- Hệ thống lấy giờ UTC, không lưu trực tiếp trạng thái SOLD vì đã có tickets.
    held_sale_id BIGINT NULL,
    held_unit_price DECIMAL(12,2) NULL,
    CONSTRAINT CK_showtime_seats_hold_all_or_none CHECK (
        (held_sale_id IS NULL AND held_unit_price IS NULL)
        OR (held_sale_id IS NOT NULL AND held_unit_price IS NOT NULL AND held_unit_price >= 0)
    ),
    CONSTRAINT FK_showtime_seats_showtimes FOREIGN KEY (showtime_id) REFERENCES dbo.showtimes(showtime_id),
    CONSTRAINT FK_showtime_seats_seats FOREIGN KEY (seat_id) REFERENCES dbo.seats(seat_id),
    CONSTRAINT UQ_showtime_seats_position UNIQUE (showtime_id, seat_id),
    CONSTRAINT UQ_showtime_seats_id_showtime UNIQUE (showtime_seat_id,showtime_id)
);
GO
CREATE INDEX IX_showtime_seats_showtime ON dbo.showtime_seats(showtime_id);
CREATE INDEX IX_showtime_seats_held_sale ON dbo.showtime_seats(held_sale_id)
    WHERE held_sale_id IS NOT NULL;
GO

-- 12. Hóa đơn hai kênh. Mỗi đơn thuộc một suất; EXPIRED khi hết thời hạn giữ.
CREATE TABLE dbo.sales (
    sale_id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_sales PRIMARY KEY,
    receipt_code VARCHAR(40) NOT NULL CONSTRAINT UQ_sales_code UNIQUE,
    showtime_id BIGINT NOT NULL,
    cashier_id INT NULL,
    customer_id INT NULL,
    sales_channel VARCHAR(10) NOT NULL,
    payment_choice VARCHAR(20) NOT NULL,
    pickup_code_hash VARBINARY(32) NULL,
    [status] VARCHAR(20) NOT NULL CONSTRAINT DF_sales_status DEFAULT ('PENDING'),
    created_at DATETIME2(0) NOT NULL CONSTRAINT DF_sales_created DEFAULT SYSUTCDATETIME(),
    completed_at DATETIME2(0) NULL,
    -- Cả hóa đơn giữ chung một hạn; giữ số ghế để kiểm tra toàn bộ khi thanh toán.
    hold_expires_at DATETIME2(3) NULL,
    held_seat_count INT NULL,
    CONSTRAINT UQ_sales_id_showtime UNIQUE(sale_id,showtime_id),
    CONSTRAINT CK_sales_hold_pair CHECK (
        (hold_expires_at IS NULL AND held_seat_count IS NULL)
        OR (hold_expires_at IS NOT NULL AND held_seat_count > 0)
    ),
    CONSTRAINT FK_sales_showtimes FOREIGN KEY (showtime_id) REFERENCES dbo.showtimes(showtime_id),
    CONSTRAINT FK_sales_cashiers FOREIGN KEY (cashier_id) REFERENCES dbo.[users](user_id),
    CONSTRAINT FK_sales_customers FOREIGN KEY (customer_id) REFERENCES dbo.[users](user_id),
    CONSTRAINT CK_sales_channel CHECK (
      (sales_channel='ONLINE' AND customer_id IS NOT NULL) OR
      (sales_channel='COUNTER' AND cashier_id IS NOT NULL AND customer_id IS NULL)),
    CONSTRAINT CK_sales_payment_choice CHECK (
      (sales_channel='ONLINE' AND payment_choice IN ('ONLINE_GATEWAY','COUNTER_CASH','COUNTER_TRANSFER')) OR
      (sales_channel='COUNTER' AND payment_choice IN ('COUNTER_CASH','COUNTER_TRANSFER'))),
    CONSTRAINT CK_sales_pickup CHECK (
      (sales_channel='ONLINE' AND payment_choice IN ('COUNTER_CASH','COUNTER_TRANSFER') AND pickup_code_hash IS NOT NULL)
      OR (NOT (sales_channel='ONLINE' AND payment_choice IN ('COUNTER_CASH','COUNTER_TRANSFER')) AND pickup_code_hash IS NULL)),
    CONSTRAINT CK_sales_status CHECK ([status] IN ('PENDING','PAID','CANCELLED','EXPIRED','REVIEW_REQUIRED')),
    CONSTRAINT CK_sales_completed CHECK (([status] = 'PAID' AND completed_at IS NOT NULL) OR ([status] <> 'PAID' AND completed_at IS NULL))
);
GO
CREATE INDEX IX_sales_showtime ON dbo.sales(showtime_id);
CREATE INDEX IX_sales_hold_expiry ON dbo.sales([status], hold_expires_at)
    WHERE hold_expires_at IS NOT NULL;
GO
-- FK tham chiếu ngược: showtime_seats tạo trước sales nên khai báo sau.
ALTER TABLE dbo.showtime_seats ADD CONSTRAINT FK_showtime_seats_hold_sales
    FOREIGN KEY (held_sale_id) REFERENCES dbo.sales(sale_id);
GO

-- 13. Xác nhận thanh toán tại quầy; V5: bản ghi thanh toán cuối cùng là duy nhất theo hóa đơn.
-- Thất bại/nhập lại: có thể cập nhật bản ghi này, KHÔNG lưu lịch sử nhiều lần thử.
-- Lịch sử thử thanh toán đã lưu riêng trong payment_attempts.
-- Lịch sử lựa chọn ghế theo đơn. Có thể tồn tại nhiều đơn hết hạn cùng ghế, nhưng chỉ một ticket hợp lệ.
CREATE TABLE dbo.booking_seats (
    booking_seat_id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_booking_seats PRIMARY KEY,
    sale_id BIGINT NOT NULL,
    showtime_seat_id BIGINT NOT NULL,
    showtime_id BIGINT NOT NULL,
    quoted_price DECIMAL(12,2) NOT NULL,
    CONSTRAINT FK_booking_seats_sales FOREIGN KEY (sale_id) REFERENCES dbo.sales(sale_id),
    CONSTRAINT FK_booking_seats_showtime_seats FOREIGN KEY (showtime_seat_id) REFERENCES dbo.showtime_seats(showtime_seat_id),
    CONSTRAINT FK_booking_seats_sale_showtime FOREIGN KEY(sale_id,showtime_id)
      REFERENCES dbo.sales(sale_id,showtime_id),
    CONSTRAINT FK_booking_seats_seat_showtime FOREIGN KEY(showtime_seat_id,showtime_id)
      REFERENCES dbo.showtime_seats(showtime_seat_id,showtime_id),
    CONSTRAINT UQ_booking_seats_sale_seat UNIQUE(sale_id,showtime_seat_id),
    CONSTRAINT UQ_booking_seats_ticket_triplet UNIQUE(booking_seat_id,sale_id,showtime_seat_id),
    CONSTRAINT CK_booking_seats_price CHECK (quoted_price >= 0)
);
GO
CREATE TABLE dbo.payments (
    payment_id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_payments PRIMARY KEY,
    sale_id BIGINT NOT NULL CONSTRAINT UQ_payments_sale UNIQUE,
    amount DECIMAL(12,2) NOT NULL,
    method VARCHAR(20) NOT NULL,
    [status] VARCHAR(20) NOT NULL,
    confirmed_by INT NULL,
    confirmed_at DATETIME2(0) NULL,
    gateway_attempt_id BIGINT NULL,
    CONSTRAINT FK_payments_sales FOREIGN KEY (sale_id) REFERENCES dbo.sales(sale_id),
    CONSTRAINT FK_payments_users FOREIGN KEY (confirmed_by) REFERENCES dbo.[users](user_id),
    CONSTRAINT CK_payments_amount CHECK (amount > 0),
    CONSTRAINT CK_payments_method CHECK (method IN ('CASH','BANK_TRANSFER','ONLINE_GATEWAY')),
    CONSTRAINT CK_payments_status CHECK ([status] IN ('PENDING','PAID','FAILED')),
    CONSTRAINT CK_payments_gateway CHECK (
       (method='ONLINE_GATEWAY' AND gateway_attempt_id IS NOT NULL AND confirmed_by IS NULL)
       OR (method<>'ONLINE_GATEWAY' AND gateway_attempt_id IS NULL AND confirmed_by IS NOT NULL)),
    CONSTRAINT CK_payments_confirm CHECK (
        ([status] = 'PAID' AND confirmed_at IS NOT NULL AND (method='ONLINE_GATEWAY' OR confirmed_by IS NOT NULL))
        OR ([status] <> 'PAID' AND confirmed_at IS NULL)
    )
);
GO
CREATE INDEX IX_payments_status_confirmed ON dbo.payments([status], confirmed_at);
GO

-- 14. Vé: ghi nhận một lần soát vé tại chính bản ghi vé (không cần bảng checkins).
-- Lượt thử thanh toán qua cổng (không đồng nhất với thanh toán cuối cùng của hóa đơn).
CREATE TABLE dbo.payment_attempts (
    attempt_id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_payment_attempts PRIMARY KEY,
    sale_id BIGINT NOT NULL,
    attempt_code VARCHAR(80) NOT NULL CONSTRAINT UQ_attempts_code UNIQUE,
    provider VARCHAR(30) NOT NULL CONSTRAINT DF_attempts_provider DEFAULT ('MOCK_GATEWAY'),
    expected_amount DECIMAL(12,2) NOT NULL,
    [status] VARCHAR(20) NOT NULL CONSTRAINT DF_attempts_status DEFAULT ('CREATED'),
    created_at DATETIME2(3) NOT NULL CONSTRAINT DF_attempts_created DEFAULT SYSUTCDATETIME(),
    completed_at DATETIME2(3) NULL,
    CONSTRAINT FK_attempts_sales FOREIGN KEY (sale_id) REFERENCES dbo.sales(sale_id),
    CONSTRAINT CK_attempts_amount CHECK (expected_amount > 0),
    CONSTRAINT CK_attempts_status CHECK ([status] IN ('CREATED','FAILED','SUCCESS','REVIEW_REQUIRED')),
    CONSTRAINT CK_attempts_provider CHECK (provider='MOCK_GATEWAY')
);
GO
CREATE UNIQUE INDEX UX_attempts_one_created ON dbo.payment_attempts(sale_id) WHERE [status]='CREATED';
GO
ALTER TABLE dbo.payments ADD CONSTRAINT FK_payments_gateway_attempt FOREIGN KEY (gateway_attempt_id) REFERENCES dbo.payment_attempts(attempt_id);
CREATE UNIQUE INDEX UX_payments_gateway_attempt ON dbo.payments(gateway_attempt_id) WHERE gateway_attempt_id IS NOT NULL;
GO
CREATE TABLE dbo.payment_events (
    event_id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_payment_events PRIMARY KEY,
    attempt_id BIGINT NOT NULL,
    provider VARCHAR(30) NOT NULL,
    provider_event_id VARCHAR(120) NOT NULL,
    event_result VARCHAR(12) NOT NULL,
    paid_amount DECIMAL(12,2) NOT NULL,
    processing_result VARCHAR(25) NOT NULL,
    received_at DATETIME2(3) NOT NULL CONSTRAINT DF_events_received DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_events_attempts FOREIGN KEY (attempt_id) REFERENCES dbo.payment_attempts(attempt_id),
    CONSTRAINT UQ_events_provider_id UNIQUE (provider,provider_event_id),
    CONSTRAINT CK_events_result CHECK (event_result IN ('SUCCESS','FAILED')),
    CONSTRAINT CK_events_processing CHECK (processing_result IN ('PROCESSED','DUPLICATE','ALREADY_PAID','REVIEW_REQUIRED')),
    CONSTRAINT CK_events_paid CHECK (paid_amount >= 0)
);
GO
CREATE TABLE dbo.tickets (
    ticket_id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_tickets PRIMARY KEY,
    sale_id BIGINT NOT NULL,
    showtime_seat_id BIGINT NOT NULL CONSTRAINT UQ_tickets_showtime_seat UNIQUE,
    booking_seat_id BIGINT NOT NULL CONSTRAINT UQ_tickets_booking_seat UNIQUE,
    ticket_code VARCHAR(60) NOT NULL CONSTRAINT UQ_tickets_code UNIQUE,
    unit_price DECIMAL(12,2) NOT NULL,
    issued_at DATETIME2(0) NOT NULL CONSTRAINT DF_tickets_issued DEFAULT SYSUTCDATETIME(),
    checked_at DATETIME2(0) NULL,
    checked_by INT NULL,
    CONSTRAINT FK_tickets_sales FOREIGN KEY (sale_id) REFERENCES dbo.sales(sale_id),
    CONSTRAINT FK_tickets_showtime_seats FOREIGN KEY (showtime_seat_id) REFERENCES dbo.showtime_seats(showtime_seat_id),
    CONSTRAINT FK_tickets_booking_seats FOREIGN KEY (booking_seat_id) REFERENCES dbo.booking_seats(booking_seat_id),
    CONSTRAINT FK_tickets_booking_seats_consistent FOREIGN KEY(booking_seat_id,sale_id,showtime_seat_id)
      REFERENCES dbo.booking_seats(booking_seat_id,sale_id,showtime_seat_id),
    CONSTRAINT FK_tickets_ushers FOREIGN KEY (checked_by) REFERENCES dbo.[users](user_id),
    CONSTRAINT CK_tickets_price CHECK (unit_price >= 0),
    CONSTRAINT CK_tickets_checkin_pair CHECK (
        (checked_at IS NULL AND checked_by IS NULL)
        OR (checked_at IS NOT NULL AND checked_by IS NOT NULL)
    )
);
GO
CREATE INDEX IX_tickets_sale ON dbo.tickets(sale_id);
GO

-- Dữ liệu cấu hình mẫu (không có tài khoản hay mật khẩu thật).
INSERT INTO dbo.roles(role_code,role_name)
SELECT v.role_code,v.role_name
FROM (VALUES ('ADMIN',N'Quản trị viên'),
             ('MANAGER',N'Quản lý rạp'),
             ('CASHIER',N'Nhân viên bán vé'),
             ('USHER',N'Nhân viên soát vé'),
             ('CUSTOMER',N'Khách hàng đặt vé trực tuyến')) AS v(role_code,role_name)
WHERE NOT EXISTS (SELECT 1 FROM dbo.roles r WHERE r.role_code=v.role_code);
GO


/* --------------------------------------------------------------------------
NGUYÊN TẮC GIỮ GHẾ V5
- AVAILABLE: không có ticket và (held_sale_id NULL hoặc sale giữ đã hết hạn/không PENDING).
- HELD: chưa có ticket, sale giữ ở PENDING và sales.hold_expires_at > UTC.
- SOLD: tồn tại tickets theo showtime_seat_id.
- can_sell là thuộc tính RIÊNG: còn hoạt động, chưa bắt đầu suất, phòng mở.
- Toàn bộ ghế cùng hóa đơn dùng sales.hold_expires_at, không lặp hạn trên từng ghế.
- Chỉ cho Backend thực thi stored procedure; cấm quyền DML trực tiếp cho role ứng dụng.
- Chuyển khoản muộn cần đối soát ngoại hệ thống, tuyệt đối không tự phát hành vé.
*/
GO

CREATE OR ALTER VIEW dbo.vw_showtime_seat_availability AS
SELECT ss.showtime_seat_id, ss.showtime_id, ss.seat_id,
       ss.held_sale_id, ss.held_unit_price, s.hold_expires_at,
       CAST(CASE WHEN t.ticket_id IS NOT NULL THEN 'SOLD'
                 WHEN s.[status]='PENDING' AND s.hold_expires_at > SYSUTCDATETIME() THEN 'HELD'
                 ELSE 'AVAILABLE' END AS VARCHAR(12)) AS seat_status,
       CAST(CASE WHEN t.ticket_id IS NULL
                  AND (s.sale_id IS NULL OR s.[status]<>'PENDING' OR s.hold_expires_at<=SYSUTCDATETIME())
                  AND st.[status]='PUBLISHED'
                  AND st.starts_at > TODATETIMEOFFSET(SYSUTCDATETIME(),'+00:00')
                  AND r.[status]='ACTIVE' AND se.room_id=st.room_id
                  AND se.is_active=1 AND ty.is_active=1
                  AND m.[status]='PUBLISHED' THEN 1 ELSE 0 END AS BIT) AS can_sell
FROM dbo.showtime_seats ss
JOIN dbo.showtimes st ON st.showtime_id=ss.showtime_id
JOIN dbo.rooms r ON r.room_id=st.room_id
JOIN dbo.movies m ON m.movie_id=st.movie_id
JOIN dbo.seats se ON se.seat_id=ss.seat_id
JOIN dbo.seat_types ty ON ty.seat_type_id=se.seat_type_id
LEFT JOIN dbo.sales s ON s.sale_id=ss.held_sale_id
LEFT JOIN dbo.tickets t ON t.showtime_seat_id=ss.showtime_seat_id;
GO


-- Thủ tục: Tạo hóa đơn an toàn cho hai kênh
CREATE OR ALTER PROCEDURE dbo.usp_create_sale
  @showtime_id BIGINT,@requested_by INT,@sales_channel VARCHAR(10),
  @payment_choice VARCHAR(20),@receipt_code VARCHAR(40)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @sales_channel IS NULL OR @sales_channel NOT IN ('ONLINE','COUNTER')
    THROW 52701,N'Kênh bán không hợp lệ.',1;
 IF @payment_choice IS NULL OR
    NOT ((@sales_channel='ONLINE' AND @payment_choice IN ('ONLINE_GATEWAY','COUNTER_CASH','COUNTER_TRANSFER'))
     OR (@sales_channel='COUNTER' AND @payment_choice IN ('COUNTER_CASH','COUNTER_TRANSFER')))
    THROW 52702,N'Kênh và phương thức thanh toán không phù hợp.',1;
 IF @receipt_code IS NULL OR LEN(@receipt_code)<6 OR LEN(@receipt_code)>40
    THROW 52703,N'Mã hóa đơn không hợp lệ.',1;
 DECLARE @now DATETIMEOFFSET(0)=TODATETIMEOFFSET(SYSUTCDATETIME(),'+00:00');
 DECLARE @pickup VARCHAR(32)=NULL,@hash VARBINARY(32)=NULL,@sale_id BIGINT;
 IF @sales_channel='ONLINE' AND @payment_choice IN ('COUNTER_CASH','COUNTER_TRANSFER')
 BEGIN
    SET @pickup=CONVERT(VARCHAR(32),CRYPT_GEN_RANDOM(16),2);
    SET @hash=HASHBYTES('SHA2_256',CONVERT(VARBINARY(MAX),@pickup));
 END;
 IF NOT EXISTS (
   SELECT 1 FROM dbo.showtimes st
   JOIN dbo.rooms rm ON rm.room_id=st.room_id AND rm.[status]='ACTIVE'
   JOIN dbo.movies m ON m.movie_id=st.movie_id AND m.[status]='PUBLISHED'
   JOIN dbo.[users] u ON u.user_id=@requested_by AND u.[status]='ACTIVE'
   JOIN dbo.roles r ON r.role_id=u.role_id
   WHERE st.showtime_id=@showtime_id AND st.[status]='PUBLISHED'
     AND st.starts_at>@now
     AND ((@sales_channel='ONLINE' AND r.role_code='CUSTOMER')
       OR (@sales_channel='COUNTER' AND r.role_code='CASHIER' AND u.cinema_id=rm.cinema_id))
 ) THROW 52704,N'Không có quyền hoặc suất chưa sẵn sàng.',1;
 INSERT INTO dbo.sales(receipt_code,showtime_id,cashier_id,customer_id,
                       sales_channel,payment_choice,pickup_code_hash)
 VALUES(@receipt_code,@showtime_id,
        CASE WHEN @sales_channel='COUNTER' THEN @requested_by END,
        CASE WHEN @sales_channel='ONLINE' THEN @requested_by END,
        @sales_channel,@payment_choice,@hash);
 SET @sale_id=CONVERT(BIGINT,SCOPE_IDENTITY());
 SELECT @sale_id AS sale_id,@receipt_code AS receipt_code,@pickup AS pickup_code;
END;
GO

-- PROC 1: Giữ TẤT CẢ ghế trong giao dịch ngắn; @seat_ids là showtime_seat_id.
CREATE OR ALTER PROCEDURE dbo.usp_hold_seats
    @sale_id BIGINT, @seat_ids NVARCHAR(MAX), @requested_by INT, @hold_minutes INT=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @seat_ids IS NULL OR LTRIM(RTRIM(@seat_ids))='' THROW 52002,N'Chưa chọn ghế.',1;
 IF EXISTS(SELECT 1 FROM STRING_SPLIT(@seat_ids,',') WHERE TRY_CONVERT(BIGINT,LTRIM(RTRIM(value))) IS NULL OR TRY_CONVERT(BIGINT,LTRIM(RTRIM(value)))<=0)
   THROW 52003,N'Danh sách ghế không hợp lệ.',1;
 DECLARE @ids TABLE(id BIGINT PRIMARY KEY);
 INSERT INTO @ids SELECT DISTINCT TRY_CONVERT(BIGINT,LTRIM(RTRIM(value))) FROM STRING_SPLIT(@seat_ids,',');
 DECLARE @cnt INT=(SELECT COUNT(*) FROM @ids), @showtime BIGINT,@channel VARCHAR(10),@cashier INT,@customer INT,
         @choice VARCHAR(20),@policy INT,@now DATETIME2(3),@expires DATETIME2(3);
 IF @cnt NOT BETWEEN 1 AND 8 THROW 52004,N'Chỉ hỗ trợ giữ 1 đến 8 ghế.',1;
 BEGIN TRY
  BEGIN TRAN;
  SELECT @showtime=showtime_id,@channel=sales_channel,@choice=payment_choice,@cashier=cashier_id,@customer=customer_id
    FROM dbo.sales WITH (UPDLOCK,HOLDLOCK)
    WHERE sale_id=@sale_id AND [status]='PENDING' AND hold_expires_at IS NULL;
  IF @showtime IS NULL THROW 52005,N'Hóa đơn không hợp lệ hoặc đã giữ ghế.',1;
  SET @policy=CASE WHEN @channel='ONLINE' AND @choice IN ('COUNTER_CASH','COUNTER_TRANSFER') THEN 30 ELSE 5 END;
  IF @hold_minutes IS NOT NULL AND @hold_minutes<>@policy
    THROW 52001,N'Thời hạn giữ phải theo chính sách máy chủ.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.[users] u JOIN dbo.roles r ON r.role_id=u.role_id
                JOIN dbo.showtimes st ON st.showtime_id=@showtime JOIN dbo.rooms rm ON rm.room_id=st.room_id
                JOIN dbo.movies m ON m.movie_id=st.movie_id
                WHERE u.user_id=@requested_by AND u.[status]='ACTIVE'
                  AND ((@channel='ONLINE' AND @customer=@requested_by AND r.role_code='CUSTOMER')
                    OR (@channel='COUNTER' AND @cashier=@requested_by AND r.role_code='CASHIER' AND u.cinema_id=rm.cinema_id))
                  AND st.[status]='PUBLISHED' AND m.[status]='PUBLISHED' AND rm.[status]='ACTIVE')
    THROW 52006,N'Sai quyền, sai rạp hoặc lịch chưa công bố.',1;
  IF (SELECT COUNT(*) FROM dbo.showtime_seats WITH (UPDLOCK,HOLDLOCK) WHERE showtime_id=@showtime AND showtime_seat_id IN(SELECT id FROM @ids))<>@cnt
    THROW 52007,N'Ghế không thuộc suất chiếu.',1;
  SET @now=SYSUTCDATETIME(); SET @expires=DATEADD(MINUTE,@policy,@now);
  IF NOT EXISTS(SELECT 1 FROM dbo.showtimes WHERE showtime_id=@showtime AND starts_at>TODATETIMEOFFSET(@now,'+00:00'))
    THROW 52008,N'Suất chiếu đã bắt đầu.',1;
  UPDATE ss SET held_sale_id=@sale_id,held_unit_price=st.base_price+ty.price_surcharge
   FROM dbo.showtime_seats ss WITH (UPDLOCK,HOLDLOCK)
   JOIN @ids ids ON ids.id=ss.showtime_seat_id
   JOIN dbo.showtimes st ON st.showtime_id=ss.showtime_id
   JOIN dbo.seats se ON se.seat_id=ss.seat_id
   JOIN dbo.seat_types ty ON ty.seat_type_id=se.seat_type_id
   LEFT JOIN dbo.sales prev ON prev.sale_id=ss.held_sale_id
   WHERE ss.showtime_id=@showtime AND se.room_id=st.room_id AND se.is_active=1 AND ty.is_active=1
    AND NOT EXISTS(SELECT 1 FROM dbo.tickets t WHERE t.showtime_seat_id=ss.showtime_seat_id)
    AND (ss.held_sale_id IS NULL OR prev.[status]<>'PENDING' OR prev.hold_expires_at<=@now);
  IF @@ROWCOUNT<>@cnt THROW 52009,N'Có ghế đã bán hoặc đang giữ. Toàn bộ giao dịch bị hủy.',1;
  INSERT INTO dbo.booking_seats(sale_id,showtime_seat_id,showtime_id,quoted_price)
   SELECT @sale_id,ss.showtime_seat_id,ss.showtime_id,ss.held_unit_price FROM dbo.showtime_seats ss JOIN @ids i ON i.id=ss.showtime_seat_id;
  UPDATE dbo.sales SET hold_expires_at=@expires,held_seat_count=@cnt WHERE sale_id=@sale_id;
  COMMIT; SELECT @sale_id AS sale_id,@expires AS hold_expires_at,@cnt AS seats;
 END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH
END;
GO

-- PROC 2: Xác nhận tiền đã nhận và cấp vé, kiểm tra hết hạn SAU khi lấy khóa.
CREATE OR ALTER PROCEDURE dbo.usp_confirm_sale_and_issue_tickets
 @sale_id BIGINT,@method VARCHAR(20),@confirmed_by INT,@pickup_code VARCHAR(64)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @method NOT IN ('CASH','BANK_TRANSFER') THROW 52101,N'Chỉ xác nhận thu tiền tại quầy.',1;
 DECLARE @showtime BIGINT,@cashier INT,@channel VARCHAR(10),@choice VARCHAR(20),@pickup_hash VARBINARY(32),@expiry DATETIME2(3),@expected INT,@total DECIMAL(12,2),@now DATETIME2(3);
 DECLARE @held TABLE(booking_seat_id BIGINT,showtime_seat_id BIGINT,unit_price DECIMAL(12,2));
 BEGIN TRY
 BEGIN TRAN;
 SELECT @showtime=showtime_id,@cashier=cashier_id,@channel=sales_channel,@choice=payment_choice,@pickup_hash=pickup_code_hash,@expiry=hold_expires_at,@expected=held_seat_count
  FROM dbo.sales WITH (UPDLOCK,HOLDLOCK) WHERE sale_id=@sale_id AND [status]='PENDING';
 IF @showtime IS NULL OR @expiry IS NULL OR @expected IS NULL THROW 52102,N'Hóa đơn không PENDING hoặc chưa giữ ghế.',1;
 IF (@method='CASH' AND @choice<>'COUNTER_CASH') OR (@method='BANK_TRANSFER' AND @choice<>'COUNTER_TRANSFER')
   THROW 52103,N'Phương thức thanh toán không đúng đơn.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.[users] u JOIN dbo.roles r ON r.role_id=u.role_id
     JOIN dbo.showtimes st ON st.showtime_id=@showtime JOIN dbo.rooms rm ON rm.room_id=st.room_id
     WHERE u.user_id=@confirmed_by AND u.[status]='ACTIVE' AND r.role_code='CASHIER' AND u.cinema_id=rm.cinema_id)
    THROW 52104,N'Nhân viên không có quyền xác nhận ở rạp này.',1;
 IF @cashier IS NOT NULL AND @cashier<>@confirmed_by THROW 52105,N'Hóa đơn quầy thuộc nhân viên khác.',1;
 IF @channel='ONLINE' AND (
      @pickup_code IS NULL OR @pickup_hash IS NULL OR
      HASHBYTES('SHA2_256',CONVERT(VARBINARY(MAX),@pickup_code))<>@pickup_hash)
   THROW 52112,N'Mã nhận đơn tại quầy không hợp lệ.',1;
 INSERT INTO @held SELECT b.booking_seat_id,b.showtime_seat_id,b.quoted_price
  FROM dbo.booking_seats b JOIN dbo.showtime_seats ss WITH (UPDLOCK,HOLDLOCK)
   ON ss.showtime_seat_id=b.showtime_seat_id AND ss.held_sale_id=@sale_id
  WHERE b.sale_id=@sale_id AND ss.showtime_id=@showtime;
 IF EXISTS (SELECT 1 FROM @held h JOIN dbo.showtime_seats ss ON ss.showtime_seat_id=h.showtime_seat_id
             WHERE ss.held_unit_price<>h.unit_price) THROW 52113,N'Giá giữ ghế không khớp.',1;
 SELECT @total=SUM(unit_price) FROM @held;
 IF (SELECT COUNT(*) FROM @held)<>@expected OR @expected<1 THROW 52106,N'Ghế giữ không khớp.',1;
 SET @now=SYSUTCDATETIME();
 IF @expiry<=@now THROW 52107,N'Giữ ghế đã hết hạn. Thu tiền cần đối soát.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.showtimes WHERE showtime_id=@showtime AND [status]='PUBLISHED' AND starts_at>TODATETIMEOFFSET(@now,'+00:00'))
  THROW 52108,N'Suất chiếu không còn bán.',1;
 IF EXISTS(SELECT 1 FROM dbo.payments WHERE sale_id=@sale_id) THROW 52109,N'Đơn đã có xác nhận thanh toán cuối.',1;
 INSERT INTO dbo.payments(sale_id,amount,method,[status],confirmed_by,confirmed_at)
 VALUES(@sale_id,@total,@method,'PAID',@confirmed_by,@now);
 INSERT INTO dbo.tickets(sale_id,showtime_seat_id,booking_seat_id,ticket_code,unit_price,issued_at)
 SELECT @sale_id,h.showtime_seat_id,h.booking_seat_id,CONVERT(VARCHAR(36),NEWID()),h.unit_price,@now FROM @held h;
 IF @@ROWCOUNT<>@expected THROW 52110,N'Phát hành thiếu vé.',1;
 UPDATE dbo.sales SET [status]='PAID',completed_at=@now,cashier_id=COALESCE(cashier_id,@confirmed_by) WHERE sale_id=@sale_id;
 UPDATE dbo.showtime_seats SET held_sale_id=NULL,held_unit_price=NULL WHERE held_sale_id=@sale_id;
 IF @expiry<=SYSUTCDATETIME() THROW 52111,N'Hết hạn trong lúc xác nhận, đã rollback.',1;
 COMMIT; SELECT @sale_id AS sale_id,@total AS paid_amount,@expected AS ticket_count;
 END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH
END;
GO

-- PROC 3: Dọn tất cả sales hết hạn dựa vào sales, KHÔNG dựa vào ghế còn liên kết.
CREATE OR ALTER PROCEDURE dbo.usp_expire_seat_holds
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.sales SET [status]='EXPIRED',completed_at=NULL
        WHERE [status]='PENDING' AND hold_expires_at IS NOT NULL
          AND hold_expires_at<=SYSUTCDATETIME();
        UPDATE ss SET held_sale_id=NULL,held_unit_price=NULL
        FROM dbo.showtime_seats ss
        JOIN dbo.sales s ON s.sale_id=ss.held_sale_id
        WHERE s.[status]<>'PENDING' OR s.hold_expires_at<=SYSUTCDATETIME();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- PROC 4: Hủy hóa đơn và giải phóng ghế; kiểm tra cùng cashier, đúng rạp.
CREATE OR ALTER PROCEDURE dbo.usp_cancel_pending_sale
 @sale_id BIGINT,@cancelled_by INT
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY BEGIN TRAN;
 IF NOT EXISTS(SELECT 1 FROM dbo.sales s WITH (UPDLOCK,HOLDLOCK)
   JOIN dbo.[users] u ON u.user_id=@cancelled_by AND u.[status]='ACTIVE'
   JOIN dbo.roles ro ON ro.role_id=u.role_id
   JOIN dbo.showtimes st ON st.showtime_id=s.showtime_id JOIN dbo.rooms rm ON rm.room_id=st.room_id
   WHERE s.sale_id=@sale_id AND s.[status]='PENDING'
    AND ((s.sales_channel='ONLINE' AND s.customer_id=@cancelled_by AND ro.role_code='CUSTOMER')
       OR (s.sales_channel='COUNTER' AND s.cashier_id=@cancelled_by AND ro.role_code='CASHIER' AND u.cinema_id=rm.cinema_id)))
  THROW 52201,N'Không có quyền hủy đơn hoặc đơn đã hoàn tất.',1;
 UPDATE dbo.sales SET [status]='CANCELLED' WHERE sale_id=@sale_id;
 UPDATE dbo.showtime_seats SET held_sale_id=NULL,held_unit_price=NULL WHERE held_sale_id=@sale_id;
 COMMIT;
 END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH
END;
GO

-- PROC 5: Soát vé nguyên tử, 1 vé đúng 1 lần, kiểm tra role và rạp.
CREATE OR ALTER PROCEDURE dbo.usp_checkin_ticket
    @ticket_code VARCHAR(60),@usher_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @ticket_id BIGINT;
    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT @ticket_id=t.ticket_id
        FROM dbo.tickets t WITH (UPDLOCK,HOLDLOCK)
        JOIN dbo.sales s ON s.sale_id=t.sale_id AND s.[status]='PAID'
        JOIN dbo.payments pay ON pay.sale_id=s.sale_id AND pay.[status]='PAID'
        JOIN dbo.showtimes st ON st.showtime_id=s.showtime_id
        JOIN dbo.rooms rm ON rm.room_id=st.room_id
        JOIN dbo.showtime_seats ss ON ss.showtime_seat_id=t.showtime_seat_id
                                  AND ss.showtime_id=st.showtime_id
        JOIN dbo.[users] u ON u.user_id=@usher_id
        JOIN dbo.roles ro ON ro.role_id=u.role_id
        WHERE t.ticket_code=@ticket_code AND t.checked_at IS NULL
          AND u.[status]='ACTIVE' AND ro.role_code='USHER' AND u.cinema_id=rm.cinema_id
          -- Cửa sổ soát vé demo đề xuất, chưa có xác nhận nghiệp vụ của giảng viên:
          AND TODATETIMEOFFSET(SYSUTCDATETIME(),'+00:00') BETWEEN
              DATEADD(MINUTE,-30,st.starts_at) AND DATEADD(MINUTE,30,st.ends_at);
        IF @ticket_id IS NULL
            THROW 51301, N'Vé sai mã, đã dùng, sai rạp, hoặc ngoài thời gian hợp lệ.', 1;
        UPDATE dbo.tickets SET checked_at=SYSUTCDATETIME(),checked_by=@usher_id
        WHERE ticket_id=@ticket_id AND checked_at IS NULL;
        IF @@ROWCOUNT<>1 THROW 51302, N'Vé đã được quét.', 1;
        COMMIT TRANSACTION;
        SELECT @ticket_id AS ticket_id;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- PROC 6: Công bố suất chiếu, chặn trùng phòng. Cần gọi qua API, không trực tiếp DML.
CREATE OR ALTER PROCEDURE dbo.usp_publish_showtime
    @showtime_id BIGINT,@manager_id INT,@clean_minutes INT = 15
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @clean_minutes IS NULL OR @clean_minutes<>15
        THROW 51401, N'MVP áp dụng đúng 15 phút dọn phòng.', 1;
    DECLARE @room_id INT,@cinema_id INT,@starts DATETIMEOFFSET(0),@ends DATETIMEOFFSET(0);
    DECLARE @resource NVARCHAR(255),@lock_result INT;
    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT @room_id=st.room_id,@cinema_id=rm.cinema_id,
               @starts=st.starts_at,@ends=st.ends_at
        FROM dbo.showtimes st WITH (UPDLOCK,HOLDLOCK)
        JOIN dbo.rooms rm ON rm.room_id=st.room_id AND rm.[status]='ACTIVE'
        JOIN dbo.movies m ON m.movie_id=st.movie_id AND m.[status]='PUBLISHED'
        JOIN dbo.[users] u ON u.user_id=@manager_id AND u.cinema_id=rm.cinema_id
        JOIN dbo.roles ro ON ro.role_id=u.role_id AND ro.role_code='MANAGER'
        WHERE st.showtime_id=@showtime_id AND st.[status]='DRAFT' AND u.[status]='ACTIVE';
        IF @room_id IS NULL
            THROW 51402, N'Suất, phòng, phim hoặc quyền quản lý không hợp lệ.', 1;
        IF @starts<=TODATETIMEOFFSET(SYSUTCDATETIME(),'+00:00') OR @ends<=@starts
            THROW 51403, N'Thời gian chiếu không hợp lệ.', 1;
        SET @resource=CONCAT(N'CinemaRoom-',@room_id);
        EXEC @lock_result=sys.sp_getapplock @Resource=@resource,@LockMode='Exclusive',
              @LockOwner='Transaction',@LockTimeout=10000;
        IF @lock_result<0 THROW 51404, N'Không lấy được khóa phòng chiếu.', 1;
        IF EXISTS (
            SELECT 1 FROM dbo.showtimes other WITH (UPDLOCK,HOLDLOCK)
            WHERE other.room_id=@room_id AND other.showtime_id<>@showtime_id
              AND other.[status] IN ('PUBLISHED','FINISHED')
              AND other.starts_at<DATEADD(MINUTE,@clean_minutes,@ends)
              AND other.ends_at>DATEADD(MINUTE,-@clean_minutes,@starts))
            THROW 51405, N'Lịch chiếu trùng phòng hoặc thời gian dọn phòng.', 1;
        INSERT INTO dbo.showtime_seats(showtime_id,seat_id)
        SELECT @showtime_id,se.seat_id FROM dbo.seats se
        JOIN dbo.seat_types ty ON ty.seat_type_id=se.seat_type_id
        WHERE se.room_id=@room_id AND se.is_active=1 AND ty.is_active=1;
        IF @@ROWCOUNT=0 THROW 51406, N'Phòng không có ghế hoạt động.', 1;
        UPDATE dbo.showtimes SET [status]='PUBLISHED' WHERE showtime_id=@showtime_id;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* CÁCH SỬ DỤNG: Tạo sales PENDING, gọi usp_hold_seats; sau khi kiểm tiền gọi
   usp_confirm_sale_and_issue_tickets; gọi usp_expire_seat_holds định kỳ. Gọi
   usp_checkin_ticket khi quét; usp_publish_showtime để công bố lịch.
   Không mở SQL transaction xuyên suốt thời gian khách chuyển khoản.
   Không cấp quyền INSERT/UPDATE/DELETE trực tiếp vào các bảng nghiệp vụ cho
   tài khoản DB của ứng dụng khi triển khai thực tế. Mã đây là bản tạo mới DB,
   không phải script migration từ V3 hoặc từ GitHub. Chưa được kiểm thử SQL Server V5 trong phiên xây dựng này. */

-- API phải dùng usp_create_sale để tạo đơn rồi mới gọi usp_hold_seats.
-- Lệnh gọi phía trình duyệt chỉ gửi lựa chọn, không tự định giá hoặc đổi trạng thái PAID.
-- Thủ tục: Tạo lượt thanh toán online đã kiểm tra ghế
CREATE OR ALTER PROCEDURE dbo.usp_create_gateway_attempt
 @sale_id BIGINT,@requested_by INT,@attempt_code VARCHAR(80)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @attempt_code IS NULL OR LEN(@attempt_code)<8
   THROW 52500,N'Mã lượt thanh toán không hợp lệ.',1;
 DECLARE @customer INT,@showtime BIGINT,@expires DATETIME2(3),@expected INT,
         @count INT,@owned INT,@amount DECIMAL(12,2),@now DATETIME2(3);
 BEGIN TRY
  BEGIN TRAN;
  SELECT @customer=customer_id,@showtime=showtime_id,
         @expires=hold_expires_at,@expected=held_seat_count
    FROM dbo.sales WITH(UPDLOCK,HOLDLOCK)
   WHERE sale_id=@sale_id AND [status]='PENDING'
     AND sales_channel='ONLINE' AND payment_choice='ONLINE_GATEWAY';
  IF @customer IS NULL OR @customer<>@requested_by
     THROW 52501,N'Không thể mở lượt thanh toán cho hóa đơn này.',1;
  IF NOT EXISTS (SELECT 1 FROM dbo.[users] u
     JOIN dbo.roles r ON r.role_id=u.role_id
     WHERE u.user_id=@requested_by AND u.[status]='ACTIVE' AND r.role_code='CUSTOMER')
     THROW 52502,N'Khách hàng không hợp lệ.',1;
  SELECT @owned=COUNT(*) FROM dbo.showtime_seats ss WITH(UPDLOCK,HOLDLOCK)
   WHERE ss.held_sale_id=@sale_id;
  SELECT @count=COUNT(*),@amount=SUM(b.quoted_price)
    FROM dbo.booking_seats b
    JOIN dbo.showtime_seats ss WITH(UPDLOCK,HOLDLOCK)
      ON ss.showtime_seat_id=b.showtime_seat_id AND ss.showtime_id=@showtime
       AND ss.held_sale_id=@sale_id AND ss.held_unit_price=b.quoted_price
   WHERE b.sale_id=@sale_id AND b.showtime_id=@showtime
     AND NOT EXISTS(SELECT 1 FROM dbo.tickets t WHERE t.showtime_seat_id=ss.showtime_seat_id);
  SET @now=SYSUTCDATETIME();
  IF @expires IS NULL OR @expires<=@now OR @expected IS NULL OR @expected=0
     OR @count<>@expected OR @owned<>@expected OR @amount IS NULL OR @amount<=0
     THROW 52503,N'Ghế không còn thuộc đơn, sai giá hoặc quá hạn.',1;
  IF NOT EXISTS (SELECT 1 FROM dbo.showtimes
      WHERE showtime_id=@showtime AND [status]='PUBLISHED'
      AND starts_at>TODATETIMEOFFSET(@now,'+00:00'))
     THROW 52504,N'Suất chiếu không còn bán.',1;
  IF EXISTS(SELECT 1 FROM dbo.payment_attempts WITH(UPDLOCK,HOLDLOCK)
      WHERE sale_id=@sale_id AND [status]='CREATED')
     THROW 52505,N'Đã có lượt thanh toán đang chờ, không tạo trùng.',1;
  INSERT INTO dbo.payment_attempts(sale_id,attempt_code,expected_amount)
      VALUES(@sale_id,@attempt_code,@amount);
  COMMIT;
  SELECT @attempt_code AS attempt_code,@amount AS expected_amount;
 END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH
END;
GO
-- BẮT BUỘC: API đã kiểm tra chữ ký + truy vấn đối soát cổng trước khi gọi.
-- Không công khai procedure này cho tài khoản/thiết bị khách hàng.
-- Thủ tục: Xử lý callback đã được backend xác minh (MOCK)
CREATE OR ALTER PROCEDURE dbo.usp_accept_verified_gateway_event
 @provider_event_id VARCHAR(120),@attempt_code VARCHAR(80),
 @event_result VARCHAR(12),@paid_amount DECIMAL(12,2),@server_verified BIT
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @server_verified IS NULL OR @server_verified<>1
    THROW 52601,N'Callback chưa được backend xác minh.',1;
 IF @provider_event_id IS NULL OR LEN(@provider_event_id)=0 OR
    @event_result IS NULL OR @event_result NOT IN ('SUCCESS','FAILED') OR
    @paid_amount IS NULL OR @paid_amount<0
    THROW 52602,N'Sự kiện thanh toán không hợp lệ.',1;
 DECLARE @sale_id BIGINT,@attempt_id BIGINT,@attempt_state VARCHAR(20),
         @expected_amount DECIMAL(12,2),@order_status VARCHAR(20),
         @choice VARCHAR(20),@expiry DATETIME2(3),@seats INT,
         @count INT,@owned INT,@total DECIMAL(12,2),@now DATETIME2(3),
         @app_lock INT,@result VARCHAR(25),@paid_attempt BIGINT,@lockresource NVARCHAR(255);
 BEGIN TRY
  BEGIN TRAN;
  SET @lockresource=CONCAT(N'GW-EVENT-',@provider_event_id);
  EXEC @app_lock=sys.sp_getapplock
    @Resource=@lockresource,
    @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @app_lock<0 THROW 52609,N'Không lấy được khóa sự kiện.',1;
  IF EXISTS (SELECT 1 FROM dbo.payment_events WITH(UPDLOCK,HOLDLOCK)
       WHERE provider='MOCK_GATEWAY' AND provider_event_id=@provider_event_id)
  BEGIN COMMIT; SELECT 'DUPLICATE' AS processing_result; RETURN; END;
  -- Tra sale trước; sau đó KHÓA SALE rồi ATTEMPT để giữ một thứ tự khóa.
  SELECT @sale_id=sale_id FROM dbo.payment_attempts WHERE attempt_code=@attempt_code
      AND provider='MOCK_GATEWAY';
  IF @sale_id IS NULL THROW 52603,N'Không tìm thấy lượt thanh toán.',1;
  SELECT @order_status=[status],@expiry=hold_expires_at,@seats=held_seat_count,
         @choice=payment_choice
    FROM dbo.sales WITH(UPDLOCK,HOLDLOCK) WHERE sale_id=@sale_id;
  SELECT @attempt_id=attempt_id,@expected_amount=expected_amount,@attempt_state=[status]
    FROM dbo.payment_attempts WITH(UPDLOCK,HOLDLOCK)
   WHERE sale_id=@sale_id AND attempt_code=@attempt_code AND provider='MOCK_GATEWAY';
  IF @attempt_id IS NULL THROW 52603,N'Lượt thanh toán đã thay đổi.',1;
  SET @now=SYSUTCDATETIME();
  SET @result='REVIEW_REQUIRED';
  -- Sau khi đã PAID: không bao giờ sửa trạng thái SUCCESS đã chốt.
  IF @order_status='PAID'
  BEGIN
    SELECT @paid_attempt=gateway_attempt_id FROM dbo.payments WHERE sale_id=@sale_id AND [status]='PAID';
    IF @paid_attempt=@attempt_id AND @attempt_state='SUCCESS' AND @event_result='SUCCESS' AND @paid_amount=@expected_amount
        SET @result='ALREADY_PAID';
    ELSE IF @paid_attempt=@attempt_id AND @attempt_state='SUCCESS' AND @event_result='FAILED'
        SET @result='REVIEW_REQUIRED';
    ELSE
    BEGIN
       IF @attempt_state='CREATED'
         UPDATE dbo.payment_attempts SET [status]='REVIEW_REQUIRED',completed_at=@now WHERE attempt_id=@attempt_id;
    END;
  END
  ELSE IF @event_result='FAILED'
  BEGIN
    IF @attempt_state='CREATED'
    BEGIN
      UPDATE dbo.payment_attempts SET [status]='FAILED',completed_at=@now WHERE attempt_id=@attempt_id;
      SET @result='PROCESSED';
    END
  END
  ELSE IF @attempt_state='CREATED' AND @order_status='PENDING' AND @choice='ONLINE_GATEWAY'
  BEGIN
    SELECT @owned=COUNT(*) FROM dbo.showtime_seats ss WITH(UPDLOCK,HOLDLOCK)
     WHERE ss.held_sale_id=@sale_id;
    SELECT @count=COUNT(*),@total=SUM(b.quoted_price)
      FROM dbo.booking_seats b
      JOIN dbo.showtime_seats ss WITH(UPDLOCK,HOLDLOCK)
       ON ss.showtime_seat_id=b.showtime_seat_id AND ss.held_sale_id=@sale_id
          AND ss.held_unit_price=b.quoted_price AND ss.showtime_id=b.showtime_id
     WHERE b.sale_id=@sale_id
       AND NOT EXISTS(SELECT 1 FROM dbo.tickets t WHERE t.showtime_seat_id=ss.showtime_seat_id);
    SET @now=SYSUTCDATETIME();
    IF @expiry IS NOT NULL AND @expiry>@now AND @seats IS NOT NULL AND @seats>0
      AND @owned=@seats AND @count=@seats AND @total=@paid_amount AND @expected_amount=@paid_amount
      AND NOT EXISTS(SELECT 1 FROM dbo.payments WHERE sale_id=@sale_id)
      AND EXISTS(SELECT 1 FROM dbo.sales s JOIN dbo.showtimes st ON st.showtime_id=s.showtime_id
        WHERE s.sale_id=@sale_id AND st.[status]='PUBLISHED'
           AND st.starts_at>TODATETIMEOFFSET(@now,'+00:00'))
    BEGIN
      INSERT INTO dbo.payments(sale_id,amount,method,[status],gateway_attempt_id,confirmed_at)
       VALUES(@sale_id,@total,'ONLINE_GATEWAY','PAID',@attempt_id,@now);
      INSERT INTO dbo.tickets(sale_id,showtime_seat_id,booking_seat_id,ticket_code,unit_price,issued_at)
       SELECT @sale_id,b.showtime_seat_id,b.booking_seat_id,
              CONVERT(VARCHAR(36),NEWID()),b.quoted_price,@now
        FROM dbo.booking_seats b WHERE b.sale_id=@sale_id;
      IF @@ROWCOUNT<>@seats THROW 52605,N'Không phát hành đủ vé.',1;
      UPDATE dbo.sales SET [status]='PAID',completed_at=@now WHERE sale_id=@sale_id;
      UPDATE dbo.showtime_seats SET held_sale_id=NULL,held_unit_price=NULL WHERE held_sale_id=@sale_id;
      UPDATE dbo.payment_attempts SET [status]='SUCCESS',completed_at=@now WHERE attempt_id=@attempt_id;
      -- Kiểm tra lại sát COMMIT; nếu quá hạn thì rollback và không nhận là đã cấp vé.
      IF @expiry<=SYSUTCDATETIME()
      BEGIN
        DELETE FROM dbo.tickets WHERE sale_id=@sale_id;
        DELETE FROM dbo.payments WHERE sale_id=@sale_id;
        UPDATE dbo.sales SET [status]='REVIEW_REQUIRED',completed_at=NULL WHERE sale_id=@sale_id;
        UPDATE dbo.payment_attempts SET [status]='REVIEW_REQUIRED',completed_at=SYSUTCDATETIME() WHERE attempt_id=@attempt_id;
        SET @result='REVIEW_REQUIRED';
      END
      ELSE SET @result='PROCESSED';
    END
  END;
  IF @result='REVIEW_REQUIRED'
  BEGIN
    IF @event_result='SUCCESS' AND @order_status='PENDING'
    BEGIN
      UPDATE dbo.sales SET [status]='REVIEW_REQUIRED' WHERE sale_id=@sale_id;
      UPDATE dbo.showtime_seats SET held_sale_id=NULL,held_unit_price=NULL WHERE held_sale_id=@sale_id;
    END;
    IF @attempt_state='CREATED' OR (@attempt_state='FAILED' AND @event_result='SUCCESS')
      UPDATE dbo.payment_attempts SET [status]='REVIEW_REQUIRED',completed_at=@now WHERE attempt_id=@attempt_id;
  END;
  INSERT INTO dbo.payment_events(attempt_id,provider,provider_event_id,event_result,paid_amount,processing_result)
    VALUES(@attempt_id,'MOCK_GATEWAY',@provider_event_id,@event_result,@paid_amount,@result);
  COMMIT;
  SELECT @result AS processing_result;
 END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH
END;
GO


-- View: Doanh thu đã xác nhận theo ngày UTC và rạp
CREATE OR ALTER VIEW dbo.vw_paid_revenue_daily AS
SELECT rm.cinema_id, CAST(p.confirmed_at AS DATE) AS confirmed_date_utc,
       p.method, COUNT_BIG(*) AS paid_orders, SUM(p.amount) AS paid_amount
FROM dbo.payments p
JOIN dbo.sales s ON s.sale_id=p.sale_id AND s.[status]='PAID'
JOIN dbo.showtimes st ON st.showtime_id=s.showtime_id
JOIN dbo.rooms rm ON rm.room_id=st.room_id
WHERE p.[status]='PAID' AND p.confirmed_at IS NOT NULL
GROUP BY rm.cinema_id,CAST(p.confirmed_at AS DATE),p.method;
GO
-- View: Số ghế theo suất và tỷ lệ bán (không tính ghế đang giữ thành đã bán)
CREATE OR ALTER VIEW dbo.vw_showtime_occupancy AS
SELECT st.showtime_id, st.room_id,
       COUNT_BIG(ss.showtime_seat_id) AS sellable_seats_at_publish,
       COUNT_BIG(t.ticket_id) AS sold_tickets,
       CAST(CASE WHEN COUNT_BIG(ss.showtime_seat_id)=0 THEN 0
            ELSE 100.0*COUNT_BIG(t.ticket_id)/COUNT_BIG(ss.showtime_seat_id)
            END AS DECIMAL(6,2)) AS occupancy_percent
FROM dbo.showtimes st
JOIN dbo.showtime_seats ss ON ss.showtime_id=st.showtime_id
LEFT JOIN dbo.tickets t ON t.showtime_seat_id=ss.showtime_seat_id
GROUP BY st.showtime_id,st.room_id;
GO
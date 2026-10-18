-- HỆ THỐNG QUẢN LÝ RẠP PHIM | SQL SERVER V4
-- Script tạo CSDL mới, không phải migration. Chạy bằng công cụ hỗ trợ GO.

IF DB_ID(N'CinemaManagementDB') IS NULL
BEGIN
    CREATE DATABASE CinemaManagementDB;
END;
GO
USE CinemaManagementDB;
GO

-- Bảng: roles
CREATE TABLE dbo.roles (
    role_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_roles PRIMARY KEY,
    role_code VARCHAR(30) NOT NULL CONSTRAINT UQ_roles_code UNIQUE,
    role_name NVARCHAR(80) NOT NULL
);
GO

-- Bảng: cinemas
CREATE TABLE dbo.cinemas (
    cinema_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_cinemas PRIMARY KEY,
    cinema_name NVARCHAR(150) NOT NULL,
    [address] NVARCHAR(255) NOT NULL,
    [status] VARCHAR(20) NOT NULL CONSTRAINT DF_cinemas_status DEFAULT ('ACTIVE'),
    CONSTRAINT CK_cinemas_status CHECK ([status] IN ('ACTIVE','INACTIVE'))
);
GO

-- Bảng: users
CREATE TABLE dbo.[users] (
    user_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_users PRIMARY KEY,
    role_id INT NOT NULL,
    cinema_id INT NULL,
    username VARCHAR(80) NOT NULL CONSTRAINT UQ_users_username UNIQUE,
    full_name NVARCHAR(120) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    [status] VARCHAR(20) NOT NULL CONSTRAINT DF_users_status DEFAULT ('ACTIVE'),
    created_at DATETIME2(0) NOT NULL CONSTRAINT DF_users_created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_users_roles FOREIGN KEY (role_id) REFERENCES dbo.roles(role_id),
    CONSTRAINT FK_users_cinemas FOREIGN KEY (cinema_id) REFERENCES dbo.cinemas(cinema_id),
    CONSTRAINT CK_users_status CHECK ([status] IN ('ACTIVE','LOCKED'))
);
GO

-- Bảng: movies
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

-- Bảng: genres
CREATE TABLE dbo.genres (
    genre_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_genres PRIMARY KEY,
    genre_name NVARCHAR(80) NOT NULL CONSTRAINT UQ_genres_name UNIQUE,
    is_active BIT NOT NULL CONSTRAINT DF_genres_active DEFAULT (1)
);
GO

-- Bảng: movie_genres
CREATE TABLE dbo.movie_genres (
    movie_id INT NOT NULL,
    genre_id INT NOT NULL,
    CONSTRAINT PK_movie_genres PRIMARY KEY (movie_id, genre_id),
    CONSTRAINT FK_movie_genres_movies FOREIGN KEY (movie_id) REFERENCES dbo.movies(movie_id),
    CONSTRAINT FK_movie_genres_genres FOREIGN KEY (genre_id) REFERENCES dbo.genres(genre_id)
);
GO

-- Bảng: rooms
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

-- Bảng: seat_types
CREATE TABLE dbo.seat_types (
    seat_type_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_seat_types PRIMARY KEY,
    type_name NVARCHAR(60) NOT NULL CONSTRAINT UQ_seat_types_name UNIQUE,
    price_surcharge DECIMAL(12,2) NOT NULL CONSTRAINT DF_seat_types_surcharge DEFAULT (0),
    is_active BIT NOT NULL CONSTRAINT DF_seat_types_active DEFAULT (1),
    CONSTRAINT CK_seat_types_surcharge CHECK (price_surcharge >= 0)
);
GO

-- Bảng: seats
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

-- Bảng: showtimes
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

-- Bảng: showtime_seats
CREATE TABLE dbo.showtime_seats (
    showtime_seat_id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_showtime_seats PRIMARY KEY,
    showtime_id BIGINT NOT NULL,
    seat_id INT NOT NULL,
    held_sale_id BIGINT NULL,
    held_unit_price DECIMAL(12,2) NULL,
    CONSTRAINT CK_showtime_seats_hold_all_or_none CHECK (
        (held_sale_id IS NULL AND held_unit_price IS NULL)
        OR (held_sale_id IS NOT NULL AND held_unit_price IS NOT NULL AND held_unit_price >= 0)
    ),
    CONSTRAINT FK_showtime_seats_showtimes FOREIGN KEY (showtime_id) REFERENCES dbo.showtimes(showtime_id),
    CONSTRAINT FK_showtime_seats_seats FOREIGN KEY (seat_id) REFERENCES dbo.seats(seat_id),
    CONSTRAINT UQ_showtime_seats_position UNIQUE (showtime_id, seat_id)
);
GO
CREATE INDEX IX_showtime_seats_showtime ON dbo.showtime_seats(showtime_id);
CREATE INDEX IX_showtime_seats_held_sale ON dbo.showtime_seats(held_sale_id)
    WHERE held_sale_id IS NOT NULL;
GO

-- Bảng: sales
CREATE TABLE dbo.sales (
    sale_id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_sales PRIMARY KEY,
    receipt_code VARCHAR(40) NOT NULL CONSTRAINT UQ_sales_code UNIQUE,
    showtime_id BIGINT NOT NULL,
    cashier_id INT NOT NULL,
    [status] VARCHAR(20) NOT NULL CONSTRAINT DF_sales_status DEFAULT ('PENDING'),
    created_at DATETIME2(0) NOT NULL CONSTRAINT DF_sales_created DEFAULT SYSUTCDATETIME(),
    completed_at DATETIME2(0) NULL,
    hold_expires_at DATETIME2(3) NULL,
    held_seat_count INT NULL,
    CONSTRAINT CK_sales_hold_pair CHECK (
        (hold_expires_at IS NULL AND held_seat_count IS NULL)
        OR (hold_expires_at IS NOT NULL AND held_seat_count > 0)
    ),
    CONSTRAINT FK_sales_showtimes FOREIGN KEY (showtime_id) REFERENCES dbo.showtimes(showtime_id),
    CONSTRAINT FK_sales_cashiers FOREIGN KEY (cashier_id) REFERENCES dbo.[users](user_id),
    CONSTRAINT CK_sales_status CHECK ([status] IN ('PENDING','PAID','CANCELLED','EXPIRED')),
    CONSTRAINT CK_sales_completed CHECK (([status] = 'PAID' AND completed_at IS NOT NULL) OR ([status] <> 'PAID' AND completed_at IS NULL))
);
GO
CREATE INDEX IX_sales_showtime ON dbo.sales(showtime_id);
CREATE INDEX IX_sales_hold_expiry ON dbo.sales([status], hold_expires_at)
    WHERE hold_expires_at IS NOT NULL;
GO
ALTER TABLE dbo.showtime_seats ADD CONSTRAINT FK_showtime_seats_hold_sales
    FOREIGN KEY (held_sale_id) REFERENCES dbo.sales(sale_id);
GO

-- Bảng: payments
CREATE TABLE dbo.payments (
    payment_id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_payments PRIMARY KEY,
    sale_id BIGINT NOT NULL CONSTRAINT UQ_payments_sale UNIQUE,
    amount DECIMAL(12,2) NOT NULL,
    method VARCHAR(20) NOT NULL,
    [status] VARCHAR(20) NOT NULL,
    confirmed_by INT NULL,
    confirmed_at DATETIME2(0) NULL,
    CONSTRAINT FK_payments_sales FOREIGN KEY (sale_id) REFERENCES dbo.sales(sale_id),
    CONSTRAINT FK_payments_users FOREIGN KEY (confirmed_by) REFERENCES dbo.[users](user_id),
    CONSTRAINT CK_payments_amount CHECK (amount > 0),
    CONSTRAINT CK_payments_method CHECK (method IN ('CASH','BANK_TRANSFER')),
    CONSTRAINT CK_payments_status CHECK ([status] IN ('PENDING','PAID','FAILED')),
    CONSTRAINT CK_payments_confirm CHECK (
        ([status] = 'PAID' AND confirmed_by IS NOT NULL AND confirmed_at IS NOT NULL)
        OR ([status] <> 'PAID' AND confirmed_at IS NULL)
    )
);
GO
CREATE INDEX IX_payments_status_confirmed ON dbo.payments([status], confirmed_at);
GO

-- Bảng: tickets
CREATE TABLE dbo.tickets (
    ticket_id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_tickets PRIMARY KEY,
    sale_id BIGINT NOT NULL,
    showtime_seat_id BIGINT NOT NULL CONSTRAINT UQ_tickets_showtime_seat UNIQUE,
    ticket_code VARCHAR(60) NOT NULL CONSTRAINT UQ_tickets_code UNIQUE,
    unit_price DECIMAL(12,2) NOT NULL,
    issued_at DATETIME2(0) NOT NULL CONSTRAINT DF_tickets_issued DEFAULT SYSUTCDATETIME(),
    checked_at DATETIME2(0) NULL,
    checked_by INT NULL,
    CONSTRAINT FK_tickets_sales FOREIGN KEY (sale_id) REFERENCES dbo.sales(sale_id),
    CONSTRAINT FK_tickets_showtime_seats FOREIGN KEY (showtime_seat_id) REFERENCES dbo.showtime_seats(showtime_seat_id),
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

INSERT INTO dbo.roles(role_code,role_name)
SELECT v.role_code,v.role_name
FROM (VALUES ('ADMIN',N'Quản trị viên'),
             ('MANAGER',N'Quản lý rạp'),
             ('CASHIER',N'Nhân viên bán vé'),
             ('USHER',N'Nhân viên soát vé')) AS v(role_code,role_name)
WHERE NOT EXISTS (SELECT 1 FROM dbo.roles r WHERE r.role_code=v.role_code);
GO



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

-- Thủ tục: usp_hold_seats
CREATE OR ALTER PROCEDURE dbo.usp_hold_seats
    @sale_id BIGINT, @seat_ids NVARCHAR(MAX), @requested_by INT, @hold_minutes INT = 5
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @hold_minutes IS NULL OR @hold_minutes NOT BETWEEN 1 AND 15
        THROW 51001, N'Thời gian giữ phải trong khoảng 1-15 phút.', 1;
    IF @seat_ids IS NULL OR LTRIM(RTRIM(@seat_ids)) = N''
        THROW 51002, N'Danh sách ghế trống.', 1;
    IF EXISTS (SELECT 1 FROM STRING_SPLIT(@seat_ids,N',')
               WHERE TRY_CONVERT(BIGINT,LTRIM(RTRIM(value))) IS NULL)
        THROW 51003, N'Danh sách ghế không hợp lệ.', 1;
    DECLARE @ids TABLE (id BIGINT NOT NULL PRIMARY KEY);
    INSERT INTO @ids(id) SELECT DISTINCT TRY_CONVERT(BIGINT,LTRIM(RTRIM(value)))
    FROM STRING_SPLIT(@seat_ids,N',');
    DECLARE @expected INT=(SELECT COUNT(*) FROM @ids);
    IF @expected=0 OR @expected>8
        THROW 51004, N'Một hóa đơn phải chọn 1-8 ghế (giới hạn MVP đề xuất).', 1;

    DECLARE @showtime_id BIGINT, @cashier_id INT, @locked INT, @now DATETIME2(3), @until DATETIME2(3);
    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT @showtime_id=s.showtime_id,@cashier_id=s.cashier_id
        FROM dbo.sales s WITH (UPDLOCK,HOLDLOCK)
        WHERE s.sale_id=@sale_id AND s.[status]='PENDING'
          AND s.hold_expires_at IS NULL AND s.held_seat_count IS NULL;
        IF @showtime_id IS NULL OR @requested_by<>@cashier_id
            THROW 51005, N'Hóa đơn không hợp lệ, sai nhân viên hoặc đã giữ ghế.', 1;
        IF NOT EXISTS (
            SELECT 1 FROM dbo.[users] u
            JOIN dbo.roles ro ON ro.role_id=u.role_id
            JOIN dbo.showtimes st ON st.showtime_id=@showtime_id
            JOIN dbo.rooms rm ON rm.room_id=st.room_id
            JOIN dbo.movies m ON m.movie_id=st.movie_id
            WHERE u.user_id=@cashier_id AND u.[status]='ACTIVE'
              AND ro.role_code='CASHIER' AND u.cinema_id=rm.cinema_id
              AND rm.[status]='ACTIVE' AND m.[status]='PUBLISHED'
              AND st.[status]='PUBLISHED')
            THROW 51006, N'Sai quyền/rạp hoặc phim, phòng, suất không hoạt động.', 1;

        SELECT @locked=COUNT(*)
        FROM dbo.showtime_seats ss WITH (UPDLOCK,HOLDLOCK)
        JOIN @ids i ON i.id=ss.showtime_seat_id
        WHERE ss.showtime_id=@showtime_id;
        IF @locked<>@expected
            THROW 51007, N'Mã ghế không nằm trong suất đang mua.', 1;
        SET @now=SYSUTCDATETIME();
        SET @until=DATEADD(MINUTE,@hold_minutes,@now);
        IF NOT EXISTS (
            SELECT 1 FROM dbo.showtimes st WHERE st.showtime_id=@showtime_id
              AND st.starts_at > TODATETIMEOFFSET(@now,'+00:00'))
            THROW 51008, N'Suất chiếu đã bắt đầu.', 1;

        UPDATE ss SET ss.held_sale_id=@sale_id,
                      ss.held_unit_price=st.base_price+ty.price_surcharge
        FROM dbo.showtime_seats ss WITH (UPDLOCK,HOLDLOCK)
        JOIN @ids i ON i.id=ss.showtime_seat_id
        JOIN dbo.showtimes st ON st.showtime_id=ss.showtime_id
        JOIN dbo.seats se ON se.seat_id=ss.seat_id
        JOIN dbo.seat_types ty ON ty.seat_type_id=se.seat_type_id
        LEFT JOIN dbo.sales prev ON prev.sale_id=ss.held_sale_id
        WHERE ss.showtime_id=@showtime_id AND se.room_id=st.room_id
          AND se.is_active=1 AND ty.is_active=1
          AND NOT EXISTS (SELECT 1 FROM dbo.tickets t
                          WHERE t.showtime_seat_id=ss.showtime_seat_id)
          AND (ss.held_sale_id IS NULL OR prev.[status]<>'PENDING'
               OR prev.hold_expires_at<=@now);
        IF @@ROWCOUNT<>@expected
            THROW 51009, N'Ghế đang được giữ, đã bán hoặc không hợp lệ. Tất cả được rollback.', 1;

        UPDATE dbo.sales SET hold_expires_at=@until,held_seat_count=@expected
        WHERE sale_id=@sale_id AND [status]='PENDING' AND hold_expires_at IS NULL;
        IF @@ROWCOUNT<>1
            THROW 51010, N'Không ghi được hạn giữ cho hóa đơn.', 1;
        COMMIT TRANSACTION;
        SELECT @sale_id AS sale_id,@until AS hold_expires_at,@expected AS held_seat_count;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- Thủ tục: usp_confirm_sale_and_issue_tickets
CREATE OR ALTER PROCEDURE dbo.usp_confirm_sale_and_issue_tickets
    @sale_id BIGINT,@method VARCHAR(20),@confirmed_by INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @method IS NULL OR @method NOT IN ('CASH','BANK_TRANSFER')
        THROW 51101, N'Phương thức không hợp lệ.', 1;
    DECLARE @showtime_id BIGINT,@cashier_id INT,@expiry DATETIME2(3),
            @expected INT,@locked INT,@count INT,@amount DECIMAL(12,2),@now DATETIME2(3);
    DECLARE @held TABLE(showtime_seat_id BIGINT PRIMARY KEY,unit_price DECIMAL(12,2) NOT NULL);
    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT @showtime_id=showtime_id,@cashier_id=cashier_id,
               @expiry=hold_expires_at,@expected=held_seat_count
        FROM dbo.sales WITH (UPDLOCK,HOLDLOCK)
        WHERE sale_id=@sale_id AND [status]='PENDING';
        IF @showtime_id IS NULL OR @expiry IS NULL OR @expected IS NULL
            THROW 51102, N'Hóa đơn không PENDING hoặc chưa giữ ghế.', 1;
        IF @cashier_id<>@confirmed_by OR NOT EXISTS (
            SELECT 1 FROM dbo.[users] u
            JOIN dbo.roles ro ON ro.role_id=u.role_id
            JOIN dbo.showtimes st ON st.showtime_id=@showtime_id
            JOIN dbo.rooms rm ON rm.room_id=st.room_id
            WHERE u.user_id=@confirmed_by AND u.[status]='ACTIVE'
              AND ro.role_code='CASHIER' AND u.cinema_id=rm.cinema_id)
            THROW 51103, N'Nhân viên không có quyền xác nhận hóa đơn ở rạp này.', 1;

        SELECT @locked=COUNT(*) FROM dbo.showtime_seats ss WITH (UPDLOCK,HOLDLOCK)
        WHERE ss.held_sale_id=@sale_id;
        INSERT INTO @held(showtime_seat_id,unit_price)
        SELECT ss.showtime_seat_id,ss.held_unit_price
        FROM dbo.showtime_seats ss WITH (UPDLOCK,HOLDLOCK)
        JOIN dbo.seats se ON se.seat_id=ss.seat_id
        JOIN dbo.showtimes st ON st.showtime_id=ss.showtime_id
        WHERE ss.held_sale_id=@sale_id AND ss.showtime_id=@showtime_id
          AND se.room_id=st.room_id;
        SELECT @count=COUNT(*),@amount=SUM(unit_price) FROM @held;
        IF @locked<>@expected OR @count<>@expected OR @count=0
            THROW 51104, N'Ghế giữ bị thiếu, sai suất hoặc bị thay đổi.', 1;
        IF EXISTS(SELECT 1 FROM dbo.tickets t JOIN @held h
                  ON h.showtime_seat_id=t.showtime_seat_id)
            THROW 51105, N'Ghế đã phát hành vé.', 1;
        SET @now=SYSUTCDATETIME();
        IF @now>=@expiry
            THROW 51106, N'Giữ ghế đã hết hạn, không được cấp vé.', 1;
        IF NOT EXISTS (
            SELECT 1 FROM dbo.showtimes st WHERE st.showtime_id=@showtime_id
             AND st.[status]='PUBLISHED' AND st.starts_at>TODATETIMEOFFSET(@now,'+00:00'))
            THROW 51107, N'Suất chiếu không còn bán.', 1;

        IF EXISTS (SELECT 1 FROM dbo.payments WHERE sale_id=@sale_id)
            UPDATE dbo.payments SET amount=@amount,method=@method,[status]='PAID',
                 confirmed_by=@confirmed_by,confirmed_at=@now
            WHERE sale_id=@sale_id AND [status]<>'PAID';
        ELSE
            INSERT INTO dbo.payments(sale_id,amount,method,[status],confirmed_by,confirmed_at)
            VALUES (@sale_id,@amount,@method,'PAID',@confirmed_by,@now);
        IF @@ROWCOUNT<>1
            THROW 51108, N'Thanh toán đã được xác nhận.', 1;

        INSERT INTO dbo.tickets(sale_id,showtime_seat_id,ticket_code,unit_price,issued_at)
        SELECT @sale_id,h.showtime_seat_id,CONVERT(VARCHAR(36),NEWID()),h.unit_price,@now FROM @held h;
        IF @@ROWCOUNT<>@expected
            THROW 51109, N'Phát hành không đủ vé.', 1;
        UPDATE dbo.sales SET [status]='PAID',completed_at=@now WHERE sale_id=@sale_id;
        UPDATE ss SET held_sale_id=NULL,held_unit_price=NULL
        FROM dbo.showtime_seats ss JOIN @held h ON h.showtime_seat_id=ss.showtime_seat_id
        WHERE ss.held_sale_id=@sale_id;
        IF @expiry<=SYSUTCDATETIME()
            THROW 51110, N'Đã hết thời hạn trước khi giao dịch hoàn tất.', 1;
        COMMIT TRANSACTION;
        SELECT @sale_id AS sale_id,@expected AS ticket_count,@amount AS total_paid;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- Thủ tục: usp_expire_seat_holds
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

-- Thủ tục: usp_cancel_pending_sale
CREATE OR ALTER PROCEDURE dbo.usp_cancel_pending_sale
    @sale_id BIGINT,@cancelled_by INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS(
            SELECT 1 FROM dbo.sales s WITH (UPDLOCK,HOLDLOCK)
            JOIN dbo.showtimes st ON st.showtime_id=s.showtime_id
            JOIN dbo.rooms rm ON rm.room_id=st.room_id
            JOIN dbo.[users] u ON u.user_id=@cancelled_by
            JOIN dbo.roles ro ON ro.role_id=u.role_id
            WHERE s.sale_id=@sale_id AND s.[status]='PENDING' AND s.cashier_id=@cancelled_by
              AND u.[status]='ACTIVE' AND ro.role_code='CASHIER' AND u.cinema_id=rm.cinema_id)
            THROW 51201, N'Không có quyền hủy hóa đơn này.', 1;
        UPDATE dbo.sales SET [status]='CANCELLED' WHERE sale_id=@sale_id;
        UPDATE dbo.showtime_seats SET held_sale_id=NULL,held_unit_price=NULL
        WHERE held_sale_id=@sale_id;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- Thủ tục: usp_checkin_ticket
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

-- Thủ tục: usp_publish_showtime
CREATE OR ALTER PROCEDURE dbo.usp_publish_showtime
    @showtime_id BIGINT,@manager_id INT,@clean_minutes INT = 15
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @clean_minutes IS NULL OR @clean_minutes NOT BETWEEN 0 AND 120
        THROW 51401, N'Thời gian dọn phòng không hợp lệ.', 1;
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

/* DE XUAT: Mo rong CHI CAC BANG CHINH cua KNLTNC.
  Can chay file schema V5 hien co truoc khi chay migration nay tren DB TEST.
  Khong thay the database/01_cinema_management_schema_v4.sql.
  Khong xoa 17 bang cu; chi them 4 bang moi va cot chi tiet.
  LUU Y: chua kiem thu migration tren SQL Server. Tao ban sao luu truoc khi chay.
  CAC BANG KY THUAT GIU NGUYEN: roles, genres, movie_genres,
  seat_types, payment_attempts, payment_events va cac bang giao dich khac.
  CCCD khong bat buoc de mua ve; khong luu CCCD ro trong database.
*/
USE CinemaManagementV5_DualChannel;
GO

-- Bo sung thuoc tinh cho bang users.
IF COL_LENGTH(N'dbo.users', N'date_of_birth') IS NULL
    ALTER TABLE dbo.[users] ADD [date_of_birth] DATE NULL;
GO
IF COL_LENGTH(N'dbo.users', N'gender') IS NULL
    ALTER TABLE dbo.[users] ADD [gender] VARCHAR(10) NULL;
GO
IF COL_LENGTH(N'dbo.users', N'address_line') IS NULL
    ALTER TABLE dbo.[users] ADD [address_line] NVARCHAR(255) NULL;
GO
IF COL_LENGTH(N'dbo.users', N'avatar_url') IS NULL
    ALTER TABLE dbo.[users] ADD [avatar_url] NVARCHAR(500) NULL;
GO

-- Bo sung thuoc tinh cho bang cinemas.
IF COL_LENGTH(N'dbo.cinemas', N'cinema_code') IS NULL
    ALTER TABLE dbo.[cinemas] ADD [cinema_code] VARCHAR(30) NULL;
GO
IF COL_LENGTH(N'dbo.cinemas', N'phone') IS NULL
    ALTER TABLE dbo.[cinemas] ADD [phone] VARCHAR(20) NULL;
GO
IF COL_LENGTH(N'dbo.cinemas', N'email') IS NULL
    ALTER TABLE dbo.[cinemas] ADD [email] NVARCHAR(160) NULL;
GO

-- Bo sung thuoc tinh cho bang movies.
IF COL_LENGTH(N'dbo.movies', N'original_title') IS NULL
    ALTER TABLE dbo.[movies] ADD [original_title] NVARCHAR(250) NULL;
GO
IF COL_LENGTH(N'dbo.movies', N'director') IS NULL
    ALTER TABLE dbo.[movies] ADD [director] NVARCHAR(200) NULL;
GO
IF COL_LENGTH(N'dbo.movies', N'cast_text') IS NULL
    ALTER TABLE dbo.[movies] ADD [cast_text] NVARCHAR(MAX) NULL;
GO
IF COL_LENGTH(N'dbo.movies', N'country') IS NULL
    ALTER TABLE dbo.[movies] ADD [country] NVARCHAR(100) NULL;
GO
IF COL_LENGTH(N'dbo.movies', N'language') IS NULL
    ALTER TABLE dbo.[movies] ADD [language] NVARCHAR(100) NULL;
GO
IF COL_LENGTH(N'dbo.movies', N'production_year') IS NULL
    ALTER TABLE dbo.[movies] ADD [production_year] SMALLINT NULL;
GO
IF COL_LENGTH(N'dbo.movies', N'poster_url') IS NULL
    ALTER TABLE dbo.[movies] ADD [poster_url] NVARCHAR(500) NULL;
GO
IF COL_LENGTH(N'dbo.movies', N'trailer_url') IS NULL
    ALTER TABLE dbo.[movies] ADD [trailer_url] NVARCHAR(500) NULL;
GO

-- Bo sung thuoc tinh cho bang rooms.
IF COL_LENGTH(N'dbo.rooms', N'projection_format') IS NULL
    ALTER TABLE dbo.[rooms] ADD [projection_format] VARCHAR(10) NULL;
GO
IF COL_LENGTH(N'dbo.rooms', N'notes') IS NULL
    ALTER TABLE dbo.[rooms] ADD [notes] NVARCHAR(255) NULL;
GO

-- Bo sung thuoc tinh cho bang seats.
IF COL_LENGTH(N'dbo.seats', N'notes') IS NULL
    ALTER TABLE dbo.[seats] ADD [notes] NVARCHAR(255) NULL;
GO

-- Bo sung thuoc tinh cho bang showtimes.
IF COL_LENGTH(N'dbo.showtimes', N'format_code') IS NULL
    ALTER TABLE dbo.[showtimes] ADD [format_code] VARCHAR(10) NULL;
GO
IF COL_LENGTH(N'dbo.showtimes', N'cleaning_buffer_minutes') IS NULL
    ALTER TABLE dbo.[showtimes] ADD [cleaning_buffer_minutes] INT NULL;
GO

-- Bo sung thuoc tinh cho bang sales.
IF COL_LENGTH(N'dbo.sales', N'contact_name') IS NULL
    ALTER TABLE dbo.[sales] ADD [contact_name] NVARCHAR(120) NULL;
GO
IF COL_LENGTH(N'dbo.sales', N'contact_phone') IS NULL
    ALTER TABLE dbo.[sales] ADD [contact_phone] VARCHAR(20) NULL;
GO
IF COL_LENGTH(N'dbo.sales', N'contact_email') IS NULL
    ALTER TABLE dbo.[sales] ADD [contact_email] NVARCHAR(160) NULL;
GO

-- Ma rap co the bo trong du lieu cu; neu co ma thi phai duy nhat.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_cinemas_cinema_code' AND object_id = OBJECT_ID(N'dbo.cinemas'))
    CREATE UNIQUE INDEX UX_cinemas_cinema_code ON dbo.cinemas(cinema_code) WHERE cinema_code IS NOT NULL;
GO

-- 01: Ho so nhan vien; thong tin dang nhap va lien he da o bang users.
IF OBJECT_ID(N'dbo.employee_profiles',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.employee_profiles (
  employee_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_employee_profiles PRIMARY KEY,
  user_id INT NOT NULL CONSTRAINT UQ_employee_profiles_user UNIQUE,
  employee_code VARCHAR(30) NOT NULL CONSTRAINT UQ_employee_profiles_code UNIQUE,
  position_title NVARCHAR(100) NOT NULL,
  hire_date DATE NOT NULL,
  contract_type VARCHAR(30) NULL,
  contract_start DATE NULL,
  contract_end DATE NULL,
  base_salary DECIMAL(14,2) NULL,
  employment_status VARCHAR(20) NOT NULL CONSTRAINT DF_employee_profiles_status DEFAULT('ACTIVE'),
  CONSTRAINT FK_employee_profiles_users FOREIGN KEY (user_id) REFERENCES dbo.[users](user_id),
  CONSTRAINT CK_employee_profiles_salary CHECK (base_salary IS NULL OR base_salary >= 0),
  CONSTRAINT CK_employee_profiles_contract CHECK (contract_start IS NULL OR contract_end IS NULL OR contract_end >= contract_start),
  CONSTRAINT CK_employee_profiles_status CHECK (employment_status IN ('ACTIVE','ON_LEAVE','INACTIVE'))
 );
END;
GO

-- 02: Phan ca + moc cham cong thuc te (chua phai he thong tinh luong).
IF OBJECT_ID(N'dbo.employee_shifts',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.employee_shifts (
  shift_assignment_id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_employee_shifts PRIMARY KEY,
  employee_id INT NOT NULL,
  cinema_id INT NOT NULL,
  shift_start DATETIME2(0) NOT NULL,
  shift_end DATETIME2(0) NOT NULL,
  clock_in_at DATETIME2(0) NULL,
  clock_out_at DATETIME2(0) NULL,
  [status] VARCHAR(20) NOT NULL CONSTRAINT DF_employee_shifts_status DEFAULT('SCHEDULED'),
  CONSTRAINT FK_employee_shifts_employee FOREIGN KEY(employee_id) REFERENCES dbo.employee_profiles(employee_id),
  CONSTRAINT FK_employee_shifts_cinema FOREIGN KEY(cinema_id) REFERENCES dbo.cinemas(cinema_id),
  CONSTRAINT CK_employee_shifts_interval CHECK(shift_end > shift_start),
  CONSTRAINT CK_employee_shifts_clock CHECK(clock_in_at IS NULL OR clock_out_at IS NULL OR clock_out_at >= clock_in_at),
  CONSTRAINT CK_employee_shifts_status CHECK([status] IN ('SCHEDULED','COMPLETED','CANCELLED','ABSENT')),
  CONSTRAINT UQ_employee_shifts_person_time UNIQUE (employee_id,shift_start)
 );
 CREATE INDEX IX_employee_shifts_cinema_start ON dbo.employee_shifts(cinema_id,shift_start);
END;
GO

-- 03: Danh muc bap nuoc combo. Stock don gian; chua co so nhap/xuat.
IF OBJECT_ID(N'dbo.products',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.products (
  product_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_products PRIMARY KEY,
  product_code VARCHAR(30) NOT NULL CONSTRAINT UQ_products_code UNIQUE,
  product_name NVARCHAR(150) NOT NULL,
  category VARCHAR(30) NOT NULL,
  [description] NVARCHAR(500) NULL,
  unit_name NVARCHAR(30) NOT NULL,
  price DECIMAL(12,2) NOT NULL,
  stock_quantity INT NOT NULL CONSTRAINT DF_products_stock DEFAULT(0),
  image_url NVARCHAR(500) NULL,
  is_active BIT NOT NULL CONSTRAINT DF_products_active DEFAULT(1),
  CONSTRAINT CK_products_price CHECK(price >= 0),
  CONSTRAINT CK_products_stock CHECK(stock_quantity >= 0),
  CONSTRAINT CK_products_category CHECK(category IN ('FOOD','DRINK','COMBO','OTHER'))
 );
END;
GO

-- 04: Nhat ky thao tac, de truyen du lieu cu/moi da loai bo thong tin nhay cam.
IF OBJECT_ID(N'dbo.audit_logs',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.audit_logs (
  audit_id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_audit_logs PRIMARY KEY,
  actor_id INT NULL,
  [action] VARCHAR(80) NOT NULL,
  entity_name VARCHAR(80) NOT NULL,
  entity_id VARCHAR(80) NULL,
  old_values_json NVARCHAR(MAX) NULL,
  new_values_json NVARCHAR(MAX) NULL,
  actor_ip VARCHAR(45) NULL,
  created_at DATETIME2(0) NOT NULL CONSTRAINT DF_audit_logs_created DEFAULT(SYSUTCDATETIME()),
  CONSTRAINT FK_audit_logs_actor FOREIGN KEY(actor_id) REFERENCES dbo.[users](user_id),
  CONSTRAINT CK_audit_logs_old_json CHECK(old_values_json IS NULL OR ISJSON(old_values_json) = 1),
  CONSTRAINT CK_audit_logs_new_json CHECK(new_values_json IS NULL OR ISJSON(new_values_json) = 1)
 );
 CREATE INDEX IX_audit_logs_created ON dbo.audit_logs(created_at DESC);
END;
GO

/* Gioi han cua ban rut gon:
 - Phim: truong cast_text la mo ta, khong thay bang quan he dien vien neu can loc/chia se dien vien.
 - Lich chieu: cleaning_buffer_minutes la thong tin. Phai cap nhat SP/API moi enforce thoi gian don phong.
 - Gia ve: van dung base_price / seat_types / booking_seats. Chua co quy tac gia phuc tap.
 - Khuyen mai, hoan tien, chot ca tien mat, bao cao luong, phan hoi va ho tro:
   chua co bang nghiep vu rieng trong migration nay; se thiet ke khi trien khai giai doan sau.
 - Products: chua lien ket ban san pham vao sales. Can bang chi tiet ban hang khi lam flow bap nuoc.
 - Bao cao doanh thu: van dung view doanh thu V5, khong tinh thieu/du tien hoan.
 - Khong ghi audit bang trigger vo dieu kien. API phai loai du lieu nhay cam truoc khi ghi log.
 - Ca lam: can kiem tra trung ca va dung rap nhan vien bang transaction trong backend.
 - Chung minh cac rang buoc bang test tren database ban sao truoc khi merge.
*/

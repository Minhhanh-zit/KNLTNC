# HỆ THỐNG QUẢN LÝ RẠP PHIM

**Học phần:** Kỹ năng lập trình nâng cao  
**Nhóm:** TCN  
**Giai đoạn hiện tại:** Thiết kế và kiểm thử cơ sở dữ liệu V4  
**Công nghệ CSDL:** Microsoft SQL Server 2022

## Thành viên

| STT | MSSV | Họ và tên |
|---:|---|---|
| 1 | BIT246755 | Chu Thị Minh Hạnh |
| 2 | BIT230239 | Phạm Phương Linh |
| 3 | BIT240168 | Nguyễn Hà Trung Nam |
| 4 | BIT240216 | Phạm Ngọc Thành |
| 5 | BIT240241 | Nguyễn Quốc Tuấn |

## Những gì hiện có trong repository

| Tệp | Nội dung |
|---|---|
| [SQL Server V4](database/01_cinema_management_schema_v4.sql) | Script tạo mới CSDL, **14 bảng, 20 khóa ngoại**, một view và **6 stored procedure** |
| [ERD DBML](database/He_thong_quan_ly_rap_phim_ERD.dbml) | Sơ đồ 14 bảng và 20 quan hệ FK, có ghi chú tiếng Việt |

**14 bảng:** `roles`, `cinemas`, `users`, `movies`, `genres`, `movie_genres`, `rooms`, `seat_types`, `seats`, `showtimes`, `showtime_seats`, `sales`, `payments`, `tickets`.

### Hai điểm cần hiểu trong V4

- `seats` là ghế vật lý; `showtime_seats` là ghế thuộc một suất chiếu cụ thể.
- Giữ ghế tạm thời bằng `showtime_seats.held_sale_id`; thời hạn giữ chung cho cả hóa đơn nằm tại `sales.hold_expires_at`. Thanh toán hợp lệ mới phát hành vé `tickets`.

## Kết quả kiểm thử đã thực hiện

Thành viên nhóm đã chạy bộ kiểm thử V4 trên **Microsoft SQL Server 2022 bằng Docker** và cung cấp log **6/6 PASS**:

1. Hai quầy cùng giữ ghế A5: chỉ một quầy thành công.
2. Giữ A5 và A6 khi A6 đã bán: rollback toàn bộ.
3. Hóa đơn A hết hạn: A thành `EXPIRED`, B giữ lại được ghế.
4. Thanh toán khi đã hết hạn: không phát hành vé.
5. Xác nhận thanh toán hai lần: chỉ một payment và một ticket.
6. Nhân viên khác rạp: không được giữ hoặc xác nhận hóa đơn.

**Giới hạn bằng chứng:** 6/6 là kết quả của **sáu ca nêu trên**, không chứng minh toàn bộ chức năng đã hoàn tất. Bộ kiểm thử Python đã chạy trên máy của thành viên; **chưa được lưu trong repository này**.

## Cách xem và sử dụng database

1. Mở tệp `.dbml` trong [dbdiagram.io](https://dbdiagram.io) để xem ERD.
2. Dùng **môi trường SQL Server thử nghiệm trống** và công cụ chạy T-SQL hỗ trợ lệnh tách batch `GO`.
3. Chạy script SQL V4 để tạo `CinemaManagementDB`. **Script này dùng để tạo mới, không phải migration**; không chạy chồng lên cơ sở dữ liệu đang có dữ liệu quan trọng.

**Trạng thái dự án:** Repository hiện chỉ chứa mã thiết kế CSDL và ERD, **chưa có ứng dụng Java Spring Boot, frontend hoặc chức năng báo cáo doanh thu được triển khai trong repo**. Những nghiệp vụ khác đang thuộc phạm vi thiết kế/định hướng, không được coi là đã lập trình xong.


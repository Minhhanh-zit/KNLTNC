# HỆ THỐNG QUẢN LÝ RẠP PHIM

**Học phần:** Kỹ năng lập trình nâng cao  
**Nhóm:** TCN  

## Thành viên

| STT | MSSV | Họ và tên |
|---:|---|---|
| 1 | BIT246755 | Chu Thị Minh Hạnh |
| 2 | BIT230239 | Phạm Phương Linh |
| 3 | BIT240168 | Nguyễn Hà Trung Nam |
| 4 | BIT240216 | Phạm Ngọc Thành |
| 5 | BIT240241 | Nguyễn Quốc Tuấn |

## CSDL hợp nhất V4 + V5

Giữ các chức năng quản lý rạp, phòng, phim, lịch chiếu và bán vé tại quầy của V4; bổ sung luồng **đặt vé online** và **thanh toán qua cổng giả lập**, lịch sử giữ ghế và lịch sử các lượt/sự kiện thanh toán từ V5.

**Thiết kế hiện tại:** 17 bảng, 30 khóa ngoại, 9 stored procedure, 3 view.

**17 bảng:** `roles`, `cinemas`, `users`, `movies`, `genres`, `movie_genres`, `rooms`, `seat_types`, `seats`, `showtimes`, `showtime_seats`, `sales`, `payments`, `tickets`, `booking_seats`, `payment_attempts`, `payment_events`.

Các chức năng có trong SQL bao gồm quản lý giữ ghế, tạo đơn theo kênh, xác nhận thanh toán tại quầy, tạo lượt thanh toán giả lập, nhận sự kiện đã xác minh từ backend, dọn giữ ghế hết hạn, hủy đơn chờ, soát vé và công bố suất chiếu.

## Tệp chính

| Tệp | Nội dung |
|---|---|
| [SQL hợp nhất](database/01_cinema_management_schema_v4.sql) | **Bản đang dùng**: SQL V4 + V5, thiết kế 17 bảng và hai kênh bán. Giữ tên file V4 để bảo toàn liên kết cũ. |
| [ERD hợp nhất](database/He_thong_quan_ly_rap_phim_ERD.dbml) | Sơ đồ 17 bảng và 30 quan hệ khóa ngoại. |
| [Bộ kiểm thử 15 ca](tests/kiem_thu_sqlserver_15_tinh_huong.py) | Python + pyodbc, chỉ cho phép kết nối `localhost,14331`. |
| [SQL V4 gốc](database/archive/01_cinema_management_schema_v4_original_14_tables.sql) | Bản V4 nguyên gốc 14 bảng, được sao lưu trước khi hợp nhất. |
| [ERD V4 gốc](database/archive/He_thong_quan_ly_rap_phim_ERD_v4_14_tables.dbml) | Sơ đồ cũ 14 bảng, lưu để so sánh. |

**Lưu ý tên:** Đường dẫn SQL vẫn có đuôi `_v4.sql` theo yêu cầu hợp nhất ngay vào V4, nhưng **nội dung hiện tại không còn là V4 14 bảng**. Tên database được SQL tạo mới là `CinemaManagementV5_DualChannel` để tránh vô tình ghi đè DB V4 đã có.

## Bằng chứng kiểm thử

- V4 gốc: 6/6 ca PASS trên SQL Server 2022, theo log nhóm trước khi hợp nhất.
- Bản hai kênh hợp nhất: **15/15 ca PASS trên Microsoft SQL Server 2022**, theo log Terminal do nhóm cung cấp ngày 19/10/2026.
- 15 tình huống gồm giữ ghế cạnh tranh, chống bán trùng, thời hạn giữ theo kênh, phân quyền, online nhận vé/trả tiền tại quầy, callback lặp, thanh toán đến muộn, đối soát, giới hạn payment attempt, ràng buộc FK chéo suất/đơn, sai số tiền và xác nhận tiền tại quầy hai lần.

Đây là kết quả **bộ kiểm thử SQL có phạm vi xác định**. Chưa chứng minh toàn bộ hệ thống hoạt động hoàn thiện, chưa thay thế kiểm thử bảo mật, hiệu năng, tải cao hay backend/frontend.

## Chạy lại kiểm thử trên Mac

Cần SQL Server TEST đã chạy trên `localhost,14331`, ODBC Driver 18 và `pyodbc`.

```bash
python -m pip install pyodbc
export SQLSERVER_HOST='localhost,14331'
export SQLSERVER_USER='sa'
read -s 'SQLSERVER_PASSWORD?Nhập mật khẩu SQL Server TEST: '
echo
export SQLSERVER_PASSWORD
python -u tests/kiem_thu_sqlserver_15_tinh_huong.py
```

Bộ kiểm thử tạo một database **có tên ngẫu nhiên** `CinemaV5_TEST_<mã>` trên instance test, cài schema, chạy 15 ca rồi xóa database này khi kết thúc theo đúng luồng. Nếu script bị ngắt, database test có thể còn và cần kiểm tra thủ công. **Không chạy trên các instance đang chứa dữ liệu quan trọng.**

**SQL hợp nhất là script tạo mới, không phải migration từ V4 sang V5.** Không chạy trực tiếp lên database V4 cũ đã có dữ liệu thật. Để xem ERD, mở tệp `.dbml` bằng [dbdiagram.io](https://dbdiagram.io).

## Giới hạn hiện tại

- Chưa có ứng dụng Spring Boot hoặc frontend hoàn chỉnh trong repository.
- Cổng thanh toán hiện là `MOCK_GATEWAY`, chưa tích hợp thanh toán thật hoặc xác minh webhook thật.
- 3 view là truy vấn SQL, không đồng nghĩa đã có giao diện báo cáo.
- Thời hạn giữ ghế mặc định 5 phút cho quầy/online gateway và 30 phút cho online trả tại quầy là chính sách demo, cần được nhóm/giảng viên xác nhận.
- Các Use Case trong tài liệu thiết kế không phải tất cả đều đã được lập trình.


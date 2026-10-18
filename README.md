# HỆ THỐNG QUẢN LÝ RẠP PHIM

## Thông tin đề tài và nhóm thực hiện

- **Tên đề tài:** Hệ thống quản lý rạp phim
- **Học phần:** Kỹ năng lập trình nâng cao
- **Quy mô nhóm:** 05 thành viên
- **Nhóm:** TCN

| STT | Mã sinh viên | Họ và tên |
|---:|---|---|
| 1 | BIT246755 | Chu Thị Minh Hạnh |
| 2 | BIT230239 | Phạm Phương Linh |
| 3 | BIT240168 | Nguyễn Hà Trung Nam |
| 4 | BIT240216 | Phạm Ngọc Thành |
| 5 | BIT240241 | Nguyễn Quốc Tuấn |

**Học phần:** Kỹ năng lập trình nâng cao  
**Giai đoạn:** Phân tích yêu cầu và thiết kế CSDL/ERD  
**Định hướng:** Java Spring Boot + Microsoft SQL Server 2022  
**Phiên bản thiết kế:** **V4**, 20 Use Case, **14 bảng**, **20 khóa ngoại**

> Đây là hệ thống **vận hành rạp và bán vé tại quầy (MVP)**, không phải dự án đặt vé trực tuyến CineHunt. Repo CineHunt cũ chỉ dùng để tham khảo và không được thay đổi.

## 1. Tài liệu cơ sở dữ liệu

- [**Mã SQL Server V4**](database/01_cinema_management_schema_v4.sql): tạo database `CinemaManagementDB`, 14 bảng, ràng buộc, các view và **6 stored procedure** xử lý nghiệp vụ.
- [**Thiết kế ERD bằng DBML**](database/He_thong_quan_ly_rap_phim_ERD.dbml): 14 bảng, 20 quan hệ FK. Có thể mở [dbdiagram.io](https://dbdiagram.io), tạo sơ đồ mới và dán nội dung tệp `.dbml`.

Danh sách **14 bảng**:

`roles`, `cinemas`, `users`, `movies`, `genres`, `movie_genres`, `rooms`, `seat_types`, `seats`, `showtimes`, `showtime_seats`, `sales`, `payments`, `tickets`.

**Khác phiên bản cũ:** không còn bảng `ticket_checkins`; lượt soát vé thành công được ghi trực tiếp bằng `tickets.checked_at` và `tickets.checked_by`. Giữ ghế tạm theo hóa đơn: `sales.hold_expires_at`, `showtime_seats.held_sale_id` và `showtime_seats.held_unit_price`.

## 2. Nghiệp vụ MVP

- Quản lý rạp, nhân viên, vai trò; phim và thể loại; phòng, loại ghế và ghế.
- Tạo/công bố suất chiếu; kiểm tra trùng phòng và khoảng thời gian dọn phòng.
- Bán vé tại quầy: **giữ nhiều ghế nguyên tử**, chờ thu tiền mặt hoặc xác nhận chuyển khoản thủ công, phát hành vé.
- Hết hạn giữ ghế, hủy hóa đơn đang chờ, soát vé một lần và tổng hợp báo cáo.

**Ngoài phạm vi:** thanh toán trực tuyến tự động, ví điện tử, AI gợi ý phim, chương trình khách hàng thân thiết, bán đồ ăn và đặt vé online.

## 3. Giữ ghế và chống bán trùng

1. Nhân viên tạo hóa đơn `sales` trạng thái `PENDING`, đúng suất chiếu và đúng rạp.
2. `usp_hold_seats` giữ tất cả ghế yêu cầu trong **một giao dịch**; thời hạn mặc định 5 phút được lưu **một lần tại hóa đơn**.
3. Sau khi xác nhận đã thu tiền, `usp_confirm_sale_and_issue_tickets` kiểm tra thời hạn, quyền nhân viên, tình trạng ghế và phát hành vé.
4. `usp_expire_seat_holds` chuyển hóa đơn hết hạn sang `EXPIRED`; ghế quá hạn có thể được yêu cầu giữ lại ngay cả khi tác vụ dọn chưa chạy.
5. `usp_cancel_pending_sale` xử lý hủy hóa đơn chưa thanh toán; `usp_checkin_ticket` soát vé; `usp_publish_showtime` công bố lịch.

Các ràng buộc quan trọng: `UNIQUE(showtime_id, seat_id)` ở `showtime_seats`, `UNIQUE(showtime_seat_id)` ở `tickets`; các điều kiện liên bảng và xử lý đồng thời được kiểm soát thêm trong stored procedure/giao dịch SQL.

> Nếu tiền chuyển khoản đến **sau khi hết hạn giữ**, không được tự phát hành vé. Khoản tiền thực tế cần được đối soát và xử lý thủ công; database không tự hoàn tiền.

## 4. Kết quả kiểm thử V4 trên SQL Server 2022

Người thực hiện đã chạy bộ thử nghiệm **trên SQL Server 2022 Docker, ở một database dùng một lần**, và cung cấp log:

| STT | Kịch bản | Kết quả |
|---|---|---|
| 1 | Hai quầy đồng thời giữ ghế A5 | **PASS**: một thành công, một thất bại |
| 2 | Giữ A5 + A6 khi A6 đã bán | **PASS**: rollback cả yêu cầu |
| 3 | Hóa đơn A hết hạn, B giữ lại ghế | **PASS**: A = EXPIRED; B giữ thành công |
| 4 | Thanh toán sau hạn trong lúc chờ khóa | **PASS**: không phát hành vé |
| 5 | Cashier xác nhận hai lần | **PASS**: một payment và một ticket |
| 6 | Cashier rạp X xử lý hóa đơn rạp Y | **PASS**: bị từ chối |

**Tổng:** `RESULT: 6/6 PASS on actual Microsoft SQL Server`.

> Kết quả này chứng minh **sáu kịch bản nêu trên** trong điều kiện đã thử, **không** có nghĩa mọi tính năng hoặc tình huống sản xuất đều đã được kiểm thử. Cần kiểm thử thêm trùng lịch, dữ liệu bất thường, retry, lỗi kết nối, thanh toán đến muộn và phân quyền ở tầng API.

## 5. Cách tạo cơ sở dữ liệu

1. Chuẩn bị **SQL Server 2022** và một **instance/database thử nghiệm trống**.
2. Mở `database/01_cinema_management_schema_v4.sql` bằng SSMS, Azure Data Studio hoặc công cụ chạy T-SQL hỗ trợ `GO`.
3. Chạy script trên môi trường mới. Script sẽ tạo `CinemaManagementDB` nếu chưa tồn tại, rồi tạo bảng/ràng buộc/view/stored procedure.

**Lưu ý:** script **tạo mới**, không phải migration và **không nên chạy lại trên database đã có bảng**. `GO` là dấu phân tách batch của công cụ SQL, không phải lệnh T-SQL hợp lệ để gửi nguyên tệp qua một câu lệnh JDBC.

Khi tích hợp Spring Boot, tài khoản của ứng dụng không nên được quyền cập nhật trực tiếp các bảng giao dịch ngoài cơ chế nghiệp vụ đã kiểm soát.

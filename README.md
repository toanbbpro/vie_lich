<div align="center">
  <img src="assets/icon/vie_lich_logo.png" alt="VIE Lịch Logo" width="120" height="120">

  <h1>VIE Lịch - App lịch Việt của người Việt</h1>

  <!-- Badges -->
  [![Release](https://img.shields.io/github/v/release/toanbbpro/vie_lich?label=version&color=blue)](https://github.com/toanbbpro/vie_lich/releases/latest)
  [![Flutter](https://img.shields.io/badge/Built_with-Flutter-%2302569B.svg?style=flat&logo=flutter&logoColor=white)](https://flutter.dev)
  [![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey.svg)](#)
  [![License: GPL v3](https://img.shields.io/badge/License-GPLv3-green.svg)](https://www.gnu.org/licenses/gpl-3.0)
  [![Author: ToanBB](https://img.shields.io/badge/Author-To%C3%A0nBB-orange.svg)](https://github.com/toanbbpro)
  
  > Ứng dụng xem lịch âm, dương và nhắc nhở ngày giỗ, họp họ, lễ hôị truyền thống theo Âm lịch.
</div>

---

## 🌟 Tính năng nổi bật

*   **📅 Lịch ngày:** Hiển thị chi tiết ngày âm/dương, can chi, tiết khí, giờ hoàng đạo và sao tốt/xấu.
*   **📆 Lịch tháng:** Giao diện lưới lịch trực quan, xem bao quát cả âm lịch và dương lịch.
*   **🔔 Nhắc lịch & Sự kiện:** Tạo sự kiện theo lịch âm, đồng bộ sang lịch hệ thống và hỗ trợ thông báo cục bộ (local notification).
*   **⚙️ Tùy chỉnh thông báo:** Hỗ trợ chọn âm thanh thông báo hệ thống hoặc tải lên file âm thanh tùy chỉnh.
*   **🔒 Quản lý thông minh:** Tự động xin và quản lý quyền thông báo, báo thức chạy ngầm ổn định kể cả khi đóng ứng dụng.

## 📱 Screenshot

<details>
<summary><b>Bấm vào đây để xem ảnh</b></summary>

<img width="1440" height="3168" alt="chup_man_hinh1" src="https://github.com/user-attachments/assets/9ffd5359-5c26-404e-9ba8-0c92a6efbfd6" />
<img width="1440" height="3168" alt="chup_man_hinh2" src="https://github.com/user-attachments/assets/60a400ca-21f3-4fff-ae17-bffd6841ea53" />
<img width="1440" height="3168" alt="chup_man_hinh3" src="https://github.com/user-attachments/assets/b5a6b8a1-7f1c-4b4c-8f21-a266439c0816" />
<img width="1440" height="3168" alt="chup_man_hinh4" src="https://github.com/user-attachments/assets/695b26e3-5ac7-42bb-88e4-d7b92cb32fdd" />
<img width="1440" height="3168" alt="chup_man_hinh5" src="https://github.com/user-attachments/assets/6642c74a-5cf7-4e44-a4bb-a64fb9f130d3" />

</details>



## 🛠 Công nghệ sử dụng

Ứng dụng được phát triển bằng Dart & framework Flutter, tích hợp các công nghệ:

*   **[Flutter](https://flutter.dev/):** Nền tảng UI đa nền tảng.
*   **[Hive CE](https://pub.dev/packages/hive_ce):** Cơ sở dữ liệu NoSQL cục bộ, tốc độ cao.
*   **Thuật toán Hồ Ngọc Đức:** Đảm bảo độ chính xác tuyệt đối cho việc tính toán Âm lịch theo múi giờ UTC+7.

## 📥 Cài đặt

Bạn có thể tải xuống phiên bản (APK) mới nhất tại mục **[Releases](https://github.com/toanbbpro/vie_lich/releases)**.

**Dành cho nhà phát triển (Build từ mã nguồn):**

<details>
<summary><b>Bấm vào đây để xem</b></summary>

```bash
# 1. Clone kho lưu trữ
git clone [https://github.com/toanbbpro/vie_lich.git](https://github.com/toanbbpro/vie_lich.git)

# 2. Di chuyển vào thư mục
cd vie_lich

# 3. Tải các thư viện phụ thuộc
flutter pub get

# 4. Build file APK với format version code ngày tháng (Ví dụ: 1.0.0 build 20260918)
flutter build apk --build-number=$(date +'%Y%m%d')
```

</details>


## **📄 Giấy phép**
* **Mã nguồn (Source Code):** Được phát hành dưới giấy phép **[GPL v3](LICENSE)**. Bạn có thể tự do xem, sửa đổi và phân phối lại mã nguồn theo điều khoản của giấy phép này.
* **Tài nguyên (Assets):** Tất cả các tài nguyên hình ảnh, logo (bao gồm `vie_lich_logo.png`), biểu tượng và âm thanh nằm trong thư mục `assets/` đều thuộc bản quyền của tác giả (Copyright © 2026 ToànBB). **KHÔNG** áp dụng giấy phép GPL v3 cho các tài nguyên này. Bạn không được phép sao chép, sử dụng lại hoặc phân phối các tài nguyên này cho mục đích thương mại hay gắn vào dự án khác khi chưa có sự cho phép.

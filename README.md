<div align="center">
  <img src="assets/icon/vie_lich_logo.png" alt="VIE Lịch Logo" width="120" height="120">

  <h1>VIE Lịch - App lịch Việt của người Việt</h1>

  <!-- Badges -->
  [![Release](https://img.shields.io/github/v/release/toanbbpro/vie_lich?label=version&color=blue)](https://github.com/toanbbpro/vie_lich/releases/latest)
  [![Flutter](https://img.shields.io/badge/Built_with-Flutter-%2302569B.svg?style=flat&logo=flutter&logoColor=white)](https://flutter.dev)
  [![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey.svg)](#)
  [![License: GPL v3](https://img.shields.io/badge/License-GPLv3-green.svg)](https://www.gnu.org/licenses/gpl-3.0)
  [![Author: ToanBB](https://img.shields.io/badge/Author-To%C3%A0nBB-orange.svg)](https://github.com/toanbbpro)
  
   Ứng dụng xem lịch âm, dương và nhắc nhở ngày giỗ, họp họ, lễ hội truyền thống theo Âm lịch.
</div>

---

## 🌟 Tính năng

*   **📅 Lịch ngày:** Hiển thị chi tiết ngày âm/dương, can chi, tiết khí, giờ hoàng đạo và sao tốt/xấu.
*   **📆 Lịch tháng:** Giao diện lưới lịch trực quan, xem bao quát cả âm lịch, dương lịch và các lịch được tạo trong nhắc lịch .
*   **🔔 Nhắc lịch & Sự kiện:** Tạo sự kiện theo lịch âm, đồng bộ sang lịch hệ thống và hỗ trợ thông báo cục bộ. Chia sẻ nhắc lịch cho người khác với tạo mã QR.
*   **⚙️ Tùy chỉnh thông báo:** Hỗ trợ chọn âm thanh thông báo hệ thống hoặc tải lên file âm thanh tùy chỉnh. Sao lưu/khôi phục cài đặt app qua file JSON.
*   **🔒 Quản lý thông minh:** Tự động xin và quản lý quyền thông báo.
*   **📆 Widget lịch tháng:** Widget lịch tháng 4x3 ngoài homescreen trên Android, hỗ trợ hiện cả nhắc lịch đã tạo. Widget đi kèm dòng nhắc nhở sự kiện tiếp theo gần nhất.

## 📱 Screenshot

<details>
<summary><b>Bấm vào đây để xem ảnh</b></summary>

<img width="240" height="528" alt="chup_man_hinh1" src="https://github.com/user-attachments/assets/9ffd5359-5c26-404e-9ba8-0c92a6efbfd6" />
<img width="240" height="528" alt="chup_man_hinh2" src="https://github.com/user-attachments/assets/60a400ca-21f3-4fff-ae17-bffd6841ea53" />
<img width="240" height="528" alt="chup_man_hinh3" src="https://github.com/user-attachments/assets/b5a6b8a1-7f1c-4b4c-8f21-a266439c0816" />
<img width="240" height="528" alt="chup_man_hinh4" src="https://github.com/user-attachments/assets/695b26e3-5ac7-42bb-88e4-d7b92cb32fdd" />
<img width="240" height="528" alt="chup_man_hinh6" src="https://github.com/user-attachments/assets/7ee90435-af65-41b3-8666-231273956c54" />
<img width="240" height="528" alt="chup_man_hinh7" src="https://github.com/user-attachments/assets/a045277a-20a5-4e63-9629-108872f7110e" />
<img width="240" height="528" alt="chup_man_hinh8" src="https://github.com/user-attachments/assets/a65aec95-7284-41c9-816c-5e2faf31c6b8" />
<img width="240" height="528" alt="chup_man_hinh0" src="https://github.com/user-attachments/assets/1486733a-7537-456a-bc39-f564dbaf9ecc" />
<img width="240" height="528" alt="chup_man_hinh_update" src="https://github.com/user-attachments/assets/2eb75b1e-4e77-4dc0-b58a-179691a431e8" />

</details>

## 🛠 Công nghệ

Ứng dụng được phát triển bằng Dart & framework Flutter, tích hợp các công nghệ:

*   **[Flutter](https://flutter.dev/):** Nền tảng UI đa nền tảng.
*   **[Hive CE](https://pub.dev/packages/hive_ce):** Cơ sở dữ liệu NoSQL cục bộ, tốc độ cao.
*   **Thuật toán Hồ Ngọc Đức:** Đảm bảo độ chính xác tuyệt đối cho việc tính toán Âm lịch theo múi giờ UTC+7.

## 📥 Cài đặt

Bạn có thể tải xuống phiên bản (APK) mới nhất tại mục **[Releases](https://github.com/toanbbpro/vie_lich/releases)**.
Nếu bạn đã cài bản cũ từ v1.2.1 trở đi sẽ được thông báo cập nhật, ấn cập nhật để app tự tải về và cập nhật.

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

---

## 🚩 Roadmap

*   Publish app lên Google Play Store.
*   App cho Windows, chú trọng desktop widget và notification icon vì sẽ là giao diện thường xuyên nhìn vào nhất.
*   App cho MacOS, chú trọng menubar và widget desktop nếu khả thi.
*   App cho Linux, cụ thể ZorinOS, chú trọng menubar và widget desktop nếu khả thi.
*   App cho iOS, nhưng ko đưa lên Appstore, chỉ hỗ trợ sideload.

## **📄 Giấy phép**
* **Mã nguồn (Source Code):** Được phát hành dưới giấy phép **[GPL v3](LICENSE)**. Bạn có thể tự do xem, sửa đổi và phân phối lại mã nguồn theo điều khoản của giấy phép này.
* **Tài nguyên (Assets):** Tất cả các tài nguyên hình ảnh, logo (bao gồm `vie_lich_logo.png`), biểu tượng và âm thanh nằm trong thư mục `assets/` đều thuộc bản quyền của tác giả (Copyright © 2026 ToànBB). **KHÔNG** áp dụng giấy phép GPL v3 cho các tài nguyên này. Bạn không được phép sao chép, sử dụng lại hoặc phân phối các tài nguyên này cho mục đích thương mại hay gắn vào dự án khác khi chưa có sự cho phép.

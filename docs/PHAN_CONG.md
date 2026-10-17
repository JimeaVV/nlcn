# Phân công và lịch thực hiện (NLCN, nhóm 2 người)

- Thời gian: 8 tuần, từ **thứ Hai 19/10/2026** đến **Chủ nhật 13/12/2026**
  (tạm tính theo mốc "còn khoảng 2 tháng"; khi biết hạn nộp chính thức thì
  chỉnh lại).
- Mục tiêu: chụp một dĩa hoặc tô → app nhận ra **món gì** và **có những thành
  phần nào** (ví dụ cơm tấm có sườn, trứng, có bì hay không) → người dùng chỉnh
  khẩu phần → ghi calo vào Nhật ký. Chạy offline.
- Mọi thoả thuận về dữ liệu và model nằm ở [MODEL_CONTRACT.md](MODEL_CONTRACT.md).

## 1. Vai trò

| | Người A: App và dinh dưỡng | Người B: Model nhận diện |
|---|---|---|
| Tên | JimeaVV (chủ repo) | _(điền tên bạn cùng nhóm)_ |
| Dữ liệu | `components.csv`, `dishes.csv` (dinh dưỡng, khẩu phần mặc định, có nguồn) | Gom ảnh, dọn dữ liệu, gán nhãn, chia tập (`labels.csv`, `splits.csv`) |
| Kỹ thuật | Màn chụp ảnh, màn xác nhận món và thành phần, chỉnh khẩu phần, ghi Nhật ký, gắn `tflite_flutter` | Notebook Colab, các thí nghiệm, đánh giá, xuất `.tflite` + `MODEL_CARD.md` |
| Việc khác | Mở rộng dữ liệu bài tập, Progressive Overload theo lịch sử, benchmark Branch & Bound | Đo tốc độ và kích thước model trên điện thoại |
| Báo cáo | Thiết kế hệ thống, CSDL, giao diện, thuật toán gợi ý | Dữ liệu, phương pháp, thực nghiệm, đánh giá model |

**Làm chung:** chốt danh sách món và thành phần; chụp ảnh tập test; gán nhãn
khung ở giai đoạn YOLO; mở đầu, kết luận, slide và demo.

## 2. Lịch 8 tuần

| Tuần | Thời gian | Người A | Người B | Kết quả cuối tuần |
|---|---|---|---|---|
| 1 | 19/10 – 25/10 | Chốt danh sách cùng B; làm `components.csv` + `dishes.csv` cho khoảng 10 món đầu | Chốt danh sách cùng A; gom ảnh từ bộ công khai, bắt đầu tự chụp; tạo thư mục Drive theo contract | Contract **v1.0** đã chốt, ≥ 50 ảnh/món cho 10 món |
| 2 | 26/10 – 01/11 | Màn camera + màn xác nhận, chạy với **model tạm** | Dọn dữ liệu, gán nhãn món + thành phần; train baseline | Model baseline đầu tiên, app chụp được ảnh |
| 3 | 02/11 – 08/11 | Chỉnh khẩu phần theo thành phần, ghi Nhật ký; hoàn thiện dinh dưỡng 20 món | Thí nghiệm 1–3 (train từ đầu, chỉ lớp cuối, fine-tune) | Bảng kết quả thí nghiệm bản đầu |
| **4** | 09/11 – 15/11 | **Ghép model thật**, chạy trọn luồng trên điện thoại | Chọn model tốt nhất, chỉnh ngưỡng, đo trên điện thoại | **MỐC AN TOÀN: app hoàn chỉnh, nộp được** |
| 5 | 16/11 – 22/11 | Gán khung YOLO (một nửa) + cải thiện app | Gán khung YOLO (một nửa), train YOLO bản đầu | Bộ nhãn khung đầu tiên |
| 6 | 23/11 – 29/11 | Màn hiện khung, đếm số lượng, gợi ý khẩu phần | Cải thiện YOLO, xuất `.tflite`; thí nghiệm 4 (Food-101) nếu kịp | YOLO chạy được trên máy tính |
| 7 | 30/11 – 06/12 | Ghép YOLO vào app, sửa lỗi | Đánh giá mAP@0.5, so sánh nhiều nhãn với YOLO | Bản demo cuối |
| 8 | 07/12 – 13/12 | Báo cáo, slide, demo | Báo cáo, slide, demo | **Nộp** (còn dư thời gian dự phòng) |

**Nếu chậm tiến độ:** đến cuối tuần 4 mà chưa ổn thì **bỏ YOLO**, dùng tuần
5–7 để làm tốt phần nhiều nhãn và viết báo cáo. YOLO chuyển vào *hướng phát
triển*.

## 3. Cách làm việc chung
- **Git:**
  - không commit thẳng lên `main`;
  - mỗi việc một branch, ví dụ `feature/camera`, `data/nutrition`,
    `ml/baseline`;
  - làm xong thì mở **Pull Request**, người kia xem rồi mới gộp.
- **Khu vực code riêng:** A làm trong `lib/` và `assets/data/`; B làm trong
  `tool/train/` và `assets/models/`. Đụng vào khu vực của người kia thì báo
  trước.
- **Họp nhanh mỗi tuần (15 phút):** đã xong gì, đang vướng gì, tuần tới làm
  gì. Ghi kết quả vào `docs/QUA_TRINH_THUC_HIEN.md`.
- **Đổi contract** (thêm hoặc bớt món, thành phần, đổi đầu vào/đầu ra): phải
  cả hai đồng ý, tăng `contract_version`.

## 4. Việc cần làm ngay (tuần 1)
1. **Cả hai:**
   - đọc mục 2–3 của contract, thêm hoặc bớt món và thành phần cho hợp với ảnh
     gom được;
   - chốt contract **v1.0**;
   - thêm người còn lại làm collaborator trên GitHub.
2. **Người A:**
   - lấy *Bảng thành phần thực phẩm Việt Nam* (Viện Dinh dưỡng);
   - điền `assets/data/vn_food/components.csv` (đã có khung: mã, tên, đơn
     vị; cột số liệu để trống), mỗi dòng ghi cột `source`;
   - điền khẩu phần mặc định trong `dishes.csv` cho 10 món đầu (đã có sẵn
     danh sách thành phần thường gặp của mỗi món);
   - sau mỗi lần điền, chạy `python tool/check_vn_food.py` để kiểm tra mã,
     số liệu và nguồn.
3. **Người B:**
   - tìm và kiểm tra license các bộ ảnh công khai, ghi vào `SOURCES.md`;
   - tải về `dataset/vnfood/images/`;
   - bắt đầu tự chụp mỗi bữa ăn, nhất là cơm tấm và cơm phần;
   - tạo thư mục trên Google Drive.
4. **Claude hỗ trợ:**
   - khi đã có ảnh: viết script lọc ảnh trùng, resize, chia tập;
   - gán nhãn sơ bộ, làm trang duyệt ảnh bằng bàn phím;
   - viết notebook Colab train baseline.

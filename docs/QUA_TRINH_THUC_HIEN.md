# OptiFit — Ghi chép quá trình thực hiện (NLCN)

File này ghi lại **đã làm gì, vì sao làm vậy và kết quả ra sao** qua từng giai
đoạn, để làm tư liệu viết báo cáo niên luận chuyên ngành (NLCN). Mỗi khi có
thay đổi đáng kể thì bổ sung một mục mới vào phần *Nhật ký*, ghi rõ ngày,
commit và kết quả kiểm thử.

- Repo NLCN: <https://github.com/JimeaVV/nlcn> (từ 2026-10-17; giữ toàn bộ
  lịch sử commit). Repo NLCSN cũ: <https://github.com/JimeaVV/nlcsn>, giữ
  nguyên, không cập nhật thêm.
- Nền tảng: Flutter (Android), chạy **hoàn toàn offline**: SQLite lưu dữ
  liệu, engine gợi ý viết bằng Dart thuần.
- Xuất phát điểm: sản phẩm NLCSN (OptiFit 1.0, có backend FastAPI), sau đó
  nâng cấp dần lên NLCN.

---

## 1. Nhật ký theo mốc

### 2026-10-16 · Rà soát hiện trạng trước khi nâng cấp
- **Kết quả kiểm tra:** `flutter analyze` không có lỗi, `flutter test` đạt
  76/76.
- **Điểm mạnh:** engine Dart thuần chạy trên isolate riêng, có migration
  SQLite, test đầy đủ.
- **Vấn đề phát hiện:**
  - Phần lớn code mới **chưa được commit**.
  - Repo còn file rác: file khoá Word `~$*.docx`, `render.yaml` cũ.
  - Giao diện lẫn lộn tiếng Việt và tiếng Anh; lỗi từ engine hiện thẳng
    tiếng Anh cho người dùng.
  - Dữ liệu bài tập chỉ đóng gói 96/2918 bài (7 bài Beginner, 0 bài Pro);
    thực phẩm chỉ có 9 món tinh bột, toàn tên tiếng Anh, chưa có món Việt.
  - Branch & Bound chỉ cắt nhánh theo protein; Progressive Overload chưa
    dùng lịch sử tập.
  - `applicationId` vẫn là `com.example.nlcsn`; bản release ký bằng debug key.

### 2026-10-16 · Commit phần chạy offline (`c1680a5`) và dọn repo (`a058671`)
- Chuyển engine gợi ý từ Python/FastAPI sang Dart chạy trên máy; dữ liệu
  đóng gói trong `assets/data/recommendations.json`; bỏ quyền INTERNET ở
  bản release.
- Thêm màn Hồ sơ: mục tiêu giảm/giữ/tăng cân, tự đặt calo và protein, ghi
  cân nặng theo ngày kèm biểu đồ. SQLite lên version 3 mà không mất dữ liệu cũ.
- Dọn repo: gỡ `render.yaml`, file khoá Word, tài liệu cũ (vẫn còn trong
  lịch sử git).

### 2026-10-16 · Đa ngôn ngữ Việt/Anh (`9ab611d`)
- **Làm gì:**
  - Dùng `flutter_localizations` và `gen-l10n`.
  - Chuỗi hiển thị nằm trong `lib/l10n/app_vi.arb` (file gốc) và
    `app_en.arb`.
  - Thêm mục chọn **Ngôn ngữ** trong Cài đặt; mặc định tiếng Việt, lựa chọn
    lưu bằng `shared_preferences`.
- **Quyết định kỹ thuật:**
  - Engine không sinh câu chữ hiển thị nữa, mà ném lỗi có mã:
    `NutritionTargetError`, `MealPlanUnavailableError`,
    `RecommendationErrorCode`. Giao diện dịch mã thành câu theo ngôn ngữ
    đang chọn, thay cho cách so khớp chuỗi tiếng Anh dễ vỡ trước đây.
  - Lời khuyên Progressive Overload được dựng lại từ mã `action` đã lưu, nên
    lịch sử cũ cũng hiển thị đúng ngôn ngữ.
  - Định dạng số theo locale: `1.800,5` (vi) và `1,800.5` (en).
- **Kiểm thử:** analyze sạch, 79/79 test (thêm test đổi ngôn ngữ).

### 2026-10-16 · Nhật ký ăn uống (`d4806b1`)
- **Vì sao:** muốn có tính năng quét đồ ăn bằng camera thì trước tiên app
  phải có chỗ ghi lại *những gì đã ăn*. Trước đó app chỉ gợi ý thực đơn,
  không ghi nhận lượng ăn thực tế.
- **Làm gì:**
  - Tab **Nhật ký**: ghi món theo ngày và theo bữa (sáng/trưa/tối/phụ).
    - Chọn thực phẩm có sẵn trong dữ liệu và nhập số gram; hoặc
    - tự nhập món ngoài theo calo/macro.
  - Tổng calo/protein trong ngày được so với mục tiêu trong hồ sơ.
  - Nút **"Ghi vào nhật ký hôm nay"** ghi cả thực đơn gợi ý trong một
    transaction, mỗi thực đơn chỉ ghi một lần.
  - Cài đặt chuyển thành icon bánh răng trên AppBar để nhường chỗ cho tab mới.
- **Thiết kế dữ liệu:** SQLite version 4 thêm bảng `food_log`.
  - Mỗi dòng lưu **ảnh chụp dinh dưỡng** tại lúc ghi, để cập nhật dataset sau
    này không làm đổi số liệu các ngày cũ.
  - Có cột `source` (`manual` / `mealPlan` / `camera`) và `confidence`, chừa
    sẵn cho model nhận diện món ăn sau này.
- **Lỗi phát hiện nhờ test:** món ghi bằng `DateTime.now()` bị coi là "ngày
  tương lai" vì so sánh có kèm giờ. Đã sửa thành so sánh theo ngày.
- **Kiểm thử:** analyze sạch, 92/92 test (migration v4, model, màn Nhật ký,
  nút ghi thực đơn).

### 2026-10-17 · Chốt hướng nhận diện, phân công nhóm và lịch 8 tuần
- **Yêu cầu làm rõ:** không chỉ nhận ra "cơm tấm", mà còn phải biết dĩa
  **có những thành phần nào** (sườn, trứng, cơm, bì…) thì mới tính calo theo
  từng phần được.
- **Quyết định:**
  - Dùng **một model hai đầu ra** (multi-task) trên cùng backbone ImageNet:
    - đầu `dish`: phân loại món (softmax);
    - đầu `components`: nhận diện nhiều nhãn thành phần (sigmoid).
  - Cách này đủ để biết có hay không có từng thành phần, mà công gán nhãn chỉ
    là tick chọn, rẻ hơn vẽ khung nhiều.
  - **YOLO** chuyển xuống tuần 5–7, chỉ dùng để **đếm số lượng** và gợi ý
    khẩu phần; có phương án bỏ YOLO nếu đến tuần 4 chậm tiến độ.
- **Phân công:**
  - Người A lo app và dữ liệu dinh dưỡng;
  - Người B lo dữ liệu ảnh và model;
  - cả hai cùng gán nhãn khung ở giai đoạn YOLO.
- **Tài liệu mới:**
  - [MODEL_CONTRACT.md](MODEL_CONTRACT.md): bản nháp 20 món, 24 thành phần,
    định dạng `labels.csv`, đầu vào/đầu ra của model, ngưỡng hiển thị;
  - [PHAN_CONG.md](PHAN_CONG.md): vai trò, lịch 19/10 – 13/12/2026, mốc an
    toàn ở tuần 4, quy trình git theo branch và Pull Request.
- `dataset/vnfood/` được thêm vào `.gitignore` để không commit ảnh.

### 2026-10-17 · Tách repo riêng cho NLCN
- Tạo repo công khai **JimeaVV/nlcn** và push toàn bộ lịch sử commit, để vẫn
  thấy được quá trình nâng cấp từ NLCSN lên NLCN.
- Trong repo trên máy: `origin` trỏ về `nlcn`; repo cũ đổi tên remote thành
  `nlcsn` và không push lên đó nữa.
- Bạn cùng nhóm clone từ repo mới:
  `git clone https://github.com/JimeaVV/nlcn.git`.

### 2026-10-17 · Chuẩn bị tuần 1: đổi Application ID, khung dữ liệu dinh dưỡng
- **Phân vai:** JimeaVV là Người A (App + dinh dưỡng), vì đã nắm code app từ
  NLCSN; bạn cùng nhóm là Người B (dữ liệu ảnh + model).
- **Application ID:** đổi từ `com.example.nlcsn` sang
  `io.github.jimeavv.optifit` (Android, iOS, macOS, Linux); `MainActivity`
  chuyển sang package mới.
  - Lưu ý: bản đã cài với ID cũ sẽ không cập nhật lên được, phải gỡ cài đặt
    trước. Lịch sử trên máy đó cũng mất theo.
- **Khung dữ liệu** `assets/data/vn_food/`:
  - `components.csv`: 24 thành phần + 16 dòng "nền" (nước dùng, nước chấm,
    vỏ bánh), đã có mã, tên Việt/Anh và đơn vị tự nhiên;
  - `dishes.csv`: 94 dòng thành phần thường gặp của 20 món;
  - mọi cột số liệu để trống, chờ điền từ nguồn chính thức.
- **Script** `tool/check_vn_food.py`: kiểm tra mã khớp contract, số liệu hợp
  lý, đủ nguồn và báo tiến độ điền. Đã thử với dữ liệu có lỗi cố ý: bắt đủ cả
  4 lỗi.
- Bắt đầu làm theo branch (`chore/week1-setup`) và Pull Request như đã thống
  nhất.

### 2026-10-17 · Cài GitHub CLI, PR đầu tiên và CI
- Cài **GitHub CLI** (`gh` 2.102.0) để mở, gộp và theo dõi Pull Request từ
  terminal. PR #1 (đổi Application ID, khung dữ liệu dinh dưỡng) được gộp
  vào `main` tại commit `bafdf42`.
- Thêm **CI bằng GitHub Actions** (`.github/workflows/ci.yml`), chạy cho mỗi
  PR vào `main` và mỗi lần push lên `main`:
  - job `flutter`:
    - kiểm tra file dịch trong `lib/l10n` khớp với `flutter gen-l10n`
      (tránh quên sinh lại);
    - chạy `flutter analyze` và `flutter test` trên máy Ubuntu sạch, cùng
      phiên bản Flutter 3.44.4 với máy phát triển;
  - job `data`: chạy `tool/check_vn_food.py` để kiểm tra bảng dinh dưỡng.
- **Lý do:**
  - nhóm 2 người cùng gộp code vào `main`;
  - CI chạy trên môi trường sạch, nên bắt được lỗi kiểu "máy tui chạy được"
    và lỗi chỉ xuất hiện khi gộp hai branch, kể cả khi ai đó quên tự chạy
    test.

### 2026-10-17 · Dọn lịch sử commit
- Bỏ dòng đồng tác giả `Co-Authored-By` (do công cụ AI tự thêm) khỏi 9
  commit trên `main` bằng `git filter-branch`, rồi force-push. Nội dung code
  không đổi: so sánh cây thư mục trước và sau không có khác biệt.
- Vì vậy mã commit đã đổi. Các mã ghi trong file này là mã mới.
- Từ nay commit không thêm dòng đồng tác giả. Việc có dùng AI hỗ trợ lập
  trình sẽ được nêu rõ trong báo cáo.

---

## 2. Kế hoạch nhận diện món ăn bằng camera

### 2.1. Bài toán
Muốn ra calo từ ảnh chụp thì phải giải 3 việc:
1. **Nhận diện món** (phần AI).
2. **Ước lượng khẩu phần:** cho người dùng chọn nhỏ/vừa/lớn hoặc nhập gram.
3. **Tra bảng dinh dưỡng món Việt**, ví dụ từ *Bảng thành phần thực phẩm
   Việt Nam* của Viện Dinh dưỡng.

Luồng dự kiến: chụp ảnh → model trên máy trả về top-3 món kèm độ tin cậy →
người dùng xác nhận món và khẩu phần → ghi vào `food_log` với
`source = camera`.

### 2.2. Các quyết định đã chốt
| Vấn đề | Quyết định | Lý do |
|---|---|---|
| Model chạy ở đâu | Trên điện thoại (`.tflite`, đóng gói trong APK) | Giữ app offline, không tốn phí API, có phần tự làm cho báo cáo |
| Dùng model có sẵn hay tự train | **Tự fine-tune** (transfer learning) | Danh sách món phải khớp bảng dinh dưỡng; model có sẵn (Food-101, ML Kit) không biết món Việt hoặc nhãn quá chung chung |
| Điểm xuất phát | Backbone train sẵn trên **ImageNet** | Có sẵn cho các kiến trúc nhẹ, xuất `.tflite` dễ |
| Train ở đâu | **Google Colab** trước; sau này có thể dựng WSL2 trên máy | Colab không phải cài đặt. Máy cá nhân có RTX 2060 Super 8 GB đủ mạnh, nhưng TensorFlow trên Windows không chạy GPU, cần WSL2 và Python 3.10/3.11 |
| Phạm vi | **Một ảnh một dĩa/tô**; model trả về món + các thành phần có trong dĩa (nhiều nhãn) | Đủ để tính calo theo từng thành phần; đếm số lượng giao cho YOLO ở tuần 5–7 (cập nhật 2026-10-17) |

### 2.3. Thiết kế thí nghiệm (chương thực nghiệm)
Cả 4 thí nghiệm dùng cùng tập dữ liệu, cùng cách chia và cùng tập test.

| # | Thí nghiệm | Mục đích |
|---|---|---|
| 1 | CNN nhỏ train từ đầu | Mốc thấp: cho thấy thiếu dữ liệu thì train từ đầu bị overfit |
| 2 | ImageNet, chỉ train lớp phân loại cuối | Hiệu quả của transfer learning |
| 3 | ImageNet, fine-tune thêm vài lớp cuối, có data augmentation | Model chính, đem lên app |
| 4 | ImageNet → Food-101 → món Việt (tuỳ chọn) | Học qua dữ liệu đồ ăn trung gian có giúp gì không |

- Kiến trúc so sánh ở thí nghiệm 3: MobileNetV3, EfficientNet-Lite0,
  EfficientNetV2-B0.
- Chỉ số đánh giá: accuracy top-1/top-3, F1 từng món, confusion matrix,
  kích thước model, thời gian chạy trên điện thoại.
- Xuất model: `.tflite` lượng tử hoá float16 kèm `labels.txt`, đặt trong
  `assets/models/`.

### 2.4. Dữ liệu ảnh
- Danh sách 30–50 món phổ biến, món nào cũng phải có số liệu dinh dưỡng.
- Mỗi món ít nhất 150–300 ảnh. Nguồn gồm:
  - bộ ảnh công khai (đang xem xét *VinaFood21*, *30VNFoods*; **cần kiểm
    tra lại nguồn và license**);
  - ảnh tự chụp.
- Chia tập train/val/test 70/15/15, chia theo từng món; tập test nên có ảnh
  tự chụp bằng điện thoại.
- Ảnh không commit vào git; chỉ commit notebook, script, model cuối cùng và
  kết quả đánh giá. Cố định random seed để chạy lại ra đúng kết quả.

### 2.5. Về YOLO (object detection)
- **YOLO khác phân loại:** YOLO vẽ khung và gọi tên **từng món trong ảnh**,
  ví dụ một đĩa cơm tấm có sườn, trứng, đồ chua. Phân loại thì chỉ trả về
  một nhãn cho cả ảnh.
- **Chi phí lớn hơn nhiều:** phải gán nhãn bằng khung cho từng món trong
  từng ảnh, bằng công cụ như Roboflow, CVAT hay Label Studio, tốn công hơn
  hẳn gán nhãn theo thư mục.
- YOLO cũng dùng transfer learning (train sẵn trên COCO). Diện tích khung có
  thể gợi ý khẩu phần, nhưng vẫn chưa ra được gram.
- **Lưu ý license:** Ultralytics YOLO (v8/11) dùng giấy phép AGPL-3.0. Với đồ
  án học tập thì không sao, nhưng cần ghi rõ nếu sau này phát hành ứng dụng.
- **Quyết định (cập nhật 2026-10-17):**
  - Tuần 1–4 làm model hai đầu ra (món + thành phần nhiều nhãn).
  - Tuần 5–7 làm YOLO để đếm số lượng và gợi ý khẩu phần.
  - Chậm tiến độ thì bỏ YOLO, chuyển vào *hướng phát triển*.

---

## 3. Việc còn tồn đọng
- [ ] Chốt contract v1.0 (danh sách món và thành phần), điền tên hai người
  vào `PHAN_CONG.md`.
- [ ] Gom ảnh vào `dataset/vnfood/` kèm `SOURCES.md`.
- [ ] Script dọn dữ liệu, gán nhãn sơ bộ, trang duyệt ảnh.
- [ ] Notebook Colab để train (chia dữ liệu, các thí nghiệm, đánh giá, xuất
  `.tflite`) trong `tool/train/`.
- [ ] Điền số liệu `assets/data/vn_food/components.csv` và khẩu phần
  `dishes.csv` (khung đã có; chạy `tool/check_vn_food.py`).
- [ ] Màn chụp ảnh, xác nhận món và thành phần, chỉnh khẩu phần, gắn
  `tflite_flutter`.
- [ ] Giai đoạn YOLO (tuần 5–7): gán khung, train, đếm số lượng.
- [ ] Mở rộng dữ liệu bài tập (đang 96/2918 bài, thiếu Beginner/Pro).
- [ ] Benchmark Branch & Bound so với greedy/vét cạn (số node, thời gian,
  độ lệch mục tiêu).
- [ ] Progressive Overload dựa vào lịch sử tập; biểu đồ tiến bộ từng bài.
- [x] Đổi `applicationId` sang `io.github.jimeavv.optifit`.
- [ ] Tạo keystore release riêng.
- [ ] Chạy thử trên điện thoại thật: đổi ngôn ngữ, Nhật ký, ghi thực đơn.

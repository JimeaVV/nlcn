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

### 2026-10-17 · Sắp xếp lại điều hướng, thêm màn Hôm nay và nút Quét
- **Vấn đề khi chạy thử trên điện thoại:**
  - thanh dưới có 5 nút, mỗi nút chỉ rộng khoảng 72 px nên chữ "Tập luyện"
    bị xuống dòng;
  - nếu thêm camera thì thành 6 nút.
- **Quyết định:**
  - Thanh dưới còn **Hôm nay · Ăn uống · 📷 Quét · Tập luyện · Hồ sơ**,
    chia đều hai bên nút Quét.
  - Quét là **nút hành động nổi** ở chính giữa (tròn, nổi lên khỏi thanh,
    gradient), không phải một tab.
  - Các màn cùng nhóm gộp lại bằng **tab con ở trên**:
    - Ăn uống: *Nhật ký · Thực đơn · Đã lưu*;
    - Tập luyện: *Buổi tập · Lịch sử*.
  - Tab Lịch sử cũ được chia vào đúng nhóm; nút "Xóa toàn bộ lịch sử" chuyển
    sang Cài đặt (mục Dữ liệu).
- **Màn Hôm nay mới:** calo và protein đã ăn so với mục tiêu, cân nặng mới
  nhất và thay đổi 7 ngày, số bài đã tập trong ngày, buổi tập gần nhất, kèm
  các nút đi nhanh (Mở nhật ký, Quét, Ghi cân nặng, Tạo buổi tập).
- **Màn Quét tạm thời:** trong lúc chưa có model, cho ghi món thủ công vào
  nhật ký hôm nay. Sau này đây cũng là đường dự phòng khi model nhận sai.
- **Chi tiết kỹ thuật:**
  - Tab con giữ trạng thái khi lướt qua lại (`AutomaticKeepAliveClientMixin`),
    nên thực đơn vừa tạo không bị mất.
  - Chữ trên thanh dưới luôn một dòng, tự thu nhỏ khi hẹp; cỡ chữ hệ thống
    được giới hạn ở 1,3 lần bên trong thanh.
  - Test phát hiện thanh dưới bị tràn 9 px khi bật chữ cỡ lớn; đã sửa.
- **Kiểm thử:** analyze sạch, 98/98 test (thêm test thanh điều hướng, tab
  con, Hôm nay, Quét, Lịch sử tách đôi, xóa lịch sử trong Cài đặt).

### 2026-10-17 · Khóa ký phát hành và tự đăng APK lên GitHub Release
- **Vì sao:**
  - Android chỉ cho cài đè một bản cập nhật khi nó được ký bằng **cùng một
    khóa**.
  - Trước đây bản release ký bằng khóa debug, mà mỗi máy tính lại sinh một
    khóa riêng. Nên APK build ở máy này không cài đè được lên bản build ở
    máy khác hay trên CI, buộc phải gỡ app và mất dữ liệu.
- **Khóa ký:**
  - Tạo khóa RSA 2048, hiệu lực 10.000 ngày, alias `optifit`, chứng chỉ
    `CN=OptiFit, OU=NLCN, O=JimeaVV, C=VN`, SHA-256
    `e3b83ac4…7c7efb`.
  - Khóa và mật khẩu lưu **ngoài repo** (`D:\project\nlcn-keys\`, có
    README hướng dẫn sao lưu); `android/key.properties` bị git bỏ qua.
  - Gradle dùng khóa này khi có `key.properties`. Máy không có khóa (ví dụ
    máy bạn cùng nhóm) vẫn build được bằng khóa debug.
- **GitHub Actions** (`.github/workflows/release.yml`), chạy mỗi lần `main`
  thay đổi:
  - lấy khóa từ **GitHub Secrets** và build APK cho từng loại chip;
  - **kiểm tra chữ ký đúng khóa OptiFit**, sai thì dừng;
  - đăng lên bản phát hành `latest`, để bạn cùng nhóm và giảng viên tải
    thẳng về điện thoại;
  - số hiệu bản (build number) = 100 + số lần chạy, nên bản sau luôn cài
    đè được bản trước.
- **Lưu ý:** app cài bằng khóa debug trên điện thoại phải gỡ một lần để
  chuyển sang khóa mới. Từ đó trở đi, mọi bản đều cài đè được và giữ dữ liệu.

### 2026-10-17 · Nút Quét đổi kiểu theo giao diện
- **Yêu cầu:** đổi giao diện trong Cài đặt thì nút Quét cũng đổi kiểu,
  không chỉ đổi màu.
- **Bốn kiểu** (`lib/widgets/scan_button_face.dart`):

  | Giao diện | Kiểu nút Quét |
  |---|---|
  | Cyberpunk | tròn, gradient xanh neon → hồng, phát sáng hai màu |
  | Minimal Light | tròn, một màu phẳng, bóng đổ nhẹ |
  | Forest | vuông bo góc kiểu chiếc lá, gradient xanh lá → ngọc |
  | Sunset | tròn, dải vàng → cam → tím, vầng sáng như mặt trời |

- Bấm vào thì nút **nhún xuống** (thu nhỏ còn 90%).
- Trong Cài đặt, mỗi ô giao diện hiện **xem trước nút Quét** của giao diện
  đó.
- Kiểu Sunset ban đầu đặt tâm màu vàng ngay dưới icon trắng nên icon bị
  chìm. Đã đổi thành dải màu từ trên xuống, để icon nằm trên nền cam.
- **Kiểm thử:** 101/101 test (thêm test hình dạng từng kiểu, thanh dưới đổi
  theo giao diện, hiệu ứng nhún, ô xem trước trong Cài đặt).

### 2026-10-17 · Luồng quét món bằng camera (chưa có model)
- **Mục tiêu:** dựng xong toàn bộ luồng *chụp ảnh → nhận diện → xác nhận →
  ghi nhật ký* trước khi có model. Khi Người B train xong, chỉ cần cài đặt
  interface nhận diện, giao diện không phải sửa.
- **Thành phần:**
  - `image_picker`: chụp ảnh hoặc chọn từ thư viện, ảnh thu nhỏ còn tối đa
    1280 px.
  - `FoodRecognizer` (`lib/services/food_recognizer.dart`): interface theo
    contract, gồm xác suất món (softmax) và xác suất từng thành phần
    (sigmoid). Tạm dùng `NoModelRecognizer` (chưa đoán gì).
  - `VnFoodRepository` + `parseVnFoodData`: đọc `components.csv`,
    `dishes.csv` và file mới `dish_names.csv` (tên Việt/Anh của 20 món). Bộ
    đọc CSV tự viết, xử lý được ô có ngoặc kép, dấu phẩy, xuống dòng, BOM.
  - `ScanPlate`: áp ngưỡng của contract:
    - ≥ 0,6: tick sẵn;
    - 0,3–0,6: gắn nhãn "Có thể có", chờ người dùng xác nhận;
    - thành phần ngoài công thức mà model thấy chắc thì tự thêm vào;
    - phần nền (nước chấm, nước dùng) luôn được giữ.
- **Màn kết quả:**
  - Model chắc chắn (≥ 0,5) thì mở thẳng món; nếu không thì hiện top-3,
    hoặc cho chọn trong 20 món.
  - Mỗi thành phần có ô tick, nút −/+ (đơn vị tự nhiên như quả, miếng, hoặc
    gram), calo; có thể thêm thành phần khác.
  - Ghi vào nhật ký mỗi thành phần một dòng, tên dạng "Sườn nướng (Cơm
    tấm)", `source = camera`, kèm `confidence`.
- **Ràng buộc dữ liệu:** thành phần chưa có số liệu dinh dưỡng thì hiện
  "chưa có số liệu" và chặn nút ghi, cho tới khi bỏ chọn hoặc điền số liệu.
  App không bao giờ tự đoán số liệu.
- **Kiểm thử:** 111/111 test, trong đó:
  - CSV: ngoặc kép, CRLF, BOM; dữ liệu thật có đủ 20 món;
  - ngưỡng tick và câu hỏi;
  - quy đổi đơn vị sang gram;
  - luồng có model và không có model;
  - huỷ chụp ảnh;
  - đường đi từ màn Quét tới khi ghi nhật ký.

### 2026-10-17 · Camera ngay trong app, theo phong cách giao diện
- **Yêu cầu:** bấm Quét là mở camera ngay trong app (không nhảy sang app
  camera của máy). Nút thư viện ảnh nằm bên trái nút chụp, nút ghi thủ công
  bên phải, tất cả đổi kiểu theo giao diện.
- **Làm gì:**
  - Dùng plugin `camera` chính thức (CameraX trên Android), camera sau,
    độ phân giải cao, chỉ chụp ảnh nên không bật âm thanh.
  - Bố cục màn camera:
    - camera chiếm toàn màn hình;
    - **khung ngắm** dạng 4 góc, màu theo giao diện; Forest bo góc mềm,
      Cyberpunk/Sunset có phát sáng;
    - nút đóng và đèn flash ở trên;
    - dòng nhắc "Đặt dĩa hoặc tô vào giữa khung";
    - hàng dưới gồm **Thư viện · nút chụp · Ghi tay**.
  - Nút chụp là nút Quét của giao diện đang chọn, thêm vòng trắng như camera
    thật. Hai nút bên (`StyledCameraButton`) cũng đổi hình dạng và màu theo
    giao diện.
  - Lớp `ScanCamera` tách camera ra khỏi giao diện, để test dùng camera giả.
  - Camera được giải phóng khi app chạy nền và mở lại khi quay về. Có cờ
    chặn mở hai lần, vì hộp thoại xin quyền cũng làm app tạm dừng.
  - Xem ảnh xong mà không ghi thì camera chạy tiếp; ghi xong thì đóng màn
    Quét.
  - **Dự phòng:** bị từ chối quyền, máy không có camera, hoặc lệnh liệt kê
    camera bị treo quá 10 giây thì chuyển sang màn có *Chọn ảnh · Ghi thủ
    công · Thử mở camera lại*.
- **Quyền Android:**
  - Gỡ quyền **ghi âm** (`RECORD_AUDIO`) mà plugin tự thêm, vì app không
    dùng micro.
  - Camera đặt là *không bắt buộc*, để máy không có camera vẫn cài được.
  - App vẫn không có quyền INTERNET.
- **Kiểm thử:** 113/113 test, thêm các trường hợp:
  - chụp → xem kết quả → ghi → đóng camera;
  - vị trí ba nút, đèn flash, quay lại thì camera chạy tiếp;
  - huỷ chọn ảnh, nút đóng;
  - bị từ chối quyền thì sang màn dự phòng.
- Đã cài lên điện thoại thật (Xiaomi, HyperOS 4).

### 2026-10-17 · Bảo vệ nhánh main bằng CI bắt buộc
- PR #6 (luồng quét và camera trong app) đã gộp vào `main`.
- Bật **Allow auto-merge** cho repo, và đặt **branch protection** cho `main`:
  - hai job `Flutter analyze and test` và `Nutrition data check` là điều
    kiện bắt buộc trước khi gộp;
  - không bắt buộc nhánh phải cập nhật theo `main` mới nhất (`strict: false`)
    để nhóm 2 người đỡ phải gộp lại nhiều lần; job CI chạy khi push lên
    `main` vẫn bắt lỗi phát sinh sau khi gộp.
- **Lý do:** tự gộp chỉ chờ những check *bắt buộc*. Không đặt điều kiện thì
  bật tự gộp sẽ gộp ngay cả khi CI chưa chạy xong.

### 2026-10-17 · Làm gọn màn Hồ sơ
- **Vấn đề khi dùng thật:** màn Hồ sơ quá nhiều chữ.
  - Đoạn công thức BMR/TDEE và ghi chú luôn hiện.
  - Hai ô "calo/protein tự đặt" kèm nút "Dùng … ước tính" nằm giữa form.
  - Kết quả quan trọng nhất (calo, protein mỗi ngày) lại nằm cuối form.
  - Thẻ cân nặng có đoạn ghi chú 4 dòng.
- **Nguyên tắc áp dụng:** số liệu chính to và đặt lên đầu; giải thích để sau
  nút ⓘ; tùy chọn nâng cao thì ẩn cho tới khi bật.
- **Thay đổi:**
  - Thẻ **Mục tiêu mỗi ngày** ở trên cùng:
    - hai ô số lớn (kcal, protein), mỗi ô có nhãn "ước tính" hoặc "tự đặt";
    - nút ⓘ mở bảng **Cách tính** gồm công thức, BMR/TDEE và lưu ý dành cho
      người trưởng thành.
  - Form gọn hơn:
    - Tuổi, chiều cao, cân nặng trên **một hàng**;
    - giới tính và mục tiêu chọn bằng **nút bấm** thay cho danh sách thả
      xuống.
  - **Công tắc "Tự đặt calo" và "Tự đặt protein"** (theo góp ý):
    - tắt thì dùng số ước tính và ẩn ô nhập;
    - bật thì hiện ô nhập, điền sẵn số ước tính hiện tại;
    - tắt lại thì quay về ước tính.
  - Thẻ cân nặng:
    - ghi chú chuyển vào ⓘ;
    - danh sách chỉ hiện 5 lần ghi gần nhất, có nút "Xem tất cả (n)".
  - Bỏ 11 chuỗi không còn dùng.
- **Lỗi phát hiện khi test:** `SwitchListTile` đặt trong thẻ có nền màu làm
  hiệu ứng chạm không hiện được. Đã đổi sang hàng chữ cộng `Switch`.
- **Kiểm thử:** 114/114 test, gồm:
  - bật công tắc thì điền sẵn đúng số ước tính (2.625 kcal, 126 g);
  - tắt công tắc thì quay về ước tính;
  - ⓘ hiện công thức và BMR/TDEE;
  - danh sách cân nặng gập ở 5 lần ghi.

### 2026-10-17 · Điền dữ liệu dinh dưỡng cho các thành phần món ăn
- **Mục tiêu:** model chỉ nhận ra trong dĩa có gì; muốn ra calo thì app cần
  dinh dưỡng trên 100 g của từng thành phần trong `components.csv`.
- **Nguồn dữ liệu (theo thứ tự ưu tiên):**
  1. **Viện Dinh dưỡng Quốc gia**, công cụ "Tra cứu giá trị dinh dưỡng thực
     phẩm" (https://viendinhduong.vn/vi/cong-cu-va-tien-ich/gia-tri-dinh-duong-thuc-pham):
     853 thực phẩm, mã số theo Bảng thành phần thực phẩm Việt Nam. Ưu tiên vì
     là số liệu của thực phẩm Việt Nam.
  2. **USDA FoodData Central** (https://fdc.nal.usda.gov), bộ FNDDS và SR
     Legacy: dùng cho món đã nấu mà bảng Việt Nam không có (cơm, trứng ốp la,
     hủ tiếu, cháo, sườn nướng).
  - Công cụ "Tra cứu giá trị dinh dưỡng của món ăn" của Viện cho số liệu
    **theo suất**, không ghi khối lượng, nên không quy ra 100 g được; chỉ
    dùng để tham khảo.
- **Kết quả:** 24/40 thành phần đã có số. Cột `source` ghi mã của từng số
  liệu; dòng nào là **gần đúng** thì ghi rõ lý do. Ví dụ "Thịt kho" lấy theo
  thịt luộc, chưa tính nước kho.
  - Đơn vị có nguồn: 1 quả trứng ốp la = 55 g, 1 quả trứng luộc = 50 g
    (USDA FNDDS).
- **Chưa điền, có lý do:**
  - **Xôi nếp:** USDA chỉ có nếp luộc (96 kcal/100 g), trong khi xôi hấp
    đặc hơn nhiều (bảng Việt Nam ghi xôi gấc, xôi đỗ khoảng 230 kcal). Dùng
    số USDA sẽ sai gần 2,5 lần.
  - **Nước dùng, nước chấm** (13 dòng `_base_*`), **mỡ hành**, **chả trứng**:
    không có nguồn cho riêng phần này. Mục phở của USDA đã gồm cả bánh phở
    nên dùng sẽ bị tính hai lần. Cần tính theo công thức nấu từ nguyên liệu
    có trong bảng.
  - **Khối lượng 1 đơn vị** (chén cơm, ổ bánh mì, miếng sườn…) và khẩu phần
    mặc định trong `dishes.csv`: cần cân thực tế.
- **Sửa lỗi nhỏ:** `tool/check_vn_food.py --strict` bị lỗi khi in tiếng Việt
  ra console Windows. Đã ép stdout dùng UTF-8.
- **Kiểm thử:** `check_vn_food.py` báo OK; tất cả dòng đã điền đều khớp
  calo ≈ 4·đạm + 4·bột đường + 9·béo; 114/114 test.

### 2026-10-17 · Tính dinh dưỡng cho nước chấm và món phụ theo công thức
- **Vấn đề:** nước chấm, mỡ hành, chả trứng, vỏ bánh xèo là hỗn hợp nhiều
  nguyên liệu. Bảng thành phần không có sẵn số cho chúng.
- **Cách làm:**
  1. Nhờ hai chatbot (ChatGPT và Gemini) liệt kê công thức nấu: nguyên liệu
     tính bằng gram, khối lượng thành phẩm, link nguồn. **Không** lấy số calo
     của chatbot.
  2. So sánh hai bản:
     - **Chọn bản ChatGPT** vì mỗi món dẫn về một bài công thức cụ thể và
       tự ghi rõ chỗ nào là ước tính.
     - **Không dùng bản Gemini:** nguồn mơ hồ ("Hướng Nghiệp Á Âu", sách
       không ghi trang). Có số chính xác giả tạo, ví dụ "xương tiết 50–70 g
       mỡ". Còn ghi Bảng thành phần thực phẩm là nguồn của tỷ lệ nếp ra xôi,
       trong khi bảng này không có số đó.
  3. Tự mở bài gốc trên Điện máy XANH để kiểm tra từng công thức:
     - bánh xèo khớp định lượng (200 g bột gạo, 50 g bột năng, 400 ml nước
       dừa);
     - chả trứng: bài gốc ghi **20 g gia vị**, ChatGPT tự nâng lên 52 g. Đã
       sửa theo bài gốc.
  4. Script `tool/vn_food_recipes.py` cộng dinh dưỡng các nguyên liệu (số
     của Viện Dinh dưỡng) rồi chia cho khối lượng thành phẩm, ra số trên
     100 g. Chạy `--write` để ghi vào `components.csv`.
- **Kết quả đợt đầu:** thêm 7 dòng, nâng lên 31/40:
  - nước mắm cơm tấm 122 kcal, nước chấm bún chả 53 kcal, nước mắm bún thịt
    nướng 98 kcal (trên 100 g);
  - mỡ hành 583 kcal, chả trứng 168 kcal, vỏ bánh xèo và giá 191 kcal
    (1 cái khoảng 139 g, tính từ mẻ 6 cái);
  - **xôi nếp:** không dùng tỷ lệ nếp ra xôi của chatbot (2,2 lần hoặc 1,62
    lần, hai bên lệch nhau). Lấy "Xôi nếp cẩm" của Viện Dinh dưỡng (235 kcal)
    làm số gần đúng, vì cùng là nếp đồ chín.
- **9 dòng cuối (7 loại nước dùng, sốt bò kho, gỏi cuốn), dùng số tạm:**
  - Nước dùng hầm xương: phần lớn năng lượng đến từ mỡ và chất tan từ
    xương, công thức không cho biết lượng này. Nhóm chốt **dùng số tạm**:
    mọi app đếm calo đều chỉ là ước tính, và nước dùng chiếm phần nhỏ trong
    tổng calo của tô.
  - Cách tính: lấy nước dùng xương làm sẵn của USDA (bò 171538: 7 kcal; gà
    174536: 6 kcal trên 100 g), cộng phần gia vị còn lại trong nồi theo công
    thức (nước mắm, đường phèn, mắm ruốc, dầu điều, riêu cua, cà chua…).
  - Kết quả: phở bò 9, phở gà 9, hủ tiếu 11, bánh canh 10, bún bò Huế 19,
    bún riêu 25, nước nhưn mì Quảng 40 kcal/100 g. Cột nguồn ghi **"ước tính
    thấp"** vì chưa tính mỡ xương. Nước phở thật có thể cao hơn vài lần.
  - Sốt bò kho (46 kcal): chưa tính gói xốt 90 g (không rõ thành phần) và
    mỡ bò tiết ra.
  - Gỏi cuốn: 1 cuốn = 1 bánh tráng 15 g (khối lượng theo USDA FNDDS
    2708166) và 15 g tương đậu phộng (**giả định** 1 muỗng canh/cuốn).
  - Phở bò, phở gà: link ChatGPT đưa (BlueStone, VnExpress) không tìm thấy,
    nên dẫn bài Điện máy XANH tương ứng. Phần chính là số USDA, gia vị nêm
    chỉ thêm vài kcal.
- **Kết quả cuối: 40/40 thành phần có dinh dưỡng.**
- **Khối lượng 1 đơn vị** (nhóm ước lượng):

  | Đơn vị | Khối lượng |
  |---|---|
  | 1 chén cơm | 150 g |
  | 1 ổ bánh mì | 80 g |
  | 1 miếng chả trứng | 50 g |
  | 1 khúc cá | 100 g |
  | 1 miếng đậu hũ | 100 g |
  | 1 lát chả lụa | 20 g |
  | 1 cuốn bánh cuốn | 35 g |

  - **Trừ phần không ăn được:** số dinh dưỡng trên 100 g tính cho phần ăn
    được. Vì vậy:
    - Sườn: 1 miếng 120 g kể cả xương. Theo USDA 167827 (miếng sườn 209 g
      có xương cho 157 g thịt) phần ăn được là 75%, nên tính **90 g**.
    - Tôm: 1 con 20 g cả vỏ, thịt bóc vỏ 10–12 g, nên tính **11 g**.
    - Cá: 100 g còn da và xương, chưa trừ vì không có tỷ lệ; có thể hơi cao.
  - Các số này là ước lượng của nhóm. Khi cân thực tế thì cập nhật lại.

### 2026-10-17 · Khẩu phần mặc định của từng món
- **Mục đích:** model báo dĩa có thành phần nào thì app điền sẵn lượng của
  thành phần đó theo `dishes.csv`; người dùng chỉnh lại nếu dĩa nhiều hoặc
  ít hơn.
- **Cách làm:** nhóm **ước lượng** một suất bình thường ở quán cho cả 94
  dòng. Đây là đồ án sinh viên nên không cân từng món. Ví dụ:
  - cơm tấm: 1,5 chén cơm, 1 miếng sườn, 30 g bì, 1 miếng chả, 1 trứng;
  - phở: 200 g bánh phở, 80 g thịt, 400 g nước dùng;
  - bánh cuốn: 6 cuốn.
- **Kiểm tra chéo** với công cụ tra cứu món ăn của Viện Dinh dưỡng (số liệu
  theo suất):

  | Món | App tính | Viện Dinh dưỡng |
  |---|---|---|
  | Phở bò | 480 kcal | 350–450 kcal |
  | Bún chả | 809 kcal | 520–750 kcal |
  | Hủ tiếu | 292 kcal | khoảng 450 kcal |

  - Hủ tiếu thấp hơn vì nước dùng đang là ước tính thấp và chưa tính thịt.
  - Bún chả hơi cao vì thịt nướng (401 kcal/100 g) là loại nửa nạc nửa mỡ.
  - Nhìn chung cùng cỡ số, đủ dùng cho app ước tính.
- **Kết quả:** `check_vn_food.py --strict` không còn ô trống: 40/40 thành
  phần, 94/94 khẩu phần.

### 2026-10-17 · Mở rộng lên 40 món theo bộ ảnh VinaFood21
- **Phát hiện:** đối chiếu 20 món ban đầu với hai bộ ảnh công khai:
  - **30VNFoods** (MIT, 30 món): có 13/20 món;
  - **VinaFood21** (UIT, 21 món, khoảng 14 nghìn ảnh): chỉ trùng `bo_kho`;
  - không bộ nào có cơm phần, cơm gà, cơm chiên, bún chả, cháo gà; phở chỉ
    có chung "Phở", không tách bò và gà. Những món này phải tự chụp.
- **Quyết định:** thêm 20 món còn lại của VinaFood21 (món 21–40 trong
  contract), để dùng được hết bộ ảnh đó.
- **Giữ chi phí gán nhãn thấp:**
  - Món gồm nhiều thứ thì **dùng lại thành phần có sẵn**, không thêm mã thành
    phần mới. Ví dụ: thịt kho trứng = `thit_kho` + `trung_kho`; gà nướng =
    `ga`; bánh hỏi = `thit_nuong` + `mo_hanh`.
  - Món chỉ có một thứ (bánh tét, bắp nướng, tàu hũ, há cảo…) thì để toàn
    bộ dinh dưỡng ở dòng nền `_base_<món>`. Ảnh VinaFood21 đã có nhãn món,
    nên không phải gán nhãn thành phần.
- **Dinh dưỡng của 18 dòng nền mới:**
  - Lấy món gần nhất trong bảng Viện Dinh dưỡng, ghi rõ "gần đúng":
    - bánh tét theo bánh chưng (181 kcal/100 g);
    - bánh ú theo bánh gio (173);
    - bò lá lốt theo chả lá lốt rán (306);
    - hoành thánh theo mỳ vằn thắn, tính cả nước (81);
    - bánh ướt theo bánh cuốn (129);
    - bánh hỏi theo bún tươi (116);
    - bắp nướng theo ngô nướng (274).
  - Lấy theo USDA: há cảo (113, FNDDS 2708708), pate của bánh mì chảo (319,
    SR 172930).
  - Tính theo **công thức nhóm ước lượng** bằng `vn_food_recipes.py`:
    - tàu hũ 90, phá lấu 135, bánh căn 173, bánh tráng trộn 338, bột chiên
      199 kcal/100 g;
    - nước cà ri 87, canh khoai mỡ 45, canh khổ qua 43 kcal/100 g;
    - nước trộn gỏi gà 210 kcal/100 g.
  - Khối lượng 1 đơn vị và khẩu phần mặc định cũng do nhóm ước lượng, ví dụ
    1 khoanh bánh tét 100 g, 1 trái bắp 120 g, 6 cái há cảo.
- **Kết quả:** 40 món, 58 dòng thành phần (24 thành phần + 34 dòng nền), 133
  dòng khẩu phần; `--strict` báo OK; 114/114 test.
- Đây là thay đổi contract: số lớp đầu ra `dish` tăng từ 20 lên 40.

### 2026-10-17 · Họp nhóm: chốt contract v1.0
- Hai thành viên đồng ý danh sách **40 món** và các thành phần hiện có.
  `contract_version` tăng từ 0.1 lên **1.0**.
- Từ nay muốn thêm hoặc bớt món, thành phần thì phải cả hai đồng ý và tăng
  phiên bản contract.

### 2026-10-17 · Gắn sẵn khung chạy model TFLite vào app
- **Mục tiêu:** làm trước phần ghép model, để tới tuần 4 (mốc ghép model
  thật) chỉ việc thả file của người B vào `assets/models/` là app chạy.
  Lỗi kỹ thuật lộ ra từ bây giờ thay vì sát hạn.
- **Thiết kế:**
  - `food_model.dart` (Dart thuần, test được trên máy tính):
    - **tiền xử lý ảnh:** xoay ảnh theo EXIF (ảnh điện thoại thường lưu
      hướng xoay trong EXIF chứ không xoay điểm ảnh), cắt vuông ở giữa,
      resize 224×224 bilinear, RGB 0–255 float32;
    - đọc `dishes.txt`, `components.txt` và các ngưỡng trong
      `MODEL_CARD.md`;
    - đổi hai đầu ra thành xác suất theo mã.
  - `tflite_food_recognizer.dart`:
    - chạy model bằng `tflite_flutter` 0.12.1 (LiteRT 1.4.0);
    - giải mã ảnh và chạy model trên **isolate riêng** để giao diện không
      bị khựng;
    - interpreter chỉ mở khi chụp tấm đầu tiên, không làm chậm lúc mở app.
  - App kiểm tra `assets/models/food_v1.tflite`: có thì chạy model, không có
    hoặc file hỏng thì về chọn món bằng tay như trước.
  - Ngưỡng tick/hỏi lại không còn cố định trong code mà đi theo từng model.
    Contract tăng lên **v1.1** để ghi cách viết ngưỡng.
- **Phát hiện khi thử:**
  - Model xuất từ Keras có thể đổi thứ tự đầu ra: model giả trả ra
    `components` trước `dish`. Vì vậy app nhận ra đầu ra theo **độ dài**,
    không theo vị trí.
  - Build Android lỗi "Inconsistent JVM Target": `tflite_flutter` biên dịch
    Java theo bản 11 nhưng Kotlin theo bản 21. Sửa trong
    `android/build.gradle.kts`, chỉ áp cho plugin này.
  - APK arm64 tăng từ 19,9 MB lên 39,4 MB do thư viện LiteRT (có cả phần
    GPU). Có thể tối ưu sau.
- **Model giả:**
  - `tool/make_dummy_food_model.py` tạo model **chưa train**, đúng định dạng
    contract: 40 món, 24 thành phần, float16, 6,8 KB. Đây cũng là mẫu cách
    xuất model cho người B.
  - Đã cài thử lên điện thoại thật: chụp ảnh thì app hiện 3 món, mỗi món
    khoảng 3% (đoán ngẫu nhiên trên 40 món). App báo "model không chắc, hãy
    chọn món", đúng nhánh xử lý khi độ tin cậy thấp.
  - Model giả **không** được đưa vào repo.
- **Kiểm thử:** thêm 13 test, có test tự kiểm tra mã trong model khớp bảng
  dinh dưỡng khi người B đưa model vào; analyze sạch.

### 2026-10-18 · Rà soát toàn app và sửa đợt 1
- **Cách rà soát:** chia app làm 3 mảng, mỗi mảng giao một agent chỉ đọc
  code:
  - thuật toán gợi ý (Branch & Bound, bài tập, Progressive Overload);
  - giao diện;
  - dữ liệu, lưu trữ và luồng quét món.
  - Kết quả: 36 đề xuất, mỗi đề xuất có vị trí code và mức công sức.
  - Mọi lỗi được kiểm chứng lại trực tiếp trong code trước khi sửa.
  - Nhóm thành 3 đợt: đợt 1 sửa lỗi người dùng gặp, đợt 2 nâng cấp thuật
    toán, đợt 3 kỹ thuật.
- **Đợt 1 đã sửa:**
  1. **Lưu hồ sơ không còn tự ghi cân nặng.** Trước đây chỉ đổi mục tiêu
     cũng ghi thêm cân nặng hôm nay, làm sai biểu đồ và số "thay đổi 7
     ngày". Giờ chỉ ghi khi cân nặng trên form khác lần cân gần nhất.
  2. **Nhận số thập phân dấu phẩy** ("70,5"), đúng cách app hiển thị tiếng
     Việt. Dùng chung hàm `parseDecimal` cho hồ sơ, cân nặng, tạ và nhật ký.
  3. **Bấm Quét 2 lần nhanh** không còn mở 2 màn camera.
  4. **Chạy model lần lượt từng ảnh.** Thư viện `tflite_flutter` trả về
     kết quả toàn 0 (không báo lỗi) nếu ảnh mới đến khi ảnh trước chưa chạy
     xong; giờ ảnh sau chờ ảnh trước.
  5. **Xoá ảnh quét** sau khi xem kết quả, để ảnh bữa ăn không chất trong
     bộ nhớ máy. Camera cũng không tự mở lại sau màn kết quả khi app quay về
     từ nền.
  6. **Lưu thực đơn hoặc buổi tập chỉ một lần**: nút chuyển thành "ĐÃ LƯU".
  7. **Bỏ chữ tiếng Anh viết cứng** (`PROCESSING...`, `g protein`,
     `P/C/F`, `0–30`), chuyển hết vào file dịch. Câu "Model chưa chắc
     chắn" đổi thành "Ứng dụng chưa chắc chắn".
  8. **Tìm món trong Nhật ký:**
     - không cần gõ dấu ("pho", "trung op la");
     - tìm được cả 58 món và thành phần Việt Nam có dinh dưỡng;
     - chọn món có đơn vị thì điền sẵn khối lượng 1 đơn vị (1 quả trứng ốp
       la = 55 g);
     - sửa lỗi đổi qua "Tự nhập" rồi quay lại vẫn lưu món cũ không còn hiện
       trên màn.
- **Kiểm thử:** 136 test pass, analyze sạch. Test mới gồm:
  - lưu hồ sơ không thêm cân nặng;
  - dấu phẩy thập phân, tìm kiếm bỏ dấu;
  - tìm món Việt trong Nhật ký;
  - chạy model không chồng lên nhau;
  - lưu thực đơn một lần.

### 2026-10-18 · Thực đơn món Việt (đợt 2, phần 1)
- **Vấn đề:** planner cũ chọn từ 160 nguyên liệu tiếng Anh, ra kiểu "75 g
  yến mạch sống + ức gà", không ai ăn theo được.
- **Cách làm, chốt cùng nhóm:**
  - **Bữa sáng:** ăn nguyên món (phở, bánh mì, xôi…), chỉnh số suất.
  - **Trưa/tối:** món nguyên, hoặc **cơm phần** do Branch & Bound ghép: cơm
    (theo chén), 1–2 món mặn, rau, canh tuỳ chọn.
  - **Bảng tag `meal_plan.csv`:** món nào hợp bữa nào và mục tiêu nào.
    - Đang giảm cân thì **không** gợi ý phở, bánh mì, xôi, bánh cuốn, cơm
      tấm…: không ai cutting mà ăn các món đó.
    - Giảm cân: cơm **tính theo gram** (người cutting thường cân cơm), mỗi
      bữa 100–200 g; chỉ món nạc (gà, cá, tôm, đậu hũ, trứng luộc, thịt
      bò).
    - Tag nằm trong CSV, sửa được mà không cần sửa code.
  - **Thêm thành phần `ga_chien`** (contract v1.2): cơm gà ở quán thường là
    gà chiên hoặc xối mỡ. Tính như gà luộc sẽ thiếu nhiều calo. Số liệu
    lấy theo USDA FNDDS 2705996.
  - Planner cũ (nguyên liệu tiếng Anh) vẫn giữ trong code; app dùng planner
    mới.
- **Cải tiến Branch & Bound:**
  - **Cận dưới theo calo:** từ calo ít nhất và nhiều nhất các nhóm còn lại
    có thể thêm, tính được sai số calo nhỏ nhất còn có thể đạt. Cộng với
    cận protein cũ, nhánh nào chắc chắn không tốt hơn lời giải đang có thì
    cắt.
  - Món nguyên tốt nhất được dùng làm lời giải ban đầu cho cơm phần.
  - **Seed thay cho giới hạn thời gian:**
    - Mỗi lần bấm, app bốc một seed ngẫu nhiên mới nên thực đơn vẫn mỗi lần
      một khác.
    - Giới hạn tìm kiếm đổi từ 1,5 giây sang tối đa 300.000 nút, nên cùng
      seed thì máy nào cũng ra cùng thực đơn. Seed được lưu kèm thực đơn.
- **Kết quả đo** (`dart run tool/bench_meal_planner.dart`, 150 hồ sơ thật
  mỗi mục tiêu: 2 giới, 5 mức cân nặng, 3 mức vận động, 5 seed):

  | Mục tiêu | Đạt mục tiêu | Số nút: chỉ cận protein | Số nút: thêm cận calo | Giảm | Chất lượng giống nhau |
  |---|---|---|---|---|---|
  | Giảm cân | 106/150 | 31.242 | 19.809 | 1,6 lần | 150/150 |
  | Giữ cân | 129/150 | 17.576 | 8.435 | 2,1 lần | 150/150 |
  | Tăng cân | 128/150 | 19.336 | 9.322 | 2,1 lần | 150/150 |

  - Lập một thực đơn cả ngày mất khoảng 1 ms.
  - "Đạt mục tiêu" nghĩa là calo trong ±5% và protein từ −10% đến +20%.
- **Tinh chỉnh dựa trên số đo:**
  - Bản đầu chỉ có 17/150 thực đơn giảm cân đạt. Lý do: người vận động
    nhiều có mục tiêu giảm cân 2.200–2.700 kcal mà chỉ được 1 chén cơm mỗi
    bữa. Đã sửa (cùng góp ý của nhóm: TDEE cao thì ăn 1,5–2 chén vẫn ổn):
    - bữa sáng nhẹ hơn (25%), trưa và tối mỗi bữa 37,5%;
    - cháo hoặc gỏi cuốn được tới 2 suất;
    - cơm tính theo gram: bữa tới 600 kcal tối đa 200 g, bữa lớn hơn tới
      300 g (khoảng 2 chén);
    - bắp nướng làm bữa phụ.
    - Kết quả lên 106/150; phần còn hụt là người vận động rất nhiều (hệ số
      1,9).
  - Mục tiêu từ 2.600 kcal có thêm **bữa phụ** (bắp nướng, bánh tét, xôi,
    tàu hũ).
  - **Ngưỡng protein thống nhất:** planner chấp nhận protein dư tới 20%
    nhưng nhãn "đạt mục tiêu" chỉ cho 10%, nên có thực đơn planner coi là
    tốt mà app lại báo chưa đạt. Giờ cả hai cùng dùng −10% đến +20%.
- **Kiểm thử:** 145 test pass.
  - Thêm `vn_meal_planner_test.dart`, gồm:
    - cùng seed ra cùng thực đơn;
    - giảm cân không có món nặng, cơm ≤ 1 chén;
    - cận calo không làm đổi kết quả;
    - hết ngân sách nút vẫn trả về thực đơn.
  - `check_vn_food.py` kiểm tra thêm `meal_plan.csv`.

### 2026-10-18 · Progressive Overload theo lịch sử tập (đợt 2, phần 2)
- **Giữ bước tăng 2,5 kg** (theo góp ý của nhóm): ngoài phòng gym không có
  bánh tạ nhỏ hơn, nên tăng theo % là không thực tế.
- **Luật 2 buổi:** chỉ tăng tạ khi buổi này **và** buổi trước của cùng bài,
  cùng mức tạ, đều đạt 3×12 với độ khó Dễ hoặc Vừa. Mới đạt lần đầu thì app
  khuyên "tập lại mức này thêm một buổi". Tránh trường hợp hôm nay khoẻ bất
  thường là tăng tạ liền.
  - App lấy buổi gần nhất của bài đó trong lịch sử tập. Cột `difficulty`
    đã có sẵn trong database, chỉ cần đọc ra.
- **Bài không tạ (0 kg):** đạt 3×12 thì khuyên **thêm 2 lần mỗi hiệp** hoặc
  chuyển biến thể khó hơn, thay vì "tăng 2,5 kg"; chưa đạt thì khuyên nhắm 8
  lần đúng kỹ thuật, thay vì "giảm 2,5 kg".
- **Sửa luật:** đạt đủ 3×12 nhưng chọn "Kiệt sức" trước đây bị khuyên giảm
  tạ. Giờ đổi thành giữ nguyên mức tạ, vì mục tiêu đã đạt.
- Bỏ điều kiện thừa `tổng số lần < 24`: điều kiện này chỉ đúng khi có hiệp
  dưới 8 lần, mà trường hợp đó đã được kiểm tra riêng.
- **Kiểm thử:** 138 test pass, gồm luật 2 buổi (khác mức tạ, buổi trước
  nặng, buổi trước thiếu lần đều không tính) và bài không tạ.

### 2026-10-18 · Gán lại cấp độ cho 96 bài tập (đợt 2, phần 3)
- **Giữ bộ 96 bài** (quyết định của nhóm): bộ 2.918 bài có nhiều bài ít
  người tập, nên chỉ giữ những bài phổ biến nhất cho mỗi nhóm cơ.
- **Vấn đề:** trong 96 bài chỉ có 7 bài Beginner và 0 bài Pro, nên người chọn
  Beginner hoặc Pro gần như luôn nhận bài Intermediate.
- **Cách sửa:** gán lại cấp cho 42 bài theo nguyên tắc:
  - máy, cáp, cô lập, thân người đơn giản là **Beginner**;
  - bài nặng, đòi kỹ thuật (deadlift, front squat, dip, glute ham raise,
    hanging leg raise…) là **Pro**.
  - Nhóm đã duyệt từng dòng, chi tiết trong [CAP_DO_BAI_TAP.md](CAP_DO_BAI_TAP.md).
  - Sau khi sửa: 38 Beginner, 49 Intermediate, 9 Pro; buổi nào cũng có đủ cả
    3 cấp.
  - Cấp độ trong app là **ưu tiên mềm**: đúng cấp 6 điểm, lệch 1 cấp 3 điểm.
    Gán lại cấp không làm mất bài của ai.
- **Nhóm cơ bị bỏ sót:** cầu vai (shrug) và đùi trong/ngoài (máy khép, mở
  đùi) không nằm trong buổi nào nên không bao giờ được gợi ý. Đã cho cầu vai
  vào Pull, đùi trong/ngoài vào Legs.
- Sửa ở file gốc `backend/data/gym-ex-dataset.csv` rồi sinh lại asset. Đã
  kiểm tra chỉ 42 dòng cấp độ thay đổi, dữ liệu thực phẩm giữ nguyên.
- **Kiểm thử:** người mới tập Push giờ nhận toàn bài Beginner; Pro nhận được
  bài Pro; shrug và máy khép/mở đùi được gợi ý.
- **Hạn chế cần ghi trong báo cáo:** khối lượng thành phẩm là ước tính của
  công thức, chưa cân thực tế. Khi nấu và cân được thì sửa số trong script và
  chạy lại.

### 2026-10-19 · Notebook train trên Kaggle
- **Bộ ảnh:** người B tìm được 4 bộ công khai. Đối chiếu với 40 món, 25
  thành phần:

  | Bộ ảnh | Trùng món | Ghi chú |
  |---|---|---|
  | VinaFood21 | 21 | 20 món mới của contract v1.0 lấy theo bộ này |
  | VietFood67 (33.000 ảnh, 26 GB) | 17 | có khung cho khoảng 15 thành phần, CC BY-NC-SA 4.0 |
  | 30VNFoods | 14 | phở bò và gà chung một lớp, MIT |
  | 20FoodVN | 12 | có phở bò riêng, Apache 2.0 |

  - Chỉ còn 4 món không bộ nào có, phải tự chụp: cơm phần, cơm gà, cháo gà,
    phở gà.
- **Chọn Kaggle Notebook thay cho Colab:** dữ liệu nằm sẵn trên Kaggle, gắn
  vào notebook là dùng được, khỏi tải 26 GB. GPU miễn phí khoảng 30 giờ một
  tuần. "Save & Run All" chạy trên server nên tắt trình duyệt vẫn chạy tiếp.
- **Notebook `tool/train/train_food_model.ipynb`:**
  - Gộp 4 bộ thành một tập train chung.
  - Đổi tên lớp sang mã của app bằng cách so tên đã bỏ dấu; lớp app không
    có thì bỏ.
  - **Dùng khung của VietFood67 làm nhãn thành phần:**
    - ảnh chỉ có cơm và món mặn, không có khung tên món, là cơm phần, nên
      có thêm dữ liệu cho món còn thiếu;
    - "Trứng", "Chả", "Rau" được đổi theo món chứa nó.
  - **Masked loss:** ảnh chỉ có nhãn món thì không tính loss phần thành
    phần, để "không biết" không bị học thành "không có".
  - Bỏ ảnh trùng giữa các bộ bằng average hash, để không có ảnh vừa ở train
    vừa ở test. Chia 70/15/15 theo từng món.
  - Train 2 pha (đầu ra trước, rồi 40% lớp trên của backbone) và lưu
    checkpoint mỗi epoch. Ba thí nghiệm (`scratch`, `linear`, `finetune`)
    và hai backbone chỉ cần đổi một biến.
  - Chỉnh ngưỡng tick thành phần trên tập val, ghi vào `MODEL_CARD.md`.
  - Xuất tflite float16, rồi tự kiểm tra kích thước đầu vào, đầu ra và so
    kết quả với Keras.
- **Đã thử trên máy** với dữ liệu giả mô phỏng 4 kiểu thư mục:
  - chạy trọn từ gom ảnh tới xuất file;
  - nhãn đúng: "Bánh mì" có dấu nhận đúng, phở lẫn và cao lầu bị bỏ, ảnh
    cơm + thịt kho + rau thành cơm phần, ảnh 2 món bị bỏ;
  - file xuất ra qua được test của app (mã khớp bảng dinh dưỡng).

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

### 2026-10-19 · Contract v1.3: thêm 12 món và lớp "khác"
- **Vấn đề:** chụp món app chưa có thì model vẫn buộc phải đoán một trong
  40 món, và thường đoán sai mà rất tự tin.
- **Thêm 12 món phổ biến có sẵn ảnh trong 4 bộ công khai** (tổng 52 món):
  bánh chưng, bánh khọt, bánh bèo, cao lầu, bún đậu, bún mắm, cháo lòng, cá
  kho, canh chua, trứng vịt lộn, chè, nước mía.
  - Lấy thẳng từ bảng của Viện Dinh dưỡng: bánh chưng (15006, 1 miếng 150 g),
    cháo lòng (15042), trứng vịt lộn (9010, 1 quả 60 g), nước mía (14040,
    1 ly 300 g).
  - Tính theo công thức trong `tool/vn_food_recipes.py`, ghi rõ là ước
    lượng (kcal/100 g): bánh khọt 248, bánh bèo 125, nước sốt cao lầu 196,
    phần nền bún đậu 213, nước bún mắm 50,5, cá kho 188, canh chua 28,7,
    chè 146.
  - Gắn tag bữa ăn và mục tiêu trong `meal_plan.csv` cho các món mới.
- **Lớp `khac` (món app chưa có):**
  - Là dòng cuối của `dishes.txt`, không có dinh dưỡng.
  - App không bao giờ đưa `khac` ra làm gợi ý. Khi xác suất của nó từ
    `threshold_confident_dish` trở lên, app không tự chọn món và báo "Có vẻ
    món này chưa có trong app".
  - Notebook gom ảnh của các lớp app không có (gỏi ngó sen, lẩu, hamburger,
    bún chả cá…) vào `khac`, tối đa 3.000 ảnh để lớp này không lấn các lớp
    khác. Đặt `USE_OTHER = False` để bỏ.
  - Với VietFood67, ảnh có khung heo quay, mực, ốc, cua, lòng heo, chả
    được tính như món mặn. Vì vậy ảnh cơm kèm các món đó thành cơm phần,
    không bị đưa vào `khac`.
- **Thực đơn chỉnh lại sau khi thêm món:** thêm món làm chất lượng giữ cân
  tụt còn 107/150. Đã sửa:
  - lập các bữa ăn nguyên món (sáng, phụ) trước; bữa trưa và tối dùng cơm
    phần để bù phần calo còn thiếu hoặc dư;
  - chia protein theo bữa: sáng 20%, phụ 5%, phần còn lại chia đều trưa và
    tối;
  - các món nguyên có điểm gần bằng nhau (lệch dưới 12% calo của bữa) thì
    bốc ngẫu nhiên, nên thực đơn đa dạng hơn;
  - mỗi lần chỉ thử 4 món mặn ngẫu nhiên, để cây tìm kiếm không phình ra.
- **Kết quả đo lại** (`dart run tool/bench_meal_planner.dart`, 150 hồ sơ mỗi
  mục tiêu):

  | Mục tiêu | Đạt mục tiêu | Số nút: chỉ cận protein | Số nút: thêm cận calo | Giảm | Chất lượng giống nhau |
  |---|---|---|---|---|---|
  | Giảm cân | 100/150 | 18.315 | 12.602 | 1,5 lần | 150/150 |
  | Giữ cân | 150/150 | 6.906 | 3.370 | 2,0 lần | 150/150 |
  | Tăng cân | 150/150 | 7.878 | 3.965 | 2,0 lần | 150/150 |

  - Lập một thực đơn cả ngày mất khoảng 0,7–1,2 ms.
- **Kiểm thử:**
  - 149 test pass. Test model thật bị bỏ qua vì chưa có model đi kèm app.
  - Chạy thử notebook trên dữ liệu giả, có một lớp app không có (gỏi ngó
    sen). Kết quả:
    - 12 ảnh của lớp đó vào `khac`;
    - `dishes.txt` có 53 dòng (52 món + `khac`);
    - `results.json` có độ chính xác riêng của `khac`.

### 2026-10-19 · Train trên cả 2 GPU T4
- **Vấn đề:** Kaggle cho "GPU T4 x2", nhưng Keras chỉ dùng GPU đầu tiên nếu
  không có code chia việc, nên GPU thứ hai ngồi không.
- **Cách làm:**
  - Tạo và compile model trong `tf.distribute.MirroredStrategy`. Mỗi batch
    được chia đôi cho 2 GPU, rồi gộp gradient lại.
  - `BATCH = 64` vẫn là tổng của cả 2 GPU, không nhân đôi. Nhờ vậy chạy trên
    1 GPU hay 2 GPU, model học cùng một kiểu, và kết quả của hai người vẫn
    so sánh được.
  - Lúc xuất, trọng số được chép sang một model tạo ngoài strategy rồi mới
    chuyển sang TFLite, để converter chỉ thấy biến bình thường.
  - Notebook in ra số GPU đang dùng, để kiểm tra ngay khi chạy thử.
- **Đã thử trên máy:** chia CPU thành 2 thiết bị ảo để mô phỏng 2 GPU.
  Chạy trọn tới bước xuất TFLite, và kết quả TFLite khớp với Keras. Bản
  chạy 1 thiết bị vẫn chạy bình thường.
- **Phiên nháp kẹt ở "Adding data":** khi gắn 4 bộ ảnh (VietFood67 nặng
  26 GB), phiên nháp của Kaggle có lúc báo tải xong từng bộ, lặp vòng mãi
  mà không vào được. Cách tránh: chạy thử bằng **Save & Run All** với
  `QUICK_TEST = True`, vì bản này chạy trên máy riêng của Kaggle. Đã ghi
  vào README và phần đầu notebook.

### 2026-10-19 · Notebook đọc ảnh nhanh hơn
- **Vấn đề:** lần chạy thử đầu tiên trên Kaggle (`QUICK_TEST`, GPU T4 x2)
  chạy gần 20 phút mà chưa xong.
  - Bước bỏ ảnh trùng mở **toàn bộ** ảnh của 4 bộ, khoảng 70.000 ảnh, để
    tính hash, rồi mới cắt xuống 12 ảnh mỗi món.
  - Ảnh nằm trên ổ mạng của Kaggle nên mở từng ảnh một rất chậm.
- **Cách sửa:**
  - Với mỗi món, trộn ảnh bằng seed cố định trước, rồi mở lần lượt tới khi
    đủ số ảnh cần (`MAX_PER_DISH`), mỗi đợt mở gấp đôi số còn thiếu để bù
    ảnh trùng. Chạy thử giờ chỉ mở khoảng 32 ảnh mỗi món, thay vì tất cả.
  - Mở ảnh song song 32 luồng.
  - Với JPEG, giải nén ở kích thước nhỏ (`draft`) vì hash chỉ cần 8×8.
  - Ảnh WebP chỉ đổi sang JPEG khi được giữ lại.
  - In ra số ảnh đã mở và thời gian.
  - VietFood67 có 33.000 file nhãn. Bản cũ kiểm tra tới 4 lần xem ảnh có
    tồn tại không cho mỗi nhãn. Giờ notebook liệt kê thư mục ảnh một lần,
    còn file nhãn thì đọc song song.
  - Log in một dòng khi bắt đầu đọc mỗi bộ ảnh, kèm số giây. Trước đây log
    trống cho tới khi gom xong, nên không biết notebook đang chạy tới đâu.
  - Mỗi thư mục chỉ đọc một lần, theo đường dẫn thật. Kaggle có thể gắn một
    bộ ảnh vừa bằng symlink vừa bằng thư mục thật, nên bản cũ có thể đọc
    một bộ hai lần, hoặc đi mãi nếu có link vòng. Đã thử với một thư mục
    trỏ ngược về thư mục cha: notebook vẫn chạy xong.
  - Cách chia vẫn cố định theo seed. Thứ tự ảnh có đổi so với bản trước,
    nhưng lúc đó chưa có lần train thật nào nên không ảnh hưởng.
- **Đã thử trên máy:** dữ liệu giả, 2 thiết bị ảo, chạy trọn tới bước xuất
  file.

### 2026-10-19 · Notebook chạy được cả trên Google Colab
- **Vấn đề:** chạy thử trên Kaggle chạy gần 20 phút mà trang log vẫn trống.
  Trang log của Kaggle hiện rất chậm: lần chạy trước, các dòng in ở giây
  thứ 8 tới phút thứ 20 trở đi mới hiện. Vì vậy không biết notebook đang
  chạy hay đã kẹt. Nhóm quyết định chuyển sang Colab để xem log ngay lúc
  chạy.
- **Ô mới "On Google Colab"** (trên Kaggle thì tự bỏ qua):
  - Đọc key từ Secrets của Colab, nên key không nằm trong notebook.
    Notebook nhận token kiểu mới của Kaggle (`KAGGLE_API_TOKEN`, dạng
    `KGAT_...`) hoặc key cũ (`KAGGLE_USERNAME` + `KAGGLE_KEY`). Trước khi tải,
    notebook cập nhật `kagglehub`, vì token kiểu mới cần bản `kagglehub` gần
    đây.
  - Tải 4 bộ ảnh bằng `kagglehub` về ổ cứng của máy Colab, rồi tạo link
    `/content/datasets/<tên bộ>`. Tên nguồn ảnh vì vậy giống hệt trên Kaggle,
    và cách chia train/val/test không đổi.
  - Lưu kết quả lên Google Drive (`MyDrive/macrorunner_train`), để rớt kết
    nối không mất checkpoint.
  - In thời gian tải từng bộ và dung lượng ổ còn trống.
- **So với Kaggle:** Colab chỉ có 1 T4 và phải để mở tab. Bù lại, log hiện
  ngay và đọc ảnh từ ổ cứng của máy nhanh hơn. Notebook vẫn chạy được trên
  Kaggle như cũ.
- **Đã thử trên máy:** giả lập `google.colab` và `kagglehub`. Notebook đã:
  - tải đủ 4 bộ và đọc được key;
  - ghi 9 file kết quả vào thư mục Drive.
  Chạy lại kiểu Kaggle cũng vẫn chạy bình thường. Chưa chạy trên Colab
  thật.

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
- [x] Màn chụp ảnh, xác nhận món và thành phần, chỉnh khẩu phần (chạy
  với `NoModelRecognizer`).
- [ ] Gắn model thật: cài `FoodRecognizer` bằng `tflite_flutter`.
- [ ] Giai đoạn YOLO (tuần 5–7): gán khung, train, đếm số lượng.
- [ ] Mở rộng dữ liệu bài tập (đang 96/2918 bài, thiếu Beginner/Pro).
- [ ] Benchmark Branch & Bound so với greedy/vét cạn (số node, thời gian,
  độ lệch mục tiêu).
- [ ] Progressive Overload dựa vào lịch sử tập; biểu đồ tiến bộ từng bài.
- [x] Đổi `applicationId` sang `io.github.jimeavv.optifit`.
- [x] Tạo keystore release riêng, tự đăng APK lên GitHub Release.
- [ ] Chạy thử trên điện thoại thật: đổi ngôn ngữ, Nhật ký, ghi thực đơn.

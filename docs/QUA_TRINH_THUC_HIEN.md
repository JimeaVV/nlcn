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

### 2026-10-19 · So sánh 3 backbone để chọn model cho app
- **Kết quả chạy thử trên Colab** (`QUICK_TEST`, 12 ảnh mỗi món):
  - Chạy trọn từ đầu tới cuối, ghi đủ 9 file lên Drive.
  - Ảnh: 408 train / 102 val / 102 test. Nguồn: VietFood67 244, VinaFood21
    209, 30VNFoods 90, 20FoodVN 69.
  - Chỉ còn 3 món không có ảnh: cơm gà, phở gà, cháo gà (phải tự chụp).
  - Top-1 6,9%, F1 thành phần 0,44. Mới train 1 epoch nên các số này chỉ
    cho thấy notebook chạy đúng, chưa nói gì về độ chính xác.
- **Ba ứng viên** (cùng thí nghiệm `finetune`, cùng cách chia dữ liệu):
  MobileNetV3-Large, EfficientNetB0, EfficientNetV2-B0. Cả ba đều nhẹ, chạy
  được trên điện thoại. EfficientNetB0 là ứng viên mới thêm.
- **Cách chọn** (`tool/train/compare_results.py`):
  - Lấy model có val top-1 cao nhất. Tập test chỉ dùng để báo cáo, không
    dùng để chọn.
  - Nếu các model lệch nhau không quá 0,5 điểm % thì lấy model nhỏ hơn.
  - Bản chạy cũ chưa ghi val thì script lấy val từ log train. Đây là epoch
    tốt nhất của pha cuối, cũng là trọng số được giữ lại nhờ early
    stopping.
- **`results.json` ghi thêm:** val top-1, số tham số, dung lượng TFLite và
  thời gian chạy 1 ảnh trên CPU của máy train (chỉ để so tương đối).
- **Lỗi gặp khi thêm EfficientNetB0:** TFLite cho kết quả khác Keras.
  - Lúc xuất, notebook dựng lại một bản sao model không có trọng số
    ImageNet. Nhưng Keras chỉ thêm lớp chuẩn hóa ảnh đầu vào khi model được
    dựng có trọng số ImageNet, nên bản sao thiếu lớp này.
  - Đổi sang dựng bản sao từ config của chính model đã train. Vẫn lệch,
    vì `set_weights` chép mean/variance của lớp Normalization nhưng không
    áp dụng chúng.
  - Gọi thêm `finalize_state()` thì bản sao khớp tuyệt đối với model gốc.
    Notebook giờ kiểm tra bản sao khớp model gốc trước khi chuyển sang
    TFLite.
  - Lỗi này không ảnh hưởng MobileNetV3 hay EfficientNetV2-B0, vì hai model
    này không có lớp Normalization.
- **Đã thử trên máy** (dữ liệu giả, 2 thiết bị ảo): cả 3 backbone chạy trọn
  tới bước xuất TFLite.

  | Backbone | TFLite | CPU máy thử / ảnh |
  |---|---|---|
  | MobileNetV3 | 6,1 MB | 6,8 ms |
  | EfficientNetB0 | 8,3 MB | 17,8 ms |
  | EfficientNetV2-B0 | 12,0 MB | 21,6 ms |

### 2026-10-19 · Thu nhỏ ảnh một lần trước khi train
- **Vấn đề:** bản train thật MobileNetV3 trên Colab chạy khoảng 15 phút mỗi
  epoch, tức chừng 40 ảnh/giây.
  - Theo log trên Drive: chuẩn bị dữ liệu xong lúc 14:53, pha 1 (5 epoch)
    xong lúc 16:06. Val top-1 của pha 1 tăng từ 44,4% lên 50,6%.
  - Mỗi epoch phải giải nén lại ảnh gốc độ phân giải cao, mà Colab chỉ có 2
    nhân CPU. GPU phần lớn thời gian ngồi chờ. Cả 20 epoch có thể mất 4–6
    giờ.
- **Cách sửa:**
  - Ở bước lọc ảnh trùng (vốn đã mở từng ảnh), lưu luôn một bản JPEG thu
    nhỏ, cạnh ngắn 384 px. Lúc train chỉ đọc bản nhỏ này.
  - Có giảm độ chính xác không? Model chỉ nhìn ảnh 224×224, nên ảnh gốc
    to bao nhiêu cũng bị thu nhỏ trước khi vào model.
    - Bản đầu dùng 288 px: mảnh cắt nhỏ nhất (60%, tức 173 px) phải phóng
      to lên 224 px, nên hơi mờ hơn bản dùng ảnh gốc.
    - Đổi sang 384 px: mảnh nhỏ nhất là 230 px, vẫn lớn hơn 224 px. Mọi
      mảnh cắt đều chỉ thu nhỏ, không phóng to, nên không mất chi tiết.
    - Pillow thu nhỏ có khử răng cưa (antialias), còn `tf.image.resize`
      mặc định thì không. Nên ảnh 224 px tạo ra có thể còn sạch hơn trước.
    - Chưa đo trực tiếp ảnh hưởng tới độ chính xác.
  - Ảnh JPEG được giải nén thẳng ở kích thước nhỏ (`draft`).
  - Ảnh được xoay đúng chiều theo EXIF, giống cách app xử lý ảnh chụp.
  - Bản nhỏ là JPEG, nên không cần bước đổi WebP riêng nữa.
- **Cách chia dữ liệu không đổi:** hash và thứ tự giữ nguyên, nên tập
  train/val/test giống hệt bản trước. `splits.csv` vẫn ghi đường dẫn ảnh gốc.
- **Ảnh hưởng tới so sánh:** bản MobileNetV3 đang chạy dùng ảnh gốc, còn 2
  bản EfficientNet sẽ dùng ảnh thu nhỏ. Muốn so thật công bằng thì train lại
  MobileNetV3 bằng notebook mới, lần này nhanh hơn nhiều.
- **Đã thử trên máy:** dữ liệu giả, 2 thiết bị ảo. Chạy trọn tới bước xuất
  TFLite, cách chia giống hệt trước.

### 2026-10-19 · Kết quả train thật đầu tiên: MobileNetV3
- **Thiết lập:** Colab, 1 GPU T4, thí nghiệm `finetune`, ảnh thu nhỏ 384 px.
  - Ảnh: 38.677 train / 8.287 val / 8.287 test.
  - Train hết 44,6 phút, khoảng 2 phút mỗi epoch. Bản đọc ảnh gốc trước đó
    mất khoảng 15 phút mỗi epoch, nên thu nhỏ ảnh giúp nhanh khoảng 7 lần.
- **Kết quả:**

  | Chỉ số | Giá trị |
  |---|---|
  | Val top-1 | 67,8% |
  | Test top-1 | 67,4% |
  | Test top-3 | 82,5% |
  | F1 thành phần | 0,48 |
  | TFLite | 6,19 MB |

- **Theo từng món:**
  - Tốt: bánh mì chảo 96,7%, bánh hỏi 92%, há cảo 91,2%, bắp nướng 91,1%.
  - Yếu: bún riêu và bánh canh 44,4%, hủ tiếu 45,8%, cơm phần 46,7%, xôi và
    bún mắm 47,6%. Các món nước dạng sợi trông rất giống nhau.
  - Lớp `khac` chỉ đạt 39,3%: lớp này gom nhiều món khác hẳn nhau nên khó
    học.
- **Đường học:**
  - Pha 2 chạy đủ 15 epoch. Val top-1 gần như đứng yên khoảng 67–68% từ
    epoch thứ 9.
  - Train top-1 vẫn tăng lên 79%, còn val loss bắt đầu tăng: model đã bắt
    đầu học thuộc dữ liệu train (overfit). Train thêm epoch sẽ không giúp
    nhiều.
- **Cần xem lại khi nâng cấp:**
  - Ngưỡng tick thành phần được chỉnh xuống 0,3, đúng bằng mức thấp nhất
    của lưới thử. Nghĩa là xác suất thành phần model đưa ra đang thấp, và
    ngưỡng tốt nhất có thể còn thấp hơn 0,3.
  - Cơm gà, phở gà, cháo gà không có ảnh, nên model chưa nhận ra được.
  - Tập test chỉ gồm ảnh từ các bộ công khai. Với ảnh tự chụp bằng điện
    thoại, độ chính xác có thể thấp hơn (contract yêu cầu ít nhất 30% ảnh
    test là ảnh tự chụp).

### 2026-10-19 · Gắn model MobileNetV3 vào app để thử trên điện thoại
- Chép 4 file từ thư mục Drive `macrorunner_train/mobilenetv3_finetune` vào
  `assets/models/`: `food_v1.tflite` (6,19 MB), `dishes.txt` (52 món +
  `khac`), `components.txt` (25 thành phần), `MODEL_CARD.md`. Đây là model
  tạm. Khi so xong 3 backbone, model thắng sẽ thay vào.
- App tự đọc ngưỡng từ `MODEL_CARD.md`: tick sẵn từ 0,3, hỏi lại từ 0,15,
  chắc chắn về món từ 0,5.
- **Kiểm thử:** 150 test pass. Test "model đi kèm chỉ dùng mã có trong bảng
  dinh dưỡng" trước đây bị bỏ qua vì chưa có model, giờ đã chạy và pass.
- **APK:** build bản release arm64 (32,7 MB), build number 109. APK ký bằng
  khóa phát hành: SHA-256 khớp `RELEASE_CERT_SHA256` của CI. Vì vậy cài đè
  lên bản đang có được, không mất dữ liệu.

### 2026-10-19 · Thử quét thật: sửa lỗi tick dư thành phần
- **Thử trên điện thoại** (chụp ảnh một tô phở bò):
  - Đoán món đúng: phở bò 93%, tiếp theo là bún bò Huế 5%.
  - Nhưng app tick thêm 8 thành phần không có trong món: sườn nướng, bì,
    chả trứng, trứng ốp la, trứng kho, chả lụa, rau luộc, mỡ hành. Tổng ra
    1.692 kcal, trong khi tô phở thật khoảng 500 kcal.
- **Nguyên nhân:**
  - Model chưa học thành phần của phở. Nhãn thành phần chỉ có ở ảnh
    VietFood67, mà ảnh phở của bộ này đã bị bỏ (phở bò lẫn phở gà). Nên với
    ảnh phở, đầu ra thành phần không có nghĩa, xác suất lơ lửng quanh
    0,3–0,6.
  - Ngưỡng tick được chỉnh xuống 0,3. App tự tick cả thành phần nằm ngoài
    công thức món nếu xác suất từ ngưỡng này trở lên.
  - Thành phần thêm vào mặc định 100 g: mỡ hành 100 g là 583 kcal.
- **Sửa ở app** (`lib/models/scan_plate.dart`):
  - Thành phần ngoài công thức món **không bao giờ được tick sẵn**. Nó chỉ
    hiện ở dạng "Có thể" (chưa tick) khi xác suất từ 0,6 trở lên. Mốc 0,6 là
    ngưỡng mặc định của contract; model có chỉnh ngưỡng thấp hơn thì vẫn
    dùng 0,6. Ăn thiếu một món thì người dùng tự thêm được, còn cộng nhầm món
    không ăn thì làm sai tổng calo.
  - Thành phần thêm vào (do model gợi ý hoặc người dùng tự thêm) lấy khẩu
    phần thường gặp: trung vị khẩu phần của thành phần đó trong các món có
    nó. Ví dụ mỡ hành 10 g, bì 30 g, chả lụa 2 miếng. Thành phần không món
    nào có thì mới dùng 1 đơn vị hoặc 100 g.
  - Thành phần có trong công thức món vẫn tick theo ngưỡng của model như
    cũ.
- **Việc cho lần train sau:**
  - Gán nhãn "không có" theo công thức món. Ví dụ ảnh phở thì chắc chắn
    không có bì hay chả trứng. Như vậy ảnh nào cũng dạy được phần thành
    phần, không chỉ ảnh VietFood67.
  - Chọn ngưỡng tick theo độ chính xác (precision), thay vì theo F1.
- **Kiểm thử:** 151 test pass, có thêm test khẩu phần thường gặp và mốc
  0,6 cho thành phần ngoài công thức. Đã build lại APK, ký đúng khóa phát
  hành.

### 2026-10-19 · Chỉ tin phần thành phần ở món model đã học
- **Thử lại tô phở** sau bản sửa trước:
  - Đoán món: phở bò 99%.
  - Thịt bò lại bị bỏ tick, nên tổng chỉ còn 335 kcal và 11,5 g protein.
  - Model vẫn chắc trên 60% là có chả trứng, trứng, chả lụa, rau luộc, mỡ
    hành.
  - Kết luận: với phở, đầu ra thành phần không mang ý nghĩa gì, vì không
    ảnh phở nào có nhãn thành phần. Chỉnh ngưỡng cũng không sửa được.
- **Cách làm (contract v1.3, phần bổ sung):**
  - `MODEL_CARD.md` có thêm dòng `component_dishes: …`, liệt kê các món
    được tin phần thành phần.
  - Notebook tự tính danh sách này trên tập val. Món được chọn phải có ít
    nhất 20 ảnh có nhãn thành phần, và F1 thành phần đạt từ 0,7 trở lên.
    Danh sách được ghi vào thẻ model và `results.json`.
  - App chỉ dùng đầu ra thành phần cho các món trong danh sách. Món khác
    thì tick theo công thức món (như khi chưa có model) và không gợi ý
    thêm. Thẻ model không có dòng này thì không tin món nào.
  - Model MobileNetV3 đang đi kèm app có thẻ cũ, chưa có dòng này. Vì vậy
    app chỉ dùng model để đoán món; thành phần đi theo công thức. Tô phở
    giờ ra bánh phở, thịt bò, rau thơm, nước dùng.
- **Kiểm thử:**
  - 153 test pass. Có thêm test đọc `component_dishes` (cả dạng có gạch đầu
    dòng, dấu `` ` `` và CRLF) và test "món chưa học thì theo công thức".
  - Chạy notebook trên dữ liệu giả, nới giới hạn: danh sách ra đúng hai món
    có nhãn thành phần (cơm tấm, cơm phần).
  - Đã build lại APK.

### 2026-10-19 · Làm lại màn kết quả quét và thêm hiệu ứng
- **Vấn đề khi thử thật:**
  - Tổng calo và nút "Ghi vào nhật ký" nằm tận cuối danh sách, nên phải cuộn
    xuống mới thấy tổng thay đổi.
  - 6 dòng "Có thể có" chiếm gần hết màn hình.
  - Muốn chỉnh một tô lớn hơn thì phải bấm ± cho từng thành phần.
- **Màn kết quả quét:**
  - **Thanh tổng cố định ở đáy:**
    - tổng kcal và protein, số chạy dần tới giá trị mới;
    - dòng gram đạm / tinh bột / béo;
    - một thanh màu chia calo theo đạm, tinh bột, béo;
    - chọn bữa và nút ghi.
  - **Khẩu phần cả món:** các nút ×½, ×1, ×1½, ×2 nhân mọi thành phần cùng
    lúc. Thành phần người dùng đã chỉnh vẫn giữ đúng tỉ lệ. Thành phần thêm
    sau cũng được nhân theo.
  - **Gợi ý ngoài công thức được gom vào mục thu gọn** "Có thể có thêm (n)",
    kèm số món đã chọn. Thành phần trong công thức vẫn hiện như cũ, kể cả
    dòng "Có thể có".
- **Hiệu ứng:**
  - Trong lúc model nhận diện, một vạch neon quét dọc ảnh. Hiệu ứng viết
    bằng fragment shader của Flutter (`shaders/scan_sweep.frag`) và lấy màu
    theo giao diện đang dùng.
    - Máy nào không nạp được shader thì dùng một dải màu chuyển thay thế.
    - Điện thoại bật "giảm chuyển động" thì vạch đứng yên.
  - Thẻ món và thẻ thành phần trượt lên lần lượt khi hiện ra.
  - Rung nhẹ khi:
    - bấm chụp;
    - nhận diện xong;
    - chọn món, tick thành phần, đổi khẩu phần;
    - ghi xong.
- **Kiểm thử:**
  - 157 test pass. Có thêm test mục gợi ý thu gọn, khẩu phần ×2 (tổng gấp
    đôi, rau thêm sau cũng gấp đôi), và test hiệu ứng quét đứng yên khi tắt
    chuyển động.
  - APK build được, shader được biên dịch và đóng gói vào APK.
  - Chưa xem hiệu ứng trên điện thoại thật.

### 2026-10-20 · Giảm dung lượng APK từ 32,8 MB xuống 17,2 MB
- **Đo các file lớn trong APK arm64:**

  | File | Dung lượng |
  |---|---|
  | `libflutter.so` | 11,6 MB |
  | `libapp.so` | 8,3 MB |
  | `food_v1.tflite` | 6,2 MB |
  | `libtensorflowlite_jni.so` (LiteRT) | 4,3 MB |
  | `libtensorflowlite_gpu_jni.so` | 2,5 MB |

  Các thư viện native được lưu không nén.
- **Cách sửa** (`android/app/build.gradle.kts`):
  - **Bỏ thư viện GPU của LiteRT.** App chạy model trên CPU. Gói
    `tflite_flutter` chỉ mở thư viện này khi tạo `GpuDelegate`, mà app không
    bao giờ tạo.
  - **Nén thư viện native trong APK** (`useLegacyPackaging`). File APK để
    tải và gửi nhỏ hơn; Android giải nén một lần khi cài. Đổi lại, app chiếm
    nhiều chỗ hơn một chút sau khi cài.
- **Kết quả:** APK arm64 giảm từ 32,8 MB xuống 17,2 MB, vẫn ký đúng khóa phát
  hành. Giờ gửi được qua Zalo hay Telegram.
- **Còn giảm thêm được:** lượng tử hóa model sang int8 (khoảng 6,2 xuống
  3 MB). Việc này cần xuất lại từ checkpoint và đo lại độ chính xác, nên làm
  sau khi chọn được model thắng.

### 2026-10-20 · Khung ngắm lệch so với ảnh chụp
- **Vấn đề khi thử thật:** canh món vào khung ngắm rồi chụp, nhưng trong
  ảnh chụp món lại lệch so với lúc canh.
- **Nguyên nhân:** khung ngắm được đặt cao hơn tâm màn hình, khoảng 7% chiều
  cao (`Alignment(0, -0.15)`). Trong khi đó ảnh xem trước luôn canh giữa, nên
  tâm ảnh chụp nằm thấp hơn khung. Model chỉ đọc hình vuông chính giữa ảnh,
  nên món canh trong khung có thể bị cắt mất một phần.
- **Cách sửa:** đặt khung đúng tâm màn hình, trùng với tâm ảnh chụp và tâm
  hình vuông model đọc.
- **Kiểm thử:** thêm test kiểm tra tâm khung trùng tâm ảnh xem trước. Test
  này fail với bố cục cũ và pass với bố cục mới. Đã build lại APK và cài lên
  điện thoại qua adb.

### 2026-10-20 · Rung và vạch quét chưa thấy khi thử thật
- **Vạch quét:** chỉ hiện trong lúc model đang chạy. Trên điện thoại, model
  trả lời chưa tới nửa giây, còn shader cần thời gian nạp lần đầu, nên vạch
  gần như không kịp hiện.
  - Sửa: vạch luôn chạy đủ một lượt, 1,4 giây. Kết quả vẫn hiện ngay bên
    dưới, không phải chờ.
  - Shader được nạp sẵn từ lúc mở camera.
- **Rung:** điện thoại thử là Xiaomi, đã bật rung khi chạm
  (`haptic_feedback_enabled=1`). Nhưng `selectionClick` ứng với
  `CLOCK_TICK`, mà nhiều máy Android không rung với kiểu này.
  - Gom các kiểu rung vào `lib/core/haptics.dart`:
    - tick hoặc chọn: `lightImpact` (VIRTUAL_KEY);
    - nhận ra món: `mediumImpact`;
    - bấm chụp và ghi xong: `vibrate` (LONG_PRESS), kiểu máy Android nào
      cũng rung.
- **Kiểm thử:** 158 test pass, có thêm test "model trả lời ngay mà vạch quét
  vẫn chạy đủ một lượt". Đã build và cài lên điện thoại qua adb.

### 2026-10-20 · So sánh 3 backbone: EfficientNetB0 thắng
- **Thiết lập:**
  - Cả 4 bản chạy dùng cùng notebook (ảnh thu nhỏ 384 px), cùng thí nghiệm
    `finetune`, cùng cách chia dữ liệu (38.677 train / 8.287 val / 8.287
    test). Đều train trên Colab, 1 GPU T4.
  - Người A train MobileNetV3. Người B train EfficientNetB0,
    EfficientNetV2-B0, và một bản MobileNetV3 nữa.
- **Kết quả** (`tool/train/compare_results.py`):

  | Backbone | Val top-1 | Test top-1 | Test top-3 | F1 thành phần | TFLite | CPU Colab / ảnh | Train |
  |---|---|---|---|---|---|---|---|
  | **EfficientNetB0 (chọn)** | **69,0%** | **68,8%** | **83,9%** | 0,497 | 8,3 MB | 21,9 ms | 55 phút |
  | EfficientNetV2-B0 | 68,5% | 68,5% | 83,1% | 0,504 | 12,0 MB | 27,8 ms | 53 phút |
  | MobileNetV3 (người A) | 67,8% | 67,4% | 82,5% | 0,482 | 6,2 MB | 11,4 ms | 45 phút |
  | MobileNetV3 (người B) | 67,7% | 67,1% | 82,2% | 0,482 | 6,2 MB | 8,3 ms | 53 phút |

- **Nhận xét:**
  - Hai lần train MobileNetV3 độc lập chỉ lệch nhau 0,1 điểm % (val). Nên
    khoảng cách 1,1 điểm % giữa EfficientNetB0 và MobileNetV3 lớn hơn nhiều
    so với độ dao động giữa các lần chạy.
  - EfficientNetB0 hơn EfficientNetV2-B0 0,5 điểm %, file nhỏ hơn
    (8,3 so với 12 MB) và nhanh hơn. Theo luật chọn đã chốt, EfficientNetB0
    thắng.
  - Đổi lại, EfficientNetB0 chạy chậm gấp khoảng 2 lần MobileNetV3, file
    nặng hơn 2,1 MB.
  - Theo từng món, EfficientNetB0 tốt hơn rõ ở bún chả (66,7% so với
    52,9%), hủ tiếu (58,2% so với 45,8%), xôi, bún riêu, bánh khọt. Nhưng
    **cơm phần giảm từ 46,7% xuống 35,1%**, trong khi đây là món cơm nhà quan
    trọng. Bò kho và bún bò Huế cũng giảm.
  - Lớp `khac` của cả ba backbone đều chỉ khoảng 37–39%.
  - Ngưỡng tick thành phần của cả ba đều bị chỉnh xuống mức thấp nhất của
    lưới thử (0,3).
- **Việc tiếp theo:** đưa EfficientNetB0 vào app, rồi nâng cấp contract
  1.4:
  - gán nhãn "không có" theo công thức món;
  - chọn ngưỡng tick theo precision;
  - thêm ảnh tự chụp, nhất là cơm phần, cơm gà, phở gà, cháo gà.

### 2026-10-20 · Đưa EfficientNetB0 vào app
- Thay 4 file trong `assets/models/` bằng bản EfficientNetB0 của người B
  (Drive `macrorunner_train/efficientnetb0_finetune`).
  - Danh sách món và thành phần giống hệt model cũ (52 món + `khac`, 25
    thành phần).
  - Đã kiểm tra bằng LiteRT: đầu vào `[1, 224, 224, 3]`, hai đầu ra 53 và
    25, xác suất món cộng lại bằng 1.
- Thẻ model được train trước khi có dòng `component_dishes`, nên app chỉ
  dùng model này để đoán món. Thành phần đi theo công thức món.
- 158 test pass. APK arm64 tăng từ 17,2 MB lên 19,3 MB vì model nặng hơn
  2,1 MB. APK vẫn ký đúng khóa phát hành, đã cài lên điện thoại qua adb.

### 2026-10-20 · Notebook đo TTA (xem một ảnh theo nhiều góc)
- **Ý tưởng:** EfficientNetB0 chạy 22 ms một ảnh trên CPU của Colab, còn
  nhóm chấp nhận tới khoảng 1 giây mỗi lần quét. Vì vậy có thể đổi thời gian
  lấy độ chính xác: chạy model trên vài cách xem của cùng một ảnh, rồi lấy
  trung bình xác suất.
- **`tool/train/evaluate_tta.ipynb`:**
  - Nạp checkpoint của một lần train, chạy lại đúng tập test trong
    `splits.csv`. Ảnh được thu nhỏ y như notebook train.
  - So 4 cách xem: ảnh gốc, lật ngang, mảnh 80% ở giữa, mảnh 80% lật ngang.
    Đây là các cách xem app làm được dễ dàng từ một ảnh.
  - Không train lại.
- `make_notebook.py` nhận thêm tên file nguồn, để build được notebook khác
  ngoài notebook train.
- **Đã thử trên máy** (dữ liệu giả): dòng "ảnh như hiện tại" ra đúng test
  top-1 của lần train (56,25%), nghĩa là cách xử lý ảnh khớp với lúc train.
  Kết quả thật phải chạy trên Colab với checkpoint EfficientNetB0.
- **Lần chạy đầu trên Colab báo "0 of 8287 test photos":** không tìm thấy
  ảnh nào theo đường dẫn trong `splits.csv`.
  - Sửa: notebook tìm lại từng ảnh theo tên bộ ảnh dưới thư mục dữ liệu của
    phiên hiện tại. Cách này chạy đúng cả khi lần train chạy trên Kaggle
    hoặc ở một phiên Colab khác.
  - Link cũ trỏ vào cache đã bị xóa thì được tạo lại.
  - Nếu vẫn thiếu ảnh, notebook in ra ảnh bị thiếu và nội dung các thư mục
    dữ liệu. Không thấy ảnh nào thì dừng với thông báo rõ ràng, thay vì lỗi
    TensorFlow khó hiểu.
  - Đã thử với đường dẫn kiểu Kaggle trên dữ liệu giả: vẫn ra đúng 56,25%.

### 2026-10-20 · Đo thời gian nhận diện trên điện thoại
- **Vấn đề:** người B nghe nói EfficientNetB0 chạy hơi lag trên máy yếu.
  Đọc code thì thấy hai chỗ có thể chậm hơn cả model:
  - Bước chuẩn bị ảnh giải nén nguyên tấm ảnh chụp bằng Dart thuần, rồi mới
    thu nhỏ về 224×224. Theo ghi chú trong code, bước này mất 1–2 giây, và
    không phụ thuộc model nào.
  - Interpreter LiteRT chạy với mặc định 1 luồng.
- **Cách làm:** đo trước, sửa sau.
  - App đo thời gian chuẩn bị ảnh và thời gian chạy model. Kết quả in vào
    log (`Scan timing: …`) và hiện một dòng nhỏ trên màn kết quả quét, ví dụ
    "Nhận diện trong 0,82 s (ảnh 0,64 s · model 0,18 s)". Nhờ vậy máy của
    người B cũng đo được mà không cần adb.
    - Lần quét đầu tiên, thời gian model gồm cả lúc mở interpreter.
  - Bật đa luồng cho model: dùng số nhân CPU, tối đa 4 luồng.
- **Kiểm thử:** 159 test pass. Đã cài lên điện thoại thử (Xiaomi, 8 nhân)
  để đo.

### 2026-10-20 · Màn kết quả quét bị giật khi đổi món
- **Phân tích video quay màn hình** (4,6 giây, khoảng 31 khung/giây): khoảng
  cách giữa các khung đều 32 ms, tức là không rớt khung. Cái "giật" là do bố
  cục nhảy:
  - Chip món đang chọn có dấu ✓ nên rộng ra, làm hàng chip xếp lại dòng.
  - Danh sách thành phần đổi tức thì (Há cảo 1 dòng, Bò lá lốt 3 dòng), nên
    mọi thứ bên dưới bị đẩy đi trong một khung hình.
  - Số kcal chạy 380 ms đúng lúc bố cục đang nhảy.
- **Cách sửa:**
  - Bỏ dấu ✓ trên chip món và chip khẩu phần; chip đang chọn vẫn được tô màu.
  - Khi đổi món, danh sách thành phần mờ dần sang danh sách mới (180 ms), và
    chiều cao đổi từ từ (220 ms).
  - Số kcal chạy nhanh hơn: 260 ms thay vì 380 ms.
- **Kiểm thử:** 159 test pass. Đã cài lên điện thoại thử.
  - Log `Scan timing` không đọc được qua adb trên máy Xiaomi này (có thể máy
    chặn log của app bản release), nên dùng dòng thời gian hiện trên màn
    hình.

### 2026-10-20 · Thời gian nhận diện đo trên điện thoại; camera 1080p
- **Số đo trên máy thử** (Xiaomi, 8 nhân, EfficientNetB0, 4 luồng, ảnh 720p):

  | Lần quét | Tổng | Chuẩn bị ảnh | Model |
  |---|---|---|---|
  | 1 | 0,14 s | 0,09 s | 0,05 s |
  | 2 | 0,16 s | 0,12 s | 0,04 s |
  | 3 | 0,15 s | 0,12 s | 0,03 s |

  - Model chỉ mất 30–50 ms. Chuyện "B0 lag trên máy yếu" không đến từ model
    trên máy này. Máy yếu cần đo riêng bằng dòng thời gian trên màn hình.
  - Một ảnh chụp lại màn hình (tô bún bò Huế) bị đoán sai, xác suất cao nhất
    chỉ 16%. App đúng là đã hỏi lại người dùng. Ảnh chụp màn hình có vân
    sọc và màu lệch, nên không đại diện cho ảnh món ăn thật.
- **Camera mờ:** `ResolutionPreset.high` trên Android chỉ là 720p, và app chưa
  có chạm để lấy nét.
  - Đổi sang 1080p (`veryHigh`). Model chỉ đọc 224×224, nên độ phân giải cao
    hơn nữa cũng không giúp gì. Bước chuẩn bị ảnh sẽ lâu hơn một chút, cần
    đo lại.
  - Chạm vào ảnh xem trước để lấy nét và đo sáng tại chỗ chạm, có vòng tròn
    báo vị trí. Vị trí chạm được đổi ngược từ ảnh đã bị cắt (BoxFit.cover)
    về toạ độ của ảnh xem trước gốc.
  - Khung ngắm trước đây nuốt mất lượt chạm ở giữa màn hình, đúng chỗ đặt
    món. Đã cho khung bỏ qua chạm.
- **Kiểm thử:** 159 test pass. Có thêm test chạm giữa ảnh xem trước thì
  camera lấy nét đúng tâm (0,5; 0,5). Đã cài lên điện thoại thử.

### 2026-10-20 · Contract v1.4: thêm 13 món đã có ảnh
- **Quyết định của nhóm:** không làm thêm thí nghiệm nữa. Chốt train một
  model EfficientNetB3 thật kỹ. Trước khi train thì thêm món.
- **Món nào thêm được:** chỉ món đã có ảnh trong 4 bộ công khai. Đọc
  `splits.csv` của lần train EfficientNetB0 thì thấy các lớp đang bị gom vào
  `khac`:
  - 30VNFoods: bánh tráng nướng, bánh giò, bánh bột lọc, bánh đúc, nem chua,
    bánh pía;
  - 20FoodVN: bún cá, gỏi ngó sen;
  - khung VietFood67: bún chả cá, nộm hoa chuối, nui xào bò, súp cua, khoai
    tây chiên, salad, hamburger, lẩu.

  Thêm 13 món (53–65). `khac` giữ lại lẩu (món ăn chung nồi, không tính được
  khẩu phần một người) và gỏi ngó sen. Bún cá gộp ảnh bún cá của 20FoodVN
  và bún chả cá của VietFood67.
  - Đồng thời thấy 25/52 món đang bị chặn ở mức 1.500 ảnh, nên lần train
    sau sẽ nâng giới hạn này.
- **Số liệu dinh dưỡng:**
  - Lấy thẳng từ bảng Viện Dinh dưỡng: bánh giò (15017), bánh bột lọc
    (15003), bánh đúc (15014 bánh đúc nóng; bánh đúc nguội 15013 là 88
    kcal), nem chua (7073).
  - Lấy thẳng từ USDA: khoai tây chiên (FNDDS 2709461; 1 phần vừa 117 g theo
    SR 170698), hamburger (FNDDS 2706920, 1 cái 145 g).
  - Tính theo công thức, có ghi là ước lượng (kcal/100 g): bánh tráng nướng
    389, bánh pía 377, nước dùng và chả cá 51,7, salad có 15 g mayonnaise
    85,5, nui xào (chưa có bò) 159, súp cua 34,9, nộm hoa chuối 85,5.
  - Không dùng số "Nui, luộc" của Viện (371 kcal/100 g): đó là số của nui
    khô. Dùng số nui đã nấu của USDA (SR 169737, 158 kcal).
  - Đơn vị do nhóm ước lượng: bánh giò 150 g, bánh bột lọc 15 g, nem chua
    25 g, bánh tráng nướng 70 g, bánh pía 100 g một cái.
- **Gợi ý thực đơn:** gắn tag cho 13 món. Nem chua, salad, súp cua, nộm hoa
  chuối dùng được khi giảm cân; khoai tây chiên và bánh pía chỉ dùng khi tăng
  cân. Đo lại chất lượng thực đơn: không đổi (giảm cân 100/150, giữ cân và
  tăng cân 150/150).
- **Kiểm thử:** `check_vn_food.py` OK (84/84 thành phần có số liệu), 159
  test pass (bảng món giờ có 65 món).

### 2026-10-20 · Notebook train EfficientNetB3 ("full") và app đọc kích thước ảnh từ model
- **Vì sao B3:** trong nhóm EfficientNet, B3 (ảnh 300 px, 12 triệu tham số,
  ImageNet 81,6%) là model lớn nhất còn chạy được trên điện thoại. Ước tính
  khoảng 150–250 ms trên máy thử, suy từ 30–50 ms đo thật của B0. B7 (ảnh
  600 px, 66 triệu tham số) bị loại: file khoảng 130 MB, máy yếu mất cả chục
  giây, mà train 20 epoch trên Kaggle 2×T4 mất 8–13 giờ, sát giới hạn 12 giờ
  mỗi phiên.
- **Vì sao đổi cách train:** đường học của B0 cho thấy train top-1 chỉ 78%,
  val 69%. Model chưa học hết dữ liệu train (chỉ mở 40% lớp, learning rate
  cố định, 15 epoch), chứ chưa phải học thuộc.
- **Notebook (`RECIPE = 'full'`):**
  - mở băng toàn bộ backbone;
  - learning rate khởi động rồi giảm theo cosine; AdamW; label smoothing 0,1;
  - 3 + 30 epoch, dừng sớm sau 6 epoch không tiến bộ;
  - tối đa 4.000 ảnh mỗi món; món ít ảnh được lặp lại cho đủ 300 ảnh train;
  - nhãn "không có" theo công thức món, cho mọi ảnh;
  - ngưỡng tick theo precision ≥ 85%;
  - mixed precision;
  - ảnh thu nhỏ 512 px;
  - xuất thêm bản int8.
- **VietFood67:** khoai tây chiên và salad là món phụ. Ảnh hamburger kèm
  khoai tây chiên tính là hamburger; ảnh cơm kèm salad vẫn tính là cơm phần.
  Chỉ khi ảnh chỉ có khoai tây chiên hoặc chỉ có salad thì mới tính là món
  đó.
- **Xuất model khi train bằng mixed precision:** bản sao để chuyển sang
  TFLite được dựng lại ở float32, bằng cách đổi kiểu `mixed_float16` trong
  config của từng lớp. Khi đó Keras và TFLite cho kết quả lệch nhau dưới
  0,02.
- **App:** kích thước ảnh vào giờ đọc từ file `.tflite`. Model phải nhận ảnh
  vuông float32 `[1, N, N, 3]`. App mở interpreter trước, rồi mới chuẩn bị
  ảnh theo N. Contract mục 6 đã sửa theo.
- **`check_vn_food.py`** kiểm tra thêm `DISHES` và `DISH_PARTS` trong
  notebook có khớp bảng dữ liệu không.
- **Notebook TTA:** đọc kích thước ảnh từ checkpoint và thu nhỏ ảnh đúng như
  lần train.
- **Kiểm thử:**
  - Chạy B3 trên dữ liệu giả với 2 thiết bị ảo và mixed precision: chạy trọn
    tới bước xuất file; float16 21,8 MB, int8 11,9 MB.
  - Notebook TTA với checkpoint B3: dòng "ảnh như hiện tại" khớp test top-1.
  - 160 test pass. Có thêm test chuẩn bị ảnh cho model 300×300.

### 2026-10-20 · Kết quả TTA của EfficientNetB0
- Chạy `evaluate_tta.ipynb` trên Kaggle với checkpoint EfficientNetB0, cùng
  8.287 ảnh test của lần train:

  | Cách xem | Số lần chạy model | Top-1 | Top-3 | So với hiện tại |
  |---|---|---|---|---|
  | Ảnh gốc (app đang dùng) | 1 | 68,84% | 83,93% | — |
  | Ảnh gốc + lật ngang | 2 | 68,96% | 84,06% | +0,12 |
  | Ảnh gốc + mảnh 80% ở giữa | 2 | 69,63% | 84,31% | +0,79 |
  | Cả 4 cách | 4 | 69,82% | 84,46% | +0,98 |

- **Nhận xét:**
  - Dòng đầu khớp test top-1 của lần train (68,84%), tức notebook xử lý
    ảnh đúng y như lúc train.
  - Lật ngang gần như không giúp, vì lúc train đã lật ngang ngẫu nhiên.
  - Nhìn gần hơn (mảnh 80% ở giữa) giúp nhiều nhất. Model thấy rõ món hơn,
    bớt nền.
  - Hai cách xem (ảnh gốc + nhìn gần) được 80% lợi ích của cả 4 cách, mà
    chỉ tốn nửa thời gian.
  - Có món tăng rõ: cà ri +5,5, canh chua +5,0, cơm tấm +4,9, bò kho +2,6
    điểm %. Cơm phần lại giảm nhẹ (35,1% xuống 32,9%), vì đĩa cơm phần bày
    nhiều món tới tận mép đĩa.
- **Quyết định:** đưa TTA vào app theo từng model, đọc từ một dòng trong
  thẻ model (ví dụ `tta_views: photo, closer`). Mức lợi trên EfficientNetB3
  có thể khác B0, nên cần đo lại khi B3 train xong.

### 2026-10-20 · Notebook train được mọi EfficientNet B0–B7
- Chỉ cần đổi `BACKBONE = 'efficientnetbN'`. Notebook tự lấy kích thước ảnh
  vào gốc của model đó (B0 224, B1 240, B2 260, B3 300, B4 380, B5 456, B6
  528, B7 600). Ảnh thu nhỏ cũng tự lớn theo để mảnh cắt 60% vẫn đủ: B1
  416 px, B2 448 px, B3 512 px.
- Đã thử B2 trên dữ liệu giả: chạy trọn tới bước xuất file, ảnh vào 260×260,
  float16 15,7 MB, int8 8,7 MB.

### 2026-10-20 · Bản QUICK của B3 trên Kaggle chạy 2 giờ chưa xong
- Bản QUICK lẽ ra chỉ mất tối đa khoảng 1 giờ 15 phút. Trang log của Kaggle
  hiện trễ, nên không biết notebook đang kẹt ở bước nào.
- **Nghi vấn chính:** chế độ 2 GPU (MirroredStrategy) chưa từng chạy trên 2 GPU
  thật. Các lần train trước đều trên Colab 1 GPU, còn lần thử trên máy dùng 2
  thiết bị CPU ảo. Bước đồng bộ gradient mặc định (NCCL) có lúc bị treo ngay
  bước train đầu tiên trên Kaggle T4×2.
- **Cách sửa:**
  - Khi có từ 2 GPU, đồng bộ bằng `HierarchicalCopyAllReduce`: chép gradient
    qua bộ nhớ máy chủ, chậm hơn một chút nhưng không bị treo.
  - Thêm dòng log có mốc thời gian ở từng bước: ảnh sẵn sàng, xong bước train
    đầu tiên, xong từng epoch, đánh giá, chuyển sang TFLite float16, chuyển
    sang int8, đo hai file TFLite. Lần sau nhìn dòng cuối là biết kẹt ở đâu.
- Đã thử trên dữ liệu giả với 2 thiết bị ảo: đủ các mốc, chạy xong trong 3
  phút.
- **Log của bản chạy nền trên Kaggle trễ rất nhiều:** chạy được 7.400 giây mà
  log mới hiện tới giây thứ 22, dòng `reading vietfood68`. Vì vậy không biết
  notebook kẹt ở bước đọc 33.000 file nhãn VietFood67 trên ổ mạng hay chỉ là
  log hiện chậm.
  - Bước đọc VietFood67 in thêm tiến độ: liệt kê nhãn xong, liệt kê ảnh xong,
    và cứ mỗi 5.000 nhãn lại in một dòng.
  - Bản QUICK chỉ đọc 1/10 số nhãn, vẫn đủ 12 ảnh mỗi món.
  - Theo dõi bằng phiên tương tác trong trình soạn notebook của Kaggle: kết
    quả hiện ngay dưới từng ô, không bị trễ như trang log.

### 2026-10-20 · Train tiếp được khi Colab ngắt phiên, sửa lỗi dừng ở epoch 2
- Kết quả bản QUICK của B3 trên Kaggle (bản trước khi sửa phần đọc nhãn):
  chạy hết 64 phút, trong đó 57 phút chỉ để đọc nhãn VietFood67 trên ổ mạng.
  Phần train chỉ mất 4 phút. Chuyển sang int8 và float16 đều chạy được.
  - File float16 nặng 21,8 MB, chạy 89 ms một ảnh trên CPU của Kaggle.
  - File int8 nặng 11,9 MB.
  - Top-1 trên mẫu test là 0,203 (int8) so với 0,234 (float16). Đây là bản
    QUICK (512 ảnh, 1 epoch) nên chỉ cho biết các bước chạy được, không nói
    gì về độ chính xác thật.
- Ba món chưa có ảnh nào: `com_ga`, `pho_ga`, `chao`.
- Thử train 3 epoch fine-tune trên máy thì gặp lỗi `AlreadyExistsError ...
  ArithmeticOptimizer/AddOpsRewrite ... tmp_var` ở đầu epoch thứ 2.
  - Bản đã commit trước đó cũng bị, nên đây là lỗi có sẵn của cách train
    `full` chứ không phải do phần chạy tiếp.
  - Các lần chạy trước không thấy lỗi vì bản QUICK chỉ có 1 epoch fine-tune,
    còn bản FULL của B3 chưa chạy lần nào. Nếu không sửa, bản FULL sẽ dừng
    ngay sau epoch fine-tune đầu tiên.
  - Sửa: tắt bước `arithmetic_optimization` của Grappler. Sau khi sửa, chạy
    đủ 3 epoch cả trên 1 thiết bị lẫn 2 thiết bị (giả lập 2 T4).
- Chạy tiếp khi bị ngắt phiên: bản FULL của B3 ước tính 7–8 giờ, dễ bị Colab
  ngắt giữa chừng.
  - Mỗi epoch lưu `last.keras` (model kèm optimizer và lịch learning rate)
    và `progress.json` vào thư mục kết quả trên Drive.
  - Chạy lại notebook với cùng backbone, cách train và `QUICK_TEST` thì nó
    nạp `last.keras` và train tiếp từ epoch kế tiếp.
  - `checkpoint.keras` vẫn giữ epoch tốt nhất của cả quá trình, kể cả qua
    nhiều lần chạy tiếp. Khi train xong, model lấy lại trọng số của epoch đó
    rồi mới đánh giá và xuất TFLite.
  - Đã thử: cố ý dừng sau epoch 2, chạy lại thì nó báo "resuming fine-tuning
    after epoch 2 (best val 0.833)", train epoch 3, và `training_log_fine.csv`
    nối đủ 3 dòng.
- Dòng "first training step done" chỉ in ở epoch đầu mỗi giai đoạn thay vì
  mọi epoch.

### 2026-10-20 · Train B3 FULL trên Kaggle: tự dừng trước 12 giờ, version sau train tiếp
- Bản QUICK chạy thành công trên Kaggle nên bản FULL của B3 cũng chạy trên
  Kaggle (2 GPU T4).
- Kaggle dừng mỗi lần chạy ở 12 giờ và có thể không giữ file nào. Bản FULL
  ước tính 7–8 giờ train, cộng khoảng 1–1,5 giờ đọc ảnh, nên khá sát giới hạn.
- Giới hạn thời gian: trên Kaggle `TIME_LIMIT_HOURS = 11`.
  - Sau mỗi epoch fine-tune, notebook ước lượng epoch kế tiếp có xong trước
    mốc 11 giờ trừ 30 phút hay không. Nếu không, nó dừng train.
  - Phần còn lại vẫn chạy: đánh giá, xuất float16 và int8 từ epoch tốt nhất.
  - `results.json` ghi `finished: false` và số epoch đã xong; `MODEL_CARD.md`
    ghi "DỪNG VÌ HẾT GIỜ".
  - Trên Colab mặc định không giới hạn, vì Colab đã chạy tiếp được qua Drive.
- Chạy tiếp trên Kaggle: mỗi version bắt đầu với `/kaggle/working` trống.
  - Thêm output của version trước làm dữ liệu (Add Input → Your Work →
    Notebooks).
  - Notebook tìm `progress.json` ở tối đa 3 tầng thư mục trong
    `/kaggle/input`, không tìm sâu hơn vì đó là các bộ ảnh rất nhiều file.
  - Nó chép `last.keras`, `checkpoint.keras`, `progress.json` và hai file log
    sang thư mục làm việc rồi train tiếp. Thời gian train được cộng dồn qua
    các lần chạy.
- Đã thử trên máy, giả lập Kaggle:
  - Lần 1 dừng vì hết giờ sau epoch 1 và vẫn xuất đủ file.
  - Lần 2 dùng thư mục output trống, chỉ có output lần 1 làm dữ liệu. Nó báo
    "Previous run found", train tiếp epoch 2–3 và `finished: true`.

### 2026-10-20 · B3 FULL chuyển sang Colab, chia thành nhiều phiên 5 giờ
- Lượt FULL đầu tiên trên Kaggle đọc nhãn VietFood67 quá chậm: khoảng 9 phút
  cho 5.000 nhãn, tức khoảng 5 giờ cho cả 171.619 nhãn. Lần QUICK trước, đọc
  đủ số nhãn đó chỉ mất 56 phút, nên chậm là do ổ dữ liệu của Kaggle hôm đó.
  - Ước tính phải đến khoảng giờ thứ 8 mới bắt đầu train, chỉ kịp vài epoch
    trước mốc 11 giờ.
  - Version sau lại phải đọc dữ liệu từ đầu.
  - Vì vậy dừng lượt đó và chuyển sang Colab, nơi dữ liệu nằm trên ổ cục bộ.
- Colab miễn phí chỉ cho mỗi phiên khoảng 5 giờ, còn B3 cần 7–8 giờ train,
  nên phải chạy 2–3 phiên.
  - Trên Colab `TIME_LIMIT_HOURS = 4.75`. Train dừng khi epoch kế tiếp có
    thể vượt mốc đó trừ 20 phút. Notebook vẫn đánh giá và xuất model tốt
    nhất, rồi phiên sau chạy tiếp.
  - Lưu model an toàn: `last.keras`, `checkpoint.keras` và `progress.json`
    được ghi ra file tạm rồi mới đổi tên. Nếu phiên bị cắt đúng lúc đang ghi,
    file cũ vẫn còn nguyên.
  - Cuối notebook gọi `drive.flush_and_unmount()`, chờ mọi file lên hết Drive.
  - Định dạng `progress.json` giữ nguyên, nên phiên đang chạy bằng notebook
    trước đó vẫn chạy tiếp được bằng notebook mới.
- Đã thử trên máy, giả lập 3 phiên:
  - Phiên 1 bị cắt ngang sau epoch 1.
  - Phiên 2 chạy tiếp, dừng vì hết giờ sau epoch 2 và vẫn xuất file
    (`finished: false`).
  - Phiên 3 chạy tiếp epoch 3 và báo `finished: true`. Thời gian train cộng
    dồn được 2,7 phút.

### 2026-10-20 · Hướng dẫn và công cụ cho Claude Code trong repo
- Mục đích: những quy tắc và lệnh hay dùng trước đây chỉ nằm trong bộ nhớ
  của Claude trên máy Người A. Đưa chúng vào repo để Người B dùng Claude
  cũng theo cùng quy tắc.
- `CLAUDE.md`: Claude đọc file này mỗi khi mở phiên trong repo. Nội dung:
  cấu trúc dự án, các lệnh CI chạy, và các quy tắc:
  - ghi nhật ký này;
  - commit không ghi Claude là đồng tác giả, chỉ push khi được bảo;
  - không đụng tới keystore;
  - số liệu dinh dưỡng phải có nguồn;
  - đổi contract thì cập nhật đủ 4 nơi.
- `CLAUDE.local.md`: đường dẫn Flutter, Android SDK, điện thoại test và mã
  chứng chỉ của máy Người A. File này nằm trong `.gitignore` cùng
  `.claude/settings.local.json`.
- Skill `/build-apk`:
  - các bước build APK arm64, chọn build number lớn hơn bản đang cài,
    kiểm tra chữ ký release, đặt tên `MacroRunner-<model>-arm64.apk`;
  - chỉ người dùng gọi được, vì nó cài app lên điện thoại.
- Skill `train-notebook`: quy trình sửa notebook, gồm sửa file `.py`, sinh
  lại `.ipynb`, thử nhanh, và tạo bản QUICK hoặc FULL gửi lên Kaggle hoặc
  Colab.
- Agent `model-contract-reviewer`:
  - chỉ đọc; so contract, notebook, code app đọc model, các CSV dinh dưỡng
    và model đang dùng;
  - báo chỗ lệch cùng hậu quả khi app chạy (ví dụ lệch thứ tự `dishes.txt`
    làm app hiện sai tên món).
- Thử nhanh notebook (`tool/train/test/`): các script trước nằm trong thư
  mục tạm, nay đưa vào repo.
  - `make_fake_input.py` tạo dữ liệu giả theo đúng cách Kaggle sắp thư mục.
  - `run_two_devices.py` giả lập 2 GPU.
  - `run_fake_colab.py` giả lập Colab và Drive.
  - `smoke_test.py` chạy notebook 3 epoch fine-tune rồi kiểm tra: đủ file
    xuất, `finished: true`, log đủ 3 epoch, không sót file tạm. Thêm
    `--resume` để cắt sau epoch 1 rồi chạy tiếp.
  - Đã chạy cả 4 chế độ: 1 thiết bị, chạy tiếp, 2 thiết bị, Colab giả.

### 2026-10-21 · B3 FULL trên Kaggle hỏng vì loss thành NaN, thêm cơ chế tự quay lại
- Kết quả lượt B3 FULL trên Kaggle (2 GPU T4):
  - Đọc dữ liệu mất khoảng 5 giờ 50 phút, chủ yếu do đọc 171.619 nhãn
    VietFood67 trên ổ mạng.
  - Mỗi epoch fine-tune mất khoảng 12,6 phút. Colab 1 T4 mất khoảng 17
    phút.
  - 5 epoch fine-tune đầu bình thường: val tăng từ 0,655 lên 0,794, gần như
    trùng lượt Colab (0,671 lên 0,796). Điều này cho thấy hai nơi train
    giống nhau.
  - Ở epoch 6, loss chuyển thành `nan` và độ chính xác rơi xuống 3,2% (luôn
    đoán một món). Trọng số đã hỏng nên 5 epoch sau đứng yên ở 3,2%, cho tới
    khi EarlyStopping (patience 6) dừng ở epoch 11. Lúc đó mới khoảng 8 giờ
    30 phút, chưa tới giới hạn thời gian.
  - Model xuất ra lấy từ epoch tốt nhất (epoch 5): top-1 0,800, top-3 0,909
    trên 14.823 ảnh test. Dùng được nhưng kém bản Colab ở epoch 10 (0,829).
  - `results.json` ghi `finished: true` vì EarlyStopping không bị coi là
    dừng giữa chừng. Bản sửa dưới đây ghi rõ trường hợp này.
- Nguyên nhân có thể: mixed precision (float16) cộng với chia batch cho 2 GPU
  vào lúc learning rate gần đỉnh (khoảng 3e-4). Chưa xác định chắc. Hai đầu
  ra của model đã ở float32, và hàm loss có kẹp giá trị. Lượt Colab 1 GPU
  chưa gặp lỗi này sau 10 epoch.
- Sửa (`StopOnNaN`): không đổi gì khi loss bình thường, nên kết quả vẫn so
  được với B1, B2 và các lượt trước.
  - Ngay batch đầu tiên có loss NaN hoặc vô cực, notebook dừng epoch đó.
  - Không lưu `last.keras`, `checkpoint.keras` hay `progress.json` cho epoch
    hỏng.
  - Notebook nạp lại `last.keras` của epoch tốt cuối cùng và train tiếp. Thứ
    tự ảnh lần này khác nên khó gặp lại đúng batch đó. Thử lại tối đa 3 lần.
  - Nếu vẫn NaN: dừng, giữ epoch tốt nhất, `finished: false`, và
    `MODEL_CARD.md` ghi "DỪNG VÌ LOSS BỊ NaN".
- Thêm chế độ `--nan` cho `smoke_test.py`: cố ý biến trọng số lớp cuối thành
  NaN sau batch đầu của epoch fine-tune thứ 2. Notebook phải quay lại cuối
  epoch 1 và chạy đủ 3 epoch.
- Đã chạy `smoke_test.py` ở 4 chế độ, cả 4 đều PASS:
  - `--nan` trên 1 thiết bị và trên 2 thiết bị: đều báo "the loss is NaN,
    stopping this epoch", rồi "going back to the end of fine epoch 1", và
    chạy đủ 3 epoch.
  - `--resume` và chạy thường: vẫn như trước, nên bản sửa không làm hỏng
    tính năng cũ.

### 2026-10-21 · Colab hỏi quyền Google Drive ngay khi bắt đầu chạy
- Vấn đề: trước đây notebook tải hết dữ liệu (khoảng 40 phút) rồi mới kết
  nối Drive. Người dùng bấm *Run all* rồi để máy chạy một mình, nên hộp
  thoại xin quyền Drive hiện ra lúc không có ai bấm. Phiên đó coi như mất,
  phải chạy lại từ đầu.
- Sửa:
  - Kết nối Drive là việc đầu tiên trên Colab, trước khi đọc secret Kaggle
    và tải dữ liệu. Notebook in "Allow Google Drive access in the window
    that opens now."
  - Ngay sau khi kết nối, notebook in tiến độ cũ tìm thấy trên Drive (số
    epoch đã train, val tốt nhất), hoặc báo là train từ đầu. Nhờ vậy người
    dùng biết ngay phiên này sẽ chạy tiếp, khỏi đợi 40 phút mới thấy dòng
    `resuming`.
  - Phần hướng dẫn đầu notebook nhắc bấm cho phép Drive và secret trong vài
    giây đầu, rồi mới để máy tự chạy.
- Kiểm tra: `smoke_test.py --colab` và `--colab --resume` đều PASS. Lượt chạy
  tiếp in đúng "Earlier progress on Drive: {... epochs_done: 1 ...}" trước
  khi tải dữ liệu.

### 2026-10-21 · Không bao giờ âm thầm train lại từ đầu khi đã có tiến độ
- Chuyện xảy ra: tiến độ B3 (epoch 10/30) đã được chép sang Drive của acc
  mới. Nhưng ở hộp thoại cho phép Drive, phiên Colab chọn nhầm một acc khác
  không có tiến độ. Notebook không thấy gì nên train lại từ head epoch 1, và
  hơn 2 giờ GPU chạy lại phần đã có. Bản sao trên acc mới vẫn còn nguyên
  (đã kiểm tra `progress.json` qua Google Drive).
- Rủi ro lớn hơn: nếu thư mục có tiến độ nhưng một thiết lập khác đi (ví dụ
  đổi `BACKBONE`), lần chạy mới sẽ coi là chạy từ đầu và xóa luôn
  `last.keras` cùng `progress.json`.
- Sửa:
  - Nếu thư mục kết quả có tiến độ fine-tune mà không chạy tiếp được, notebook
    dừng bằng `RuntimeError`, không xóa gì. Các lý do không chạy tiếp được:
    khác backbone, khác recipe, khác `QUICK_TEST`, đã xong đủ epoch, hoặc
    thiếu `last.keras`. Thông báo ghi rõ lý do; muốn train lại từ đầu thì đổi
    tên thư mục cũ trước.
  - Trên Colab, nếu Drive vừa cho phép không có tiến độ, notebook in cảnh
    báo: nếu bạn đã chép tiến độ thì dừng ngay, vì đó là Drive của acc khác.
- Kiểm tra:
  - `smoke_test.py --resume`: PASS.
  - Chạy lại thư mục đó với `BACKBONE = 'efficientnetb0'`: notebook dừng,
    báo khác backbone, và `last.keras` cùng `progress.json` vẫn còn.

### 2026-10-21 · Ghi món nhanh hơn, hiện buổi tập trước, TDEE theo dữ liệu thật
- Lý do: so với các app cùng loại (MyFitnessPal, MacroFactor, Cal AI, Hevy),
  app thiếu 3 thứ hay dùng nhất:
  - ghi lại món đã ăn chỉ bằng một chạm;
  - thấy kết quả buổi tập trước ngay lúc tập;
  - TDEE điều chỉnh theo cân nặng thật thay vì chỉ dùng công thức.
- Nhật ký ăn:
  - Mỗi món có nút ngôi sao để thêm vào hoặc bỏ khỏi yêu thích. Dữ liệu lưu
    ở bảng mới `favorite_food`, nên database lên phiên bản 5; bản cũ được
    nâng cấp mà không mất dữ liệu.
  - Sheet "Thêm món" có hàng chip **Yêu thích** và **Gần đây** (8 món mới
    nhất, mỗi tên một lần, kèm đúng khẩu phần đã ăn). Chạm một chip là thêm
    ngay vào bữa đang chọn.
  - Bữa trống hôm nay có nút "Ăn giống hôm qua (N món · X kcal)". Khi xem
    ngày cũ, mỗi bữa có nút "Chép bữa này sang hôm nay".
- Tập luyện:
  - Dưới mỗi bài tập hiện "Lần trước (ngày): 60 kg × 10 · 9 · 8".
  - Hộp thoại ghi kết quả hiện gợi ý hôm nay, và điền sẵn mức tạ cùng số lần
    theo gợi ý của buổi trước.
  - Nút bấm giờ nghỉ: đếm ngược 90 giây ở cuối màn hình, có nút ±15 giây,
    rung khi hết giờ. Chỉ chạy khi app đang mở; chưa có thông báo nền.
- TDEE thích ứng (`lib/engine/adaptive_tdee.dart`):
  - Công thức: TDEE ≈ calo ăn trung bình − độ dốc cân nặng (kg/ngày) × 7700
    kcal/kg, tính trong 4 tuần gần nhất. 7700 kcal/kg là con số xấp xỉ
    thường dùng; app ghi rõ đây là ước lượng.
  - Độ dốc lấy bằng bình phương tối thiểu qua các lần cân, nên một lần cân
    lệch chỉ làm kết quả xê dịch ít.
  - Điều kiện để có kết quả: ít nhất 10 ngày ghi ăn (bỏ ngày dưới 500 kcal vì
    coi là ghi thiếu), ít nhất 3 lần cân, lần đầu và lần cuối cách nhau ít
    nhất 10 ngày.
  - Nếu kết quả lệch quá 30% dưới hoặc 40% trên so với công thức
    Mifflin-St Jeor, app cảnh báo là có thể ghi ăn chưa đủ và không cho dùng
    làm mục tiêu.
  - Màn Hồ sơ có thẻ "TDEE theo dữ liệu thật". Nút "Dùng làm mục tiêu" điền
    calo theo mục tiêu (giảm ×0,9, giữ ×1, tăng ×1,1, dùng chung hàm
    `goalCalorieFactor`) vào ô mục tiêu thủ công; bấm Lưu hồ sơ mới áp dụng.
- Kiểm tra:
  - `flutter analyze` sạch; `flutter test` 178/178 PASS, gồm test mới cho:
    - cách tính TDEE: cân đứng yên, giảm 0,5 kg/tuần ra +550 kcal, một lần
      cân lệch, ngày ghi thiếu, dữ liệu ngoài 4 tuần, thiếu dữ liệu, kết quả
      vô lý;
    - món gần đây, yêu thích và tổng calo theo ngày trên SQLite thật;
    - chạm chip yêu thích để thêm món, "ăn giống hôm qua", chép bữa sang hôm
      nay;
    - đồng hồ nghỉ và hộp thoại có buổi tập trước;
    - thẻ TDEE trên màn Hồ sơ.
  - `check_vn_food.py`: OK.
  - Chưa chạy thử trên điện thoại thật.

### 2026-10-21 · Nước uống, chuỗi ngày, tổng kết tuần, nhắc ghi bữa, sao lưu, widget
- Lý do: đây là nhóm 2 và 3 trong danh sách so sánh với các app cùng loại.
  Đó là những tính năng giữ người dùng quay lại mỗi ngày và giữ an toàn dữ
  liệu cho một app chạy offline.
- Màn Hôm nay:
  - **Chuỗi ngày ghi ăn**: số ngày liên tiếp có ghi món, tính đến hôm nay.
    Hôm nay chưa ghi thì chuỗi vẫn giữ tới hôm qua, kèm nhắc "Ghi bữa hôm nay
    để giữ chuỗi".
  - **Nước uống**: nút ± từng ly 250 ml, thanh tiến độ tới 2 lít.
    - 2 lít là mức tham khảo chung, không phải chỉ định cá nhân; app ghi rõ
      cần nhiều hơn khi trời nóng hoặc tập nặng.
    - Lưu ở bảng mới `water_log`, nên database lên phiên bản 6.
    - Bấm nhanh hai lần được cộng đủ hai ly: test phát hiện bản đầu chỉ cộng
      một ly, đã sửa.
  - **7 ngày qua**:
    - số ngày ghi ăn;
    - calo và protein trung bình, chỉ tính trên những ngày có ghi;
    - chênh lệch so với mục tiêu calo;
    - số ngày tập;
    - thay đổi cân nặng giữa lần cân đầu và cuối trong tuần.
  - Hai phần chuỗi ngày và tổng kết tuần là phần thêm: nếu lỗi thì phần còn
    lại của màn vẫn hiện.
- Cài đặt:
  - **Nhắc ghi bữa**: thông báo hằng ngày lúc 8:00, 12:30 và 19:30, đổi được
    giờ.
    - Dùng `flutter_local_notifications` kiểu không chính xác tuyệt đối, có
      thể đến trễ vài phút. Nhờ vậy không cần quyền báo thức chính xác, và
      không gửi gì qua mạng.
    - Android 13 trở lên hỏi quyền khi bật. Nếu bị từ chối, nhắc nhở vẫn tắt
      và app báo cách bật lại.
    - Cài lại lịch nhắc sau khi máy khởi động lại (`RECEIVE_BOOT_COMPLETED`).
    - Thêm desugaring vào Gradle theo yêu cầu của thư viện.
  - **Sao lưu dữ liệu**:
    - Xuất mọi bảng ra một file `optifit_backup_YYYY-MM-DD.json` rồi chia sẻ
      qua Drive, Zalo… Bản thân app không tải lên đâu cả.
    - "Khôi phục từ file" hỏi xác nhận, rồi thay toàn bộ dữ liệu trong một
      transaction.
    - File sai (app khác, phiên bản mới hơn, bảng lạ, cột lạ) bị từ chối và
      dữ liệu hiện có giữ nguyên.
    - Bản sao lưu từ phiên bản cũ thiếu bảng nước uống hay yêu thích vẫn khôi
      phục được.
- **Widget màn hình chính** (Android):
  - Hiện "OptiFit hôm nay", calo ăn so với mục tiêu, nước uống và chuỗi ngày.
    Chạm vào thì mở app.
  - App cập nhật widget mỗi lần màn Hôm nay tải lại, qua `home_widget`; chữ
    được dịch sẵn theo ngôn ngữ app.
  - Phần Android: `TodayWidgetProvider.java`, layout `today_widget.xml`, thêm
    vào manifest.
- Thư viện mới: `flutter_local_notifications`, `timezone`, `flutter_timezone`,
  `share_plus`, `file_picker`, `home_widget`. Bản release vẫn không có quyền
  INTERNET.
- Kiểm tra:
  - `flutter analyze` sạch; `flutter test` 195/195 PASS, gồm test mới cho:
    - chuỗi ngày (ngắt quãng, hôm nay chưa ghi, trùng ngày);
    - tổng kết tuần;
    - nước uống và tổng theo ngày trên SQLite thật;
    - sao lưu rồi khôi phục sang database trống, file hỏng không làm mất dữ
      liệu, bản sao lưu đời cũ;
    - bật, tắt, đổi giờ, bị từ chối quyền nhắc nhở;
    - luồng khôi phục có hỏi xác nhận.
  - `check_vn_food.py`: OK.
- Gỡ quyền `READ_PHONE_STATE` khỏi bản release. Quyền này do thư viện GPU
  của LiteRT kéo vào (vì khai báo targetSdk cũ) chứ app không dùng. Các
  quyền mới của WorkManager (do `home_widget` dùng) là quyền thường, không
  phải xin người dùng.
- Đã build APK arm64 build 110 (20,7 MB, chữ ký release khớp) và cài đè lên
  điện thoại test. App mở được, nâng cấp database lên v6, log không có lỗi.

### 2026-10-22 · Đưa EfficientNetB3 (bản int8) vào app thay EfficientNetB0
- B3 train xong đủ 30 epoch fine-tune qua nhiều phiên Colab và nhiều acc
  Google (`finished: true`), tổng 630 phút train, không lần nào bị lỗi NaN.
  - Val top-1 0,867; test top-1 **0,860**, top-3 **0,941** trên 14.823 ảnh
    test; F1 thành phần 0,468.
  - 26/63 món có ảnh đạt từ 90% trở lên. Yếu nhất: salad 0,48, cơm phần
    0,57, "món lạ" (khac) 0,63, cà ri 0,67, khoai tây chiên 0,70.
  - Ngưỡng chọn theo độ chính xác ≥ 0,85: `threshold_checked` 0,7,
    `threshold_ask` 0,4.
- So với B0 đang dùng (contract 1.3, 52 món): test top-1 0,688, top-3
  0,839. B3 cao hơn khoảng 17 điểm dù phải nhận 65 món. Hai model thi trên hai
  tập test khác nhau, nên đây không phải phép so trên cùng một đề. Phép so
  công bằng là với B1/B2, cùng cách train và cùng tập test.
- Chọn bản **int8** (lượng tử hóa trọng số theo dynamic range): 11,9 MB so
  với 21,8 MB của bản float16. Trên cùng mẫu ảnh test, int8 đạt 0,830 và
  float16 đạt 0,832. Trên CPU điện thoại, bản int8 thường nhanh hơn và tốn ít
  RAM hơn.
- Kiểm tra trước khi đưa vào app:
  - `dishes.txt` (66 dòng) và `components.txt` (25 dòng) đúng thứ tự `DISHES`
    + `khac` và `COMPONENTS` của notebook.
  - Model nhận `[1,300,300,3]` float32 và trả hai đầu ra 66 và 25; đầu ra món
    cộng lại bằng 1.
  - `flutter test` 195/195 PASS.
- `MODEL_CARD.md` ghi rõ app dùng bản int8. Sửa chú thích trong
  `scan_camera.dart`: model đọc ảnh tối đa 300×300, không còn 224×224.
- Build APK arm64 build 111: 24,1 MB (bản B0 là 20,7 MB), chữ ký release
  khớp, không có quyền INTERNET. Chưa đo tốc độ quét trên điện thoại thật.

### 2026-10-22 · Đổi tên hiển thị thành MacroRunner và thêm logo
- Vấn đề: app trên điện thoại vẫn hiện tên cũ "OptiFit" và icon mặc định của
  Flutter.
- Tên: mọi chỗ người dùng nhìn thấy đều đổi thành **MacroRunner**:
  - tên dưới icon (`android:label`) và tiêu đề app;
  - chữ trên thanh đầu app;
  - tên và chữ của widget;
  - thông báo nhắc ghi bữa;
  - các câu báo lỗi camera và bản sao lưu.
- Giữ nguyên applicationId `io.github.jimeavv.optifit` cùng tên package và
  class trong code, vì đổi applicationId thì Android coi là app khác, không
  cài đè được và người dùng mất dữ liệu. Khóa `app: optifit` trong file sao
  lưu cũng giữ nguyên để file cũ vẫn khôi phục được.
- Logo (tự vẽ bằng code, `tool/brand/make_logo.py`, không dùng hình hay
  thương hiệu của ai):
  - Chữ **M vẽ bằng đường nhịp tim**, chỉ sức khỏe và luyện tập, chuyển màu
    từ cyan sang hồng. Cuối đường có một chấm lime, chỉ tiến bộ.
  - Nền xanh navy, sáng nhẹ ở giữa.
  - Màu lấy đúng bảng màu Cyberpunk của app: `#00F5FF`, `#FF2BD6`,
    `#B7FF00`.
- Icon Android:
  - Icon thích ứng (adaptive): lớp nền, lớp hình, và lớp đơn sắc cho icon
    theo chủ đề trên Android 13 trở lên.
  - Icon PNG bo góc cho Android cũ, đủ 5 mật độ màn hình.
  - Icon thông báo màu trắng trên nền trong suốt (`ic_stat_notify`). Android
    tô xám icon thông báo có màu, nên icon cũ hiện thành ô vuông xám.
    `res/raw/keep.xml` giữ icon này khỏi bị bước thu gọn tài nguyên xóa, vì
    nó chỉ được gọi bằng tên trong code Dart.
- Logo cũng thay icon tia sét trên thanh đầu app (`assets/brand/logo.png`).
  Bản 1024 px ở `docs/logo_macrorunner.png` để dùng cho báo cáo.
- Kiểm tra:
  - `flutter analyze` sạch; `flutter test` 195/195 PASS.
  - APK build 112 (24,4 MB): `aapt` báo tên "MacroRunner", có
    `drawable/ic_stat_notify`, chữ ký release khớp.
  - Đã cài đè lên điện thoại test; app mở được, log không có lỗi.

### 2026-10-22 · Ô tìm kiếm khi chọn món, và ghi "ăn riêng một thứ"
- Thử thật trên điện thoại với model B3:
  - Quét rất nhanh: 0,19–0,22 giây mỗi lần, trong đó model chạy 0,07–0,10
    giây.
  - Cơm trắng trong nồi và ức gà luộc bị đoán thành xôi, bánh đúc, há cảo,
    vì đó không phải "món" trong 65 món model được học.
  - Chạy lại model trên ảnh cắt từ màn hình: đầu ra thành phần nhận ra cơm
    chắc 100%, nhưng gà luộc thì 0%.
- Vấn đề khi ghi tay: danh sách "Món khác" chỉ có 65 món, cuộn dài, không tìm
  được, và không chọn được một thứ ăn riêng (cơm, gà, trứng…).
- Sửa:
  - Bảng chọn mới (`FoodPickerSheet`) có ô tìm kiếm, gõ không dấu cũng được.
    Bảng có hai nhóm: **Món** và **Ăn riêng một thứ** (các thành phần, kèm
    kcal/100 g).
  - Kết quả khớp đủ mọi từ hiện trước. Sau đó hiện các mục có một từ bắt đầu
    bằng từ đã gõ, nên gõ "ức gà" vẫn ra "Thịt gà" dù không món nào tên như
    vậy. Chỉ so phần đầu từ, vì so cả chuỗi con thì "uc" khớp nhầm "bánh
    đúc".
  - Chọn một thứ ăn riêng tạo đĩa chỉ gồm thứ đó, với khẩu phần thường gặp
    (`ScanPlate.single`). Nhật ký ghi đúng tên thứ đó, không kèm tên món.
  - Bảng "Thêm thành phần" cũng có ô tìm kiếm.
- Kiểm tra:
  - `flutter analyze` sạch; `flutter test` 196/196 PASS. Có thêm test: tìm
    "pho" ra Phở bò, tìm "tom luoc" ra Tôm, chọn Tôm rồi ghi được một dòng
    tên "Tôm".
  - Build APK 113 (24,4 MB). Chưa cài lên điện thoại vì máy mất kết nối adb.

### 2026-10-22 · Gom ảnh của chính người dùng để dạy model, và ghi món chưa có
- Lý do: nhiều món hay ăn (yến mạch, khoai lang, gạo lứt, sữa chua Hy Lạp,
  bánh mì đen, bơ đậu phộng, shake protein, mì gói, trà sữa) không có bộ ảnh
  công khai nào dùng được. Đã tìm trên Hugging Face, Kaggle, Roboflow và danh
  sách lớp của ISIA Food-500. Ảnh người dùng tự chụp lại khớp đúng chén bát,
  ánh sáng và góc chụp thật, nên dạy model tốt hơn ảnh trên mạng.
- `PhotoCollector` (`lib/services/photo_collector.dart`):
  - Mặc định tắt; bật trong Cài đặt, thẻ "Gom ảnh để dạy model".
  - Khi bật, mỗi lần ghi một món đã quét, app giữ lại ảnh (cạnh dài nhất 640
    px, JPEG 85, khoảng 60 KB) trong thư mục `training_photos/<nhãn>/`.
  - Nhãn là mã món, `single_<thành phần>` cho thứ ăn riêng, hoặc
    `new_<tên>` cho món chưa có (ví dụ "Yến mạch" thành `new_yen_mach`).
  - `index.csv` ghi tên món người dùng xác nhận, kèm món model đoán và độ tin
    cậy. Ảnh model đoán sai là ảnh đáng train nhất.
  - Ảnh chỉ nằm trong máy. "Xuất ảnh đã gom (zip)" mở bảng chia sẻ của
    Android; "Xóa ảnh đã gom" có hỏi xác nhận và không đụng tới nhật ký ăn.
  - Lưu ảnh trước khi rời màn kết quả, vì ảnh quét bị xóa ngay sau đó. Lỗi
    khi lưu ảnh không chặn việc ghi món.
- Bảng chọn món có thêm mục "Món chưa có trong danh sách…": nhập tên và dinh
  dưỡng như món tự nhập trong nhật ký, ghi vào bữa đang chọn, và giữ ảnh dưới
  nhãn `new_<tên>`.
- Kiểm tra:
  - `flutter analyze` sạch; `flutter test` 200/200 PASS.
  - Test mới: không lưu gì khi đang tắt; ảnh 1600×1200 được thu còn 640×480;
    `index.csv` đúng cột; nhãn `new_` sinh từ tên tiếng Việt; nhãn có `../`
    bị chặn; file zip có ảnh và chỉ mục; xóa sạch được.
  - Hai test cũ của màn Cài đặt phải cuộn xa hơn vì có thêm thẻ mới.
  - Build APK 114 (24,5 MB) và cài đè lên điện thoại test.

### 2026-10-22 · Contract 1.5: thêm 26 món ăn hằng ngày, notebook train tiếp từ B3
- Lý do: người dùng muốn app nhận được cả món lẻ (cơm trắng, ức gà, trứng)
  và món phổ biến không phải món Việt (pizza, sushi, mì Ý…), để dùng lâu dài.
  Train lại từ đầu tốn 10 tiếng; train tiếp từ model B3 của contract 1.4 chỉ
  cần khoảng 8 epoch.
- Chọn món theo ảnh có sẵn, mỗi món phải có ít nhất một bộ ảnh:
  - Food-101 (Kaggle `kmader/food41`, 1.000 ảnh mỗi lớp): pizza, sushi,
    sashimi, ramen, hot dog, bít tết, ốp lết, mì Ý, chả giò, cánh gà, cá hồi,
    mực chiên, sủi cảo, sandwich, pancake, waffle, donut, bánh kem, kem. Một
    số lớp gộp vào món cũ: cơm chiên, khoai tây chiên, salad, cà ri gà. Các
    lớp còn lại vào `khac`.
  - MyFood (Zenodo, CC BY 4.0, khoảng 1.250 ảnh có mask): cơm, ức gà, trứng
    luộc, trứng ốp la, bít tết, mì Ý, táo. Notebook cắt theo mask, nên một
    dĩa cơm trưa cho ra nhiều ảnh, mỗi ảnh một món.
  - VietFood67: cắt riêng khung cơm, đậu hũ, chả giò, và rau trên dĩa cơm
    phần (rau cạnh phở, bún là rau sống nên không lấy).
  - Không dùng ISIA Food-500: bản trên Hugging Face chỉ có 40 ảnh mỗi lớp,
    và không có yến mạch, sữa chua Hy Lạp, bơ đậu phộng, trà sữa. Các món đó
    vẫn chờ ảnh người dùng tự lưu.
- Dữ liệu dinh dưỡng (`assets/data/vn_food`):
  - 26 món mới trong `dish_names.csv` và `dishes.csv`; 20 dòng nền mới trong
    `components.csv`, nguồn USDA FoodData Central (SR Legacy hoặc FNDDS) có
    mã cụ thể. Khối lượng một cái, một miếng ghi rõ là ước lượng của nhóm,
    trừ quả táo (182 g theo USDA).
  - Món nào là một thành phần sẵn có thì dùng thành phần đó: cơm trắng là
    `com`, trứng luộc là `trung_kho`, gà rán là `ga_chien`…
  - Mã món đậu hũ là `dau_hu_chien` để không trùng mã thành phần `dau_hu`.
- `docs/MODEL_CONTRACT.md` lên 1.5: bảng món 66–91; ảnh của món chỉ có dòng
  nền (ức gà, sushi…) không dạy đầu ra thành phần, vì trên ảnh có gà, có cơm
  nhưng công thức món không ghi; mô tả file zip ảnh tự lưu (mục 5).
- Notebook (`tool/train/train_food_model.py`):
  - `EXPERIMENT = 'continue'` (mặc định): tìm `checkpoint.keras` của B3 1.4
    (trên Drive, trong input của Kaggle, hoặc `WARM_START`). Chép backbone và
    đầu ra thành phần nguyên vẹn; đầu ra món chép theo từng cột: 65 món cũ giữ
    chỗ, `khac` chuyển xuống cuối, 26 món mới bắt đầu từ trọng số mới. Train
    1 epoch đầu ra rồi 8 epoch fine-tune với learning rate 1e-4, bằng một
    phần ba lần trước, để không làm hỏng những gì 1.4 đã học.
  - `progress.json` ghi thêm thí nghiệm và phiên bản contract. Nhờ vậy, khi
    gắn output của lần 1.4 vào Kaggle, notebook không nhầm nó là lần chạy
    dở của chính mình.
  - Ảnh có thêm khung cắt (`box`); bản thu nhỏ và mã hash tính trên phần cắt.
  - Tự tải MyFood; đọc file zip ảnh tự lưu (Kaggle: thêm như dataset; Colab:
    để trong Drive `macrorunner_train/my_photos/`). Nhãn `single_com` thành
    `com_trang`, `new_<tên>` vào `khac`.
- App: chỉ đổi dữ liệu. Bảng chọn món đã có 91 món, nên ghi tay pizza, ức
  gà… được ngay, trước khi có model mới.
- Kiểm tra:
  - `python tool/check_vn_food.py`: OK, 104/104 dòng có dinh dưỡng và nguồn.
  - `flutter analyze` sạch; `flutter test` PASS (sửa test đếm món 65 → 91).
  - Smoke test notebook trên dữ liệu giả, có thêm Food-101, MyFood, zip ảnh
    tự lưu và một model 1.4 giả: PASS cả 3 chế độ (một máy, cắt ngang rồi
    chạy tiếp, giả lập Colab với model và zip trên Drive). Lần chạy tìm thấy
    model 1.4, chép trọng số rồi train tiếp; nhãn `single_bi` (không có món
    lẻ tương ứng) bị bỏ qua đúng như thiết kế.
  - Agent `model-contract-reviewer`: mã và thứ tự món khớp ở mọi nơi. Đã sửa
    theo góp ý: lớp Food-101 gần giống món của app (filet mignon, prime rib,
    salad củ dền, caprese, sandwich thịt kéo, lobster roll) gộp vào món đó
    thay vì `khac`; frozen yogurt và salad rong biển bỏ qua; `MODEL_CARD`
    ghi rằng điểm test có thể cao hơn thực tế vì ảnh được chia lại.
  - Build APK 115 (24,5 MB), chữ ký release đúng; chưa cài lên điện thoại
    theo yêu cầu, gửi file cho người dùng tự cài.

### 2026-10-22 · Notebook báo ngay khi Drive thiếu model 1.4, hoặc tự tải từ link
- Lý do: người dùng train 1.5 bằng một tài khoản Google khác. Trước đây,
  nếu Drive của tài khoản đó chưa có `checkpoint.keras` của B3, notebook
  chỉ báo lỗi khi bắt đầu train, tức là sau khoảng 40 phút tải dữ liệu.
- Đã làm: trên Colab, ngay sau khi kết nối Drive, notebook kiểm tra file
  `macrorunner_train/efficientnetb3_finetune/checkpoint.keras` (hoặc đường
  dẫn trong `WARM_START`). Thiếu file thì dừng ngay và chỉ chỗ cần chép file
  vào; có file thì in đường dẫn sẽ dùng.
- Thêm `WARM_START_URL`: link chia sẻ của `checkpoint.keras`. Drive chưa có
  file thì notebook tự tải về bằng `gdown` (lấy mã file trong link, vì bản
  `gdown` mới bỏ tham số `fuzzy`), khỏi chép tay. Bản gửi người dùng điền sẵn
  link bản B3 30 epoch (val 0,867). Repo để trống, không lộ link Drive.
- Kiểm tra: `smoke_test.py --colab` PASS. Tải thật file qua link: 217 MB,
  mở được, ảnh vào 300×300, 66 đầu ra món, 25 thành phần. Smoke test dùng
  chính file này làm điểm xuất phát: PASS.

### 2026-10-22 · Nhắc uống nước
- Lý do: người dùng muốn được nhắc uống nước đều trong ngày, mỗi lần một
  câu khác nhau, tự bật tắt và chọn khoảng cách giữa hai lần nhắc.
- `WaterReminderController` (`lib/services/water_reminder_service.dart`):
  - Mặc định tắt. Tuỳ chọn nhắc mỗi 1; 1,5; 2; 3 hoặc 4 tiếng (mặc định 2),
    trong khung giờ đổi được (mặc định 8:00–22:00) để không nhắc lúc ngủ.
  - 5 câu nhắc (tiếng Việt và tiếng Anh). Mỗi thông báo chọn ngẫu nhiên một
    câu, không lặp lại câu ngay trước đó.
  - Android không có kiểu thông báo lặp lại mà mỗi lần đổi chữ, nên app hẹn
    sẵn từng thông báo cho 7 ngày tới (tối đa 7 × 24 cái, dưới giới hạn 500
    của Android). Mỗi lần mở màn Hôm nay hoặc ghi nước thì hẹn lại; quá 7
    ngày không mở app thì hết nhắc (ghi trong thẻ Cài đặt).
  - Hôm nào đã uống đủ mục tiêu (2.000 ml) thì bỏ các lần nhắc còn lại trong
    ngày.
  - Các lần hẹn lại chạy lần lượt, để hai lần chồng nhau không để lại thông
    báo trùng.
- Kênh thông báo riêng "Nhắc uống nước", nên có thể tắt tiếng riêng trong
  Android. Mã thông báo 1000–1999, tách khỏi nhắc bữa (100–199).
- Sửa lỗi cũ: tắt nhắc bữa trước đây xoá mọi thông báo đã hẹn (`cancelAll`).
  Giờ mỗi loại chỉ xoá mã của mình. Phần khởi tạo thông báo dùng chung nằm
  ở `lib/services/local_notifications.dart`.
- Cài đặt có thẻ "Nhắc uống nước": công tắc, các nút chọn số tiếng, giờ bắt
  đầu và kết thúc. Giờ kết thúc không sau giờ bắt đầu thì báo lỗi và không
  đổi gì.
- Kiểm tra:
  - `flutter analyze` sạch; `flutter test` 207/207 PASS.
  - 7 test mới: giờ nhắc đúng theo khoảng cách, khung giờ và giờ hiện tại;
    nhắc mỗi 1,5 tiếng; câu nhắc luôn là một trong 5 câu và không lặp liền;
    đủ nước thì hôm nay thôi nhắc; quyền bị từ chối; khung giờ sai; cài đặt
    còn sau khi mở lại app; tắt nhắc nước không đụng tới nhắc bữa; bật và đổi
    khoảng cách từ thẻ Cài đặt.
  - Build APK 116.

### 2026-10-22 · Đưa model 1.5 (B3 train tiếp, 91 món) vào app
- Lý do: lần train tiếp từ B3 1.4 trên Colab (tài khoản khác, tự tải model
  1.4 qua link) đã xong. Colab hết giờ sau epoch 6/8; notebook dừng gọn và
  xuất epoch tốt nhất (val 0,873, vẫn đang tăng chậm).
- Kết quả trên tập test (22.229 ảnh), so với B3 1.4:
  - Món top-1: 0,870 (1.4: 0,860); top-3: 0,949 (0,941).
  - Thành phần F1: 0,577 (0,468). Lần đầu có món được tin phần thành phần
    (`component_dishes`): mì Quảng, xôi, cơm trắng, đậu hũ.
  - 26 món mới: phần lớn 0,79–0,97, như pizza 0,907, bò bít tết 0,930, chả
    giò 0,933, cơm trắng 0,950. Yếu nhất là ức gà 0,650 và cá hồi 0,727.
    Táo và trứng luộc đạt 1,0 nhưng chỉ có khoảng 15 ảnh test, chưa nói lên
    gì.
  - Món cũ tăng nhờ ảnh Food-101: salad 0,479 lên 0,907, khoai tây chiên
    0,698 lên 0,897, cà ri 0,667 lên 0,838. Món cũ giảm nhiều nhất: há cảo
    0,932 xuống 0,844 (dễ nhầm với sủi cảo mới), gà nướng 0,899 xuống 0,840.
  - Lưu ý: ảnh được chia lại vì có thêm bộ ảnh, nên một phần ảnh test model
    1.4 đã thấy khi train; điểm có thể cao hơn thực tế (ghi trong MODEL_CARD).
- App dùng bản int8 (12,0 MB; trên mẫu ảnh test int8 0,838, float16 0,839).
  Ngưỡng mới: tick sẵn 0,55, hỏi lại 0,25.
- Kiểm tra: `flutter test` 207/207 PASS, trong đó có test mã món của model
  phải có trong bảng dinh dưỡng; đầu vào 300×300, đầu ra 92 món và 25 thành
  phần. Build APK 117.

### 2026-10-22 · Sửa chú thích cũ "224×224" trong notebook
- Lý do: người dùng thấy mục "Input pipeline" ghi ảnh vào 224×224 trong khi
  đang train B3. Chú thích đó viết từ hồi dùng EfficientNetB0; code thật dùng
  biến `IMG` (300×300 với B3) nên kết quả train không bị ảnh hưởng.
- Đã làm: sửa chú thích ở mục "Input pipeline" và phần thu nhỏ ảnh
  (`SHRUNK_SIDE`) cho đúng kích thước theo từng backbone. Không đổi code.
- Kiểm tra: sinh lại `train_food_model.ipynb`; `grep 224` chỉ còn ở bảng
  kích thước và các chú thích đúng.

### 2026-10-23 · Train nốt model 1.5 (epoch 7–8), đưa epoch 7 vào app
- Lý do: bản 1.5 trước dừng ở epoch 6/8 vì hết giờ Colab. Người dùng chạy
  tiếp epoch 7 rồi đổi tài khoản Google chạy epoch 8. Notebook gửi đi có
  thêm một ô ở đầu, chép `last.keras`, `checkpoint.keras`, `progress.json`
  và log của epoch 7 từ thư mục chia sẻ sang Drive tài khoản mới, nên lần
  chạy đó tự tiếp tục từ epoch 7.
- Kết quả: đủ 8 epoch, tổng 261 phút train. Val: epoch 7 đạt 0,8756, epoch 8
  0,8751, nên notebook giữ epoch 7. Trên tập test, so với epoch 6 đang dùng:
  - món top-1 0,871 (0,870), top-3 0,950 (0,949);
  - thành phần F1 0,589 (0,577); ngưỡng mới: tick sẵn 0,5, hỏi lại 0,2;
  - ức gà 0,75 (0,65), mực chiên 0,85 (0,83); rau xào giảm 0,77 xuống 0,69,
    trứng chiên 0,75 xuống 0,73.
- App dùng bản int8 12,0 MB; trên mẫu 1.000 ảnh test, int8 0,833 và
  float16 0,827.
- Kiểm tra: `flutter test` 207/207 PASS. Build APK 118. Lần build đầu chạy
  cùng lúc với `flutter test` nên kẹt file tạm và không ra APK mới; build
  lại riêng thì ra đúng versionCode 2118 và đúng chữ ký release.

### 2026-10-23 · Lưu kết quả mọi lần train vào `docs/ket_qua_model`
- Lý do: kết quả các lần train nằm rải rác trên Drive của nhiều tài khoản
  và trong thư mục tạm. Viết báo cáo và so sánh backbone sau này cần chúng ở
  một chỗ, trong repo.
- Đã làm:
  - Sáu lần train thật, mỗi lần một thư mục với `results.json`,
    `MODEL_CARD.md` và hai file log: bốn lần so backbone ở contract 1.3
    (EfficientNetB0, EfficientNetV2-B0, MobileNetV3 của mỗi người), B3 1.4
    và B3 1.5. Số liệu B3 1.4 lấy lại từ thư mục gốc trên Drive và khớp
    với bản đã lưu trước đó. File model và `splits.csv` không đưa vào git vì
    quá nặng; README ghi chỗ để chúng trên Drive.
  - `README.md` có bảng so sánh chung và ghi rõ lần nào so được với lần nào:
    chỉ so khi cùng contract và cùng cách train. B3 1.4 hơn nhóm 1.3 khoảng
    17 điểm %, nhưng do cả backbone, cách train lẫn dữ liệu đều khác, nên
    không quy hết cho backbone. Muốn so công bằng thì train lại B0 và
    MobileNetV3 bằng notebook 1.4 với `RECIPE = 'full'`.
  - `tool/train/compare_results.py` in được tiếng Việt trên console Windows
    (trước đó lỗi `UnicodeEncodeError`).
- Kiểm tra: chạy `compare_results.py` trên bốn thư mục 1.3 cho đúng bảng và
  đúng lựa chọn EfficientNetB0 như ngày 20/10; số trong README lấy thẳng từ
  các `results.json`.

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

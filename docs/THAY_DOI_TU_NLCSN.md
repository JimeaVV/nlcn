# Thay đổi từ NLCSN (OptiFit 1.0) đến MacroRunner (NLCN)

Tài liệu này liệt kê những gì đã đổi từ sản phẩm niên luận cơ sở ngành
(OptiFit 1.0, tháng 8/2026) đến bản MacroRunner hiện tại, để báo cáo tiến độ
ngày 03/11/2026.

- Mốc "trước": OptiFit 1.0 trong repo cũ <https://github.com/JimeaVV/nlcsn>
  (commit `c321150`, 13/08/2026) và báo cáo NLCSN.
- Mốc "sau": nhánh `feature/contract-1.5`, commit `d3370a3` (01/11/2026).
  Nhánh này còn 2 commit chưa gộp vào `main` (`c5228b8`, `d3370a3`).
- Số liệu lấy từ `docs/QUA_TRINH_THUC_HIEN.md`, `docs/MODEL_CONTRACT.md`,
  `assets/models/MODEL_CARD.md`, `assets/models/DETECTOR_CARD.md` và
  `git log`. Từ 16/10 đến 01/11 có 139 commit.
- Mục 9 là việc đang làm trên nhánh riêng, chưa có trong app.

## Tóm tắt

| Hạng mục | NLCSN (OptiFit 1.0) | MacroRunner (02/11/2026) |
|---|---|---|
| Kiến trúc | Flutter gọi backend FastAPI qua HTTP | Chạy hoàn toàn trên điện thoại, không có quyền INTERNET |
| Nhận diện món | Không có | EfficientNetB3 (91 món + "món lạ", 25 thành phần) và detector YOLO11s (21 lớp) |
| Dữ liệu món ăn | 160 nguyên liệu tên tiếng Anh, không có món Việt | 91 món, 104 dòng thành phần có nguồn, 204 dòng khẩu phần, 74 biến thể thịt, cá, trứng, cơm |
| Gợi ý thực đơn | Ghép nguyên liệu kiểu "yến mạch sống + ức gà" | Món Việt nguyên suất hoặc cơm phần |
| Ghi ăn uống | Không có | Nhật ký theo bữa, quét món, yêu thích, gần đây, nước uống |
| Ngôn ngữ | Lẫn tiếng Việt và tiếng Anh | Việt và Anh, đổi trong Cài đặt |
| SQLite | Version 2, 4 bảng | Version 6, thêm nhật ký ăn, yêu thích, nước uống |
| Tên, applicationId | OptiFit, `com.example.nlcsn` | MacroRunner, `io.github.jimeavv.optifit` |
| Ký app | Khóa debug | Khóa release riêng, CI kiểm tra chữ ký |
| Kiểm thử | 18 test backend, 6 test Flutter | 250 test Flutter, CI chạy cho mọi PR |

## 1. Kiến trúc: bỏ backend, chạy offline

Trước:
- App Flutter gửi hồ sơ lên FastAPI (`POST /api/recommend-diet`,
  `/api/recommend-workout`), chờ tối đa 20 giây. Không có máy chủ thì không
  tạo được thực đơn hay buổi tập mới.
- Backend đọc 2 file CSV bằng pandas lúc khởi động. App chỉ giữ hồ sơ và lịch
  sử trong SQLite.
- Repo còn `render.yaml` để deploy, và phần lớn code mới chưa được commit.

Sau:
- Engine gợi ý viết lại bằng Dart thuần, chạy trên isolate riêng. Dữ liệu
  đóng gói trong `assets/data/`. Commit `c1680a5` (16/10).
- Bản release bỏ quyền INTERNET. Camera, model nhận diện, thông báo, widget,
  sao lưu đều chạy trên máy.
- Thư mục `backend/` vẫn giữ để tham khảo thuật toán gốc; app không cần nó.
- Lỗi từ engine trả về mã lỗi (`NutritionTargetError`,
  `MealPlanUnavailableError`…), giao diện dịch mã thành câu theo ngôn ngữ đang
  chọn. Trước đây lỗi tiếng Anh hiện thẳng cho người dùng.
- SQLite lên dần từ version 2 tới version 6, mỗi lần nâng cấp giữ dữ liệu cũ:
  - v3: mục tiêu giảm, giữ, tăng cân và lịch sử cân nặng;
  - v4: bảng `food_log` (nhật ký ăn). Mỗi dòng lưu dinh dưỡng tại lúc ghi,
    nên sửa dataset sau này không làm đổi số của ngày cũ;
  - v5: bảng `favorite_food`;
  - v6: bảng `water_log`.

Cách làm:
- Viết lại từng hàm Python sang Dart theo đúng công thức cũ (Mifflin-St Jeor,
  hệ số vận động, Branch & Bound, chấm điểm bài tập, luật Progressive
  Overload), rồi viết test so kết quả.
- Hai file CSV của backend được đổi một lần thành
  `assets/data/recommendations.json` đóng gói trong APK; app đọc khi mở.
- Lập thực đơn chạy trên isolate (luồng riêng của Dart) để giao diện không
  bị đứng trong lúc tìm kiếm.
- Nâng cấp database bằng `onUpgrade` của sqflite: mỗi version chỉ tạo bảng
  hoặc cột mới, không xóa bảng cũ. Có test mở database version cũ rồi nâng
  lên để chắc dữ liệu còn nguyên.

## 2. Nhận diện món ăn

NLCSN không có phần này. Đây là phần mới chính của NLCN.

### 2.1. Thỏa thuận giữa app và model

- `docs/MODEL_CONTRACT.md` ghi danh sách món, thành phần, định dạng đầu vào
  và đầu ra, ngưỡng, các dòng trong thẻ model. Hai người làm song song mà
  không phải chờ nhau.
- Phiên bản đi từ 0.1 (20 món, 24 thành phần) lên 1.0 (40 món), 1.3 (52 món
  và lớp `khac`), 1.4 (65 món), 1.5 (91 món), 1.6 (thêm detector 21 lớp), 1.7
  (ngưỡng riêng từng lớp của detector).
- Đổi danh sách món thì phải sửa cùng lúc contract, notebook, các CSV dinh
  dưỡng và `tool/vn_food_recipes.py`. Script `tool/check_vn_food.py` và agent
  `model-contract-reviewer` kiểm tra việc này.

### 2.2. Model nhận diện món: một model, hai đầu ra

- Đầu `dish` đoán món (softmax), đầu `components` đoán từng thành phần có trên
  đĩa (sigmoid, nhiều nhãn). Nhờ vậy app tính calo theo từng thành phần,
  ví dụ cơm tấm có sườn, trứng, bì hay không.
- Ảnh từ các bộ công khai: VietFood67, VinaFood21, 30VNFoods, 20FoodVN,
  Food-101, MyFood. Ảnh trùng giữa các bộ được bỏ bằng average hash; chia
  70/15/15 theo từng món.
- So sánh 3 backbone trên contract 1.3 (52 món, cùng dữ liệu, cùng cách chia,
  8.287 ảnh test):

  | Backbone | Test top-1 | Test top-3 | TFLite |
  |---|---|---|---|
  | EfficientNetB0 (chọn) | 68,8% | 83,9% | 8,3 MB |
  | EfficientNetV2-B0 | 68,5% | 83,1% | 12,0 MB |
  | MobileNetV3 | 67,4% | 82,5% | 6,2 MB |

  Hai lần train MobileNetV3 độc lập chỉ lệch 0,1 điểm, nên khoảng cách 1,1
  điểm của EfficientNetB0 lớn hơn độ dao động giữa các lần chạy.
- Sau đó nhóm chuyển sang EfficientNetB3 (ảnh 300 px), mở toàn bộ backbone,
  AdamW, learning rate cosine, label smoothing:
  - contract 1.4, 65 món: test top-1 86,0%, top-3 94,1%, 630 phút train;
  - contract 1.5, 91 món (train tiếp từ bản 1.4): test top-1 87,1%, top-3
    95,0%, F1 thành phần 0,589, trên 22.229 ảnh test.

  B3 cao hơn B0 khoảng 17 điểm, nhưng hai bên khác cả backbone, cách train
  và dữ liệu, nên không quy hết cho backbone.
- App dùng bản int8: 12,0 MB, so với 21,9 MB của bản float16. Trên mẫu 1.000
  ảnh test, int8 đúng 83,3%, float16 82,7%.
- Lớp `khac` (món app chưa có): khi model nghiêng về lớp này, app không tự
  chọn món mà báo "Có vẻ món này chưa có trong app".
- App chỉ tin đầu ra thành phần ở 4 món model học tốt (mì Quảng, xôi, cơm
  trắng, đậu hũ). Món khác thì tick theo công thức. Lý do: lần thử đầu, tô
  phở bị tick thêm 8 thành phần không có, tổng ra 1.692 kcal thay vì khoảng
  500 kcal.
- Tốc độ trên điện thoại test (Xiaomi 8 nhân): EfficientNetB0 0,14 đến 0,16
  giây cả lần quét; EfficientNetB3 0,19 đến 0,22 giây, trong đó model 0,07
  đến 0,10 giây.

Cách làm:
- Transfer learning: lấy backbone đã train sẵn trên ImageNet, gắn 2 đầu ra
  mới. Train 2 pha: pha 1 chỉ train 2 đầu ra, pha 2 mở backbone ra train
  tiếp với learning rate nhỏ.
- Nhãn món lấy theo thư mục của bộ ảnh, đổi tên lớp sang mã của app bằng
  cách so tên đã bỏ dấu. Nhãn thành phần lấy từ khung có sẵn của
  VietFood67, và nhãn "không có" suy từ công thức món (ảnh phở thì chắc chắn
  không có bì, chả trứng).
- Masked loss: ảnh không có nhãn thành phần thì không tính loss ở đầu thành
  phần, để "không biết" không bị học thành "không có".
- Ngưỡng tick thành phần chọn trên tập val sao cho độ chính xác từ 85%; danh
  sách món được tin phần thành phần cũng chọn trên val (ít nhất 20 ảnh, F1
  từ 0,7). Notebook ghi các số này vào `MODEL_CARD.md`.
- Xuất TFLite, lượng tử hóa int8 theo dynamic range (chỉ trọng số).
  Notebook tự chạy lại file TFLite và so với Keras trước khi lưu.
- Trong app (`tflite_flutter`): xoay ảnh theo EXIF, cắt vuông ở giữa, thu về
  N×N (N đọc từ file model), chạy trên isolate riêng. App đọc ngưỡng từ
  `MODEL_CARD.md`, nên đổi model không phải sửa code.

### 2.3. Detector YOLO: tìm từng món trên đĩa

- Vì sao: một đĩa tự gắp (cơm trắng và ức gà) không phải món nào trong 91
  món, nên model trên đoán thành "Cà ri gà 49%". Cần model khoanh từng thứ
  trên đĩa. Kế hoạch ban đầu để YOLO ở tuần 5 đến 7 (16/11 đến 06/12); thực
  tế bắt đầu từ 24/10.
- 21 lớp, mỗi lớp ứng với một thành phần sẵn có trong bảng dinh dưỡng (cơm,
  gà, heo, bò, cá, trứng, rau…). Trứng, chả giò, bánh mì đếm theo số khung.
- Các bản đã thử:

  | Bản | Model | Kết quả chính |
  |---|---|---|
  | 25/10 | YOLO11n 640 px, VietFood67 + MyFood | test mAP50 0,832; trên 459 ảnh cơm phần chỉ tìm ra 28% món |
  | 27/10 | YOLO11n, thêm FoodInsSeg | cơm phần 48% |
  | 27/10 | YOLO11s 512 px, thêm khung do Grounding DINO tự khoanh trên 9.094 ảnh món Việt | cơm phần 52,7% (ngưỡng 0,38); chạy được trên điện thoại bản float32 |
  | 01/11 (v17, đang dùng) | YOLO11s, gộp khung từng miếng, ngưỡng riêng từng lớp | test mAP50 0,748; cơm phần 56,2% món, 183 báo sai |

  Bộ 459 ảnh cơm phần (phần test của FoodInsSeg, 778 món) là phép đo sát với
  cách app dùng: mỗi ảnh tính món nào có, món nào báo nhầm. Bản `.pt` đạt
  56,4% (439/778); bản float16 trong app đạt 56,2% (437/778).
- Bản INT8 của YOLO11s làm treo màn quét với `tflite_flutter` 0.12.1. App
  thêm giới hạn 8 giây cho detector rồi chuyển sang float16 tự viết
  (`tool/train/tflite_to_fp16.py`): 37,9 MB xuống 19,1 MB, cùng kết quả với
  float32 trên cả 459 ảnh.
- Trên điện thoại, detector float16 mất 158 đến 184 ms một ảnh (float32 mất
  339 ms).
- Màn kết quả quét chạy cả hai model cùng lúc. Detector thấy món nào thì vẽ
  khung và tên lên ảnh, dựng sẵn "Đĩa có N món". Model món chắc chắn và mọi
  món detector thấy đều thuộc món đó (ví dụ cơm tấm) thì giữ món, vì công
  thức món có cả nước mắm, mỡ hành.
- Chỗ yếu còn lại: gà chỉ tìm ra 62/144 ảnh, heo 9/61. Trong 339 món bị sót,
  182 món là thịt; 87 món thịt model đã thấy nhưng gọi sai loại.

Cách làm:
- Dùng Ultralytics YOLO11, bắt đầu từ trọng số đã train trên COCO.
- Dữ liệu khung: khung có sẵn của VietFood67 đổi về 21 lớp; mặt nạ của MyFood
  đổi ra khung; FoodInsSeg (FoodSeg103 có khung từng miếng). Ảnh có khung
  cả món (phở, cơm tấm) bị bỏ, vì cơm, trứng bên trong không được khoanh
  riêng.
- Không đủ người vẽ khung, nên dùng cách "model lớn dạy model nhỏ": Grounding
  DINO (model lớn, tìm vật theo câu chữ) tự khoanh khung trên ảnh món Việt
  chỉ có nhãn món. Detector cũ kiểm tra lại: khung điểm thấp chỉ giữ khi
  detector cũng thấy đồ ăn ở đó. Khung tự động chỉ vào tập train; tập val và
  test giữ khung người vẽ.
- Các bộ vẽ khung khác nhau (bộ vẽ từng lát dưa leo, bộ vẽ cả đống), nên
  notebook gộp các miếng cùng loại nằm sát nhau thành một khung.
- Ngưỡng riêng từng lớp chọn trên tập val theo F1, ghi vào
  `DETECTOR_CARD.md`.
- Trong app: letterbox ảnh về 512×512, chạy model, giải mã đầu ra
  `[1, 25, A]`, NMS theo từng lớp, rồi đổi mỗi lớp thành một dòng thành phần
  có dinh dưỡng trong CSV.
- Cách đo trên 459 ảnh cơm phần: với mỗi ảnh, so tập món model báo với tập
  món có thật; đếm món tìm ra và món báo nhầm. Đây là đúng thứ người dùng
  thấy trên màn kết quả.
- Bản float16: script đọc file float32, lưu trọng số dạng float16 và thêm
  bước giải nén về float32 khi nạp, nên đầu vào, đầu ra không đổi.

### 2.4. Hạ tầng train

- Notebook viết từ file `.py` rồi sinh `.ipynb`, có smoke test trên dữ liệu
  giả (`tool/train/test/`). Chạy được trên Kaggle (2 GPU T4) và Colab.
- Colab miễn phí ngắt sau khoảng 5 giờ, Kaggle sau 12 giờ. Notebook tự dừng
  trước giới hạn, lưu tiến độ, lần sau train tiếp; đã train tiếp qua nhiều
  tài khoản Google.
- Các lỗi đã sửa trong lúc train thật: loss thành NaN ở epoch 6 trên 2 GPU
  (thêm cơ chế quay lại epoch tốt), không bao giờ âm thầm train lại từ đầu
  khi đã có tiến độ, hết bộ nhớ GPU ở bước chọn ngưỡng, đọc 171.619 nhãn
  VietFood67 trên Kaggle từ 158 phút xuống 2,7 phút.
- Thu nhỏ ảnh một lần trước khi train: MobileNetV3 từ khoảng 15 phút xuống 2
  phút mỗi epoch.
- Kết quả mọi lần train lưu trong `docs/ket_qua_model/`.

## 3. Dữ liệu dinh dưỡng món Việt có nguồn

Trước: 160 nguyên liệu tên tiếng Anh, trong đó chỉ 9 món tinh bột; không có
món Việt.

Sau (`assets/data/vn_food/`):
- `dish_names.csv`: 91 món (65 món Việt và món phổ biến, cộng 26 món ăn hằng
  ngày như cơm trắng, ức gà, pizza, sushi).
- `components.csv`: 104 dòng thành phần và dòng nền (nước dùng, nước chấm),
  dòng nào cũng có nguồn.
- `dishes.csv`: 204 dòng khẩu phần mặc định của từng món.
- `food_variants.csv`: 74 biến thể gà, heo, bò, trứng, cá, cơm và tinh bột
  theo phần, da, cách nấu. Ví dụ cùng 100 g gà: cánh nướng cả da 254 kcal,
  ức sống 120 kcal.
- `meal_plan.csv`: món nào hợp bữa nào, hợp mục tiêu nào.

Nguồn số liệu theo thứ tự ưu tiên: Viện Dinh dưỡng Quốc gia (bảng thành phần
thực phẩm Việt Nam), rồi USDA FoodData Central. Món là hỗn hợp (nước chấm, mỡ
hành, chả trứng, vỏ bánh xèo) thì tính theo công thức nấu bằng
`tool/vn_food_recipes.py`, ghi rõ là ước lượng. Công thức được đối chiếu lại
với bài gốc; ví dụ chả trứng bài gốc ghi 20 g gia vị, chatbot ghi 52 g, nhóm
lấy theo bài gốc.

Kiểm tra chéo với công cụ tra món ăn của Viện Dinh dưỡng:

| Món | App tính | Viện Dinh dưỡng |
|---|---|---|
| Phở bò | 480 kcal | 350 đến 450 kcal |
| Bún chả | 809 kcal | 520 đến 750 kcal |
| Hủ tiếu | 292 kcal | khoảng 450 kcal |

Hủ tiếu thấp vì nước dùng đang là ước tính thấp. `tool/check_vn_food.py` kiểm
tra mọi dòng có nguồn, calo khớp 4·đạm + 4·bột đường + 9·béo, mã khớp
contract; CI chạy script này cho mọi PR.

Cách làm:
- Với mỗi thành phần, tra công cụ của Viện Dinh dưỡng; không có thì tra USDA.
  Cột `source` ghi mã thực phẩm cụ thể (ví dụ USDA FNDDS 2705996 cho gà
  chiên), dòng nào là gần đúng thì ghi lý do.
- Món hỗn hợp: lấy công thức nấu (gram từng nguyên liệu, khối lượng thành
  phẩm), cộng dinh dưỡng các nguyên liệu theo số của Viện Dinh dưỡng rồi chia
  cho khối lượng thành phẩm, ra số trên 100 g. Hai chatbot chỉ dùng để liệt
  kê công thức, không lấy số calo của chatbot.
- Trừ phần không ăn được: ví dụ miếng sườn 120 g có xương, theo USDA phần ăn
  được 75%, nên tính 90 g.
- Khẩu phần mặc định là một suất bình thường ở quán do nhóm ước lượng, rồi so
  với số theo suất của Viện Dinh dưỡng như bảng trên.

## 4. Thuật toán gợi ý

Gợi ý thực đơn:
- Trước: Branch & Bound chỉ cắt nhánh theo protein, giới hạn 1,5 giây mỗi bữa,
  chọn từ 160 nguyên liệu. Báo cáo NLCSN: đạt ràng buộc 10/10 lần thử,
  Greedy 0/10.
- Sau: bữa sáng ăn nguyên món (phở, bánh mì, xôi…); trưa và tối là món nguyên
  hoặc cơm phần do Branch & Bound ghép (cơm, 1 đến 2 món mặn, rau, canh).
  Đang giảm cân thì không gợi ý phở, bánh mì, cơm tấm, cơm tính theo gram.
- Thêm cận dưới theo calo. Giới hạn đổi từ thời gian sang tối đa 300.000 nút
  và seed, nên cùng seed máy nào cũng ra cùng thực đơn. Một thực đơn cả ngày
  mất khoảng 0,7 đến 1,2 ms.
- Đo trên 150 hồ sơ mỗi mục tiêu (calo trong ±5%, protein từ −10% đến +20%):

  | Mục tiêu | Đạt mục tiêu | Số nút: chỉ cận protein | Thêm cận calo |
  |---|---|---|---|
  | Giảm cân | 100/150 | 18.315 | 12.602 |
  | Giữ cân | 150/150 | 6.906 | 3.370 |
  | Tăng cân | 150/150 | 7.878 | 3.965 |

  Thêm cận calo giảm số nút 1,5 đến 2 lần mà kết quả giống hệt ở 150/150 hồ
  sơ.
- Cách làm cận calo: ở mỗi nút, lấy calo ít nhất và nhiều nhất mà các nhóm
  món còn lại có thể thêm vào, suy ra sai số calo nhỏ nhất còn đạt được. Cộng
  với cận protein cũ mà vẫn không tốt hơn lời giải đang có thì cắt nhánh đó.
  Món nguyên tốt nhất dùng làm lời giải ban đầu.
- Số đo trên lấy bằng `dart run tool/bench_meal_planner.dart`: 150 hồ sơ mỗi
  mục tiêu (2 giới, 5 mức cân nặng, 3 mức vận động, 5 seed), chạy có và
  không có cận calo rồi so.

Bài tập:
- Trước: 96 bài, chỉ 7 bài Beginner, 0 bài Pro, nên người chọn Beginner hay
  Pro gần như luôn nhận bài Intermediate. Shrug và máy khép, mở đùi không bao
  giờ được gợi ý.
- Sau: gán lại cấp cho 42 bài, còn 38 Beginner, 49 Intermediate, 9 Pro. Nhóm
  duyệt từng dòng (`docs/CAP_DO_BAI_TAP.md`).

Progressive Overload:
- Trước: chỉ xét buổi vừa tập.
- Sau: chỉ tăng 2,5 kg khi hai buổi liền nhau cùng mức tạ đều đạt 3×12 với độ
  khó Dễ hoặc Vừa. Bài không tạ thì khuyên thêm 2 lần mỗi hiệp. Đạt 3×12
  nhưng chọn "Kiệt sức" thì giữ mức tạ, không giảm như trước.

TDEE theo dữ liệu thật (mới): từ calo đã ghi và độ dốc cân nặng trong 4 tuần
(bình phương tối thiểu, 7700 kcal/kg). Cần ít nhất 10 ngày ghi ăn và 3 lần
cân. Lệch quá 30% dưới hoặc 40% trên so với công thức Mifflin-St Jeor thì app
cảnh báo và không cho dùng làm mục tiêu.

## 5. Giao diện

- Điều hướng: trước có 5 tab, chữ "Tập luyện" bị xuống dòng. Nay thanh dưới
  là Hôm nay, Ăn uống, nút Quét ở giữa, Tập luyện, Hồ sơ; các màn cùng nhóm
  gộp bằng tab con.
- Màn Hôm nay (mới): vòng cung calo, phần trăm carb, protein, béo, 8 ly nước,
  chuỗi ngày ghi ăn, tổng kết 7 ngày.
- Nhật ký ăn (mới): ghi theo bữa, tìm món không cần gõ dấu, yêu thích, gần
  đây, "ăn giống hôm qua", chép bữa sang hôm nay, gom các thành phần của một
  lần quét thành một dòng.
- Quét món: camera ngay trong app, khung ngắm canh đúng tâm ảnh model đọc,
  chạm để lấy nét, ảnh 1080p. Màn kết quả có thanh tổng cố định ở đáy, nút
  khẩu phần ×½ đến ×2, chọn phần và cách nấu cho thịt, cá, trứng, cơm.
- Tập luyện: hiện kết quả buổi trước dưới mỗi bài, đồng hồ nghỉ 90 giây.
- Hồ sơ: số mục tiêu lên đầu, công thức để sau nút (i), mức vận động ghi theo
  số buổi tập mỗi tuần.
- Ngôn ngữ Việt và Anh (`flutter gen-l10n`), số theo locale (1.800,5 và
  1,800.5).
- Vẫn 4 giao diện như NLCSN, nhưng đổi tên theo màu (Xanh lơ, Xanh dương,
  Xanh lá, Cam) và bỏ tên liên quan Cyberpunk. Nút Quét đổi hình theo từng
  giao diện. Font Be Vietnam Pro đóng sẵn trong app.
- Mỗi lần sửa giao diện, `tool/ui_screenshots` vẽ các màn ra PNG ở 4 giao
  diện và ở máy nhỏ 360 px chữ ×1,3 (35 ảnh). Lần rà ngày 28/10 sửa 13 lỗi,
  gồm vùng bấm dưới 48 dp, độ tương phản icon nút Quét (khoảng 1,4:1, dưới
  mức 3:1), nhãn cho trình đọc màn hình.

Cách làm:
- Camera dùng plugin `camera` (CameraX). Vạch quét là fragment shader của
  Flutter; vòng cung calo vẽ bằng `CustomPainter`.
- Chuỗi hiển thị nằm trong `lib/l10n/app_vi.arb` và `app_en.arb`, sinh code
  bằng `flutter gen-l10n`.
- Ảnh các màn vẽ bằng golden test của Flutter với font thật, chạy trên máy
  tính, không cần điện thoại. Agent `ui-reviewer` rà code theo 10 quy tắc
  giao diện (màu theo theme, số liền đơn vị, vùng bấm 48 dp…).

## 6. Thông báo, widget, sao lưu

NLCSN không có các phần này.
- Nhắc ghi bữa lúc 8:00, 12:30, 19:30, đổi được giờ. Không cần quyền báo thức
  chính xác.
- Nhắc uống nước mỗi 1 đến 4 tiếng trong khung giờ tự chọn, 5 câu nhắc không
  lặp liền nhau, uống đủ 2.000 ml thì thôi nhắc trong ngày.
- Widget màn hình chính: calo đã ăn so với mục tiêu, nước uống, chuỗi ngày.
- Sao lưu ra file JSON để chia sẻ qua Drive hay Zalo; khôi phục có hỏi xác
  nhận và chạy trong một transaction. File sai bị từ chối, dữ liệu hiện có
  giữ nguyên.
- Gom ảnh của chính người dùng để dạy model (mặc định tắt): ảnh nằm trong
  máy, chỉ rời máy khi người dùng tự xuất file zip.

Cách làm:
- Thông báo dùng `flutter_local_notifications`, kiểu hẹn giờ không chính
  xác tuyệt đối. Android không có thông báo lặp mà mỗi lần đổi chữ, nên app
  hẹn sẵn từng lần nhắc uống nước cho 7 ngày tới và hẹn lại mỗi lần mở màn
  Hôm nay.
- Widget dùng gói `home_widget` cộng một `AppWidgetProvider` viết bằng Java;
  app cập nhật số liệu mỗi lần màn Hôm nay tải lại.
- Sao lưu xuất mọi bảng SQLite ra JSON rồi mở bảng chia sẻ của Android
  (`share_plus`); khôi phục chọn file bằng `file_picker`, kiểm tra tên app,
  phiên bản, bảng và cột trước khi ghi.

## 7. Đổi tên, applicationId, logo

- applicationId: `com.example.nlcsn` thành `io.github.jimeavv.optifit` (17/10).
  Bản cài với ID cũ phải gỡ một lần.
- Tên hiển thị: OptiFit thành MacroRunner (22/10) ở tên dưới icon, thanh đầu
  app, thông báo, widget. Trong code vẫn giữ package `optifit` và
  applicationId, vì đổi applicationId thì Android coi là app khác và người
  dùng mất dữ liệu.
- Logo tự vẽ bằng code (`tool/brand/make_logo.py`): chữ M bằng đường nhịp
  tim. Có icon thích ứng (kèm lớp đơn sắc cho Android 13 trở lên) và icon
  thông báo màu trắng.
- Repo riêng cho NLCN: <https://github.com/JimeaVV/nlcn>, giữ toàn bộ lịch
  sử commit từ NLCSN.

## 8. CI, build và ký app

- CI bằng GitHub Actions, chạy cho mọi PR vào `main`: kiểm tra file dịch,
  `flutter analyze`, `flutter test`, `check_vn_food.py`. `main` được bảo vệ,
  CI chưa xanh thì không gộp được.
- Workflow release build APK, kiểm tra chữ ký đúng khóa OptiFit, đăng lên
  GitHub Release `latest`. Build number bằng 100 cộng số lần chạy, nên bản
  sau luôn cài đè được bản trước.
- Khóa ký: trước là khóa debug, mỗi máy một khóa, APK máy này không cài đè
  được bản máy khác. Nay là khóa RSA 2048 riêng, lưu ngoài repo.
- Dung lượng APK arm64:
  - 19,9 MB lúc đầu NLCN; 39,4 MB sau khi thêm LiteRT;
  - 17,2 MB sau khi bỏ thư viện GPU và nén thư viện native;
  - tăng dần theo model: B3 24,1 MB, thêm detector YOLO11s float32 61,2 MB,
    detector float16 43,3 MB (APK 139).
- Số test Flutter: 6 (báo cáo NLCSN), 76 lúc bắt đầu NLCN, 250 hiện nay.
- Repo có `CLAUDE.md`, skill và agent cho Claude Code (build APK, chụp giao
  diện, rà contract, rà giao diện) để cả hai người dùng chung quy tắc. Việc
  dùng AI hỗ trợ lập trình được ghi rõ trong báo cáo.

Cách làm:
- `.github/workflows/ci.yml` chạy trên máy Ubuntu sạch, cùng Flutter 3.44.4
  với máy phát triển. Branch protection đặt 2 job CI làm điều kiện bắt buộc
  trước khi gộp.
- `.github/workflows/release.yml` lấy khóa ký từ GitHub Secrets, build APK,
  dùng `apksigner` so SHA-256 chứng chỉ với `RELEASE_CERT_SHA256`, sai thì
  dừng.
- Giảm dung lượng APK: bỏ `libtensorflowlite_gpu_jni.so` (app chạy model
  trên CPU) và bật nén thư viện native (`useLegacyPackaging`) trong
  `android/app/build.gradle.kts`.

## 9. Đang làm, chưa vào app

Ba việc dưới đây nằm trên nhánh riêng, chưa gộp vào nhánh chính, nên APK
hiện tại chưa có.

Model phân loại thịt chạy sau detector (nhánh
`claude/meat-crop-classifier-a296a9`):
- MobileNetV3Large 224 px, 8 lớp (7 loại thịt và `khac`), 6,0 MB float16,
  train trên Kaggle 62 phút.
- Đúng 80,2% trên tập crop test (heo thấp nhất, 63,9%).
- Gộp với detector trên 459 ảnh cơm phần: tìm ra 59,5% món (detector một
  mình 56,2%), báo sai 200 (trước 183).
- Trên điện thoại: 31 ms một khung thịt.
- Cách làm: cắt khung thịt từ chính dữ liệu train của detector, train một
  model phân loại nhỏ. Trong app, detector khoanh khung trước, rồi
  classifier xem lại từng khung thịt; hai model bỏ phiếu bằng điểm
  detector^0,5 × điểm classifier. Khung thịt detector chấm hơi thấp (từ 0,20)
  được giữ lại nếu classifier chắc từ 0,60.

Chế độ nhận diện online bằng Gemini (nhánh `claude/gemini-compare-89d8c2`):
- Trên cùng 459 ảnh cơm phần, Gemini 3.5 Flash-Lite tìm ra 76,5% món, báo sai
  282. Detector hạ ngưỡng tới cùng mức báo sai chỉ tìm ra 65,6%.
- Đổi lại Gemini cần mạng, mất 2,4 giây mỗi ảnh (detector khoảng 0,2 giây),
  gửi ảnh lên Google, và gói miễn phí giới hạn 500 ảnh mỗi ngày.
- Đã làm thành chế độ "dev test" tùy chọn: offline vẫn là mặc định, kcal vẫn
  lấy từ CSV. Bản này phải thêm quyền INTERNET và đóng key vào APK, nên chỉ
  gửi cho người thử.
- Cách làm: script `tool/eval/gemini_compare.py` gửi từng ảnh lên Gemini, bắt
  trả JSON chỉ gồm 21 lớp của detector, rồi chấm theo ảnh y như detector.
  Câu lệnh viết một lần trước khi chạy, không sửa theo kết quả test.

Detector v18 thêm ảnh đĩa (nhánh `claude/detector-weak-classes-data-5f855b`):
- Thêm 2.203 ảnh đĩa từ MyFoodRepo và Nutrition5k cho gà, heo, bò, rau.
- Trên 459 ảnh cơm phần: v18 tìm ra 55,8%, v17 56,4%. Không hơn, nên app giữ
  v17. Có lẽ vì ảnh mới là món kiểu Âu, thịt trông khác hẳn trong cơm phần.

## 10. Việc còn tồn đọng

- Detector mới tìm ra khoảng 56% món trên ảnh cơm phần; heo (9/61) và gà
  (62/144) yếu nhất. Chưa có bộ ảnh cơm phần Việt Nam nào có khung từng món.
- Quyết định có gộp model phân loại thịt và chế độ Gemini vào app hay không.
- Tập test chưa có ảnh tự chụp, trong khi contract yêu cầu ít nhất 30%. Điểm
  test của model 1.5 có thể cao hơn thực tế vì ảnh được chia lại.
- Chưa ước lượng số gam từ diện tích khung, vì cần biết cỡ đĩa thật.
- Khối lượng một đơn vị (chén cơm, miếng sườn…) và khẩu phần mặc định là ước
  lượng của nhóm, chưa cân thực tế. Nước dùng đang là ước tính thấp.
- Gộp 2 commit của `feature/contract-1.5` vào `main`.
- Đồng hồ nghỉ giữa hiệp chưa có thông báo khi app chạy nền.
- Điền tên Người B vào `docs/PHAN_CONG.md`.

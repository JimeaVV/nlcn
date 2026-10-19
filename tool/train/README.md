# Train model nhận diện món ăn (Người B)

Notebook `train_food_model.ipynb` gộp 4 bộ ảnh công khai thành một tập train,
train model hai đầu ra theo `docs/MODEL_CONTRACT.md` (contract 1.3), rồi xuất
4 file app cần: `food_v1.tflite`, `dishes.txt`, `components.txt`,
`MODEL_CARD.md`.

Code gốc là `train_food_model.py`. Sửa file đó, rồi chạy
`python tool/train/make_notebook.py` để sinh lại `.ipynb`.

## Chạy trên Kaggle (khuyên dùng)

1. Tài khoản Kaggle đã xác minh số điện thoại (bắt buộc để dùng GPU).
2. *Create → New Notebook → File → Import Notebook*, chọn
   `train_food_model.ipynb`.
3. *Add data*, thêm 4 bộ ảnh:

   | Bộ ảnh | Trên Kaggle | Trùng món của app (đếm ở contract 1.2) | License |
   |---|---|---|---|
   | VinaFood21 | `sonbui25/vinafood21` | 21 | xem lại trang dataset |
   | 30VNFoods | `quandang/vietnamese-foods` | 14 | MIT |
   | 20FoodVN | `lnguynanhnht/20foodvn` | 12 | Apache 2.0 |
   | VietFood67 | `thomasnguyen6868/vietfood68` | 17 món + khoảng 15 thành phần (1.3: 24 món) | CC BY-NC-SA 4.0, phải trích 2 bài báo |

   Contract 1.3 thêm 12 món nên số món trùng tăng lên. Khi chạy, notebook in
   số ảnh lấy được từ từng bộ.

4. *Settings*: Accelerator **GPU T4 x2**, Internet **On**.
5. Chạy thử với `QUICK_TEST = True` (vài phút) để chắc không lỗi.
6. Đặt `QUICK_TEST = False`, rồi **Save Version → Save & Run All**.
   - Tắt trình duyệt vẫn chạy.
   - Xong thì vào tab *Output* tải 4 file, bỏ vào `assets/models/` và mở PR.

## Notebook làm gì

- **Đổi tên lớp sang mã của app:** so tên đã bỏ dấu, nên "Bánh Mì",
  "banh_mi" và "Banh mi" là một lớp. Phở bò và gà gộp chung một lớp thì
  mặc định bỏ (`MIXED_PHO`).
- **Lớp `khac` (món app chưa có):** ảnh của lớp app không có (gỏi ngó sen,
  lẩu, hamburger…) gộp vào lớp `khac`, tối đa `MAX_OTHER` ảnh. Lớp này là
  dòng cuối của `dishes.txt`. App không bao giờ đưa `khac` ra làm gợi ý; khi
  xác suất của nó cao, app báo "món này chưa có trong app". Đặt
  `USE_OTHER = False` để bỏ lớp này.
- **VietFood67 có khung**, nên suy ra được nhãn thành phần:
  - khung "Cơm", "Thịt kho", "Trứng"… thành `com`, `thit_kho`, `trung_*`;
  - ảnh chỉ có cơm và món mặn, không có khung tên món, là **cơm phần**;
  - ảnh có 2 món khác nhau thì bỏ;
  - "Trứng", "Chả", "Rau" được đổi theo món chứa nó (cơm tấm thành trứng ốp
    la, chả trứng…).
- **Thành phần không biết thì không tính là "không có":** ảnh chỉ có nhãn
  món, loss của phần thành phần bỏ qua ảnh đó (masked loss).
- **Bỏ ảnh trùng** giữa các bộ (average hash) và chia 70/15/15 theo từng
  món. Danh sách chia nằm trong `splits.csv`.
- **Ba thí nghiệm cho báo cáo:** đổi `EXPERIMENT` thành `scratch`, `linear`
  hoặc `finetune`; đổi `BACKBONE` thành `mobilenetv3` hoặc
  `efficientnetv2b0`. Kết quả mỗi lần chạy nằm trong `results.json` và
  `training_log_*.csv`.
- **Ngưỡng tick thành phần** được chỉnh trên tập val và ghi vào
  `MODEL_CARD.md`; app đọc từ đó.

## Ảnh tự chụp

Tạo một dataset Kaggle riêng gồm `labels.csv` (định dạng ở contract mục 5)
và thư mục `images/`, rồi *Add data* như 4 bộ kia. Notebook tự nhận ra file
`labels.csv`. Bốn món không bộ nào có, phải tự chụp: **cơm phần, cơm gà,
cháo gà, phở gà**.

## Đã kiểm tra

Chạy thử trên máy với dữ liệu giả, mô phỏng đủ 4 kiểu thư mục:
- lớp tên tiếng Việt có dấu, lớp app không có (vào `khac`), ảnh
  VietFood67 có khung, ảnh có 2 món, ảnh `.webp`;
- file `.tflite` xuất ra qua được test `food_model_test.dart` của app (mã
  món và thành phần khớp bảng dinh dưỡng).

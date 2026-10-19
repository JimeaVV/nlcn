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
   - Phải thấy dòng `GPUs: 2 | training on 2 device(s)`: notebook chia mỗi
     batch cho cả 2 GPU (`MirroredStrategy`).
   - `BATCH` là tổng của cả 2 GPU, nên chạy trên 1 GPU cũng học giống
     vậy và kết quả vẫn so sánh được.
   - Nếu phiên nháp cứ báo "Draft Session Adding data" mãi: bỏ qua phiên
     nháp. Để `QUICK_TEST = True`, bấm **Save Version → Save & Run All**.
     Bản chạy này tự chạy trên một máy riêng của Kaggle, xong thì xem log
     ở trang version.
6. Đặt `QUICK_TEST = False`, rồi **Save Version → Save & Run All**.
   - Tắt trình duyệt vẫn chạy.
   - Xong thì vào tab *Output* tải 4 file, bỏ vào `assets/models/` và mở PR.

## Chạy trên Google Colab

Colab hiện log ngay lúc chạy. Ảnh được tải về ổ cứng của máy Colab nên đọc
nhanh hơn ổ mạng của Kaggle. Đổi lại, Colab chỉ có 1 GPU T4, và phải để mở
tab trình duyệt.

1. Mở [colab.research.google.com](https://colab.research.google.com),
   chọn *File → Upload notebook*, rồi chọn `train_food_model.ipynb`.
2. *Runtime → Change runtime type → T4 GPU*.
3. Lấy token Kaggle: kaggle.com → *Settings → API Tokens → Generate New
   Token*. Token có dạng `KGAT_...` và chỉ hiện một lần.
4. Trong Colab, bấm biểu tượng chìa khóa (*Secrets*) ở thanh bên trái:
   - thêm secret tên `KAGGLE_API_TOKEN`, dán token vào phần giá trị;
   - bật *Notebook access*.

   Nếu dùng key kiểu cũ (`kaggle.json`, nút *Create Legacy API Key*), thêm
   `KAGGLE_USERNAME` và `KAGGLE_KEY` thay cho `KAGGLE_API_TOKEN`.

   Key nằm trong Secrets của tài khoản Google, không ghi vào notebook.
5. *Runtime → Run all*:
   - Notebook tự tải 4 bộ ảnh bằng `kagglehub`. VietFood67 nặng 26 GB, nên
     lần đầu mất khoảng 10–20 phút.
   - Colab hỏi quyền Google Drive: cho phép. Kết quả lưu ở Drive, thư mục
     `macrorunner_train`, nên rớt kết nối cũng không mất.
6. Chạy thử xong thì đặt `QUICK_TEST = False`, rồi *Run all* lại **trong
   cùng phiên** để khỏi tải lại 26 GB.
   - Đừng đóng tab.
   - Bản Colab miễn phí tự ngắt nếu để yên lâu không thao tác.

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
  - Mỗi món chỉ mở vừa đủ số ảnh cần lấy (`MAX_PER_DISH`), đọc song song
    32 luồng. Dòng `Opened … of … photos` cho biết đã mở bao nhiêu ảnh.
- **Ba thí nghiệm cho báo cáo:** đổi `EXPERIMENT` thành `scratch`, `linear`
  hoặc `finetune`. Kết quả mỗi lần chạy nằm trong `results.json` và
  `training_log_*.csv`.
- **Ngưỡng tick thành phần** được chỉnh trên tập val và ghi vào
  `MODEL_CARD.md`; app đọc từ đó.

## So sánh 3 backbone, chọn model cho app

Train cùng một notebook 3 lần (`EXPERIMENT = 'finetune'`), mỗi lần một
`BACKBONE`:

| `BACKBONE` | Tham số | TFLite (float16) | Ghi chú |
|---|---|---|---|
| `mobilenetv3` | khoảng 4 triệu | khoảng 6 MB | nhẹ nhất, nhanh nhất |
| `efficientnetb0` | khoảng 5 triệu | khoảng 8 MB | |
| `efficientnetv2b0` | khoảng 7 triệu | khoảng 12 MB | |

- Cả 3 bản chạy dùng chung cách chia dữ liệu (seed cố định), nên so với
  nhau được.
- Trên Colab, mỗi bản chạy ghi vào một thư mục riêng trên Drive, ví dụ
  `macrorunner_train/efficientnetb0_finetune`.

Tải thư mục kết quả của cả 3 về máy, rồi chạy:

```
python tool/train/compare_results.py runs/mobilenetv3 runs/efficientnetb0 runs/efficientnetv2b0 --out runs/comparison.md
```

Cách chọn:
- Lấy model có **val top-1** cao nhất. Tập test chỉ để báo cáo, không dùng
  để chọn, để con số trên test vẫn khách quan.
- Nếu các model lệch nhau không quá 0,5 điểm %, lấy model nhỏ hơn, vì nó
  mở nhanh hơn và chạy nhanh hơn trên điện thoại.
- Bảng in ra có thêm top-3, F1 thành phần, dung lượng, tốc độ trên CPU của
  máy train (chỉ để so tương đối) và thời gian train.
- Bản chạy cũ chưa ghi val vào `results.json` thì script lấy val từ
  `training_log_*.csv`.

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

# MacroRunner – hướng dẫn cho Claude

App Android chạy offline: gợi ý thực đơn, bài tập, Progressive Overload, và
chụp ảnh món ăn để nhận diện món, ước lượng dinh dưỡng. Đồ án NLCN, nhóm 2
người (phân công ở `docs/PHAN_CONG.md`):

- **Người A** (JimeaVV): app Flutter và dữ liệu dinh dưỡng.
- **Người B**: train model nhận diện món ăn.

Tên trong code vẫn là OptiFit: package `optifit`, applicationId
`io.github.jimeavv.optifit`. File APK đặt tên `MacroRunner-...apk`.

## Cấu trúc
- `lib/`: app Flutter.
  - `screens/`: các màn hình.
  - `services/`: database, đọc dataset, model nhận diện.
    - `food_model.dart`: đọc `MODEL_CARD.md` và các file nhãn.
    - `tflite_food_recognizer.dart`: chạy model TFLite.
  - `engine/`: thuật toán gợi ý.
  - `l10n/`: bản dịch, sinh bằng `flutter gen-l10n`.
- `assets/models/`: model app đang dùng: `food_v1.tflite`, `dishes.txt`,
  `components.txt`, `MODEL_CARD.md`.
- `assets/data/vn_food/`: CSV món Việt, thành phần và khẩu phần, có nguồn.
- `tool/train/`: notebook train model.
  - Code gốc là `train_food_model.py`. File `.ipynb` được sinh từ đó.
  - Thử nhanh nằm trong `tool/train/test/`.
- `docs/MODEL_CONTRACT.md`: thỏa thuận giữa app và model (đang ở 1.4): danh
  sách món, thành phần, định dạng đầu vào và đầu ra, các dòng trong
  `MODEL_CARD.md`.
- `backend/`: bản Python gốc, chỉ giữ để tham khảo thuật toán. App không cần
  nó.

## Lệnh thường dùng
CI (`.github/workflows/ci.yml`) chạy các lệnh dưới đây; chạy đủ trước khi
commit code app:

```bash
flutter gen-l10n        # sau khi sửa lib/l10n/*.arb; CI báo lỗi nếu quên
flutter analyze
flutter test
python tool/check_vn_food.py   # sau khi sửa assets/data/vn_food hoặc DISHES
```

Notebook train:
- Sửa `tool/train/train_food_model.py`, rồi chạy
  `python tool/train/make_notebook.py` để sinh lại `train_food_model.ipynb`.
- Commit cả hai file.
- Kiểm tra bằng `python tool/train/test/smoke_test.py`. Cần Python có
  tensorflow 2.18 và pillow. Xem skill `train-notebook`.

Build APK cho điện thoại: xem skill `build-apk`.

## Quy tắc
- **Nhật ký:** mọi thay đổi đều ghi thêm một mục vào
  `docs/QUA_TRINH_THUC_HIEN.md`, bằng tiếng Việt, đặt trước dòng `---` của mục
  "3. Việc còn tồn đọng". Tiêu đề dạng `### YYYY-MM-DD · <việc đã làm>`, nội
  dung nêu vì sao, đã làm gì, đã kiểm tra thế nào. Nhật ký này dùng để viết
  báo cáo.
- **Commit:**
  - Tiêu đề tiếng Anh, thể mệnh lệnh, ngắn gọn, kèm một đoạn giải thích vì
    sao.
  - Không thêm `Co-Authored-By: Claude` vào commit, không thêm "Generated with
    Claude Code" vào PR.
  - Chỉ push hoặc merge khi được bảo.
- **Bí mật:** không đọc, in hay commit `android/key.properties`, keystore
  hoặc mật khẩu ký app.
- **Dinh dưỡng:** mọi số liệu phải có nguồn trong CSV. Số nào là ước lượng
  thì ghi rõ là ước lượng. `check_vn_food.py` kiểm tra phần này.
- **Contract:** đổi danh sách món, thành phần hay định dạng model thì phải
  cập nhật cùng lúc:
  - `docs/MODEL_CONTRACT.md` (tăng số phiên bản)
  - `DISHES` và `DISH_PARTS` trong notebook
  - các CSV trong `assets/data/vn_food`
  - `tool/vn_food_recipes.py`

  Rồi chạy `check_vn_food.py`. Agent `model-contract-reviewer` kiểm tra việc
  này.
- **Giao diện:** không dùng hình ảnh, tên hay thương hiệu của CD Projekt Red
  hoặc Cyberpunk: Edgerunners.
- **Điện thoại:** không chụp màn hình điện thoại khi chưa hỏi người dùng.
- **Train trên Kaggle hoặc Colab:** người dùng tự chạy. Claude chỉ chuẩn bị
  notebook và đọc log họ dán vào. Log Kaggle thường hiện trễ. Colab miễn phí
  ngắt sau khoảng 5 giờ; notebook tự dừng gọn và lần chạy sau train tiếp.

## Cách trả lời
Người dùng viết tiếng Việt, thường ngắn và kiểu nhắn tin. Trả lời bằng tiếng
Việt, rõ ràng, đưa con số cụ thể khi ước tính thời gian hay kết quả.

# Model nhận diện món ăn

Người B đặt model đã train vào thư mục này (docs/MODEL_CONTRACT.md mục 6):

- `food_v1.tflite`: model;
- `dishes.txt`: mỗi dòng một mã món, đúng thứ tự đầu ra `dish`;
- `components.txt`: mỗi dòng một mã thành phần, đúng thứ tự đầu ra `components`;
- `MODEL_CARD.md`: ngày train, dữ liệu, kết quả, và các ngưỡng, ví dụ
  `threshold_checked: 0.6`, `threshold_ask: 0.3`, `threshold_confident_dish: 0.5`.

Thư mục chưa có `food_v1.tflite` thì app tự chuyển về chọn món bằng tay.

Model phát hiện từng món trên đĩa (YOLO, contract mục 7, không bắt buộc), lấy
từ thư mục `export` của notebook `tool/train/train_detector.ipynb`:

- `detector.tflite`: model; bản `detector_int8.tflite` muốn dùng thì phải
  đổi tên thành `detector.tflite`;
- `detector_classes.txt`: mỗi dòng một lớp, đúng thứ tự đầu ra;
- `DETECTOR_CARD.md`: kết quả và các ngưỡng `threshold_box`,
  `threshold_iou`.

Thiếu các file này thì màn quét chỉ dùng model nhận diện món như cũ.

Model phân loại thịt (contract mục 9, không bắt buộc), lấy từ Output của
notebook `tool/train/train_meat_classifier.ipynb`. Nó xem lại từng khung thịt
detector tìm ra:

- `meat_classifier.tflite`: model;
- `meat_classes.txt`: mỗi dòng một lớp, đúng thứ tự đầu ra;
- `MEAT_CARD.md`: kết quả và các ngưỡng (`crop_pad`, `vote_power`,
  `box_floor`, `threshold_rescue`, `threshold_drop`), chọn bằng
  `tool/train/eval_meat_classifier.py` trên khung của detector đang dùng.

Thiếu các file này thì app giữ nguyên tên detector đặt.

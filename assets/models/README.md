# Model nhận diện món ăn

Người B đặt model đã train vào thư mục này (docs/MODEL_CONTRACT.md mục 6):

- `food_v1.tflite`: model;
- `dishes.txt`: mỗi dòng một mã món, đúng thứ tự đầu ra `dish`;
- `components.txt`: mỗi dòng một mã thành phần, đúng thứ tự đầu ra `components`;
- `MODEL_CARD.md`: ngày train, dữ liệu, kết quả, và các ngưỡng, ví dụ
  `threshold_checked: 0.6`, `threshold_ask: 0.3`, `threshold_confident_dish: 0.5`.

Thư mục chưa có `food_v1.tflite` thì app tự chuyển về chọn món bằng tay.

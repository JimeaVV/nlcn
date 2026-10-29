# MODEL_CARD – food_v1

- Ngày train: 2026-10-19
- Contract: 1.3 (52 món + lớp khac, 25 thành phần)
- Kiến trúc: mobilenetv3, thí nghiệm `finetune`
- Dữ liệu: 38677 train / 8287 val / 8287 test
- Nguồn ảnh: vietfood68: 29595, vinafood21: 12713, vietnamese-foods: 10801, 20foodvn: 2142
- Kích thước: 6.2 MB (float16)
- Thời gian train: 53 phút

## Kết quả trên tập test
- Món, top-1: 0.671
- Món, top-3: 0.822
- Thành phần, F1: 0.482

## Ngưỡng (app đọc các dòng này)
threshold_checked: 0.3
threshold_ask: 0.15
threshold_confident_dish: 0.5

## Hạn chế
- Tập test chưa có ảnh tự chụp: contract yêu cầu ít nhất 30%.
- Nhãn thành phần chỉ có ở ảnh VietFood67 và ảnh tự gán; các ảnh còn lại
  chỉ dạy phần đoán món.

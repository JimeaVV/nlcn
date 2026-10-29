# MODEL_CARD – food_v1

- Ngày train: 2026-10-21
- Contract: 1.4 (65 món + lớp khac, 25 thành phần)
- Kiến trúc: efficientnetb3 (300×300), thí nghiệm `finetune`, cách train `full`
- Dữ liệu: 70065 train / 14823 val / 14823 test
- Nguồn ảnh: vietfood68: 58999, vietnamese-foods: 23022, vinafood21: 13855, 20foodvn: 3835
- Kích thước: 21.8 MB (float16)
- Thời gian train: 630 phút

## Kết quả trên tập test
- Món, top-1: 0.860
- Món, top-3: 0.941
- Thành phần, F1: 0.468

## Ngưỡng (app đọc các dòng này)
threshold_checked: 0.7
threshold_ask: 0.4
threshold_confident_dish: 0.5
component_dishes: 

## Hạn chế
- Tập test chưa có ảnh tự chụp: contract yêu cầu ít nhất 30%.
- Nhãn thành phần chỉ có ở ảnh VietFood67 và ảnh tự gán; các ảnh còn lại
  chỉ dạy phần đoán món.

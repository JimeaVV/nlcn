# MODEL_CARD – food_v1

- Ngày train: 2026-10-22
- Contract: 1.5 (91 món + lớp khac, 25 thành phần)
- Kiến trúc: efficientnetb3 (300×300), thí nghiệm `continue`, cách train `full`
- Train tiếp từ: model contract 1.4 (checkpoint.keras)
- Dữ liệu: 105693 train / 22229 val / 22229 test
- Nguồn ảnh: vietfood68: 68464, food41: 39190, vietnamese-foods: 23021, vinafood21: 13802, 20foodvn: 3723, myfood: 1951
- Kích thước: 12.0 MB, bản int8 (lượng tử hóa trọng số) mà app dùng; bản
  float16 21.9 MB. Trên cùng mẫu ảnh test: int8 0.838, float16 0.839.
- Thời gian train: 196 phút (Colab hết giờ sau epoch 6/8; dùng epoch tốt nhất, val 0.873)

## Kết quả trên tập test
- Món, top-1: 0.870
- Món, top-3: 0.949
- Thành phần, F1: 0.577

## Ngưỡng (app đọc các dòng này)
threshold_checked: 0.55
threshold_ask: 0.25
threshold_confident_dish: 0.5
component_dishes: mi_quang, xoi, com_trang, dau_hu_chien

## Hạn chế
- Tập test chưa có ảnh tự chụp: contract yêu cầu ít nhất 30%.
- Nhãn thành phần chỉ có ở ảnh VietFood67 và ảnh tự gán; các ảnh còn lại
  chỉ dạy phần đoán món.
- Train tiếp từ model 1.4, nhưng ảnh chia lại vì có thêm bộ ảnh: một số ảnh
  test lần này model 1.4 đã thấy khi train, nên điểm test có thể cao hơn
  thực tế.

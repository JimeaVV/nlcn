# Kết quả các lần train model nhận diện món ăn

Mỗi thư mục con là một lần train thật (không tính các lần chạy thử
`QUICK_TEST`), tên theo dạng `<contract>_<cách train>_<backbone>`. Trong mỗi
thư mục có:

- `results.json`: toàn bộ số đo do notebook ghi ra. Mục `dish_accuracy` là
  độ chính xác top-1 của từng món trên tập test.
- `MODEL_CARD.md`: thẻ model lúc train xong, gồm nguồn ảnh và ngưỡng.
- `training_log_head.csv`, `training_log_fine.csv`: số đo sau từng epoch.

File model (`.tflite`, `.keras`) và `splits.csv` (ảnh nào thuộc tập nào) quá
nặng nên không đưa vào git. Bản đầy đủ nằm trên Google Drive, xem cuối trang.

## Bảng so sánh

| Lần train | Contract (số món) | Ảnh vào | Train / val / test | Val top-1 | Test top-1 | Test top-3 | F1 thành phần | TFLite float16 | int8 | Thời gian train |
|---|---|---|---|---|---|---|---|---|---|---|
| [EfficientNetB0](1.3_light_efficientnetb0) | 1.3 (52) | 224 | 38.677 / 8.287 / 8.287 | 69,0% | 68,8% | 83,9% | 0,497 | 8,3 MB | – | 55 phút |
| [EfficientNetV2-B0](1.3_light_efficientnetv2b0) | 1.3 (52) | 224 | 38.677 / 8.287 / 8.287 | 68,5% | 68,5% | 83,1% | 0,504 | 12,0 MB | – | 53 phút |
| [MobileNetV3, người A](1.3_light_mobilenetv3_nguoiA) | 1.3 (52) | 224 | 38.677 / 8.287 / 8.287 | 67,8% | 67,4% | 82,5% | 0,482 | 6,2 MB | – | 45 phút |
| [MobileNetV3, người B](1.3_light_mobilenetv3_nguoiB) | 1.3 (52) | 224 | 38.677 / 8.287 / 8.287 | 67,7% | 67,1% | 82,2% | 0,482 | 6,2 MB | – | 53 phút |
| [EfficientNetB3](1.4_full_efficientnetb3) | 1.4 (65) | 300 | 70.065 / 14.823 / 14.823 | 86,7% | 86,0% | 94,1% | 0,468 | 21,8 MB | 11,9 MB | 630 phút |
| [EfficientNetB3, train tiếp](1.5_continue_efficientnetb3) **(app đang dùng)** | 1.5 (91) | 300 | 105.693 / 22.229 / 22.229 | 87,6% | 87,1% | 95,0% | 0,589 | 21,9 MB | 12,0 MB | 261 phút |

Số món chưa tính lớp `khac` (món không có trong app). Mọi lần đều train trên
Colab hoặc Kaggle bằng GPU T4.

## Lần nào so được với lần nào

Chỉ so trực tiếp các lần **cùng contract và cùng cách train**, vì khi đó các
lần dùng cùng ảnh và cùng cách chia train / val / test (seed 42).

- **Nhóm contract 1.3, cách train `light`** (4 lần đầu): so sánh backbone
  trên cùng dữ liệu.
  - Chỉ fine-tune 40% lớp trên cùng của backbone, learning rate cố định, 15
    epoch.
  - EfficientNetB0 được chọn vì val top-1 cao nhất. Hai lần MobileNetV3 độc
    lập chỉ lệch nhau 0,1 điểm %, nên khoảng cách 1,1 điểm % (val) giữa B0 và
    MobileNetV3 là thật, không phải do may rủi.
- **EfficientNetB3, contract 1.4, cách train `full`**:
  - Fine-tune toàn bộ backbone, có warm-up và cosine learning rate, label
    smoothing, nhiều ảnh hơn cho mỗi món, 30 epoch.
  - Cao hơn nhóm 1.3 khoảng 17 điểm %. Nhưng phần chênh này đến từ cả ba
    thứ cùng lúc: backbone lớn hơn, cách train khác, và dữ liệu khác (13 món
    mới, gán nhãn "không có" theo công thức món). Vì vậy không thể nói B3 tốt
    hơn B0 17 điểm %.
  - F1 thành phần thấp hơn nhóm 1.3 vì ngưỡng tick chọn theo precision ≥
    85% (tick sai là ghi thêm món người dùng không ăn), không chọn theo F1.
- **EfficientNetB3 1.5**:
  - Train tiếp 8 epoch từ bản 1.4, có thêm 26 món, ảnh Food-101 và MyFood.
    Ảnh được chia lại, nên một phần ảnh test lần này model 1.4 đã thấy lúc
    train, và điểm test có thể cao hơn thực tế.
  - Không dùng để so backbone; chỉ cho biết model app đang dùng tốt cỡ nào.
- **CPU / ảnh** trong `results.json` đo trên máy Colab, mỗi phiên một máy
  khác, nên chỉ để so tương đối. Tốc độ thật phải đo trên điện thoại.

### Muốn so B0, MobileNetV3 với B3 cho công bằng

Train lại B0 và MobileNetV3 bằng **notebook contract 1.4**, giữ nguyên các
thiết lập sau:
- `RECIPE = 'full'`, `EXPERIMENT = 'finetune'`;
- cùng bốn bộ ảnh và seed 42.

Như vậy cách chia ảnh trùng với lần B3 1.4. Có thể kiểm tra bằng cách so
`splits.csv` của hai lần train.

Kết quả mới thì chép thư mục output vào đây (chỉ 4 file như trên), thêm một
dòng vào bảng, rồi chạy công cụ chọn model cho nhóm đó:

```bash
python tool/train/compare_results.py docs/ket_qua_model/1.4_full_efficientnetb3 docs/ket_qua_model/1.4_full_efficientnetb0
```

## Bản đầy đủ trên Google Drive

| Lần train | Tài khoản | Thư mục |
|---|---|---|
| Nhóm 1.3 | Người B và người A | Drive của từng người (`macrorunner_train/<backbone>_finetune`) |
| B3 1.4 | `giangthegamer69` | `macrorunner_train/efficientnetb3_finetune` |
| B3 1.5 | tài khoản chạy epoch 8 | `macrorunner_train/efficientnetb3_continue` |

Các thư mục này có thêm `checkpoint.keras` (để train tiếp), `last.keras`,
`splits.csv` và cả hai file `.tflite`.

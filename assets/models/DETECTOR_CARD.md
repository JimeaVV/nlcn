# Detector card

contract_version: 1.6
threshold_box: 0.38
threshold_iou: 0.5

- Trained: 2026-10-27, yolo11s.pt with Ultralytics 8.4.185, 512 px
- Photos: {'test': 1819, 'train': 29284, 'val': 2940} (VietFood67 boxes, MyFood masks, FoodInsSeg boxes, Grounding DINO and Open Images boxes in train)
- Test: mAP50 0.646, mAP50-95 0.556, precision 0.699, recall 0.601
- Files: detector.tflite 37.9 MB, detector_int8.tflite 9.9 MB
- In the app: detector.tflite (float32). The INT8 file (w8a32) fails on the phone with tflite_flutter 0.12.1 ("Input tensor 207 lacks data")

| class | test boxes | mAP50 | mAP50-95 |
|---|---|---|---|
| com | 247 | 0.760 | 0.654 |
| bun | 35 | 0.929 | 0.800 |
| mi | 68 | 0.911 | 0.785 |
| banh_mi_o | 68 | 0.942 | 0.874 |
| ga | 545 | 0.318 | 0.255 |
| thit_kho | 58 | 0.925 | 0.859 |
| thit_nuong | 51 | 0.634 | 0.567 |
| heo | 328 | 0.323 | 0.276 |
| bo | 413 | 0.392 | 0.311 |
| ca | 234 | 0.679 | 0.607 |
| tom | 226 | 0.473 | 0.369 |
| muc | 77 | 0.804 | 0.701 |
| trung | 239 | 0.661 | 0.564 |
| dau_hu | 81 | 0.423 | 0.368 |
| cha | 77 | 0.648 | 0.539 |
| cha_gio | 69 | 0.836 | 0.750 |
| rau | 745 | 0.389 | 0.282 |
| dua_leo_ca_chua | 1109 | 0.374 | 0.274 |
| do_chua | 26 | 0.952 | 0.852 |
| khoai_tay_chien | 347 | 0.317 | 0.229 |
| canh | 47 | 0.865 | 0.757 |

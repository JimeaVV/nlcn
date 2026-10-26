# Detector card

contract_version: 1.6
threshold_box: 0.35
threshold_iou: 0.5

- Trained: 2026-10-26, fine-tuned from https://drive.google.com/file/d/1tw-qrwKxF486cxxlaLttHCvRtc3abE1d/view?usp=sharing with Ultralytics 8.4.185, 640 px
- Photos: {'val': 2967, 'test': 1811, 'train': 20171} (VietFood67 boxes, MyFood masks, FoodInsSeg boxes)
- Test: mAP50 0.632, mAP50-95 0.527, precision 0.695, recall 0.585
- Files: detector.tflite 10.7 MB, detector_int8.tflite 3.0 MB

| class | test boxes | mAP50 | mAP50-95 |
|---|---|---|---|
| com | 247 | 0.700 | 0.567 |
| bun | 35 | 0.896 | 0.735 |
| mi | 68 | 0.928 | 0.771 |
| banh_mi_o | 68 | 0.920 | 0.805 |
| ga | 545 | 0.323 | 0.240 |
| thit_kho | 58 | 0.901 | 0.815 |
| thit_nuong | 51 | 0.762 | 0.676 |
| heo | 328 | 0.309 | 0.249 |
| bo | 413 | 0.405 | 0.305 |
| ca | 234 | 0.642 | 0.544 |
| tom | 226 | 0.460 | 0.350 |
| muc | 77 | 0.798 | 0.691 |
| trung | 239 | 0.659 | 0.537 |
| dau_hu | 81 | 0.394 | 0.325 |
| cha | 77 | 0.573 | 0.457 |
| cha_gio | 69 | 0.728 | 0.641 |
| rau | 745 | 0.365 | 0.246 |
| dua_leo_ca_chua | 1109 | 0.372 | 0.265 |
| do_chua | 26 | 0.944 | 0.853 |
| khoai_tay_chien | 347 | 0.296 | 0.203 |
| canh | 47 | 0.898 | 0.801 |

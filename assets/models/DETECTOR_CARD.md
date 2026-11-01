# Detector card

contract_version: 1.7
threshold_box: 0.52
threshold_box_com: 0.18
threshold_box_bun: 0.30
threshold_box_mi: 0.30
threshold_box_banh_mi_o: 0.58
threshold_box_thit_kho: 0.60
threshold_box_ca: 0.42
threshold_box_tom: 0.34
threshold_box_muc: 0.10
threshold_box_trung: 0.26
threshold_box_dau_hu: 0.32
threshold_box_cha: 0.38
threshold_box_cha_gio: 0.40
threshold_box_dua_leo_ca_chua: 0.16
threshold_box_do_chua: 0.68
threshold_box_canh: 0.68
threshold_iou: 0.5

- Trained: 2026-11-01, yolo11s.pt with Ultralytics 8.4.185, 512 px
- Photos: {'test': 1819, 'train': 34070, 'val': 2940} (VietFood67 boxes, MyFood masks, FoodInsSeg boxes, its train photos used 3 times; touching pieces of one food joined, 25392 boxes into 8134, Grounding DINO and Open Images boxes in train)
- Test: mAP50 0.748, mAP50-95 0.649, precision 0.780, recall 0.676
- Files: detector.tflite 37.9 MB, detector_int8.tflite 9.9 MB
- In the app: detector.tflite with float16 weights, 19.1 MB, made from the float32 file by tool/train/tflite_to_fp16.py; input and output stay float32. On the 459 FoodInsSeg test photos (cơm phần) it finds the same foods as the float32 file on all 459, and with these thresholds finds 56.2% of the foods on them (437/778) with 183 wrong finds; the 2026-10-27 detector found about 56% (on the half its thresholds were not tuned on) with about 0.5 wrong finds a photo
- Trained in Kaggle version 11, tested and exported in version 14 from the same best.pt (version 11 ran out of GPU memory after training)

| class | test boxes | mAP50 | mAP50-95 |
|---|---|---|---|
| com | 217 | 0.836 | 0.711 |
| bun | 35 | 0.939 | 0.809 |
| mi | 68 | 0.928 | 0.804 |
| banh_mi_o | 68 | 0.934 | 0.861 |
| ga | 248 | 0.537 | 0.434 |
| thit_kho | 58 | 0.900 | 0.830 |
| thit_nuong | 51 | 0.728 | 0.660 |
| heo | 179 | 0.535 | 0.475 |
| bo | 194 | 0.586 | 0.479 |
| ca | 201 | 0.791 | 0.697 |
| tom | 91 | 0.656 | 0.549 |
| muc | 77 | 0.822 | 0.724 |
| trung | 239 | 0.652 | 0.549 |
| dau_hu | 50 | 0.673 | 0.587 |
| cha | 77 | 0.612 | 0.501 |
| cha_gio | 69 | 0.810 | 0.731 |
| rau | 332 | 0.630 | 0.509 |
| dua_leo_ca_chua | 346 | 0.551 | 0.434 |
| do_chua | 26 | 0.899 | 0.813 |
| khoai_tay_chien | 77 | 0.809 | 0.684 |
| canh | 47 | 0.877 | 0.787 |

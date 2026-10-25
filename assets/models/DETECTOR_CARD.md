# Detector card

contract_version: 1.6
threshold_box: 0.48
threshold_iou: 0.5

- Trained: 2026-10-24, yolo11n.pt with Ultralytics 8.4.185, 640 px
- Photos: {'train': 17804, 'val': 2441, 'test': 1296} (VietFood67 boxes, MyFood masks)
- Test: mAP50 0.832, mAP50-95 0.708, precision 0.815, recall 0.759
- Files: detector.tflite 10.7 MB, detector_int8.tflite 3.0 MB

| class | test boxes | mAP50 | mAP50-95 |
|---|---|---|---|
| com | 115 | 0.942 | 0.813 |
| bun | 35 | 0.881 | 0.736 |
| mi | 68 | 0.906 | 0.755 |
| banh_mi_o | 68 | 0.913 | 0.781 |
| ga | 100 | 0.742 | 0.589 |
| thit_kho | 58 | 0.924 | 0.835 |
| thit_nuong | 51 | 0.882 | 0.770 |
| heo | 109 | 0.781 | 0.660 |
| bo | 78 | 0.849 | 0.734 |
| ca | 154 | 0.828 | 0.714 |
| tom | 60 | 0.845 | 0.710 |
| muc | 77 | 0.822 | 0.713 |
| trung | 193 | 0.796 | 0.662 |
| dau_hu | 45 | 0.713 | 0.604 |
| cha | 77 | 0.607 | 0.475 |
| cha_gio | 69 | 0.758 | 0.656 |
| rau | 128 | 0.751 | 0.607 |
| dua_leo_ca_chua | 145 | 0.731 | 0.604 |
| do_chua | 26 | 0.934 | 0.841 |
| khoai_tay_chien | 51 | 0.956 | 0.798 |
| canh | 47 | 0.902 | 0.818 |

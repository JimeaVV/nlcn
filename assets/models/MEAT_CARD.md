# Meat classifier card

contract_version: 1.8
crop_pad: 0.10
vote_power: 0.5
box_floor: 0.20
threshold_rescue: 0.60
threshold_drop: 0.80

- Trained: 2026-11-02, mobilenetv3large at 224×224
- Crops: 160458 train (88326 after balancing) / 3057 val / 1969 test, from vf67 157845, fis 5879, fis_empty 1312, myfood 448
- Photos shrunk to 512 px, box grown by 10% a side
- Test accuracy on the boxes: 0.8019, val 0.8714
- File: meat_classifier.tflite, float16 weights, 6.0 MB, 7.2 ms a box on the training machine's CPU
- Trained in Kaggle notebook jimeav/macrorunner-meat-classifier, version 1 (62 minutes on a T4)
- Thresholds above chosen by tool/train/eval_meat_classifier.py on 470 FoodInsSeg val photos, on the boxes of the 2026-11-01 detector (contract 1.7), as the most foods found with no more wrong finds than the detector alone: there 59.8% found, 170 wrong -> 65.1%, 170 wrong
- On the 459 FoodInsSeg test photos: detector alone 56.2% found (437/778), 183 wrong; with these thresholds 59.5% (463/778), 200 wrong; the vote alone (no box_floor, no threshold_drop) 56.8%, 173 wrong
- On the detector's meat boxes of those test photos with a labelled meat under them (246), the classifier alone names 148 right, the detector 155, the vote 161: it was trained on the detector's own data, so it mostly helps by vouching for meat boxes scored just under their threshold

| class | test boxes | right |
|---|---|---|
| ga | 305 | 0.761 |
| thit_kho | 59 | 1.0 |
| thit_nuong | 55 | 0.945 |
| heo | 263 | 0.639 |
| bo | 284 | 0.789 |
| ca | 227 | 0.811 |
| tom | 120 | 0.9 |
| khac | 656 | 0.841 |

# Cấp độ của 96 bài tập

Nhóm duyệt ngày 18/10/2026 và đã áp dụng trong `backend/data/gym-ex-dataset.csv`
(sinh lại `assets/data/recommendations.json` bằng
`python tool/generate_recommendation_assets.py`).

**Vấn đề:** trong 96 bài chỉ có 7 bài Beginner và 0 bài Pro. Người chọn
Beginner hay Pro gần như luôn nhận bài Intermediate.

**Cách app dùng cấp độ:** đây là ưu tiên mềm, không phải bộ lọc.
- Bài đúng cấp được 6 điểm, lệch 1 cấp được 3, lệch 2 cấp được 0.
- Gán lại cấp không làm mất bài của ai, chỉ đổi bài nào được chọn trước.

**Nguyên tắc đề xuất:**
- **Beginner:** máy, cáp, bài cô lập tạ đơn, bài thân người đơn giản. Ít đòi
  kỹ thuật, khó chấn thương.
- **Intermediate:** bài tạ đòn và tạ đơn nhiều khớp (bench, squat, row…).
- **Pro:** bài nặng, đòi kỹ thuật cao (deadlift, front squat, dip, glute ham
  raise…).

## Số bài mỗi cấp trong từng buổi

| Buổi | Trước (Beg / Int / Pro) | Sau (Beg / Int / Pro) |
|---|---|---|
| Push | 0 / 33 / 0 | 10 / 21 / 2 |
| Pull | 3 / 23 / 0 | 10 / 15 / 1 |
| Legs | 4 / 17 / 0 | 11 / 6 / 4 |
| Core | 0 / 12 / 0 | 5 / 5 / 2 |

## 42 thay đổi (bài không có tên ở đây giữ nguyên)

| Nhóm cơ | Bài | Dụng cụ | Hiện tại | Đề xuất |
|---|---|---|---|---|
| Ngực | Machine chest press | Machine | Intermediate | **Beginner** |
| Ngực | Machine chest fly | Machine | Intermediate | **Beginner** |
| Ngực | Pushups | Body Only | Intermediate | **Beginner** |
| Ngực | Chest dip | Other | Intermediate | **Pro** |
| Vai | Machine shoulder press | Machine | Intermediate | **Beginner** |
| Vai | Dumbbell lateral raise | Dumbbell | Intermediate | **Beginner** |
| Vai | Dumbbell front raise | Dumbbell | Intermediate | **Beginner** |
| Tay sau | Triceps Pushdown | Cable | Intermediate | **Beginner** |
| Tay sau | Cable V-bar push-down | Cable | Intermediate | **Beginner** |
| Tay sau | Machine Triceps Extension | Machine | Intermediate | **Beginner** |
| Tay sau | Bench Dips | Body Only | Intermediate | **Beginner** |
| Tay sau | Parallel Bar Dip | Body Only | Intermediate | **Pro** |
| Tay trước | Dumbbell Bicep Curl | Dumbbell | Intermediate | **Beginner** |
| Tay trước | Hammer Curls | Dumbbell | Intermediate | **Beginner** |
| Tay trước | Standing Biceps Cable Curl | Cable | Intermediate | **Beginner** |
| Xô | Lat pull-down | Cable | Intermediate | **Beginner** |
| Xô | Close-grip pull-down | Cable | Intermediate | **Beginner** |
| Lưng giữa | Seated Cable Rows | Cable | Intermediate | **Beginner** |
| Lưng giữa | One-Arm Dumbbell Row | Dumbbell | Intermediate | **Beginner** |
| Lưng dưới | Barbell deadlift | Barbell | Intermediate | **Pro** |
| Đùi trước | Leg Press | Machine | Intermediate | **Beginner** |
| Đùi trước | Leg Extensions | Machine | Intermediate | **Beginner** |
| Đùi trước | Goblet Squat | Kettlebells | Intermediate | **Beginner** |
| Đùi trước | Barbell front squat | Barbell | Intermediate | **Pro** |
| Đùi trước | Barbell Bulgarian split squat | Barbell | Intermediate | **Pro** |
| Đùi trước | Hack Squat | Barbell | Intermediate | **Pro** |
| Đùi sau | Seated Leg Curl | Machine | Intermediate | **Beginner** |
| Đùi sau | Glute Ham Raise | Machine | Intermediate | **Pro** |
| Đùi sau | Stiff-Legged Deadlift | Barbell | Beginner | **Intermediate** (cần kỹ thuật lưng) |
| Bắp chân | Seated Calf Raise | Machine | Intermediate | **Beginner** |
| Bắp chân | Machine seated calf raise | Machine | Intermediate | **Beginner** |
| Bắp chân | Calf Press On The Leg Press Machine | Machine | Intermediate | **Beginner** |
| Mông | Glute bridge | Body Only | Intermediate | **Beginner** |
| Bụng | Crunch | Body Only | Intermediate | **Beginner** |
| Bụng | Sit-up | Body Only | Intermediate | **Beginner** |
| Bụng | Elbow plank | Body Only | Intermediate | **Beginner** |
| Bụng | Ab bicycle | Body Only | Intermediate | **Beginner** |
| Bụng | Mountain climber | Body Only | Intermediate | **Beginner** |
| Bụng | Hanging leg raise | Body Only | Intermediate | **Pro** |
| Bụng | Ab Roller | Other | Intermediate | **Pro** |
| Đùi trong | Thigh adductor | Machine | Intermediate | **Beginner** |
| Đùi ngoài | Thigh abductor | Machine | Intermediate | **Beginner** |

## Nhóm cơ trước đây không được gợi ý (đã sửa)

App hiện chia 4 buổi: Push (ngực, vai, tay sau), Pull (lưng, tay trước, xô,
cẳng tay), Legs (đùi trước, đùi sau, bắp chân, mông), Core (bụng). Có 4 bài
**không bao giờ được gợi ý** vì nhóm cơ của chúng không nằm trong buổi nào:
- Barbell shrug, Standing dumbbell shrug (cầu vai): đã cho vào **Pull**;
- Thigh adductor, Thigh abductor (đùi trong, đùi ngoài): đã cho vào
  **Legs**.

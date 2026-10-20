---
name: train-notebook
description: Change the food-model training notebook safely - edit train_food_model.py, regenerate the .ipynb, smoke-test it on fake data (one device, two devices, cut-off and resume, fake Colab), and make QUICK/FULL copies for one backbone to send to Kaggle or Colab. Use whenever tool/train/train_food_model.py changes or the user asks for a notebook to train with.
argument-hint: "[backbone, vd efficientnetb3] [quick|full]"
---

# Sửa và gửi notebook train

## Quy tắc
- Chỉ sửa `tool/train/train_food_model.py`. Không sửa `.ipynb` bằng tay vì
  nó được sinh ra.
- Ô `# %% [markdown]` đầu file là hướng dẫn chạy trên Kaggle và Colab. Đổi
  cách chạy thì sửa luôn phần đó.
- Đụng tới `DISHES`, `COMPONENTS` hay `DISH_PARTS` là đổi contract. Xem
  phần Contract trong `CLAUDE.md`.
- Mọi thứ ảnh hưởng kết quả (recipe, số epoch, cách chia dữ liệu, kích
  thước ảnh) phải giữ giống nhau giữa các backbone đem ra so sánh. Đổi những
  thứ này thì báo người dùng rằng kết quả cũ không còn so trực tiếp được.

## 1. Sinh lại notebook
```bash
python tool/train/make_notebook.py
```

## 2. Thử nhanh trên dữ liệu giả
Cần Python có tensorflow 2.18 và pillow (xem `CLAUDE.local.md`). Mỗi lượt
mất 3–6 phút; chạy các lượt nối tiếp nhau trong nền, không chạy song song vì
CPU sẽ chậm hẳn.

```bash
python tool/train/test/smoke_test.py                 # 1 thiết bị
python tool/train/test/smoke_test.py --resume        # cắt sau epoch 1, chạy tiếp
python tool/train/test/smoke_test.py --two-devices   # 2 thiết bị như Kaggle T4 x2
python tool/train/test/smoke_test.py --colab         # Colab và Drive giả
```

- Sửa phần đọc dữ liệu: chạy lượt 1 thiết bị và `--colab`.
- Sửa phần train, callback, checkpoint: chạy cả bốn lượt.
- Thêm `--backbone efficientnetb0` cho nhanh nếu thay đổi không liên quan
  tới backbone.
- Dòng cuối phải là `PASS`. Nếu `FAIL`, đọc log trong thư mục work mà script
  in ra.
- Độ chính xác trên dữ liệu giả không có ý nghĩa. Chỉ kiểm tra là notebook
  chạy hết, đủ file, đủ 3 epoch và chạy tiếp đúng.

Script tự sửa bản sao notebook: 3 epoch fine-tune và một móc để cắt giữa
chừng. Nếu nó báo "cannot patch the notebook", nghĩa là dòng nó tìm đã đổi;
sửa `smoke_test.py` cho khớp.

## 3. Tạo bản gửi người dùng
Tạo trong scratchpad, không để lại trong repo:

```bash
sed -e "s/^QUICK_TEST = True /QUICK_TEST = False/" \
    -e "s/^BACKBONE = 'efficientnetb3'/BACKBONE = '<backbone>'/" \
    tool/train/train_food_model.py > tool/train/_send.py
python tool/train/make_notebook.py _send.py
mv tool/train/_send.ipynb <scratchpad>/FULL_<backbone>.ipynb
rm tool/train/_send.py
```

- Bản QUICK bỏ dòng `-e` đầu tiên.
- Kiểm tra bản vừa tạo có đúng `QUICK_TEST` và `BACKBONE` mong muốn, rồi gửi
  bằng SendUserFile.
- Nhắc người dùng chạy QUICK trước nếu notebook vừa đổi nhiều.

## 4. Commit và nhật ký
- Commit `train_food_model.py` cùng `train_food_model.ipynb`.
- Ghi một mục vào `docs/QUA_TRINH_THUC_HIEN.md`: lý do, thay đổi, và kết quả
  các lượt thử nhanh đã chạy.

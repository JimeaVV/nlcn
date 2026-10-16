# Hợp đồng dữ liệu và model nhận diện món ăn

Tài liệu này là **thoả thuận chung giữa Người A (App) và Người B (Model)**.
Hai bên làm song song, chỉ dựa vào những gì ghi ở đây. Muốn đổi bất kỳ mục
nào thì phải báo người kia, tăng `contract_version` và ghi vào
`docs/QUA_TRINH_THUC_HIEN.md`.

- `contract_version`: **0.1 (bản nháp, chờ hai người chốt danh sách ở mục 2–3)**
- Cập nhật: 2026-10-17

---

## 1. Model làm gì
Nhận **một ảnh chụp một dĩa hoặc tô** và trả về hai kết quả:
1. **Món gì:** chọn đúng 1 món trong danh sách món (mục 2).
2. **Có những thành phần nào:** mỗi thành phần có một xác suất riêng, độc lập
   với nhau (mục 3). Ví dụ dĩa cơm tấm có sườn, trứng, có bì hay không.

Model **không** đếm số lượng và **không** ước lượng gram. Người dùng xác nhận
số lượng và khẩu phần trên app; khẩu phần mặc định lấy ở mục 4. Việc đếm thuộc
giai đoạn YOLO (mục 7).

## 2. Danh sách món (đầu ra `dish`)
Quy tắc đặt mã: chữ thường, không dấu, nối bằng `_`. Mã dùng chung cho tên
nhãn trong `labels.csv`, thứ tự trong `dishes.txt` và khoá trong bảng dinh
dưỡng của app.

Bản nháp gồm **20 món** để bắt đầu; khi dữ liệu đủ thì mở rộng lên 30.

| # | Mã | Tên hiển thị (vi) | Ghi chú |
|---|---|---|---|
| 1 | `com_tam` | Cơm tấm | |
| 2 | `com_phan` | Cơm phần (cơm + món mặn tự chọn) | Thành phần thay đổi nhiều, dựa hẳn vào đầu ra `components` |
| 3 | `com_ga` | Cơm gà | |
| 4 | `com_chien` | Cơm chiên | |
| 5 | `pho_bo` | Phở bò | |
| 6 | `pho_ga` | Phở gà | |
| 7 | `bun_bo_hue` | Bún bò Huế | |
| 8 | `bun_cha` | Bún chả | |
| 9 | `bun_rieu` | Bún riêu | |
| 10 | `bun_thit_nuong` | Bún thịt nướng | |
| 11 | `hu_tieu` | Hủ tiếu | |
| 12 | `mi_quang` | Mì Quảng | |
| 13 | `banh_canh` | Bánh canh | |
| 14 | `bo_kho` | Bò kho | |
| 15 | `chao` | Cháo | |
| 16 | `banh_mi` | Bánh mì | |
| 17 | `banh_cuon` | Bánh cuốn | |
| 18 | `banh_xeo` | Bánh xèo | |
| 19 | `goi_cuon` | Gỏi cuốn | |
| 20 | `xoi` | Xôi | |

## 3. Danh sách thành phần (đầu ra `components`)
Thành phần dùng chung giữa các món, nên mỗi thành phần chỉ cần một dòng dinh
dưỡng. Bản nháp gồm **24 thành phần**:

| Nhóm | Mã | Tên hiển thị (vi) |
|---|---|---|
| Tinh bột | `com` | Cơm (cơm trắng / cơm tấm) |
| | `bun` | Bún |
| | `banh_pho` | Bánh phở |
| | `mi` | Mì / hủ tiếu / sợi khác |
| | `banh_mi_o` | Ổ bánh mì |
| | `xoi_nep` | Xôi nếp |
| Đạm | `suon_nuong` | Sườn nướng |
| | `thit_nuong` | Thịt nướng |
| | `thit_kho` | Thịt kho |
| | `bi` | Bì |
| | `cha_trung` | Chả trứng hấp |
| | `trung_op_la` | Trứng ốp la |
| | `trung_kho` | Trứng kho / trứng luộc |
| | `ga` | Thịt gà |
| | `bo` | Thịt bò |
| | `ca` | Cá |
| | `tom` | Tôm |
| | `dau_hu` | Đậu hũ |
| | `cha_lua` | Chả lụa / giò |
| Rau và khác | `rau_song` | Rau sống |
| | `rau_nau` | Rau luộc / xào |
| | `do_chua` | Đồ chua |
| | `dua_leo_ca_chua` | Dưa leo / cà chua |
| | `mo_hanh` | Mỡ hành |

> Nước dùng của các món nước (phở, bún, hủ tiếu…) **không** là thành phần
> riêng. Năng lượng của nước dùng tính vào dòng "nền" của món (mục 4).

## 4. Dữ liệu dinh dưỡng (Người A phụ trách)
Lưu ở dạng CSV trong repo, đặt tại `assets/data/vn_food/`:

**`components.csv`**: dinh dưỡng của từng thành phần, tính trên 100 g.
```
code,name_vi,name_en,kcal_per_100g,protein_g,carb_g,fat_g,unit_name_vi,unit_grams,source
suon_nuong,Sườn nướng,Grilled pork chop,...,...,...,...,miếng,...,"Bảng TPTP VN 2007, mã ..."
```
- `unit_name_vi` / `unit_grams`: đơn vị tự nhiên để người dùng chỉnh, ví dụ
  `quả`/50 với trứng, `miếng`/100 với sườn. Để trống nếu chỉ tính theo gram.
- Cột `source` **bắt buộc**: ghi rõ nguồn của từng số liệu. **Không tự đoán
  số.**

**`dishes.csv`**: thành phần mặc định của từng món, và phần "nền" như nước
dùng hay nước chấm.
```
dish,component,default_grams,default_units
com_tam,com,200,
com_tam,suon_nuong,,1
com_tam,trung_op_la,,1
com_tam,do_chua,30,
pho_bo,_base,500,        ← nước dùng; dinh dưỡng ghi ở dòng `_base_pho_bo` trong components.csv
```
Kiểm tra hai file bằng `python tool/check_vn_food.py`; thêm `--strict` để
liệt kê các ô còn trống. Script kiểm tra mã có khớp contract không, số liệu có
hợp lý không (calo ≈ 4·protein + 4·carb + 9·fat, sai lệch ≤ 25%) và đã có
nguồn chưa.

App dùng `dishes.csv` để điền sẵn khẩu phần cho những thành phần model báo là
có. Thành phần model báo có mà không nằm trong danh sách mặc định của món thì
lấy `unit_grams`, hoặc 100 g nếu không có.

## 5. Dữ liệu ảnh (Người B phụ trách)
Ảnh **không commit vào git** (`dataset/vnfood/` đã có trong `.gitignore`).
Cấu trúc thư mục trên máy và trên Google Drive:
```
dataset/vnfood/
  images/            ảnh gốc, tên file tuỳ ý nhưng không trùng nhau
  labels.csv         file,dish,components
  splits.csv         file,split            (train / val / test)
  SOURCES.md         nguồn và license của từng bộ ảnh
```
`labels.csv`: mỗi ảnh một dòng, thuộc đúng 1 món; các thành phần cách nhau
bằng `|`.
```
file,dish,components
img_0001.jpg,com_tam,com|suon_nuong|trung_op_la|do_chua
img_0002.jpg,pho_bo,banh_pho|bo|rau_song
```
- Mỗi món ít nhất **150 ảnh**; mỗi thành phần xuất hiện ít nhất **100 lần**
  trong tập train.
- Chia tập 70/15/15, chia theo từng món, cố định seed. **Tập test có ít nhất
  30% ảnh tự chụp** và được người kiểm tra lại toàn bộ.
- Có dùng AI hỗ trợ gán nhãn thì ghi vào `SOURCES.md` và báo cáo.

## 6. Định dạng model đưa vào app
Đặt trong `assets/models/`:
```
food_v1.tflite      model
dishes.txt          mỗi dòng một mã món, đúng thứ tự đầu ra `dish`
components.txt      mỗi dòng một mã thành phần, đúng thứ tự đầu ra `components`
MODEL_CARD.md       ngày train, phiên bản dữ liệu, kiến trúc, kết quả, ngưỡng
```

| Mục | Quy định |
|---|---|
| Đầu vào | `float32 [1, 224, 224, 3]`, ảnh **RGB, giá trị 0–255** |
| Tiền xử lý | App: cắt vuông ở giữa ảnh rồi resize về 224×224 (bilinear). **Việc chuẩn hoá pixel nằm trong model** (lớp `Rescaling`/preprocess), app không tự chuẩn hoá |
| Đầu ra 1 `dish` | `float32 [1, số_món]`, softmax (tổng bằng 1) |
| Đầu ra 2 `components` | `float32 [1, số_thành_phần]`, sigmoid (mỗi giá trị 0–1, độc lập) |
| Lượng tử hoá | float16 |
| Kích thước | Mục tiêu ≤ 15 MB |
| Tốc độ | Mục tiêu ≤ 300 ms mỗi ảnh trên điện thoại tầm trung |

**Ngưỡng hiển thị thành phần** (Người B chỉnh trên tập val, ghi vào
`MODEL_CARD.md`; app đọc từ đó):
- `≥ 0.6`: tick sẵn;
- `0.3 – 0.6`: hỏi lại người dùng ("Có bì không?");
- `< 0.3`: ẩn, người dùng vẫn tự thêm được.

Món có xác suất cao nhất dưới `0.5` thì app hiện top-3 cho người dùng chọn.

## 7. Giai đoạn YOLO (tuần 5–7, nâng cấp)
- Lớp của YOLO = các thành phần trong `components.txt` (có thể chỉ lấy một
  phần), cùng mã.
- Nhãn theo định dạng YOLO (`class cx cy w h`), gán bằng Roboflow hoặc CVAT.
- Dùng để **đếm** (2 trứng, 2 miếng sườn) và **gợi ý khẩu phần** từ diện tích
  khung. Định dạng đầu ra sẽ được bổ sung vào contract khi bắt đầu tuần 5.
- License Ultralytics: AGPL-3.0, phải ghi rõ trong báo cáo.

## 8. Ghi vào nhật ký ăn uống
Mỗi thành phần người dùng xác nhận được ghi thành **một dòng `food_log`**:
- `source = camera`;
- `confidence` = xác suất model đưa ra cho thành phần đó;
- `name` là tên thành phần, kèm tên món, ví dụ "Sườn nướng (cơm tấm)".

Bảng `food_log` đã có sẵn từ commit `714d4d4`, không cần đổi database.

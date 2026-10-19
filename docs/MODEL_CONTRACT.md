# Hợp đồng dữ liệu và model nhận diện món ăn

Tài liệu này là **thoả thuận chung giữa Người A (App) và Người B (Model)**.
Hai bên làm song song, chỉ dựa vào những gì ghi ở đây. Muốn đổi bất kỳ mục
nào thì phải báo người kia, tăng `contract_version` và ghi vào
`docs/QUA_TRINH_THUC_HIEN.md`.

- `contract_version`: **1.3**
  - 1.0: hai người chốt 40 món ở mục 2 và các thành phần ở mục 3;
  - 1.1: thêm cách ghi ngưỡng trong `MODEL_CARD.md` và những gì app kiểm
    tra khi nạp model (mục 6);
  - 1.2: thêm thành phần `ga_chien` (gà chiên / xối mỡ), lên 25 thành phần,
    vì cơm gà ở quán thường là gà chiên; thêm bảng `meal_plan.csv` cho phần
    gợi ý thực đơn (mục 4);
  - 1.3: thêm 12 món có nhiều ảnh trong các bộ công khai (món 41–52), và
    lớp `khac` ở cuối đầu ra `dish` cho món không có trong app (mục 6).
- Cập nhật: 2026-10-19

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

Gồm **52 món**:
- món 1–20 là danh sách ban đầu, phần lớn có trong bộ ảnh 30VNFoods;
- món 21–40 lấy theo bộ ảnh VinaFood21 (chỉ trùng `bo_kho` với danh sách
  ban đầu);
- món 41–52 là các món phổ biến có nhiều ảnh trong 30VNFoods, 20FoodVN và
  VietFood67.

Model có thêm một đầu ra cuối cùng `khac` (món không có trong app), không
nằm trong bảng này; xem mục 6.

Món nào chỉ gồm một thứ (bánh tét, bắp nướng…) thì không cần gán nhãn thành
phần; toàn bộ dinh dưỡng nằm ở dòng nền `_base_<mã món>`.

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
| 21 | `bo_la_lot` | Bò lá lốt | VinaFood21 |
| 22 | `ha_cao` | Há cảo | VinaFood21 |
| 23 | `banh_uot` | Bánh ướt | VinaFood21 |
| 24 | `banh_hoi` | Bánh hỏi | VinaFood21 |
| 25 | `thit_kho_trung` | Thịt kho trứng | VinaFood21; thành phần `thit_kho`, `trung_kho` |
| 26 | `banh_can` | Bánh căn | VinaFood21 |
| 27 | `ca_ri` | Cà ri gà | VinaFood21 |
| 28 | `bap_nuong` | Bắp nướng | VinaFood21 |
| 29 | `banh_trang_tron` | Bánh tráng trộn | VinaFood21 |
| 30 | `hoanh_thanh_nuoc` | Hoành thánh nước | VinaFood21 |
| 31 | `pha_lau` | Phá lấu | VinaFood21 |
| 32 | `tau_hu` | Tàu hũ nước đường | VinaFood21 |
| 33 | `bot_chien` | Bột chiên | VinaFood21 |
| 34 | `ga_nuong` | Gà nướng | VinaFood21; thành phần `ga` |
| 35 | `banh_u` | Bánh ú | VinaFood21 |
| 36 | `banh_tet` | Bánh tét | VinaFood21 |
| 37 | `goi_ga` | Gỏi gà | VinaFood21 |
| 38 | `canh_khoai_mo` | Canh khoai mỡ | VinaFood21 |
| 39 | `canh_kho_qua` | Canh khổ qua | VinaFood21 |
| 40 | `banh_mi_chao` | Bánh mì chảo | VinaFood21 |
| 41 | `banh_chung` | Bánh chưng | 30VNFoods, VietFood67 |
| 42 | `banh_khot` | Bánh khọt | 30VNFoods, VietFood67 |
| 43 | `banh_beo` | Bánh bèo | 30VNFoods, VietFood67 |
| 44 | `cao_lau` | Cao lầu | 30VNFoods, VietFood67 |
| 45 | `bun_dau` | Bún đậu mắm tôm | 30VNFoods, VietFood67 |
| 46 | `bun_mam` | Bún mắm | 30VNFoods, VietFood67 |
| 47 | `chao_long` | Cháo lòng | 30VNFoods, 20FoodVN, VietFood67 |
| 48 | `ca_kho` | Cá kho | 30VNFoods (cá kho tộ), 20FoodVN (cá lóc kho) |
| 49 | `canh_chua` | Canh chua | 30VNFoods |
| 50 | `trung_vit_lon` | Trứng vịt lộn | 20FoodVN |
| 51 | `che` | Chè | 20FoodVN (chè Thái, chè bưởi) |
| 52 | `nuoc_mia` | Nước mía | 20FoodVN |

## 3. Danh sách thành phần (đầu ra `components`)
Thành phần dùng chung giữa các món, nên mỗi thành phần chỉ cần một dòng dinh
dưỡng. Gồm **25 thành phần**:

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
| | `ga` | Thịt gà (luộc, nướng, hấp) |
| | `ga_chien` | Gà chiên / xối mỡ |
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

**`dish_names.csv`**: tên hiển thị của từng món, đúng thứ tự mục 2.
```
code,name_vi,name_en
com_tam,Cơm tấm,Broken rice
```

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
**`meal_plan.csv`**: món nào được gợi ý trong thực đơn, cho bữa nào và mục
tiêu nào (chỉ phần gợi ý thực đơn dùng; model không dùng).
```
code,kind,slots,goals,note
pho_bo,dish,breakfast,maintain|gain,
com_phan,combo,lunch|dinner,lose|maintain|gain,
ga,main,lunch|dinner,lose|maintain|gain,
```
- `kind`: `dish` ăn nguyên món, `combo` là cơm phần do thuật toán ghép,
  `soup` canh ăn kèm cơm phần; `staple`, `main`, `side` là cơm, món mặn,
  rau dùng để ghép cơm phần.
- `slots`: `breakfast`, `lunch`, `dinner`, `snack`; `goals`: `lose`,
  `maintain`, `gain`, ngăn bằng `|`.
- Món không có trong bảng thì không được gợi ý (vẫn quét và ghi nhật ký
  được).

Thành phần là hỗn hợp (nước chấm, mỡ hành, chả trứng…) được tính từ công
thức nấu bằng `python tool/vn_food_recipes.py --write`. Script cộng dinh
dưỡng của từng nguyên liệu rồi chia cho khối lượng thành phẩm.

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

**Lớp `khac` (từ v1.3):** dòng cuối của `dishes.txt` là `khac`. Lớp này
train bằng ảnh của các món không có trong app, ví dụ gỏi ngó sen, lẩu,
hamburger.
- `khac` không có dinh dưỡng và không hiện trong danh sách gợi ý.
- `khac` từ `threshold_confident_dish` trở lên thì app báo "có thể món này
  chưa có trong app" và mở danh sách món cho người dùng chọn, không đoán bừa
  một món gần giống.

**Cách ghi ngưỡng trong `MODEL_CARD.md`** (từ v1.1): mỗi ngưỡng một dòng
dạng `khoá: giá trị`, giá trị trong khoảng 0–1. Thiếu dòng nào thì app dùng
số mặc định ở trên.
```
threshold_checked: 0.6
threshold_ask: 0.3
threshold_confident_dish: 0.5
```

**App kiểm tra khi nạp model:**
- đầu vào phải là `float32 [1, 224, 224, 3]`, mọi đầu ra là float32;
- hai đầu ra được nhận ra theo **độ dài**, khớp với số dòng của
  `dishes.txt` và `components.txt`, nên thứ tự đầu ra trong file `.tflite`
  không quan trọng; vì vậy hai file này phải có số dòng khác nhau;
- mã trong hai file phải có trong bảng dinh dưỡng (test
  `food_model_test.dart` tự kiểm tra khi có model);
- file nào hỏng thì app bỏ qua model và chuyển về chọn món bằng tay.

**Model giả để thử:** `python tool/make_dummy_food_model.py build/dummy_model`
(cần TensorFlow) tạo một model chưa train, đúng định dạng trên. Đây cũng là
mẫu cách xuất model. **Không** đưa model giả vào `assets/models/`.

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

Bảng `food_log` đã có sẵn từ commit `d4806b1`, không cần đổi database.

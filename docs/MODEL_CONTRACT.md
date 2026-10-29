# Hợp đồng dữ liệu và model nhận diện món ăn

Tài liệu này là **thoả thuận chung giữa Người A (App) và Người B (Model)**.
Hai bên làm song song, chỉ dựa vào những gì ghi ở đây. Muốn đổi bất kỳ mục
nào thì phải báo người kia, tăng `contract_version` và ghi vào
`docs/QUA_TRINH_THUC_HIEN.md`.

- `contract_version`: **1.6**
  - 1.0: hai người chốt 40 món ở mục 2 và các thành phần ở mục 3;
  - 1.1: thêm cách ghi ngưỡng trong `MODEL_CARD.md` và những gì app kiểm
    tra khi nạp model (mục 6);
  - 1.2: thêm thành phần `ga_chien` (gà chiên / xối mỡ), lên 25 thành phần,
    vì cơm gà ở quán thường là gà chiên; thêm bảng `meal_plan.csv` cho phần
    gợi ý thực đơn (mục 4);
  - 1.3: thêm 12 món có nhiều ảnh trong các bộ công khai (món 41–52), và
    lớp `khac` ở cuối đầu ra `dish` cho món không có trong app (mục 6).
  - 1.4: thêm 13 món đã có ảnh trong các bộ công khai nhưng trước đó bị gom
    vào `khac` (món 53–65); `khac` còn lẩu và gỏi ngó sen. Kích thước ảnh
    vào do model quyết định, app đọc từ file `.tflite` (mục 6).
  - 1.5: thêm 26 món ăn hằng ngày (món 66–91): món lẻ như cơm trắng, ức gà,
    trứng, và món quốc tế phổ biến như pizza, sushi, ramen. Ảnh lấy từ
    Food-101, MyFood và các khung trong VietFood67; ảnh người dùng tự lưu
    trong app cũng dùng để train (mục 5). Model 1.5 train tiếp từ model
    1.4: 65 món cũ giữ nguyên thứ tự, món mới nối vào sau.
  - 1.6: thêm model thứ hai, **phát hiện từng món trên đĩa** bằng YOLO (mục
    7): 21 lớp, mỗi lớp ứng với một thành phần hoặc một nhóm biến thể của
    app. Model nhận diện món (mục 6) không đổi, vẫn là model 1.5.
- Cập nhật: 2026-10-24

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

Gồm **91 món**:
- món 1–20 là danh sách ban đầu, phần lớn có trong bộ ảnh 30VNFoods;
- món 21–40 lấy theo bộ ảnh VinaFood21 (chỉ trùng `bo_kho` với danh sách
  ban đầu);
- món 41–65 là các món phổ biến có nhiều ảnh trong 30VNFoods, 20FoodVN và
  VietFood67;
- món 66–91 là món ăn hằng ngày, cả món lẻ (cơm trắng, ức gà, trứng) lẫn
  món quốc tế. Ảnh lấy từ Food-101, MyFood và các khung trong VietFood67
  (cắt riêng phần cơm, rau, đậu hũ, chả giò trên dĩa).

Model có thêm một đầu ra cuối cùng `khac` (món không có trong app), không
nằm trong bảng này; xem mục 6.

Món nào chỉ gồm một thứ (bánh tét, bắp nướng…) thì không cần gán nhãn thành
phần; toàn bộ dinh dưỡng nằm ở dòng nền `_base_<mã món>`.

Món 66–91 chỉ có dòng nền (ức gà, pizza…) thì ảnh của chúng **không** dạy
đầu ra thành phần: ức gà có thịt gà, sushi có cơm và cá, nhưng dinh dưỡng đã
nằm ở dòng nền nên các thành phần đó không có trong công thức món. Món mới
có công thức bằng thành phần (cơm trắng là `com`, trứng luộc là
`trung_kho`…) thì dạy như các món cũ.

| # | Mã | Tên hiển thị (vi) | Ghi chú |
|---|---|---|---|
| 1 | `com_tam` | Cơm tấm | |
| 2 | `com_phan` | Cơm phần (cơm + món mặn tự chọn) | Thành phần thay đổi nhiều, dựa hẳn vào đầu ra `components` |
| 3 | `com_ga` | Cơm gà | |
| 4 | `com_chien` | Cơm chiên | Từ v1.5 thêm Food-101 (fried rice) |
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
| 27 | `ca_ri` | Cà ri gà | VinaFood21; từ v1.5 thêm Food-101 (chicken curry) |
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
| 53 | `banh_trang_nuong` | Bánh tráng nướng | 30VNFoods |
| 54 | `banh_gio` | Bánh giò | 30VNFoods |
| 55 | `banh_bot_loc` | Bánh bột lọc | 30VNFoods |
| 56 | `banh_duc` | Bánh đúc | 30VNFoods |
| 57 | `nem_chua` | Nem chua | 30VNFoods |
| 58 | `banh_pia` | Bánh pía | 30VNFoods |
| 59 | `bun_ca` | Bún cá | 20FoodVN (bún cá), VietFood67 (bún chả cá) |
| 60 | `khoai_tay_chien` | Khoai tây chiên | VietFood67, Food-101 (french fries) |
| 61 | `salad` | Salad | VietFood67, Food-101 (caesar, greek, beet, caprese salad), MyFood (salad) |
| 62 | `hamburger` | Hamburger | VietFood67, Food-101 (hamburger) |
| 63 | `nui_xao_bo` | Nui xào bò | VietFood67 |
| 64 | `sup_cua` | Súp cua | VietFood67 |
| 65 | `nom_hoa_chuoi` | Nộm hoa chuối | VietFood67 |
| 66 | `com_trang` | Cơm trắng | MyFood (rice), VietFood67 (khung `Com`) |
| 67 | `uc_ga` | Ức gà | MyFood (chicken breast) |
| 68 | `trung_luoc` | Trứng luộc | MyFood (boiled egg) |
| 69 | `trung_op` | Trứng ốp la | MyFood (fried egg) |
| 70 | `trung_chien` | Trứng chiên / ốp lết | Food-101 (omelette) |
| 71 | `bo_bit_tet` | Bò bít tết | Food-101 (steak, filet mignon, prime rib), MyFood (steak) |
| 72 | `mi_y` | Mì Ý | Food-101 (spaghetti bolognese, carbonara), MyFood (spaghetti) |
| 73 | `tao` | Táo | MyFood (apple) |
| 74 | `dau_hu_chien` | Đậu hũ chiên / sốt cà | VietFood67 (khung `Dau hu`) |
| 75 | `rau_xao` | Rau luộc / xào | VietFood67 (khung `Rau` trên dĩa cơm phần) |
| 76 | `cha_gio` | Chả giò | Food-101 (spring rolls), VietFood67 (khung `Cha gio`) |
| 77 | `ga_ran` | Gà rán / cánh gà chiên | Food-101 (chicken wings) |
| 78 | `ca_hoi` | Cá hồi áp chảo / nướng | Food-101 (grilled salmon) |
| 79 | `muc_chien` | Mực chiên | Food-101 (fried calamari) |
| 80 | `sui_cao` | Sủi cảo / há cảo hấp | Food-101 (dumplings, gyoza) |
| 81 | `pizza` | Pizza | Food-101 (pizza) |
| 82 | `sushi` | Sushi | Food-101 (sushi) |
| 83 | `sashimi` | Sashimi | Food-101 (sashimi) |
| 84 | `ramen` | Ramen | Food-101 (ramen) |
| 85 | `hot_dog` | Hot dog | Food-101 (hot dog) |
| 86 | `sandwich` | Sandwich | Food-101 (club, grilled cheese, pulled pork, lobster roll sandwich) |
| 87 | `pancake` | Bánh pancake | Food-101 (pancakes) |
| 88 | `banh_waffle` | Bánh waffle | Food-101 (waffles) |
| 89 | `banh_donut` | Bánh donut | Food-101 (donuts) |
| 90 | `banh_kem` | Bánh kem / bánh ngọt | Food-101 (chocolate cake, cheesecake, red velvet cake, strawberry shortcake, carrot cake, cupcakes) |
| 91 | `kem` | Kem | Food-101 (ice cream) |

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

**Ảnh người dùng tự lưu trong app** (từ v1.5): bật "Lưu ảnh để train" trong
Cài đặt thì mỗi lần ghi món bằng camera, app giữ một bản ảnh nhỏ (cạnh dài
640 px) kèm món người dùng đã xác nhận. Nút xuất cho ra một file zip:
```
index.csv          file,label,name,model_guess,model_confidence,saved_at
<nhãn>/<số>.jpg    ảnh, mỗi nhãn một thư mục
```
- `label` là mã món, hoặc `single_<mã thành phần>` khi người dùng ghi một
  thứ ăn riêng, hoặc `new_<tên>` khi món không có trong app.
- Notebook đổi `single_com` thành `com_trang`, `single_trung_kho` thành
  `trung_luoc`… (món lẻ có cùng nghĩa); `new_<tên>` vào lớp `khac`.
- `model_guess` là món model đoán lúc chụp: ảnh model đoán sai là ảnh
  đáng train nhất.
- Từ v1.6, `label` là `plate` khi người dùng ghi một đĩa nhiều món do
  model phát hiện tìm ra (mục 7). Notebook nhận diện món bỏ qua nhãn này;
  ảnh để dành khoanh khung cho model phát hiện sau.

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
| Đầu vào | `float32 [1, N, N, 3]`, ảnh **RGB, giá trị 0–255**. N do model quyết định (từ v1.4): 224 cho MobileNetV3/EfficientNetB0, 300 cho EfficientNetB3; app đọc N từ file `.tflite` |
| Tiền xử lý | App: cắt vuông ở giữa ảnh rồi resize về N×N (bilinear). **Việc chuẩn hoá pixel nằm trong model** (lớp `Rescaling`/preprocess), app không tự chuẩn hoá |
| Đầu ra 1 `dish` | `float32 [1, số_món]`, softmax (tổng bằng 1) |
| Đầu ra 2 `components` | `float32 [1, số_thành_phần]`, sigmoid (mỗi giá trị 0–1, độc lập) |
| Lượng tử hoá | float16 hoặc int8 (B3 từ v1.4 dùng int8) |
| Kích thước | Mục tiêu ≤ 15 MB |
| Tốc độ | Mục tiêu ≤ 300 ms mỗi ảnh trên điện thoại tầm trung |

**Ngưỡng hiển thị thành phần** (Người B chỉnh trên tập val, ghi vào
`MODEL_CARD.md`; app đọc từ đó):
- `≥ 0.6`: tick sẵn;
- `0.3 – 0.6`: hỏi lại người dùng ("Có bì không?");
- `< 0.3`: ẩn, người dùng vẫn tự thêm được.

Món có xác suất cao nhất dưới `0.5` thì app hiện top-3 cho người dùng chọn.

**Lớp `khac` (từ v1.3):** dòng cuối của `dishes.txt` là `khac`. Lớp này
train bằng ảnh của các món không có trong app. Từ v1.4 đó là lẩu (món ăn
chung nồi, không tính được khẩu phần một người) và gỏi ngó sen; từ v1.5 có
thêm các lớp Food-101 chưa có trong app (taco, lasagna…). Lớp nào của bộ
ảnh khác không khớp món của app cũng vào `khac`.
- `khac` không có dinh dưỡng và không hiện trong danh sách gợi ý.
- `khac` từ `threshold_confident_dish` trở lên thì app báo "có thể món này
  chưa có trong app" và mở danh sách món cho người dùng chọn, không đoán bừa
  một món gần giống.

**Món được tin phần thành phần** (từ v1.3, thêm sau khi thử thật): thẻ
model có dòng `component_dishes: com_tam, com_phan, …`. Đó là các món mà
phần thành phần đạt F1 từ 0,7 trở lên, đo trên ít nhất 20 ảnh val có nhãn
thành phần.
- Với món nằm trong danh sách: app dùng các ngưỡng ở trên.
- Với món khác, hoặc thẻ model không có dòng này: app bỏ qua đầu ra thành
  phần, tick các thành phần theo công thức món như khi chưa có model, và
  không gợi ý thêm thành phần nào.
- Thành phần nằm ngoài công thức món không bao giờ được tick sẵn. Nó chỉ
  hiện ở dạng "Có thể" khi xác suất từ 0,6 trở lên.

Vì sao cần: khi thử thật với một tô phở bò, model chắc trên 60% là có
trứng, bì, chả trứng, nhưng lại bỏ tick thịt bò. Lý do là không ảnh phở
nào có nhãn thành phần, nên với phở, đầu ra thành phần không mang ý nghĩa
gì.

**Cách ghi ngưỡng trong `MODEL_CARD.md`** (từ v1.1): mỗi ngưỡng một dòng
dạng `khoá: giá trị`, giá trị trong khoảng 0–1. Thiếu dòng nào thì app dùng
số mặc định ở trên.
```
threshold_checked: 0.6
threshold_ask: 0.3
threshold_confident_dish: 0.5
component_dishes: com_tam, com_phan
```

**App kiểm tra khi nạp model:**
- đầu vào phải là `float32 [1, N, N, 3]` (ảnh vuông, N ≥ 32), mọi đầu ra là float32;
- hai đầu ra được nhận ra theo **độ dài**, khớp với số dòng của
  `dishes.txt` và `components.txt`, nên thứ tự đầu ra trong file `.tflite`
  không quan trọng; vì vậy hai file này phải có số dòng khác nhau;
- mã trong hai file phải có trong bảng dinh dưỡng (test
  `food_model_test.dart` tự kiểm tra khi có model);
- file nào hỏng thì app bỏ qua model và chuyển về chọn món bằng tay.

**Model giả để thử:** `python tool/make_dummy_food_model.py build/dummy_model`
(cần TensorFlow) tạo một model chưa train, đúng định dạng trên. Đây cũng là
mẫu cách xuất model. **Không** đưa model giả vào `assets/models/`.

## 7. Model phát hiện món trên đĩa (YOLO, từ v1.6)
**Vì sao cần:** model ở mục 6 chỉ trả lời "ảnh này là món gì". Một đĩa
cơm trắng với ức gà không phải món nào trong 91 món, nên khi thử thật model
đoán "Cà ri gà" 49%. Model phát hiện tìm **từng thứ trên đĩa**, mỗi thứ một
khung, nên đĩa đó ra "cơm" và "thịt gà". Nó cũng đếm được (2 quả trứng, 3
cuốn chả giò).

Đặt trong `assets/models/`, **không bắt buộc**: thiếu thì app chạy như cũ.
```
detector.tflite        model
detector_classes.txt   mỗi dòng một mã lớp, đúng thứ tự đầu ra
DETECTOR_CARD.md       ngày train, dữ liệu, kết quả, ngưỡng
```

### 7.1. Danh sách lớp
Thứ tự dưới đây là thứ tự đầu ra, không được đổi; lớp mới chỉ nối vào
cuối. Cột "Trong app" là thứ app đưa vào đĩa khi thấy lớp đó. Lớp có nhóm
biến thể thì người dùng bấm vào tên để chọn phần và cách nấu (mục 4,
`food_variants.csv`).

| # | Mã lớp | Khung VietFood67 | Mặt nạ MyFood | Trong app |
|---|---|---|---|---|
| 0 | `com` | Com | rice | `com` (nhóm Cơm & tinh bột) |
| 1 | `bun` | Bun | | `bun` |
| 2 | `mi` | Mi | spaghetti | `mi` |
| 3 | `banh_mi_o` | Banh mi | | `banh_mi_o` |
| 4 | `ga` | Thit ga | chicken_breast | `ga` (nhóm Gà) |
| 5 | `thit_kho` | Thit kho | | `thit_kho` (nhóm Heo) |
| 6 | `thit_nuong` | Thit nuong | | `thit_nuong` (nhóm Heo) |
| 7 | `heo` | Thit heo, Heo quay | | biến thể heo "nửa nạc nửa mỡ, luộc" (nhóm Heo) |
| 8 | `bo` | Thit bo | steak | `bo` (nhóm Bò) |
| 9 | `ca` | Ca | | `ca` (nhóm Cá) |
| 10 | `tom` | Tom | | `tom` |
| 11 | `muc` | Muc | | `_base_muc_chien` |
| 12 | `trung` | Trung | boiled_egg, fried_egg | `trung_kho` (nhóm Trứng) |
| 13 | `dau_hu` | Dau hu | | `dau_hu` |
| 14 | `cha` | Cha | | `cha_lua` |
| 15 | `cha_gio` | Cha gio | | `_base_cha_gio` |
| 16 | `rau` | Rau, Bong cai | salad | `rau_nau` |
| 17 | `dua_leo_ca_chua` | Dua leo, Ca chua | | `dua_leo_ca_chua` |
| 18 | `do_chua` | Dua chua | | `do_chua` |
| 19 | `khoai_tay_chien` | Khoai tay chien | | `_base_khoai_tay_chien` |
| 20 | `canh` | Canh | | `_base_canh_chua` (**ước lượng**: mọi loại canh tính như canh chua) |

- Mã lớp trùng mã thành phần khi có thành phần đó (`com`, `ga`…). Các lớp
  `heo`, `muc`, `trung`, `cha`, `cha_gio`, `rau`, `khoai_tay_chien`, `canh`
  không có thành phần cùng tên, app đổi theo bảng trên.
- Dinh dưỡng của mọi lớp lấy từ `components.csv` và `food_variants.csv`,
  không có số mới.
- Khung VietFood67 khác không thuộc lớp nào (người, chanh, ớt, nấm…) là nền.
- Ảnh VietFood67 có khung **cả món** (Phở, Cơm tấm, Bún bò Huế…) mặc định
  không dùng: trong khung đó, cơm, trứng, chả thường không được khoanh riêng,
  nên train vào sẽ dạy model rằng chúng là nền. Notebook có cờ
  `KEEP_DISH_PHOTOS` để thử dùng.
- MyFood: mỗi vùng liền của một giá trị mặt nạ là một khung (hai quả trứng
  thành hai khung). Táo và đậu (bean) là nền.

### 7.2. Định dạng model
| Mục | Quy định |
|---|---|
| Đầu vào | `float32`, ảnh **RGB, giá trị 0–1** (khác model mục 6, vốn nhận 0–255). Dạng `[1, 3, S, S]` (bản xuất LiteRT của Ultralytics) hoặc `[1, S, S, 3]` (bản xuất cũ qua onnx2tf); app nhận cả hai, đọc S từ file. YOLO11n dùng S = 640, YOLO11s dùng S = 512 |
| Tiền xử lý | App: thu nhỏ ảnh giữ tỉ lệ cho cạnh dài bằng S, đặt vào giữa, phần thừa tô xám (114, 114, 114) như lúc train ("letterbox") |
| Đầu ra | Một tensor `float32 [1, 4 + số_lớp, A]` (A = 8400 khi S = 640, 5376 khi S = 512); app cũng nhận dạng chuyển vị `[1, A, 4 + số_lớp]`. Bốn dòng đầu là `cx, cy, w, h` của khung, chia cho S (0–1); nếu giá trị lớn hơn 2 thì app coi là pixel và tự chia. Các dòng sau là điểm của từng lớp, 0–1 |
| NMS | Không nằm trong model. App bỏ khung dưới `threshold_box`, rồi với mỗi lớp bỏ khung trùng khung điểm cao hơn quá `threshold_iou` |
| Lượng tử hoá | Trọng số FP32 hoặc FP16; đầu vào và đầu ra vẫn là float32. App đang dùng bản FP16, tạo từ file FP32 bằng `python tool/train/tflite_to_fp16.py detector.tflite detector_fp16.tflite`. Bản INT8 động (`w8a32`, file `detector_int8.tflite`) không chạy được với tflite_flutter 0.12.1 ("Input tensor 207 lacks data") nên không dùng |
| Kích thước | YOLO11n: khoảng 10 MB (FP32), 3 MB (INT8). YOLO11s: khoảng 37 MB (FP32), 10 MB (INT8), ước tính theo số tham số |
| Tốc độ | Mục tiêu ≤ 400 ms mỗi ảnh trên điện thoại tầm trung |

**`DETECTOR_CARD.md`**, mỗi dòng `khoá: giá trị` như `MODEL_CARD.md`:
```
contract_version: 1.6
threshold_box: 0.35
threshold_iou: 0.5
```
Thiếu dòng nào thì app dùng số mặc định ở trên. Thẻ cũng ghi mAP50 và
mAP50-95 của từng lớp trên tập test.

**App kiểm tra khi nạp model:** đầu vào float32 bốn chiều, có một chiều
bằng 3; đầu ra có một chiều bằng `4 + số dòng của detector_classes.txt`;
mọi mã lớp phải có trong bảng ở 7.1. Sai thì app bỏ qua model phát hiện và
chỉ dùng model mục 6.

### 7.3. App dùng kết quả thế nào
- Chạy cả hai model trên cùng ảnh.
- Thấy từ **2 lớp khác nhau** trở lên thì app mở sẵn "Đĩa có N món", mỗi
  món một dòng. Các món model mục 6 đoán vẫn hiện bên cạnh để bấm chọn.
- Ngoại lệ: model mục 6 chắc chắn (từ `threshold_confident_dish`) **và**
  mọi lớp thấy được đều là thành phần của món đó (ví dụ cơm tấm có cơm,
  trứng, thịt nướng). Khi đó app mở món như cũ, vì công thức món đủ hơn
  (có nước mắm, mỡ hành).
- Chỉ thấy 1 lớp: app mở "Đĩa có 1 món" khi model mục 6 không chắc món
  nào hoặc đoán là món ngoài app (`khac`), để người dùng thêm phần còn lại; model mục 6 chắc thì mở món như cũ.
  Không thấy gì thì như cũ.
- Mỗi lớp thành một dòng trên đĩa, với khẩu phần thường gặp
  (`typicalPortion`). Riêng `trung`, `cha_gio`, `banh_mi_o` lấy **số khung**
  làm số quả / cuốn / ổ. Tôm, chả lụa thường được khoanh cả đống trong một
  khung nên không đếm.
- Khung được vẽ lên ảnh, cùng tên và điểm.
- Ước lượng số gam từ diện tích khung **chưa làm**: cần biết cỡ đĩa thật.

### 7.4. Train
- Notebook `tool/train/train_detector.ipynb`, sinh từ `train_detector.py`.
  Người dùng tự chạy trên Colab (GPU T4).
- Dữ liệu: khung có sẵn của VietFood67, mặt nạ MyFood đổi ra khung, và khung
  từng miếng của FoodInsSeg; giữ cách chia train/val/test của từng bộ.
- Thêm vào **train** (không vào val, test): `autolabel.zip` do notebook
  `tool/train/autolabel_detector.ipynb` làm.
  - Ảnh món Việt của 30VNFoods, VinaFood21, 20FoodVN được Grounding DINO
    khoanh theo các thứ món đó có. Lớp của khung lấy theo tên món (thịt
    trên đĩa cơm tấm là `thit_nuong`). Model phát hiện hiện có kiểm tra lại
    từng khung.
  - Món có sợi nằm trong nước (phở, bún bò, hủ tiếu, mì Quảng) không dùng,
    vì VietFood67 khoanh cả bát thành một món chứ không khoanh `bun`, `mi`.
  - Khung khoai tây chiên, tôm, cà chua, dưa leo, bông cải, bắp cải trên
    đĩa hay bát của Open Images.
  - Khung do máy làm nên chỉ dùng để train; điểm test vẫn đo trên khung do
    người vẽ, so được với các lần train trước.
- Model: YOLO11s của Ultralytics ở 512 px, bắt đầu từ trọng số COCO. Bản
  YOLO11n 640 px (train từ đầu, rồi fine-tune với FoodInsSeg) là bản trước,
  và vẫn là bản trong `assets/models` cho đến khi bản YOLO11s train xong.
- License Ultralytics: **AGPL-3.0**, phải ghi rõ trong báo cáo. MyFood: CC
  BY 4.0. FoodInsSeg: CC BY-NC-SA 4.0. Open Images: khung CC BY 4.0, ảnh
  theo license từng ảnh (phần lớn CC BY 2.0). Grounding DINO: Apache-2.0.

## 8. Ghi vào nhật ký ăn uống
Mỗi thành phần người dùng xác nhận được ghi thành **một dòng `food_log`**:
- `source = camera`;
- `confidence` = xác suất model đưa ra cho thành phần đó;
- `name` là tên thành phần, kèm tên món, ví dụ "Sườn nướng (cơm tấm)".

Bảng `food_log` đã có sẵn từ commit `d4806b1`, không cần đổi database.

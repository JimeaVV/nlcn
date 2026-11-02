# Chế độ nhận diện online (tùy chọn): thiết kế

Trạng thái: **thiết kế, chưa làm**. Số liệu dẫn tới thiết kế này nằm trong
`docs/QUA_TRINH_THUC_HIEN.md`, mục "2026-11-02 · So detector với Gemini trên
cùng 459 ảnh cơm phần".

Trên 459 ảnh cơm phần, so ở cùng mức báo sai (khoảng 0.6 món sai mỗi ảnh):

| | Gemini 3.5 Flash-Lite | Detector |
|---|---|---|
| Món tìm được | 76.5% | 65.6% |
| Gà tìm được | 116/144 | 81/144 |

Đổi lại, Gemini cần mạng, mất khoảng 2.4 s mỗi ảnh và gửi ảnh ra khỏi máy.
Vì vậy Gemini chỉ là chế độ thêm, người dùng tự bật; app vẫn chạy offline
như cũ.

## 1. Nguyên tắc

1. **Offline là mặc định.** Khi chưa bật, app không gửi gì lên mạng, giống
   hiện nay.
2. **Ảnh chỉ rời máy khi người dùng đã đồng ý.** Phải có đủ ba điều kiện:
   công tắc đang bật, có key, và người dùng đã bấm đồng ý trong hộp thoại ở
   mục 5.
3. **Không có kết quả online thì dùng kết quả offline.** Áp dụng khi mất
   mạng, quá 8 giây, lỗi, hết lượt gọi hoặc JSON hỏng. Lúc đó app dùng kết
   quả của detector và báo một dòng ngắn cho người dùng.
4. **APK không chứa key.** Người dùng tự nhập key Gemini của mình (mục 4).
5. **Gemini chỉ cho biết tên món, không cho số dinh dưỡng.**
   - Gemini trả lớp (một trong 21 lớp của detector) và số gam.
   - Kcal và macro vẫn tính từ CSV trong `assets/data/vn_food`, qua
     `detectorFoods` như với detector.
   - Món Gemini xếp vào `other` không có số dinh dưỡng nào. App chỉ hiện tên
     món và để người dùng tự thêm.
6. **Chung contract với detector.** Gemini dùng cùng danh sách lớp
   (`detector_classes.txt`), cùng mô tả lớp và cùng câu lệnh với
   `tool/eval/gemini_compare.py`. Như vậy số đo được ở trên vẫn đúng cho
   app.

## 2. Luồng quét

`ScanResultScreen._recognize()` hiện chạy song song detector và model nhận
món. Khi bật online, có thêm việc thứ ba chạy cùng lúc:

```
chụp ảnh ─┬─ detector (≈0.2 s) ───────────────┐
          ├─ model nhận món (đĩa một món) ────┼─► dựng đĩa
          └─ Gemini (≈2.4 s, tối đa 8 s) ─────┘
```

- **Gemini trả lời kịp:** dựng đĩa bằng `ScanPlate.online(...)` (mục 3).
  - Khung của detector vẫn vẽ trên ảnh, nhưng chỉ cho những lớp mà Gemini
    cũng thấy.
  - Món chỉ Gemini thấy thì vẫn có dòng trong danh sách, chỉ không có khung.
- **Gemini lỗi hoặc quá 8 giây:** dựng đĩa như hiện nay, từ detector. Hiện
  một snackbar, ví dụ "Không kết nối được Gemini, đã dùng nhận diện
  offline".
- **Trong lúc chờ:** hiệu ứng quét vẫn chạy và có nút "Dùng kết quả
  offline", để người dùng không phải chờ đủ 8 giây khi mạng chậm.
- Không hiện kết quả offline trước rồi mới thay bằng kết quả online, vì
  người dùng có thể đang sửa đĩa thì bị thay mất.
- Kết quả có một nhãn nhỏ "Online · Gemini" hoặc "Offline", để người dùng
  biết món do đâu nhận ra.
- Ghi nhật ký ăn vẫn dùng `FoodLogSource.camera`, không cần sửa database.

## 3. Từ câu trả lời của Gemini tới đĩa

Câu trả lời có dạng `{"foods": [{"class", "name", "grams"}]}` (schema trong
`gemini_compare.py`). Thêm một trường `count` cho `trung`, `cha_gio`,
`banh_mi_o`, vì app đếm các món này theo cái (contract §7.3).

`ScanPlate.online(data, foods)` làm giống `ScanPlate.detected`:

- `class` được đổi sang thành phần bằng `detectedComponent()`, vẫn qua
  `detectorFoods` và `detectorVariantFoods`. Món trùng chỉ giữ một dòng.
- Lượng ăn:
  - **Bản đầu dùng `typicalPortion` như detector, không dùng số gam của
    Gemini.** Số gam của Gemini chưa được đo.
  - Khi đã so số gam Gemini đoán với số cân thật của Nutrition5k (mục 8), và
    sai số nhỏ hơn `typicalPortion`, thì mới dùng số gam Gemini, giới hạn
    trong khoảng 0.25–3 lần khẩu phần thường. Lúc đó số này vẫn ghi là "ước
    lượng" và người dùng sửa được.
  - Món đếm theo cái thì dùng `count`.
- `confidence`: Gemini không trả điểm tin cậy, nên để `null`. Không tự đặt ra
  một điểm số.
- Món loại `other` vào một danh sách riêng tên "Gemini thấy thêm":
  - mỗi món chỉ có tên và nút "Thêm thủ công" (mở ô tìm món sẵn có);
  - không có số kcal nào.

## 4. Key Gemini

**Chọn: người dùng tự nhập key của họ.**

- Người dùng tạo key miễn phí trong Google AI Studio.
- Mỗi người có hạn mức riêng: Flash-Lite 15 lần gọi một phút, 500 lần một
  ngày. Như vậy đủ cho một người, nhóm không phải trả tiền và không phải
  chạy máy chủ.
- Key lưu bằng `flutter_secure_storage` (Android Keystore), là dependency
  mới:
  - không lưu trong SharedPreferences hay SQLite;
  - không nằm trong file sao lưu của `backup_service.dart`;
  - không in ra log;
  - ô nhập key luôn che ký tự.
- Nút "Kiểm tra key" gửi một câu hỏi chỉ có chữ, không kèm ảnh, rồi báo key
  dùng được hay không.

Cách thay thế là proxy nhỏ (ví dụ Cloudflare Worker) giữ key của nhóm. Chưa
làm, vì:

- key miễn phí của nhóm chỉ có 500 lần gọi một ngày, chia cho mọi người
  dùng;
- proxy phải chặn người lạ gọi, nên cần thêm việc xác thực;
- nhóm phải giữ một máy chủ chạy trong lúc chấm đồ án.

Nếu sau này cần proxy, chỉ phải đổi địa chỉ gửi (mục 6). Phần còn lại giữ
nguyên.

## 5. Quyền riêng tư

- **Hộp thoại đồng ý** hiện khi người dùng bật công tắc lần đầu, và hiện lại
  nếu nội dung hộp thoại đổi. Nội dung nói rõ:
  - ảnh món ăn được gửi tới Google (Gemini API);
  - với key miễn phí, Google có thể dùng ảnh để cải thiện sản phẩm của họ;
  - app không gửi vị trí hay thông tin cá nhân nào;
  - có thể tắt bất cứ lúc nào trong Cài đặt.

  Bấm "Không" thì công tắc tắt lại.
- **Ảnh gửi đi đã được xử lý lại.**
  - Ảnh được xoay đúng chiều (`bakeOrientation`), thu về cạnh dài tối đa
    1024 px, rồi lưu lại thành JPEG mới bằng package `image`.
  - Nhờ vậy mọi EXIF (vị trí GPS, máy chụp) bị bỏ đi.
  - Ảnh gốc không rời máy.
- Request gửi kèm `store: false`, để Google không giữ cuộc hội thoại.
- **Quyền INTERNET:**
  - `android/app/src/main/AndroidManifest.xml` hiện không xin quyền này, nên
    bản release hoàn toàn offline.
  - Chế độ online bắt buộc phải thêm quyền này.
  - Báo cáo cần ghi rõ: app có quyền mạng, nhưng chỉ dùng khi người dùng bật
    chế độ online.

## 6. Gọi API

- Gọi thẳng Interactions API qua REST:
  `POST https://generativelanguage.googleapis.com/v1beta/interactions`, key
  đặt trong header `x-goog-api-key`.
- Dùng `dart:io` `HttpClient`, nên không cần thêm package `http`. Trong test
  thì thay bằng client giả.
- Model `gemini-3.5-flash-lite` là model đã đo. Model ghi trong file cấu
  hình, không viết cứng trong code.
- Không gửi lại khi gặp 429 hay 503, mà chuyển ngay sang kết quả offline.
  - Hết lượt trong ngày thì báo "Đã hết lượt Gemini hôm nay".
  - Khi đó app tạm không gọi Gemini tới nửa đêm giờ Thái Bình Dương (lúc
    Google đặt lại hạn mức).
- Gemini trả lời chậm nhất 8 giây (trung vị đo được là 2.4 s). Ảnh đã nén
  còn khoảng 100–300 KB.

## 7. Contract và file chung

- **Contract:** thêm mục "Nhận diện online" vào `docs/MODEL_CONTRACT.md`,
  ghi model, câu lệnh, schema, cách đổi lớp sang thành phần và cách chọn
  lượng ăn ở trên, rồi tăng số phiên bản.
  - Nhánh model phân loại thịt đã dùng số 1.8, nên nhánh nào merge sau thì
    lấy số tiếp theo.
- **Một nguồn cho mô tả lớp:** chuyển `DESCRIPTIONS` từ
  `gemini_compare.py` sang file asset mới
  `assets/models/online_classes.json`.
  - Nội dung file: mô tả tiếng Việt và tiếng Anh của từng lớp, cùng phần
    hướng dẫn trong câu lệnh.
  - Cả app lẫn script đều đọc file này, nên câu lệnh trong app luôn trùng
    câu lệnh đã đo.
  - Thêm một test kiểm tra file này có đủ các lớp trong
    `detector_classes.txt`.
- Agent `model-contract-reviewer` rà phần này trước khi commit.

## 8. Đo thêm trước khi tin số gam

Nutrition5k có số cân thật của từng đĩa; nhánh dữ liệu detector đã tải một
phần về ổ D.

- Chạy `gemini_compare.py` trên các đĩa đó (thêm một chế độ chấm số gam).
- So sai số trung bình theo gam của hai cách:
  - số gam Gemini đoán;
  - `typicalPortion`.
- Cách nào sai ít hơn thì dùng cách đó (mục 3). Có hạn mức 500 lần một ngày
  nên đo được khoảng 400 đĩa trong một ngày.

## 9. Việc phải làm khi code

| Phần | File |
|---|---|
| Dịch vụ gọi Gemini, nén ảnh, đọc JSON | `lib/services/online_food_recognizer.dart` (mới) |
| Lưu công tắc, đồng ý, key | `lib/services/online_settings.dart` (mới), `flutter_secure_storage` |
| Đĩa từ câu trả lời Gemini | `lib/models/scan_plate.dart` (`ScanPlate.online`) |
| Chạy song song, chuyển sang offline, nút bỏ chờ, nhãn nguồn | `lib/screens/scan_result_screen.dart` |
| Mục "Nhận diện online (tùy chọn)" | `lib/screens/settings_screen.dart` |
| Chữ tiếng Việt và tiếng Anh | `lib/l10n/*.arb`, chạy `flutter gen-l10n` |
| Quyền mạng | `android/app/src/main/AndroidManifest.xml` |
| Mô tả lớp dùng chung | `assets/models/online_classes.json`, `tool/eval/gemini_compare.py` |
| Contract | `docs/MODEL_CONTRACT.md` |

Test cần có:

- đọc JSON đúng, JSON hỏng, lớp lạ, món `other`;
- chưa đồng ý hoặc chưa có key thì không có request nào (client giả đếm số
  lần gọi);
- lỗi, quá giờ hoặc 429 thì ra đĩa của detector;
- ảnh gửi đi không còn EXIF và cạnh dài không quá 1024 px;
- key không có trong file sao lưu.

Giao diện thì chạy skill `ui-screenshots`, rồi nhờ agent `ui-reviewer` rà.

Ước lượng: khoảng 1–1.5 ngày code và test, cộng nửa ngày đo số gam.

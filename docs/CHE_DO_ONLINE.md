# Chế độ nhận diện online (tùy chọn): thiết kế

Trạng thái: **đã làm cho bản dev test** (2026-11-02). Bản làm khác thiết kế
ban đầu ở chỗ key: dùng key của nhóm đưa vào lúc build, không bắt người dùng
nhập (mục 4). Số liệu dẫn tới thiết kế này nằm trong
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
4. **Repo không chứa key.** Key chỉ có trong bản dev test, đưa vào lúc build
   (mục 4). Bản build không có key (CI, release) không có chế độ online.
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

Câu trả lời có dạng `{"foods": [{"class", "name", "grams"}]}`, đúng schema
đã đo. Không thêm trường nào, để câu hỏi giữ nguyên như lúc đo.

`ScanPlate.online(data, codes, detection)` làm giống `ScanPlate.detected`.
`codes` là các lớp Gemini nêu, mỗi lớp một lần. `detection` là kết quả của
detector chạy cùng lúc.

- `class` được đổi sang thành phần bằng `detectedComponent()`, vẫn qua
  `detectorFoods` và `detectorVariantFoods`. Món trùng chỉ giữ một dòng.
- Lượng ăn:
  - **Bản đầu dùng `typicalPortion` như detector, không dùng số gam của
    Gemini.** Số gam của Gemini chưa được đo.
  - Khi đã so số gam Gemini đoán với số cân thật của Nutrition5k (mục 8), và
    sai số nhỏ hơn `typicalPortion`, thì mới dùng số gam Gemini, giới hạn
    trong khoảng 0.25–3 lần khẩu phần thường. Lúc đó số này vẫn ghi là "ước
    lượng" và người dùng sửa được.
  - Món đếm theo cái (`trung`, `cha_gio`, `banh_mi_o`, contract §7.3)
    lấy số khung của detector nếu detector cũng thấy món đó, không thì lấy
    khẩu phần thường.
  - Nếu sau này muốn Gemini đếm, phải thêm trường `count` vào schema, đo lại
    và tăng phiên bản contract.
- `confidence`: Gemini không trả điểm tin cậy, nên để `null`. Không tự đặt ra
  một điểm số.
- Món loại `other` hiện thành một dòng "Gemini còn thấy: …", chỉ có tên,
  không có số kcal nào. Muốn ghi thì người dùng thêm bằng tay như mọi món.
- Gemini trả lời nhưng không nêu lớp nào của detector (chỉ có `other`, hoặc
  danh sách rỗng): app dùng đĩa của detector như khi không có câu trả lời,
  nhưng không báo lỗi.
- Khung vẽ trên ảnh vẫn là khung của detector, nhưng chỉ vẽ cho các lớp
  Gemini cũng nêu.

## 4. Key Gemini

**Ban đầu chọn để người dùng tự nhập key. Bản đã làm dùng key của nhóm**,
vì người dùng thường không biết API key là gì (người dùng quyết định ngày
2026-11-02).

- Key đưa vào lúc build:

  ```
  flutter build apk --dart-define=GEMINI_API_KEY=<key>
  ```

  Code đọc bằng `String.fromEnvironment`. Key không nằm trong repo, CI hay
  bất kỳ file nào được commit. Trên máy Người A, key lấy từ biến môi trường
  `GEMINI_API_KEY` của tài khoản người dùng.
- Build không có key thì mục Cài đặt bị ẩn và app không gọi mạng.
- **Rủi ro, và vì sao vẫn chấp nhận:**
  - Ai có file APK cũng lấy được key ra, vì key nằm trong mã đã biên dịch.
  - Key thuộc project miễn phí, chưa gắn thẻ thanh toán, nên tệ nhất là hết
    500 lần gọi trong ngày, không mất tiền.
  - Chỉ gửi APK cho người thử, không đăng công khai.
  - Bị lộ thì xoá key trong AI Studio, tạo key mới rồi build lại.
- Hạn mức Flash-Lite là 15 lần gọi một phút và 500 lần một ngày, tính
  chung cho mọi máy dùng bản dev test.

Nếu sau này phát hành rộng hơn, có hai cách để APK không chứa key:

- người dùng tự nhập key, lưu bằng `flutter_secure_storage`;
- một proxy nhỏ giữ key.

Chỉ phải đổi chỗ lấy key và địa chỉ gửi (mục 6); phần còn lại giữ nguyên.

## 5. Quyền riêng tư

- **Hộp thoại đồng ý** hiện khi người dùng bật công tắc lần đầu, và hiện lại
  nếu nội dung hộp thoại đổi. Nội dung nói rõ:
  - ảnh món ăn được gửi tới Google (Gemini API);
  - với key miễn phí, Google có thể dùng ảnh để cải thiện sản phẩm của họ;
  - app không gửi vị trí hay thông tin cá nhân nào;
  - có thể tắt bất cứ lúc nào trong Cài đặt.

  Bấm "Hủy" thì công tắc vẫn tắt. Đã đồng ý rồi thì tắt, bật lại không hỏi
  nữa; đổi `OnlineRecognizer.consentVersion` thì hỏi lại.
- **Ảnh gửi đi đã được xử lý lại.**
  - Ảnh được xoay đúng chiều (`bakeOrientation`), thu về cạnh dài tối đa
    1024 px, rồi lưu lại thành JPEG mới bằng package `image`.
  - Nhờ vậy mọi EXIF (vị trí GPS, máy chụp) bị bỏ đi.
  - Ảnh gốc không rời máy.
- Request gửi kèm `store: false`, để Google không giữ cuộc hội thoại.
- **Quyền INTERNET:**
  - Trước đây `android/app/src/main/AndroidManifest.xml` không xin quyền này,
    nên bản release hoàn toàn offline.
  - Nay đã thêm, vì chế độ online cần.
  - Báo cáo cần ghi rõ: app có quyền mạng, nhưng chỉ dùng khi bản build có
    key và người dùng bật chế độ online.

## 6. Gọi API

- Gọi thẳng Interactions API qua REST:
  `POST https://generativelanguage.googleapis.com/v1beta/interactions`, key
  đặt trong header `x-goog-api-key`.
- Dùng `dart:io` `HttpClient`, nên không cần thêm package `http`. Trong test
  thì thay bằng client giả.
- Model `gemini-3.5-flash-lite` là model đã đo và là mặc định. Tên model
  ghi trong `assets/models/online_classes.json`.
- Trong Cài đặt có thể đổi sang `gemini-3.8-flash` (`OnlineModel.flash`).
  - Người dùng muốn thử model này vì nó mạnh hơn, dù chưa được đo.
  - Model này suy nghĩ trước khi trả lời, nên app gửi
    `thinking_level: low` và chờ tối đa 20 giây thay cho 8 giây.
  - Gói miễn phí của model này chỉ có 5 lần gọi một phút và 20 lần một
    ngày.
  - Muốn đo thì chạy `gemini_compare.py --model gemini-3.8-flash --thinking
    low`.
- Không gửi lại khi gặp 429 hay 503, mà chuyển ngay sang kết quả offline.
  - Gặp 429 thì báo "Hết lượt Gemini hôm nay".
  - Chưa làm phần tạm ngừng gọi tới nửa đêm giờ Thái Bình Dương (lúc Google
    đặt lại hạn mức). Mỗi lần quét vẫn thử gọi một lần, rồi chuyển sang
    offline ngay.
- Gemini trả lời chậm nhất 8 giây (trung vị đo được là 2.4 s). Ảnh đã nén
  còn khoảng 100–300 KB.

## 7. Contract và file chung

- **Contract:** đã thêm mục 10 vào `docs/MODEL_CONTRACT.md` và tăng lên
  1.9, vì số 1.8 đã dành cho nhánh model phân loại thịt.
- **Một nguồn cho mô tả lớp:** chuyển `DESCRIPTIONS` từ
  `gemini_compare.py` sang file asset mới
  `assets/models/online_classes.json`.
  - Nội dung file: mô tả tiếng Việt và tiếng Anh của từng lớp, cùng phần
    hướng dẫn trong câu lệnh.
  - Cả app lẫn script đều đọc file này, nên câu lệnh trong app luôn trùng
    câu lệnh đã đo.
  - `python tool/eval/gemini_compare.py --print-request
    test/fixtures/gemini_request.json` xuất câu lệnh và schema.
    `test/online_recognizer_test.dart` kiểm tra app dựng ra đúng như vậy.
  - App báo lỗi nếu file thiếu một lớp nào trong `detector_classes.txt`.
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

## 9. Đã làm

| Phần | File |
|---|---|
| Gọi Gemini, nén ảnh, đọc JSON, lưu công tắc và đồng ý | `lib/services/online_recognizer.dart` |
| Đĩa từ câu trả lời Gemini | `lib/models/scan_plate.dart` (`ScanPlate.online`) |
| Chạy song song, chuyển sang offline, nút bỏ chờ, nhãn nguồn | `lib/screens/scan_result_screen.dart` |
| Mục "Nhận diện online (dev test)" và hộp thoại đồng ý | `lib/screens/settings_screen.dart` |
| Chữ tiếng Việt và tiếng Anh | `lib/l10n/*.arb` |
| Quyền mạng | `android/app/src/main/AndroidManifest.xml` |
| Mô tả lớp dùng chung | `assets/models/online_classes.json`, `tool/eval/gemini_compare.py` |
| Contract | `docs/MODEL_CONTRACT.md` mục 10 |

Test đã có:

- `test/online_recognizer_test.dart`:
  - câu lệnh trùng câu đã đo;
  - không có key hoặc chưa đồng ý thì không có request nào;
  - đọc đúng câu trả lời, kể cả lớp lạ và món `other`;
  - phân biệt mất mạng, quá giờ, hết lượt và lỗi khác;
  - ảnh gửi đi không còn EXIF và cạnh dài không quá 1024 px.
- `test/scan_online_test.dart`:
  - đĩa dựng theo các món Gemini nêu, dinh dưỡng lấy từ CSV, khẩu phần
    thường;
  - hết lượt thì dùng đĩa của detector và báo cho người dùng;
  - bấm "Dùng kết quả offline" thì thôi chờ Gemini;
  - chưa đồng ý thì không gửi ảnh.
- Golden `scan_online` và `settings_online` trong `tool/ui_screenshots`.

Chưa làm:

- đo số gam của Gemini (mục 8);
- tạm ngừng gọi sau khi hết lượt trong ngày (mục 6).

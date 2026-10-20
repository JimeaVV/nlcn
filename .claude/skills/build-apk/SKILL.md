---
name: build-apk
description: Build the release APK for arm64 phones, check its signature, and optionally install it on the test phone over adb. Use when the user asks to build, gửi APK, cài lên điện thoại.
disable-model-invocation: true
argument-hint: "[tên model, vd efficientnetb3] [install]"
---

# Build APK MacroRunner

Đường dẫn Flutter, Android SDK, điện thoại và chứng chỉ của máy này nằm trong
`CLAUDE.local.md`. Đọc file đó trước. Nếu không có file đó (máy khác), hỏi
người dùng các đường dẫn.

## 1. Chọn build number
Build number phải **lớn hơn** bản đang cài trên điện thoại; nhỏ hơn thì
Android không cho cài đè.

```bash
"$ADB" shell dumpsys package io.github.jimeavv.optifit | grep -m1 versionCode
```

Lấy versionCode đó cộng 1. Nếu không kết nối được điện thoại, lấy số ghi
trong `CLAUDE.local.md` cộng 1.

## 2. Build
```bash
export ANDROID_HOME='<Android SDK trong CLAUDE.local.md>'
"<flutter trong CLAUDE.local.md>/flutter.bat" build apk --release \
  --split-per-abi --target-platform android-arm64 --build-number <N>
```

- Chỉ build arm64: điện thoại hiện nay đều là arm64, và file nhỏ hơn bản
  universal nhiều.
- Build mất vài phút; chạy nền nếu cần.
- File ra ở `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

## 3. Kiểm tra chữ ký
```bash
"<SDK>/build-tools/36.0.0/apksigner.bat" verify --print-certs \
  build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | grep SHA-256
```

SHA-256 phải bắt đầu bằng mã ghi trong `CLAUDE.local.md`. Nếu khác:
- `android/key.properties` bị thiếu, nên app đã ký bằng key debug.
- Bản này không cài đè được lên bản đang có trên điện thoại.

Báo người dùng, **không** tự sửa và **không** mở file `key.properties`.

## 4. Đặt tên
Model đang dùng xem ở dòng "Kiến trúc" trong `assets/models/MODEL_CARD.md`,
hoặc lấy từ tham số đầu tiên.

```bash
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
  build/app/outputs/flutter-apk/MacroRunner-<model>-arm64.apk
```

## 5. Cài lên điện thoại (chỉ khi người dùng bảo, hoặc tham số có `install`)
```bash
"$ADB" install -r build/app/outputs/flutter-apk/MacroRunner-<model>-arm64.apk
"$ADB" shell monkey -p io.github.jimeavv.optifit -c android.intent.category.LAUNCHER 1
```

- Nếu adb không thấy máy, nhắc người dùng bật *Gỡ lỗi không dây* rồi ghép
  nối lại. Không đoán địa chỉ IP.
- Không chụp màn hình điện thoại khi chưa hỏi.

## 6. Báo lại và ghi nhật ký
- Báo người dùng: đường dẫn file, dung lượng (MB), build number, chữ ký có
  khớp không, đã cài chưa.
- Ghi số build mới vào `CLAUDE.local.md`.
- Một bản build không làm đổi code nên không cần mục nhật ký riêng. Nếu nó
  đi kèm thay đổi code, mục nhật ký của thay đổi đó ghi thêm build number.

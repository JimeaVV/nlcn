---
name: ui-screenshots
description: Render MacroRunner's main screens (Hôm nay, Nhật ký, Hồ sơ, Cài đặt) to PNG on this computer, in all four styles plus a small-phone, large-text pass, with the app's real fonts, then look at them. Use after changing the UI, before sending an APK, or when the user asks how a screen looks; never take phone screenshots instead without asking.
argument-hint: "[tên màn, vd diary] [tên giao diện, vd cyberpunk]"
---

# Chụp giao diện bằng golden test

CLAUDE.md không cho tự chụp màn hình điện thoại. Skill này vẽ các màn ngay
trên máy tính bằng golden test của Flutter, rồi Claude đọc file PNG để xem.

Đường dẫn Flutter của máy này nằm trong `CLAUDE.local.md`.

## 1. Chạy

```bash
flutter test tool/ui_screenshots --update-goldens
```

Mất khoảng 5–10 giây. Muốn chỉ một màn thì thêm `--plain-name diary`.

Ảnh nằm ở `tool/ui_screenshots/out/` (đã nằm trong `.gitignore`):

| File | Là gì |
|---|---|
| `<màn>_cyberpunk.png` | giao diện Neon (mã cũ vẫn là `cyberpunk`), rộng 412 px |
| `<màn>_minimalLight.png`, `_forest`, `_sunset` | ba giao diện còn lại |
| `<màn>_small_large_text.png` | máy nhỏ 360 px, chữ hệ thống ×1,3 |

Ảnh có chiều cao cố định cho mỗi màn, nên phần dưới có thể để trống.

## 2. Đọc kết quả

- **Một test bị FAIL** thường là bị tràn bố cục (`A RenderFlex overflowed by
  … pixels`). Log có ghi tên widget và vị trí trong code. Phải sửa xong mới
  coi là đạt.
- **Xem ảnh** bằng Read, ít nhất ba ảnh: `_cyberpunk`, `_minimalLight` và
  `_small_large_text` của các màn vừa sửa. Kiểm tra:
  - chữ hiện bằng Be Vietnam Pro; ô đen nghĩa là widget tự đặt `TextStyle`
    và làm mất font của theme (lỗi cũ của `NeonButton`);
  - số và đơn vị nằm cùng dòng (` `);
  - mỗi màn chỉ một thẻ `highlight` có viền sáng;
  - giao diện sáng không còn chữ trắng trên nền trắng (thường do màu cứng
    `Colors.white`);
  - không còn chữ lẻ rớt xuống dòng một mình, nút không bị cắt chữ.
- Gửi ảnh cho người dùng bằng SendUserFile khi họ muốn xem. Ghi rõ đây là
  ảnh vẽ trên máy tính, không phải ảnh chụp điện thoại.

## 3. Thêm màn mới

Màn mới thêm vào bảng `_screens` trong
`tool/ui_screenshots/screenshots_test.dart`, kèm chiều cao cần để hiện hết
nội dung. Màn cần dữ liệu thì thêm hàm vào database giả `_Database` (chỉ
những hàm màn đó gọi; hàm thiếu sẽ báo `UnimplementedError`).

Màn Quét và Kết quả quét cần camera và model nên chưa có trong bảng.

## Ghi chú

- Đây không phải test so ảnh (golden test thật). Ảnh không được commit và
  không chạy trong CI, nên khác font hay khác máy cũng không làm CI đỏ.
- Font Be Vietnam Pro nạp từ `assets/fonts`; icon nạp từ Flutter SDK
  (`FLUTTER_ROOT`). Thiếu icon thì kiểm tra biến này.

# Code Comment Quality

Áp dụng mọi lúc khi viết/sửa code. Bản đầy đủ: `.cursor/rules/code-comments.mdc`.

- Ưu tiên code tự giải thích; chỉ comment khi cần giải thích WHY / invariant / ràng buộc ngoài.
- Không comment theo prompt, nhật ký thay đổi, narration “bước 1/2/3”, TODO mơ hồ, hoặc code chết.
- Không để lại reasoning AI, “temporary”, “hack”, “debug” trong source.
- JSDoc/DartDoc chỉ khi truyền contract thật (lỗi, side effect, invariant).

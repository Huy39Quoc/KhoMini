import 'package:flutter/foundation.dart';

/// Hủy các controller/focus node dùng trong dialog hoặc bottom sheet.
///
/// Không được gọi `dispose()` ngay sau `await showDialog(...)`: lúc đó route đã
/// pop nhưng hiệu ứng đóng vẫn đang chạy, TextField bên trong còn dùng controller
/// nên Flutter ném lỗi "used after being disposed" và hiện màn hình đỏ
/// (`_dependents.isEmpty`). Hàm này chờ hiệu ứng đóng kết thúc rồi mới hủy.
void disposeAfterRouteCloses(Iterable<ChangeNotifier> items) {
  final list = items.toList();
  Future<void>.delayed(const Duration(milliseconds: 600), () {
    for (final item in list) {
      item.dispose();
    }
  });
}

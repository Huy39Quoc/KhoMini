import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/core/utils/safe_dispose.dart';

void main() {
  testWidgets('disposeAfterRouteCloses chỉ hủy controller sau khi route đóng xong',
      (tester) async {
    final controller = TextEditingController();

    disposeAfterRouteCloses([controller]);

    // Ngay lúc dialog vừa pop, controller vẫn phải dùng được.
    controller.addListener(() {});

    await tester.pump(const Duration(milliseconds: 700));

    // Sau khi hiệu ứng đóng kết thúc, controller đã bị hủy.
    expect(() => controller.addListener(() {}), throwsA(anything));
  });
}

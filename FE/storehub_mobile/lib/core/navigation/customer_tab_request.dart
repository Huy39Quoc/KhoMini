import 'package:flutter/material.dart';

/// Vị trí các tab ở màn hình chính của khách (khớp thứ tự thanh điều hướng dưới).
class CustomerTabs {
  static const int home = 0;
  static const int myUnits = 1;
  static const int explore = 2;
  static const int support = 3;
}

/// Các màn hình con (đặt kho, thanh toán...) đặt giá trị này để yêu cầu màn hình
/// chính của khách chuyển sang một tab; màn hình chính sẽ xử lý rồi đặt lại thành null.
final ValueNotifier<int?> customerTabRequest = ValueNotifier<int?>(null);

/// Quay về màn hình chính của khách và mở đúng tab.
void goToCustomerTab(BuildContext context, int tab) {
  customerTabRequest.value = tab;
  Navigator.of(context).popUntil((route) => route.isFirst);
}

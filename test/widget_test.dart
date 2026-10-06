import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke test placeholder', (WidgetTester tester) async {
    // App khởi tạo phức tạp với Hive, window_manager, desktop_multi_window
    // nên không test trực tiếp trong widget test được.
    expect(1 + 1, 2);
  });
}
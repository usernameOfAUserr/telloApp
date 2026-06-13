import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tello_app/src/controllers/tello_controller.dart';
import 'package:tello_app/src/providers/tello_provider.dart';

void main() {
  testWidgets('creates the Tello controller provider', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(telloControllerProvider), isA<TelloController>());
  });
}

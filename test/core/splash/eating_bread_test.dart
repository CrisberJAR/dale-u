import 'package:dale_u/core/splash/eating_bread.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('el splash muestra la animación Lottie y el mensaje', (
    tester,
  ) async {
    await tester.pumpWidget(const EatingBreadSplash());
    expect(find.byType(EatingBread), findsOneWidget);
    expect(find.text('Preparando la ruta…'), findsOneWidget);
    expect(find.byType(Lottie), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:monte_glass/main.dart';

void main() {
  testWidgets('Inicialização do app Monte Glass', (WidgetTester tester) async {
    await tester.pumpWidget(const MonteGlassApp());
  });
}

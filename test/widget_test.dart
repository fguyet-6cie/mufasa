import 'package:flutter_test/flutter_test.dart';
import 'package:mufasa/cot.dart';
import 'package:mufasa/main.dart';
import 'package:mufasa/partage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('La carte Mufasa démarre', (tester) async {
    SharedPreferences.setMockInitialValues({'indicatif': 'ALPHA 1', 'mode': 0});
    await tester.pumpWidget(const MufasaApp());
    expect(find.text('Mufasa'), findsOneWidget);
  });

  test('les positions reçues alimentent la liste des camarades', () {
    final p = Partage();
    p.recevoir(CotEvenement.maPosition(
            uid: 'B', indicatif: 'BRAVO', equipe: 'Red', lat: 1, lon: 2)
        .versXml());
    p.recevoir('<event uid="X" type="b-m-p"><point lat="1" lon="2"/></event>');
    p.recevoir('déchet');
    expect(p.camarades.keys, ['B']);
    expect(p.camarades['B']!.indicatif, 'BRAVO');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mufasa/cot.dart';
import 'package:mufasa/main.dart';
import 'package:mufasa/partage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('L\'accueil puis la carte Mufasa démarrent', (tester) async {
    SharedPreferences.setMockInitialValues({'indicatif': 'ALPHA 1', 'mode': 0});
    await tester.pumpWidget(const MufasaApp());
    // Écran d'accueil aux couleurs de la compagnie.
    expect(find.text('MUFASA'), findsOneWidget);
    expect(find.text('6e COMPAGNIE · 21e RIMa'), findsOneWidget);
    await tester.tap(find.text('ENTRER'));
    await tester.pump(const Duration(milliseconds: 500));
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

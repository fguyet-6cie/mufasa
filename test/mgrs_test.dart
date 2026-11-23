import 'package:flutter_test/flutter_test.dart';
import 'package:mufasa/mgrs.dart';

void main() {
  // Valeurs de référence calculées avec la bibliothèque « mgrs » (Python).
  final references = {
    (48.8583, 2.2945): '31U DQ 48251 11943', // tour Eiffel
    (43.2965, 5.3698): '31T FH 92230 96468', // Marseille
    (-33.8688, 151.2093): '56H LH 34368 50948',
    (64.1466, -21.9426): '27W VM 54138 13689',
    (60.39, 5.32): '32V KN 97230 00510', // exception Norvège
    (78.22, 15.65): '33X WG 14813 83004', // exception Svalbard
    (-45.0, -70.0): '19G DL 21184 16563',
    (49.5, 8.0): '32U MV 27592 83521',
    (16.0, -61.7): '20Q PC 39099 69370',
  };
  test('conversion en MGRS au mètre près', () {
    references.forEach((pos, attendu) {
      final obtenu = versMgrs(pos.$1, pos.$2);
      // On tolère 1 m d'écart d'arrondi sur l'est et le nord.
      final o = obtenu.split(' '), a = attendu.split(' ');
      expect(o.sublist(0, 2), a.sublist(0, 2), reason: '$pos');
      expect((int.parse(o[2]) - int.parse(a[2])).abs() <= 1, isTrue,
          reason: '$pos : $obtenu au lieu de $attendu');
      expect((int.parse(o[3]) - int.parse(a[3])).abs() <= 1, isTrue,
          reason: '$pos : $obtenu au lieu de $attendu');
    });
  });

  test('MGRS tapé à la main → position, au mètre près', () {
    references.forEach((pos, texte) {
      final r = depuisMgrs(texte);
      expect(r, isNotNull, reason: texte);
      // 1 m ≈ 0,000009° de latitude ; on tolère 2 m.
      expect(versMgrs(r!.$1, r.$2).substring(0, 6), texte.substring(0, 6));
      expect((r.$1 - pos.$1).abs() < 2e-5, isTrue,
          reason: '$texte → $r au lieu de $pos');
      expect((r.$2 - pos.$2).abs() * 0.7 < 3e-5, isTrue,
          reason: '$texte → $r au lieu de $pos');
    });
    expect(depuisMgrs('31udq4811'), isNotNull);
    expect(depuisMgrs('31U DQ 4825111943'), isNotNull);
    expect(depuisMgrs('bonjour'), isNull);
    expect(depuisMgrs('31U DQ 123'), isNull);
  });
}

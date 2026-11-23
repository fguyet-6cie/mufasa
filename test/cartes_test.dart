import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mufasa/cartes/tuiles.dart';

void main() {
  test('numéro de tuile (calcul de référence en Python)', () {
    // Tour Eiffel au zoom 16 : tuile x = 33185, y = 22545.
    expect(tuilePour(const LatLng(48.8583, 2.2945), 16), (33185, 22545));
    expect(tuilePour(const LatLng(0, 0), 1), (1, 1));
  });

  test('zone : liste et compte des tuiles concordent', () {
    const no = LatLng(48.87, 2.28), se = LatLng(48.85, 2.31);
    final l = tuilesZone(no, se, 10, 16);
    expect(l.length, compterTuiles(no, se, 10, 16));
    expect(l.first.$1, 10);
    expect(l.last.$1, 16);
    expect(l.toSet().length, l.length);
  });
}

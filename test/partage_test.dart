import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mufasa/partage.dart';

void main() {
  test('immobile : position envoyée une fois par minute seulement', () {
    final t0 = DateTime(2026, 11, 23, 15);
    const ici = LatLng(48.8463, 2.3037);
    const pasLoin = LatLng(48.84634, 2.3037); // ~4 m
    const plusLoin = LatLng(48.8465, 2.3037); // ~22 m
    bool envoi(LatLng actuelle, int secondes) => Partage.fautEnvoyer(
        dernierEnvoi: t0,
        maintenant: t0.add(Duration(seconds: secondes)),
        envoyee: ici,
        actuelle: actuelle);
    expect(envoi(pasLoin, 10), isFalse);
    expect(envoi(pasLoin, 50), isFalse);
    expect(envoi(pasLoin, 60), isTrue);
    expect(envoi(plusLoin, 10), isTrue);
    expect(
        Partage.fautEnvoyer(
            dernierEnvoi: t0, maintenant: t0, envoyee: null, actuelle: ici),
        isTrue);
  });
}

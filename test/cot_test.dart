import 'package:flutter_test/flutter_test.dart';
import 'package:mufasa/cot.dart';

void main() {
  test('un message de position se relit à l\'identique', () {
    final ev = CotEvenement.maPosition(
        uid: 'MUFASA-1',
        indicatif: 'ALPHA <1>',
        equipe: 'Red',
        lat: 48.8463,
        lon: 2.3037,
        precision: 5);
    final lu = CotEvenement.depuisXml(ev.versXml())!;
    expect(lu.uid, 'MUFASA-1');
    expect(lu.indicatif, 'ALPHA <1>');
    expect(lu.equipe, 'Red');
    expect(lu.lat, closeTo(48.8463, 1e-9));
    expect(lu.lon, closeTo(2.3037, 1e-9));
    expect(lu.type, 'a-f-G-U-C');
    expect(lu.estPerime, isFalse);
  });

  test('lit un message venant d\'un autre outil compatible CoT', () {
    const xml = '<?xml version="1.0" standalone="yes"?>'
        '<event version="2.0" uid="ANDROID-abc" type="a-f-G-U-C" how="h-e" '
        'time="2026-11-21T10:00:00Z" start="2026-11-21T10:00:00Z" '
        'stale="2026-11-21T10:06:00Z"><point lat="45.1" lon="5.7" hae="200" '
        'ce="10" le="10"/><detail><contact endpoint="*:-1:stcp" '
        'callsign="BRAVO"/><__group name="Cyan" role="Team Lead"/>'
        '<status battery="80"/></detail></event>';
    final ev = CotEvenement.depuisXml(xml)!;
    expect(ev.indicatif, 'BRAVO');
    expect(ev.lat, 45.1);
    expect(ev.estPerime, isTrue);
  });

  test('un message illisible est ignoré', () {
    expect(CotEvenement.depuisXml('n\'importe quoi'), isNull);
    expect(CotEvenement.depuisXml('<event uid="x"/>'), isNull);
  });

  test('le découpeur retrouve les messages dans un flux morcelé', () {
    final a = CotEvenement.maPosition(
            uid: 'A', indicatif: 'A', equipe: 'Cyan', lat: 1, lon: 2)
        .versXml();
    final b = CotEvenement.maPosition(
            uid: 'B', indicatif: 'B', equipe: 'Cyan', lat: 3, lon: 4)
        .versXml();
    final flux = a + b;
    final d = DecoupeurCot();
    final recus = <String>[];
    for (var i = 0; i < flux.length; i += 37) {
      recus.addAll(d.ajouter(
          flux.substring(i, i + 37 > flux.length ? flux.length : i + 37)));
    }
    expect(recus.map((m) => CotEvenement.depuisXml(m)!.uid), ['A', 'B']);
  });
}

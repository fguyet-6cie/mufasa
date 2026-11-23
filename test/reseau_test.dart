// Teste le mode Wi-Fi local avec de vraies connexions réseau locales.

import 'package:flutter_test/flutter_test.dart';
import 'package:mufasa/cot.dart';
import 'package:mufasa/reseau/liaison_io.dart';

String pos(String uid) =>
    CotEvenement.maPosition(uid: uid, indicatif: uid, lat: 48, lon: 2)
        .versXml();

void main() {
  test('mode sans serveur : multidiffusion sur le réseau local', () async {
    final a = LiaisonWifi();
    final b = LiaisonWifi();
    await a.demarrer();
    await b.demarrer();
    if (!a.etat.value.startsWith('active')) {
      markTestSkipped('multidiffusion indisponible ici : ${a.etat.value}');
      return;
    }
    final recu = b.messages
        .map(CotEvenement.depuisXml)
        .firstWhere((e) => e?.uid == 'ALPHA');
    for (var i = 0; i < 5; i++) {
      await a.envoyer(pos('ALPHA'));
      await Future.delayed(const Duration(milliseconds: 100));
    }
    final ev = await recu.timeout(const Duration(seconds: 3));
    expect(ev!.uid, 'ALPHA');
    await a.arreter();
    await b.arreter();
  });
}

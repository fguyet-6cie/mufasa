// Teste les deux modes de partage avec de vraies connexions réseau locales.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mufasa/cot.dart';
import 'package:mufasa/reseau/liaison_io.dart';

String pos(String uid) => CotEvenement.maPosition(
        uid: uid, indicatif: uid, equipe: 'Cyan', lat: 48, lon: 2)
    .versXml();

void main() {
  test('mode serveur : deux téléphones se voient via un relais TCP', () async {
    // Mini relais qui renvoie chaque message aux autres connectés,
    // comme le fait un serveur TAK.
    final serveur = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final clients = <Socket>[];
    serveur.listen((c) {
      clients.add(c);
      c.listen((data) {
        for (final autre in clients) {
          if (autre != c) autre.add(data);
        }
      });
    });

    final a = LiaisonServeur('127.0.0.1', serveur.port);
    final b = LiaisonServeur('127.0.0.1', serveur.port);
    await a.demarrer();
    await b.demarrer();
    expect(a.etat.value, 'connectée');
    await Future.delayed(const Duration(milliseconds: 200));

    final recu = b.messages.first;
    await a.envoyer(pos('ALPHA'));
    final ev =
        CotEvenement.depuisXml(await recu.timeout(const Duration(seconds: 5)))!;
    expect(ev.uid, 'ALPHA');

    await a.arreter();
    await b.arreter();
    await serveur.close();
  });

  test('mode serveur : se reconnecte quand le serveur revient', () async {
    final s1 = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = s1.port;
    await s1.close();
    final a = LiaisonServeur('127.0.0.1', port);
    await a.demarrer();
    expect(a.etat.value, contains('injoignable'));
    final s2 = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    final connexion = s2.first;
    await connexion.timeout(const Duration(seconds: 8));
    await Future.delayed(const Duration(milliseconds: 100));
    expect(a.etat.value, 'connectée');
    await a.arreter();
    await s2.close();
  });

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

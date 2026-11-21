// Test du mode 4G/5G avec une vraie boîte aux lettres MQTT locale.
// Lancer d'abord un serveur MQTT sur 127.0.0.1:18830, sinon le test est ignoré.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mufasa/cot.dart';
import 'package:mufasa/reseau/liaison_relais_io.dart';

LiaisonRelais relais(String uid, String code) => LiaisonRelais(
    hote: '127.0.0.1',
    port: 18830,
    identifiant: 'test',
    motDePasse: 'test',
    codeGroupe: code,
    uid: uid,
    tls: false);

void main() {
  test('mode 4G/5G : seuls les téléphones du même groupe se voient', () async {
    try {
      await (await Socket.connect('127.0.0.1', 18830)).close();
    } catch (_) {
      markTestSkipped('pas de serveur MQTT local');
      return;
    }
    final a = relais('A', 'groupe-un');
    final b = relais('B', 'groupe-un');
    final intrus = relais('X', 'groupe-deux');
    for (final l in [a, b, intrus]) {
      await l.demarrer();
      expect(l.etat.value, 'connectée');
    }
    final recusIntrus = <String>[];
    intrus.messages.listen(recusIntrus.add);
    final recu = b.messages
        .map(CotEvenement.depuisXml)
        .firstWhere((e) => e?.uid == 'ALPHA');
    await Future.delayed(const Duration(milliseconds: 300));
    await a.envoyer(CotEvenement.maPosition(
            uid: 'ALPHA', indicatif: 'ALPHA', equipe: 'Cyan', lat: 48, lon: 2)
        .versXml());
    final ev = await recu.timeout(const Duration(seconds: 5));
    expect(ev!.indicatif, 'ALPHA');
    await Future.delayed(const Duration(milliseconds: 300));
    expect(recusIntrus, isEmpty);
    for (final l in [a, b, intrus]) {
      await l.arreter();
    }
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mufasa/chiffrement.dart';
import 'package:mufasa/reglages.dart';

void main() {
  test('un message chiffré se relit avec le même code de groupe', () async {
    final a = await CleGroupe.depuisCode('Lion-Rouge-2026');
    final b = await CleGroupe.depuisCode('Lion-Rouge-2026');
    expect(a.casier, b.casier);
    final chiffre = await a.chiffrer('<event uid="A"/>');
    expect(String.fromCharCodes(chiffre).contains('event'), isFalse);
    expect(await b.dechiffrer(chiffre), '<event uid="A"/>');
  });

  test('un autre code de groupe ne peut rien lire', () async {
    final a = await CleGroupe.depuisCode('Lion-Rouge-2026');
    final c = await CleGroupe.depuisCode('Lion-Bleu-2026');
    expect(a.casier, isNot(c.casier));
    expect(await c.dechiffrer(await a.chiffrer('secret')), isNull);
    expect(await c.dechiffrer([1, 2, 3]), isNull);
  });

  test('une invitation se relit, même au milieu d\'un texte', () {
    const inv = Invitation(
        hote: 'abc.s1.eu.hivemq.cloud',
        port: 8883,
        identifiant: 'mufasa',
        motDePasse: 'Mot2Passe!',
        codeGroupe: 'Lion Rouge 2026');
    final texte = 'Rejoins le groupe :\n${inv.encoder()}\nmerci';
    final lu = Invitation.decoder(texte)!;
    expect(lu.hote, inv.hote);
    expect(lu.port, 8883);
    expect(lu.motDePasse, 'Mot2Passe!');
    expect(lu.codeGroupe, 'Lion Rouge 2026');
    expect(Invitation.decoder('bonjour'), isNull);
  });
}

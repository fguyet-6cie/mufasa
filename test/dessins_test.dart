import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mufasa/dessins.dart';
import 'package:mufasa/partage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Dessin exemple(String uid,
        {FormeDessin forme = FormeDessin.ligne,
        Map<String, String> fiche = const {},
        String auteur = 'AUTRE'}) =>
    Dessin(
      uid: uid,
      forme: forme,
      points: forme == FormeDessin.point
          ? const [LatLng(48, 2)]
          : const [LatLng(48, 2), LatLng(48.01, 2.01), LatLng(48.02, 2)],
      nom: 'OBJ <LION>',
      couleur: Colors.red,
      auteur: auteur,
      auteurIndicatif: 'ALPHA',
      fiche: fiche,
    );

void main() {
  test('point, ligne et zone se relisent à l\'identique', () {
    for (final f in [FormeDessin.point, FormeDessin.ligne, FormeDessin.zone]) {
      final lu = Dessin.depuisXml(exemple('D-$f', forme: f).versXml())!;
      expect(lu.forme, f);
      expect(lu.nom, 'OBJ <LION>');
      expect(lu.auteurIndicatif, 'ALPHA');
      expect(lu.couleur.toARGB32(), Colors.red.toARGB32());
      expect(lu.points.length, f == FormeDessin.point ? 1 : 3);
    }
  });

  test('un point particulier garde ses observations', () {
    final d = exemple('P1', forme: FormeDessin.point, fiche: const {
      'observations': 'Pont détruit, gué à 200 m "nord" & sec'
    });
    final xml = d.versXml();
    expect(xml, contains('<remarks>'));
    final lu = Dessin.depuisXml(xml)!;
    expect(lu.observations, 'Pont détruit, gué à 200 m "nord" & sec');
  });

  test('une zone est un tracé fermé lisible par d\'autres outils', () {
    final xml = exemple('Z', forme: FormeDessin.zone).versXml();
    expect('<link point='.allMatches(xml).length, 4); // 3 coins + retour
    expect(xml, contains('type="u-d-f"'));
  });

  test('les missions et symboles des anciennes versions sont ignorés', () {
    const ancien =
        '<event version="2.0" uid="M1" type="u-d-f" time="2026-11-21T10:00:00Z" '
        'start="2026-11-21T10:00:00Z" stale="2026-12-21T10:00:00Z">'
        '<point lat="48" lon="2" hae="0" ce="0" le="0"/><detail>'
        '<link point="48,2"/><link point="48.1,2"/>'
        '<__mufasa calque="Général" forme="mission" mission="attaquer"/>'
        '</detail></event>';
    expect(Dessin.depuisXml(ancien), isNull);
  });

  test('un ordre de suppression se relit', () {
    expect(Dessin.lireSuppression(Dessin.suppressionXml('D-1', 'MOI')), 'D-1');
    expect(Dessin.lireSuppression(exemple('X').versXml()), isNull);
  });

  test('partage : réception et suppression définitive', () async {
    SharedPreferences.setMockInitialValues({});
    final p = Partage();
    p.recevoir(exemple('D1').versXml());
    p.recevoir(exemple('D2').versXml());
    p.recevoir(Dessin.suppressionXml('D1', 'AUTRE'));
    expect(p.dessins.keys, ['D2']);
    // Le dessin effacé revient (renvoyé par un retardataire) : il est ignoré.
    p.recevoir(exemple('D1').versXml());
    expect(p.dessins.keys, ['D2']);
  });

  test('les dessins sont gardés dans le téléphone', () async {
    SharedPreferences.setMockInitialValues({});
    Partage().ajouterDessin(exemple('D9',
        forme: FormeDessin.point, fiche: const {'observations': 'RAS'}));
    await Future.delayed(const Duration(milliseconds: 50));
    final q = Partage();
    await q.chargerDessins();
    expect(q.dessins['D9']!.observations, 'RAS');
  });

  test('un ennemi signalé se relit avec sa fiche et prévient les autres',
      () async {
    SharedPreferences.setMockInitialValues({});
    final e = Dessin(
      uid: 'E1',
      forme: FormeDessin.ennemi,
      points: const [LatLng(48, 2)],
      nom: '',
      couleur: Colors.red,
      auteur: 'AUTRE',
      auteurIndicatif: 'BRAVO 2',
      fiche: const {
        'volume': '1 groupe',
        'nature': 'Infanterie',
        'remarques': 'armes "légères" & RPG',
        'observateur': 'BRAVO 2',
      },
    );
    final xml = e.versXml();
    expect(xml, contains('<remarks>'));
    final lu = Dessin.depuisXml(xml)!;
    expect(lu.forme, FormeDessin.ennemi);
    expect(lu.fiche['remarques'], 'armes "légères" & RPG');
    expect(lu.fiche['volume'], '1 groupe');

    final p = Partage();
    final alerte = p.nouveauxEnnemis.first;
    p.recevoir(xml);
    expect((await alerte).uid, 'E1');
    expect(p.camarades, isEmpty); // pas pris pour un camarade
    expect(p.dessins.keys, ['E1']);
  });

  test('l\'effacement d\'urgence vide tout le téléphone', () async {
    SharedPreferences.setMockInitialValues({'codeGroupe': 'SECRET'});
    final p = Partage()..ajouterDessin(exemple('D1'));
    p.recevoir(exemple('D2').versXml());
    await Future.delayed(const Duration(milliseconds: 50));
    await p.toutEffacer();
    expect(p.dessins, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
    final q = Partage();
    await q.chargerDessins();
    expect(q.dessins, isEmpty);
  });

  test('ennemi : toujours là, il a bougé, plus là', () {
    final e = Dessin(
      uid: 'E9',
      forme: FormeDessin.ennemi,
      points: const [LatLng(48, 2)],
      nom: '',
      couleur: Colors.red,
      auteur: 'A',
      auteurIndicatif: 'GOLF 21B',
      heure: DateTime.now().subtract(const Duration(minutes: 45)),
      fiche: const {'volume': '1 groupe', 'heure': '13h10'},
    );
    expect(e.estAncien, isTrue);
    final revu = e.toujoursLa(par: 'GOLF 32A', parUid: 'B');
    expect(revu.estAncien, isFalse);
    expect(revu.fiche['revuPar'], 'GOLF 32A');
    expect(revu.fiche['volume'], '1 groupe');

    final bouge = e.aBouge(const LatLng(48.01, 2.01), par: 'X', parUid: 'C');
    final lu = Dessin.depuisXml(bouge.versXml())!;
    expect(lu.points.first, const LatLng(48.01, 2.01));
    expect(lu.anciennePosition, const LatLng(48, 2));
    expect(lu.fiche['ancienHeure'], '13h10');

    final parti = Dessin.depuisXml(e.plusLa(par: 'X', parUid: 'C').versXml())!;
    expect(parti.disparu, isTrue);
    expect(parti.toujoursLa(par: 'Y', parUid: 'D').disparu, isFalse);
  });

  test('un ennemi signalé tout près est peut-être le même', () {
    final e = Dessin(
      uid: 'E1',
      forme: FormeDessin.ennemi,
      points: const [LatLng(48, 2)],
      nom: '',
      couleur: Colors.red,
      auteur: 'A',
      auteurIndicatif: 'A',
    );
    expect(ennemiProche([e], const LatLng(48.001, 2.001))?.uid, 'E1'); // ~130 m
    expect(ennemiProche([e], const LatLng(48.01, 2)), isNull); // ~1,1 km
    final disparu = e.plusLa(par: 'X', parUid: 'C');
    expect(ennemiProche([disparu], const LatLng(48.001, 2.001)), isNull);
  });

  test('sans réseau, les envois attendent et sont gardés', () async {
    SharedPreferences.setMockInitialValues({});
    final p = Partage();
    p.ajouterDessin(exemple('E1', forme: FormeDessin.ennemi));
    p.ajouterDessin(exemple('E1', forme: FormeDessin.ennemi)); // même dessin
    p.supprimerDessin('D2');
    expect(p.nombreEnAttente, 2);
    await Future.delayed(const Duration(milliseconds: 50));
    final relu = Partage();
    await relu.chargerDessins();
    expect(relu.nombreEnAttente, 2);
  });
}

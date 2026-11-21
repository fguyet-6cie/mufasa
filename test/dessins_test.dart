import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mufasa/dessins.dart';
import 'package:mufasa/partage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Dessin exemple(String uid,
        {FormeDessin forme = FormeDessin.ligne,
        String? mission,
        String calque = 'Phase 1',
        String auteur = 'AUTRE'}) =>
    Dessin(
      uid: uid,
      forme: forme,
      points: const [LatLng(48, 2), LatLng(48.01, 2.01), LatLng(48.02, 2)],
      nom: 'OBJ <LION>',
      couleur: Colors.red,
      calque: calque,
      auteur: auteur,
      auteurIndicatif: 'ALPHA',
      mission: mission,
      pion: mission == null ? '' : '2e SECTION',
    );

void main() {
  test('chaque forme de dessin se relit à l\'identique', () {
    for (final f in FormeDessin.values
        .where((f) => f != FormeDessin.symbole && f != FormeDessin.ennemi)) {
      final d = exemple('D-$f',
          forme: f, mission: f == FormeDessin.mission ? 'attaquer' : null);
      final lu = Dessin.depuisXml(d.versXml())!;
      expect(lu.forme, f);
      expect(lu.nom, 'OBJ <LION>');
      expect(lu.calque, 'Phase 1');
      expect(lu.auteurIndicatif, 'ALPHA');
      expect(lu.couleur.toARGB32(), Colors.red.toARGB32());
      expect(lu.points.length, f == FormeDessin.point ? 1 : 3);
      if (f == FormeDessin.mission) {
        expect(lu.laMission!.nom, 'Attaquer');
        expect(lu.pion, '2e SECTION');
      }
    }
  });

  test('une zone est un tracé fermé lisible par d\'autres outils', () {
    final xml = exemple('Z', forme: FormeDessin.zone).versXml();
    expect('<link point='.allMatches(xml).length, 4); // 3 coins + retour
    expect(xml, contains('type="u-d-f"'));
  });

  test('toutes les missions ont un code unique', () {
    expect(missions.map((m) => m.code).toSet().length, missions.length);
  });

  test('un ordre de suppression se relit', () {
    expect(Dessin.lireSuppression(Dessin.suppressionXml('D-1', 'MOI')), 'D-1');
    expect(Dessin.lireSuppression(exemple('X').versXml()), isNull);
  });

  test('partage : réception, calques masqués, suppression définitive',
      () async {
    SharedPreferences.setMockInitialValues({});
    final p = Partage();
    p.recevoir(exemple('D1').versXml());
    p.recevoir(exemple('D2', calque: 'Phase 2').versXml());
    expect(p.calques, ['Général', 'Phase 1', 'Phase 2']);
    p.basculerCalque('Phase 2', false);
    expect(p.dessinsVisibles.map((d) => d.uid), ['D1']);
    p.recevoir(Dessin.suppressionXml('D1', 'AUTRE'));
    expect(p.dessins.keys, ['D2']);
    // Le dessin effacé revient (renvoyé par un retardataire) : il est ignoré.
    p.recevoir(exemple('D1').versXml());
    expect(p.dessins.keys, ['D2']);
  });

  test('les dessins sont gardés dans le téléphone', () async {
    SharedPreferences.setMockInitialValues({});
    final p = Partage()
      ..ajouterDessin(
          exemple('D9', forme: FormeDessin.mission, mission: 'boucler'));
    await Future.delayed(const Duration(milliseconds: 50));
    final q = Partage();
    await q.chargerDessins();
    expect(q.dessins['D9']!.laMission!.nom, 'Boucler');
    expect(p.dessins.length, 1);
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
      calque: calqueEnnemis,
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
}

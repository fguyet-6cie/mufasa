import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mufasa/cot.dart';
import 'package:mufasa/dessins.dart';
import 'package:mufasa/hierarchie.dart';
import 'package:mufasa/rejeu/enregistrement.dart';
import 'package:mufasa/rejeu/rejeu.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 23, 14);
  CotEvenement pos(double lat) => CotEvenement(
      uid: 'A',
      indicatif: 'FAURE',
      lat: lat,
      lon: 2.3,
      place: const Place(Fonction.chefGroupe, section: 1, groupe: 2));

  test('enregistrement : on ne garde que les vrais déplacements', () {
    final lignes = <String>[];
    final e = Enregistreur(lignes.add);
    e.position(pos(48.8460), t0);
    e.position(pos(48.84601), t0.add(const Duration(seconds: 10))); // 1 m
    e.position(pos(48.8470), t0.add(const Duration(seconds: 20))); // 110 m
    e.position(pos(48.8470), t0.add(const Duration(seconds: 90))); // 1 min
    expect(lignes.length, 3);
  });

  test('rejeu : position, trace et dessins à une heure donnée', () {
    final lignes = <String>[];
    final e = Enregistreur(lignes.add);
    e.position(pos(48.8460), t0);
    e.position(pos(48.8470), t0.add(const Duration(minutes: 5)));
    final eni = Dessin(
      uid: 'E1',
      forme: FormeDessin.ennemi,
      points: const [LatLng(48.85, 2.31)],
      nom: '',
      couleur: Colors.red,
      auteur: 'A',
      auteurIndicatif: 'FAURE',
    );
    e.dessin(eni.versXml(), t0.add(const Duration(minutes: 2)));
    e.suppression('E1', t0.add(const Duration(minutes: 8)));
    final r = Rejeu.depuisLignes(lignes.reversed); // ordre rétabli au tri

    expect(r.debut, t0);
    expect(r.passageA('A', t0.subtract(const Duration(seconds: 1))), isNull);
    final p = r.passageA('A', t0.add(const Duration(minutes: 3)))!;
    expect(p.point.latitude, 48.8460);
    expect(p.place.section, 1);
    expect(p.indicatif, 'FAURE');
    expect(r.traceA('A', t0.add(const Duration(minutes: 6))).length, 2);
    // Silencieux depuis plus de 10 min : disparaît.
    expect(r.passageA('A', t0.add(const Duration(minutes: 20))), isNull);

    expect(r.dessinsA(t0.add(const Duration(minutes: 1))), isEmpty);
    expect(r.dessinsA(t0.add(const Duration(minutes: 3))).length, 1);
    expect(r.dessinsA(t0.add(const Duration(minutes: 9))), isEmpty);
  });
}

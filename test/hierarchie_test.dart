import 'package:flutter_test/flutter_test.dart';
import 'package:mufasa/cot.dart';
import 'package:mufasa/hierarchie.dart';

const cdu = Place(Fonction.cdu);
const cds1 = Place(Fonction.chefSection, section: 1);
const cds2 = Place(Fonction.chefSection, section: 2);
const cdg11 = Place(Fonction.chefGroupe, section: 1, groupe: 1);
const cdg12 = Place(Fonction.chefGroupe, section: 1, groupe: 2);
const cdg21 = Place(Fonction.chefGroupe, section: 2, groupe: 1);
const cde111 = Place(Fonction.chefEquipe, section: 1, groupe: 1, equipe: 1);
const cde112 = Place(Fonction.chefEquipe, section: 1, groupe: 1, equipe: 2);
const eq111 = Place(Fonction.equipier, section: 1, groupe: 1, equipe: 1);
const eq112 = Place(Fonction.equipier, section: 1, groupe: 1, equipe: 2);
const tous = [
  cdu,
  cds1,
  cds2,
  cdg11,
  cdg12,
  cdg21,
  cde111,
  cde112,
  eq111,
  eq112
];

List<Place> vus(Place moi, int profondeur,
        [Perimetre perimetre = Perimetre.compagnie]) =>
    [
      for (final p in tous)
        if (p != moi && estVisible(moi, p, profondeur, perimetre)) p
    ];

void main() {
  test('par défaut, tout le monde voit tout le monde', () {
    for (final moi in tous) {
      expect(vus(moi, 4).length, tous.length - 1, reason: '$moi');
    }
  });

  test('chacun choisit jusqu\'à quel niveau il affiche', () {
    expect(vus(eq111, 1), [cdu, cds1, cds2]);
    expect(vus(cdu, 2), [cds1, cds2, cdg11, cdg12, cdg21]);
  });

  test('ma section seulement, mon groupe seulement', () {
    expect(vus(cds1, 4, Perimetre.section),
        [cdu, cdg11, cdg12, cde111, cde112, eq111, eq112]);
    expect(vus(cdg11, 4, Perimetre.groupe),
        [cdu, cds1, cde111, cde112, eq111, eq112]);
    expect(vus(eq111, 2, Perimetre.section), [cdu, cds1, cdg11, cdg12]);
    // Le CDU n'a pas de section : il voit toute la compagnie.
    expect(vus(cdu, 1, Perimetre.section), [cds1, cds2]);
  });

  test('on reconnaît son trinôme et son groupe', () {
    expect(memeTrinome(eq111, cde111), isTrue);
    expect(memeTrinome(eq111, eq112), isFalse);
    expect(memeGroupe(eq111, eq112), isTrue);
    expect(memeGroupe(eq111, cdg11), isTrue);
    expect(memeGroupe(eq111, cdg12), isFalse);
  });

  test('noms : CARMIN, GOLF et trinômes A et B', () {
    expect(cds2.numeroCarre, '2');
    expect(cdg12.numeroCarre, '12');
    expect(eq112.numeroCarre, '11');
    expect(cdu.numeroCarre, '');
    expect(cds2.description, 'CARMIN 2 · chef de section');
    expect(cdg12.description, 'GOLF 12 · chef de groupe');
    expect(cde112.description, "GOLF 11B · chef d'équipe");
    expect(eq111.description, 'GOLF 11A');
    expect(const Place(Fonction.sk).description, 'SK');
  });

  test('sans fonction renseignée, on voit tout et on est vu de tous', () {
    expect(estVisible(Place.inconnue, cdu, 1), isTrue);
    expect(estVisible(eq111, Place.inconnue, 1), isTrue);
  });

  test('la place circule dans le message de position', () {
    final xml = CotEvenement.maPosition(
            uid: 'A', indicatif: 'A', lat: 1, lon: 2, place: cdg12)
        .versXml();
    final lu = CotEvenement.depuisXml(xml)!;
    expect(lu.place.fonction, Fonction.chefGroupe);
    expect(lu.place.section, 1);
    expect(lu.place.groupe, 2);
  });
}

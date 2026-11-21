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

List<Place> vus(Place moi, int profondeur) => [
      for (final p in tous)
        if (p != moi && estVisible(moi, p, profondeur)) p
    ];

void main() {
  test('le CDU choisit son niveau de détail', () {
    expect(vus(cdu, 1), [cds1, cds2]);
    expect(vus(cdu, 2), [cds1, cds2, cdg11, cdg12, cdg21]);
    expect(vus(cdu, 4).length, tous.length - 1);
  });

  test('le chef de section ne voit que sa section', () {
    expect(vus(cds1, 4), [cdg11, cdg12, cde111, cde112, eq111, eq112]);
    expect(vus(cds1, 2), [cdg11, cdg12]);
    expect(vus(cds2, 4), [cdg21]);
  });

  test('le chef de groupe voit ses équipes, le chef d\'équipe ses équipiers',
      () {
    expect(vus(cdg11, 3), [cde111, cde112]);
    expect(vus(cdg11, 4), [cde111, cde112, eq111, eq112]);
    expect(vus(cde111, 4), [eq111]);
  });

  test('l\'équipier voit son équipe', () {
    expect(vus(eq111, 4), [cde111]);
  });

  test('sans fonction renseignée, on voit tout et on est vu de tous', () {
    expect(estVisible(Place.inconnue, cdu, 1), isTrue);
    expect(estVisible(eq111, Place.inconnue, 1), isTrue);
  });

  test('la place circule dans le message de position', () {
    final xml = CotEvenement.maPosition(
            uid: 'A',
            indicatif: 'A',
            equipe: 'Cyan',
            lat: 1,
            lon: 2,
            place: cdg12)
        .versXml();
    final lu = CotEvenement.depuisXml(xml)!;
    expect(lu.place.fonction, Fonction.chefGroupe);
    expect(lu.place.section, 1);
    expect(lu.place.groupe, 2);
    expect(xml, contains('role="Team Lead"'));
  });
}

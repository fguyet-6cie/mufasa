import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mufasa/dessins.dart';
import 'package:mufasa/symboles.dart';

void main() {
  test('chaque variante proposée a son image', () {
    for (final s in catalogue) {
      for (final ami in [true, false]) {
        for (final e in s.aEchelon ? echelons.keys : ['-']) {
          for (final pc in s.aEchelon ? [false, true] : [false]) {
            final code = s.variante(ami: ami, echelon: e, pc: pc);
            expect(
                File('assets/symboles/${code.replaceAll('-', '_')}.svg')
                    .existsSync(),
                isTrue,
                reason: code);
            expect(ancres.containsKey(code), isTrue, reason: code);
            expect(symboleDuCode(code)?.nom, s.nom, reason: code);
            expect(estEnnemi(code), !ami);
          }
        }
      }
    }
  });

  test('type CoT déduit du code (pour les autres outils)', () {
    expect(typeCotDuSymbole('SFGPUCI----D---'), 'a-f-G-U-C-I');
    expect(typeCotDuSymbole('SHGPEVAT-------'), 'a-h-G-E-V-A-T');
    expect(typeCotDuSymbole('GFGPGPPK-------'), 'b-m-p-s-m');
  });

  test('un pion posé se relit, sans être pris pour un camarade', () {
    final d = Dessin(
      uid: 'P1',
      forme: FormeDessin.symbole,
      points: const [LatLng(48, 2)],
      nom: '1re SON',
      couleur: Colors.black,
      calque: 'Ennemi',
      auteur: 'MOI',
      auteurIndicatif: 'CDU',
      sidc: 'SHGPUCI----D---',
    );
    final lu = Dessin.depuisXml(d.versXml())!;
    expect(lu.forme, FormeDessin.symbole);
    expect(lu.sidc, 'SHGPUCI----D---');
    expect(lu.nom, '1re SON');
    final bouge = lu.deplace(const LatLng(48.1, 2.1), par: 'MOI');
    expect(bouge.points.first, const LatLng(48.1, 2.1));
    expect(bouge.uid, 'P1');
  });
}

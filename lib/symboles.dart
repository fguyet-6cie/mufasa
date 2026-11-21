// Symboles OTAN (MIL-STD-2525C / APP-6) retenus pour Mufasa.
// Les images sont fabriquées une fois pour toutes par outils/gen_symboles.js
// (bibliothèque libre milsymbol) et rangées dans assets/symboles/.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

part 'symboles_catalogue.dart';

enum FamilleSymbole { unite, materiel, point, obstacle }

const nomsFamilles = {
  FamilleSymbole.unite: 'Unités',
  FamilleSymbole.materiel: 'Matériels et menaces',
  FamilleSymbole.point: 'Points de manœuvre',
  FamilleSymbole.obstacle: 'Obstacles',
};

/// Échelons proposés (12e caractère du code SIDC).
const echelons = {
  '-': 'Aucun',
  'B': 'Groupe',
  'D': 'Section',
  'E': 'Compagnie'
};

class SymboleCatalogue {
  final String nom;

  /// Code SIDC de base (ou « PO » pour le poste d'observation dessiné ici).
  final String sidc;
  final FamilleSymbole famille;
  const SymboleCatalogue(this.nom, this.sidc, this.famille);

  bool get aEchelon => famille == FamilleSymbole.unite;

  /// Le code complet selon les choix de l'utilisateur.
  String variante({required bool ami, String echelon = '-', bool pc = false}) {
    if (sidc == 'PO') return ami ? 'PO_F' : 'PO_H';
    var s = _remplacer(sidc, 1, ami ? 'F' : 'H');
    if (aEchelon) {
      s = _remplacer(_remplacer(s, 10, pc ? 'A' : '-'), 11, echelon);
    }
    return s;
  }
}

String _remplacer(String s, int i, String c) =>
    s.substring(0, i) + c + s.substring(i + 1);

/// Nom lisible d'un code complet (ex. « Infanterie ennemie, section »).
SymboleCatalogue? symboleDuCode(String sidc) {
  if (sidc.startsWith('PO')) {
    return catalogue.where((s) => s.sidc == 'PO').firstOrNull;
  }
  for (final s in catalogue) {
    if (s.sidc == 'PO') continue;
    final base = s.aEchelon
        ? _remplacer(_remplacer(_remplacer(sidc, 1, 'F'), 10, '-'), 11, '-')
        : _remplacer(sidc, 1, 'F');
    if (_remplacer(s.sidc, 1, 'F') == base) return s;
  }
  return null;
}

bool estEnnemi(String sidc) =>
    sidc.startsWith('PO') ? sidc.endsWith('H') : sidc[1] == 'H';

/// Type CoT correspondant (ex. SFGPUCI → a-f-G-U-C-I), pour que les autres
/// outils compatibles reconnaissent l'unité.
String typeCotDuSymbole(String sidc) {
  if (!sidc.startsWith('S')) return 'b-m-p-s-m';
  final fonction = sidc.substring(4, 10).replaceAll('-', '').split('');
  return ['a', sidc[1].toLowerCase(), sidc[2], ...fonction].join('-');
}

/// Image d'un symbole, avec son point d'ancrage (le centre du cadre).
class ImageSymbole extends StatelessWidget {
  final String sidc;
  final double hauteur;
  const ImageSymbole(this.sidc, {super.key, this.hauteur = 36});

  static (double, double, double, double) mesures(String sidc) =>
      ancres[sidc] ?? (40.0, 40.0, 20.0, 20.0);

  @override
  Widget build(BuildContext context) {
    final (l, h, _, _) = mesures(sidc);
    return SvgPicture.asset(
      'assets/symboles/${sidc.replaceAll('-', '_')}.svg',
      width: hauteur * l / h,
      height: hauteur,
    );
  }
}

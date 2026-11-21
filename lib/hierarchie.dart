// Place de chacun dans la compagnie, et qui voit qui.
// CDU → chefs de section → chefs de groupe → chefs d'équipe → équipiers.
// Chaque chef voit ses subordonnés (dans sa branche), jusqu'au niveau qu'il
// choisit. L'équipier voit son équipe.

enum Fonction {
  nonRenseignee,
  cdu,
  chefSection,
  chefGroupe,
  chefEquipe,
  equipier
}

const nomsFonctions = {
  Fonction.nonRenseignee: 'Non renseignée',
  Fonction.cdu: 'Commandant d\'unité',
  Fonction.chefSection: 'Chef de section',
  Fonction.chefGroupe: 'Chef de groupe',
  Fonction.chefEquipe: 'Chef d\'équipe',
  Fonction.equipier: 'Équipier',
};

/// Noms des niveaux d'affichage, du moins détaillé au plus détaillé.
const nomsNiveaux = {
  1: 'Chefs de section',
  2: 'Chefs de groupe',
  3: 'Chefs d\'équipe',
  4: 'Équipiers',
};

extension NiveauFonction on Fonction {
  /// 0 pour le CDU … 4 pour l'équipier ; -1 si non renseignée.
  int get niveau => switch (this) {
        Fonction.nonRenseignee => -1,
        Fonction.cdu => 0,
        Fonction.chefSection => 1,
        Fonction.chefGroupe => 2,
        Fonction.chefEquipe => 3,
        Fonction.equipier => 4,
      };

  String get abreviation => switch (this) {
        Fonction.cdu => 'CDU',
        Fonction.chefSection => 'CDS',
        Fonction.chefGroupe => 'CDG',
        Fonction.chefEquipe => 'CDE',
        _ => '',
      };

  /// Rôle compris par les autres outils compatibles (TAK).
  String get roleTak => switch (this) {
        Fonction.cdu => 'HQ',
        Fonction.chefSection ||
        Fonction.chefGroupe ||
        Fonction.chefEquipe =>
          'Team Lead',
        _ => 'Team Member',
      };

  bool get aSection => niveau >= 1;
  bool get aGroupe => niveau >= 2;
  bool get aEquipe => niveau >= 3;
}

class Place {
  final Fonction fonction;

  /// Numéros de section, groupe, équipe (0 = sans objet).
  final int section, groupe, equipe;

  const Place(this.fonction,
      {this.section = 0, this.groupe = 0, this.equipe = 0});

  static const inconnue = Place(Fonction.nonRenseignee);

  /// Texte court, ex. « 2e SON / 1er GPE ».
  String get description {
    String n(int i) => i == 1 ? '1er' : '${i}e';
    String nf(int i) => i == 1 ? '1re' : '${i}e';
    return [
      if (fonction.aSection && section > 0) '${nf(section)} SON',
      if (fonction.aGroupe && groupe > 0) '${n(groupe)} GPE',
      if (fonction.aEquipe && equipe > 0) '${nf(equipe)} EQ',
    ].join(' / ');
  }

  String versAttributs() =>
      'fonction="${fonction.name}" section="$section" groupe="$groupe" equipe="$equipe"';

  static Place depuisAttributs(String? Function(String) attribut) {
    final f = Fonction.values
        .where((f) => f.name == attribut('fonction'))
        .firstOrNull;
    if (f == null) return inconnue;
    int n(String c) => int.tryParse(attribut(c) ?? '') ?? 0;
    return Place(f,
        section: n('section'), groupe: n('groupe'), equipe: n('equipe'));
  }
}

/// Est-ce que « moi » doit voir « autre » sur la carte ?
/// [profondeur] : niveau le plus détaillé que je veux voir (1 à 4).
bool estVisible(Place moi, Place autre, int profondeur) {
  // Sans fonction renseignée (ou autre outil), on montre tout.
  if (moi.fonction == Fonction.nonRenseignee ||
      autre.fonction == Fonction.nonRenseignee) {
    return true;
  }
  // L'équipier voit les membres de son équipe.
  if (moi.fonction == Fonction.equipier) {
    return autre.fonction.niveau >= 3 &&
        autre.section == moi.section &&
        autre.groupe == moi.groupe &&
        autre.equipe == moi.equipe;
  }
  final n = autre.fonction.niveau;
  if (n <= moi.fonction.niveau || n > profondeur) return false;
  if (moi.fonction.aSection && autre.section != moi.section) return false;
  if (moi.fonction.aGroupe && autre.groupe != moi.groupe) return false;
  if (moi.fonction.aEquipe && autre.equipe != moi.equipe) return false;
  return true;
}

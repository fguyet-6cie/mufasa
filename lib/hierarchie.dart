// Place de chacun dans la compagnie (6e Cie) et ce que chacun affiche.
// CDU → chefs de section (CARMIN 1 à 4) → chefs de groupe (GOLF 11 à 43)
// → trinômes A et B. La SK est la section de commandement.
// Tout le monde peut tout voir ; chacun choisit ce qu'il affiche.

enum Fonction {
  nonRenseignee,
  cdu,
  chefSection,
  chefGroupe,
  chefEquipe,
  equipier,
  sk
}

const nomsFonctions = {
  Fonction.nonRenseignee: 'Non renseignée',
  Fonction.cdu: 'Commandant d\'unité',
  Fonction.chefSection: 'Chef de section',
  Fonction.chefGroupe: 'Chef de groupe',
  Fonction.chefEquipe: "Chef d'équipe",
  Fonction.equipier: 'Équipier',
  Fonction.sk: 'SK (section de commandement)',
};

/// « Jusqu'à » : niveau le plus détaillé affiché.
const nomsNiveaux = {
  1: 'Chefs de section',
  2: 'Chefs de groupe',
  4: 'Tout le monde',
};

/// « Ce que je vois » : quelle partie de la compagnie.
enum Perimetre { compagnie, section, groupe }

const nomsPerimetres = {
  Perimetre.compagnie: 'Toute la compagnie',
  Perimetre.section: 'Ma section seulement',
  Perimetre.groupe: 'Mon groupe seulement',
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
        Fonction.sk => 4,
      };

  String get abreviation => switch (this) {
        Fonction.cdu => 'CDU',
        Fonction.chefSection => 'CDS',
        Fonction.chefGroupe => 'CDG',
        _ => '',
      };

  bool get aSection => niveau >= 1 && this != Fonction.sk;
  bool get aGroupe => niveau >= 2 && this != Fonction.sk;
  bool get aEquipe => niveau >= 3 && this != Fonction.sk;
}

class Place {
  final Fonction fonction;

  /// Numéros de section, groupe, équipe (0 = sans objet).
  final int section, groupe, equipe;

  const Place(this.fonction,
      {this.section = 0, this.groupe = 0, this.equipe = 0});

  static const inconnue = Place(Fonction.nonRenseignee);

  /// Nom du groupe, ex. « GOLF 21 » (section 2, groupe 1).
  String get golf => 'GOLF $section$groupe';

  /// Lettre du trinôme : A ou B.
  String get lettre => equipe == 2 ? 'B' : 'A';

  /// Ce qui est écrit dans le petit carré : n° de section pour un chef de
  /// section, n° de GOLF pour un groupe, rien pour la SK et le CDU.
  String get numeroCarre => switch (fonction) {
        Fonction.chefSection => '$section',
        Fonction.chefGroupe ||
        Fonction.chefEquipe ||
        Fonction.equipier =>
          '$section$groupe',
        _ => '',
      };

  /// Texte de la bulle, ex. « GOLF 21B · chef d'équipe ».
  String get description => switch (fonction) {
        Fonction.nonRenseignee => '',
        Fonction.cdu => 'Commandant d\'unité',
        Fonction.sk => 'SK',
        Fonction.chefSection => 'CARMIN $section · chef de section',
        Fonction.chefGroupe => '$golf · chef de groupe',
        Fonction.chefEquipe => "$golf$lettre · chef d'équipe",
        Fonction.equipier => '$golf$lettre',
      };

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

/// Est-ce que « moi » affiche « autre » sur la carte ?
/// [perimetre] : quelle partie de la compagnie ; [profondeur] : jusqu'à quel
/// niveau (1 = chefs de section, 2 = chefs de groupe, 4 = tout le monde).
/// Le CDU reste toujours affiché.
bool estVisible(Place moi, Place autre, int profondeur,
    [Perimetre perimetre = Perimetre.compagnie]) {
  if (autre.fonction == Fonction.nonRenseignee) return true;
  if (autre.fonction == Fonction.cdu) return true;
  if (autre.fonction.niveau > profondeur) return false;
  if (moi.fonction == Fonction.nonRenseignee) return true;
  switch (perimetre) {
    case Perimetre.compagnie:
      return true;
    case Perimetre.section:
      if (!moi.fonction.aSection) return true;
      return autre.fonction.aSection && autre.section == moi.section;
    case Perimetre.groupe:
      if (!moi.fonction.aGroupe) {
        return estVisible(moi, autre, profondeur, Perimetre.section);
      }
      if (!autre.fonction.aSection || autre.section != moi.section) {
        return false;
      }
      // Mon chef de section reste visible.
      return autre.fonction == Fonction.chefSection ||
          autre.groupe == moi.groupe;
  }
}

/// Les deux font-ils partie du même groupe (GOLF) ?
bool memeGroupe(Place moi, Place autre) =>
    moi.fonction.aGroupe &&
    autre.fonction.aGroupe &&
    moi.section == autre.section &&
    moi.groupe == autre.groupe;

/// Les deux font-ils partie du même trinôme (même équipe) ?
bool memeTrinome(Place moi, Place autre) =>
    moi.fonction.aEquipe &&
    autre.fonction.aEquipe &&
    moi.section == autre.section &&
    moi.groupe == autre.groupe &&
    moi.equipe == autre.equipe;

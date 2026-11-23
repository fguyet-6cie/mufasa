// Version navigateur (aperçu) : exercices gardés en mémoire seulement.
final _memoire = <String, List<String>>{};

Future<void> ajouterLignes(String nom, List<String> lignes) async =>
    (_memoire[nom] ??= []).addAll(lignes);

Future<List<String>> lireExercice(String nom) async => _memoire[nom] ?? [];

Future<List<(String, int)>> listerExercices() async => [
      for (final e in _memoire.entries)
        (e.key, e.value.fold<int>(0, (s, l) => s + l.length + 1))
    ]..sort((a, b) => b.$1.compareTo(a.$1));

Future<void> effacerExercice(String nom) async => _memoire.remove(nom);

Future<void> effacerExercices() async => _memoire.clear();

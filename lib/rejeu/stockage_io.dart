import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<Directory?> _dossier() async {
  try {
    final d = await getApplicationSupportDirectory();
    return Directory('${d.path}/exercices');
  } catch (_) {
    return null;
  }
}

Future<void> ajouterLignes(String nom, List<String> lignes) async {
  final d = await _dossier();
  if (d == null || lignes.isEmpty) return;
  await d.create(recursive: true);
  await File('${d.path}/$nom').writeAsString('${lignes.join('\n')}\n',
      mode: FileMode.append, flush: true);
}

Future<List<String>> lireExercice(String nom) async {
  final d = await _dossier();
  if (d == null) return const [];
  final f = File('${d.path}/$nom');
  if (!await f.exists()) return const [];
  return f.readAsLines();
}

/// (nom du fichier, taille en octets), du plus récent au plus ancien.
Future<List<(String, int)>> listerExercices() async {
  final d = await _dossier();
  if (d == null || !await d.exists()) return const [];
  final r = <(String, int)>[];
  await for (final e in d.list()) {
    if (e is File) r.add((e.uri.pathSegments.last, await e.length()));
  }
  r.sort((a, b) => b.$1.compareTo(a.$1));
  return r;
}

Future<void> effacerExercice(String nom) async {
  final d = await _dossier();
  if (d == null) return;
  final f = File('${d.path}/$nom');
  if (await f.exists()) await f.delete();
}

Future<void> effacerExercices() async {
  final d = await _dossier();
  if (d != null && await d.exists()) await d.delete(recursive: true);
}

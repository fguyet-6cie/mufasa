// Mise à jour : au démarrage, l'appli regarde sur GitHub si une version
// plus récente existe et propose de la télécharger.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dépôt GitHub où sont publiées les versions (il doit être public pour
/// que tout le monde puisse télécharger).
const depotTelechargement = 'fguyet-6cie/mufasa';

const lienTelechargement =
    'https://github.com/$depotTelechargement/releases/latest/download/mufasa.apk';

/// Numéro de version tiré du nom d'une version GitHub (« v0.2.7 » → 7).
int? numeroDepuisTag(String tag) {
  final m = RegExp(r'(\d+)\s*$').firstMatch(tag);
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// Vrai si la version publiée est plus récente que celle installée.
bool estPlusRecente(String tagPublie, String numeroInstalle) {
  final publie = numeroDepuisTag(tagPublie);
  final installe = int.tryParse(numeroInstalle);
  if (publie == null || installe == null) return false;
  return publie > installe;
}

/// Renvoie le nom de la nouvelle version (ex. « v0.2.7 »), ou null.
Future<String?> chercherNouvelleVersion() async {
  // Le fichier APK ne sert que sur Android.
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    final info = await PackageInfo.fromPlatform();
    final rep = await http
        .get(Uri.parse(
            'https://api.github.com/repos/$depotTelechargement/releases/latest'))
        .timeout(const Duration(seconds: 10));
    if (rep.statusCode != 200) return null; // pas de réseau, dépôt privé…
    final tag = (jsonDecode(rep.body) as Map)['tag_name'] as String? ?? '';
    return estPlusRecente(tag, info.buildNumber) ? tag : null;
  } catch (_) {
    return null; // hors réseau : on réessaiera au prochain démarrage
  }
}

/// Affiche la fenêtre « Nouvelle version disponible » si besoin.
Future<void> proposerMiseAJour(BuildContext context) async {
  final tag = await chercherNouvelleVersion();
  if (tag == null || !context.mounted) return;
  await afficherMiseAJour(context, tag);
}

Future<void> afficherMiseAJour(BuildContext context, String tag) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.system_update, size: 40),
      title: const Text('Nouvelle version disponible'),
      content: Text('La version $tag de Mufasa est prête.\n\n'
          'Touche « Télécharger », puis ouvre le fichier mufasa.apk '
          'pour l\'installer. Tes réglages et tes dessins sont conservés.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Plus tard')),
        FilledButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('Télécharger'),
          onPressed: () {
            Navigator.pop(ctx);
            launchUrl(Uri.parse(lienTelechargement),
                mode: LaunchMode.externalApplication);
          },
        ),
      ],
    ),
  );
}

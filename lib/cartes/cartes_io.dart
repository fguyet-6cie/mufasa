// Version téléphone : les tuiles sont rangées dans un dossier de l'appli,
// tuiles/<couche>/<z>/<x>/<y>.<png|jpg>.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

const cartesHorsLigneDisponibles = true;

String? _racine;
final _client = http.Client();
const _agent = 'MUFASA (fr.cie6.mufasa)';

Future<void> preparerCartes() async {
  try {
    final d = await getApplicationSupportDirectory();
    _racine = '${d.path}/tuiles';
  } catch (_) {
    _racine = null;
  }
}

String? _chemin(String couche, String ext, int z, int x, int y) =>
    _racine == null ? null : '$_racine/$couche/$z/$x/$y.$ext';

/// Lit la tuile dans le téléphone ; sinon la télécharge et la garde.
Future<Uint8List?> _tuile(String? fichier, String url) async {
  if (fichier != null) {
    final f = File(fichier);
    if (await f.exists()) return f.readAsBytes();
  }
  final rep = await _client.get(Uri.parse(url),
      headers: {'User-Agent': _agent}).timeout(const Duration(seconds: 20));
  if (rep.statusCode != 200 || rep.bodyBytes.isEmpty) return null;
  if (fichier != null) {
    try {
      final f = File(fichier);
      await f.parent.create(recursive: true);
      await f.writeAsBytes(rep.bodyBytes, flush: false);
    } catch (_) {}
  }
  return rep.bodyBytes;
}

class _FournisseurHorsLigne extends TileProvider {
  final String couche;
  final String extension;
  _FournisseurHorsLigne(this.couche, this.extension);

  @override
  ImageProvider getImage(TileCoordinates c, TileLayer options) => _TuileImage(
        getTileUrl(c, options),
        _chemin(couche, extension, c.z, c.x, c.y),
      );
}

TileProvider fournisseurTuiles(String couche, String extension) =>
    _FournisseurHorsLigne(couche, extension);

class _TuileImage extends ImageProvider<_TuileImage> {
  final String url;
  final String? fichier;
  const _TuileImage(this.url, this.fichier);

  @override
  Future<_TuileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
          _TuileImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(_charger(decode));

  Future<ImageInfo> _charger(ImageDecoderCallback decode) async {
    final octets = await _tuile(fichier, url);
    if (octets == null) throw StateError('tuile indisponible');
    final codec = await decode(await ui.ImmutableBuffer.fromUint8List(octets));
    final image = (await codec.getNextFrame()).image;
    return ImageInfo(image: image);
  }

  @override
  bool operator ==(Object other) =>
      other is _TuileImage && other.url == url && other.fichier == fichier;

  @override
  int get hashCode => Object.hash(url, fichier);
}

/// Place occupée par les cartes gardées, en octets.
Future<int> tailleCartes() async {
  final r = _racine;
  if (r == null) return 0;
  final d = Directory(r);
  if (!await d.exists()) return 0;
  var total = 0;
  await for (final e in d.list(recursive: true, followLinks: false)) {
    if (e is File) total += await e.length();
  }
  return total;
}

Future<void> effacerCartes() async {
  final r = _racine;
  if (r == null) return;
  final d = Directory(r);
  if (await d.exists()) await d.delete(recursive: true);
}

/// Télécharge une liste de tuiles (6 à la fois). Renvoie le nombre d'échecs.
Future<int> telechargerTuiles({
  required String couche,
  required String extension,
  required String Function(int z, int x, int y) url,
  required List<(int, int, int)> tuiles,
  required void Function(int faites) progression,
  required bool Function() annule,
}) async {
  var suivante = 0, faites = 0, echecs = 0;
  Future<void> ouvrier() async {
    while (!annule()) {
      final i = suivante++;
      if (i >= tuiles.length) return;
      final (z, x, y) = tuiles[i];
      try {
        final ok =
            await _tuile(_chemin(couche, extension, z, x, y), url(z, x, y));
        if (ok == null) echecs++;
      } catch (_) {
        echecs++;
      }
      progression(++faites);
    }
  }

  await Future.wait([for (var i = 0; i < 6; i++) ouvrier()]);
  return echecs;
}

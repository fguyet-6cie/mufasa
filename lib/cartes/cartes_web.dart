// Version navigateur (aperçu) : pas de cartes hors ligne.
import 'package:flutter_map/flutter_map.dart';

const cartesHorsLigneDisponibles = false;

Future<void> preparerCartes() async {}

TileProvider fournisseurTuiles(String couche, String extension) =>
    NetworkTileProvider();

Future<int> tailleCartes() async => 0;

Future<void> effacerCartes() async {}

Future<int> telechargerTuiles({
  required String couche,
  required String extension,
  required String Function(int z, int x, int y) url,
  required List<(int, int, int)> tuiles,
  required void Function(int faites) progression,
  required bool Function() annule,
}) async =>
    tuiles.length;

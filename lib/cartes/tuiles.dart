// Calcul des tuiles (petites images carrées) qui couvrent une zone de carte.
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Numéro (x, y) de la tuile qui contient [p] au niveau de zoom [z].
(int, int) tuilePour(LatLng p, int z) {
  final n = 1 << z;
  final lat = p.latitude.clamp(-85.05, 85.05) * math.pi / 180;
  final x = ((p.longitude + 180) / 360 * n).floor().clamp(0, n - 1);
  final y =
      ((1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2 * n)
          .floor()
          .clamp(0, n - 1);
  return (x, y);
}

/// Toutes les tuiles (z, x, y) d'une zone, du zoom [zMin] au zoom [zMax].
List<(int, int, int)> tuilesZone(
    LatLng nordOuest, LatLng sudEst, int zMin, int zMax) {
  final r = <(int, int, int)>[];
  for (var z = zMin; z <= zMax; z++) {
    final (x0, y0) = tuilePour(nordOuest, z);
    final (x1, y1) = tuilePour(sudEst, z);
    for (var x = math.min(x0, x1); x <= math.max(x0, x1); x++) {
      for (var y = math.min(y0, y1); y <= math.max(y0, y1); y++) {
        r.add((z, x, y));
      }
    }
  }
  return r;
}

/// Nombre de tuiles d'une zone, sans les lister.
int compterTuiles(LatLng nordOuest, LatLng sudEst, int zMin, int zMax) {
  var total = 0;
  for (var z = zMin; z <= zMax; z++) {
    final (x0, y0) = tuilePour(nordOuest, z);
    final (x1, y1) = tuilePour(sudEst, z);
    total += ((x1 - x0).abs() + 1) * ((y1 - y0).abs() + 1);
  }
  return total;
}

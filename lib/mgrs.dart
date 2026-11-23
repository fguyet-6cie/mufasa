// Coordonnées MGRS (carroyage militaire OTAN) à partir de la latitude et de
// la longitude GPS (WGS84). Exemple : « 31U DQ 48251 11943 » (précision 1 m).
import 'dart:math' as math;

const _bandes = 'CDEFGHJKLMNPQRSTUVWXX';
const _colonnes = ['ABCDEFGH', 'JKLMNPQR', 'STUVWXYZ'];
const _lignes = 'ABCDEFGHJKLMNPQRSTUV';

/// Fuseau UTM, avec les exceptions de la Norvège et du Svalbard.
int _fuseau(double lat, double lon) {
  var z = ((lon + 180) / 6).floor() + 1;
  if (lon >= 180) z = 60;
  if (lat >= 56 && lat < 64 && lon >= 3 && lon < 12) z = 32;
  if (lat >= 72 && lat < 84) {
    if (lon >= 0 && lon < 9) {
      z = 31;
    } else if (lon >= 9 && lon < 21) {
      z = 33;
    } else if (lon >= 21 && lon < 33) {
      z = 35;
    } else if (lon >= 33 && lon < 42) {
      z = 37;
    }
  }
  return z;
}

/// Renvoie (fuseau, est, nord) en mètres, projection UTM WGS84.
(int, double, double) versUtm(double lat, double lon) {
  const a = 6378137.0, f = 1 / 298.257223563, k0 = 0.9996;
  final e2 = f * (2 - f);
  final ep2 = e2 / (1 - e2);
  final z = _fuseau(lat, lon);
  final lon0 = ((z - 1) * 6 - 180 + 3) * math.pi / 180;
  final phi = lat * math.pi / 180, lam = lon * math.pi / 180;
  final n = a / math.sqrt(1 - e2 * math.pow(math.sin(phi), 2));
  final t = math.pow(math.tan(phi), 2).toDouble();
  final c = ep2 * math.pow(math.cos(phi), 2);
  final aa = math.cos(phi) * (lam - lon0);
  final e4 = e2 * e2, e6 = e4 * e2;
  final m = a *
      ((1 - e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * phi -
          (3 * e2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * math.sin(2 * phi) +
          (15 * e4 / 256 + 45 * e6 / 1024) * math.sin(4 * phi) -
          (35 * e6 / 3072) * math.sin(6 * phi));
  final est = k0 *
          n *
          (aa +
              (1 - t + c) * math.pow(aa, 3) / 6 +
              (5 - 18 * t + t * t + 72 * c - 58 * ep2) *
                  math.pow(aa, 5) /
                  120) +
      500000;
  var nord = k0 *
      (m +
          n *
              math.tan(phi) *
              (aa * aa / 2 +
                  (5 - t + 9 * c + 4 * c * c) * math.pow(aa, 4) / 24 +
                  (61 - 58 * t + t * t + 600 * c - 330 * ep2) *
                      math.pow(aa, 6) /
                      720));
  if (lat < 0) nord += 10000000;
  return (z, est, nord);
}

/// Coordonnées MGRS lisibles, ex. « 31U DQ 48251 11943 ».
/// Renvoie un texte vide hors de la zone couverte (au-delà de 84° N / 80° S).
String versMgrs(double lat, double lon) {
  if (lat < -80 || lat > 84) return '';
  final (z, est, nord) = versUtm(lat, lon);
  final bande = _bandes[((lat + 80) / 8).floor().clamp(0, 20)];
  final col = _colonnes[(z - 1) % 3][(est / 100000).floor() - 1];
  final ligne = _lignes[((nord / 100000).floor() + (z.isEven ? 5 : 0)) % 20];
  String cinq(double v) => (v.floor() % 100000).toString().padLeft(5, '0');
  return '$z$bande $col$ligne ${cinq(est)} ${cinq(nord)}';
}

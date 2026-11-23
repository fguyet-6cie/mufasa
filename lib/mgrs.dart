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

/// Inverse de [versUtm] : (latitude, longitude) en degrés.
(double, double) depuisUtm(int z, double est, double nord, {bool sud = false}) {
  const a = 6378137.0, f = 1 / 298.257223563, k0 = 0.9996;
  final e2 = f * (2 - f);
  final ep2 = e2 / (1 - e2);
  final e1 = (1 - math.sqrt(1 - e2)) / (1 + math.sqrt(1 - e2));
  final x = est - 500000;
  final y = sud ? nord - 10000000 : nord;
  final m = y / k0;
  final mu = m / (a * (1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * e2 * e2 * e2 / 256));
  final phi1 = mu +
      (3 * e1 / 2 - 27 * math.pow(e1, 3) / 32) * math.sin(2 * mu) +
      (21 * e1 * e1 / 16 - 55 * math.pow(e1, 4) / 32) * math.sin(4 * mu) +
      (151 * math.pow(e1, 3) / 96) * math.sin(6 * mu) +
      (1097 * math.pow(e1, 4) / 512) * math.sin(8 * mu);
  final s = math.sin(phi1), c = math.cos(phi1);
  final n1 = a / math.sqrt(1 - e2 * s * s);
  final t1 = math.pow(math.tan(phi1), 2).toDouble();
  final c1 = ep2 * c * c;
  final r1 = a * (1 - e2) / math.pow(1 - e2 * s * s, 1.5);
  final d = x / (n1 * k0);
  final lat = phi1 -
      (n1 * math.tan(phi1) / r1) *
          (d * d / 2 -
              (5 + 3 * t1 + 10 * c1 - 4 * c1 * c1 - 9 * ep2) *
                  math.pow(d, 4) /
                  24 +
              (61 +
                      90 * t1 +
                      298 * c1 +
                      45 * t1 * t1 -
                      252 * ep2 -
                      3 * c1 * c1) *
                  math.pow(d, 6) /
                  720);
  final lon0 = ((z - 1) * 6 - 180 + 3) * math.pi / 180;
  final lon = lon0 +
      (d -
              (1 + 2 * t1 + c1) * math.pow(d, 3) / 6 +
              (5 - 2 * c1 + 28 * t1 - 3 * c1 * c1 + 8 * ep2 + 24 * t1 * t1) *
                  math.pow(d, 5) /
                  120) /
          c;
  return (lat * 180 / math.pi, lon * 180 / math.pi);
}

/// Lit des coordonnées MGRS tapées à la main (espaces facultatifs, de 1 à
/// 5 chiffres pour l'est et le nord), ex. « 31U DQ 48251 11943 » ou
/// « 31udq4811 ». Renvoie null si le texte n'est pas valable.
(double, double)? depuisMgrs(String texte) {
  final t = texte.toUpperCase().replaceAll(RegExp(r'\s'), '');
  final m = RegExp(r'^(\d{1,2})([C-HJ-NP-X])([A-HJ-NP-Z])([A-HJ-NP-V])(\d*)$')
      .firstMatch(t);
  if (m == null) return null;
  final z = int.parse(m.group(1)!);
  if (z < 1 || z > 60) return null;
  final bande = m.group(2)!;
  final chiffres = m.group(5)!;
  if (chiffres.length.isOdd || chiffres.length > 10) return null;
  final moitie = chiffres.length ~/ 2;
  final echelle = math.pow(10, 5 - moitie).toDouble();
  // Sans précision donnée, on vise le milieu du carré.
  final e = moitie == 0
      ? 50000.0
      : int.parse(chiffres.substring(0, moitie)) * echelle + echelle / 2;
  final n = moitie == 0
      ? 50000.0
      : int.parse(chiffres.substring(moitie)) * echelle + echelle / 2;
  final col = _colonnes[(z - 1) % 3].indexOf(m.group(3)!);
  if (col < 0) return null;
  final est = (col + 1) * 100000 + e;
  final ligne = (_lignes.indexOf(m.group(4)!) - (z.isEven ? 5 : 0)) % 20;
  var nord = ligne * 100000 + n;
  // On remonte par tranches de 2 000 km jusqu'à la bande de latitude.
  final latMin = -80 + 8 * _bandes.indexOf(bande);
  final sud = latMin < 0;
  final lonCentre = (z - 1) * 6 - 180 + 3.0;
  final nordMin = versUtm(latMin.toDouble(), lonCentre).$3 - 100000;
  while (nord < nordMin) {
    nord += 2000000;
  }
  final (lat, lon) = depuisUtm(z, est, nord, sud: sud);
  if (lat < latMin - 1 || lat > latMin + 13) return null;
  return (lat, lon);
}

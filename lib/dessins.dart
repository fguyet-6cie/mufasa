// Dessins partagés sur la carte (points, lignes, zones), rangés en calques.
// Ils circulent au format CoT, comme les positions, pour rester compatibles
// avec les autres outils de situation tactique.
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

enum FormeDessin { point, ligne, zone, mission }

/// Comment un graphique de mission est tracé.
enum TraceMission {
  /// Flèche du pion vers l'objectif (2 points ou plus).
  fleche,

  /// Secteur : du pion vers deux limites (3 points : pion, limite 1, limite 2).
  /// Deux traits à pointe ouverte, avec la lettre sur chaque trait.
  secteur,

  /// Arc presque fermé autour de l'objectif (centre puis bord).
  boucle,

  /// Grande croix sur l'objectif (centre puis taille).
  croix,
}

enum StyleTrait { plein, tirets, pointilles, zigzag }

class Mission {
  final String code;
  final String nom;
  final String lettre;
  final TraceMission trace;
  final StyleTrait style;
  final bool pointePleine;
  const Mission(this.code, this.nom, this.lettre, this.trace,
      {this.style = StyleTrait.plein, this.pointePleine = false});

  int get pointsMini => trace == TraceMission.secteur ? 3 : 2;
  int? get pointsMaxi => switch (trace) {
        TraceMission.secteur => 3,
        TraceMission.boucle || TraceMission.croix => 2,
        TraceMission.fleche => null,
      };

  /// Consigne affichée pendant le tracé.
  String get consigne => switch (trace) {
        TraceMission.fleche =>
          'Touchez le départ (le pion), puis le chemin jusqu\'à l\'objectif.',
        TraceMission.secteur =>
          'Touchez le pion, puis la première limite, puis la seconde.',
        TraceMission.boucle =>
          'Touchez le centre de l\'objectif, puis le bord du bouclage.',
        TraceMission.croix =>
          'Touchez le centre de l\'objectif, puis la taille de la croix.',
      };
}

/// Graphiques de mission, alignés sur la liste de symboles validée avec Fred
/// (inspirés de l'APP-6 ; « Reconnaître » et « Éclairer » n'y ont pas
/// d'équivalent exact).
const missions = <Mission>[
  Mission('attaquer', 'Attaquer', '', TraceMission.fleche, pointePleine: true),
  Mission('fixer', 'Fixer', 'F', TraceMission.fleche,
      style: StyleTrait.zigzag, pointePleine: true),
  Mission('detruire', 'Détruire', 'D', TraceMission.croix),
  Mission('neutraliser', 'Neutraliser', 'N', TraceMission.croix),
  Mission('boucler', 'Boucler', 'I', TraceMission.boucle),
  Mission('couvrir', 'Couvrir', 'C', TraceMission.secteur),
  Mission('surveiller', 'Surveiller', 'S', TraceMission.secteur),
  Mission('flanc-garder', 'Flanc-garder', 'G', TraceMission.secteur),
  Mission('reconnaitre', 'Reconnaître', 'RECO', TraceMission.fleche,
      style: StyleTrait.tirets),
  Mission('eclairer', 'Éclairer', 'ECL', TraceMission.fleche,
      style: StyleTrait.pointilles),
];

Mission? missionParCode(String? code) =>
    missions.where((m) => m.code == code).firstOrNull;

/// Couleurs proposées pour dessiner.
const couleursDessin = <String, Color>{
  'Rouge': Colors.red,
  'Bleu': Colors.blue,
  'Vert': Colors.green,
  'Jaune': Colors.amber,
  'Orange': Colors.orange,
  'Violet': Colors.purple,
  'Noir': Colors.black,
};

const calqueParDefaut = 'Général';

/// Type CoT d'un ordre de suppression.
const typeSuppression = 't-x-d-d';

class Dessin {
  final String uid;
  final FormeDessin forme;
  final List<LatLng> points;
  final String nom;
  final Color couleur;
  final String calque;
  final String auteur; // uid du téléphone qui l'a dessiné
  final String auteurIndicatif;
  final DateTime heure;

  /// Pour un graphique de mission : code de la mission et pion concerné.
  final String? mission;
  final String pion;

  Mission? get laMission => missionParCode(mission);

  Dessin({
    this.mission,
    this.pion = '',
    required this.uid,
    required this.forme,
    required this.points,
    required this.nom,
    required this.couleur,
    required this.calque,
    required this.auteur,
    required this.auteurIndicatif,
    DateTime? heure,
  }) : heure = (heure ?? DateTime.now()).toUtc();

  LatLng get centre {
    if (forme == FormeDessin.point) return points.first;
    var lat = 0.0, lon = 0.0;
    for (final p in points) {
      lat += p.latitude;
      lon += p.longitude;
    }
    return LatLng(lat / points.length, lon / points.length);
  }

  /// Types CoT : point de carte « b-m-p-s-m », tracé « u-d-f »
  /// (une zone est un tracé fermé : son premier point est répété à la fin).
  String get typeCot => forme == FormeDessin.point ? 'b-m-p-s-m' : 'u-d-f';

  static String _e(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  String versXml() {
    final t = heure.toIso8601String();
    // Les dessins restent valables longtemps ; on les renvoie régulièrement.
    final perime = heure.add(const Duration(days: 30)).toIso8601String();
    final c = centre;
    final argb = couleur.toARGB32().toSigned(32);
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write(
          '<event version="2.0" uid="${_e(uid)}" type="$typeCot" how="h-e" ')
      ..write('time="$t" start="$t" stale="$perime">')
      ..write(
          '<point lat="${c.latitude}" lon="${c.longitude}" hae="9999999.0" ')
      ..write('ce="9999999.0" le="9999999.0"/><detail>')
      ..write('<contact callsign="${_e(nom)}"/>');
    if (forme == FormeDessin.point) {
      b.write('<color argb="$argb"/>');
    } else {
      final liste = [...points, if (forme == FormeDessin.zone) points.first];
      for (final p in liste) {
        b.write('<link point="${p.latitude},${p.longitude}"/>');
      }
      b
        ..write('<strokeColor value="$argb"/>')
        ..write('<strokeWeight value="3.0"/>');
      if (forme == FormeDessin.zone) {
        final remplissage =
            couleur.withValues(alpha: 0.25).toARGB32().toSigned(32);
        b.write('<fillColor value="$remplissage"/>');
      }
    }
    b
      ..write('<link uid="${_e(auteur)}" relation="p-p" type="a-f-G-U-C" ')
      ..write('parent_callsign="${_e(auteurIndicatif)}"/>')
      ..write('<__mufasa calque="${_e(calque)}" forme="${forme.name}"')
      ..write(mission == null
          ? ''
          : ' mission="${_e(mission!)}" pion="${_e(pion)}"')
      ..write('/>')
      ..write('</detail></event>');
    return b.toString();
  }

  /// Lit un dessin CoT. Renvoie null si ce n'est pas un dessin.
  static Dessin? depuisXml(String texte) {
    try {
      final ev = XmlDocument.parse(texte.trim()).rootElement;
      final type = ev.getAttribute('type') ?? '';
      final uid = ev.getAttribute('uid');
      final detail = ev.getElement('detail');
      if (uid == null || detail == null) return null;
      if (!type.startsWith('b-m-p') && type != 'u-d-f') return null;
      final mufasa = detail.getElement('__mufasa');
      final nom = detail.getElement('contact')?.getAttribute('callsign') ?? '';
      final parent = detail
          .findElements('link')
          .where((l) => l.getAttribute('relation') == 'p-p')
          .firstOrNull;
      Color lireCouleur(String? v, Color defaut) {
        final n = int.tryParse(v ?? '');
        return n == null ? defaut : Color(n & 0xFFFFFFFF);
      }

      FormeDessin forme;
      List<LatLng> points;
      Color couleur;
      if (type.startsWith('b-m-p')) {
        final pt = ev.getElement('point')!;
        forme = FormeDessin.point;
        points = [
          LatLng(double.parse(pt.getAttribute('lat')!),
              double.parse(pt.getAttribute('lon')!))
        ];
        couleur = lireCouleur(
            detail.getElement('color')?.getAttribute('argb'), Colors.red);
      } else {
        points = [
          for (final l in detail.findElements('link'))
            if (l.getAttribute('point') case final p?)
              LatLng(
                  double.parse(p.split(',')[0]), double.parse(p.split(',')[1])),
        ];
        if (points.length < 2) return null;
        final ferme = points.length > 3 && points.first == points.last;
        final declare = mufasa?.getAttribute('forme');
        forme = declare == 'mission' || mufasa?.getAttribute('mission') != null
            ? FormeDessin.mission
            : declare == 'zone' || (declare == null && ferme)
                ? FormeDessin.zone
                : FormeDessin.ligne;
        if (forme == FormeDessin.zone && ferme) points.removeLast();
        couleur = lireCouleur(
            detail.getElement('strokeColor')?.getAttribute('value'),
            Colors.red);
      }
      return Dessin(
        mission: forme == FormeDessin.mission
            ? mufasa?.getAttribute('mission')
            : null,
        pion: mufasa?.getAttribute('pion') ?? '',
        uid: uid,
        forme: forme,
        points: points,
        nom: nom,
        couleur: couleur.withValues(alpha: 1),
        calque: mufasa?.getAttribute('calque') ?? calqueParDefaut,
        auteur: parent?.getAttribute('uid') ?? '',
        auteurIndicatif: parent?.getAttribute('parent_callsign') ?? '',
        heure: DateTime.tryParse(ev.getAttribute('time') ?? ''),
      );
    } catch (_) {
      return null;
    }
  }

  /// Message CoT qui demande à tout le monde d'effacer un dessin.
  static String suppressionXml(String uidDessin, String monUid) {
    final t = DateTime.now().toUtc();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<event version="2.0" uid="${_e(monUid)}-suppr-${t.millisecondsSinceEpoch}" '
        'type="$typeSuppression" how="h-e" time="${t.toIso8601String()}" '
        'start="${t.toIso8601String()}" '
        'stale="${t.add(const Duration(minutes: 5)).toIso8601String()}">'
        '<point lat="0" lon="0" hae="9999999.0" ce="9999999.0" le="9999999.0"/>'
        '<detail><link uid="${_e(uidDessin)}" relation="none" type="none"/>'
        '<__forcedelete/></detail></event>';
  }

  /// Si le message est un ordre de suppression, renvoie l'uid du dessin visé.
  static String? lireSuppression(String texte) {
    try {
      final ev = XmlDocument.parse(texte.trim()).rootElement;
      if (ev.getAttribute('type') != typeSuppression) return null;
      return ev.getElement('detail')?.getElement('link')?.getAttribute('uid');
    } catch (_) {
      return null;
    }
  }
}

// Dessins partagés sur la carte : points particuliers, dessins libres
// (lignes, zones) et ennemis signalés.
// Ils circulent au format CoT, comme les positions, pour rester compatibles
// avec les autres outils de situation tactique.
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

enum FormeDessin { point, ligne, zone, ennemi }

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

/// Rubriques de la fiche de désignation d'un ennemi, dans l'ordre d'affichage.
const rubriquesEnnemi = <String, String>{
  'volume': 'Volume',
  'nature': 'Nature',
  'attitude': 'Attitude',
  'cap': 'Se dirige vers',
  'direction': 'Direction / déplacement',
  'materiels': 'Matériels / armement',
  'remarques': 'Remarques',
  'heure': 'Vu à',
  'observateur': 'Signalé par',
};

/// Directions possibles d'un ennemi en mouvement, en degrés (0 = nord).
const capsEnnemi = <String, int>{
  'NO': 315, 'N': 0, 'NE': 45, //
  'O': 270, 'E': 90, //
  'SO': 225, 'S': 180, 'SE': 135,
};

const nomsCaps = {
  'N': 'le nord',
  'NE': 'le nord-est',
  'E': 'l\'est',
  'SE': 'le sud-est',
  'S': 'le sud',
  'SO': 'le sud-ouest',
  'O': 'l\'ouest',
  'NO': 'le nord-ouest',
};

/// Ennemi déjà connu le plus proche de [ou], à moins de [metres] (sinon null).
Dessin? ennemiProche(Iterable<Dessin> dessins, LatLng ou,
    {double metres = 300}) {
  const distance = Distance();
  Dessin? meilleur;
  var mieux = metres;
  for (final d in dessins) {
    if (d.forme != FormeDessin.ennemi || d.disparu) continue;
    final m = distance(d.points.first, ou);
    if (m <= mieux) {
      mieux = m;
      meilleur = d;
    }
  }
  return meilleur;
}

/// Type CoT d'un ordre de suppression.
const typeSuppression = 't-x-d-d';

class Dessin {
  final String uid;
  final FormeDessin forme;
  final List<LatLng> points;
  final String nom;
  final Color couleur;
  final String auteur; // uid du téléphone qui l'a dessiné
  final String auteurIndicatif;
  final DateTime heure;

  /// Ennemi signalé : les informations remplies par l'observateur.
  /// Point particulier : ses observations (clé « observations »).
  final Map<String, String> fiche;

  String get observations => fiche['observations'] ?? '';

  // ----- Ennemis : ancienneté et mises à jour -----

  /// Au-delà de ce délai sans nouvelle, un ennemi pâlit sur la carte.
  static const delaiAncien = Duration(minutes: 30);

  bool get estAncien => ancienA(DateTime.now());

  /// Ancien à l'heure [t] (utile pour le rejeu d'un exercice).
  bool ancienA(DateTime t) =>
      forme == FormeDessin.ennemi && t.toUtc().difference(heure) > delaiAncien;

  /// « Plus là » : l'ennemi a disparu (il reste sur la carte, barré).
  bool get disparu => fiche['etat'] == 'disparu';

  /// Ancienne position, quand quelqu'un a indiqué « Il a bougé ».
  LatLng? get anciennePosition {
    final t = (fiche['ancien'] ?? '').split(',');
    if (t.length != 2) return null;
    final lat = double.tryParse(t[0]), lon = double.tryParse(t[1]);
    return lat == null || lon == null ? null : LatLng(lat, lon);
  }

  /// Copie mise à jour maintenant par [par] (son indicatif) depuis [parUid].
  Dessin _majPar(String par, String parUid,
      {List<LatLng>? points, Map<String, String> fiche = const {}}) {
    final maintenant = DateTime.now();
    final h = maintenant.toLocal();
    final hh =
        '${h.hour.toString().padLeft(2, '0')}h${h.minute.toString().padLeft(2, '0')}';
    return Dessin(
      uid: uid,
      forme: forme,
      points: points ?? this.points,
      nom: nom,
      couleur: couleur,
      auteur: parUid,
      auteurIndicatif: par,
      heure: maintenant,
      fiche: {
        ...this.fiche,
        'heure': hh,
        'revuPar': par,
        ...fiche,
      },
    );
  }

  /// « Toujours là » : je le revois au même endroit.
  Dessin toujoursLa({required String par, required String parUid}) {
    final f = Map.of(fiche)..remove('etat');
    return Dessin(
      uid: uid,
      forme: forme,
      points: points,
      nom: nom,
      couleur: couleur,
      auteur: auteur,
      auteurIndicatif: auteurIndicatif,
      heure: heure,
      fiche: f,
    )._majPar(par, parUid);
  }

  /// « Il a bougé » : il est maintenant en [vers] ; on garde l'ancienne place.
  Dessin aBouge(LatLng vers,
      {required String par,
      required String parUid,
      Map<String, String> fiche = const {}}) {
    final p = points.first;
    return _majPar(par, parUid, points: [
      vers
    ], fiche: {
      'ancien': '${p.latitude},${p.longitude}',
      'ancienHeure': this.fiche['heure'] ?? '',
      'etat': '',
      ...fiche,
    });
  }

  /// « Plus là » : il a disparu (barré, pas effacé).
  Dessin plusLa({required String par, required String parUid}) =>
      _majPar(par, parUid, fiche: {'etat': 'disparu'});

  Dessin({
    this.fiche = const {},
    required this.uid,
    required this.forme,
    required this.points,
    required this.nom,
    required this.couleur,
    required this.auteur,
    required this.auteurIndicatif,
    DateTime? heure,
  }) : heure = (heure ?? DateTime.now()).toUtc();

  LatLng get centre {
    if (points.length == 1) return points.first;
    var lat = 0.0, lon = 0.0;
    for (final p in points) {
      lat += p.latitude;
      lon += p.longitude;
    }
    return LatLng(lat / points.length, lon / points.length);
  }

  /// Copie déplacée : le centre du dessin va au nouvel endroit.
  Dessin deplace(LatLng vers, {required String par}) {
    final c = centre;
    final dLat = vers.latitude - c.latitude,
        dLon = vers.longitude - c.longitude;
    return Dessin(
      uid: uid,
      forme: forme,
      points: [
        for (final p in points) LatLng(p.latitude + dLat, p.longitude + dLon)
      ],
      nom: nom,
      couleur: couleur,
      auteur: par,
      auteurIndicatif: auteurIndicatif,
      fiche: fiche,
    );
  }

  /// Types CoT : point de carte « b-m-p-s-m », tracé « u-d-f »
  /// (une zone est un tracé fermé : son premier point est répété à la fin).
  String get typeCot => switch (forme) {
        FormeDessin.point => 'b-m-p-s-m',
        FormeDessin.ennemi => 'a-h-G',
        _ => 'u-d-f',
      };

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
    if (forme == FormeDessin.ennemi) {
      for (final e in fiche.entries) {
        b.write('<__champ cle="${_e(e.key)}" valeur="${_e(e.value)}"/>');
      }
      // Résumé lisible par les autres outils compatibles.
      final resume = [
        for (final e in rubriquesEnnemi.entries)
          if ((fiche[e.key] ?? '').isNotEmpty) '${e.value} : ${fiche[e.key]}'
      ].join(' / ');
      b.write('<remarks>${_e(resume)}</remarks>');
    } else if (forme == FormeDessin.point) {
      b.write('<color argb="$argb"/>');
      if (observations.isNotEmpty) {
        b.write('<remarks>${_e(observations)}</remarks>');
      }
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
      ..write('<__mufasa forme="${forme.name}"/>')
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
      final mufasa = detail.getElement('__mufasa');
      final declare = mufasa?.getAttribute('forme');
      // Anciennes versions : missions et symboles OTAN ne sont plus gérés.
      if (declare == 'mission' ||
          declare == 'symbole' ||
          mufasa?.getAttribute('mission') != null ||
          mufasa?.getAttribute('sidc') != null) {
        return null;
      }
      final estEnnemi = declare == 'ennemi';
      if (!estEnnemi && !type.startsWith('b-m-p') && type != 'u-d-f') {
        return null;
      }
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
      if (estEnnemi || type.startsWith('b-m-p')) {
        final pt = ev.getElement('point')!;
        forme = estEnnemi ? FormeDessin.ennemi : FormeDessin.point;
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
        forme = declare == 'zone' || (declare == null && ferme)
            ? FormeDessin.zone
            : FormeDessin.ligne;
        if (forme == FormeDessin.zone && ferme) points.removeLast();
        couleur = lireCouleur(
            detail.getElement('strokeColor')?.getAttribute('value'),
            Colors.red);
      }
      final remarques = detail.getElement('remarks')?.innerText ?? '';
      return Dessin(
        fiche: forme == FormeDessin.point
            ? {if (remarques.isNotEmpty) 'observations': remarques}
            : {
                for (final c in detail.findElements('__champ'))
                  if (c.getAttribute('cle') case final cle?)
                    cle: c.getAttribute('valeur') ?? '',
              },
        uid: uid,
        forme: forme,
        points: points,
        nom: nom,
        couleur: couleur.withValues(alpha: 1),
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

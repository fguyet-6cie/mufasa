// Messages échangés entre téléphones : un petit texte XML (format « CoT »,
// Cursor on Target) par position ou par dessin.
import 'package:xml/xml.dart';

import 'hierarchie.dart';

class CotEvenement {
  /// Identifiant unique et stable de l'émetteur (un par téléphone).
  final String uid;

  /// Type CoT. « a-f-G-U-C » = ami, terrestre, unité, combat.
  final String type;
  final String indicatif;

  /// Place dans la compagnie (fonction, section, groupe, équipe).
  final Place place;
  final double lat;
  final double lon;

  /// Précision horizontale en mètres (ce = circular error).
  final double precision;

  /// Niveau de batterie du téléphone, en %, s'il est connu.
  final int? batterie;
  final DateTime heure;

  /// Au-delà de cette heure, l'information est considérée périmée.
  final DateTime perime;

  CotEvenement({
    required this.uid,
    required this.indicatif,
    required this.lat,
    required this.lon,
    this.type = 'a-f-G-U-C',
    this.place = Place.inconnue,
    this.precision = 9999999,
    this.batterie,
    DateTime? heure,
    DateTime? perime,
  })  : heure = (heure ?? DateTime.now()).toUtc(),
        perime = (perime ??
                (heure ?? DateTime.now()).add(const Duration(minutes: 3)))
            .toUtc();

  bool get estPerime => DateTime.now().toUtc().isAfter(perime);

  /// Message de position (« SA ») de ce téléphone.
  factory CotEvenement.maPosition({
    required String uid,
    required String indicatif,
    required double lat,
    required double lon,
    double? precision,
    int? batterie,
    Place place = Place.inconnue,
  }) =>
      CotEvenement(
        place: place,
        uid: uid,
        indicatif: indicatif,
        lat: lat,
        lon: lon,
        precision: precision ?? 9999999,
        batterie: batterie,
      );

  String versXml() {
    String t(DateTime d) => d.toUtc().toIso8601String();
    String e(String s) => s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<event version="2.0" uid="${e(uid)}" type="${e(type)}" how="m-g" '
        'time="${t(heure)}" start="${t(heure)}" stale="${t(perime)}">'
        '<point lat="$lat" lon="$lon" hae="9999999.0" '
        'ce="${precision.toStringAsFixed(1)}" le="9999999.0"/>'
        '<detail><contact callsign="${e(indicatif)}"/>'
        '<__mufasa ${place.versAttributs()}'
        '${batterie == null ? '' : ' batterie="$batterie"'}/></detail></event>';
  }

  /// Lit un message CoT. Renvoie null s'il est illisible ou sans position.
  static CotEvenement? depuisXml(String texte) {
    try {
      final ev = XmlDocument.parse(texte.trim()).rootElement;
      if (ev.name.local != 'event') return null;
      final pt = ev.getElement('point');
      final uid = ev.getAttribute('uid');
      if (pt == null || uid == null) return null;
      final lat = double.parse(pt.getAttribute('lat')!);
      final lon = double.parse(pt.getAttribute('lon')!);
      final detail = ev.getElement('detail');
      final indicatif =
          detail?.getElement('contact')?.getAttribute('callsign') ?? uid;
      final m = detail?.getElement('__mufasa');
      return CotEvenement(
        place: m == null
            ? Place.inconnue
            : Place.depuisAttributs((c) => m.getAttribute(c)),
        uid: uid,
        type: ev.getAttribute('type') ?? 'a-f-G',
        indicatif: indicatif,
        lat: lat,
        lon: lon,
        precision: double.tryParse(pt.getAttribute('ce') ?? '') ?? 9999999,
        batterie: int.tryParse(m?.getAttribute('batterie') ?? ''),
        heure: DateTime.tryParse(ev.getAttribute('time') ?? ''),
        perime: DateTime.tryParse(ev.getAttribute('stale') ?? ''),
      );
    } catch (_) {
      return null;
    }
  }
}

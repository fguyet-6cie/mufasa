// Messages CoT (« Cursor on Target ») : le format XML standard utilisé par
// les outils de situation tactique. Le parler permet à Mufasa d'échanger avec
// d'autres outils compatibles et avec les serveurs TAK open source.
import 'package:xml/xml.dart';

class CotEvenement {
  /// Identifiant unique et stable de l'émetteur (un par téléphone).
  final String uid;

  /// Type CoT. « a-f-G-U-C » = ami, terrestre, unité, combat.
  final String type;
  final String indicatif;
  final String equipe;
  final double lat;
  final double lon;

  /// Précision horizontale en mètres (ce = circular error).
  final double precision;
  final DateTime heure;

  /// Au-delà de cette heure, l'information est considérée périmée.
  final DateTime perime;

  CotEvenement({
    required this.uid,
    required this.indicatif,
    required this.lat,
    required this.lon,
    this.type = 'a-f-G-U-C',
    this.equipe = 'Cyan',
    this.precision = 9999999,
    DateTime? heure,
    DateTime? perime,
  })  : heure = (heure ?? DateTime.now()).toUtc(),
        perime = (perime ??
                (heure ?? DateTime.now()).add(const Duration(minutes: 2)))
            .toUtc();

  bool get estPerime => DateTime.now().toUtc().isAfter(perime);

  /// Message de position (« SA ») de ce téléphone.
  factory CotEvenement.maPosition({
    required String uid,
    required String indicatif,
    required String equipe,
    required double lat,
    required double lon,
    double? precision,
  }) =>
      CotEvenement(
        uid: uid,
        indicatif: indicatif,
        equipe: equipe,
        lat: lat,
        lon: lon,
        precision: precision ?? 9999999,
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
        '<__group name="${e(equipe)}" role="Team Member"/>'
        '<takv platform="Mufasa" version="0.2"/></detail></event>';
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
      final equipe =
          detail?.getElement('__group')?.getAttribute('name') ?? 'Cyan';
      return CotEvenement(
        uid: uid,
        type: ev.getAttribute('type') ?? 'a-f-G',
        indicatif: indicatif,
        equipe: equipe,
        lat: lat,
        lon: lon,
        precision: double.tryParse(pt.getAttribute('ce') ?? '') ?? 9999999,
        heure: DateTime.tryParse(ev.getAttribute('time') ?? ''),
        perime: DateTime.tryParse(ev.getAttribute('stale') ?? ''),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Découpe un flux TCP en messages CoT complets (un message se termine
/// par la balise de fin `</event>`). Garde le morceau incomplet pour la suite.
class DecoupeurCot {
  final _tampon = StringBuffer();

  List<String> ajouter(String morceau) {
    _tampon.write(morceau);
    var texte = _tampon.toString();
    final messages = <String>[];
    while (true) {
      final fin = texte.indexOf('</event>');
      if (fin < 0) break;
      final debut = texte.indexOf('<event');
      if (debut >= 0 && debut < fin) {
        messages.add(texte.substring(debut, fin + 8));
      }
      texte = texte.substring(fin + 8);
    }
    _tampon
      ..clear()
      ..write(texte.length > 100000 ? '' : texte); // garde-fou mémoire
    return messages;
  }
}

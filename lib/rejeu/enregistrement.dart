// Enregistrement d'un exercice pour le rejeu (RETEX) : positions de tous,
// ennemis, points et dessins. Réservé au mode administrateur.
import 'dart:async';
import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cot.dart';
import '../hierarchie.dart';
import 'stockage.dart';

/// Transforme les événements en lignes de texte compactes (une par
/// événement). Une position n'est gardée que si la personne a bougé de 5 m
/// ou si la précédente date de plus d'une minute.
class Enregistreur {
  final void Function(String ligne) ecrire;
  Enregistreur(this.ecrire);

  final _derniere = <String, (DateTime, LatLng)>{};

  void position(CotEvenement e, DateTime t) {
    final ici = LatLng(e.lat, e.lon);
    final avant = _derniere[e.uid];
    if (avant != null &&
        t.difference(avant.$1) < const Duration(minutes: 1) &&
        const Distance()(avant.$2, ici) < 5) {
      return;
    }
    _derniere[e.uid] = (t, ici);
    ecrire(jsonEncode({
      't': t.millisecondsSinceEpoch,
      'k': 'p',
      'u': e.uid,
      'n': e.indicatif,
      'a': double.parse(e.lat.toStringAsFixed(6)),
      'o': double.parse(e.lon.toStringAsFixed(6)),
      'f': e.place.fonction.name,
      's': e.place.section,
      'g': e.place.groupe,
      'e': e.place.equipe,
    }));
  }

  void dessin(String xml, DateTime t) =>
      ecrire(jsonEncode({'t': t.millisecondsSinceEpoch, 'k': 'd', 'x': xml}));

  void suppression(String uid, DateTime t) =>
      ecrire(jsonEncode({'t': t.millisecondsSinceEpoch, 'k': 's', 'u': uid}));
}

/// Un événement relu depuis un exercice enregistré.
class Evenement {
  final DateTime t;
  final String type; // p : position, d : dessin, s : suppression
  final Map<String, dynamic> donnees;
  Evenement(this.t, this.type, this.donnees);

  static Evenement? lire(String ligne) {
    try {
      final j = jsonDecode(ligne) as Map<String, dynamic>;
      return Evenement(
          DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt(),
              isUtc: true),
          j['k'] as String,
          j);
    } catch (_) {
      return null;
    }
  }

  String get uid => donnees['u'] as String? ?? '';
  String get indicatif => donnees['n'] as String? ?? '';
  LatLng get point => LatLng(
      (donnees['a'] as num).toDouble(), (donnees['o'] as num).toDouble());
  String get xml => donnees['x'] as String? ?? '';
  Place get place => Place.depuisAttributs((c) => switch (c) {
        'fonction' => donnees['f'] as String?,
        'section' => '${donnees['s'] ?? 0}',
        'groupe' => '${donnees['g'] ?? 0}',
        'equipe' => '${donnees['e'] ?? 0}',
        _ => null,
      });
}

/// L'enregistrement en cours (un seul à la fois, sur le téléphone de
/// l'administrateur). Les lignes sont écrites par paquets toutes les 10 s.
class Enregistrement {
  String? _nom;
  Enregistreur? _enregistreur;
  final _tampon = <String>[];
  Timer? _ecriture;

  bool get actif => _nom != null;
  String? get nom => _nom;

  /// Reprend l'enregistrement après un redémarrage de l'appli.
  Future<void> reprendre() async {
    final p = await SharedPreferences.getInstance();
    final n = p.getString('enregistrement');
    if (n != null) _ouvrir(n);
  }

  Future<void> demarrer() async {
    final t = DateTime.now();
    String d(int v) => v.toString().padLeft(2, '0');
    final n = 'exercice-${t.year}${d(t.month)}${d(t.day)}-'
        '${d(t.hour)}${d(t.minute)}.txt';
    _ouvrir(n);
    final p = await SharedPreferences.getInstance();
    await p.setString('enregistrement', n);
  }

  void _ouvrir(String n) {
    _nom = n;
    _enregistreur = Enregistreur(_tampon.add);
    _ecriture?.cancel();
    _ecriture = Timer.periodic(const Duration(seconds: 10), (_) => _vider());
  }

  Future<void> _vider() async {
    final n = _nom;
    if (n == null || _tampon.isEmpty) return;
    final lignes = List<String>.of(_tampon);
    _tampon.clear();
    await ajouterLignes(n, lignes);
  }

  Future<void> arreter() async {
    await _vider();
    _ecriture?.cancel();
    _nom = null;
    _enregistreur = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('enregistrement');
  }

  void position(CotEvenement e) =>
      _enregistreur?.position(e, DateTime.now().toUtc());
  void dessin(String xml) => _enregistreur?.dessin(xml, DateTime.now().toUtc());
  void suppression(String uid) =>
      _enregistreur?.suppression(uid, DateTime.now().toUtc());
}

final enregistrement = Enregistrement();

// Partage avec le groupe : envoie ma position régulièrement, garde la liste
// des camarades reçus, et partage les dessins (points, dessins libres, ennemis).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cot.dart';
import 'dessins.dart';
import 'hierarchie.dart';
import 'reglages.dart';
import 'reseau/liaison.dart';

class Partage extends ChangeNotifier {
  /// Fréquence d'envoi de ma position quand je bouge.
  static const intervalle = Duration(seconds: 10);

  /// Immobile (moins de [deplacementMin] mètres), on n'envoie qu'à ce rythme,
  /// pour économiser la batterie et le forfait.
  static const intervalleImmobile = Duration(seconds: 60);
  static const deplacementMin = 10.0;

  /// Un camarade silencieux depuis ce délai disparaît de la carte.
  static const oubli = Duration(minutes: 10);

  /// Mes dessins sont renvoyés à ce rythme, pour ceux qui arrivent en retard.
  static const renvoiDessins = Duration(seconds: 60);

  final camarades = <String, CotEvenement>{};

  /// Tous les dessins connus (les miens et ceux reçus), par uid.
  final dessins = <String, Dessin>{};

  /// Dessins effacés : on les ignore s'ils reviennent.
  final _supprimes = <String>{};

  DateTime _dernierRenvoi = DateTime(2000);

  /// Prévient l'écran quand un camarade signale un nouvel ennemi.
  final _nouveauxEnnemis = StreamController<Dessin>.broadcast();
  Stream<Dessin> get nouveauxEnnemis => _nouveauxEnnemis.stream;
  Liaison? _liaison;
  StreamSubscription<String>? _ecoute;
  Timer? _minuterie;
  Reglages? _reglages;
  double? _lat, _lon, _precision;
  double? _latEnvoyee, _lonEnvoyee;
  DateTime _dernierEnvoi = DateTime(2000);

  Liaison? get liaison => _liaison;

  /// Message à afficher quand le partage ne peut pas démarrer.
  String? avertissement;

  Future<void> demarrer(Reglages r) async {
    await arreter();
    avertissement = null;
    _reglages = r;
    switch (r.mode) {
      case ModePartage.aucun:
        return;
      case ModePartage.wifi:
        _liaison = liaisonWifi();
      case ModePartage.relais || ModePartage.ancienServeur:
        if (!r.relaisComplet) {
          avertissement = '4G/5G : réglages à compléter';
          notifyListeners();
          return;
        }
        _liaison = liaisonRelais(
          hote: r.relaisHote,
          port: r.relaisPort,
          identifiant: r.relaisIdentifiant,
          motDePasse: r.relaisMotDePasse,
          codeGroupe: r.codeGroupe,
          uid: r.uid,
        );
    }
    _ecoute = _liaison!.messages.listen(recevoir);
    _liaison!.etat.addListener(notifyListeners);
    await _liaison!.demarrer();
    _minuterie = Timer.periodic(intervalle, (_) {
      if (_doitEnvoyer()) _envoyer();
      _nettoyer();
      if (DateTime.now().difference(_dernierRenvoi) >= renvoiDessins) {
        _envoyerMesDessins();
      }
    });
    _envoyer();
    _envoyerMesDessins();
    notifyListeners();
  }

  Future<void> arreter() async {
    _minuterie?.cancel();
    await _ecoute?.cancel();
    _liaison?.etat.removeListener(notifyListeners);
    await _liaison?.arreter();
    _liaison = null;
    camarades.clear();
    notifyListeners();
  }

  /// À appeler quand le GPS donne une nouvelle position.
  void majPosition(double lat, double lon, double precision) {
    final premiere = _lat == null;
    _lat = lat;
    _lon = lon;
    _precision = precision;
    if (premiere) _envoyer();
  }

  bool _doitEnvoyer() => fautEnvoyer(
      dernierEnvoi: _dernierEnvoi,
      maintenant: DateTime.now(),
      envoyee: _latEnvoyee == null ? null : LatLng(_latEnvoyee!, _lonEnvoyee!),
      actuelle: _lat == null ? null : LatLng(_lat!, _lon!));

  /// Faut-il renvoyer ma position ? Oui si j'ai bougé d'au moins
  /// [deplacementMin] mètres, ou si le dernier envoi date de plus d'une minute.
  static bool fautEnvoyer({
    required DateTime dernierEnvoi,
    required DateTime maintenant,
    required LatLng? envoyee,
    required LatLng? actuelle,
  }) {
    if (actuelle == null) return false;
    if (envoyee == null) return true;
    if (maintenant.difference(dernierEnvoi) >= intervalleImmobile) return true;
    return const Distance()(envoyee, actuelle) >= deplacementMin;
  }

  void _envoyer() {
    final r = _reglages;
    if (r == null || _lat == null || _liaison == null) return;
    _dernierEnvoi = DateTime.now();
    _latEnvoyee = _lat;
    _lonEnvoyee = _lon;
    _liaison!.envoyer(CotEvenement.maPosition(
      uid: r.uid,
      indicatif: r.indicatif,
      lat: _lat!,
      lon: _lon!,
      precision: _precision,
      place: r.place,
    ).versXml());
  }

  @visibleForTesting
  void recevoir(String xml) {
    final suppr = Dessin.lireSuppression(xml);
    if (suppr != null) {
      _oublierDessin(suppr);
      return;
    }
    final d = Dessin.depuisXml(xml);
    if (d != null) {
      if (_supprimes.contains(d.uid)) {
        // Quelqu'un renvoie un dessin déjà effacé : on lui redit de l'effacer.
        _liaison?.envoyer(Dessin.suppressionXml(d.uid, _reglages?.uid ?? ''));
        return;
      }
      final connu = dessins[d.uid];
      if (connu == null &&
          d.forme == FormeDessin.ennemi &&
          d.auteur != _reglages?.uid) {
        _nouveauxEnnemis.add(d);
      }
      if (connu == null || !connu.heure.isAfter(d.heure)) {
        dessins[d.uid] = d;
        _enregistrerDessins();
        notifyListeners();
      }
      return;
    }
    final ev = CotEvenement.depuisXml(xml);
    if (ev == null || ev.uid == _reglages?.uid) return;
    // On ne garde ici que les unités (types « a-… »), pas les autres objets.
    if (!ev.type.startsWith('a-')) return;
    camarades[ev.uid] = ev;
    notifyListeners();
  }

  void _nettoyer() {
    final limite = DateTime.now().toUtc().subtract(oubli);
    final avant = camarades.length;
    camarades.removeWhere((_, ev) => ev.perime.isBefore(limite));
    if (camarades.length != avant) notifyListeners();
  }

  /// Camarades à afficher selon ma place et le niveau de détail choisi.
  Iterable<CotEvenement> get camaradesVisibles {
    final r = _reglages;
    if (r == null) return camarades.values;
    return camarades.values
        .where((c) => estVisible(r.place, c.place, r.profondeur, r.perimetre));
  }

  /// Ce camarade est-il dans mon trinôme ?
  bool estDeMonTrinome(CotEvenement c) {
    final r = _reglages;
    return r != null && memeTrinome(r.place, c.place);
  }

  /// Change ce que j'affiche (chacun choisit).
  Future<void> choisirAffichage(
      {int? profondeur, Perimetre? perimetre, bool? ennemisAnciens}) async {
    final r = _reglages;
    if (r == null) return;
    if (profondeur != null) r.profondeur = profondeur;
    if (perimetre != null) r.perimetre = perimetre;
    if (ennemisAnciens != null) r.ennemisAnciens = ennemisAnciens;
    await r.enregistrer();
    notifyListeners();
  }

  /// Ce camarade est-il dans mon groupe (GOLF) ?
  bool estDeMonGroupe(CotEvenement c) {
    final r = _reglages;
    return r != null && memeGroupe(r.place, c.place);
  }

  Reglages? get reglages => _reglages;

  // ----- Dessins -----

  void ajouterDessin(Dessin d) {
    dessins[d.uid] = d;
    _enregistrerDessins();
    _liaison?.envoyer(d.versXml());
    notifyListeners();
  }

  void supprimerDessin(String uid) {
    _oublierDessin(uid);
    _liaison?.envoyer(Dessin.suppressionXml(uid, _reglages?.uid ?? ''));
  }

  void _oublierDessin(String uid) {
    _supprimes.add(uid);
    if (dessins.remove(uid) != null) notifyListeners();
    _enregistrerDessins();
  }

  void _envoyerMesDessins() {
    _dernierRenvoi = DateTime.now();
    final moi = _reglages?.uid;
    if (_liaison == null || moi == null) return;
    for (final d in dessins.values.where((d) => d.auteur == moi)) {
      _liaison!.envoyer(d.versXml());
    }
  }

  /// Effacement d'urgence : coupe le partage et efface tout ce que Mufasa
  /// a gardé dans ce téléphone (dessins, réglages, code de groupe…).
  Future<void> toutEffacer() async {
    await arreter();
    _reglages = null;
    _lat = _lon = _precision = null;
    dessins.clear();
    _supprimes.clear();
    camarades.clear();
    final p = await SharedPreferences.getInstance();
    await p.clear();
    notifyListeners();
  }

  /// Recharge les dessins gardés dans le téléphone.
  Future<void> chargerDessins() async {
    final p = await SharedPreferences.getInstance();
    for (final xml in p.getStringList('dessins') ?? const <String>[]) {
      final d = Dessin.depuisXml(xml);
      if (d != null) dessins[d.uid] = d;
    }
    _supprimes.addAll(p.getStringList('dessinsSupprimes') ?? const []);
    notifyListeners();
  }

  Future<void> _enregistrerDessins() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
        'dessins', [for (final d in dessins.values) d.versXml()]);
    // On ne garde que les 500 dernières suppressions.
    final s = _supprimes.toList();
    await p.setStringList(
        'dessinsSupprimes', s.length > 500 ? s.sublist(s.length - 500) : s);
  }
}

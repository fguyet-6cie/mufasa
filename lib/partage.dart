// Partage des positions : envoie la mienne régulièrement et garde la liste
// des camarades reçus.
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'cot.dart';
import 'reglages.dart';
import 'reseau/liaison.dart';

class Partage extends ChangeNotifier {
  /// Fréquence d'envoi de ma position.
  static const intervalle = Duration(seconds: 10);

  /// Un camarade silencieux depuis ce délai disparaît de la carte.
  static const oubli = Duration(minutes: 10);

  final camarades = <String, CotEvenement>{};
  Liaison? _liaison;
  StreamSubscription<String>? _ecoute;
  Timer? _minuterie;
  Reglages? _reglages;
  double? _lat, _lon, _precision;

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
      case ModePartage.serveur:
        if (r.hote.isEmpty) return;
        _liaison = liaisonServeur(r.hote, r.port);
      case ModePartage.relais:
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
      _envoyer();
      _nettoyer();
    });
    _envoyer();
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

  void _envoyer() {
    final r = _reglages;
    if (r == null || _lat == null || _liaison == null) return;
    _liaison!.envoyer(CotEvenement.maPosition(
      uid: r.uid,
      indicatif: r.indicatif,
      equipe: r.equipe,
      lat: _lat!,
      lon: _lon!,
      precision: _precision,
    ).versXml());
  }

  @visibleForTesting
  void recevoir(String xml) {
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
}

// Version navigateur (aperçu uniquement) : pas de réseau direct possible.
import 'dart:async';

import 'liaison.dart';

class _LiaisonInactive extends Liaison {
  @override
  final String nom;
  _LiaisonInactive(this.nom);
  @override
  Stream<String> get messages => const Stream.empty();
  @override
  Future<void> demarrer() async =>
      etat.value = 'indisponible dans le navigateur';
  @override
  Future<void> envoyer(String xml) async {}
  @override
  Future<void> arreter() async => etat.value = 'arrêtée';
}

Liaison liaisonWifi() => _LiaisonInactive('Wi-Fi local');
Liaison liaisonRelais({
  required String hote,
  required int port,
  required String identifiant,
  required String motDePasse,
  required String codeGroupe,
  required String uid,
}) =>
    _LiaisonInactive('4G/5G');

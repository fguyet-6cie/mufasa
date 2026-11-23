// Une « liaison » transporte les messages CoT entre téléphones.
// Deux modes :
//  - Wi-Fi local (sans serveur) : tous les téléphones sur le même Wi-Fi ou le
//    même partage de connexion se parlent directement (multidiffusion UDP).
//  - 4G/5G : chaque téléphone passe par une boîte aux lettres en ligne
//    (MQTT), avec les positions chiffrées par le code de groupe.
import 'package:flutter/foundation.dart';

import 'liaison_io.dart' if (dart.library.js_interop) 'liaison_web.dart'
    as impl;

abstract class Liaison {
  String get nom;

  /// Messages CoT reçus (texte XML).
  Stream<String> get messages;

  /// Texte court décrivant l'état, affiché à l'utilisateur.
  final etat = ValueNotifier<String>('arrêtée');

  Future<void> demarrer();
  Future<void> envoyer(String xml);
  Future<void> arreter();
}

/// Adresse et port de la multidiffusion propres à Mufasa (on ne reprend pas
/// ceux d'ATAK, pour ne pas mélanger avec d'autres applis sur le même Wi-Fi).
const groupeMulticast = '239.21.6.6';
const portMulticast = 21606;

Liaison liaisonWifi() => impl.liaisonWifi();
Liaison liaisonRelais({
  required String hote,
  required int port,
  required String identifiant,
  required String motDePasse,
  required String codeGroupe,
  required String uid,
}) =>
    impl.liaisonRelais(
        hote: hote,
        port: port,
        identifiant: identifiant,
        motDePasse: motDePasse,
        codeGroupe: codeGroupe,
        uid: uid);

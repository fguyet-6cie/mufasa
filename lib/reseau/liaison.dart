// Une « liaison » transporte les messages CoT entre téléphones.
// Trois modes :
//  - Wi-Fi local (sans serveur) : tous les téléphones sur le même Wi-Fi ou le
//    même partage de connexion se parlent directement (multidiffusion UDP).
//  - 4G/5G : chaque téléphone passe par une boîte aux lettres en ligne
//    (MQTT), avec les positions chiffrées par le code de groupe.
//  - Serveur TAK : connexion TCP à un serveur TAK (pour l'interopérabilité).
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

/// Adresse et port standard de la multidiffusion de positions CoT.
const groupeMulticast = '239.2.3.1';
const portMulticast = 6969;

/// Port TCP non chiffré habituel des serveurs TAK.
const portServeurParDefaut = 8087;

Liaison liaisonWifi() => impl.liaisonWifi();
Liaison liaisonServeur(String hote, int port) =>
    impl.liaisonServeur(hote, port);
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

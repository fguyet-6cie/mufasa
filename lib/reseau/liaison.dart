// Une « liaison » transporte les messages CoT entre téléphones.
// Deux modes :
//  - Wi-Fi local (sans serveur) : tous les téléphones sur le même Wi-Fi ou le
//    même partage de connexion se parlent directement (multidiffusion UDP).
//  - Serveur : chaque téléphone se connecte à un serveur TAK (TCP), qui
//    redistribue les positions à tout le monde, même via la 4G.
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

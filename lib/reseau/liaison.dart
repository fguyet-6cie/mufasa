// Une « liaison » transporte les messages entre téléphones, en 4G/5G :
// chaque téléphone passe par une boîte aux lettres en ligne (MQTT), avec les
// messages chiffrés par le code de groupe.
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

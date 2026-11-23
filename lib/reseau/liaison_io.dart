// Version téléphone : vraies connexions réseau.

import 'liaison.dart';
import 'liaison_relais_io.dart';

Liaison liaisonRelais({
  required String hote,
  required int port,
  required String identifiant,
  required String motDePasse,
  required String codeGroupe,
  required String uid,
}) =>
    LiaisonRelais(
        hote: hote,
        port: port,
        identifiant: identifiant,
        motDePasse: motDePasse,
        codeGroupe: codeGroupe,
        uid: uid);

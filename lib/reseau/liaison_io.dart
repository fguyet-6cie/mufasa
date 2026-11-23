// Version téléphone : vraies connexions réseau.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'liaison.dart';
import 'liaison_relais_io.dart';

Liaison liaisonWifi() => LiaisonWifi();
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

/// Sans serveur : multidiffusion UDP sur le réseau Wi-Fi local.
class LiaisonWifi extends Liaison {
  static const _canalAndroid = MethodChannel('mufasa/multicast');

  @override
  String get nom => 'Wi-Fi local';
  final _messages = StreamController<String>.broadcast();
  RawDatagramSocket? _socket;
  final _groupe = InternetAddress(groupeMulticast);

  @override
  Stream<String> get messages => _messages.stream;

  @override
  Future<void> demarrer() async {
    if (_socket != null) return;
    try {
      if (Platform.isAndroid) {
        // Sans ce « verrou », Android jette les messages multidiffusés.
        await _canalAndroid.invokeMethod('acquerir');
      }
      final s = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        portMulticast,
        reuseAddress: true,
        reusePort: Platform.isIOS || Platform.isMacOS,
      );
      s.joinMulticast(_groupe);
      s.listen((ev) {
        if (ev != RawSocketEvent.read) return;
        final d = s.receive();
        if (d != null) {
          _messages.add(utf8.decode(d.data, allowMalformed: true));
        }
      });
      _socket = s;
      etat.value = 'active';
    } catch (e) {
      etat.value = 'erreur : $e';
    }
  }

  @override
  Future<void> envoyer(String xml) async {
    _socket?.send(utf8.encode(xml), _groupe, portMulticast);
  }

  @override
  Future<void> arreter() async {
    _socket?.close();
    _socket = null;
    if (Platform.isAndroid) {
      try {
        await _canalAndroid.invokeMethod('liberer');
      } catch (_) {}
    }
    etat.value = 'arrêtée';
  }
}

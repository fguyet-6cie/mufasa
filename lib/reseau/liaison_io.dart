// Version téléphone : vraies connexions réseau.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../cot.dart';
import 'liaison.dart';
import 'liaison_relais_io.dart';

Liaison liaisonWifi() => LiaisonWifi();
Liaison liaisonServeur(String hote, int port) => LiaisonServeur(hote, port);
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

/// Avec serveur : connexion TCP à un serveur TAK, reconnexion automatique.
class LiaisonServeur extends Liaison {
  final String hote;
  final int port;
  LiaisonServeur(this.hote, this.port);

  @override
  String get nom => 'Serveur $hote:$port';
  final _messages = StreamController<String>.broadcast();
  Socket? _socket;
  bool _actif = false;
  Timer? _relance;

  @override
  Stream<String> get messages => _messages.stream;

  @override
  Future<void> demarrer() async {
    _actif = true;
    await _connecter();
  }

  Future<void> _connecter() async {
    if (!_actif || _socket != null) return;
    etat.value = 'connexion…';
    try {
      final s = await Socket.connect(hote, port,
          timeout: const Duration(seconds: 10));
      s.setOption(SocketOption.tcpNoDelay, true);
      _socket = s;
      etat.value = 'connectée';
      final decoupe = DecoupeurCot();
      s
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(
            (morceau) => decoupe.ajouter(morceau).forEach(_messages.add),
            onError: (_) => _perdue(),
            onDone: _perdue,
            cancelOnError: true,
          );
    } catch (e) {
      etat.value = 'serveur injoignable, nouvel essai…';
      _programmerRelance();
    }
  }

  void _perdue() {
    _socket?.destroy();
    _socket = null;
    if (_actif) {
      etat.value = 'connexion perdue, nouvel essai…';
      _programmerRelance();
    }
  }

  void _programmerRelance() {
    _relance?.cancel();
    if (_actif) _relance = Timer(const Duration(seconds: 5), _connecter);
  }

  @override
  Future<void> envoyer(String xml) async {
    try {
      _socket?.write(xml);
    } catch (_) {
      _perdue();
    }
  }

  @override
  Future<void> arreter() async {
    _actif = false;
    _relance?.cancel();
    _socket?.destroy();
    _socket = null;
    etat.value = 'arrêtée';
  }
}

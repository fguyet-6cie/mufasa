// Liaison 4G/5G : passe par une boîte aux lettres en ligne (protocole MQTT,
// connexion chiffrée TLS). Les messages sont en plus chiffrés avec le code de
// groupe avant de quitter le téléphone.
import 'dart:async';
import 'package:typed_data/typed_data.dart';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../chiffrement.dart';
import 'liaison.dart';

class LiaisonRelais extends Liaison {
  final String hote;
  final int port;
  final String identifiant;
  final String motDePasse;
  final String codeGroupe;
  final String uid;

  /// Toujours vrai en vrai ; faux seulement pour les tests locaux.
  final bool tls;

  LiaisonRelais({
    required this.hote,
    required this.identifiant,
    required this.motDePasse,
    required this.codeGroupe,
    required this.uid,
    this.port = 8883,
    this.tls = true,
  });

  @override
  String get nom => '4G/5G';
  final _messages = StreamController<String>.broadcast();
  MqttServerClient? _client;
  CleGroupe? _cle;
  StreamSubscription? _ecoute;

  @override
  Stream<String> get messages => _messages.stream;

  String get _sujet => 'mufasa/${_cle!.casier}/cot';

  @override
  Future<void> demarrer() async {
    etat.value = 'connexion…';
    _cle ??= await CleGroupe.depuisCode(codeGroupe);
    final c = MqttServerClient.withPort(hote, uid, port)
      ..secure = tls
      ..keepAlivePeriod = 30
      ..setProtocolV311()
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true
      ..logging(on: false)
      ..onConnected = (() => etat.value = 'connectée')
      ..onAutoReconnect = (() => etat.value = 'connexion perdue, nouvel essai…')
      ..onAutoReconnected = (() => etat.value = 'connectée')
      ..onDisconnected = (() {
        if (_client != null) etat.value = 'déconnectée';
      });
    c.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(uid)
        .authenticateAs(identifiant, motDePasse)
        .startClean();
    _client = c;
    try {
      await c.connect();
    } catch (e) {
      etat.value = 'connexion impossible (vérifier l\'accès)';
      _client = null;
      c.disconnect();
      return;
    }
    if (c.connectionStatus?.state != MqttConnectionState.connected) {
      etat.value = 'accès refusé (identifiant ou mot de passe ?)';
      _client = null;
      c.disconnect();
      return;
    }
    etat.value = 'connectée';
    c.subscribe(_sujet, MqttQos.atMostOnce);
    _ecoute = c.updates?.listen((recus) async {
      for (final r in recus) {
        final msg = r.payload;
        if (msg is! MqttPublishMessage) continue;
        final texte = await _cle!.dechiffrer(msg.payload.message.toList());
        if (texte != null) _messages.add(texte);
      }
    });
  }

  @override
  Future<void> envoyer(String xml) async {
    final c = _client;
    if (c == null ||
        c.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }
    final donnees = await _cle!.chiffrer(xml);
    final b = MqttClientPayloadBuilder()
      ..addBuffer(Uint8Buffer()..addAll(donnees));
    c.publishMessage(_sujet, MqttQos.atMostOnce, b.payload!);
  }

  @override
  Future<void> arreter() async {
    await _ecoute?.cancel();
    final c = _client;
    _client = null;
    c?.autoReconnect = false;
    c?.disconnect();
    etat.value = 'arrêtée';
  }
}

// Chiffrement des positions avec le code de groupe.
// Le code de groupe ne quitte jamais le téléphone : il sert à fabriquer une
// clé secrète (AES-256-GCM). La boîte aux lettres en ligne ne voit passer
// que des messages illisibles.
import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class CleGroupe {
  final SecretKey _cle;

  /// Nom du « casier » dans la boîte aux lettres, tiré lui aussi du code :
  /// deux groupes avec des codes différents ne se voient pas.
  final String casier;

  CleGroupe._(this._cle, this.casier);

  static final _aes = AesGcm.with256bits();

  static Future<CleGroupe> depuisCode(String code) async {
    final derive = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 20000,
      bits: 384,
    );
    final brut = await (await derive.deriveKeyFromPassword(
      password: code.trim(),
      nonce: utf8.encode('mufasa-groupe-v1'),
    ))
        .extractBytes();
    final casier = brut
        .sublist(32, 44)
        .map((o) => o.toRadixString(16).padLeft(2, '0'))
        .join();
    return CleGroupe._(SecretKey(brut.sublist(0, 32)), casier);
  }

  Future<List<int>> chiffrer(String texte) async {
    final boite = await _aes.encrypt(utf8.encode(texte), secretKey: _cle);
    return boite.concatenation();
  }

  /// Renvoie null si le message n'a pas été chiffré avec le même code.
  Future<String?> dechiffrer(List<int> donnees) async {
    try {
      final boite = SecretBox.fromConcatenation(
        donnees,
        nonceLength: _aes.nonceLength,
        macLength: _aes.macAlgorithm.macLength,
      );
      return utf8.decode(await _aes.decrypt(boite, secretKey: _cle));
    } catch (_) {
      return null;
    }
  }
}

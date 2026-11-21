// Réglages de l'utilisateur, gardés dans le téléphone.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ModePartage { aucun, wifi, serveur }

/// Couleurs d'équipe. Le nom anglais est celui qui circule dans les messages
/// CoT (pour rester compatible), le nom français est affiché.
const equipes = <String, (String, Color)>{
  'Cyan': ('Cyan', Colors.cyan),
  'Red': ('Rouge', Colors.red),
  'Green': ('Vert', Colors.green),
  'Yellow': ('Jaune', Colors.amber),
  'Orange': ('Orange', Colors.orange),
  'Blue': ('Bleu', Colors.blue),
  'Purple': ('Violet', Colors.purple),
  'White': ('Blanc', Colors.white),
};

Color couleurEquipe(String nom) => equipes[nom]?.$2 ?? Colors.cyan;

class Reglages {
  String uid;
  String indicatif;
  String equipe;
  ModePartage mode;
  String hote;
  int port;

  Reglages({
    required this.uid,
    required this.indicatif,
    required this.equipe,
    required this.mode,
    required this.hote,
    required this.port,
  });

  static Future<Reglages> charger() async {
    final p = await SharedPreferences.getInstance();
    var uid = p.getString('uid');
    if (uid == null) {
      final r = Random.secure();
      uid =
          'MUFASA-${List.generate(8, (_) => r.nextInt(16).toRadixString(16)).join().toUpperCase()}';
      await p.setString('uid', uid);
    }
    return Reglages(
      uid: uid,
      indicatif: p.getString('indicatif') ?? 'Sans nom',
      equipe: p.getString('equipe') ?? 'Cyan',
      mode: ModePartage.values[p.getInt('mode') ?? ModePartage.wifi.index],
      hote: p.getString('hote') ?? '',
      port: p.getInt('port') ?? 8087,
    );
  }

  Future<void> enregistrer() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('indicatif', indicatif);
    await p.setString('equipe', equipe);
    await p.setInt('mode', mode.index);
    await p.setString('hote', hote);
    await p.setInt('port', port);
  }
}

class ReglagesScreen extends StatefulWidget {
  final Reglages reglages;
  const ReglagesScreen({super.key, required this.reglages});

  @override
  State<ReglagesScreen> createState() => _ReglagesScreenState();
}

class _ReglagesScreenState extends State<ReglagesScreen> {
  late final _indicatif = TextEditingController(
      text: widget.reglages.indicatif == 'Sans nom'
          ? ''
          : widget.reglages.indicatif);
  late final _hote = TextEditingController(text: widget.reglages.hote);
  late final _port = TextEditingController(text: '${widget.reglages.port}');
  late String _equipe = widget.reglages.equipe;
  late ModePartage _mode = widget.reglages.mode;

  @override
  void dispose() {
    _indicatif.dispose();
    _hote.dispose();
    _port.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    final r = widget.reglages
      ..indicatif =
          _indicatif.text.trim().isEmpty ? 'Sans nom' : _indicatif.text.trim()
      ..equipe = _equipe
      ..mode = _mode
      ..hote = _hote.text.trim()
      ..port = int.tryParse(_port.text.trim()) ?? 8087;
    await r.enregistrer();
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _indicatif,
            decoration: const InputDecoration(
                labelText: 'Mon indicatif', hintText: 'ex. ALPHA 1'),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _equipe,
            decoration: const InputDecoration(labelText: 'Mon équipe'),
            items: [
              for (final e in equipes.entries)
                DropdownMenuItem(
                  value: e.key,
                  child: Row(children: [
                    CircleAvatar(radius: 8, backgroundColor: e.value.$2),
                    const SizedBox(width: 8),
                    Text(e.value.$1),
                  ]),
                ),
            ],
            onChanged: (v) => setState(() => _equipe = v!),
          ),
          const SizedBox(height: 24),
          Text('Partage des positions',
              style: Theme.of(context).textTheme.titleMedium),
          RadioGroup<ModePartage>(
            groupValue: _mode,
            onChanged: (v) => setState(() => _mode = v!),
            child: const Column(children: [
              RadioListTile(
                value: ModePartage.wifi,
                title: Text('Sans serveur (même Wi-Fi)'),
                subtitle: Text(
                    'Pour un petit exercice : tous les téléphones sur le même '
                    'Wi-Fi ou le même partage de connexion.'),
              ),
              RadioListTile(
                value: ModePartage.serveur,
                title: Text('Avec serveur'),
                subtitle:
                    Text('Fonctionne aussi en 4G, via le boîtier serveur.'),
              ),
              RadioListTile(
                value: ModePartage.aucun,
                title: Text('Désactivé'),
              ),
            ]),
          ),
          if (_mode == ModePartage.serveur) ...[
            TextField(
              controller: _hote,
              decoration: const InputDecoration(
                  labelText: 'Adresse du serveur',
                  hintText: 'ex. 192.168.1.10'),
              keyboardType: TextInputType.url,
            ),
            TextField(
              controller: _port,
              decoration: const InputDecoration(labelText: 'Port'),
              keyboardType: TextInputType.number,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _valider, child: const Text('Enregistrer')),
          const SizedBox(height: 12),
          Text('Identifiant de ce téléphone : ${widget.reglages.uid}',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

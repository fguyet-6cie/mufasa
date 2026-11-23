// Réglages de l'utilisateur, gardés dans le téléphone.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hierarchie.dart';

/// Tout ce qu'il faut pour rejoindre un groupe en 4G/5G, en un seul texte à
/// envoyer par messagerie : « MUFASA1:… ».
class Invitation {
  final String hote;
  final int port;
  final String identifiant;
  final String motDePasse;
  final String codeGroupe;

  const Invitation({
    required this.hote,
    required this.port,
    required this.identifiant,
    required this.motDePasse,
    required this.codeGroupe,
  });

  static const prefixe = 'MUFASA1:';

  String encoder() =>
      prefixe +
      base64Url.encode(utf8.encode(jsonEncode({
        'h': hote,
        'p': port,
        'i': identifiant,
        'm': motDePasse,
        'g': codeGroupe,
      })));

  static Invitation? decoder(String texte) {
    final t = texte.trim();
    final debut = t.indexOf(prefixe);
    if (debut < 0) return null;
    try {
      final brut =
          t.substring(debut + prefixe.length).split(RegExp(r'\s')).first;
      final j =
          jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(brut))))
              as Map<String, dynamic>;
      return Invitation(
        hote: j['h'] as String,
        port: (j['p'] as num).toInt(),
        identifiant: j['i'] as String,
        motDePasse: j['m'] as String,
        codeGroupe: j['g'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}

class Reglages {
  String uid;
  String indicatif;
  // Boîte aux lettres 4G/5G
  String relaisHote;
  int relaisPort;
  String relaisIdentifiant;
  String relaisMotDePasse;
  String codeGroupe;
  // Place dans la compagnie
  Fonction fonction;
  int section, groupe, numEquipe;

  /// Ce que j'affiche : jusqu'à quel niveau (1, 2 ou 4) et quelle partie.
  int profondeur;
  Perimetre perimetre;

  /// Afficher les ennemis signalés il y a plus de 30 min.
  bool ennemisAnciens;

  Place get place => Place(fonction,
      section: fonction.aSection ? section : 0,
      groupe: fonction.aGroupe ? groupe : 0,
      equipe: fonction.aEquipe ? numEquipe : 0);

  Reglages({
    this.fonction = Fonction.nonRenseignee,
    this.section = 1,
    this.groupe = 1,
    this.numEquipe = 1,
    this.profondeur = 4,
    this.perimetre = Perimetre.compagnie,
    this.ennemisAnciens = true,
    required this.uid,
    required this.indicatif,
    required this.relaisHote,
    required this.relaisPort,
    required this.relaisIdentifiant,
    required this.relaisMotDePasse,
    required this.codeGroupe,
  });

  bool get relaisComplet =>
      relaisHote.isNotEmpty &&
      relaisIdentifiant.isNotEmpty &&
      relaisMotDePasse.isNotEmpty &&
      codeGroupe.isNotEmpty;

  Invitation get invitation => Invitation(
        hote: relaisHote,
        port: relaisPort,
        identifiant: relaisIdentifiant,
        motDePasse: relaisMotDePasse,
        codeGroupe: codeGroupe,
      );

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
      relaisHote: p.getString('relaisHote') ?? '',
      relaisPort: p.getInt('relaisPort') ?? 8883,
      relaisIdentifiant: p.getString('relaisIdentifiant') ?? '',
      relaisMotDePasse: p.getString('relaisMotDePasse') ?? '',
      codeGroupe: p.getString('codeGroupe') ?? '',
      fonction: Fonction.values
              .where((f) => f.name == p.getString('fonction'))
              .firstOrNull ??
          Fonction.nonRenseignee,
      section: p.getInt('section') ?? 1,
      groupe: p.getInt('groupe') ?? 1,
      numEquipe: p.getInt('equipeNum') ?? 1,
      profondeur: p.getInt('profondeur') ?? 4,
      perimetre: Perimetre.values
              .where((v) => v.name == p.getString('perimetre'))
              .firstOrNull ??
          Perimetre.compagnie,
      ennemisAnciens: p.getBool('ennemisAnciens') ?? true,
    );
  }

  Future<void> enregistrer() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('indicatif', indicatif);
    await p.setString('relaisHote', relaisHote);
    await p.setInt('relaisPort', relaisPort);
    await p.setString('relaisIdentifiant', relaisIdentifiant);
    await p.setString('relaisMotDePasse', relaisMotDePasse);
    await p.setString('codeGroupe', codeGroupe);
    await p.setString('fonction', fonction.name);
    await p.setInt('section', section);
    await p.setInt('groupe', groupe);
    await p.setInt('equipeNum', numEquipe);
    await p.setInt('profondeur', profondeur);
    await p.setString('perimetre', perimetre.name);
    await p.setBool('ennemisAnciens', ennemisAnciens);
  }
}

class ReglagesScreen extends StatefulWidget {
  final Reglages reglages;
  const ReglagesScreen({super.key, required this.reglages});

  @override
  State<ReglagesScreen> createState() => _ReglagesScreenState();
}

class _ReglagesScreenState extends State<ReglagesScreen> {
  Reglages get r => widget.reglages;
  late final _indicatif =
      TextEditingController(text: r.indicatif == 'Sans nom' ? '' : r.indicatif);
  late final _relaisHote = TextEditingController(text: r.relaisHote);
  late final _relaisPort = TextEditingController(text: '${r.relaisPort}');
  late final _relaisId = TextEditingController(text: r.relaisIdentifiant);
  late final _relaisMdp = TextEditingController(text: r.relaisMotDePasse);
  late final _code = TextEditingController(text: r.codeGroupe);
  late Fonction _fonction = r.fonction;
  late int _section = r.section, _groupe = r.groupe, _equipeNum = r.numEquipe;
  bool _voirAcces = false;

  @override
  void dispose() {
    for (final c in [
      _indicatif,
      _relaisHote,
      _relaisPort,
      _relaisId,
      _relaisMdp,
      _code,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _info(String texte) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(texte)));

  Future<void> _collerInvitation() async {
    final presse = await Clipboard.getData(Clipboard.kTextPlain);
    final inv = Invitation.decoder(presse?.text ?? '');
    if (inv == null) {
      _info('Pas d\'invitation MUFASA dans le presse-papiers.');
      return;
    }
    setState(() {
      _relaisHote.text = inv.hote;
      _relaisPort.text = '${inv.port}';
      _relaisId.text = inv.identifiant;
      _relaisMdp.text = inv.motDePasse;
      _code.text = inv.codeGroupe;
    });
    _info('Invitation reçue. Appuie sur Enregistrer.');
  }

  Future<void> _copierInvitation() async {
    final inv = Invitation(
      hote: _relaisHote.text.trim(),
      port: int.tryParse(_relaisPort.text.trim()) ?? 8883,
      identifiant: _relaisId.text.trim(),
      motDePasse: _relaisMdp.text,
      codeGroupe: _code.text.trim(),
    );
    await Clipboard.setData(ClipboardData(
        text: 'Rejoins MUFASA : ouvre MUFASA > Réglages > '
            '« Coller une invitation ».\n${inv.encoder()}'));
    _info('Invitation copiée. Envoie-la par messagerie à ta compagnie.');
  }

  Future<void> _valider() async {
    r
      ..indicatif =
          _indicatif.text.trim().isEmpty ? 'Sans nom' : _indicatif.text.trim()
      ..relaisHote = _relaisHote.text.trim()
      ..relaisPort = int.tryParse(_relaisPort.text.trim()) ?? 8883
      ..relaisIdentifiant = _relaisId.text.trim()
      ..relaisMotDePasse = _relaisMdp.text
      ..codeGroupe = _code.text.trim()
      ..fonction = _fonction
      ..section = _section
      ..groupe = _groupe
      ..numEquipe = _equipeNum;
    await r.enregistrer();
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final titre = Theme.of(context).textTheme.titleMedium;
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
          const SizedBox(height: 24),
          Text('Ma place dans la compagnie', style: titre),
          DropdownButtonFormField<Fonction>(
            initialValue: _fonction,
            decoration: const InputDecoration(labelText: 'Ma fonction'),
            items: [
              for (final f in Fonction.values)
                DropdownMenuItem(value: f, child: Text(nomsFonctions[f]!)),
            ],
            onChanged: (v) => setState(() => _fonction = v!),
          ),
          Row(children: [
            if (_fonction.aSection)
              Expanded(
                  child: _numero(
                      'Section',
                      _section.clamp(1, 4),
                      {for (var i = 1; i <= 4; i++) i: 'CARMIN $i'},
                      (v) => setState(() => _section = v))),
            if (_fonction.aGroupe)
              Expanded(
                  child: _numero(
                      'Groupe',
                      _groupe.clamp(1, 3),
                      {
                        for (var i = 1; i <= 3; i++)
                          i: 'GOLF ${_section.clamp(1, 4)}$i'
                      },
                      (v) => setState(() => _groupe = v))),
            if (_fonction.aEquipe)
              Expanded(
                  child: _numero(
                      'Trinôme',
                      _equipeNum.clamp(1, 2),
                      const {1: 'A', 2: 'B'},
                      (v) => setState(() => _equipeNum = v))),
          ]),
          const SizedBox(height: 24),
          Text('Accès au partage', style: titre),
          ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _collerInvitation,
              icon: const Icon(Icons.content_paste),
              label: const Text('Coller une invitation'),
            ),
            TextField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'Code de la compagnie',
                helperMaxLines: 3,
                helperText: 'Le même sur tous les téléphones de la compagnie. '
                    'Il sert de clé de chiffrement : choisis-le long.',
              ),
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('Accès à la boîte aux lettres'),
              subtitle: Text(_relaisHote.text.isEmpty
                  ? 'À remplir une fois (ou via une invitation)'
                  : _relaisHote.text),
              tilePadding: EdgeInsets.zero,
              children: [
                TextField(
                  controller: _relaisHote,
                  decoration: const InputDecoration(
                      labelText: 'Adresse',
                      hintText: 'xxxx.s1.eu.hivemq.cloud'),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                ),
                TextField(
                  controller: _relaisPort,
                  decoration: const InputDecoration(labelText: 'Port'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: _relaisId,
                  decoration: const InputDecoration(labelText: 'Identifiant'),
                  autocorrect: false,
                ),
                TextField(
                  controller: _relaisMdp,
                  obscureText: !_voirAcces,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    suffixIcon: IconButton(
                      icon: Icon(
                          _voirAcces ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _voirAcces = !_voirAcces),
                    ),
                  ),
                  autocorrect: false,
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _copierInvitation,
              icon: const Icon(Icons.share),
              label: const Text('Copier une invitation pour la compagnie'),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _valider, child: const Text('Enregistrer')),
          const SizedBox(height: 12),
          Text('Identifiant de ce téléphone : ${r.uid}',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _numero(String titre, int valeur, Map<int, String> choix,
          ValueChanged<int> changer) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: DropdownButtonFormField<int>(
          key: ValueKey('$titre-${choix.values.join()}'),
          initialValue: valeur,
          isExpanded: true,
          decoration: InputDecoration(labelText: titre),
          items: [
            for (final e in choix.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => changer(v!),
        ),
      );
}

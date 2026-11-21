// Réglages de l'utilisateur, gardés dans le téléphone.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hierarchie.dart';

/// Attention : l'ordre compte (il est enregistré par numéro). Ajouter à la fin.
enum ModePartage { aucun, wifi, serveur, relais }

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
  String equipe;
  ModePartage mode;
  // Serveur TAK
  String hote;
  int port;
  // Boîte aux lettres 4G/5G
  String relaisHote;
  int relaisPort;
  String relaisIdentifiant;
  String relaisMotDePasse;
  String codeGroupe;
  // Place dans la compagnie
  Fonction fonction;
  int section, groupe, numEquipe;

  /// Niveau le plus détaillé que je veux voir (1 à 4), au choix du chef.
  int profondeur;

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
    required this.uid,
    required this.indicatif,
    required this.equipe,
    required this.mode,
    required this.hote,
    required this.port,
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
      equipe: p.getString('equipe') ?? 'Cyan',
      mode: ModePartage.values[p.getInt('mode') ?? ModePartage.relais.index],
      hote: p.getString('hote') ?? '',
      port: p.getInt('port') ?? 8087,
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
    );
  }

  Future<void> enregistrer() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('indicatif', indicatif);
    await p.setString('equipe', equipe);
    await p.setInt('mode', mode.index);
    await p.setString('hote', hote);
    await p.setInt('port', port);
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
  late final _hote = TextEditingController(text: r.hote);
  late final _port = TextEditingController(text: '${r.port}');
  late final _relaisHote = TextEditingController(text: r.relaisHote);
  late final _relaisPort = TextEditingController(text: '${r.relaisPort}');
  late final _relaisId = TextEditingController(text: r.relaisIdentifiant);
  late final _relaisMdp = TextEditingController(text: r.relaisMotDePasse);
  late final _code = TextEditingController(text: r.codeGroupe);
  late String _equipe = r.equipe;
  late ModePartage _mode = r.mode;
  late Fonction _fonction = r.fonction;
  late int _section = r.section, _groupe = r.groupe, _equipeNum = r.numEquipe;
  bool _voirAcces = false;

  @override
  void dispose() {
    for (final c in [
      _indicatif,
      _hote,
      _port,
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
      _info('Pas d\'invitation Mufasa dans le presse-papiers.');
      return;
    }
    setState(() {
      _mode = ModePartage.relais;
      _relaisHote.text = inv.hote;
      _relaisPort.text = '${inv.port}';
      _relaisId.text = inv.identifiant;
      _relaisMdp.text = inv.motDePasse;
      _code.text = inv.codeGroupe;
    });
    _info('Invitation reçue. Appuyez sur Enregistrer.');
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
        text: 'Rejoins le groupe Mufasa : ouvre Mufasa > Réglages > '
            '« Coller une invitation ».\n${inv.encoder()}'));
    _info('Invitation copiée. Envoyez-la par messagerie à votre groupe.');
  }

  Future<void> _valider() async {
    r
      ..indicatif =
          _indicatif.text.trim().isEmpty ? 'Sans nom' : _indicatif.text.trim()
      ..equipe = _equipe
      ..mode = _mode
      ..hote = _hote.text.trim()
      ..port = int.tryParse(_port.text.trim()) ?? 8087
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
                  child: _numero('Section', _section,
                      (v) => setState(() => _section = v))),
            if (_fonction.aGroupe)
              Expanded(
                  child: _numero(
                      'Groupe', _groupe, (v) => setState(() => _groupe = v))),
            if (_fonction.aEquipe)
              Expanded(
                  child: _numero('Équipe', _equipeNum,
                      (v) => setState(() => _equipeNum = v))),
          ]),
          const SizedBox(height: 24),
          Text('Partage des positions', style: titre),
          RadioGroup<ModePartage>(
            groupValue: _mode,
            onChanged: (v) => setState(() => _mode = v!),
            child: const Column(children: [
              RadioListTile(
                value: ModePartage.relais,
                title: Text('4G/5G'),
                subtitle: Text('Partout où il y a du réseau mobile. '
                    'Positions chiffrées avec le code de groupe.'),
              ),
              RadioListTile(
                value: ModePartage.wifi,
                title: Text('Sans réseau mobile (même Wi-Fi)'),
                subtitle: Text('Secours : tous les téléphones sur le même '
                    'Wi-Fi ou le même partage de connexion.'),
              ),
              RadioListTile(
                value: ModePartage.serveur,
                title: Text('Serveur TAK'),
                subtitle: Text('Pour se brancher sur un serveur TAK existant.'),
              ),
              RadioListTile(
                value: ModePartage.aucun,
                title: Text('Désactivé'),
              ),
            ]),
          ),
          if (_mode == ModePartage.relais) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _collerInvitation,
              icon: const Icon(Icons.content_paste),
              label: const Text('Coller une invitation'),
            ),
            TextField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'Code de groupe',
                helperMaxLines: 3,
                helperText: 'Le même sur tous les téléphones du groupe. '
                    'Il sert de clé de chiffrement : choisissez-le long.',
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
              label: const Text('Copier une invitation pour mon groupe'),
            ),
          ],
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
          Text('Identifiant de ce téléphone : ${r.uid}',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _numero(String titre, int valeur, ValueChanged<int> changer) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: DropdownButtonFormField<int>(
          initialValue: valeur,
          decoration: InputDecoration(labelText: titre),
          items: [
            for (var i = 1; i <= 6; i++)
              DropdownMenuItem(value: i, child: Text('$i')),
          ],
          onChanged: (v) => changer(v!),
        ),
      );
}

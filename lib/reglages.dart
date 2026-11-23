// Réglages de l'utilisateur, gardés dans le téléphone.
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hierarchie.dart';
import 'rejeu/rejeu_screen.dart';

/// Empreinte du code PIN administrateur (on ne garde jamais le code lui-même).
Future<String> empreintePin(String pin) async {
  final h = await Sha256().hash(utf8.encode('MUFASA-admin:${pin.trim()}'));
  return base64Url.encode(h.bytes);
}

/// Tout ce qu'il faut pour rejoindre la compagnie en 4G/5G, en un seul texte
/// à envoyer par messagerie : « MUFASA1:… ».
class Invitation {
  final String hote;
  final int port;
  final String identifiant;
  final String motDePasse;
  final String codeGroupe;

  /// Empreinte du code PIN administrateur (vide s'il n'y en a pas).
  final String admin;

  const Invitation({
    required this.hote,
    required this.port,
    required this.identifiant,
    required this.motDePasse,
    required this.codeGroupe,
    this.admin = '',
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
        if (admin.isNotEmpty) 'a': admin,
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
        admin: j['a'] as String? ?? '',
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

  /// Empreinte du code PIN administrateur ('' = pas encore créé).
  String pinAdmin;
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
    this.pinAdmin = '',
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
        admin: pinAdmin,
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
      pinAdmin: p.getString('pinAdmin') ?? '',
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
    await p.setString('pinAdmin', pinAdmin);
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

  /// Mode administrateur : seul moyen de voir et changer l'accès au partage.
  bool _admin = false;
  late String _pin = r.pinAdmin;

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
      if (inv.admin.isNotEmpty) _pin = inv.admin;
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
      admin: _pin,
    );
    await Clipboard.setData(ClipboardData(
        text: 'Rejoins MUFASA : ouvre MUFASA > Réglages > '
            '« Coller une invitation ».\n${inv.encoder()}'));
    _info('Invitation copiée. Envoie-la par messagerie à ta compagnie.');
  }

  Widget _etatAcces() {
    final pret = _relaisHote.text.trim().isNotEmpty &&
        _relaisId.text.trim().isNotEmpty &&
        _relaisMdp.text.isNotEmpty &&
        _code.text.trim().isNotEmpty;
    return Row(children: [
      Icon(pret ? Icons.check_circle : Icons.info_outline,
          color: pret ? Colors.green.shade700 : Colors.orange.shade800),
      const SizedBox(width: 8),
      Expanded(
        child: Text(pret
            ? 'Compagnie configurée'
            : 'Pas encore configuré : colle l\'invitation reçue par messagerie.'),
      ),
    ]);
  }

  /// Ouvre le mode administrateur : crée le code PIN la première fois,
  /// sinon le demande.
  Future<void> _ouvrirAdmin() async {
    final creation = _pin.isEmpty;
    final pin1 = TextEditingController(), pin2 = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.admin_panel_settings_outlined, size: 36),
        title: Text(creation
            ? 'Créer le code PIN administrateur'
            : 'Code PIN administrateur'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (creation)
            const Text('Ce code protège l\'accès au partage. Il sera '
                'demandé sur tous les téléphones qui reçoivent ton '
                'invitation. Garde-le pour toi.'),
          TextField(
            controller: pin1,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Code PIN (4 chiffres ou plus)'),
          ),
          if (creation)
            TextField(
              controller: pin2,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Confirme le code PIN'),
            ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Valider')),
        ],
      ),
    );
    final pin = pin1.text.trim();
    final confirmation = pin2.text.trim();
    pin1.dispose();
    pin2.dispose();
    if (ok != true || !mounted) return;
    if (creation) {
      if (pin.length < 4) {
        _info('Le code PIN doit faire au moins 4 chiffres.');
        return;
      }
      if (pin != confirmation) {
        _info('Les deux codes PIN ne sont pas identiques.');
        return;
      }
      final e = await empreintePin(pin);
      setState(() {
        _pin = e;
        _admin = true;
      });
      _info('Code PIN créé. Pense à appuyer sur Enregistrer.');
      return;
    }
    if (await empreintePin(pin) == _pin) {
      setState(() => _admin = true);
    } else {
      _info('Code PIN incorrect.');
    }
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
      ..pinAdmin = _pin
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
          const SizedBox(height: 8),
          _etatAcces(),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _collerInvitation,
            icon: const Icon(Icons.content_paste),
            label: const Text('Coller une invitation'),
          ),
          if (!_admin)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _ouvrirAdmin,
                icon: const Icon(Icons.lock_outline, size: 18),
                label: const Text('Mode administrateur'),
              ),
            )
          else ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.lock_open, size: 18),
              const SizedBox(width: 6),
              const Expanded(child: Text('Mode administrateur')),
              TextButton(
                onPressed: () => setState(() => _admin = false),
                child: const Text('Quitter'),
              ),
            ]),
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
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history),
              title: const Text('Rejeu des exercices'),
              subtitle: const Text('Enregistrer un exercice et le rejouer '
                  'pour le RETEX'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ExercicesScreen())),
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

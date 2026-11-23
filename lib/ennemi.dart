// Désignation d'un ennemi : la fiche que remplit celui qui l'a vu.
import 'package:flutter/material.dart';

import 'dessins.dart';

const naturesEnnemi = [
  'Infanterie',
  'Blindé',
  'Véhicule léger',
  'Tireur isolé',
  'Drone',
  'Inconnu',
];
const attitudesEnnemi = [
  'Statique',
  'En mouvement',
  'Défend',
  'Attaque',
  'Inconnue',
];

String heureCourte(DateTime d) {
  final l = d.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}h${l.minute.toString().padLeft(2, '0')}';
}

/// Ouvre la fiche. Renvoie les informations remplies, ou null si abandon.
Future<Map<String, String>?> remplirFicheEnnemi(
    BuildContext context, String observateur) {
  return Navigator.push<Map<String, String>>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _FicheEnnemi(observateur),
    ),
  );
}

class _FicheEnnemi extends StatefulWidget {
  final String observateur;
  const _FicheEnnemi(this.observateur);
  @override
  State<_FicheEnnemi> createState() => _FicheEnnemiEtat();
}

class _FicheEnnemiEtat extends State<_FicheEnnemi> {
  final _vu = DateTime.now();
  final _volume = TextEditingController();
  final _direction = TextEditingController();
  final _materiels = TextEditingController();
  final _remarques = TextEditingController();
  String _nature = 'Inconnu';
  String _attitude = 'Inconnue';
  String? _cap;

  @override
  void dispose() {
    for (final c in [_volume, _direction, _materiels, _remarques]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _choix(String titre, List<String> options, String valeur,
          ValueChanged<String> changer) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(titre, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final o in options)
                ChoiceChip(
                  label: Text(o),
                  selected: o == valeur,
                  onSelected: (_) => changer(o),
                ),
            ],
          ),
        ],
      );

  /// Rose des vents : vers où se dirige l'ennemi.
  Widget _boussole() {
    const grille = [
      ['NO', 'N', 'NE'],
      ['O', '', 'E'],
      ['SO', 'S', 'SE'],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('Il se dirige vers…',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Center(
          child: Column(children: [
            for (final ligne in grille)
              Row(mainAxisSize: MainAxisSize.min, children: [
                for (final c in ligne)
                  Padding(
                    padding: const EdgeInsets.all(3),
                    child: SizedBox(
                      width: 64,
                      height: 48,
                      child: c.isEmpty
                          ? const Icon(Icons.warning_amber, color: Colors.red)
                          : (c == _cap
                              ? FilledButton(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red.shade700,
                                      padding: EdgeInsets.zero),
                                  onPressed: () => setState(() => _cap = null),
                                  child: _fleche(c, Colors.white),
                                )
                              : OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.zero),
                                  onPressed: () => setState(() => _cap = c),
                                  child: _fleche(c, Colors.red.shade700),
                                )),
                    ),
                  ),
              ]),
          ]),
        ),
      ],
    );
  }

  Widget _fleche(String cap, Color couleur) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: capsEnnemi[cap]! * 3.14159265 / 180,
            child: Icon(Icons.arrow_upward, size: 18, color: couleur),
          ),
          Text(cap,
              style: TextStyle(color: couleur, fontWeight: FontWeight.bold)),
        ],
      );

  void _envoyer() {
    Navigator.pop(context, {
      'volume': _volume.text.trim(),
      'nature': _nature,
      'attitude': _attitude,
      if (_attitude == 'En mouvement' && _cap != null) 'cap': _cap!,
      'direction': _direction.text.trim(),
      'materiels': _materiels.text.trim(),
      'remarques': _remarques.text.trim(),
      'heure': heureCourte(_vu),
      'observateur': widget.observateur,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ennemi vu'),
        backgroundColor: Colors.red.shade100,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Vu à ${heureCourte(_vu)} par ${widget.observateur}'),
          TextField(
            controller: _volume,
            decoration: const InputDecoration(
                labelText: 'Volume', hintText: 'ex. 1 groupe, 3 hommes'),
          ),
          _choix('Nature', naturesEnnemi, _nature,
              (v) => setState(() => _nature = v)),
          _choix('Attitude', attitudesEnnemi, _attitude,
              (v) => setState(() => _attitude = v)),
          if (_attitude == 'En mouvement') _boussole(),
          TextField(
            controller: _direction,
            decoration: const InputDecoration(
                labelText: 'Direction / déplacement',
                hintText: 'ex. vers le nord, sur la route'),
          ),
          TextField(
            controller: _materiels,
            decoration: const InputDecoration(
                labelText: 'Matériels / armement',
                hintText: 'ex. 1 pick-up, armes légères'),
          ),
          TextField(
            controller: _remarques,
            decoration: const InputDecoration(labelText: 'Remarques'),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: _envoyer,
            icon: const Icon(Icons.send),
            label: const Text('Signaler à tout le monde'),
          ),
        ],
      ),
    );
  }
}

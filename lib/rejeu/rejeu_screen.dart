// Écrans du rejeu : liste des exercices enregistrés, et rejeu sur la carte.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../cartes/cartes_hors_ligne.dart';
import '../cartes/fonds.dart';
import '../graphiques.dart';
import '../hierarchie.dart';
import '../pions.dart';
import 'enregistrement.dart';
import 'rejeu.dart';
import 'stockage.dart';

String _deux(int v) => v.toString().padLeft(2, '0');
String _heure(DateTime t) {
  final l = t.toLocal();
  return '${_deux(l.hour)}:${_deux(l.minute)}:${_deux(l.second)}';
}

/// « exercice-20261123-1405.txt » → « Exercice du 23/11/2026 à 14h05 ».
String nomExercice(String fichier) {
  final m = RegExp(r'(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})').firstMatch(fichier);
  if (m == null) return fichier;
  return 'Exercice du ${m[3]}/${m[2]}/${m[1]} à ${m[4]}h${m[5]}';
}

class ExercicesScreen extends StatefulWidget {
  const ExercicesScreen({super.key});

  @override
  State<ExercicesScreen> createState() => _ExercicesScreenState();
}

class _ExercicesScreenState extends State<ExercicesScreen> {
  late Future<List<(String, int)>> _liste = listerExercices();

  void _recharger() => setState(() => _liste = listerExercices());

  Future<void> _basculer(bool v) async {
    if (v) {
      await enregistrement.demarrer();
    } else {
      await enregistrement.arreter();
    }
    _recharger();
  }

  Future<void> _effacer(String nom) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Effacer cet exercice ?'),
        content: Text('${nomExercice(nom)} sera supprimé de ce téléphone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Effacer')),
        ],
      ),
    );
    if (ok != true) return;
    if (enregistrement.nom == nom) await enregistrement.arreter();
    await effacerExercice(nom);
    _recharger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rejeu des exercices')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(Icons.fiber_manual_record,
                color: enregistrement.actif ? Colors.red : Colors.grey),
            title: const Text('Enregistrer l\'exercice'),
            subtitle: Text(enregistrement.actif
                ? 'En cours : positions, ennemis, points et dessins de '
                    'toute la compagnie sont enregistrés sur ce téléphone.'
                : 'À lancer au début de l\'exercice. Environ 1 Mo par heure.'),
            value: enregistrement.actif,
            onChanged: _basculer,
          ),
          const Divider(),
          Text('Exercices enregistrés',
              style: Theme.of(context).textTheme.titleMedium),
          FutureBuilder<List<(String, int)>>(
            future: _liste,
            builder: (_, s) {
              final l = s.data ?? const [];
              if (l.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Aucun exercice enregistré pour l\'instant.'),
                );
              }
              return Column(children: [
                for (final (nom, octets) in l)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history),
                    title: Text(nomExercice(nom)),
                    subtitle: Text('${(octets / 1e6).toStringAsFixed(1)} Mo'
                        '${enregistrement.nom == nom ? ' · en cours' : ''}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: 'Effacer',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _effacer(nom),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Rejouer'),
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => RejeuScreen(fichier: nom))),
                      ),
                    ]),
                  ),
              ]);
            },
          ),
        ],
      ),
    );
  }
}

class RejeuScreen extends StatefulWidget {
  final String fichier;
  const RejeuScreen({super.key, required this.fichier});

  @override
  State<RejeuScreen> createState() => _RejeuScreenState();
}

class _RejeuScreenState extends State<RejeuScreen> {
  Rejeu? _rejeu;
  late DateTime _t;
  bool _lecture = false;
  int _vitesse = 60;
  Timer? _minuterie;
  String? _choisi;
  final _carte = MapController();
  final _fond = fondsIgn.first;
  late final _tuiles = fournisseurTuiles(_fond.couche, _fond.extension);

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final r = Rejeu.depuisLignes(await lireExercice(widget.fichier));
    if (!mounted) return;
    setState(() {
      _rejeu = r;
      _t = r.debut;
    });
  }

  @override
  void dispose() {
    _minuterie?.cancel();
    super.dispose();
  }

  void _jouer() {
    final r = _rejeu!;
    if (!_t.isBefore(r.fin)) _t = r.debut;
    setState(() => _lecture = true);
    _minuterie?.cancel();
    _minuterie = Timer.periodic(const Duration(milliseconds: 200), (_) {
      setState(() {
        _t = _t.add(Duration(milliseconds: 200 * _vitesse));
        if (!_t.isBefore(r.fin)) {
          _t = r.fin;
          _pause();
        }
      });
    });
  }

  void _pause() {
    _minuterie?.cancel();
    _lecture = false;
  }

  @override
  Widget build(BuildContext context) {
    final r = _rejeu;
    return Scaffold(
      appBar: AppBar(title: Text(nomExercice(widget.fichier))),
      body: r == null
          ? const Center(child: CircularProgressIndicator())
          : r.vide
              ? const Center(child: Text('Cet exercice est vide.'))
              : Column(children: [
                  Expanded(child: _carteRejeu(r)),
                  _commandes(r),
                ]),
    );
  }

  Widget _carteRejeu(Rejeu r) {
    final points = r.tousLesPoints;
    final presents = [
      for (final uid in r.traces.keys)
        if (r.passageA(uid, _t) case final p?) (uid, p)
    ];
    final choisi = presents.where((e) => e.$1 == _choisi).firstOrNull;
    return FlutterMap(
      mapController: _carte,
      options: MapOptions(
        initialCameraFit: points.length > 1
            ? CameraFit.coordinates(
                coordinates: points, padding: const EdgeInsets.all(48))
            : null,
        initialCenter: points.isEmpty ? const LatLng(46.6, 2.4) : points.first,
        initialZoom: 15,
        backgroundColor: const Color(0xFFE0E0E0),
        interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        onTap: (_, __) => setState(() => _choisi = null),
      ),
      children: [
        TileLayer(
          urlTemplate: _fond.url,
          maxNativeZoom: _fond.zoomMax,
          userAgentPackageName: 'fr.cie6.mufasa',
          tileProvider: _tuiles,
        ),
        PolylineLayer(polylines: [
          for (final (uid, p) in presents)
            Polyline(
              points: [...r.traceA(uid, _t), p.point],
              color: couleurSection(p.place).withValues(alpha: 0.7),
              strokeWidth: 3,
            ),
        ]),
        CoucheDessins(dessins: r.dessinsA(_t), maintenant: _t),
        MarkerLayer(markers: [
          for (final (uid, p) in presents)
            Marker(
              point: p.point,
              width: p.place.fonction == Fonction.cdu ? 50 : 34,
              height: p.place.fonction == Fonction.cdu ? 58 : 34,
              child: GestureDetector(
                onTap: () => setState(() => _choisi = uid),
                child: Center(child: PionAmi(place: p.place)),
              ),
            ),
        ]),
        if (choisi != null)
          MarkerLayer(markers: [
            Marker(
              point: choisi.$2.point,
              width: 240,
              height: 70,
              alignment: const Alignment(0, -1.6),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bleuBulle,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 8)
                  ],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(choisi.$2.indicatif,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.black)),
                  Text(choisi.$2.place.description,
                      style: const TextStyle(color: Colors.black)),
                ]),
              ),
            ),
          ]),
      ],
    );
  }

  Widget _commandes(Rejeu r) {
    final total = r.fin.difference(r.debut).inSeconds.toDouble();
    final ecoule = _t.difference(r.debut).inSeconds.toDouble();
    return Material(
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(_heure(r.debut), style: const TextStyle(fontSize: 12)),
              Expanded(
                child: Center(
                  child: Text(_heure(_t),
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()])),
                ),
              ),
              Text(_heure(r.fin), style: const TextStyle(fontSize: 12)),
            ]),
            Slider(
              value: total <= 0 ? 0 : ecoule.clamp(0, total),
              max: total <= 0 ? 1 : total,
              onChanged: (v) => setState(
                  () => _t = r.debut.add(Duration(seconds: v.round()))),
            ),
            Row(children: [
              IconButton.filled(
                iconSize: 32,
                icon: Icon(_lecture ? Icons.pause : Icons.play_arrow),
                onPressed: () => _lecture ? setState(_pause) : _jouer(),
              ),
              const SizedBox(width: 12),
              const Text('Vitesse'),
              const SizedBox(width: 8),
              Expanded(
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 10, label: Text('×10')),
                    ButtonSegment(value: 60, label: Text('×60')),
                    ButtonSegment(value: 300, label: Text('×300')),
                  ],
                  selected: {_vitesse},
                  onSelectionChanged: (s) => setState(() => _vitesse = s.first),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

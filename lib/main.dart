// Mufasa – prototype : carte IGN, ma position, positions des camarades.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'dart:math';

import 'cot.dart';
import 'dessins.dart';
import 'graphiques.dart';
import 'outils_dessin.dart';
import 'partage.dart';
import 'reglages.dart';
import 'symboles.dart';

void main() => runApp(const MufasaApp());

class MufasaApp extends StatelessWidget {
  const MufasaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mufasa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF4B5320), // vert olive
        useMaterial3: true,
      ),
      home: const CarteScreen(),
    );
  }
}

/// Un fond de carte IGN (Géoplateforme, service WMTS gratuit sans clé).
class FondIgn {
  final String nom;
  final String couche;
  final String format;
  final int zoomMax;
  const FondIgn(this.nom, this.couche, this.format, this.zoomMax);

  String get url => 'https://data.geopf.fr/wmts?SERVICE=WMTS&REQUEST=GetTile'
      '&VERSION=1.0.0&LAYER=$couche&STYLE=normal&TILEMATRIXSET=PM'
      '&FORMAT=$format&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}';
}

const fondsIgn = [
  FondIgn('Plan IGN', 'GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2', 'image/png', 19),
  FondIgn('Photos aériennes', 'ORTHOIMAGERY.ORTHOPHOTOS', 'image/jpeg', 19),
];

class CarteScreen extends StatefulWidget {
  const CarteScreen({super.key});

  @override
  State<CarteScreen> createState() => _CarteScreenState();
}

class _CarteScreenState extends State<CarteScreen> {
  final _carte = MapController();
  FondIgn _fond = fondsIgn.first;
  LatLng? _maPosition;
  String? _message;
  StreamSubscription<Position>? _suivi;
  bool _premierePosition = true;
  final _partage = Partage();
  Reglages? _reglages;

  // Tracé en cours
  ChoixOutil? _outil;
  String _pion = '';
  bool _departAuto = false;
  Dessin? _aDeplacer;
  final _pointsTrace = <LatLng>[];
  String _dernierCalque = calqueParDefaut;

  @override
  void initState() {
    super.initState();
    _partage.addListener(_rafraichir);
    _partage.chargerDessins();
    _demarrerGeoloc();
    _demarrerPartage();
  }

  @override
  void dispose() {
    _suivi?.cancel();
    _partage.removeListener(_rafraichir);
    _partage.arreter();
    super.dispose();
  }

  void _rafraichir() {
    if (mounted) setState(() {});
  }

  Future<void> _demarrerPartage() async {
    _reglages = await Reglages.charger();
    await _partage.demarrer(_reglages!);
    // Au premier lancement, on demande l'indicatif.
    if (_reglages!.indicatif == 'Sans nom' && mounted) _ouvrirReglages();
  }

  Future<void> _ouvrirReglages() async {
    if (_reglages == null) return;
    final change = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ReglagesScreen(reglages: _reglages!)),
    );
    if (change == true) await _partage.demarrer(_reglages!);
  }

  Future<void> _demarrerGeoloc() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() => _message = 'Activez la localisation (GPS) du téléphone.');
      return;
    }
    var droit = await Geolocator.checkPermission();
    if (droit == LocationPermission.denied) {
      droit = await Geolocator.requestPermission();
    }
    if (droit == LocationPermission.denied ||
        droit == LocationPermission.deniedForever) {
      setState(() => _message = 'Mufasa a besoin de votre position.');
      return;
    }
    setState(() => _message = null);
    _suivi = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // mise à jour tous les 5 m
      ),
    ).listen((p) {
      final pos = LatLng(p.latitude, p.longitude);
      _partage.majPosition(p.latitude, p.longitude, p.accuracy);
      setState(() => _maPosition = pos);
      if (_premierePosition) {
        _premierePosition = false;
        _carte.move(pos, 15);
      }
    });
  }

  void _centrerSurMoi() {
    if (_maPosition != null) {
      _carte.move(_maPosition!, _carte.camera.zoom);
    } else {
      _demarrerGeoloc();
    }
  }

  // ----- Dessin -----

  bool get _enTrace => _outil != null;

  Future<void> _commencerTrace() async {
    final outil = await choisirOutil(context);
    if (outil == null || !mounted) return;
    var pion = '';
    final depart = <LatLng>[];
    final m = outil.mission;
    if (m != null) {
      final positions = <String, LatLng>{
        if (_reglages != null && _maPosition != null)
          _reglages!.indicatif: _maPosition!,
        for (final c in _partage.camarades.values)
          c.indicatif: LatLng(c.lat, c.lon),
        // Pions amis posés sur la carte (unités nommées).
        for (final d in _partage.dessins.values)
          if (d.forme == FormeDessin.symbole &&
              d.nom.isNotEmpty &&
              !estEnnemi(d.sidc) &&
              symboleDuCode(d.sidc)?.famille == FamilleSymbole.unite)
            d.nom: d.points.first,
      };
      final choisi = await choisirPion(context, m, positions.keys.toList());
      if (choisi == null || !mounted) return;
      pion = choisi;
      // Les flèches et secteurs partent du pion, si on connaît sa position.
      final pos = positions[pion];
      if (pos != null &&
          (m.trace == TraceMission.fleche || m.trace == TraceMission.secteur)) {
        depart.add(pos);
      }
    }
    setState(() {
      _outil = outil;
      _pion = pion;
      _departAuto = depart.isNotEmpty;
      _pointsTrace
        ..clear()
        ..addAll(depart);
    });
  }

  int get _pointsMini => switch (_outil?.forme) {
        FormeDessin.point || FormeDessin.symbole => 1,
        FormeDessin.ligne => 2,
        FormeDessin.zone => 3,
        FormeDessin.mission => _outil!.mission!.pointsMini,
        null => 1,
      };

  int? get _pointsMaxi => switch (_outil?.forme) {
        FormeDessin.point || FormeDessin.symbole => 1,
        FormeDessin.mission => _outil!.mission!.pointsMaxi,
        _ => null,
      };

  String get _consigne {
    final o = _outil!;
    final m = o.mission;
    if (m != null && _departAuto && _pointsTrace.isNotEmpty) {
      return m.trace == TraceMission.secteur
          ? 'Départ posé sur le pion. Touchez la première limite, puis la seconde.'
          : 'Départ posé sur le pion. Touchez le chemin jusqu\'à l\'objectif, puis Terminer.';
    }
    if (m != null) return m.consigne;
    return switch (o.forme) {
      FormeDessin.point => 'Touchez la carte pour placer le point.',
      FormeDessin.symbole =>
        'Touchez la carte pour poser : ${symboleDuCode(o.sidc)?.nom ?? 'symbole'}.',
      FormeDessin.ligne =>
        'Touchez la carte pour poser les points de la ligne.',
      _ => 'Touchez la carte pour poser les coins de la zone.',
    };
  }

  Dessin? get _brouillon {
    final o = _outil;
    if (o == null || _pointsTrace.isEmpty) return null;
    return Dessin(
      uid: 'brouillon',
      forme: o.forme,
      points: List.of(_pointsTrace),
      nom: '',
      couleur: Colors.blue,
      calque: '',
      auteur: '',
      auteurIndicatif: '',
      mission: o.mission?.code,
      pion: _pion,
    );
  }

  void _toucherCarte(TapPosition tap, LatLng point) {
    final aDeplacer = _aDeplacer;
    if (aDeplacer != null) {
      _partage.ajouterDessin(aDeplacer.deplace(point, par: aDeplacer.auteur));
      setState(() => _aDeplacer = null);
      return;
    }
    if (_enTrace) {
      setState(() => _pointsTrace.add(point));
      final maxi = _pointsMaxi;
      if (maxi != null && _pointsTrace.length >= maxi) _terminerTrace();
      return;
    }
    final d = dessinTouche(
        _carte.camera, _partage.dessinsVisibles, tap.relative ?? Offset.zero);
    if (d != null) _ouvrirFiche(d);
  }

  Future<void> _ouvrirFiche(Dessin d) async {
    final action = await ficheDessin(context, d);
    switch (action) {
      case ActionDessin.supprimer:
        _partage.supprimerDessin(d.uid);
      case ActionDessin.deplacer:
        setState(() => _aDeplacer = d);
      case null:
        break;
    }
  }

  void _abandonnerTrace() => setState(() {
        _outil = null;
        _pointsTrace.clear();
      });

  Future<void> _terminerTrace() async {
    final o = _outil;
    if (o == null || _pointsTrace.length < _pointsMini) return;
    final m = o.mission;
    final fin = await finaliserDessin(
      context,
      titre: m != null
          ? '${m.nom}${_pion.isEmpty ? '' : ' : $_pion'}'
          : switch (o.forme) {
              FormeDessin.symbole =>
                symboleDuCode(o.sidc)?.nom ?? 'Nouveau symbole',
              FormeDessin.point => 'Nouveau point',
              FormeDessin.ligne => 'Nouvelle ligne',
              _ => 'Nouvelle zone',
            },
      calques: _partage.calques,
      calqueSuggere: _partage.calques.contains(_dernierCalque)
          ? _dernierCalque
          : calqueParDefaut,
      couleurSuggeree: Colors.blue,
      nomFacultatif: m != null || o.forme == FormeDessin.symbole,
      avecCouleur: o.forme != FormeDessin.symbole,
      exempleNom: o.forme == FormeDessin.symbole ? 'ex. 1re SON, PC CIE' : null,
    );
    if (!mounted) return;
    if (fin == null) {
      _abandonnerTrace();
      return;
    }
    final r = Random.secure();
    _partage.ajouterDessin(Dessin(
      uid:
          'MUFASA-D-${List.generate(10, (_) => r.nextInt(16).toRadixString(16)).join()}',
      forme: o.forme,
      points: List.of(_pointsTrace),
      nom: fin.nom,
      couleur: fin.couleur,
      calque: fin.calque,
      auteur: _reglages?.uid ?? '',
      auteurIndicatif: _reglages?.indicatif ?? '',
      mission: m?.code,
      pion: _pion,
      sidc: o.sidc,
    ));
    _dernierCalque = fin.calque;
    _abandonnerTrace();
  }

  Future<void> _ouvrirCalques() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, maj) => SafeArea(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Fond de carte',
                      style: Theme.of(ctx).textTheme.titleMedium),
                ),
                RadioGroup<FondIgn>(
                  groupValue: _fond,
                  onChanged: (f) {
                    setState(() => _fond = f!);
                    maj(() {});
                  },
                  child: Column(children: [
                    for (final f in fondsIgn)
                      RadioListTile<FondIgn>(value: f, title: Text(f.nom)),
                  ]),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Calques',
                      style: Theme.of(ctx).textTheme.titleMedium),
                ),
                for (final c in _partage.calques)
                  SwitchListTile(
                    title: Text(c),
                    subtitle: Text(
                        '${_partage.dessins.values.where((d) => d.calque == c).length} dessin(s)'),
                    value: !_partage.calquesMasques.contains(c),
                    onChanged: (v) {
                      _partage.basculerCalque(c, v);
                      maj(() {});
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _barreTrace() {
    final n = _pointsTrace.length;
    return Material(
      elevation: 6,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Abandonner',
                icon: const Icon(Icons.close),
                onPressed: _abandonnerTrace,
              ),
              IconButton(
                tooltip: 'Retirer le dernier point',
                icon: const Icon(Icons.undo),
                onPressed:
                    n == 0 ? null : () => setState(_pointsTrace.removeLast),
              ),
              const Spacer(),
              Text('$n point(s)'),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: n >= _pointsMini ? _terminerTrace : null,
                child: const Text('Terminer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mufasa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Réglages',
            onPressed: _ouvrirReglages,
          ),
          IconButton(
            icon: const Icon(Icons.layers),
            tooltip: 'Fond de carte et calques',
            onPressed: _ouvrirCalques,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _carte,
            options: MapOptions(
              initialCenter: const LatLng(46.6, 2.4), // centre de la France
              initialZoom: 6,
              onTap: _toucherCarte,
              // Pas de rotation : le nord reste en haut.
              interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            ),
            children: [
              TileLayer(
                urlTemplate: _fond.url,
                maxNativeZoom: _fond.zoomMax,
                userAgentPackageName: 'fr.cie6.mufasa',
              ),
              CoucheDessins(
                dessins: _partage.dessinsVisibles.toList(),
                brouillon: _brouillon,
              ),
              coucheSymboles(_partage.dessinsVisibles),
              MarkerLayer(markers: [
                for (final c in _partage.camarades.values) _marqueurCamarade(c),
              ]),
              if (_maPosition != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _maPosition!,
                    width: 26,
                    height: 26,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(blurRadius: 4, color: Colors.black38)
                        ],
                      ),
                    ),
                  ),
                ]),
              const RichAttributionWidget(
                attributions: [TextSourceAttribution('© IGN – Géoplateforme')],
              ),
            ],
          ),
          if (!_enTrace)
            Positioned(left: 12, bottom: 24, child: _bandeauPartage()),
          if (_aDeplacer != null)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Material(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                elevation: 2,
                child: ListTile(
                  title: const Text('Touchez le nouvel emplacement.'),
                  trailing: TextButton(
                    onPressed: () => setState(() => _aDeplacer = null),
                    child: const Text('Annuler'),
                  ),
                ),
              ),
            ),
          if (_enTrace)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Material(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '${_outil!.mission?.nom ?? ''}${_pion.isEmpty ? '' : ' ($_pion)'}'
                    '${_outil!.mission == null ? '' : '\n'}$_consigne',
                  ),
                ),
              ),
            ),
          if (_message != null)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Material(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_message!),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _enTrace ? _barreTrace() : null,
      floatingActionButton: _enTrace
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'dessiner',
                  onPressed: _commencerTrace,
                  tooltip: 'Dessiner / mission',
                  child: const Icon(Icons.edit),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'centrer',
                  onPressed: _centrerSurMoi,
                  tooltip: 'Me centrer',
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
    );
  }

  Marker _marqueurCamarade(CotEvenement c) {
    final couleur = c.estPerime ? Colors.grey : couleurEquipe(c.equipe);
    return Marker(
      point: LatLng(c.lat, c.lon),
      width: 120,
      height: 52,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: couleur,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.black87, width: 2),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              c.indicatif,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: c.estPerime ? Colors.grey : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bandeauPartage() {
    final l = _partage.liaison;
    final texte = l == null
        ? (_partage.avertissement ?? 'Partage désactivé')
        : '${l.nom} : ${l.etat.value} · ${_partage.camarades.length} camarade(s)';
    return Material(
      color: Colors.black.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _ouvrirReglages,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(texte,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ),
    );
  }
}

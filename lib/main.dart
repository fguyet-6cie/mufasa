// Mufasa – prototype : carte IGN, ma position, positions des camarades.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'cot.dart';
import 'partage.dart';
import 'reglages.dart';

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

  @override
  void initState() {
    super.initState();
    _partage.addListener(_rafraichir);
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
          PopupMenuButton<FondIgn>(
            icon: const Icon(Icons.layers),
            tooltip: 'Fond de carte',
            onSelected: (f) => setState(() => _fond = f),
            itemBuilder: (_) => [
              for (final f in fondsIgn)
                CheckedPopupMenuItem(
                    value: f, checked: f == _fond, child: Text(f.nom)),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _carte,
            options: const MapOptions(
              initialCenter: LatLng(46.6, 2.4), // centre de la France
              initialZoom: 6,
            ),
            children: [
              TileLayer(
                urlTemplate: _fond.url,
                maxNativeZoom: _fond.zoomMax,
                userAgentPackageName: 'fr.cie6.mufasa',
              ),
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
          Positioned(left: 12, bottom: 24, child: _bandeauPartage()),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _centrerSurMoi,
        tooltip: 'Me centrer',
        child: const Icon(Icons.my_location),
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

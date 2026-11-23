// Mufasa – prototype : carte IGN, ma position, positions des camarades.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'dart:math';

import 'accueil.dart';
import 'cot.dart';
import 'dessins.dart';
import 'ennemi.dart';
import 'graphiques.dart';
import 'hierarchie.dart';
import 'cartes/cartes_hors_ligne.dart';
import 'mgrs.dart';
import 'mode_nuit.dart';
import 'notifications.dart';
import 'outils_dessin.dart';
import 'partage.dart';
import 'pions.dart';
import 'reglages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await preparerCartes();
  await chargerModeNuit();
  runApp(const MufasaApp());
}

class MufasaApp extends StatefulWidget {
  const MufasaApp({super.key});

  @override
  State<MufasaApp> createState() => _MufasaAppState();
}

class _MufasaAppState extends State<MufasaApp> {
  bool _accueil = true;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: modeNuit,
      builder: (context, nuit, _) => _app(nuit),
    );
  }

  Widget _app(bool nuit) {
    return MaterialApp(
      title: 'MUFASA',
      themeMode: nuit ? ThemeMode.dark : ThemeMode.light,
      darkTheme: themeNuit,
      builder: (context, enfant) => voileNuit(enfant!),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: CouleursCie.carmin,
          primary: CouleursCie.carmin,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: CouleursCie.carmin,
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _accueil
            ? AccueilScreen(onEntrer: () => setState(() => _accueil = false))
            : CarteScreen(onEfface: () => setState(() => _accueil = true)),
      ),
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

  String get extension => format == 'image/png' ? 'png' : 'jpg';

  String urlTuile(int z, int x, int y) => url
      .replaceAll('{z}', '$z')
      .replaceAll('{x}', '$x')
      .replaceAll('{y}', '$y');

  String get url => 'https://data.geopf.fr/wmts?SERVICE=WMTS&REQUEST=GetTile'
      '&VERSION=1.0.0&LAYER=$couche&STYLE=normal&TILEMATRIXSET=PM'
      '&FORMAT=$format&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}';
}

const fondsIgn = [
  FondIgn('Plan IGN', 'GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2', 'image/png', 19),
  FondIgn('Photos aériennes', 'ORTHOIMAGERY.ORTHOPHOTOS', 'image/jpeg', 19),
];

class CarteScreen extends StatefulWidget {
  /// Appelé après un effacement d'urgence : retour à l'écran d'accueil.
  final VoidCallback? onEfface;
  const CarteScreen({super.key, this.onEfface});

  @override
  State<CarteScreen> createState() => _CarteScreenState();
}

class _CarteScreenState extends State<CarteScreen> {
  final _carte = MapController();
  FondIgn _fond = fondsIgn.first;
  final _fournisseurs = <String, TileProvider>{};
  LatLng? _maPosition;
  String? _message;
  StreamSubscription<Position>? _suivi;
  bool _premierePosition = true;
  final _partage = Partage();
  Reglages? _reglages;

  // Tracé en cours
  FormeDessin? _outil;
  Dessin? _aDeplacer;

  /// Ennemi dont on indique la nouvelle place (« Il a bougé »).
  Dessin? _ennemiABouger;

  /// Ami dont la bulle est ouverte.
  String? _bulle;

  /// Mon sens de marche (degrés), null si je ne bouge pas.
  double? _monCap;

  /// Direction vers laquelle pointe le téléphone (boussole), en degrés.
  double? _boussole;
  StreamSubscription<CompassEvent>? _suiviBoussole;

  /// Vrai quand l'appli n'est pas à l'écran (écran éteint, autre appli).
  bool _enArrierePlan = false;
  late final AppLifecycleListener _cycle;
  bool _designation = false;
  StreamSubscription<Dessin>? _alertes;
  final _pointsTrace = <LatLng>[];

  @override
  void initState() {
    super.initState();
    _partage.addListener(_rafraichir);
    _partage.chargerDessins();
    _alertes = _partage.nouveauxEnnemis.listen(_alerteEnnemi);
    _cycle = AppLifecycleListener(onStateChange: _changementEtat);
    _demarrer();
    // Alerte de mise à jour désactivée : le dépôt GitHub est privé.
    // WidgetsBinding.instance
    //     .addPostFrameCallback((_) => proposerMiseAJour(context));
  }

  @override
  void dispose() {
    _suivi?.cancel();
    _suiviBoussole?.cancel();
    _minuterieBatterie?.cancel();
    _cycle.dispose();
    _alertes?.cancel();
    _partage.removeListener(_rafraichir);
    _partage.arreter();
    super.dispose();
  }

  Timer? _minuterieBatterie;

  /// Lit le niveau de batterie maintenant puis toutes les 5 minutes.
  void _suivreBatterie() {
    if (kIsWeb) return;
    Future<void> lire() async {
      try {
        _partage.batterie = await Battery().batteryLevel;
      } catch (_) {}
    }

    lire();
    _minuterieBatterie =
        Timer.periodic(const Duration(minutes: 5), (_) => lire());
  }

  Future<void> _demarrer() async {
    _suivreBatterie();
    await _demarrerPartage();
    if (mounted) await expliquerAutorisations(context);
    await initialiserNotifications();
    await _demarrerGeoloc();
    _demarrerBoussole();
  }

  /// Écran éteint : on coupe la boussole (inutile) pour économiser la batterie.
  void _changementEtat(AppLifecycleState e) {
    final arriere = e != AppLifecycleState.resumed;
    if (arriere == _enArrierePlan) return;
    _enArrierePlan = arriere;
    if (arriere) {
      _suiviBoussole?.cancel();
      _suiviBoussole = null;
    } else {
      _demarrerBoussole();
    }
  }

  /// La flèche « moi » suit la boussole du téléphone quand on est arrêté.
  void _demarrerBoussole() {
    if (kIsWeb || _suiviBoussole != null) return;
    _suiviBoussole = FlutterCompass.events?.listen((e) {
      final h = e.heading;
      if (h == null) return;
      final avant = _boussole;
      // On ne redessine que si l'écart dépasse 3°.
      if (avant == null || ((h - avant + 540) % 360 - 180).abs() > 3) {
        setState(() => _boussole = h);
      }
    }, onError: (_) {});
  }

  void _rafraichir() {
    if (mounted) setState(() {});
  }

  Future<void> _demarrerPartage() async {
    _reglages = await Reglages.charger();
    await _partage.demarrer(_reglages!);
    // Au premier lancement, on demande l'indicatif.
    if (_reglages!.indicatif == 'Sans nom' && mounted) await _ouvrirReglages();
  }

  Future<void> _ouvrirReglages() async {
    if (_reglages == null) return;
    final change = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ReglagesScreen(reglages: _reglages!)),
    );
    if (change == true) await _partage.demarrer(_reglages!);
  }

  /// Réglages du GPS : économes, et actifs même écran éteint (notification
  /// permanente sur Android, pastille bleue sur iPhone).
  static LocationSettings reglagesGps() {
    const metres = 10; // nouvelle position seulement après 10 m
    if (kIsWeb) {
      return const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: metres);
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: metres,
          intervalDuration: const Duration(seconds: 10),
          foregroundNotificationConfig: ForegroundNotificationConfig(
            notificationTitle: 'MUFASA',
            notificationText: 'MUFASA partage ta position',
            notificationChannelName: 'Partage de position',
            setOngoing: true,
            // Garde le téléphone éveillé juste assez pour envoyer la position
            // et recevoir les alertes écran éteint.
            enableWakeLock: true,
          ),
        ),
      TargetPlatform.iOS => AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: metres,
          activityType: ActivityType.fitness,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        ),
      _ => const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: metres),
    };
  }

  Future<void> _demarrerGeoloc() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() => _message = 'Active la localisation (GPS) du téléphone.');
      return;
    }
    var droit = await Geolocator.checkPermission();
    if (droit == LocationPermission.denied) {
      droit = await Geolocator.requestPermission();
    }
    if (droit == LocationPermission.denied ||
        droit == LocationPermission.deniedForever) {
      setState(() => _message = 'MUFASA a besoin de ta position.');
      return;
    }
    setState(() => _message = null);
    _suivi = Geolocator.getPositionStream(
      locationSettings: reglagesGps(),
    ).listen((p) {
      final pos = LatLng(p.latitude, p.longitude);
      _partage.majPosition(p.latitude, p.longitude, p.accuracy);
      setState(() {
        _maPosition = pos;
        if (p.speed > 0.7 && p.heading >= 0) {
          _monCap = p.heading;
        } else if (p.speed >= 0 && p.speed < 0.3) {
          _monCap = null;
        }
      });
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

  // ----- Effacement d'urgence -----

  Future<void> _effacementUrgence() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_forever, size: 44, color: Colors.red.shade700),
        title: const Text('Effacement d\'urgence'),
        content: const Text('Tout effacer de ce téléphone ?\n\n'
            '• positions, ennemis, points et dessins reçus ;\n'
            '• réglages, code de la compagnie et accès au réseau.\n\n'
            'Le partage s\'arrête aussitôt. Les autres téléphones ne sont '
            'pas touchés. Impossible d\'annuler.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever),
            label: const Text('TOUT EFFACER'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _suivi?.cancel();
    _suivi = null;
    await _partage.toutEffacer();
    await effacerCartes();
    await changerModeNuit(false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Toutes les données de MUFASA ont été effacées.')));
    widget.onEfface?.call();
  }

  // ----- Dessin -----

  bool get _enTrace => _outil != null;

  Future<void> _commencerTrace() async {
    final outil = await choisirOutil(context);
    if (outil == null || !mounted) return;
    setState(() {
      _outil = outil;
      _pointsTrace.clear();
    });
  }

  int get _pointsMini => switch (_outil) {
        FormeDessin.ligne => 2,
        FormeDessin.zone => 3,
        _ => 1,
      };

  int? get _pointsMaxi => _outil == FormeDessin.point ? 1 : null;

  String get _consigne => switch (_outil) {
        FormeDessin.point =>
          'Touche la carte pour placer le point particulier.',
        FormeDessin.ligne =>
          'Touche la carte pour poser les points de la ligne.',
        _ => 'Touche la carte pour poser les coins de la zone.',
      };

  Dessin? get _brouillon {
    final o = _outil;
    if (o == null || _pointsTrace.isEmpty) return null;
    return Dessin(
      uid: 'brouillon',
      forme: o,
      points: List.of(_pointsTrace),
      nom: '',
      couleur: Colors.blue,
      auteur: '',
      auteurIndicatif: '',
    );
  }

  // ----- Désignation d'un ennemi -----

  void _alerteEnnemi(Dessin d) {
    if (_enArrierePlan) {
      final f = d.fiche;
      final quoi = [f['volume'], f['nature']]
          .where((t) => t != null && t.isNotEmpty)
          .join(' · ');
      final ou = _maPosition == null
          ? ''
          : ' à ${const Distance()(_maPosition!, d.points.first).round()} m';
      notifierEnnemi('Ennemi signalé$ou',
          '${quoi.isEmpty ? '' : '$quoi, '}par ${f['observateur'] ?? d.auteurIndicatif}');
    }
    if (!mounted) return;
    // Courte vibration, jamais de son.
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Colors.red.shade800,
      duration: const Duration(seconds: 10),
      content: Text(
          'Ennemi signalé par ${d.fiche['observateur'] ?? d.auteurIndicatif}'),
      action: SnackBarAction(
        label: 'VOIR',
        textColor: Colors.white,
        onPressed: () {
          _carte.move(d.points.first,
              _carte.camera.zoom < 15 ? 15 : _carte.camera.zoom);
          _ouvrirFiche(d);
        },
      ),
    ));
  }

  String get _moi => _reglages?.indicatif ?? 'Inconnu';
  String get _monUid => _reglages?.uid ?? '';

  Future<void> _signalerEnnemi(LatLng ou) async {
    setState(() => _designation = false);
    // Un ennemi est déjà connu tout près : est-ce le même ?
    final proche = ennemiProche(_partage.dessins.values, ou);
    if (proche != null) {
      final m = const Distance()(proche.points.first, ou).round();
      final f = proche.fiche;
      final resume = [f['volume'], f['nature']]
          .where((t) => t != null && t.isNotEmpty)
          .join(' · ');
      final meme = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Même ennemi ?'),
          content: Text('Un ennemi a déjà été signalé à $m m d\'ici :\n'
              '${resume.isEmpty ? 'sans détail' : resume}, par '
              '${f['observateur'] ?? proche.auteurIndicatif} à ${f['heure'] ?? '?'}.'
              '\n\nEst-ce le même ?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Non, un autre')),
            FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Oui, le mettre à jour'),
            ),
          ],
        ),
      );
      if (meme == null || !mounted) return;
      if (meme) {
        final fiche = await remplirFicheEnnemi(context, _moi, depart: f);
        if (fiche == null || !mounted) return;
        _partage.ajouterDessin(
            proche.aBouge(ou, par: _moi, parUid: _monUid, fiche: fiche));
        return;
      }
    }
    final fiche = await remplirFicheEnnemi(context, _moi);
    if (fiche == null || !mounted) return;
    final r = Random.secure();
    _partage.ajouterDessin(Dessin(
      uid:
          'MUFASA-E-${List.generate(10, (_) => r.nextInt(16).toRadixString(16)).join()}',
      forme: FormeDessin.ennemi,
      points: [ou],
      nom: '',
      couleur: Colors.red.shade700,
      auteur: _reglages?.uid ?? '',
      auteurIndicatif: _reglages?.indicatif ?? '',
      fiche: fiche,
    ));
  }

  void _toucherCarte(TapPosition tap, LatLng point) {
    if (_bulle != null) {
      setState(() => _bulle = null);
      return;
    }
    final aBouger = _ennemiABouger;
    if (aBouger != null) {
      _partage.ajouterDessin(aBouger.aBouge(point, par: _moi, parUid: _monUid));
      setState(() => _ennemiABouger = null);
      return;
    }
    if (_designation) {
      _signalerEnnemi(point);
      return;
    }
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
        _carte.camera, _dessinsAffiches, tap.relative ?? Offset.zero);
    if (d != null) _ouvrirFiche(d);
  }

  Future<void> _ouvrirFiche(Dessin d) async {
    final action = await ficheDessin(context, d);
    switch (action) {
      case ActionDessin.supprimer:
        if (!mounted) return;
        if (await confirmerSuppression(context, d) && mounted) {
          _partage.supprimerDessin(d.uid);
        }
      case ActionDessin.deplacer:
        setState(() => _aDeplacer = d);
      case ActionDessin.toujoursLa:
        _partage.ajouterDessin(d.toujoursLa(par: _moi, parUid: _monUid));
      case ActionDessin.aBouge:
        setState(() => _ennemiABouger = d);
      case ActionDessin.plusLa:
        _partage.ajouterDessin(d.plusLa(par: _moi, parUid: _monUid));
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
    final fin = await finaliserDessin(
      context,
      titre: switch (o) {
        FormeDessin.point => 'Point particulier',
        FormeDessin.ligne => 'Nouvelle ligne',
        _ => 'Nouvelle zone',
      },
      couleurSuggeree:
          o == FormeDessin.point ? const Color(0xFFEF6C00) : Colors.blue,
      avecObservations: o == FormeDessin.point,
      avecCouleur: o != FormeDessin.point,
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
      forme: o,
      points: List.of(_pointsTrace),
      nom: fin.nom,
      couleur: fin.couleur,
      auteur: _reglages?.uid ?? '',
      auteurIndicatif: _reglages?.indicatif ?? '',
      fiche: {
        if (fin.observations.isNotEmpty) 'observations': fin.observations
      },
    ));
    _abandonnerTrace();
  }

  /// Télécharge la zone affichée, du zoom 10 au zoom 17, pour le fond choisi.
  Future<void> _telechargerZone() async {
    final b = _carte.camera.visibleBounds;
    final no = b.northWest, se = b.southEast;
    final fond = _fond;
    const zMin = 10, zMax = 17;
    final nombre = compterTuiles(no, se, zMin, zMax);
    if (nombre > 25000) {
      _info('Zone trop grande : zoome davantage avant de télécharger.');
      return;
    }
    final mo = (nombre * (fond.extension == 'png' ? 0.02 : 0.03)).ceil();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.download, size: 36),
        title: const Text('Télécharger la zone ?'),
        content: Text('Fond : ${fond.nom}\n'
            'Environ $mo Mo ($nombre morceaux de carte).\n\n'
            'De préférence en Wi-Fi. Tu pourras ensuite voir cette zone '
            'sans réseau, jusqu\'au niveau de détail d\'une rue.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Télécharger')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final faites = ValueNotifier<int>(0);
    var annule = false;
    final fenetre = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Téléchargement des cartes'),
        content: ValueListenableBuilder<int>(
          valueListenable: faites,
          builder: (_, n, __) =>
              Column(mainAxisSize: MainAxisSize.min, children: [
            LinearProgressIndicator(value: n / nombre),
            const SizedBox(height: 8),
            Text('$n / $nombre'),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () {
                annule = true;
                Navigator.pop(ctx);
              },
              child: const Text('Arrêter')),
        ],
      ),
    );
    final echecs = await telechargerTuiles(
      couche: fond.couche,
      extension: fond.extension,
      url: fond.urlTuile,
      tuiles: tuilesZone(no, se, zMin, zMax),
      progression: (n) => faites.value = n,
      annule: () => annule,
    );
    if (!annule && mounted) Navigator.of(context).pop();
    await fenetre;
    faites.dispose();
    if (!mounted) return;
    _info(annule
        ? 'Téléchargement arrêté. Ce qui est déjà téléchargé est gardé.'
        : echecs == 0
            ? 'Zone téléchargée : visible sans réseau.'
            : 'Zone téléchargée, sauf $echecs morceaux (réseau ?). '
                'Relance pour compléter.');
  }

  void _info(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  Future<void> _ouvrirAffichage() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, maj) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_reglages != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Ce que je vois',
                          style: Theme.of(ctx).textTheme.titleMedium),
                    ),
                    RadioGroup<Perimetre>(
                      groupValue: _reglages!.perimetre,
                      onChanged: (v) async {
                        await _partage.choisirAffichage(perimetre: v);
                        maj(() {});
                      },
                      child: Column(children: [
                        for (final e in nomsPerimetres.entries)
                          RadioListTile<Perimetre>(
                              dense: true, value: e.key, title: Text(e.value)),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Jusqu\'à',
                          style: Theme.of(ctx).textTheme.titleMedium),
                    ),
                    RadioGroup<int>(
                      groupValue: _reglages!.profondeur >= 3
                          ? 4
                          : _reglages!.profondeur.clamp(1, 2),
                      onChanged: (v) async {
                        await _partage.choisirAffichage(profondeur: v);
                        maj(() {});
                      },
                      child: Column(children: [
                        for (final e in nomsNiveaux.entries)
                          RadioListTile<int>(
                              dense: true, value: e.key, title: Text(e.value)),
                      ]),
                    ),
                    SwitchListTile(
                      dense: true,
                      title: const Text(
                          'Ennemis anciens (plus de 30 min) et disparus'),
                      value: _reglages!.ennemisAnciens,
                      onChanged: (v) async {
                        await _partage.choisirAffichage(ennemisAnciens: v);
                        maj(() {});
                      },
                    ),
                    const Divider(),
                  ],
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
                  SwitchListTile(
                    secondary: const Icon(Icons.dark_mode_outlined),
                    title: const Text('Mode nuit'),
                    subtitle: const Text('Écran sombre et rouge, discret'),
                    value: modeNuit.value,
                    onChanged: (v) async {
                      await changerModeNuit(v);
                      if (mounted) setState(() {});
                      maj(() {});
                    },
                  ),
                  if (cartesHorsLigneDisponibles) ...[
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Cartes hors ligne',
                          style: Theme.of(ctx).textTheme.titleMedium),
                    ),
                    FutureBuilder<int>(
                      future: tailleCartes(),
                      builder: (_, t) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.sd_storage_outlined),
                        title: Text(t.hasData
                            ? '${(t.data! / 1e6).toStringAsFixed(0)} Mo de cartes gardées dans le téléphone'
                            : '…'),
                        subtitle: const Text(
                            'Les cartes vues ou téléchargées restent '
                            'visibles sans réseau.'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(spacing: 8, children: [
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _telechargerZone();
                          },
                          icon: const Icon(Icons.download),
                          label: const Text('Télécharger la zone affichée'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await effacerCartes();
                            maj(() {});
                          },
                          child: const Text('Effacer les cartes'),
                        ),
                      ]),
                    ),
                  ],
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Qui est qui ?',
                            style: Theme.of(ctx).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        const Legende(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Demande des coordonnées MGRS (ex. reçues à la radio) et centre la carte
  /// dessus. Renvoie la position, ou null.
  Future<LatLng?> _saisirMgrs() async {
    final champ = TextEditingController();
    String? erreur;
    final r = await showDialog<LatLng>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, maj) {
          void valider() {
            final p = depuisMgrs(champ.text);
            if (p == null) {
              maj(() => erreur = 'Coordonnées non reconnues');
            } else {
              Navigator.pop(ctx, LatLng(p.$1, p.$2));
            }
          }

          return AlertDialog(
            title: const Text('Coordonnées MGRS'),
            content: TextField(
              controller: champ,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 18),
              decoration: InputDecoration(
                hintText: '31U DQ 48251 11943',
                helperText: 'De 2 à 10 chiffres après les lettres',
                errorText: erreur,
              ),
              onSubmitted: (_) => valider(),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler')),
              FilledButton(onPressed: valider, child: const Text('Placer')),
            ],
          );
        },
      ),
    );
    champ.dispose();
    if (r != null) {
      _carte.move(r, _carte.camera.zoom < 14 ? 14 : _carte.camera.zoom);
    }
    return r;
  }

  Future<void> _ajouterPointMgrs() async {
    final p = await _saisirMgrs();
    if (p == null || !mounted || !_enTrace) return;
    setState(() => _pointsTrace.add(p));
    final maxi = _pointsMaxi;
    if (maxi != null && _pointsTrace.length >= maxi) _terminerTrace();
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
              TextButton(
                onPressed: _ajouterPointMgrs,
                child: const Text('MGRS'),
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
        title: Row(children: [
          Image.asset('assets/images/insigne_6cie.png', height: 32),
          const SizedBox(width: 10),
          const Text('MUFASA',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        ]),
        flexibleSpace: const Align(
          alignment: Alignment.bottomCenter,
          child: Row(children: [
            Expanded(
                child: SizedBox(
                    height: 3,
                    child: ColoredBox(color: CouleursCie.bleuMarine))),
            Expanded(
                child: SizedBox(
                    height: 3,
                    child: ColoredBox(color: CouleursCie.rougeMarine))),
          ]),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Effacement d\'urgence',
            onPressed: _effacementUrgence,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Réglages',
            onPressed: _ouvrirReglages,
          ),
          IconButton(
            icon: const Icon(Icons.layers),
            tooltip: 'Fond de carte et niveaux',
            onPressed: _ouvrirAffichage,
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
                tileProvider: _fournisseurs.putIfAbsent(_fond.couche,
                    () => fournisseurTuiles(_fond.couche, _fond.extension)),
                tileBuilder: modeNuit.value
                    ? (context, tuile, _) => ColorFiltered(
                        colorFilter: filtreCarteNuit, child: tuile)
                    : null,
              ),
              CoucheDessins(
                dessins: _dessinsAffiches.toList(),
                brouillon: _brouillon,
              ),
              MarkerLayer(markers: [
                for (final c in _partage.camaradesVisibles)
                  _marqueurCamarade(c),
              ]),
              if (_maPosition != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _maPosition!,
                    width: 40,
                    height: 40,
                    child: FlecheMoi(cap: _monCap ?? _boussole),
                  ),
                ]),
              if (_camaradeBulle case final c?)
                MarkerLayer(markers: [
                  Marker(
                    point: LatLng(c.lat, c.lon),
                    width: 260,
                    height: 150,
                    // La pointe de la bulle tombe juste au-dessus du pion.
                    alignment: const Alignment(0, -1.05),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: BulleAmi(
                            c: c,
                            onFermer: () => setState(() => _bulle = null)),
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
          if (_designation)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Material(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Touche la carte là où se trouve l\'ennemi.'),
                      Wrap(spacing: 8, children: [
                        if (_maPosition != null)
                          TextButton(
                            onPressed: () => _signalerEnnemi(_maPosition!),
                            child: const Text('Il est sur ma position'),
                          ),
                        TextButton(
                          onPressed: () async {
                            final p = await _saisirMgrs();
                            if (p != null && _designation) _signalerEnnemi(p);
                          },
                          child: const Text('Saisir MGRS'),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _designation = false),
                          child: const Text('Annuler'),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          if (_ennemiABouger != null)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Material(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                elevation: 2,
                child: ListTile(
                  title: const Text('Touche la nouvelle place de l\'ennemi.'),
                  trailing: TextButton(
                    onPressed: () => setState(() => _ennemiABouger = null),
                    child: const Text('Annuler'),
                  ),
                ),
              ),
            ),
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
                  title: const Text('Touche le nouvel emplacement.'),
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
                  child: Text(_consigne),
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
                FloatingActionButton.extended(
                  heroTag: 'ennemi',
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  onPressed: () => setState(() => _designation = true),
                  icon: const Icon(Icons.warning_amber),
                  label: const Text('Ennemi'),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'dessiner',
                  onPressed: _commencerTrace,
                  tooltip: 'Point particulier ou dessin',
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

  /// Dessins affichés : on peut masquer les ennemis anciens ou disparus.
  Iterable<Dessin> get _dessinsAffiches {
    final anciens = _reglages?.ennemisAnciens ?? true;
    return _partage.dessins.values
        .where((d) => anciens || !(d.estAncien || d.disparu));
  }

  CotEvenement? get _camaradeBulle =>
      _bulle == null ? null : _partage.camarades[_bulle];

  Marker _marqueurCamarade(CotEvenement c) {
    final cdu = c.place.fonction == Fonction.cdu;
    return Marker(
      point: LatLng(c.lat, c.lon),
      width: cdu ? 50 : 34,
      height: cdu ? 58 : 34,
      child: GestureDetector(
        onTap: () => setState(() => _bulle = _bulle == c.uid ? null : c.uid),
        child: Center(
          child: PionAmi(
            place: c.place,
            monGroupe: _partage.estDeMonGroupe(c),
            monTrinome: _partage.estDeMonTrinome(c),
            perime: c.estPerime,
          ),
        ),
      ),
    );
  }

  Widget _bandeauPartage() {
    final l = _partage.liaison;
    final texte = l == null
        ? (_partage.avertissement ?? 'Partage désactivé')
        : '${l.nom} : ${l.etat.value} · ${_partage.camarades.length} camarade(s)';
    final attente = _partage.nombreEnAttente;
    return Material(
      color: Colors.black.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _ouvrirReglages,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
              attente == 0
                  ? texte
                  : '$texte\n$attente envoi(s) en attente de réseau',
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ),
    );
  }
}

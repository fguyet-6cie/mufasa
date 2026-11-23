// Relecture d'un exercice enregistré : où était chacun, et quels ennemis,
// points et dessins existaient, à une heure donnée.
import 'package:latlong2/latlong.dart';

import '../dessins.dart';
import '../hierarchie.dart';
import 'enregistrement.dart';

class PassageRejeu {
  final DateTime t;
  final LatLng point;
  final String indicatif;
  final Place place;
  const PassageRejeu(this.t, this.point, this.indicatif, this.place);
}

class Rejeu {
  /// Positions de chacun, dans l'ordre du temps.
  final Map<String, List<PassageRejeu>> traces;

  /// Ennemis, points, dessins et suppressions, dans l'ordre du temps.
  final List<Evenement> dessins;
  final DateTime debut, fin;

  Rejeu._(this.traces, this.dessins, this.debut, this.fin);

  factory Rejeu.depuisLignes(Iterable<String> lignes) {
    final evs = [
      for (final l in lignes)
        if (Evenement.lire(l) case final e?) e
    ]..sort((a, b) => a.t.compareTo(b.t));
    final traces = <String, List<PassageRejeu>>{};
    final dessins = <Evenement>[];
    for (final e in evs) {
      if (e.type == 'p') {
        (traces[e.uid] ??= [])
            .add(PassageRejeu(e.t, e.point, e.indicatif, e.place));
      } else {
        dessins.add(e);
      }
    }
    final debut = evs.isEmpty ? DateTime.now().toUtc() : evs.first.t;
    final fin = evs.isEmpty ? debut : evs.last.t;
    return Rejeu._(traces, dessins, debut, fin);
  }

  bool get vide => traces.isEmpty && dessins.isEmpty;

  /// Dernier passage connu à l'heure [t] (rien si la personne n'a pas donné
  /// de nouvelles depuis plus de [oubli]).
  PassageRejeu? passageA(String uid, DateTime t,
      {Duration oubli = const Duration(minutes: 10)}) {
    final l = traces[uid];
    if (l == null || l.isEmpty || l.first.t.isAfter(t)) return null;
    var bas = 0, haut = l.length - 1;
    while (bas < haut) {
      final m = (bas + haut + 1) ~/ 2;
      if (l[m].t.isAfter(t)) {
        haut = m - 1;
      } else {
        bas = m;
      }
    }
    final p = l[bas];
    return t.difference(p.t) > oubli ? null : p;
  }

  /// Chemin parcouru pendant [duree] avant l'heure [t].
  List<LatLng> traceA(String uid, DateTime t,
          {Duration duree = const Duration(minutes: 15)}) =>
      [
        for (final p in traces[uid] ?? const <PassageRejeu>[])
          if (!p.t.isAfter(t) && t.difference(p.t) <= duree) p.point
      ];

  /// Ennemis, points et dessins présents sur la carte à l'heure [t].
  List<Dessin> dessinsA(DateTime t) {
    final r = <String, Dessin>{};
    for (final e in dessins) {
      if (e.t.isAfter(t)) break;
      if (e.type == 's') {
        r.remove(e.uid);
      } else if (Dessin.depuisXml(e.xml) case final d?) {
        r[d.uid] = d;
      }
    }
    return r.values.toList();
  }

  /// Tous les points enregistrés (pour cadrer la carte au départ).
  List<LatLng> get tousLesPoints => [
        for (final l in traces.values)
          for (final p in l) p.point,
        for (final e in dessins)
          if (e.type == 'd')
            if (Dessin.depuisXml(e.xml) case final d?) ...d.points,
      ];
}

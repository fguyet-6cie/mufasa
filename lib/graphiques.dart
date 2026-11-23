// Peinture des dessins partagés sur la carte : points particuliers,
// lignes et zones libres, ennemis signalés.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'dessins.dart';

/// Couche de carte qui peint tous les dessins visibles.
class CoucheDessins extends StatelessWidget {
  final List<Dessin> dessins;

  /// Tracé en cours (aperçu pendant que l'utilisateur pose les points).
  final Dessin? brouillon;

  const CoucheDessins({super.key, required this.dessins, this.brouillon});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _Peintre(
            camera, [...dessins, if (brouillon != null) brouillon!], brouillon),
      ),
    );
  }
}

/// Cherche le dessin le plus proche d'un toucher (à 24 pixels près).
Dessin? dessinTouche(
    MapCamera camera, Iterable<Dessin> dessins, Offset toucher) {
  Dessin? meilleur;
  var meilleureDistance = 24.0;
  for (final d in dessins) {
    final pts = d.points.map(camera.latLngToScreenOffset).toList();
    double dist;
    if (pts.length == 1) {
      dist = (pts.first - toucher).distance;
    } else {
      dist = double.infinity;
      final segs = [
        for (var i = 0; i < pts.length - 1; i++) (pts[i], pts[i + 1]),
        if (d.forme == FormeDessin.zone) (pts.last, pts.first),
      ];
      for (final (a, b) in segs) {
        dist = math.min(dist, _distanceSegment(toucher, a, b));
      }
      if (d.forme == FormeDessin.zone && _dedans(toucher, pts)) dist = 0;
    }
    if (dist < meilleureDistance) {
      meilleureDistance = dist;
      meilleur = d;
    }
  }
  return meilleur;
}

double _distanceSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final l2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (l2 == 0) return (p - a).distance;
  final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / l2).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

bool _dedans(Offset p, List<Offset> poly) {
  var dedans = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], b = poly[j];
    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      dedans = !dedans;
    }
  }
  return dedans;
}

class _Peintre extends CustomPainter {
  final MapCamera camera;
  final List<Dessin> dessins;
  final Dessin? brouillon;
  _Peintre(this.camera, this.dessins, this.brouillon);

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in dessins) {
      final pts = d.points.map(camera.latLngToScreenOffset).toList();
      final trait = Paint()
        ..color = d.couleur
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      final estBrouillon = identical(d, brouillon);
      switch (d.forme) {
        case FormeDessin.point:
          // Point particulier : losange orange (nom visible en le touchant).
          _losange(canvas, pts.first);
        case FormeDessin.ligne:
          if (pts.length > 1) canvas.drawPath(_chemin(pts), trait);
          _etiquette(canvas, _milieu(pts), d.nom, d.couleur);
        case FormeDessin.zone:
          if (pts.length > 2) {
            final c = _chemin(pts)..close();
            canvas.drawPath(
                c,
                Paint()
                  ..color = d.couleur.withValues(alpha: 0.18)
                  ..style = PaintingStyle.fill);
            canvas.drawPath(c, trait);
          } else if (pts.length == 2) {
            canvas.drawPath(_chemin(pts), trait);
          }
          // Nom posé au-dessus du point le plus haut de la zone.
          final haut = pts.reduce((a, b) => a.dy <= b.dy ? a : b);
          _etiquette(canvas, haut + const Offset(0, -14), d.nom, d.couleur);
        case FormeDessin.ennemi:
          _ennemi(canvas, d, pts.first);
      }
      if (estBrouillon) {
        for (final p in pts) {
          canvas.drawCircle(p, 6, Paint()..color = Colors.white);
          canvas.drawCircle(
              p,
              6,
              Paint()
                ..color = d.couleur
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2);
        }
      }
    }
  }

  Path _chemin(List<Offset> pts) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final q in pts.skip(1)) {
      p.lineTo(q.dx, q.dy);
    }
    return p;
  }

  Offset _milieu(List<Offset> pts) {
    if (pts.length == 1) return pts.first;
    // Point situé à mi-longueur du tracé.
    final longueurs = [
      for (var i = 0; i < pts.length - 1; i++) (pts[i + 1] - pts[i]).distance
    ];
    var reste = longueurs.fold(0.0, (a, b) => a + b) / 2;
    for (var i = 0; i < longueurs.length; i++) {
      if (reste <= longueurs[i] && longueurs[i] > 0) {
        return pts[i] + (pts[i + 1] - pts[i]) * (reste / longueurs[i]);
      }
      reste -= longueurs[i];
    }
    return pts.last;
  }

  void _losange(Canvas canvas, Offset p) {
    final l = Path()
      ..moveTo(p.dx, p.dy - 12)
      ..lineTo(p.dx + 12, p.dy)
      ..lineTo(p.dx, p.dy + 12)
      ..lineTo(p.dx - 12, p.dy)
      ..close();
    canvas.drawPath(
        l,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.5
          ..strokeJoin = StrokeJoin.miter);
    canvas.drawPath(
        l,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeJoin = StrokeJoin.miter);
    canvas.drawPath(l, Paint()..color = const Color(0xFFEF6C00));
  }

  /// Ennemi : rond rouge, flèche s'il bouge, heure en dessous. Il pâlit
  /// après 30 min ; « plus là », il est grisé et barré ; s'il a bougé, son
  /// ancienne place reste en pointillés.
  void _ennemi(Canvas canvas, Dessin d, Offset p) {
    final rouge = Colors.red.shade700;
    final ancienne = d.anciennePosition;
    if (ancienne != null) {
      final a = camera.latLngToScreenOffset(ancienne);
      final trait = Paint()
        ..color = rouge.withValues(alpha: 0.8)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      final chemin = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(p.dx, p.dy);
      canvas.drawPath(_pointilles(chemin, 6, 6), trait);
      final cercle = Path()..addOval(Rect.fromCircle(center: a, radius: 8));
      canvas.drawPath(_pointilles(cercle, 3, 3), trait);
      _texteHeure(canvas, a + const Offset(0, 18), d.fiche['ancienHeure'] ?? '',
          rouge.withValues(alpha: 0.8));
    }
    final pale = d.estAncien || d.disparu;
    canvas.saveLayer(
        null, Paint()..color = Colors.white.withValues(alpha: pale ? 0.4 : 1));
    final cap = capsEnnemi[d.fiche['cap']];
    if (cap != null && !d.disparu) _flecheEnnemi(canvas, p, cap);
    canvas.drawCircle(p, 11, Paint()..color = Colors.white);
    canvas.drawCircle(
        p, 8.5, Paint()..color = d.disparu ? Colors.grey.shade700 : rouge);
    canvas.restore();
    if (d.disparu) {
      final x = Paint()
        ..color = Colors.black87
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p + const Offset(-10, -10), p + const Offset(10, 10), x);
      canvas.drawLine(p + const Offset(10, -10), p + const Offset(-10, 10), x);
    }
    final h = d.fiche['heure'] ?? '';
    _texteHeure(canvas, p + const Offset(0, 20), d.disparu ? 'disparu $h' : h,
        pale ? rouge.withValues(alpha: 0.6) : rouge);
  }

  void _texteHeure(Canvas canvas, Offset centre, String texte, Color couleur) {
    if (texte.isEmpty) return;
    final tp = TextPainter(
      text: TextSpan(
          text: texte,
          style: TextStyle(
              color: couleur, fontSize: 11, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromCenter(
        center: centre, width: tp.width + 6, height: tp.height + 1);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()..color = Colors.white.withValues(alpha: 0.9));
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
  }

  Path _pointilles(Path source, double plein, double vide) {
    final res = Path();
    for (final m in source.computeMetrics()) {
      var t = 0.0;
      while (t < m.length) {
        res.addPath(
            m.extractPath(t, math.min(t + plein, m.length)), Offset.zero);
        t += plein + vide;
      }
    }
    return res;
  }

  /// Flèche rouge partant du point ennemi, vers la direction où il va.
  void _flecheEnnemi(Canvas canvas, Offset p, int cap) {
    final a = cap * math.pi / 180;
    final u = Offset(math.sin(a), -math.cos(a));
    final n = Offset(-u.dy, u.dx);
    final debut = p + u * 13, bout = p + u * 46;
    final base = bout - u * 14;
    final tete = Path()
      ..moveTo(bout.dx, bout.dy)
      ..lineTo((base + n * 9).dx, (base + n * 9).dy)
      ..lineTo((base - n * 9).dx, (base - n * 9).dy)
      ..close();
    final contour = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(debut, base, contour);
    canvas.drawPath(tete, contour);
    final rouge = Paint()
      ..color = Colors.red.shade700
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(debut, base, rouge);
    canvas.drawPath(tete, Paint()..color = Colors.red.shade700);
  }

  void _etiquette(Canvas canvas, Offset centre, String texte, Color couleur) {
    if (texte.isEmpty) return;
    final tp = TextPainter(
      text: TextSpan(
        text: texte,
        style: const TextStyle(
            color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 160);
    final rect = Rect.fromCenter(
        center: centre, width: tp.width + 8, height: tp.height + 2);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = Colors.white.withValues(alpha: 0.85));
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_Peintre old) => true;
}

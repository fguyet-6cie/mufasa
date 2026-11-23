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
          _point(canvas, pts.first, d.couleur);
          _etiquette(canvas, pts.first + const Offset(0, 16), d.nom, d.couleur);
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
          final p = pts.first;
          final cap = capsEnnemi[d.fiche['cap']];
          if (cap != null) _flecheEnnemi(canvas, p, cap);
          canvas.drawCircle(p, 11, Paint()..color = Colors.white);
          canvas.drawCircle(p, 8.5, Paint()..color = Colors.red.shade700);
          final resume = [d.fiche['volume'], d.fiche['nature']]
              .where((t) => t != null && t.isNotEmpty && t != 'Inconnu')
              .join(' ');
          _etiquette(canvas, p + const Offset(0, 20),
              resume.isEmpty ? 'ENI' : 'ENI · $resume', d.couleur);
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

  void _point(Canvas canvas, Offset p, Color couleur) {
    canvas.drawCircle(p, 9, Paint()..color = Colors.white);
    canvas.drawCircle(p, 7, Paint()..color = couleur);
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

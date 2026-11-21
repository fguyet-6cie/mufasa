// Dessin des calques sur la carte : points, lignes, zones et graphiques de
// mission (flèches, lignes à lettre, bouclage).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'dessins.dart';
import 'symboles.dart';

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
    } else if (d.laMission?.trace == TraceMission.boucle) {
      final r = (pts[1] - pts[0]).distance;
      dist = ((toucher - pts[0]).distance - r).abs();
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
        case FormeDessin.mission:
          _mission(canvas, d, pts, trait);
        case FormeDessin.symbole:
          break; // dessiné par CoucheSymboles
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

  void _mission(Canvas canvas, Dessin d, List<Offset> pts, Paint trait) {
    final m = d.laMission;
    if (m == null || pts.length < 2) return;
    final legende = [
      if (d.pion.isNotEmpty) d.pion,
      if (d.nom.isNotEmpty) d.nom,
    ].join(' · ');
    switch (m.trace) {
      case TraceMission.fleche:
        final chemin = _chemin(pts);
        final dessinTrait = switch (m.style) {
          StyleTrait.plein => chemin,
          StyleTrait.tirets => _tirets(chemin, 12, 8),
          StyleTrait.pointilles => _tirets(chemin, 3, 5),
          StyleTrait.zigzag => _zigzag(pts),
        };
        canvas.drawPath(
            dessinTrait, trait..strokeWidth = m.pointePleine ? 4 : 3);
        _pointe(canvas, pts[pts.length - 2], pts.last, d.couleur,
            plein: m.pointePleine, taille: 16);
        final mil = _milieu(pts);
        if (m.lettre.isNotEmpty) _lettre(canvas, mil, m.lettre, d.couleur);
        _etiquette(canvas, mil + const Offset(0, 18), legende, d.couleur);
      case TraceMission.secteur:
        if (pts.length < 2) return;
        final pion = pts[0];
        for (final limite in pts.skip(1)) {
          canvas.drawLine(pion, limite, trait);
          _pointe(canvas, pion, limite, d.couleur);
          final l = (limite - pion).distance;
          if (l < 30) continue;
          final u = (limite - pion) / l;
          // La lettre est posée sur le trait, un peu décalée.
          _lettre(canvas, pion + u * (l * 0.55) + Offset(-u.dy, u.dx) * 12,
              m.lettre, d.couleur,
              fond: false);
        }
        _etiquette(canvas, pion + const Offset(0, 18), legende, d.couleur);
      case TraceMission.boucle:
        final c = pts[0];
        final r = (pts[1] - c).distance;
        if (r < 4) return;
        final depart = math.atan2((pts[1] - c).dy, (pts[1] - c).dx);
        const ouverture = 0.6; // radians laissés libres
        final balayage = 2 * math.pi - ouverture;
        canvas.drawArc(Rect.fromCircle(center: c, radius: r), depart, balayage,
            false, trait);
        // Petits traits vers l'intérieur, répartis sur l'arc.
        for (var i = 1; i < 8; i++) {
          final ang = depart + balayage * i / 8;
          final dir = Offset(math.cos(ang), math.sin(ang));
          canvas.drawLine(c + dir * r, c + dir * (r - 10), trait);
        }
        // Pointe au bout de l'arc.
        final fin = depart + balayage;
        final bout = c + Offset(math.cos(fin), math.sin(fin)) * r;
        final avant =
            c + Offset(math.cos(fin - 0.15), math.sin(fin - 0.15)) * r;
        _pointe(canvas, avant, bout, d.couleur, plein: true);
        _lettre(canvas, c, m.lettre, d.couleur);
        _etiquette(canvas, c + Offset(0, r + 14), legende, d.couleur);
      case TraceMission.croix:
        final c = pts[0];
        final r = math.max((pts[1] - c).distance, 12.0);
        final epais = trait..strokeWidth = 5;
        canvas.drawLine(
            c + Offset(-r, -r) * 0.7, c + Offset(r, r) * 0.7, epais);
        canvas.drawLine(
            c + Offset(-r, r) * 0.7, c + Offset(r, -r) * 0.7, epais);
        _lettre(canvas, c, m.lettre, d.couleur);
        _etiquette(canvas, c + Offset(0, r * 0.7 + 14), legende, d.couleur);
    }
  }

  Path _zigzag(List<Offset> pts) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i], b = pts[i + 1];
      final l = (b - a).distance;
      if (l < 1) continue;
      final u = (b - a) / l;
      final n = Offset(-u.dy, u.dx);
      // Zigzag sur la partie centrale, droit près de la pointe.
      final pas = 14.0;
      var t = 0.0;
      var cote = 1.0;
      final finZigzag = i == pts.length - 2 ? l - 24 : l;
      while (t + pas < finZigzag) {
        t += pas;
        final q = a + u * t + n * (7 * cote);
        p.lineTo(q.dx, q.dy);
        cote = -cote;
      }
      p.lineTo(b.dx, b.dy);
    }
    return p;
  }

  Path _chemin(List<Offset> pts) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final q in pts.skip(1)) {
      p.lineTo(q.dx, q.dy);
    }
    return p;
  }

  Path _tirets(Path source, double plein, double vide) {
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

  void _pointe(Canvas canvas, Offset de, Offset vers, Color couleur,
      {bool plein = false, double taille = 14}) {
    final dir = vers - de;
    if (dir.distance < 0.1) return;
    final u = dir / dir.distance;
    final n = Offset(-u.dy, u.dx);
    final base = vers - u * taille;
    final p = Path()
      ..moveTo(vers.dx, vers.dy)
      ..lineTo((base + n * taille * 0.6).dx, (base + n * taille * 0.6).dy)
      ..moveTo(vers.dx, vers.dy)
      ..lineTo((base - n * taille * 0.6).dx, (base - n * taille * 0.6).dy);
    if (plein) {
      final tri = Path()
        ..moveTo(vers.dx, vers.dy)
        ..lineTo((base + n * taille * 0.6).dx, (base + n * taille * 0.6).dy)
        ..lineTo((base - n * taille * 0.6).dx, (base - n * taille * 0.6).dy)
        ..close();
      canvas.drawPath(tri, Paint()..color = couleur);
    } else {
      canvas.drawPath(
          p,
          Paint()
            ..color = couleur
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round);
    }
  }

  void _point(Canvas canvas, Offset p, Color couleur) {
    canvas.drawCircle(p, 9, Paint()..color = Colors.white);
    canvas.drawCircle(p, 7, Paint()..color = couleur);
  }

  void _lettre(Canvas canvas, Offset centre, String texte, Color couleur,
      {bool fond = true}) {
    final tp = TextPainter(
      text: TextSpan(
        text: texte,
        style: TextStyle(
            color: couleur, fontSize: 16, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromCenter(
        center: centre, width: tp.width + 8, height: tp.height + 2);
    if (fond) {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()..color = Colors.white.withValues(alpha: 0.85));
    }
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
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

/// Couche des symboles OTAN posés sur la carte (pions, matériels, points…).
MarkerLayer coucheSymboles(Iterable<Dessin> dessins) {
  // Échelle fixe : tous les cadres ont la même taille, PC et échelons en plus.
  const k = 0.85, etiquette = 18.0, largeurMini = 110.0;
  return MarkerLayer(markers: [
    for (final d in dessins.where((d) => d.forme == FormeDessin.symbole))
      () {
        final (l, h, ax, ay) = ImageSymbole.mesures(d.sidc);
        final w = l * k, hauteur = h * k;
        final largeur = w > largeurMini ? w : largeurMini;
        final total = hauteur + etiquette;
        // Le point d'ancrage du symbole (centre du cadre) tombe sur la position.
        final axs = largeur / 2 - w / 2 + ax * k, ays = ay * k;
        return Marker(
          point: d.points.first,
          width: largeur,
          height: total,
          alignment: Alignment(1 - 2 * axs / largeur, 1 - 2 * ays / total),
          child: IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ImageSymbole(d.sidc, hauteur: hauteur),
                if (d.nom.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      d.nom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: estEnnemi(d.sidc)
                            ? Colors.red.shade800
                            : Colors.black,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }(),
  ]);
}

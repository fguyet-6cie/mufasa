// Fenêtres utilisées pour dessiner : choix de l'outil, nom, couleur,
// observations, et fiche d'un dessin touché sur la carte.
import 'package:flutter/material.dart';

import 'dessins.dart';
import 'mgrs.dart';

/// Choix de ce que l'on veut poser sur la carte.
Future<FormeDessin?> choisirOutil(BuildContext context) {
  return showModalBottomSheet<FormeDessin>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.place, color: Color(0xFFEF6C00)),
            title: const Text('Point particulier'),
            subtitle: const Text('Un repère avec tes observations'),
            onTap: () => Navigator.pop(ctx, FormeDessin.point),
          ),
          ListTile(
            leading: const Icon(Icons.timeline),
            title: const Text('Ligne'),
            subtitle: const Text('Dessin libre : itinéraire, limite, axe…'),
            onTap: () => Navigator.pop(ctx, FormeDessin.ligne),
          ),
          ListTile(
            leading: const Icon(Icons.pentagon_outlined),
            title: const Text('Zone'),
            subtitle: const Text('Dessin libre : zone, objectif, secteur…'),
            onTap: () => Navigator.pop(ctx, FormeDessin.zone),
          ),
        ],
      ),
    ),
  );
}

class FinDessin {
  final String nom;
  final Color couleur;
  final String observations;
  const FinDessin(this.nom, this.couleur, [this.observations = '']);
}

/// Dernière étape : nom, couleur, et observations pour un point particulier.
Future<FinDessin?> finaliserDessin(
  BuildContext context, {
  required String titre,
  required Color couleurSuggeree,
  bool avecObservations = false,
  bool avecCouleur = true,
}) {
  final nom = TextEditingController();
  final obs = TextEditingController();
  var couleur = couleurSuggeree;
  return showDialog<FinDessin>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(titre),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nom,
                autofocus: true,
                decoration: InputDecoration(
                    labelText: 'Nom',
                    hintText: avecObservations
                        ? 'ex. Pont, Ferme, RV 1'
                        : 'ex. Itinéraire FER'),
              ),
              if (avecObservations) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: obs,
                  minLines: 3,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Observations',
                    hintText: 'Ce que tu as vu, l\'état des lieux…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (avecCouleur) const SizedBox(height: 12),
              if (avecCouleur)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in couleursDessin.entries)
                      GestureDetector(
                        onTap: () => setState(() => couleur = e.value),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: e.value,
                          child: couleur.toARGB32() == e.value.toARGB32()
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 18)
                              : null,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abandonner')),
          FilledButton(
            onPressed: () => Navigator.pop(
                ctx, FinDessin(nom.text.trim(), couleur, obs.text.trim())),
            child: const Text('Partager'),
          ),
        ],
      ),
    ),
  );
}

enum ActionDessin { supprimer, deplacer, toujoursLa, aBouge, plusLa }

/// Fiche d'un dessin touché sur la carte. Pour un ennemi, la fiche est
/// rouge et propose « Toujours là », « Il a bougé » et « Plus là ».
Future<ActionDessin?> ficheDessin(BuildContext context, Dessin d) {
  final eni = d.forme == FormeDessin.ennemi;
  final titre = eni
      ? (d.disparu ? 'Ennemi disparu' : 'Ennemi signalé')
      : (d.nom.isEmpty ? 'Sans nom' : d.nom);
  final heure = d.heure.toLocal();
  final hh =
      '${heure.hour.toString().padLeft(2, '0')}h${heure.minute.toString().padLeft(2, '0')}';
  final texte = eni ? Colors.white : Colors.black87;
  final mgrs = versMgrs(d.centre.latitude, d.centre.longitude);
  Widget rubrique(String nom, String valeur) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text.rich(TextSpan(children: [
          TextSpan(
              text: '$nom : ',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: valeur),
        ])),
      );
  Widget bouton(String titre, String sous, Color fond, ActionDessin a,
          BuildContext ctx) =>
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: fond,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Colors.white, width: 1.5)),
            ),
            onPressed: () => Navigator.pop(ctx, a),
            child: Column(children: [
              Text(titre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(sous,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11)),
            ]),
          ),
        ),
      );
  return showModalBottomSheet<ActionDessin>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: eni ? Colors.red.shade700 : null,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: texte, fontSize: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titre,
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: texte)),
              if (eni)
                for (final r in rubriquesEnnemi.entries)
                  if ((d.fiche[r.key] ?? '').isNotEmpty)
                    rubrique(
                        r.value,
                        r.key == 'cap'
                            ? nomsCaps[d.fiche['cap']] ?? d.fiche['cap']!
                            : d.fiche[r.key]!),
              if (eni && (d.fiche['revuPar'] ?? '').isNotEmpty)
                rubrique(d.disparu ? 'Vu disparu par' : 'Revu par',
                    '${d.fiche['revuPar']} à ${d.fiche['heure'] ?? hh}'),
              if (eni && d.anciennePosition != null)
                rubrique('Avant',
                    'ailleurs à ${d.fiche['ancienHeure'] ?? '?'} (pointillés)'),
              if (d.observations.isNotEmpty)
                rubrique('Observations', d.observations),
              if (d.forme != FormeDessin.ligne && mgrs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SelectableText(
                    'MGRS : $mgrs',
                    style: TextStyle(
                        color: texte,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                  'Mis à jour par ${d.auteurIndicatif.isEmpty ? 'inconnu' : d.auteurIndicatif}, à $hh',
                  style: TextStyle(color: texte.withValues(alpha: 0.8))),
              const SizedBox(height: 14),
              if (eni)
                Row(children: [
                  bouton('✓ Toujours là', 'je le revois ici',
                      Colors.green.shade700, ActionDessin.toujoursLa, ctx),
                  bouton('➜ Il a bougé', 'je touche sa nouvelle place',
                      Colors.orange.shade800, ActionDessin.aBouge, ctx),
                  if (!d.disparu)
                    bouton('✕ Plus là', 'il a disparu', Colors.grey.shade800,
                        ActionDessin.plusLa, ctx),
                ]),
              if (eni)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(ctx, ActionDessin.supprimer),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Signalé par erreur : supprimer'),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          Navigator.pop(ctx, ActionDessin.deplacer),
                      icon: const Icon(Icons.open_with),
                      label: const Text('Déplacer'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pop(ctx, ActionDessin.supprimer),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Supprimer pour tout le monde'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Demande confirmation avant d'effacer un dessin chez tout le monde.
Future<bool> confirmerSuppression(BuildContext context, Dessin d) async {
  final quoi = switch (d.forme) {
    FormeDessin.ennemi => 'cet ennemi',
    FormeDessin.point => d.nom.isEmpty ? 'ce point' : '« ${d.nom} »',
    FormeDessin.ligne => d.nom.isEmpty ? 'cette ligne' : '« ${d.nom} »',
    FormeDessin.zone => d.nom.isEmpty ? 'cette zone' : '« ${d.nom} »',
  };
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.delete_outline, size: 36),
      title: const Text('Supprimer pour tout le monde ?'),
      content: Text('Tu vas effacer $quoi de la carte de tous les membres '
          'de la compagnie. Ce n\'est pas réversible.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

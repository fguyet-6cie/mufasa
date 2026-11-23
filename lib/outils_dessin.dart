// Fenêtres utilisées pour dessiner : choix de l'outil, nom, couleur,
// observations, et fiche d'un dessin touché sur la carte.
import 'package:flutter/material.dart';

import 'dessins.dart';

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
            leading: const Icon(Icons.place),
            title: const Text('Point particulier'),
            subtitle: const Text('Un repère avec vos observations'),
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
                    hintText: 'Ce que vous avez vu, l\'état des lieux…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
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

enum ActionDessin { supprimer, deplacer }

/// Fiche d'un dessin touché sur la carte.
Future<ActionDessin?> ficheDessin(BuildContext context, Dessin d) {
  final titre = d.forme == FormeDessin.ennemi
      ? 'Ennemi signalé'
      : (d.nom.isEmpty ? 'Sans nom' : d.nom);
  final heure = d.heure.toLocal();
  final hh =
      '${heure.hour.toString().padLeft(2, '0')}h${heure.minute.toString().padLeft(2, '0')}';
  Widget rubrique(String nom, String valeur) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text.rich(TextSpan(children: [
          TextSpan(
              text: '$nom : ',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: valeur),
        ])),
      );
  return showModalBottomSheet<ActionDessin>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre, style: Theme.of(ctx).textTheme.titleLarge),
            if (d.forme == FormeDessin.ennemi)
              for (final r in rubriquesEnnemi.entries)
                if ((d.fiche[r.key] ?? '').isNotEmpty)
                  rubrique(r.value, d.fiche[r.key]!),
            if (d.observations.isNotEmpty)
              rubrique('Observations', d.observations),
            const SizedBox(height: 8),
            Text(
                'Par ${d.auteurIndicatif.isEmpty ? 'inconnu' : d.auteurIndicatif}, à $hh'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.pop(ctx, ActionDessin.deplacer),
                  icon: const Icon(Icons.open_with),
                  label: const Text('Déplacer'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx, ActionDessin.supprimer),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Supprimer pour tout le groupe'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

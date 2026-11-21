// Fenêtres utilisées pour dessiner : choix de l'outil, du pion, du calque…
import 'package:flutter/material.dart';

import 'dessins.dart';

/// Ce que l'utilisateur veut dessiner.
class ChoixOutil {
  final FormeDessin forme;
  final Mission? mission;
  const ChoixOutil(this.forme, [this.mission]);
}

Future<ChoixOutil?> choisirOutil(BuildContext context) {
  return showModalBottomSheet<ChoixOutil>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
        child: ListView(
          shrinkWrap: true,
          children: [
            const _Titre('Manœuvre : mission d\'un pion'),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in missions)
                  ActionChip(
                    avatar: m.lettre.isEmpty
                        ? const Icon(Icons.north_east, size: 18)
                        : FittedBox(
                            child: Text(m.lettre,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900)),
                          ),
                    label: Text(m.nom),
                    onPressed: () =>
                        Navigator.pop(ctx, ChoixOutil(FormeDessin.mission, m)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const _Titre('Dessin libre'),
            ListTile(
              leading: const Icon(Icons.place),
              title: const Text('Point'),
              subtitle: const Text('Un repère nommé'),
              onTap: () =>
                  Navigator.pop(ctx, const ChoixOutil(FormeDessin.point)),
            ),
            ListTile(
              leading: const Icon(Icons.timeline),
              title: const Text('Ligne'),
              subtitle: const Text('Itinéraire, limite, axe…'),
              onTap: () =>
                  Navigator.pop(ctx, const ChoixOutil(FormeDessin.ligne)),
            ),
            ListTile(
              leading: const Icon(Icons.pentagon_outlined),
              title: const Text('Zone'),
              subtitle: const Text('Zone d\'action, objectif, secteur…'),
              onTap: () =>
                  Navigator.pop(ctx, const ChoixOutil(FormeDessin.zone)),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Titre extends StatelessWidget {
  final String texte;
  const _Titre(this.texte);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(texte, style: Theme.of(context).textTheme.titleMedium),
      );
}

/// Choisit le pion qui reçoit la mission : un camarade visible ou un nom libre.
Future<String?> choisirPion(
    BuildContext context, Mission mission, List<String> indicatifs) {
  final libre = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${mission.nom} : quel pion ?'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final i in indicatifs)
              ListTile(
                leading: const Icon(Icons.person_pin_circle),
                title: Text(i),
                onTap: () => Navigator.pop(ctx, i),
              ),
            TextField(
              controller: libre,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: 'Autre pion', hintText: 'ex. 2e SECTION'),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, libre.text.trim()),
            child: const Text('Suivant')),
      ],
    ),
  );
}

class FinDessin {
  final String nom;
  final String calque;
  final Color couleur;
  const FinDessin(this.nom, this.calque, this.couleur);
}

/// Dernière étape : nom, calque et couleur.
Future<FinDessin?> finaliserDessin(
  BuildContext context, {
  required String titre,
  required List<String> calques,
  required String calqueSuggere,
  required Color couleurSuggeree,
  bool nomFacultatif = false,
}) {
  final nom = TextEditingController();
  final nouveauCalque = TextEditingController();
  var calque = calqueSuggere;
  var couleur = couleurSuggeree;
  const nouveau = '__nouveau__';
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
                autofocus: !nomFacultatif,
                decoration: InputDecoration(
                    labelText: nomFacultatif ? 'Précision (facultatif)' : 'Nom',
                    hintText: nomFacultatif ? 'ex. OBJ LION' : 'ex. PC, RV 1'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: calque,
                decoration: const InputDecoration(labelText: 'Calque'),
                items: [
                  for (final c in calques)
                    DropdownMenuItem(value: c, child: Text(c)),
                  const DropdownMenuItem(
                      value: nouveau, child: Text('+ Nouveau calque…')),
                ],
                onChanged: (v) => setState(() => calque = v!),
              ),
              if (calque == nouveau)
                TextField(
                  controller: nouveauCalque,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: 'Nom du nouveau calque',
                      hintText: 'ex. Manœuvre phase 1'),
                ),
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
            onPressed: () {
              final c = calque == nouveau
                  ? (nouveauCalque.text.trim().isEmpty
                      ? calqueParDefaut
                      : nouveauCalque.text.trim())
                  : calque;
              Navigator.pop(ctx, FinDessin(nom.text.trim(), c, couleur));
            },
            child: const Text('Partager'),
          ),
        ],
      ),
    ),
  );
}

/// Fiche d'un dessin touché sur la carte. Renvoie true pour le supprimer.
Future<bool?> ficheDessin(BuildContext context, Dessin d) {
  final m = d.laMission;
  final titre = m != null
      ? '${m.nom}${d.pion.isEmpty ? '' : ' : ${d.pion}'}'
      : (d.nom.isEmpty ? 'Sans nom' : d.nom);
  final heure = d.heure.toLocal();
  final hh =
      '${heure.hour.toString().padLeft(2, '0')}h${heure.minute.toString().padLeft(2, '0')}';
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre, style: Theme.of(ctx).textTheme.titleLarge),
            if (m != null && d.nom.isNotEmpty) Text(d.nom),
            const SizedBox(height: 8),
            Text('Calque : ${d.calque}'),
            Text(
                'Par ${d.auteurIndicatif.isEmpty ? 'inconnu' : d.auteurIndicatif}, à $hh'),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
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

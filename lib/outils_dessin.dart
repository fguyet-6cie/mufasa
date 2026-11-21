// Fenêtres utilisées pour dessiner : choix de l'outil, du pion, du calque…
import 'package:flutter/material.dart';

import 'dessins.dart';
import 'symboles.dart';

/// Ce que l'utilisateur veut dessiner.
class ChoixOutil {
  final FormeDessin forme;
  final Mission? mission;
  final String sidc;
  const ChoixOutil(this.forme, [this.mission, this.sidc = '']);
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
            const _Titre('Pion ou symbole OTAN'),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Poser un symbole'),
              subtitle: const Text('Unité amie ou ennemie, matériel, point…'),
              onTap: () async {
                final sidc = await choisirSymbole(ctx);
                if (sidc != null && ctx.mounted) {
                  Navigator.pop(
                      ctx, ChoixOutil(FormeDessin.symbole, null, sidc));
                }
              },
            ),
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
  bool avecCouleur = true,
  String? exempleNom,
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
                    hintText: exempleNom ??
                        (nomFacultatif ? 'ex. OBJ LION' : 'ex. PC, RV 1')),
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

enum ActionDessin { supprimer, deplacer }

/// Fiche d'un dessin touché sur la carte.
Future<ActionDessin?> ficheDessin(BuildContext context, Dessin d) {
  final m = d.laMission;
  final symbole = d.forme == FormeDessin.symbole ? symboleDuCode(d.sidc) : null;
  final titre = d.forme == FormeDessin.ennemi
      ? 'Ennemi signalé'
      : m != null
          ? '${m.nom}${d.pion.isEmpty ? '' : ' : ${d.pion}'}'
          : (d.nom.isEmpty ? (symbole?.nom ?? 'Sans nom') : d.nom);
  final heure = d.heure.toLocal();
  final hh =
      '${heure.hour.toString().padLeft(2, '0')}h${heure.minute.toString().padLeft(2, '0')}';
  return showModalBottomSheet<ActionDessin>(
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
            if (d.forme == FormeDessin.ennemi)
              for (final r in rubriquesEnnemi.entries)
                if ((d.fiche[r.key] ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text.rich(TextSpan(children: [
                      TextSpan(
                          text: '${r.value} : ',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: d.fiche[r.key]),
                    ])),
                  ),
            if (symbole != null)
              Text(
                  '${symbole.nom}${estEnnemi(d.sidc) ? ' (ennemi)' : ' (ami)'}'),
            const SizedBox(height: 8),
            Text('Calque : ${d.calque}'),
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

/// Choix d'un symbole OTAN : ami ou ennemi, échelon, PC. Renvoie le code SIDC.
Future<String?> choisirSymbole(BuildContext context) {
  return Navigator.push<String>(
    context,
    MaterialPageRoute(
        fullscreenDialog: true, builder: (_) => const _ChoixSymbole()),
  );
}

class _ChoixSymbole extends StatefulWidget {
  const _ChoixSymbole();
  @override
  State<_ChoixSymbole> createState() => _ChoixSymboleEtat();
}

class _ChoixSymboleEtat extends State<_ChoixSymbole> {
  bool _ami = true;
  String _echelon = '-';
  bool _pc = false;

  @override
  Widget build(BuildContext context) {
    final titre = Theme.of(context).textTheme.titleMedium;
    return Scaffold(
      appBar: AppBar(title: const Text('Poser un symbole')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Ami')),
              ButtonSegment(value: false, label: Text('Ennemi')),
            ],
            selected: {_ami},
            onSelectionChanged: (v) => setState(() => _ami = v.first),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              segments: [
                for (final e in echelons.entries)
                  ButtonSegment(value: e.key, label: Text(e.value)),
              ],
              selected: {_echelon},
              onSelectionChanged: (v) => setState(() => _echelon = v.first),
            ),
          ),
          SwitchListTile(
            title: const Text('Poste de commandement (PC)'),
            value: _pc,
            onChanged: (v) => setState(() => _pc = v),
            contentPadding: EdgeInsets.zero,
          ),
          const Text('L\'échelon et le PC ne s\'appliquent qu\'aux unités.',
              style: TextStyle(fontSize: 12)),
          for (final f in FamilleSymbole.values) ...[
            const SizedBox(height: 12),
            Text(nomsFamilles[f]!, style: titre),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in catalogue.where((s) => s.famille == f))
                  _tuile(
                      s.variante(ami: _ami, echelon: _echelon, pc: _pc), s.nom),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tuile(String sidc, String nom) => InkWell(
        onTap: () => Navigator.pop(context, sidc),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 104,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: [
            SizedBox(
                height: 48,
                child: Center(child: ImageSymbole(sidc, hauteur: 44))),
            const SizedBox(height: 4),
            Text(nom,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(fontSize: 11)),
          ]),
        ),
      );
}

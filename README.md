# MUFASA

**Military Units Follow-up And Situational Awareness**

Appli terrain collaborative de la 6e compagnie du 21e RIMa (instruction et exercices).
Android et iPhone, écrite avec Flutter.

## Installer l'appli sur un téléphone Android

À chaque modification du code, GitHub fabrique automatiquement l'appli.
Sur le téléphone, ouvrir https://github.com/fguyet-6cie/mufasa/releases/latest ,
télécharger `mufasa.apk`, puis l'ouvrir pour l'installer (autoriser
« installer des applis inconnues » si le téléphone le demande).

## Ce que fait l'appli

1. **Position de tout le personnel** sur fond IGN (plan ou photos aériennes).
   - Pions bleus, cadre de la couleur de la section (CARMIN 1 bleu, 2 rouge,
     3 jaune, 4 vert, SK blanc), numéro de section ou de GOLF, lion pour le CDU.
   - Mon groupe en bleu foncé, mon trinôme avec un halo jaune.
   - Toucher un pion : bulle bleue avec nom, fonction et coordonnées MGRS.
   - « Ce que je vois » : toute la compagnie, ma section ou mon groupe, et
     jusqu'aux chefs de section, chefs de groupe ou tout le monde.
2. **Ennemis** : bouton Ennemi, fiche (volume, nature, attitude, direction…),
   rond rouge chez tous. Les ennemis pâlissent après 30 min ; boutons
   « Toujours là », « Il a bougé », « Plus là » ; détection « même ennemi ? ».
3. **Points particuliers** (losange orange) avec observations.
4. **Dessin libre** (lignes et zones) partagé avec tout le monde.
5. **Effacement d'urgence** de toutes les données du téléphone.

## Partage entre téléphones

- 4G/5G : via une « boîte aux lettres » en ligne (MQTT sur TLS, port 8883,
  par exemple HiveMQ Cloud gratuit). Les messages sont chiffrés dans le téléphone
  (AES-256-GCM) avec une clé tirée du code de groupe : l'hébergeur ne peut pas les lire.
  Les réglages se partagent en un seul texte « invitation » (MUFASA1:…).
- Sans réseau mobile : téléphones sur le même Wi-Fi ou partage de connexion
  (multidiffusion 239.21.6.6:21606).

Limite connue : sur iPhone, le mode Wi-Fi demande une autorisation spéciale d'Apple
(« multicast entitlement ») ; le mode 4G/5G marche sans.

## Fichiers importants

- `lib/main.dart` : l'écran carte.
- `lib/accueil.dart` : l'écran d'accueil.
- `lib/reglages.dart` : l'écran réglages (indicatif, place dans la compagnie, mode de partage).
- `lib/hierarchie.dart` : sections, groupes, trinômes et filtre « Ce que je vois ».
- `lib/pions.dart` : dessin des pions amis, bulle, légende.
- `lib/partage.dart` : envoi de ma position toutes les 10 s, liste des camarades.
- `lib/cot.dart` : lecture et écriture des messages de position (XML).
- `lib/dessins.dart` : ennemis, points particuliers, lignes et zones.
- `lib/graphiques.dart` : tracé des dessins et des ennemis sur la carte.
- `lib/ennemi.dart` : fiche de désignation d'un ennemi.
- `lib/outils_dessin.dart` : fenêtres pour dessiner et fiche d'un dessin.
- `lib/mgrs.dart` : coordonnées MGRS.
- `lib/chiffrement.dart` : chiffrement des messages avec le code de groupe.
- `lib/reseau/` : les modes de liaison (4G/5G, Wi-Fi local).
- `test/` : les tests automatiques (`flutter test`).

## Lancer l'appli (pour un développeur)

    flutter pub get
    flutter run

Les fonds IGN viennent du service gratuit de la Géoplateforme (data.geopf.fr), sans clé.

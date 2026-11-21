# Mufasa

Appli terrain collaborative de la 6e compagnie (instruction et exercices).
Android et iPhone, écrite avec Flutter.

## Installer l'appli sur un téléphone Android

À chaque modification du code, GitHub fabrique automatiquement l'appli.
Sur le téléphone, ouvrir https://github.com/fguyet-6cie/mufasa/releases/latest ,
télécharger `mufasa.apk`, puis l'ouvrir pour l'installer (autoriser
« installer des applis inconnues » si le téléphone le demande).

## Où en est-on

Étape 1 (faite) : carte avec fonds IGN (Plan IGN, photos aériennes) et position du téléphone.
Étape 2 (faite) : partage des positions entre les membres du groupe, au format CoT.
- 4G/5G (mode principal) : via une « boîte aux lettres » en ligne (MQTT sur TLS, port 8883,
  par exemple HiveMQ Cloud gratuit). Les positions sont chiffrées dans le téléphone
  (AES-256-GCM) avec une clé tirée du code de groupe : l'hébergeur ne peut pas les lire.
  Les réglages se partagent en un seul texte « invitation » (MUFASA1:…).
- Sans réseau mobile : téléphones sur le même Wi-Fi ou partage de connexion (multidiffusion 239.2.3.1:6969).
- Serveur TAK : connexion TCP à un serveur TAK (port 8087 par défaut), pour l'interopérabilité.
Étape 3 (faite) : calques et manœuvre.
- Dessins partagés : points, lignes, zones, rangés en calques qu'on affiche ou masque.
- Graphiques de mission rattachés à un pion : attaquer, fixer, détruire, neutraliser,
  boucler, couvrir, surveiller, flanc-garder, reconnaître, éclairer (inspirés de l'APP-6).
- Toucher un dessin pour voir qui l'a fait, ou le supprimer pour tout le groupe.
- Les dessins sont gardés dans le téléphone et renvoyés chaque minute aux retardataires.

Limite connue : sur iPhone, le mode sans serveur demande une autorisation spéciale d'Apple
(« multicast entitlement ») ; le mode avec serveur marche sans.

## Fichiers importants

- `lib/main.dart` : l'écran carte.
- `lib/reglages.dart` : l'écran réglages (indicatif, équipe, mode de partage).
- `lib/partage.dart` : envoi de ma position toutes les 10 s, liste des camarades.
- `lib/cot.dart` : lecture et écriture des messages CoT.
- `lib/dessins.dart` : dessins, calques et missions (format CoT).
- `lib/graphiques.dart` : tracé des dessins et des graphiques de mission sur la carte.
- `lib/outils_dessin.dart` : fenêtres pour dessiner (outil, pion, calque, couleur).
- `lib/chiffrement.dart` : chiffrement des positions avec le code de groupe.
- `lib/reseau/` : les modes de liaison (4G/5G, Wi-Fi local, serveur TAK).
- `test/` : les tests automatiques (`flutter test`).
- `pubspec.yaml` : la liste des briques utilisées (carte, GPS).
- `android/` et `ios/` : réglages propres à chaque téléphone (autorisations GPS, nom de l'appli).

## Lancer l'appli (pour un développeur)

    flutter pub get
    flutter run

Les fonds IGN viennent du service gratuit de la Géoplateforme (data.geopf.fr), sans clé.

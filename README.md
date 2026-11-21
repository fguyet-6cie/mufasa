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
- Sans serveur : téléphones sur le même Wi-Fi ou partage de connexion (multidiffusion 239.2.3.1:6969).
- Avec serveur : connexion TCP à un serveur TAK (port 8087 par défaut), fonctionne en 4G.
Limite connue : sur iPhone, le mode sans serveur demande une autorisation spéciale d'Apple
(« multicast entitlement ») ; le mode avec serveur marche sans.

## Fichiers importants

- `lib/main.dart` : l'écran carte.
- `lib/reglages.dart` : l'écran réglages (indicatif, équipe, mode de partage).
- `lib/partage.dart` : envoi de ma position toutes les 10 s, liste des camarades.
- `lib/cot.dart` : lecture et écriture des messages CoT.
- `lib/reseau/` : les deux modes de liaison (Wi-Fi local, serveur).
- `test/` : les tests automatiques (`flutter test`).
- `pubspec.yaml` : la liste des briques utilisées (carte, GPS).
- `android/` et `ios/` : réglages propres à chaque téléphone (autorisations GPS, nom de l'appli).

## Lancer l'appli (pour un développeur)

    flutter pub get
    flutter run

Les fonds IGN viennent du service gratuit de la Géoplateforme (data.geopf.fr), sans clé.

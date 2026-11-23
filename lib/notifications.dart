// Notifications du téléphone : alerte « Ennemi signalé » DISCRÈTE (vibration
// seulement, jamais de son), même écran éteint, et demande des autorisations au premier lancement.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _plugin = FlutterLocalNotificationsPlugin();
bool _pret = false;
var _numero = 0;

// Sur Android, le son d'un canal ne peut plus changer une fois créé : ce canal
// est donc créé d'emblée sans son.
final _canalEnnemis = AndroidNotificationDetails(
  'ennemis_vibreur',
  'Ennemis signalés',
  channelDescription:
      'Vibration quand un camarade signale un ennemi (jamais de son)',
  importance: Importance.max,
  priority: Priority.high,
  category: AndroidNotificationCategory.alarm,
  color: Color(0xFFC62828),
  playSound: false,
  silent: false,
  enableVibration: true,
  vibrationPattern: Int64List.fromList([0, 400, 200, 400, 200, 400]),
  ticker: 'Ennemi signalé',
);

Future<void> initialiserNotifications() async {
  if (kIsWeb || _pret) return;
  try {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _pret = true;
  } catch (_) {
    // Pas de notifications sur cet appareil : l'appli marche quand même.
  }
}

/// Demande au téléphone le droit d'afficher des notifications.
Future<void> demanderNotifications() async {
  await initialiserNotifications();
  if (!_pret) return;
  try {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: false, badge: false);
  } catch (_) {}
}

Future<void> notifierEnnemi(String titre, String texte) async {
  await initialiserNotifications();
  if (!_pret) return;
  try {
    await _plugin.show(
      id: 1000 + (_numero++ % 50),
      title: titre,
      body: texte,
      notificationDetails: NotificationDetails(
        android: _canalEnnemis,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: false,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
    );
  } catch (_) {}
}

/// Au premier lancement : explique pourquoi MUFASA a besoin de la position
/// et des notifications, puis demande les autorisations au téléphone.
Future<void> expliquerAutorisations(BuildContext context) async {
  if (kIsWeb) return;
  final p = await SharedPreferences.getInstance();
  if (p.getBool('autorisationsExpliquees') ?? false) return;
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.verified_user_outlined, size: 40),
      title: const Text('Autorisations'),
      content: const Text(
        'MUFASA va te demander deux autorisations :\n\n'
        '• Ta position : pour la partager avec la compagnie, y compris '
        'écran éteint. Une notification « MUFASA partage ta position » '
        'reste affichée tant que l\'appli tourne.\n\n'
        '• Les notifications : pour te prévenir quand un ennemi est '
        'signalé, même écran éteint. Discrètes : vibration seulement, '
        'jamais de son.\n\n'
        'Pour économiser la batterie, ta position est envoyée moins '
        'souvent quand tu ne bouges pas. Pour tout arrêter : ferme l\'appli.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Continuer'),
        ),
      ],
    ),
  );
  var droit = await Geolocator.checkPermission();
  if (droit == LocationPermission.denied) {
    droit = await Geolocator.requestPermission();
  }
  await demanderNotifications();
  await p.setBool('autorisationsExpliquees', true);
}

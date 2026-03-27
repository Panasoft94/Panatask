// ignore_for_file: unused_local_variable

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:panatask/pages/home.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Notification and Timezone imports
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

// Global instance for the notification plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Global navigator key to handle notification taps
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Callback invoked when user taps a notification
void onDidReceiveNotificationResponse(NotificationResponse response) {
  debugPrint('Notification tapped: ${response.payload}');
  // payload format: "TaskID|<id>"
  // Navigation can be handled from home page via stream or simple approach
}

Future<void> main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone database
  tz.initializeTimeZones();
  try {
    final currentTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone.identifier));
  } catch (e) {
    debugPrint('Could not get local timezone: $e');
  }

  // --- Initialize the notification plugin BEFORE runApp ---
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/launch_icon');

  const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
  );

  // Create the Android notification channel explicitly
  if (Platform.isAndroid) {
    const AndroidNotificationChannel dailyChannel = AndroidNotificationChannel(
      'daily_reminder_channel',
      'Rappel Quotidien',
      description: 'Rappels quotidiens pour les tâches',
      importance: Importance.max,
    );
    const AndroidNotificationChannel singleChannel = AndroidNotificationChannel(
      'your_channel_id',
      'your_channel_name',
      description: 'your_channel_description',
      importance: Importance.max,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(dailyChannel);
    await androidPlugin?.createNotificationChannel(singleChannel);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panatask',
      navigatorKey: navigatorKey,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('fr'), // fr
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(title: 'Panatask'),
    );
  }
}

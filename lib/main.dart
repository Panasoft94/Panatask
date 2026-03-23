// ignore_for_file: unused_local_variable

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:panatask/data/db_helper.dart';
import 'package:panatask/pages/aide.dart';
import 'package:panatask/pages/apropos.dart';
import 'package:panatask/pages/parametres_page.dart'; // Ajout de l'import
import 'package:panatask/pages/backup_db.dart';
import 'package:date_field/date_field.dart';
import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:permission_handler/permission_handler.dart'; // Ajout de l'import pour les permissions

// Notification and Timezone imports
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

// Global instance for the notification plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone database
  tz.initializeTimeZones();
  try {
    final currentTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone.identifier));
  } catch (e) {
    print('Could not get local timezone: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panatask',
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

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _tasks = [];
  final _titreController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  DateTime selectedEndDate = DateTime.now(); // Date de fin de la tâche, ajoutée
  final _formkey = GlobalKey<FormState>();
  bool _isLoading = false;
  List<Map<String, dynamic>> _filteredTasks = [];
  final _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();

    // Demander les permissions au démarrage après que le widget soit entièrement construit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermission();
    });

    _refreshTasks();
    _filteredTasks = _tasks;
    _searchController.addListener(_filterTasks);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  Future<void> _requestNotificationPermission() async {
    // Vérifie et demande la permission de notification pour toutes les plateformes
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      PermissionStatus status = await Permission.notification.status;

      if (status.isPermanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Permission de notification requise pour les rappels. Veuillez l\'autoriser dans les paramètres de l\'application.'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Ouvrir les paramètres',
                onPressed: () {
                  openAppSettings();
                },
              ),
            ),
          );
        }
        return;
      }

      if (!status.isGranted) {
        // Demander la permission
        status = await Permission.notification.request();

        if (!status.isGranted && mounted) {
          // Afficher un message si l'utilisateur refuse
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(
                'Permission de notification refusée. Les rappels ne fonctionneront pas.'),
                backgroundColor: Colors.orange),
          );
        }
      }
    }
  }


  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/launch_icon');

    final DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (
          NotificationResponse notificationResponse) async {
        final String? payload = notificationResponse.payload;
        if (payload != null) {
          debugPrint('Notification tapée avec payload : $payload');
        }
      },
    );

    if (Platform.isAndroid) {
      // Pour les API Android plus récentes (33+), on demande aussi via le plugin FLNP
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    }
  }

  // Nouvelle fonction pour planifier les notifications quotidiennes dans un intervalle
  Future<void> _scheduleDailyNotificationsBetweenDates(int id, String title,
      String body, DateTime startDate, DateTime endDate) async {
    final int hour = startDate.hour;
    final int minute = startDate.minute;
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    // Initialiser la première occurrence à la date de début définie
    DateTime currentDay = DateTime(
        startDate.year, startDate.month, startDate.day, hour, minute);

    // Si l'occurrence sur la date de début est déjà passée par rapport à maintenant, 
    // on cherche la prochaine occurrence (aujourd'hui plus tard ou demain)
    if (currentDay.isBefore(DateTime.now())) {
      DateTime todayAtTime = DateTime(DateTime
          .now()
          .year, DateTime
          .now()
          .month, DateTime
          .now()
          .day, hour, minute);
      if (todayAtTime.isBefore(DateTime.now())) {
        currentDay = todayAtTime.add(const Duration(days: 1));
      } else {
        currentDay = todayAtTime;
      }
    }

    // Si après ajustement on dépasse déjà la date de fin, on ne planifie rien
    if (currentDay.isAfter(endDate)) {
      debugPrint(
          "Aucune notification planifiée car la date de fin est déjà passée pour l'heure donnée.");
      return;
    }

    const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
      'daily_reminder_channel', 'Rappel Quotidien',
      channelDescription: 'Rappels quotidiens pour les tâches',
      importance: Importance.max, priority: Priority.high, ticker: 'ticker',
    );
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true),
    );

    int baseId = id * 1000;
    int dayCount = 0;

    // Planifier chaque jour jusqu'à la date de fin (incluse si l'heure correspond)
    while (currentDay.isBefore(endDate.add(const Duration(minutes: 1)))) {
      final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(
          currentDay, tz.local);
      int uniqueDayId = baseId + dayCount;

      try {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          uniqueDayId,
          title,
          body,
          tzScheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'TaskID|$id',
        );
        dayCount++;
      } catch (e) {
        debugPrint(
            'Error scheduling daily notification for task $id on $currentDay: $e');
      }

      currentDay = currentDay.add(const Duration(days: 1));
      if (dayCount > 365) break; // Limite de sécurité (1 an)
    }
    debugPrint(
        '$dayCount notifications journalières planifiées pour la tâche $id');
  }

  void _addTask() async {
    final titre = _titreController.text;
    final description = _descriptionController.text;
    final String dateForDb = DateFormat('yyyy-MM-dd HH:mm').format(
        selectedDate);
    final String heureForDb = DateFormat('HH:mm').format(selectedDate);
    final String dateFinForDb = DateFormat('yyyy-MM-dd HH:mm').format(
        selectedEndDate); // Ajout

    final newTaskId = await DbHelper.insert(
        titre, description, dateForDb, heureForDb,
        dateFinForDb); // Mise à jour de l'appel

    if (newTaskId > 0) {
      // Déterminer s'il s'agit d'une tâche à répétition journalière (plus d'un jour de différence)
      if (selectedEndDate.isAfter(selectedDate.add(const Duration(days: 1))) ||
          selectedDate.day != selectedEndDate.day) {
        _scheduleDailyNotificationsBetweenDates(
            newTaskId, "Rappel quotidien de tâche: $titre", description,
            selectedDate, selectedEndDate);
      } else if (selectedDate.isAfter(DateTime.now())) {
        // Sinon, planification d'une notification unique
        _scheduleNotificationSingle(
            newTaskId, "Rappel de tâche: $titre", description, selectedDate);
      }
    }
    _refreshTasks();
  }

  void _refreshTasks() async {
    final tasks = await DbHelper.getTasks();
    setState(() {
      _tasks = tasks;
      _filteredTasks = _searchController.text.isEmpty
          ? _tasks
          : _tasks.where((task) {
        final query = _searchController.text.toLowerCase();
        final titre = task['titre'].toString().toLowerCase();
        final date = task['date'].toString().toLowerCase();
        return titre.contains(query) || date.contains(query);
      }).toList();
    });
  }

  void _updateTask(int id, int currentStatus) async {
    final newStatus = currentStatus == 0 ? 1 : 0;
    await DbHelper.update(id, newStatus);

    if (newStatus == 1) {
      _cancelNotification(id);
    } else {
      final task = _tasks.firstWhere((t) => t['id'] == id, orElse: () => {});
      if (task.isNotEmpty) {
        try {
          DateTime taskDate = DateFormat('yyyy-MM-dd HH:mm').parse(
              task['date']);
          DateTime taskEndDate = DateFormat('yyyy-MM-dd HH:mm').parse(
              task['date_fin']);

          if (taskEndDate.isAfter(taskDate.add(const Duration(days: 1))) ||
              taskDate.day != taskEndDate.day) {
            // Reprendre la planification quotidienne
            _scheduleDailyNotificationsBetweenDates(
                id, "Rappel quotidien: ${task['titre']}", task['description'],
                taskDate, taskEndDate);
          } else if (taskDate.isAfter(DateTime.now())) {
            // Reprendre la planification simple
            _scheduleNotificationSingle(
                id, "Rappel: ${task['titre']}", task['description'], taskDate);
          }
        } catch (e) {
          print("Error parsing date for rescheduling: $e");
        }
      }
    }
    _refreshTasks();
  }

  void _updateTaskInfo(int id, String titre, String description,
      DateTime newSelectedDate, DateTime newSelectedEndDate) async {
    // Mise à jour de la signature
    final dateString = DateFormat('yyyy-MM-dd HH:mm').format(newSelectedDate);
    final dateFinString = DateFormat('yyyy-MM-dd HH:mm').format(
        newSelectedEndDate); // Ajout
    await DbHelper.updateTask(id, titre, description, dateString,
        dateFinString); // Mise à jour de l'appel

    await _cancelNotification(
        id); // Annuler les anciennes notifications (récurrentes ou simples)

    // Nouvelle logique de planification après mise à jour
    if (newSelectedEndDate.isAfter(
        newSelectedDate.add(const Duration(days: 1))) ||
        newSelectedDate.day != newSelectedEndDate.day) {
      _scheduleDailyNotificationsBetweenDates(
          id, "$titre", description, newSelectedDate,
          newSelectedEndDate);
    } else if (newSelectedDate.isAfter(DateTime.now())) {
      _scheduleNotificationSingle(
          id, "Mise à jour: $titre", description, newSelectedDate);
    }

    _refreshTasks();
  }

  void _deleteTask(int id) async {
    await DbHelper.delete(id);
    await _cancelNotification(id);
    _refreshTasks();
  }

  void _resetDatabase() async {
    await DbHelper.resetDatabase();
    // Utiliser cancelAll est sûr ici pour la réinitialisation complète
    await flutterLocalNotificationsPlugin.cancelAll();
    _refreshTasks();
  }

  // Logique de planification simple
  Future<void> _scheduleNotificationSingle(int id, String title, String body,
      DateTime scheduledDateTime) async {
    if (scheduledDateTime.isBefore(DateTime.now())) {
      print(
          "Notification time $scheduledDateTime is in the past. Not scheduling.");
      return;
    }
    final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(
        scheduledDateTime, tz.local);
    const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
      'your_channel_id', 'your_channel_name',
      channelDescription: 'your_channel_description',
      importance: Importance.max, priority: Priority.high, ticker: 'ticker',
    );
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true),
    );
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id, title, body, tzScheduledDate, notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'TaskID|$id',
      );
    } catch (e) {
      print('Error scheduling notification for task $id: $e');
    }
  }

  Future<void> _cancelNotification(int id) async {
    // Annuler la notification simple (ID principal)
    await flutterLocalNotificationsPlugin.cancel(id);

    // Annuler toutes les notifications quotidiennes planifiées (jusqu'à 367 jours max)
    int baseId = id * 1000;
    for (int i = 0; i < 367; i++) {
      await flutterLocalNotificationsPlugin.cancel(baseId + i);
    }
  }

  PageRouteBuilder _slideTransition(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(
              animation),
          child: child,
        );
      },
    );
  }

  void _filterTasks() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTasks = _searchController.text.isEmpty
          ? _tasks
          : _tasks.where((task) {
        final titre = task['titre'].toString().toLowerCase();
        final date = task['date'].toString().toLowerCase();
        return titre.contains(query) || date.contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    _titreController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Widget _buildDetailRow(
      {required BuildContext context, required IconData icon, required String title, required String value, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme
                  .of(context)
                  .colorScheme
                  .primary
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Theme
                .of(context)
                .colorScheme
                .primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTaskDetailsBottomSheet(Map<String, dynamic> task) async {
    final bool isTaskDone = task['status'] == 1;
    DateTime taskDate;
    try {
      taskDate = DateFormat('yyyy-MM-dd HH:mm').parse(task['date']);
    } catch (e) {
      taskDate = DateTime.now();
    }

    DateTime? taskEndDate;
    try {
      if (task['date_fin'] != null && task['date_fin']
          .toString()
          .isNotEmpty) {
        taskEndDate = DateFormat('yyyy-MM-dd HH:mm').parse(task['date_fin']);
      }
    } catch (_) {}

    DateTime? taskCreationDate;
    try {
      if (task['creation'] != null && task['creation']
          .toString()
          .isNotEmpty) {
        taskCreationDate = DateTime.parse(task['creation']);
      }
    } catch (_) {}

    String durationText = "Non spécifiée";
    if (taskEndDate != null) {
      Duration duration = taskEndDate.difference(taskDate);
      if (duration.isNegative) {
        durationText = "Invalide";
      } else {
        int days = duration.inDays;
        int hours = duration.inHours.remainder(24);
        int minutes = duration.inMinutes.remainder(60);
        List<String> parts = [];
        if (days > 0) parts.add('$days j');
        if (hours > 0) parts.add('$hours h');
        if (minutes > 0 || (days == 0 && hours == 0)) parts.add('$minutes min');
        durationText = parts.join(' ');
      }
    }

    String remainingDurationText = "N/A";
    Color? remainingColor;
    if (taskEndDate != null) {
      if (isTaskDone) {
        remainingDurationText = "Tâche terminée";
        remainingColor = Colors.green.shade700;
      } else {
        DateTime now = DateTime.now();
        Duration remaining = taskEndDate.difference(now);
        if (remaining.isNegative) {
          remainingDurationText = "Délai dépassé";
          remainingColor = Colors.red.shade700;
        } else {
          int days = remaining.inDays;
          int hours = remaining.inHours.remainder(24);
          int minutes = remaining.inMinutes.remainder(60);
          List<String> parts = [];
          if (days > 0) parts.add('$days j');
          if (hours > 0) parts.add('$hours h');
          if (minutes > 0 || (days == 0 && hours == 0)) parts.add(
              '$minutes min');
          remainingDurationText = parts.join(' ');
          remainingColor = days == 0 ? Colors.orange.shade700 : Colors.blueGrey;
        }
      }
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          task['titre'].toString(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: (isTaskDone ? Colors.green : Colors.orange)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isTaskDone ? "Terminée" : "En cours",
                          style: TextStyle(
                            color: isTaskDone ? Colors.green.shade700 : Colors
                                .orange.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery
                        .of(context)
                        .size
                        .height * 0.6,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        if (task['description'] != null && task['description']
                            .toString()
                            .isNotEmpty)
                          _buildDetailRow(
                            context: context,
                            icon: Icons.notes_rounded,
                            title: "DESCRIPTION",
                            value: task['description'].toString(),
                          ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailRow(
                                context: context,
                                icon: Icons.calendar_today_rounded,
                                title: "RAPPEL",
                                value: DateFormat('dd MMM yyyy\nHH:mm', 'fr_FR')
                                    .format(taskDate),
                              ),
                            ),
                            Expanded(
                              child: _buildDetailRow(
                                context: context,
                                icon: Icons.event_available_rounded,
                                title: "ÉCHÉANCE",
                                value: taskEndDate != null
                                    ? DateFormat('dd MMM yyyy\nHH:mm', 'fr_FR')
                                    .format(taskEndDate)
                                    : "Non définie",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailRow(
                                context: context,
                                icon: Icons.timer_outlined,
                                title: "DURÉE TOTALE",
                                value: durationText,
                              ),
                            ),
                            Expanded(
                              child: _buildDetailRow(
                                context: context,
                                icon: Icons.hourglass_top_rounded,
                                title: "RESTANT",
                                value: remainingDurationText,
                                valueColor: remainingColor,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _buildDetailRow(
                          context: context,
                          icon: Icons.history_rounded,
                          title: "CRÉÉE LE",
                          value: taskCreationDate != null
                              ? DateFormat('EEEE, dd MMMM yyyy HH:mm', 'fr_FR')
                              .format(taskCreationDate)
                              : "N/A",
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Row(
                    children: [
                      if (!isTaskDone)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showMyDialog(task);
                            },
                            icon: const Icon(Icons.edit_rounded, size: 22, color: Colors.white),
                            label: const Text("MODIFIER"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                          ),
                        ),
                      if (!isTaskDone) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, size: 22, color: Colors.white),
                          label: const Text("FERMER"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade600,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _showMyDialog(Map<String, dynamic> task) async {
    _titreController.text = task['titre'];
    _descriptionController.text = task['description'];
    try {
      selectedDate = DateFormat('yyyy-MM-dd HH:mm').parse(task['date']);
    } catch (e) {
      selectedDate = DateTime.now();
    }
    try {
      selectedEndDate = DateFormat('yyyy-MM-dd HH:mm').parse(task['date_fin']);
    } catch (e) {
      selectedEndDate = selectedDate.add(const Duration(hours: 1));
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery
                .of(context)
                .viewInsets
                .bottom,
            top: 16.0,
            left: 16.0,
            right: 16.0,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_note_rounded, color: Colors.orange),
                  title: Text("Édition d'une tâche", style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none)),
                ),
                const SizedBox(height: 12),
                Form(
                  key: _formkey,
                  child: StatefulBuilder(
                      builder: (BuildContext context,
                          StateSetter setStateDialog) {
                        DateTime dialogSelectedDate = selectedDate;
                        DateTime dialogSelectedEndDate = selectedEndDate;

                        return Column(
                          children: [
                            TextFormField(
                              controller: _titreController,
                              maxLines: 3,
                              validator: (value) =>
                              (value == null || value
                                  .trim()
                                  .isEmpty) ? 'Le titre est requis' : null,
                              decoration: InputDecoration(
                                labelText: "Titre de la tâche",
                                prefixIcon: const Icon(Icons.title_rounded),
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 20, horizontal: 16),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30)),
                              ),
                              style: const TextStyle(
                                  decoration: TextDecoration.none),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _descriptionController,
                              minLines: 4,
                              maxLines: 6,
                              validator: (value) =>
                              (value == null || value
                                  .trim()
                                  .isEmpty)
                                  ? 'La description est requise'
                                  : null,
                              decoration: InputDecoration(
                                labelText: "Description de la tâche",
                                hintText: "Décris la tâche à accomplir",
                                prefixIcon: const Icon(
                                    Icons.description_rounded),
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 20, horizontal: 16),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30)),
                              ),
                              style: const TextStyle(
                                  decoration: TextDecoration.none),
                            ),
                            const SizedBox(height: 12),
                            // Date de rappel
                            DateTimeFormField(
                              decoration: InputDecoration(
                                label: const Text("Date de rappel"),
                                prefixIcon: const Icon(Icons.alarm_rounded),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              mode: DateTimeFieldPickerMode.dateAndTime,
                              lastDate: DateTime.now().add(
                                  const Duration(days: 365)),
                              initialPickerDateTime: dialogSelectedDate,
                              onChanged: (DateTime? value) {
                                if (value != null) {
                                  setStateDialog(() =>
                                  dialogSelectedDate = value);
                                  setState(() => selectedDate = value);
                                }
                              },
                              style: const TextStyle(
                                  decoration: TextDecoration.none),
                            ),
                            const SizedBox(height: 12),
                            // Champ Date de fin prévue
                            DateTimeFormField(
                              decoration: InputDecoration(
                                label: const Text("Date de fin prévue"),
                                prefixIcon: const Icon(
                                    Icons.event_note_rounded),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              mode: DateTimeFieldPickerMode.dateAndTime,
                              lastDate: DateTime.now().add(
                                  const Duration(days: 365)),
                              initialPickerDateTime: dialogSelectedEndDate,
                              onChanged: (DateTime? value) {
                                if (value != null) {
                                  setStateDialog(() =>
                                  dialogSelectedEndDate = value);
                                  setState(() => selectedEndDate = value);
                                }
                              },
                              style: const TextStyle(
                                  decoration: TextDecoration.none),
                              validator: (value) {
                                if (value != null &&
                                    value.isBefore(dialogSelectedDate)) {
                                  return 'La date de fin ne peut pas être avant la date de rappel';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isLoading ? null : () async {
                                      if (_formkey.currentState!.validate()) {
                                        setState(() => _isLoading = true);
                                        _updateTaskInfo(
                                            task['id'], _titreController.text,
                                            _descriptionController.text,
                                            dialogSelectedDate,
                                            dialogSelectedEndDate);
                                        Navigator.of(context).pop();
                                        _titreController.clear();
                                        _descriptionController.clear();
                                        ScaffoldMessenger
                                            .of(context)
                                            .showSnackBar(
                                          const SnackBar(content: Text(
                                              "✏️ Modification effectuée avec succès!",
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  decoration: TextDecoration
                                                      .none)),
                                            behavior: SnackBarBehavior.floating,
                                            backgroundColor: Colors.green,
                                            showCloseIcon: true,
                                          ),
                                        );
                                        setState(() => _isLoading = false);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20)),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                    icon: const Icon(Icons.save_rounded, color: Colors.white, size: 22),
                                    label: const Text("SAUVER", style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => Navigator.of(context).pop(),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20)),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                    icon: const Icon(Icons.cancel_outlined, color: Colors.white, size: 22),
                                    label: const Text("ANNULER", style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      }
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showMyDialogAdd() async {
    _titreController.clear();
    _descriptionController.clear();
    selectedDate = DateTime.now();
    selectedEndDate = DateTime.now().add(const Duration(hours: 1));

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery
                .of(context)
                .viewInsets
                .bottom,
            top: 16.0,
            left: 16.0,
            right: 16.0,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.task_alt_rounded, color: Colors.green),
                  title: Text("Création d'une tâche", style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none)),
                ),
                const SizedBox(height: 12),
                Form(
                  key: _formkey,
                  child: StatefulBuilder(
                      builder: (BuildContext context,
                          StateSetter setStateDialog) {
                        DateTime dialogSelectedDate = selectedDate;
                        DateTime dialogSelectedEndDate = selectedEndDate;

                        return Column(
                          children: [
                            TextFormField(
                              controller: _titreController,
                              minLines: 2,
                              maxLines: 3,
                              validator: (value) =>
                              (value == null || value
                                  .trim()
                                  .isEmpty) ? 'Le titre est requis' : null,
                              decoration: InputDecoration(
                                labelText: "Titre de la tâche",
                                hintText: "Ex. : Finaliser l’interface utilisateur",
                                prefixIcon: const Icon(Icons.title_rounded),
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 20, horizontal: 16),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30)),
                              ),
                              style: const TextStyle(
                                  decoration: TextDecoration.none),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _descriptionController,
                              minLines: 4,
                              maxLines: 6,
                              validator: (value) =>
                              (value == null || value
                                  .trim()
                                  .isEmpty)
                                  ? 'La description est requise'
                                  : null,
                              decoration: InputDecoration(
                                labelText: "Description de la tâche",
                                hintText: "Détaille les étapes ou les objectifs de la tâche",
                                prefixIcon: const Icon(
                                    Icons.description_rounded),
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 20, horizontal: 16),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30)),
                              ),
                              style: const TextStyle(
                                  decoration: TextDecoration.none),
                            ),
                            const SizedBox(height: 12),
                            // Date de rappel
                            DateTimeFormField(
                              decoration: InputDecoration(
                                label: const Text("Date de rappel"),
                                prefixIcon: const Icon(Icons.alarm_rounded),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              mode: DateTimeFieldPickerMode.dateAndTime,
                              lastDate: DateTime.now().add(
                                  const Duration(days: 365)),
                              initialPickerDateTime: dialogSelectedDate,
                              onChanged: (DateTime? value) {
                                if (value != null) {
                                  setStateDialog(() =>
                                  dialogSelectedDate = value);
                                  setState(() => selectedDate = value);
                                }
                              },
                              style: const TextStyle(
                                  decoration: TextDecoration.none),
                            ),
                            const SizedBox(height: 12),
                            // Champ Date de fin prévue
                            DateTimeFormField(
                              decoration: InputDecoration(
                                label: const Text("Date de fin prévue"),
                                prefixIcon: const Icon(
                                    Icons.event_note_rounded),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              mode: DateTimeFieldPickerMode.dateAndTime,
                              lastDate: DateTime.now().add(
                                  const Duration(days: 365)),
                              initialPickerDateTime: dialogSelectedEndDate,
                              onChanged: (DateTime? value) {
                                if (value != null) {
                                  setStateDialog(() =>
                                  dialogSelectedEndDate = value);
                                  setState(() => selectedEndDate = value);
                                }
                              },
                              style: const TextStyle(
                                  decoration: TextDecoration.none),
                              validator: (value) {
                                if (value != null &&
                                    value.isBefore(dialogSelectedDate)) {
                                  return 'La date de fin ne peut pas être avant la date de rappel';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isLoading ? null : () async {
                                      if (_formkey.currentState!.validate()) {
                                        setState(() => _isLoading = true);
                                        setState(() {
                                          selectedDate = dialogSelectedDate;
                                          selectedEndDate =
                                              dialogSelectedEndDate;
                                        });
                                        _addTask();
                                        Navigator.of(context).pop();
                                        _titreController.clear();
                                        _descriptionController.clear();
                                        ScaffoldMessenger
                                            .of(context)
                                            .showSnackBar(
                                          const SnackBar(content: Text(
                                              "✅ La tâche a été ajoutée avec succès !",
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  decoration: TextDecoration
                                                      .none)),
                                            behavior: SnackBarBehavior.floating,
                                            backgroundColor: Colors.green,
                                            showCloseIcon: true,
                                          ),
                                        );
                                        setState(() => _isLoading = false);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20)),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                    icon: const Icon(Icons.save_rounded, color: Colors.white, size: 22),
                                    label: const Text("VALIDER", style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => Navigator.of(context).pop(),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20)),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                    icon: const Icon(Icons.cancel_outlined, color: Colors.white, size: 22),
                                    label: const Text("ANNULER", style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      }
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showMyDialogConfirmation() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.warning_amber_rounded, color: Colors.orange),
            title: Text('Confirmation de la réinitialisation', style: TextStyle(
                fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
          ),
          content: const SingleChildScrollView(
            child: ListBody(children: [
              Text(
                  'Êtes-vous sûr de vouloir réinitialiser la base de données ?',
                  style: TextStyle(decoration: TextDecoration.none))
            ]),
          ),
          actionsAlignment: MainAxisAlignment.end,
          actions: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _resetDatabase();
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text(
                          "🧹 La base de données a été réinitialisée !",
                          style: TextStyle(color: Colors.white,
                              decoration: TextDecoration.none)),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.green,
                        showCloseIcon: true,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  icon: const Icon(Icons.restart_alt, color: Colors.white, size: 20),
                  label: const Text("CONFIRMER", style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  icon: const Icon(Icons.cancel_outlined, color: Colors.white, size: 20),
                  label: const Text("ANNULER", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _showMyDialogSuppression(int id) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
                Icons.delete_forever_rounded, color: Colors.redAccent),
            title: Text('Confirmation de la suppression', style: TextStyle(
                fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
          ),
          content: const SingleChildScrollView(
            child: ListBody(children: [
              Text('Êtes-vous sûr de vouloir supprimer cette tâche ?',
                  style: TextStyle(decoration: TextDecoration.none))
            ]),
          ),
          actionsAlignment: MainAxisAlignment.end,
          actions: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _deleteTask(id);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text(
                          "🗑️ La tâche a été supprimée avec succès !",
                          style: TextStyle(color: Colors.white,
                              decoration: TextDecoration.none)),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.red,
                        showCloseIcon: true,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  icon: const Icon(
                      Icons.check_circle_outline, color: Colors.white, size: 20),
                  label: const Text("CONFIRMER", style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  icon: const Icon(Icons.cancel_outlined, color: Colors.white, size: 20),
                  label: const Text("ANNULER", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        toolbarHeight: 65,
        backgroundColor: Colors.green,
        elevation: 2,
        scrolledUnderElevation: 2,
        centerTitle: false,
        title: const Text(
          "Panatask",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () =>
                Navigator.push(context, _slideTransition(const AidePage())),
            icon: const Icon(Icons.help_outline_rounded, color: Colors.white),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
            itemBuilder: (context) =>
            [
              const PopupMenuItem<String>(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text("Réinitialiser la base"),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'backup',
                child: Row(
                  children: [
                    Icon(Icons.backup_rounded, color: Colors.blueGrey),
                    SizedBox(width: 8),
                    Text("Sauvegarde/Restauration"),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'parametres',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, color: Colors.blueGrey),
                    SizedBox(width: 8),
                    Text("Paramètres"),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'reset') {
                _showMyDialogConfirmation();
              } else if (value == 'backup') {
                Navigator.push(context, _slideTransition(const BackupDbPage())).then((_) => _refreshTasks());
              } else if (value == 'parametres') {
                Navigator.push(context, _slideTransition(const ParametresPage()));
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showMyDialogAdd,
        backgroundColor: Colors.green,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        label: const Text("NOUVELLE TÂCHE", style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Rechercher une tâche...",
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                    prefixIcon: Icon(
                        Icons.search_rounded, color: Colors.green.shade400),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        FocusScope.of(context).unfocus();
                        _filterTasks();
                      },
                    )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 20),
                  ),
                  onChanged: (v) => _filterTasks(),
                ),
              ),
            ),
            Expanded(
              child: _filteredTasks.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: _filteredTasks.length,
                itemBuilder: (context, index) {
                  final task = _filteredTasks[index];
                  final bool isTaskDone = task['status'] == 1;
                  DateTime taskDate;
                  try {
                    taskDate =
                        DateFormat('yyyy-MM-dd HH:mm').parse(task['date']);
                  } catch (e) {
                    taskDate = DateTime.now();
                  }

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isTaskDone ? Colors.green.shade100 : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: isTaskDone ? Border.all(color: Colors.green.shade200, width: 1) : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _showTaskDetailsBottomSheet(task),
                        onLongPress: () => _showMyDialogSuppression(task['id']),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  _updateTask(task['id'], task['status']);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isTaskDone ? Colors.green : Colors
                                        .transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isTaskDone ? Colors.green : Colors
                                          .grey.shade300,
                                      width: 2,
                                    ),
                                  ),
                                  child: isTaskDone
                                      ? const Icon(Icons.check, size: 18,
                                      color: Colors.white)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task['titre'].toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isTaskDone ? Colors.green.shade900 : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        decoration: null,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                            Icons.access_time_rounded, size: 14,
                                            color: isTaskDone ? Colors.green.shade700 : Colors.green.shade400),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateFormat('HH:mm', 'fr_FR').format(
                                              taskDate),
                                          style: TextStyle(
                                            color: isTaskDone ? Colors.green.shade700 : Colors.grey.shade600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(Icons.calendar_month_rounded,
                                            size: 14,
                                            color: isTaskDone ? Colors.grey
                                                .shade400 : Colors.blueGrey
                                                .shade300),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateFormat('dd MMM', 'fr_FR').format(
                                              taskDate),
                                          style: TextStyle(
                                            color: isTaskDone ? Colors.grey
                                                .shade400 : Colors.grey
                                                .shade600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded,
                                  color: Colors.grey.shade300),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt_outlined, size: 80, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(
            "Aucune tâche pour le moment",
            style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

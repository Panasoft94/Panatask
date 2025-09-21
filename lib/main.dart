// ignore_for_file: unused_local_variable

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:panatask/data/db_helper.dart';
import 'package:panatask/pages/aide.dart';
import 'package:panatask/pages/apropos.dart';
import 'package:panatask/pages/parametres_page.dart'; // Ajout de l'import
import 'package:date_field/date_field.dart';
import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Notification and Timezone imports
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_native_timezone/flutter_native_timezone.dart';

// Global instance for the notification plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone database
  tz.initializeTimeZones();
  try {
    final String currentTimeZone = await FlutterNativeTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone));
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
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
        final String? payload = notificationResponse.payload;
        if (payload != null) {
          debugPrint('Notification tapée avec payload : $payload');
        }
      },
    );

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    }
  }

  void _addTask() async {
    final titre = _titreController.text;
    final description = _descriptionController.text;
    final String dateForDb = DateFormat('yyyy-MM-dd HH:mm').format(selectedDate);
    final String heureForDb = DateFormat('HH:mm').format(selectedDate);

    final newTaskId = await DbHelper.insert(titre, description, dateForDb, heureForDb);

    if (newTaskId > 0) {
      if (selectedDate.isAfter(DateTime.now())) {
        _scheduleNotification(newTaskId, "Rappel de tâche: $titre", description, selectedDate);
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
          DateTime taskDate = DateFormat('yyyy-MM-dd HH:mm').parse(task['date']);
          if (taskDate.isAfter(DateTime.now())) {
            _scheduleNotification(id, "Rappel: \${task['titre']}", task['description'], taskDate);
          }
        } catch (e) {
          print("Error parsing date for rescheduling: $e");
        }
      }
    }
    _refreshTasks();
  }

  void _updateTaskInfo(int id, String titre, String description, DateTime newSelectedDate) async {
    final dateString = DateFormat('yyyy-MM-dd HH:mm').format(newSelectedDate);
    await DbHelper.updateTask(id, titre, description, dateString);

    await _cancelNotification(id);
    if (newSelectedDate.isAfter(DateTime.now())) {
      _scheduleNotification(id, "Mise à jour: $titre", description, newSelectedDate);
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
    await flutterLocalNotificationsPlugin.cancelAll();
    _refreshTasks();
  }

  Future<void> _scheduleNotification(int id, String title, String body, DateTime scheduledDateTime) async {
    if (scheduledDateTime.isBefore(DateTime.now())) {
      print("Notification time $scheduledDateTime is in the past. Not scheduling.");
      return;
    }
    final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(scheduledDateTime, tz.local);
    const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
      'your_channel_id', 'your_channel_name',
      channelDescription: 'your_channel_description',
      importance: Importance.max, priority: Priority.high, ticker: 'ticker',
    );
    const DarwinNotificationDetails darwinNotificationDetails = DarwinNotificationDetails(
      presentAlert: true, presentBadge: true, presentSound: true,
    );
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails, iOS: darwinNotificationDetails, macOS: darwinNotificationDetails,
    );
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id, title, body, tzScheduledDate, notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'TaskID|$id',
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      print('Error scheduling notification for task $id: $e');
    }
  }

  Future<void> _cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
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

  Widget _buildDetailRow({required BuildContext context, required IconData icon, required String title, required String value, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: <TextSpan>[
                  TextSpan(text: '$title ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, decoration: TextDecoration.none, fontSize: 16)),
                  TextSpan(text: value, style: TextStyle(color: valueColor ?? Colors.black54, decoration: TextDecoration.none, fontSize: 16)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTaskDetailsDialog(Map<String, dynamic> task) async {
    final bool isTaskDone = task['status'] == 1;
    DateTime taskDate;
    try {
      taskDate = DateFormat('yyyy-MM-dd HH:mm').parse(task['date']);
    } catch (e) {
      taskDate = DateTime.now();
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          title: Row(
            children: [
              Icon(Icons.article_outlined, color: Theme.of(dialogContext).colorScheme.primary, size: 28),
              const SizedBox(width: 10),
              const Text("Détails de la Tâche", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87, decoration: TextDecoration.none)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildDetailRow(context: dialogContext, icon: Icons.title_rounded, title: "Titre:", value: task['titre'].toString()),
                const Divider(height: 16, thickness: 0.5),
                _buildDetailRow(context: dialogContext, icon: Icons.description_outlined, title: "Description:", value: task['description'].toString()),
                const Divider(height: 16, thickness: 0.5),
                _buildDetailRow(context: dialogContext, icon: Icons.calendar_today_rounded, title: "Date:", value: DateFormat('EEEE, dd MMMM yyyy HH:mm', 'fr_FR').format(taskDate)),
                const Divider(height: 16, thickness: 0.5),
                _buildDetailRow(
                  context: dialogContext,
                  icon: isTaskDone ? Icons.check_circle_outline_rounded : Icons.pending_actions_rounded,
                  title: "Statut:",
                  value: isTaskDone ? "Terminée" : "En cours",
                  valueColor: isTaskDone ? Colors.green.shade700 : Colors.orange.shade700,
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.end,
          actions: <Widget>[
            if (!isTaskDone)
              ElevatedButton.icon(
                icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
                label: const Text("Modifier", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _showMyDialog(task);
                },
              ),
            if (!isTaskDone) const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              label: const Text("Fermer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showMyDialog(Map<String, dynamic> task) async {
    _titreController.text = task['titre'];
    _descriptionController.text = task['description'];
    try {
      selectedDate = DateFormat('yyyy-MM-dd HH:mm').parse(task['date']);
    } catch (e) {
      selectedDate = DateTime.now();
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_note_rounded, color: Colors.orange),
            title: Text("Édition d\\'une tâche", style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _formkey,
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setStateDialog) {
                  DateTime dialogSelectedDate = selectedDate;
                  return Column(
                    children: [
                      TextFormField(
                        controller: _titreController,
                        maxLines: 3,
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Le titre est requis' : null,
                        decoration: InputDecoration(
                          labelText: "Titre de la tâche",
                          prefixIcon: const Icon(Icons.title_rounded),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        style: const TextStyle(decoration: TextDecoration.none),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        minLines: 4,
                        maxLines: 6,
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'La description est requise' : null,
                        decoration: InputDecoration(
                          labelText: "Description de la tâche",
                          hintText: "Décris la tâche à accomplir",
                          prefixIcon: const Icon(Icons.description_rounded),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        style: const TextStyle(decoration: TextDecoration.none),
                      ),
                      const SizedBox(height: 12),
                      DateTimeFormField(
                        decoration: InputDecoration(
                          label: const Text("Date de réalisation"),
                          prefixIcon: const Icon(Icons.calendar_today_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        mode: DateTimeFieldPickerMode.dateAndTime,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialPickerDateTime: dialogSelectedDate,
                        onChanged: (DateTime? value) {
                          if (value != null) {
                            setStateDialog(() => dialogSelectedDate = value);
                            setState(() => selectedDate = value);
                          }
                        },
                        style: const TextStyle(decoration: TextDecoration.none),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : () async {
                                if (_formkey.currentState!.validate()) {
                                  setState(() => _isLoading = true);
                                  _updateTaskInfo(task['id'], _titreController.text, _descriptionController.text, dialogSelectedDate);
                                  Navigator.of(context).pop();
                                  _titreController.clear();
                                  _descriptionController.clear();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("✏️ Modification effectuée avec succès!", style: TextStyle(color: Colors.white, decoration: TextDecoration.none)),
                                      behavior: SnackBarBehavior.floating, backgroundColor: Colors.green, showCloseIcon: true,
                                    ),
                                  );
                                  setState(() => _isLoading = false);
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12)),
                              icon: const Icon(Icons.save_rounded, color: Colors.white),
                              label: const Text("Sauver", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12)),
                              icon: const Icon(Icons.cancel_outlined, color: Colors.white),
                              label: const Text("Annuler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }
              ),
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

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.task_alt_rounded, color: Colors.green),
            title: Text("Création d\\'une tâche", style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _formkey,
               child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setStateDialog) {
                  DateTime dialogSelectedDate = selectedDate;
                  return Column(
                    children: [
                      TextFormField(
                        controller: _titreController,
                        minLines: 2,
                        maxLines: 3,
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Le titre est requis' : null,
                        decoration: InputDecoration(
                          labelText: "Titre de la tâche", hintText: "Ex. : Finaliser l’interface utilisateur",
                          prefixIcon: const Icon(Icons.title_rounded), filled: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        style: const TextStyle(decoration: TextDecoration.none),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        minLines: 4,
                        maxLines: 6,
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'La description est requise' : null,
                        decoration: InputDecoration(
                          labelText: "Description de la tâche", hintText: "Détaille les étapes ou les objectifs de la tâche",
                          prefixIcon: const Icon(Icons.description_rounded), filled: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        style: const TextStyle(decoration: TextDecoration.none),
                      ),
                      const SizedBox(height: 12),
                      DateTimeFormField(
                        decoration: InputDecoration(
                          label: const Text("Date de réalisation"),
                          prefixIcon: const Icon(Icons.calendar_today_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        mode: DateTimeFieldPickerMode.dateAndTime,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialPickerDateTime: dialogSelectedDate,
                        onChanged: (DateTime? value) {
                          if (value != null) {
                            setStateDialog(() => dialogSelectedDate = value);
                            setState(() => selectedDate = value);
                          }
                        },
                        style: const TextStyle(decoration: TextDecoration.none),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : () async {
                                if (_formkey.currentState!.validate()) {
                                  setState(() => _isLoading = true);
                                  setState(() => selectedDate = dialogSelectedDate);
                                  _addTask();
                                  Navigator.of(context).pop();
                                  _titreController.clear();
                                  _descriptionController.clear();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("✅ La tâche a été ajoutée avec succès !", style: TextStyle(color: Colors.white, decoration: TextDecoration.none)),
                                      behavior: SnackBarBehavior.floating, backgroundColor: Colors.green, showCloseIcon: true,
                                    ),
                                  );
                                  setState(() => _isLoading = false);
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12)),
                              icon: const Icon(Icons.save_rounded, color: Colors.white),
                              label: const Text("Valider", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12)),
                              icon: const Icon(Icons.cancel_outlined, color: Colors.white),
                              label: const Text("Annuler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }
              ),
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
            title: Text('Confirmation de la réinitialisation', style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
          ),
          content: const SingleChildScrollView(
            child: ListBody(children: [Text('Êtes-vous sûr de vouloir réinitialiser la base de données ?', style: TextStyle(decoration: TextDecoration.none))]),
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
                      const SnackBar(content: Text("🧹 La base de données a été réinitialisée !", style: TextStyle(color: Colors.white, decoration: TextDecoration.none)),
                        behavior: SnackBarBehavior.floating, backgroundColor: Colors.green, showCloseIcon: true,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16)), // Reduced horizontal padding
                  icon: const Icon(Icons.restart_alt, color: Colors.white),
                  label: const Text("Confirmer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16)), // Reduced horizontal padding
                  icon: const Icon(Icons.cancel_outlined, color: Colors.white),
                  label: const Text("Annuler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
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
            leading: Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            title: Text('Confirmation de la suppression', style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
          ),
          content: const SingleChildScrollView(
            child: ListBody(children: [Text('Êtes-vous sûr de vouloir supprimer cette tâche ?', style: TextStyle(decoration: TextDecoration.none))]),
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
                      const SnackBar(content: Text("🗑️ La tâche a été supprimée avec succès !", style: TextStyle(color: Colors.white, decoration: TextDecoration.none)),
                        behavior: SnackBarBehavior.floating, backgroundColor: Colors.red, showCloseIcon: true,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                  label: const Text("Confirmer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
                  icon: const Icon(Icons.cancel_outlined, color: Colors.white),
                  label: const Text("Annuler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
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
      appBar: AppBar(
        backgroundColor: Colors.green,
        elevation: 6,
        toolbarHeight: 65,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, decoration: TextDecoration.none),
        ),
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AproposPage())),
            icon: const Icon(Icons.info_outline_rounded),
            color: Colors.white,
            tooltip: "À propos",
          ),
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AidePage())),
            icon: const Icon(Icons.help_outline_rounded),
            color: Colors.white,
            tooltip: "Aide",
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'reset',
                onTap: _showMyDialogConfirmation,
                child: const Row(
                  children: [
                    Icon(Icons.restart_alt, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text("Réinitialiser la base", style: TextStyle(decoration: TextDecoration.none)),
                  ],
                ),
              ),
              PopupMenuItem<String>( // Ajout du nouvel item "Paramètres"
                value: 'parametres',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ParametresPage()),
                  );
                },
                child: const Row(
                  children: [
                    Icon(Icons.settings_outlined, color: Colors.blueGrey), // Ou une autre couleur
                    SizedBox(width: 8),
                    Text("Paramètres", style: TextStyle(decoration: TextDecoration.none)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showMyDialogAdd,
        backgroundColor: Colors.green,
        tooltip: "Ajouter une tâche",
        child: const Icon(Icons.add_task_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Rechercher une tâche...",
                    prefixIcon: Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.primary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              FocusScope.of(context).unfocus();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                    ),
                  ),
                  style: const TextStyle(fontSize: 16, decoration: TextDecoration.none),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredTasks.length,
                itemBuilder: (context, index) {
                  final task = _filteredTasks[index];
                  final bool isTaskDone = task['status'] == 1;
                  DateTime taskDate;
                  try {
                    taskDate = DateFormat('yyyy-MM-dd HH:mm').parse(task['date']);
                  } catch(e) {
                    taskDate = DateTime.now();
                  }

                  return Card(
                    key: ValueKey(task['id']),
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showTaskDetailsDialog(task),
                      onLongPress: () => _showMyDialogSuppression(task['id']),
                      child: ListTile(
                        leading: Icon(
                          isTaskDone ? Icons.check_circle_outline_rounded : Icons.pending_actions_rounded,
                          color: isTaskDone ? Colors.green : Colors.orange,
                          size: 28,
                        ),
                        title: Text(
                          task['titre'].toString(),
                          style: TextStyle(
                            color: isTaskDone ? Colors.green.shade700 : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('EEEE, dd MMMM yyyy HH:mm', 'fr_FR').format(taskDate),
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                            color: isTaskDone ? Colors.green.shade600 : Colors.blueGrey,
                            fontSize: 13,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        trailing: Checkbox(
                          value: isTaskDone,
                          onChanged: (value) {
                            _updateTask(task['id'], task['status']);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(value == true ? "✅ Tâche terminée avec succès!" : "❌ Tâche réouverte!", style: const TextStyle(color: Colors.white, decoration: TextDecoration.none)),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: value == true ? Colors.green : Colors.orange,
                                showCloseIcon: true,
                              ),
                            );
                          },
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
}

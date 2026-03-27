// ignore_for_file: unused_local_variable

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:panatask/data/db_helper.dart';
import 'package:panatask/pages/aide.dart';
import 'package:panatask/pages/apropos.dart';
import 'package:panatask/pages/parametres_page.dart';
import 'package:panatask/pages/backup_db.dart';
import 'package:date_field/date_field.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:panatask/main.dart'; // To access the global notification plugin

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
  DateTime selectedEndDate = DateTime.now().add(const Duration(hours: 1));
  bool _isLoading = false;
  String _currentFilter = 'Toutes'; // Nouvel état pour le filtre rapide
  String _selectedPriority = 'Moyenne'; // Nouvel état pour la priorité
  final _formkey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _filteredTasks = [];
  final _searchController = TextEditingController();
  late AnimationController _animationController;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermission();
    });

    _refreshTasks();
    _searchController.addListener(_filterTasks);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animationController.forward();

    // Re-schedule all pending notifications on app start
    _rescheduleAllNotifications();
  }

  Future<void> _requestNotificationPermission() async {
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
        status = await Permission.notification.request();
        if (!status.isGranted && mounted) {
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
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
      // Request exact alarms permission for Android 12+
      await androidImplementation?.requestExactAlarmsPermission();
    }
  }

  /// Re-schedule notifications for ALL incomplete tasks on app startup.
  /// This is critical because scheduled alarms can be lost after device reboot
  /// or after the app is force-stopped.
  Future<void> _rescheduleAllNotifications() async {
    try {
      final tasks = await DbHelper.getTasks();
      final mutableTasks = List<Map<String, dynamic>>.from(
          tasks.map((task) => Map<String, dynamic>.from(task)));

      // Cancel all existing notifications first to avoid duplicates
      await flutterLocalNotificationsPlugin.cancelAll();

      for (final task in mutableTasks) {
        // Only schedule for incomplete tasks
        if (task['status'] == 1) continue;

        final int taskId = task['id'];
        DateTime taskDate;
        DateTime taskEndDate;

        try {
          taskDate = DateFormat('yyyy-MM-dd HH:mm').parse(task['date']);
        } catch (_) {
          continue;
        }

        try {
          if (task['date_fin'] != null && task['date_fin'].toString().isNotEmpty) {
            taskEndDate = DateFormat('yyyy-MM-dd HH:mm').parse(task['date_fin']);
          } else {
            continue;
          }
        } catch (_) {
          continue;
        }

        final String titre = task['titre'] ?? '';
        final String description = task['description'] ?? '';

        // Schedule based on task duration
        if (taskEndDate.isAfter(taskDate.add(const Duration(days: 1))) || taskDate.day != taskEndDate.day) {
          await _scheduleDailyNotificationsBetweenDates(
              taskId, "Rappel quotidien: $titre", description, taskDate, taskEndDate);
        } else if (taskDate.isAfter(DateTime.now())) {
          await _scheduleNotificationSingle(
              taskId, "Rappel: $titre", description, taskDate);
        }
      }
      debugPrint('All notifications rescheduled successfully');
    } catch (e) {
      debugPrint('Error rescheduling notifications: $e');
    }
  }

  Future<void> _scheduleDailyNotificationsBetweenDates(int id, String title,
      String body, DateTime startDate, DateTime endDate) async {
    final int hour = startDate.hour;
    final int minute = startDate.minute;
    
    DateTime currentDay = DateTime(
        startDate.year, startDate.month, startDate.day, hour, minute);

    // If start date is in the past, start from today or tomorrow
    if (currentDay.isBefore(DateTime.now())) {
      DateTime todayAtTime = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, hour, minute);
      if (todayAtTime.isBefore(DateTime.now())) {
        currentDay = todayAtTime.add(const Duration(days: 1));
      } else {
        currentDay = todayAtTime;
      }
    }

    // Don't schedule if we're already past the end date
    if (currentDay.isAfter(endDate)) {
      debugPrint('No notifications to schedule: start ($currentDay) is after end ($endDate)');
      return;
    }

    const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
      'daily_reminder_channel', 'Rappel Quotidien',
      channelDescription: 'Rappels quotidiens pour les tâches',
      importance: Importance.max, priority: Priority.high, ticker: 'ticker',
      styleInformation: BigTextStyleInformation(''),
    );
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    );

    int baseId = id * 1000;
    int dayCount = 0;
    // Limit to 50 notifications max per task to avoid hitting Android's alarm limit
    const int maxNotifications = 50;

    while (currentDay.isBefore(endDate.add(const Duration(minutes: 1)))) {
      if (dayCount >= maxNotifications) {
        debugPrint('Max notifications limit ($maxNotifications) reached for task $id');
        break;
      }
      
      final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(currentDay, tz.local);
      
      // Only schedule future notifications
      if (tzScheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {
        int uniqueDayId = baseId + dayCount;
        try {
          await flutterLocalNotificationsPlugin.zonedSchedule(
            uniqueDayId, title, body, tzScheduledDate, notificationDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: 'TaskID|$id',
          );
          debugPrint('Scheduled notification $uniqueDayId at $tzScheduledDate for task $id');
        } catch (e) {
          debugPrint('Error scheduling daily notification for task $id at $tzScheduledDate: $e');
        }
      }
      
      dayCount++;
      currentDay = currentDay.add(const Duration(days: 1));
    }
    debugPrint('Scheduled $dayCount daily notifications for task $id');
  }

  void _addTask() async {
    final titre = _titreController.text;
    final description = _descriptionController.text;
    final String dateForDb = DateFormat('yyyy-MM-dd HH:mm').format(selectedDate);
    final String heureForDb = DateFormat('HH:mm').format(selectedDate);
    final String dateFinForDb = DateFormat('yyyy-MM-dd HH:mm').format(selectedEndDate);

    final newTaskId = await DbHelper.insert(titre, description, dateForDb, heureForDb, dateFinForDb, priority: _selectedPriority);

    if (newTaskId > 0) {
      if (selectedEndDate.isAfter(selectedDate.add(const Duration(days: 1))) || selectedDate.day != selectedEndDate.day) {
        _scheduleDailyNotificationsBetweenDates(newTaskId, "Rappel quotidien de tâche: $titre", description, selectedDate, selectedEndDate);
      } else if (selectedDate.isAfter(DateTime.now())) {
        _scheduleNotificationSingle(newTaskId, "Rappel de tâche: $titre", description, selectedDate);
      }
    }
    _refreshTasks();
  }

  void _refreshTasks() async {
    final tasks = await DbHelper.getTasks();
    if (!mounted) return;
    setState(() {
      // On convertit la liste (ainsi que chaque objet Map à l'intérieur) 
      // pour garantir qu'elle soit entièrement modifiable (évite l'erreur read-only du QueryResultSet)
      _tasks = List<Map<String, dynamic>>.from(tasks.map((task) => Map<String, dynamic>.from(task)));
      _applyFilter();
    });
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    
    // Filtrage combiné (Recherche textuelle + Filtre rapide par statut)
    _filteredTasks = _tasks.where((task) {
      final titre = task['titre']?.toString().toLowerCase() ?? '';
      final date = task['date']?.toString().toLowerCase() ?? '';
      final matchesQuery = query.isEmpty || titre.contains(query) || date.contains(query);
      
      bool matchesStatusFilter = true;
      if (_currentFilter == 'En cours') {
        matchesStatusFilter = task['status'] == 0;
      } else if (_currentFilter == 'Terminées') {
        matchesStatusFilter = task['status'] == 1;
      }

      return matchesQuery && matchesStatusFilter;
    }).toList();
  }

  void _filterTasks() {
    setState(() {
      _applyFilter();
    });
  }

  void _updateTask(int id, int currentStatus) async {
    final int newStatus = currentStatus == 0 ? 1 : 0;
    
    debugPrint("Updating task $id from $currentStatus to $newStatus");
    
    // 1. Mise à jour immédiate de l'UI (Optimiste)
    setState(() {
      // Mettre à jour dans la liste source (_tasks)
      final index = _tasks.indexWhere((t) => t['id'] == id);
      if (index != -1) {
        final updatedTask = Map<String, dynamic>.from(_tasks[index]);
        updatedTask['status'] = newStatus;
        _tasks[index] = updatedTask;
      }
      
      // Mettre à jour dans la liste affichée (_filteredTasks)
      final filteredIndex = _filteredTasks.indexWhere((t) => t['id'] == id);
      if (filteredIndex != -1) {
        final updatedFilteredTask = Map<String, dynamic>.from(_filteredTasks[filteredIndex]);
        updatedFilteredTask['status'] = newStatus;
        _filteredTasks[filteredIndex] = updatedFilteredTask;
      }
    });

    // 2. Mise à jour persistante dans la base de données
    try {
      await DbHelper.update(id, newStatus);
      debugPrint("Database updated successfully for task $id");
    } catch (e) {
      debugPrint("Database update error: $e");
      // Facultatif: Revenir en arrière en cas d'erreur
      _refreshTasks();
      return;
    }

    // 3. Gestion des notifications
    if (newStatus == 1) {
      _cancelNotification(id);
    } else {
      final index = _tasks.indexWhere((t) => t['id'] == id);
      if (index != -1) {
        final task = _tasks[index];
        try {
          DateTime taskDate = DateFormat('yyyy-MM-dd HH:mm').parse(task['date']);
          DateTime taskEndDate = DateFormat('yyyy-MM-dd HH:mm').parse(task['date_fin']);

          if (taskEndDate.isAfter(taskDate.add(const Duration(days: 1))) || taskDate.day != taskEndDate.day) {
            _scheduleDailyNotificationsBetweenDates(id, "${task['titre']}", task['description'] ?? "", taskDate, taskEndDate);
          } else if (taskDate.isAfter(DateTime.now())) {
            _scheduleNotificationSingle(id, "Rappel: ${task['titre']}", task['description'] ?? "", taskDate);
          }
        } catch (e) {
          debugPrint("Error rescheduling notification: $e");
        }
      }
    }
    
    // 4. Rafraîchissement final pour garantir la synchronisation
    _refreshTasks();
  }

  void _updateTaskInfo(int id, String titre, String description,
      DateTime newSelectedDate, DateTime newSelectedEndDate, {String priority = 'Moyenne'}) async {
    final dateString = DateFormat('yyyy-MM-dd HH:mm').format(newSelectedDate);
    final dateFinString = DateFormat('yyyy-MM-dd HH:mm').format(newSelectedEndDate);
    
    await DbHelper.updateTask(id, titre, description, dateString, dateFinString, priority: priority);
    await _cancelNotification(id);

    if (newSelectedEndDate.isAfter(newSelectedDate.add(const Duration(days: 1))) || newSelectedDate.day != newSelectedEndDate.day) {
      _scheduleDailyNotificationsBetweenDates(id, titre, description, newSelectedDate, newSelectedEndDate);
    } else if (newSelectedDate.isAfter(DateTime.now())) {
      _scheduleNotificationSingle(id, "Mise à jour: $titre", description, newSelectedDate);
    }

    _refreshTasks();
  }

  void _deleteTask(int id) async {
    // UI Optimiste
    setState(() {
      _tasks.removeWhere((t) => t['id'] == id);
      _applyFilter();
    });

    await DbHelper.delete(id);
    await _cancelNotification(id);
    _refreshTasks();
  }

  void _resetDatabase() async {
    await DbHelper.resetDatabase();
    await flutterLocalNotificationsPlugin.cancelAll();
    _refreshTasks();
  }

  Future<void> _scheduleNotificationSingle(int id, String title, String body,
      DateTime scheduledDateTime) async {
    if (scheduledDateTime.isBefore(DateTime.now())) {
      debugPrint('Skip scheduling single notification for task $id: date is in the past');
      return;
    }
    final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(scheduledDateTime, tz.local);
    const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
      'your_channel_id', 'your_channel_name',
      channelDescription: 'your_channel_description',
      importance: Importance.max, priority: Priority.high, ticker: 'ticker',
      styleInformation: BigTextStyleInformation(''),
    );
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    );
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id, title, body, tzScheduledDate, notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'TaskID|$id',
      );
      debugPrint('Scheduled single notification $id at $tzScheduledDate');
    } catch (e) {
      debugPrint('Error scheduling single notification for task $id: $e');
    }
  }

  Future<void> _cancelNotification(int id) async {
    // Cancel single notification
    await flutterLocalNotificationsPlugin.cancel(id);
    // Cancel all daily notifications for this task (baseId = id * 1000)
    int baseId = id * 1000;
    for (int i = 0; i < 51; i++) {
      await flutterLocalNotificationsPlugin.cancel(baseId + i);
    }
    debugPrint('Cancelled all notifications for task $id');
  }

  PageRouteBuilder _slideTransition(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(animation),
          child: child,
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterTasks);
    _searchController.dispose();
    _animationController.dispose();
    _titreController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
      if (task['date_fin'] != null && task['date_fin'].toString().isNotEmpty) {
        taskEndDate = DateFormat('yyyy-MM-dd HH:mm').parse(task['date_fin']);
      }
    } catch (_) {}

    DateTime? taskCreationDate;
    try {
      if (task['creation'] != null && task['creation'].toString().isNotEmpty) {
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
        remainingDurationText = "Terminée";
        remainingColor = Colors.green.shade700;
      } else {
        DateTime now = DateTime.now();
        Duration remaining = taskEndDate.difference(now);
        if (remaining.isNegative) {
          remainingDurationText = "Expirée";
          remainingColor = Colors.red.shade700;
        } else {
          int days = remaining.inDays;
          int hours = remaining.inHours.remainder(24);
          int minutes = remaining.inMinutes.remainder(60);
          List<String> parts = [];
          if (days > 0) parts.add('$days j');
          if (hours > 0) parts.add('$hours h');
          if (minutes > 0 || (days == 0 && hours == 0)) parts.add('$minutes min');
          remainingDurationText = parts.join(' ');
          remainingColor = days == 0 ? Colors.orange.shade700 : Colors.blueGrey;
        }
      }
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (isTaskDone ? Colors.green : Colors.orange).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isTaskDone ? Icons.check_circle_rounded : Icons.pending_rounded, size: 14, color: isTaskDone ? Colors.green : Colors.orange),
                            const SizedBox(width: 4),
                            Text(isTaskDone ? "TERMINÉE" : "EN COURS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isTaskDone ? Colors.green : Colors.orange)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(onPressed: () { Navigator.pop(context); _showMyDialogSuppression(task['id']); }, icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent), visualDensity: VisualDensity.compact),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(task['titre'].toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.2)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    if (task['description'] != null && task['description'].toString().isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("DESCRIPTION", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
                            const SizedBox(height: 8),
                            Text(task['description'].toString(), style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.5)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Row(
                      children: [
                        Expanded(child: _buildInfoCard(Icons.alarm_rounded, "RAPPEL", DateFormat('dd MMM, HH:mm', 'fr_FR').format(taskDate))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInfoCard(Icons.event_note_rounded, "ÉCHÉANCE", taskEndDate != null ? DateFormat('dd MMM, HH:mm', 'fr_FR').format(taskEndDate) : "N/A")),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildInfoCard(Icons.timer_outlined, "DURÉE", durationText)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInfoCard(Icons.hourglass_empty_rounded, "RESTANT", remainingDurationText, color: remainingColor)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (taskCreationDate != null)
                      Align(alignment: Alignment.centerLeft, child: Text("Créée le ${DateFormat('dd MMMM yyyy à HH:mm', 'fr_FR').format(taskCreationDate)}", style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic))),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () { Navigator.pop(context); _updateTask(task['id'], task['status']); },
                      icon: Icon(isTaskDone ? Icons.undo_rounded : Icons.check_circle_outline_rounded, size: 20),
                      label: Text(isTaskDone ? " RÉTABLIR" : " TERMINER"),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), foregroundColor: isTaskDone ? Colors.grey.shade700 : Colors.green, side: BorderSide(color: isTaskDone ? Colors.grey.shade300 : Colors.green)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (!isTaskDone)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () { Navigator.pop(context); _showMyDialog(task); },
                        icon: const Icon(Icons.edit_rounded, size: 20, color: Colors.white),
                        label: const Text("MODIFIER"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
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

  Widget _buildInfoCard(IconData icon, String title, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 16, color: color ?? Colors.green), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5))]),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color ?? Colors.black87)),
        ],
      ),
    );
  }

  Future<void> _showMyDialog(Map<String, dynamic> task) async {
    _titreController.text = task['titre'];
    _descriptionController.text = task['description'];
    _selectedPriority = task['priority'] ?? 'Moyenne';
    try { selectedDate = DateFormat('yyyy-MM-dd HH:mm').parse(task['date']); } catch (e) { selectedDate = DateTime.now(); }
    try { selectedEndDate = DateFormat('yyyy-MM-dd HH:mm').parse(task['date_fin']); } catch (e) { selectedEndDate = selectedDate.add(const Duration(hours: 1)); }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Pour permettre l'arrière-plan arrondi sans bordures blanches
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30.0)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 12.0, left: 24.0, right: 24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Petite barre "drag" au sommet
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),
                
                // En-tête amélioré
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                          child: const Icon(Icons.edit_note_rounded, color: Colors.green, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Text("Modifier la tâche", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87, decoration: TextDecoration.none)),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: Colors.grey.shade500),
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(backgroundColor: Colors.grey.shade100),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                Form(
                  key: _formkey,
                  child: StatefulBuilder(builder: (BuildContext context, StateSetter setStateDialog) {
                    DateTime dialogSelectedDate = selectedDate;
                    DateTime dialogSelectedEndDate = selectedEndDate;
                    String dialogPriority = _selectedPriority;
                    return Column(
                      children: [
                        TextFormField(
                          controller: _titreController, 
                          maxLines: 2, 
                          validator: (value) => (value == null || value.trim().isEmpty) ? 'Le titre est requis' : null, 
                          decoration: InputDecoration(
                            labelText: "Titre de la tâche", 
                            prefixIcon: Icon(Icons.title_rounded, color: Colors.green.shade500), 
                            filled: true, 
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16), 
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.green.shade300, width: 2))
                          ), 
                          style: const TextStyle(decoration: TextDecoration.none, fontWeight: FontWeight.w500)
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController, 
                          minLines: 3, 
                          maxLines: 5, 
                          validator: (value) => (value == null || value.trim().isEmpty) ? 'La description est requise' : null, 
                          decoration: InputDecoration(
                            labelText: "Description", 
                            hintText: "Détails de la tâche...", 
                            prefixIcon: Icon(Icons.description_rounded, color: Colors.green.shade500), 
                            filled: true, 
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16), 
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.green.shade300, width: 2))
                          ), 
                          style: const TextStyle(decoration: TextDecoration.none)
                        ),
                        const SizedBox(height: 16),
                        // Sélecteur de priorité
                        DropdownButtonFormField<String>(
                          value: dialogPriority,
                          decoration: InputDecoration(
                            labelText: "Priorité", 
                            prefixIcon: Icon(Icons.flag_rounded, color: dialogPriority == 'Haute' ? Colors.red : dialogPriority == 'Moyenne' ? Colors.orange : Colors.green), 
                            filled: true, 
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.green.shade300, width: 2))
                          ),
                          items: ['Haute', 'Moyenne', 'Basse'].map((priority) => DropdownMenuItem(value: priority, child: Text(priority))).toList(),
                          onChanged: (value) { if (value != null) { setStateDialog(() => dialogPriority = value); setState(() => _selectedPriority = value); } },
                        ),
                        const SizedBox(height: 16),
                        DateTimeFormField(
                          style: const TextStyle(color: Colors.black, decoration: TextDecoration.none),
                          decoration: InputDecoration(
                            labelText: "Date de rappel", 
                            prefixIcon: Icon(Icons.alarm_rounded, color: Colors.green.shade500), 
                            filled: true, 
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.green.shade300, width: 2))
                          ), 
                          mode: DateTimeFieldPickerMode.dateAndTime, 
                          lastDate: DateTime.now().add(const Duration(days: 365)), 
                          initialPickerDateTime: dialogSelectedDate, 
                          onChanged: (DateTime? value) { if (value != null) { setStateDialog(() => dialogSelectedDate = value); setState(() => selectedDate = value); } }, 
                        ),
                        const SizedBox(height: 16),
                        DateTimeFormField(
                          style: const TextStyle(color: Colors.black, decoration: TextDecoration.none),
                          decoration: InputDecoration(
                            labelText: "Date de fin prévue", 
                            prefixIcon: Icon(Icons.event_note_rounded, color: Colors.green.shade500), 
                            filled: true, 
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.green.shade300, width: 2))
                          ), 
                          mode: DateTimeFieldPickerMode.dateAndTime, 
                          lastDate: DateTime.now().add(const Duration(days: 365)), 
                          initialPickerDateTime: dialogSelectedEndDate, 
                          onChanged: (DateTime? value) { if (value != null) { setStateDialog(() => dialogSelectedEndDate = value); setState(() => selectedEndDate = value); } }, 
                          validator: (value) { if (value != null && value.isBefore(dialogSelectedDate)) { return 'La date de fin ne peut être avant la date de rappel'; } return null; }
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: <Widget>[
                            Expanded(child: ElevatedButton.icon(onPressed: () => Navigator.of(context).pop(), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade100, foregroundColor: Colors.black87, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 18), textStyle: const TextStyle(fontWeight: FontWeight.bold)), icon: const Icon(Icons.cancel_outlined, size: 22), label: const Text("ANNULER"))),
                            const SizedBox(width: 12),
                            Expanded(child: ElevatedButton.icon(onPressed: _isLoading ? null : () async { if (_formkey.currentState!.validate()) { setState(() => _isLoading = true); _updateTaskInfo(task['id'], _titreController.text, _descriptionController.text, dialogSelectedDate, dialogSelectedEndDate, priority: dialogPriority); Navigator.of(context).pop(); _titreController.clear(); _descriptionController.clear(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✏️ Modification effectuée avec succès!", style: TextStyle(color: Colors.white, decoration: TextDecoration.none)), behavior: SnackBarBehavior.floating, backgroundColor: Colors.green, showCloseIcon: true)); setState(() => _isLoading = false); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, elevation: 4, shadowColor: Colors.green.withOpacity(0.4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 18), textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)), icon: const Icon(Icons.save_rounded, size: 22), label: const Text("SAUVEGARDER"))),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  }),
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
    _selectedPriority = 'Moyenne';
    selectedDate = DateTime.now();
    selectedEndDate = DateTime.now().add(const Duration(hours: 1));

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Pour permettre l'arrière-plan arrondi sans bordures blanches
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30.0)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 12.0, left: 24.0, right: 24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Petite barre "drag" au sommet
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),
                
                // En-tête amélioré
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                          child: const Icon(Icons.add_task_rounded, color: Colors.green, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Text("Création d'une tâche", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87, decoration: TextDecoration.none)),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: Colors.grey.shade500),
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(backgroundColor: Colors.grey.shade100),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                Form(
                  key: _formkey,
                  child: StatefulBuilder(builder: (BuildContext context, StateSetter setStateDialog) {
                    DateTime dialogSelectedDate = selectedDate;
                    DateTime dialogSelectedEndDate = selectedEndDate;
                    String dialogPriority = _selectedPriority;
                    return Column(
                      children: [
                        TextFormField(
                          controller: _titreController, 
                          maxLines: 2, 
                          validator: (value) => (value == null || value.trim().isEmpty) ? 'Le titre est requis' : null, 
                          decoration: InputDecoration(
                            labelText: "Titre de la tâche", 
                            hintText: "Ex. : Finaliser l’interface...",
                            prefixIcon: Icon(Icons.title_rounded, color: Colors.green.shade500), 
                            filled: true, 
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16), 
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.green.shade300, width: 2))
                          ), 
                          style: const TextStyle(decoration: TextDecoration.none, fontWeight: FontWeight.w500)
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController, 
                          minLines: 3, 
                          maxLines: 5, 
                          validator: (value) => (value == null || value.trim().isEmpty) ? 'La description est requise' : null, 
                          decoration: InputDecoration(
                            labelText: "Description", 
                            hintText: "Détails de la tâche...", 
                            prefixIcon: Icon(Icons.description_rounded, color: Colors.green.shade500), 
                            filled: true, 
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16), 
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.green.shade300, width: 2))
                          ), 
                          style: const TextStyle(decoration: TextDecoration.none)
                        ),
                        const SizedBox(height: 16),
                        // Sélecteur de priorité
                        DropdownButtonFormField<String>(
                          value: dialogPriority,
                          decoration: InputDecoration(
                            labelText: "Priorité", 
                            prefixIcon: Icon(Icons.flag_rounded, color: dialogPriority == 'Haute' ? Colors.red : dialogPriority == 'Moyenne' ? Colors.orange : Colors.green), 
                            filled: true, 
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.green.shade300, width: 2))
                          ),
                          items: ['Haute', 'Moyenne', 'Basse'].map((priority) => DropdownMenuItem(value: priority, child: Text(priority))).toList(),
                          onChanged: (value) { if (value != null) { setStateDialog(() => dialogPriority = value); setState(() => _selectedPriority = value); } },
                        ),
                        const SizedBox(height: 16),
                        DateTimeFormField(
                          style: const TextStyle(color: Colors.black, decoration: TextDecoration.none),
                          decoration: InputDecoration(
                            labelText: "Date de rappel", 
                            prefixIcon: Icon(Icons.alarm_rounded, color: Colors.green.shade500), 
                            filled: true, 
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.green.shade300, width: 2))
                          ), 
                          mode: DateTimeFieldPickerMode.dateAndTime, 
                          lastDate: DateTime.now().add(const Duration(days: 365)), 
                          initialPickerDateTime: dialogSelectedDate, 
                          onChanged: (DateTime? value) { if (value != null) { setStateDialog(() => dialogSelectedDate = value); setState(() => selectedDate = value); } }, 
                        ),
                        const SizedBox(height: 16),
                        DateTimeFormField(
                          style: const TextStyle(color: Colors.black, decoration: TextDecoration.none),
                          decoration: InputDecoration(
                            labelText: "Date de fin prévue", 
                            prefixIcon: Icon(Icons.event_note_rounded, color: Colors.green.shade500), 
                            filled: true, 
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.green.shade300, width: 2))
                          ), 
                          mode: DateTimeFieldPickerMode.dateAndTime, 
                          lastDate: DateTime.now().add(const Duration(days: 365)), 
                          initialPickerDateTime: dialogSelectedEndDate, 
                          onChanged: (DateTime? value) { if (value != null) { setStateDialog(() => dialogSelectedEndDate = value); setState(() => selectedEndDate = value); } }, 
                          validator: (value) { if (value != null && value.isBefore(dialogSelectedDate)) { return 'La date de fin ne peut être avant la date de rappel'; } return null; }
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: <Widget>[
                            Expanded(child: ElevatedButton.icon(onPressed: () => Navigator.of(context).pop(), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade100, foregroundColor: Colors.black87, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 18), textStyle: const TextStyle(fontWeight: FontWeight.bold)), icon: const Icon(Icons.cancel_outlined, size: 22), label: const Text("ANNULER"))),
                            const SizedBox(width: 12),
                            Expanded(child: ElevatedButton.icon(onPressed: _isLoading ? null : () async { if (_formkey.currentState!.validate()) { setState(() => _isLoading = true); setState(() { selectedDate = dialogSelectedDate; selectedEndDate = dialogSelectedEndDate; }); _addTask(); Navigator.of(context).pop(); _titreController.clear(); _descriptionController.clear(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ La tâche a été ajoutée avec succès !", style: TextStyle(color: Colors.white, decoration: TextDecoration.none)), behavior: SnackBarBehavior.floating, backgroundColor: Colors.green, showCloseIcon: true)); setState(() => _isLoading = false); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, elevation: 4, shadowColor: Colors.green.withOpacity(0.4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 18), textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)), icon: const Icon(Icons.add_task_rounded, size: 22), label: const Text("CRÉER"))),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  }),
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
          title: const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.warning_amber_rounded, color: Colors.orange), title: Text('Confirmation de la réinitialisation', style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.none))),
          content: const SingleChildScrollView(child: ListBody(children: [Text('Êtes-vous sûr de vouloir réinitialiser la base de données ?', style: TextStyle(decoration: TextDecoration.none))])),
          actionsAlignment: MainAxisAlignment.end,
          actions: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(onPressed: () { _resetDatabase(); Navigator.of(context).pop(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🧹 La base de données a été réinitialisée !", style: TextStyle(color: Colors.white, decoration: TextDecoration.none)), behavior: SnackBarBehavior.floating, backgroundColor: Colors.green, showCloseIcon: true)); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)), icon: const Icon(Icons.restart_alt, color: Colors.white, size: 20), label: const Text("CONFIRMER", style: TextStyle(color: Colors.white))),
                const SizedBox(width: 8),
                ElevatedButton.icon(onPressed: () => Navigator.of(context).pop(), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)), icon: const Icon(Icons.cancel_outlined, color: Colors.white, size: 20), label: const Text("ANNULER", style: TextStyle(color: Colors.white))),
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
          title: const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.delete_forever_rounded, color: Colors.redAccent), title: Text('Confirmation de la suppression', style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.none))),
          content: const SingleChildScrollView(child: ListBody(children: [Text('Êtes-vous sûr de vouloir supprimer cette tâche ?', style: TextStyle(decoration: TextDecoration.none))])),
          actionsAlignment: MainAxisAlignment.end,
          actions: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(onPressed: () { _deleteTask(id); Navigator.of(context).pop(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🗑️ La tâche a été supprimée avec succès !", style: TextStyle(color: Colors.white, decoration: TextDecoration.none)), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red, showCloseIcon: true)); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)), icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 20), label: const Text("CONFIRMER", style: TextStyle(color: Colors.white))),
                const SizedBox(width: 8),
                ElevatedButton.icon(onPressed: () => Navigator.of(context).pop(), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)), icon: const Icon(Icons.cancel_outlined, color: Colors.white, size: 20), label: const Text("ANNULER", style: TextStyle(color: Colors.white))),
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
      appBar: AppBar(
        toolbarHeight: 65,
        backgroundColor: Colors.green,
        elevation: 2,
        scrolledUnderElevation: 2,
        centerTitle: false,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: "Rechercher...",
                  hintStyle: TextStyle(color: Colors.white70, fontSize: 18),
                  border: InputBorder.none,
                ),
              )
            : const Text("Panatask", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          _isSearching
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchController.clear();
                      _filterTasks();
                    });
                  },
                )
              : IconButton(
                  icon: const Icon(Icons.search_rounded, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                ),
          if (!_isSearching)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
              offset: const Offset(0, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              itemBuilder: (context) => [
                const PopupMenuItem<String>(value: 'aide', child: Row(children: [Icon(Icons.help_outline_rounded, color: Colors.blueGrey), SizedBox(width: 8), Text("Aide")])),
                const PopupMenuItem<String>(value: 'reset', child: Row(children: [Icon(Icons.restart_alt, color: Colors.redAccent), SizedBox(width: 8), Text("Réinitialiser la base")])),
                const PopupMenuItem<String>(value: 'backup', child: Row(children: [Icon(Icons.backup_rounded, color: Colors.blueGrey), SizedBox(width: 8), Text("Sauvegarde/Restauration")])),
                const PopupMenuItem<String>(value: 'parametres', child: Row(children: [Icon(Icons.settings_outlined, color: Colors.blueGrey), SizedBox(width: 8), Text("Paramètres")])),
                const PopupMenuItem<String>(value: 'apropos', child: Row(children: [Icon(Icons.info_outline_rounded, color: Colors.blueGrey), SizedBox(width: 8), Text("À propos")])),
              ],
              onSelected: (value) {
                if (value == 'aide') { Navigator.push(context, _slideTransition(const AidePage())); }
                else if (value == 'reset') { _showMyDialogConfirmation(); }
                else if (value == 'backup') { Navigator.push(context, _slideTransition(const BackupDbPage())).then((_) => _refreshTasks()); }
                else if (value == 'parametres') { Navigator.push(context, _slideTransition(const ParametresPage())); }
                else if (value == 'apropos') { Navigator.push(context, _slideTransition(const AproposPage())); }
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(onPressed: _showMyDialogAdd, backgroundColor: Colors.green, elevation: 4, icon: const Icon(Icons.add_rounded, color: Colors.white, size: 28), label: const Text("NOUVELLE TÂCHE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
      body: SafeArea(
        child: Column(
          children: [
            // Tableau de bord
            if (_tasks.isNotEmpty) Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Builder(
                builder: (context) {
                  double progressValue = _tasks.where((t) => t['status'] == 1).length / (_tasks.isEmpty ? 1 : _tasks.length);
                  int percentage = (progressValue * 100).toInt();
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 8))]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Progression globale", style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600)),
                            Text("$percentage%", style: const TextStyle(color: Colors.black87, fontSize: 24, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progressValue,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text("${_tasks.where((t) => t['status'] == 1).length} tâches terminées sur ${_tasks.length}", style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  );
                }
              ),
            ),
            // Début: Ajout des filtres rapides (Chips)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _buildFilterChip('Toutes'),
                  const SizedBox(width: 8),
                  _buildFilterChip('En cours'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Terminées'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Fin: Ajout des filtres rapides
            Expanded(
              child: _filteredTasks.isEmpty ? _buildEmptyState() : ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: _filteredTasks.length,
                onReorder: (int oldIndex, int newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final item = _filteredTasks.removeAt(oldIndex);
                    _filteredTasks.insert(newIndex, item);
                    
                    // Maintenir l'ordre dans la liste principale
                    final mainOldIndex = _tasks.indexWhere((t) => t['id'] == item['id']);
                    if (mainOldIndex != -1) {
                      _tasks.removeAt(mainOldIndex);
                      if (newIndex == 0) {
                        _tasks.insert(0, item);
                      } else if (newIndex == _filteredTasks.length - 1) {
                        _tasks.add(item);
                      } else {
                        final nextItemId = _filteredTasks[newIndex + 1]['id'];
                        final nextIndexMain = _tasks.indexWhere((t) => t['id'] == nextItemId);
                        if (nextIndexMain != -1) {
                          _tasks.insert(nextIndexMain, item);
                        } else {
                          _tasks.add(item);
                        }
                      }
                    }
                  });
                },
                proxyDecorator: (Widget child, int index, Animation<double> animation) {
                  return Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))
                        ]
                      ),
                      child: child,
                    ),
                  );
                },
                itemBuilder: (context, index) {
                  final task = _filteredTasks[index];
                  final bool isTaskDone = task['status'] == 1;
                  final String priority = task['priority'] ?? 'Moyenne';
                  final Color priorityColor = priority == 'Haute' ? Colors.red : priority == 'Moyenne' ? Colors.orange : Colors.green;
                  
                  DateTime taskDate;
                  try { taskDate = DateFormat('yyyy-MM-dd HH:mm').parse(task['date']); } catch (e) { taskDate = DateTime.now(); }
                  return Dismissible(
                    key: Key('task_${task['id']}'),
                    background: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: isTaskDone ? Colors.orange : Colors.green, borderRadius: BorderRadius.circular(20)),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Icon(isTaskDone ? Icons.undo_rounded : Icons.check_circle_rounded, color: Colors.white, size: 28),
                    ),
                    secondaryBackground: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
                    ),
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.endToStart) {
                        _showMyDialogSuppression(task['id']);
                        return false;
                      } else {
                        _updateTask(task['id'], task['status']);
                        return false; // Garde l'élément dans la liste pour montrer l'animation
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: isTaskDone ? Colors.green.shade100 : Colors.white, borderRadius: BorderRadius.circular(20), border: Border(left: BorderSide(color: priorityColor, width: 6)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _showTaskDetailsBottomSheet(task),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () { _updateTask(task['id'], task['status']); },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: isTaskDone ? Colors.green : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: isTaskDone ? Colors.green : Colors.grey.shade300, width: 2),
                                    ),
                                    child: isTaskDone ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(task['titre'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isTaskDone ? Colors.green.shade900 : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Row(children: [Icon(Icons.access_time_rounded, size: 14, color: isTaskDone ? Colors.green.shade700 : Colors.green.shade400), const SizedBox(width: 4), Text(DateFormat('HH:mm', 'fr_FR').format(taskDate), style: TextStyle(color: isTaskDone ? Colors.green.shade700 : Colors.grey.shade600, fontSize: 13)), const SizedBox(width: 12), Icon(Icons.flag_rounded, size: 14, color: priorityColor), const SizedBox(width: 4), Text(priority, style: TextStyle(color: priorityColor, fontSize: 13))]),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),
                              ],
                            ),
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
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.task_alt_outlined, size: 80, color: Colors.grey.shade200), const SizedBox(height: 16), Text("Aucune tâche pour le moment", style: TextStyle(color: Colors.grey.shade400, fontSize: 16))]));
  }

  // Nouveau widget pour les chips de filtrage rapide
  Widget _buildFilterChip(String label) {
    final bool isSelected = _currentFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _currentFilter = label;
            _applyFilter();
          });
        }
      },
      selectedColor: Colors.green.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.green.shade900 : Colors.grey.shade600,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.green.shade300 : Colors.grey.shade200,
        ),
      ),
    );
  }
}
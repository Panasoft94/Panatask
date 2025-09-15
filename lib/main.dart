import 'package:flutter/material.dart';
import 'package:panatask/data/db_helper.dart';
import 'package:panatask/pages/aide.dart';
import 'package:panatask/pages/apropos.dart';
import 'package:date_field/date_field.dart'; // bibiotheque de la date standar
import 'package:intl/intl.dart'; //bibiotheque de formatage de la date
import 'package:flutter_localizations/flutter_localizations.dart'; //rendre la date au format international
import 'package:format/format.dart'; //bibiotheque de formatage de l'heure';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panatask',
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('en'), // English
        Locale('fr'), // fr
      ],

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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
 TextEditingController _searchController = TextEditingController();
 late AnimationController _animationController;
 late Animation<double> _fadeAnimation;

void _addTask() async{
  final titre = _titreController.text;
  final description = _descriptionController.text;
  final date = DateFormat('yyyy-MM-dd HH:mm').format(selectedDate);
  final heure = DateFormat('HH:mm').format(selectedDate);
  await DbHelper.insert(titre, description, date, heure);
  _refreshTasks();
}

void _refreshTasks() async{
  final tasks = await DbHelper.getTasks();
  setState(() {
    _tasks = tasks;
    _filteredTasks = _searchController.text.isEmpty
        ? _tasks
        : _tasks.where((task) {
      final query = _searchController.text.toLowerCase();
      final titre = task['titre'].toLowerCase();
      final date = task['date'].toLowerCase();
      return titre.contains(query) || date.contains(query);
    }).toList();
  });
}
void _updateTask(int id, int status) async{
  await DbHelper.update(id, status == 0 ? 1 : 0);
  _refreshTasks();
}
void _updateTaskInfo(int id, String titre, String description, DateTime date) async{
  final date = DateFormat('yyyy-MM-dd HH:mm').format(selectedDate);
  await DbHelper.updateTask(id, titre, description, date.toString());
  _refreshTasks();
}
void _deleteTask(int id) async{
  await DbHelper.delete(id);
  _refreshTasks();
}
void _resetDatabase() async{
  await DbHelper.resetDatabase();
  _refreshTasks();
}

@override
  void initState() {
    super.initState();
    _refreshTasks();
    _filteredTasks = _tasks;
    _searchController.addListener(_filterTasks);

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

 void _filterTasks() {
   final query = _searchController.text.toLowerCase();
   setState(() {
     _filteredTasks = _searchController.text.isEmpty
         ? _tasks
         : _tasks.where((task) {
       final query = _searchController.text.toLowerCase();
       final titre = task['titre'].toLowerCase();
       final date = task['date'].toLowerCase();
       return titre.contains(query) || date.contains(query);
     }).toList();
   });
 }

 @override
 void dispose() {
   _searchController.dispose();
   _animationController.dispose();
   super.dispose();
 }

 Future<void> _showMyDialog(Map<String, dynamic> task) async {
   final _titreController = TextEditingController(text: task['titre']);
   final _descriptionController = TextEditingController(text: task['description']);

   return showDialog<void>(
     context: context,
     barrierDismissible: true,
     builder: (BuildContext context) {
       return AlertDialog(
         title: ListTile(
           contentPadding: EdgeInsets.zero,
           leading: Icon(Icons.edit_note_rounded, color: Colors.orange),
           title: Text("Édition d'une tâche", style: TextStyle(fontWeight: FontWeight.bold)),
         ),
         content: SingleChildScrollView(
           child: Form(
             key: _formkey,
             child: Column(
               children: [
                 TextFormField(
                   controller: _titreController,
                   maxLines: 3, // ✅ Permet d’agrandir verticalement
                   validator: (value) {
                     if (value == null || value.trim().isEmpty) {
                       return 'Le titre est requis';
                     }
                     return null;
                   },
                   decoration: InputDecoration(
                     labelText: "Titre de la tâche",
                     prefixIcon: const Icon(Icons.title_rounded),
                     filled: true,
                     contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16), // ✅ Agrandit la zone
                     border: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(30), // ✅ Arrondi plus généreux
                     ),
                   ),
                 ),
                 SizedBox(height: 12),
                 TextFormField(
                   controller: _descriptionController,
                   minLines: 4, // ✅ Hauteur minimale
                   maxLines: 6, // ✅ Permet d’écrire plus sans scroller
                   validator: (value) {
                     if (value == null || value.trim().isEmpty) {
                       return 'La description est requise';
                     }
                     return null;
                   },
                   decoration: InputDecoration(
                     labelText: "Description de la tâche",
                     hintText: "Décris la tâche à accomplir",
                     prefixIcon: const Icon(Icons.description_rounded),
                     filled: true,
                     contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16), // ✅ Espace intérieur
                     border: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(30), // ✅ Arrondi plus généreux
                     ),
                   ),
                 ),
                 SizedBox(height: 12),
                 Container(
                   margin: EdgeInsets.only(bottom: 10),
                   child: DateTimeFormField(
                     decoration: InputDecoration(
                       label: Text("Date de réalisation"),
                       prefixIcon: Icon(Icons.calendar_today_rounded),
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                     ),
                     lastDate: DateTime.now().add(Duration(days: 40)),
                     initialPickerDateTime: DateTime.now().add(Duration(days: 20)),
                     onChanged: (DateTime? value) {
                       setState(() {
                         selectedDate = value!;
                       });
                     },
                   ),
                 ),
                 SizedBox(height: 12),
                 Row(
                   children: <Widget>[
                     Expanded(
                       child: ElevatedButton.icon(
                         onPressed: _isLoading
                             ? null
                             : () async {
                           if (_formkey.currentState!.validate()) {
                             setState(() {
                               _isLoading = true;
                             });

                             _updateTaskInfo(
                               task['id'],
                               _titreController.text,
                               _descriptionController.text,
                               selectedDate,
                             );
                             Navigator.of(context).pop();
                             _titreController.clear();
                             _descriptionController.clear();

                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(
                                 content: Text(
                                   "✏️ Modification effectuée avec succès!",
                                   style: TextStyle(color: Colors.white),
                                 ),
                                 behavior: SnackBarBehavior.floating,
                                 backgroundColor: Colors.green,
                                 showCloseIcon: true,
                               ),
                             );

                             setState(() {
                               _isLoading = false;
                             });
                           }
                         },
                         style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.green,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                         ),
                         icon: Icon(Icons.save_rounded, color: Colors.white),
                         label: Text("Sauver", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                       ),
                     ),
                     SizedBox(width: 10),
                     Expanded(
                       child: ElevatedButton.icon(
                         onPressed: () {
                           Navigator.of(context).pop();
                         },
                         style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.red,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                         ),
                         icon: Icon(Icons.cancel_outlined, color: Colors.white),
                         label: Text("Annuler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                       ),
                     ),
                   ],
                 ),
               ],
             ),
           ),
         ),
       );
     },
   );
 }
 //fin de la fonction d'edition de tâche
 Future<void> _showMyDialogAdd() async {
   return showDialog<void>(
     context: context,
     barrierDismissible: true,
     builder: (BuildContext context) {
       return AlertDialog(
         title: ListTile(
           contentPadding: EdgeInsets.zero,
           leading: Icon(Icons.task_alt_rounded, color: Colors.green),
           title: Text("Création d'une tâche", style: TextStyle(fontWeight: FontWeight.bold)),
         ),
         content: SingleChildScrollView(
           child: Form(
             key: _formkey,
             child: Column(
               children: [
                 TextFormField(
                   controller: _titreController,
                   minLines: 2,
                   maxLines: 3, // ✅ Permet d’écrire sur plusieurs lignes
                   validator: (value) {
                     if (value == null || value.trim().isEmpty) {
                       return 'Le titre est requis';
                     }
                     return null;
                   },
                   decoration: InputDecoration(
                     labelText: "Titre de la tâche",
                     hintText: "Ex. : Finaliser l’interface utilisateur",
                     prefixIcon: const Icon(Icons.title_rounded),
                     filled: true,
                     contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16), // ✅ Zone élargie
                     border: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(30), // ✅ Arrondi plus doux
                     ),
                   ),
                 ),
                 const SizedBox(height: 12),

                 TextFormField(
                   controller: _descriptionController,
                   minLines: 4,
                   maxLines: 6, // ✅ Zone plus grande pour les descriptions longues
                   validator: (value) {
                     if (value == null || value.trim().isEmpty) {
                       return 'La description est requise';
                     }
                     return null;
                   },
                   decoration: InputDecoration(
                     labelText: "Description de la tâche",
                     hintText: "Détaille les étapes ou les objectifs de la tâche",
                     prefixIcon: const Icon(Icons.description_rounded),
                     filled: true,
                     contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                     border: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(30),
                     ),
                   ),
                 ),
                 SizedBox(height: 12),
                 Container(
                   margin: EdgeInsets.only(bottom: 10),
                   child: DateTimeFormField(
                     decoration: InputDecoration(
                       label: Text("Date de réalisation"),
                       prefixIcon: Icon(Icons.calendar_today_rounded),
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                     ),
                     lastDate: DateTime.now().add(Duration(days: 40)),
                     initialPickerDateTime: DateTime.now().add(Duration(days: 20)),
                     onChanged: (DateTime? value) {
                       setState(() {
                         selectedDate = value!;
                       });
                     },
                   ),
                 ),
                 SizedBox(height: 12),
                 Row(
                   children: <Widget>[
                     Expanded(
                       child: ElevatedButton.icon(
                         onPressed: _isLoading
                             ? null
                             : () async {
                           if (_formkey.currentState!.validate()) {
                             setState(() {
                               _isLoading = true;
                             });

                             _addTask();
                             Navigator.of(context).pop();
                             _titreController.clear();
                             _descriptionController.clear();

                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(
                                 content: Text(
                                   "✅ La tâche a été ajoutée avec succès !",
                                   style: TextStyle(color: Colors.white),
                                 ),
                                 behavior: SnackBarBehavior.floating,
                                 backgroundColor: Colors.green,
                                 showCloseIcon: true,
                               ),
                             );

                             setState(() {
                               _isLoading = false;
                             });
                           }
                         },
                         style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.green,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                         ),
                         icon: Icon(Icons.save_rounded, color: Colors.white),
                         label: Text("Valider", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                       ),
                     ),
                     SizedBox(width: 2),
                     Expanded(
                       child: ElevatedButton.icon(
                         onPressed: () {
                           Navigator.of(context).pop();
                         },
                         style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.red,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                         ),
                         icon: Icon(Icons.cancel_outlined, color: Colors.white),
                         label: Text("Annuler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                       ),
                     ),
                   ],
                 ),
               ],
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
         title: ListTile(
           contentPadding: EdgeInsets.zero,
           leading: Icon(Icons.warning_amber_rounded, color: Colors.orange),
           title: Text(
             'Confirmation de la réinitialisation de la base de données',
             style: TextStyle(fontWeight: FontWeight.bold),
           ),
         ),
         content: SingleChildScrollView(
           child: ListBody(
             children: [
               Text('Êtes-vous sûr de vouloir réinitialiser la base de données ?'),
             ],
           ),
         ),
         actions: <Widget>[
           ElevatedButton.icon(
             onPressed: () {
               _resetDatabase();
               Navigator.of(context).pop();
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(
                   content: Text(
                     "🧹 La base de données a été réinitialisée avec succès !",
                     style: TextStyle(color: Colors.white),
                   ),
                   behavior: SnackBarBehavior.floating,
                   backgroundColor: Colors.green,
                   showCloseIcon: true,
                 ),
               );
             },
             style: ElevatedButton.styleFrom(
               backgroundColor: Colors.green,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
             ),
             icon: Icon(Icons.restart_alt, color: Colors.white),
             label: Text("Confirmer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
           ),
           ElevatedButton.icon(
             onPressed: () {
               Navigator.of(context).pop();
             },
             style: ElevatedButton.styleFrom(
               backgroundColor: Colors.red,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
             ),
             icon: Icon(Icons.cancel_outlined, color: Colors.white),
             label: Text("Annuler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
         title: ListTile(
           contentPadding: EdgeInsets.zero,
           leading: Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
           title: Text(
             'Confirmation de la suppression',
             style: TextStyle(fontWeight: FontWeight.bold),
           ),
         ),
         content: SingleChildScrollView(
           child: ListBody(
             children: [
               Text('Êtes-vous sûr de vouloir supprimer cette tâche ?'),
             ],
           ),
         ),
         actions: <Widget>[
           ElevatedButton.icon(
             onPressed: () {
               _deleteTask(id);
               Navigator.of(context).pop();
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(
                   content: Text(
                     "🗑️ La tâche a été supprimée avec succès !",
                     style: TextStyle(color: Colors.white),
                   ),
                   behavior: SnackBarBehavior.floating,
                   backgroundColor: Colors.red,
                   showCloseIcon: true,
                 ),
               );
             },
             style: ElevatedButton.styleFrom(
               backgroundColor: Colors.green,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
             ),
             icon: Icon(Icons.check_circle_outline, color: Colors.white),
             label: Text("Confirmer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
           ),
           ElevatedButton.icon(
             onPressed: () {
               Navigator.of(context).pop();
             },
             style: ElevatedButton.styleFrom(
               backgroundColor: Colors.red,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
             ),
             icon: Icon(Icons.cancel_outlined, color: Colors.white),
             label: Text("Annuler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
         style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
       ),
       centerTitle: true,
       shape: const RoundedRectangleBorder(
         borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
       ),
       actions: [
         IconButton(
           onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AproposPage())),
           icon: Icon(Icons.info_outline_rounded),
           color: Colors.white,
           tooltip: "À propos",
         ),
         IconButton(
           onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AidePage())),
           icon: Icon(Icons.help_outline_rounded),
           color: Colors.white,
           tooltip: "Aide",
         ),
         PopupMenuButton<String>(
           icon: Icon(Icons.more_vert, color: Colors.white),
           itemBuilder: (context) => [
             PopupMenuItem(
               value: 'reset',
               child: Row(
                 children: [
                   Icon(Icons.restart_alt, color: Colors.redAccent),
                   SizedBox(width: 8),
                   Text("Réinitialiser la base"),
                 ],
               ),
               onTap: _showMyDialogConfirmation,
             ),
           ],
         ),
       ],
     ),
     floatingActionButton: FloatingActionButton(
       onPressed: _showMyDialogAdd,
       backgroundColor: Colors.green,
       child: Icon(Icons.add_task_rounded, color: Colors.white),
       tooltip: "Ajouter une tâche",
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
                   prefixIcon: Icon(Icons.search_rounded, color: Colors.green),
                   suffixIcon: _searchController.text.isNotEmpty
                       ? IconButton(
                     icon: Icon(Icons.clear_rounded, color: Colors.grey),
                     onPressed: () {
                       _searchController.clear();
                       FocusScope.of(context).unfocus();
                     },
                   )
                       : null,
                   filled: true,
                   fillColor: Colors.white,
                   contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                   enabledBorder: OutlineInputBorder(
                     borderRadius: BorderRadius.circular(30),
                     borderSide: BorderSide(color: Colors.green.shade200),
                   ),
                   focusedBorder: OutlineInputBorder(
                     borderRadius: BorderRadius.circular(30),
                     borderSide: BorderSide(color: Colors.green, width: 2),
                   ),
                 ),
                 style: TextStyle(fontSize: 16),
               ),
             ),
           ),
           Expanded(
             child: ListView.builder(
               itemCount: _filteredTasks.length,
               itemBuilder: (context, index) {
                 final task = _filteredTasks[index];
                 return MouseRegion(
                   cursor: SystemMouseCursors.click,
                   child: AnimatedSwitcher(
                     duration: Duration(milliseconds: 300),
                     child: Card(
                       key: ValueKey(task['id']),
                       elevation: 3,
                       margin: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                       shape: RoundedRectangleBorder(
                         borderRadius: BorderRadius.circular(12),
                       ),
                       child: InkWell(
                         borderRadius: BorderRadius.circular(12),
                         onTap: () {
                           if (task['status'] == 0) {
                             _showMyDialog(task);
                           } else {
                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(
                                 content: Text("⛔ Tâche déjà terminée!", style: TextStyle(color: Colors.white)),
                                 behavior: SnackBarBehavior.floating,
                                 backgroundColor: Colors.red,
                                 showCloseIcon: true,
                               ),
                             );
                           }
                         },
                         onLongPress: () => _showMyDialogSuppression(task['id']),
                         child: ListTile(
                           leading: Icon(
                             task['status'] == 0 ? Icons.edit_note_rounded : Icons.check_circle_outline_rounded,
                             color: task['status'] == 1 ? Colors.green : Colors.orange,
                           ),
                           title: Text(
                             "${task['titre']}",
                             style: TextStyle(
                               color: task['status'] == 1 ? Colors.green : Colors.black,
                               fontWeight: FontWeight.w600,
                             ),
                           ),
                           subtitle: Text(
                             "${task['date']}",
                             style: TextStyle(
                               fontWeight: FontWeight.bold,
                               color: task['status'] == 1 ? Colors.green : Colors.blue,
                               fontSize: 14,
                             ),
                           ),
                           trailing: AnimatedOpacity(
                             duration: Duration(milliseconds: 300),
                             opacity: 1.0,
                             child: Checkbox(
                               value: task['status'] == 1,
                               onChanged: (value) {
                                 _updateTask(task['id'], task['status']);
                                 ScaffoldMessenger.of(context).showSnackBar(
                                   SnackBar(
                                     content: Text(
                                       value == true
                                           ? "✅ Tâche terminée avec succès!"
                                           : "❌ Tâche annulée avec succès!",
                                       style: TextStyle(color: Colors.white),
                                     ),
                                     behavior: SnackBarBehavior.floating,
                                     backgroundColor: value == true ? Colors.green : Colors.red,
                                     showCloseIcon: true,
                                   ),
                                 );
                               },
                             ),
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
}

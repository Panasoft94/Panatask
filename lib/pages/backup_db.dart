import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:panatask/data/db_helper.dart';
import 'package:path/path.dart' as p;

class BackupDbPage extends StatefulWidget {
  const BackupDbPage({super.key});

  @override
  State<BackupDbPage> createState() => _BackupDbPageState();
}

class _BackupDbPageState extends State<BackupDbPage> with SingleTickerProviderStateMixin {
  String _lastBackupPath = 'Aucune sauvegarde récente connue.';
  bool _isSaving = false;
  bool _isRestoring = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    // Demande automatique de permission dès l’ouverture de la page
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestPermission());
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      // Android 11+ (API 30 et plus) → manageExternalStorage
      final manageStatus = await Permission.manageExternalStorage.status;
      if (manageStatus.isGranted) return true;

      final manageResult = await Permission.manageExternalStorage.request();
      if (manageResult.isGranted) return true;

      if (await Permission.manageExternalStorage.isPermanentlyDenied) {
        _showSettingsSnackBar();
        return false;
      }

      // Android < 11 → storage
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) return true;

      final storageResult = await Permission.storage.request();
      if (storageResult.isGranted) return true;

      if (await Permission.storage.isPermanentlyDenied) {
        _showSettingsSnackBar();
        return false;
      }

      // Refus simple
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission de stockage refusée.'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
    // iOS ou autres plateformes
    return true;
  }

  void _showSettingsSnackBar() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Permission de stockage requise. Veuillez l’activer dans les paramètres.'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Paramètres',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    }
  }

  Future<void> _backupDatabase() async {
    setState(() {
      _isSaving = true;
      _lastBackupPath = 'Sauvegarde en cours...';
    });

    try {
      if (!(await _requestPermission())) {
        setState(() {
          _lastBackupPath = 'Permission refusée.';
        });
        return;
      }

      String? filePath = await DbHelper.backupDatabaseToFile();

      if (filePath != null) {
        setState(() {
          _lastBackupPath = 'Sauvegarde réussie : ${p.basename(filePath)}';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Base de données sauvegardée dans $filePath.'), backgroundColor: Colors.green),
          );
        }
      } else {
        setState(() {
          _lastBackupPath = 'Échec de la sauvegarde.';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Échec de la sauvegarde de la base de données.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      setState(() {
        _lastBackupPath = 'Erreur lors de la sauvegarde.';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _restoreDatabase() async {
    setState(() {
      _isRestoring = true;
    });

    try {
      if (!(await _requestPermission())) {
        return;
      }

      // Autoriser tous les fichiers pour contourner la limitation de file_picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        String backupFilePath = result.files.single.path!;

        // Vérification manuelle de l’extension
        if (!backupFilePath.toLowerCase().endsWith(".db")) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Fichier invalide. Veuillez choisir un fichier .db.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        bool? confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirmation de la restauration'),
              content: Text(
                'Voulez-vous vraiment restaurer la base de données à partir de :\n\n${p.basename(backupFilePath)} ?\n\nCeci écrasera les données actuelles.',
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Annuler'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: const Text('Confirmer', style: TextStyle(color: Colors.red)),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        );

        if (confirmed == true) {
          bool success = await DbHelper.restoreDatabaseFromFile(backupFilePath);
          if (success) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Restauration réussie. Redémarrage des tâches.'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.pop(context, true);
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ Échec de la restauration (fichier invalide ou erreur).'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Restauration annulée.'),
              backgroundColor: Colors.grey,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la restauration: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isRestoring = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
        elevation: 6,
        toolbarHeight: 65,
        backgroundColor: Colors.green,
        title: const Text(
          "Sauvegarde et Restauration",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 25,
            color: Colors.white,
            letterSpacing: 1.2
          ),
        ),
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
        body: FadeTransition(
            opacity: _fadeAnimation,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: <Widget>[
              Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.cloud_upload_rounded, color: Colors.green, size: 40),
                title: const Text("Sauvegarder", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Copie la base de données vers le dossier de téléchargement."),
                trailing: _isSaving
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _backupDatabase,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text("Lancer", style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                _lastBackupPath,
                style: TextStyle(fontSize: 12, color: _isSaving ? Colors.orange : Colors.blueGrey),
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(height: 30),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.folder_open_rounded, color: Colors.orange, size: 40),
                    title: const Text("Restaurer", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text("Restaure la base de données à partir d'un fichier .db."),
                    trailing: _isRestoring
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                      onPressed: _restoreDatabase,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: const Text("Choisir", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
        ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:panatask/data/db_helper.dart';
import 'package:path/path.dart' as p;

class BackupDbPage extends StatefulWidget {
  const BackupDbPage({super.key});

  @override
  State<BackupDbPage> createState() => _BackupDbPageState();
}

class _BackupDbPageState extends State<BackupDbPage> {
  String _lastBackupPath = 'Aucune sauvegarde récente connue.';
  bool _isSaving = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _checkBackupStatus();
  }

  Future<void> _checkBackupStatus() async {
    // This function is limited because we cannot easily check the last external backup
    // without storing it somewhere. We will keep it simple for now.
    // The user will see the path of the last successful backup if verification is included.
  }

  Future<void> _requestStoragePermission() async {
    if (Platform.isAndroid || Platform.isIOS) {
      PermissionStatus status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission de stockage requise pour sauvegarder/restaurer.'), backgroundColor: Colors.red),
        );
        return;
      }
    }
  }

  Future<void> _backupDatabase() async {
    setState(() {
      _isSaving = true;
      _lastBackupPath = 'Sauvegarde en cours...';
    });

    try {
      await _requestStoragePermission();
      String? filePath = await DbHelper.backupDatabaseToFile();

      if (filePath != null) {
        setState(() {
          _lastBackupPath = 'Sauvegarde réussie : ${p.basename(filePath)}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Base de données sauvegardée dans ${filePath}.'), backgroundColor: Colors.green),
        );
      } else {
        setState(() {
          _lastBackupPath = 'Échec de la sauvegarde.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Échec de la sauvegarde de la base de données.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() {
        _lastBackupPath = 'Erreur lors de la sauvegarde.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red),
      );
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
      await _requestStoragePermission();

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        String backupFilePath = result.files.single.path!;

        bool? confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirmation de la restauration'),
              content: Text('Voulez-vous vraiment restaurer la base de données à partir de :\n\n${p.basename(backupFilePath)} ?\n\nCeci écrasera les données actuelles.'),
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Restauration réussie. Redémarrage des tâches.'), backgroundColor: Colors.green),
            );
            if (mounted) Navigator.pop(context, true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('❌ Échec de la restauration (fichier invalide ou erreur).'), backgroundColor: Colors.red),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restauration annulée.'), backgroundColor: Colors.grey),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la restauration: ${e.toString()}'), backgroundColor: Colors.red),
      );
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
        title: const Text("Sauvegarde et Restauration"),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Sauvegarder la base de données",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Ceci copie votre base de données locale (.db) vers le dossier de Téléchargement de votre appareil.",
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _backupDatabase,
                      icon: _isSaving
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                          : const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                      label: Text(_isSaving ? "Sauvegarde en cours..." : "Sauvegarder dans Téléchargements", style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(_lastBackupPath, style: TextStyle(fontSize: 12, color: _isSaving ? Colors.orange : Colors.blueGrey)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Restaurer la base de données",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Sélectionnez un fichier de sauvegarde (.db) depuis votre appareil. Les données actuelles seront remplacées.",
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isRestoring ? null : _restoreDatabase,
                      icon: _isRestoring
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                          : const Icon(Icons.folder_open_rounded, color: Colors.white),
                      label: Text(_isRestoring ? "Restauration en cours..." : "Sélectionner le fichier de restauration", style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (Navigator.canPop(context))
                      const Text('Après la restauration, vous serez redirigé vers l\'écran principal pour recharger les données.', style: TextStyle(fontSize: 12, color: Colors.red)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
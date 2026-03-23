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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        toolbarHeight: 65,
        elevation: 1,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ),
        title: const Text(
          "Sauvegarde & Restauration",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoSummary(),
              const SizedBox(height: 32),
              const Text(
                "Options disponibles",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 16),
              _buildActionCard(
                title: "Sauvegarder",
                description: "Crée un point de sauvegarde local de votre base de données actuelle (format .db).",
                icon: Icons.backup_rounded,
                color: Colors.green,
                isLoading: _isSaving,
                onTap: _backupDatabase,
              ),
              const SizedBox(height: 16),
              _buildActionCard(
                title: "Restaurer",
                description: "Importez un fichier de sauvegarde (.db) pour récupérer vos anciennes données.",
                icon: Icons.settings_backup_restore_rounded,
                color: Colors.blue,
                isLoading: _isRestoring,
                onTap: _restoreDatabase,
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        "Attention : La restauration écrasera toutes vos données actuelles. Assurez-vous d'avoir une sauvegarde récente.",
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.storage_rounded, color: Colors.green, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            "État du système",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _lastBackupPath,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                child: isLoading
                    ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                    : Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(description, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

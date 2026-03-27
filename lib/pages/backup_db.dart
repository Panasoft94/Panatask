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
  Map<String, int> _stats = {};

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermission();
      _loadStats();
    });
  }

  Future<void> _loadStats() async {
    try {
      final stats = await DbHelper.getTaskStats();
      if (mounted) setState(() => _stats = stats);
    } catch (_) {}
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      final manageStatus = await Permission.manageExternalStorage.status;
      if (manageStatus.isGranted) return true;

      final manageResult = await Permission.manageExternalStorage.request();
      if (manageResult.isGranted) return true;

      if (await Permission.manageExternalStorage.isPermanentlyDenied) {
        _showSettingsSnackBar();
        return false;
      }

      final storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) return true;

      final storageResult = await Permission.storage.request();
      if (storageResult.isGranted) return true;

      if (await Permission.storage.isPermanentlyDenied) {
        _showSettingsSnackBar();
        return false;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission de stockage refusée.'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
    return true;
  }

  void _showSettingsSnackBar() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Permission de stockage requise. Veuillez l\'activer dans les paramètres.'),
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
        setState(() => _lastBackupPath = 'Permission refusée.');
        return;
      }

      String? filePath = await DbHelper.backupDatabaseToFile();

      if (filePath != null) {
        setState(() => _lastBackupPath = 'Dernière sauvegarde : ${p.basename(filePath)}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Sauvegardée dans $filePath'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
          );
        }
      } else {
        setState(() => _lastBackupPath = 'Échec de la sauvegarde.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Échec de la sauvegarde.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      setState(() => _lastBackupPath = 'Erreur lors de la sauvegarde.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _restoreDatabase() async {
    setState(() => _isRestoring = true);

    try {
      if (!(await _requestPermission())) return;

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        String backupFilePath = result.files.single.path!;

        if (!backupFilePath.toLowerCase().endsWith(".db")) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('❌ Fichier invalide. Veuillez choisir un fichier .db.'), backgroundColor: Colors.red),
            );
          }
          return;
        }

        bool? confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Restauration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                ],
              ),
              content: Text(
                'Restaurer depuis :\n${p.basename(backupFilePath)}\n\nCeci écrasera toutes vos données actuelles.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Confirmer', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
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
                const SnackBar(content: Text('✅ Restauration réussie !'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
              );
              Navigator.pop(context, true);
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('❌ Échec de la restauration.'), backgroundColor: Colors.red),
              );
            }
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Restauration annulée.'), backgroundColor: Colors.grey),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        toolbarHeight: 65,
        elevation: 0,
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
              const SizedBox(height: 24),

              // Stats row
              if (_stats.isNotEmpty) ...[
                Row(
                  children: [
                    _buildStatChip("${_stats['total'] ?? 0}", "Total", Colors.blue),
                    const SizedBox(width: 10),
                    _buildStatChip("${_stats['done'] ?? 0}", "Terminées", Colors.green),
                    const SizedBox(width: 10),
                    _buildStatChip("${_stats['pending'] ?? 0}", "En cours", Colors.orange),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              const Text(
                "Options disponibles",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
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
              const SizedBox(height: 14),
              _buildActionCard(
                title: "Restaurer",
                description: "Importez un fichier de sauvegarde (.db) pour récupérer vos anciennes données.",
                icon: Icons.settings_backup_restore_rounded,
                color: Colors.blue,
                isLoading: _isRestoring,
                onTap: _restoreDatabase,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Attention", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(
                            "La restauration écrasera toutes vos données actuelles. Assurez-vous d'avoir une sauvegarde récente.",
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                          ),
                        ],
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

  Widget _buildStatChip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8), fontWeight: FontWeight.w500)),
          ],
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.storage_rounded, color: Colors.green, size: 36),
          ),
          const SizedBox(height: 16),
          const Text("État du système", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _lastBackupPath,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
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
      elevation: 0,
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
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                child: isLoading
                    ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: color))
                    : Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(description, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.3)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

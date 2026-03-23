import 'package:flutter/material.dart';
import 'package:app_settings/app_settings.dart'; // Ajout de l'import pour le plugin

class ParametresPage extends StatefulWidget {
  const ParametresPage({super.key});

  @override
  State<ParametresPage> createState() => _ParametresPageState();
}

class _ParametresPageState extends State<ParametresPage> {
  // Valeurs initiales pour les paramètres
  bool _autorisationNotifier = true;
  bool _notificationsDiscretes = false;
  bool _styleEcranVerrouille = true;
  bool _styleBannieres = true;

  Future<void> _showConfirmationDialogNotificationsDiscretes(bool newValue) async {
    final actionText = newValue ? "activer" : "désactiver";
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // L'utilisateur doit faire un choix
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Voulez-vous vraiment $actionText les notifications discrètes ?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Ferme la boîte de dialogue
              },
            ),
            TextButton(
              child: const Text('Confirmer'),
              onPressed: () {
                setState(() {
                  _notificationsDiscretes = newValue;
                  // Ici, vous pourriez ajouter une logique de sauvegarde si nécessaire
                });
                Navigator.of(dialogContext).pop(); // Ferme la boîte de dialogue
              },
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
          "Paramètres",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("NOTIFICATIONS GÉNÉRALES"),
            _buildSettingCard(
              child: SwitchListTile(
                title: const Text('Autorisation de notifier', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Gérer les permissions système'),
                value: _autorisationNotifier,
                onChanged: (bool value) {
                  setState(() => _autorisationNotifier = value);
                  AppSettings.openAppSettings(type: AppSettingsType.notification);
                },
                secondary: _buildIcon(Icons.notifications_active_rounded, Colors.blue),
                activeColor: Colors.green,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
            _buildSettingCard(
              child: SwitchListTile(
                title: const Text('Notifications discrètes', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text("Silencieuses et uniquement dans le panneau de notification."),
                value: _notificationsDiscretes,
                onChanged: (bool value) => _showConfirmationDialogNotificationsDiscretes(value),
                secondary: _buildIcon(Icons.notifications_paused_rounded, Colors.orange),
                activeColor: Colors.green,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader("STYLE D'AFFICHAGE"),
            _buildSettingCard(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Écran verrouillé', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Afficher sur l\'écran de verrouillage'),
                    value: _styleEcranVerrouille,
                    onChanged: (bool value) => setState(() => _styleEcranVerrouille = value),
                    secondary: _buildIcon(Icons.screen_lock_portrait_rounded, Colors.indigo),
                    activeColor: Colors.green,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(height: 1)),
                  SwitchListTile(
                    title: const Text('Bannières', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Afficher en haut de l\'écran'),
                    value: _styleBannieres,
                    onChanged: (bool value) => setState(() => _styleBannieres = value),
                    secondary: _buildIcon(Icons.view_stream_rounded, Colors.teal),
                    activeColor: Colors.green,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader("SYSTÈME"),
            _buildSettingCard(
              child: ListTile(
                leading: _buildIcon(Icons.volume_up_rounded, Colors.purple),
                title: const Text('Son des notifications', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Changer la sonnerie dans les réglages'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                onTap: () => AppSettings.openAppSettings(type: AppSettingsType.notification),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Text(
        title,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildSettingCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

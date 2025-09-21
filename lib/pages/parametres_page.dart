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
      appBar: AppBar(
        title: const Text('Paramètres de notification', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(8.0),
        children: <Widget>[
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: SwitchListTile(
              title: const Text('Autorisation de notifier'),
              value: _autorisationNotifier,
              onChanged: (bool value) {
                setState(() {
                  _autorisationNotifier = value;
                });
                AppSettings.openAppSettings(type: AppSettingsType.notification);
              },
              secondary: const Icon(Icons.notifications_active_outlined),
              contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: SwitchListTile(
              title: const Text('Notifications discrètes'),
              subtitle: const Text(
                  "Les notifications sont silencieuses et n'apparaissent que sur le panneau de notification."),
              value: _notificationsDiscretes,
              onChanged: (bool value) {
                // N'appelle plus setState directement ici.
                // Appelle la boîte de dialogue de confirmation.
                _showConfirmationDialogNotificationsDiscretes(value);
              },
              secondary: const Icon(Icons.notifications_paused_outlined),
              contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              children: [
                const ListTile(
                  title: Text(
                    'STYLE DE NOTIFICATION',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  contentPadding: EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0, bottom: 0.0),
                ),
                SwitchListTile(
                  title: const Text('Ecran verrouillé'),
                  subtitle: const Text('Afficher les notifications sur l\'écran de verrouillage.'),
                  value: _styleEcranVerrouille,
                  onChanged: (bool value) {
                    setState(() {
                      _styleEcranVerrouille = value;
                      // Logique de sauvegarde
                    });
                  },
                  secondary: const Icon(Icons.screen_lock_portrait_outlined),
                  contentPadding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Divider(),
                ),
                SwitchListTile(
                  title: const Text('Bannières'),
                  subtitle: const Text('Afficher les notifications sous forme de bannières en haut de l\'écran.'),
                  value: _styleBannieres,
                  onChanged: (bool value) {
                    setState(() {
                      _styleBannieres = value;
                      // Logique de sauvegarde
                    });
                  },
                  secondary: const Icon(Icons.view_stream_outlined),
                  contentPadding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
                ),
              ],
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: ListTile(
              leading: const Icon(Icons.volume_up_outlined),
              title: const Text('Son des notifications'),
              subtitle: const Text('Ouvrir les paramètres du téléphone pour changer la sonnerie.'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 18.0),
              contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              onTap: () {
                AppSettings.openAppSettings(type: AppSettingsType.notification);
              },
            ),
          ),
        ],
      ),
    );
  }
}

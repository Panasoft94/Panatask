import 'package:flutter/material.dart';
import 'package:app_settings/app_settings.dart';

class ParametresPage extends StatefulWidget {
  const ParametresPage({super.key});

  @override
  State<ParametresPage> createState() => _ParametresPageState();
}

class _ParametresPageState extends State<ParametresPage> with SingleTickerProviderStateMixin {
  bool _autorisationNotifier = true;
  bool _notificationsDiscretes = false;
  bool _styleEcranVerrouille = true;
  bool _styleBannieres = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _showConfirmationDialogNotificationsDiscretes(bool newValue) async {
    final actionText = newValue ? "activer" : "désactiver";
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications_paused_rounded, color: Colors.orange, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Confirmation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            ],
          ),
          content: Text(
            'Voulez-vous vraiment $actionText les notifications discrètes ?',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.4),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actions: <Widget>[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
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
                    onPressed: () {
                      setState(() => _notificationsDiscretes = newValue);
                      Navigator.of(dialogContext).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
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
          "Paramètres",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.tune_rounded, color: Colors.green.shade600, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Configuration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          SizedBox(height: 2),
                          Text("Personnalisez votre expérience", style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

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
                  subtitle: const Text("Silencieuses, uniquement dans le panneau."),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(height: 1, color: Colors.grey.shade100),
                    ),
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
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
                  onTap: () => AppSettings.openAppSettings(type: AppSettingsType.notification),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
              _buildSettingCard(
                child: ListTile(
                  leading: _buildIcon(Icons.storage_rounded, Colors.blueGrey),
                  title: const Text('Stockage de l\'application', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Gérer le cache et les données'),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
                  onTap: () => AppSettings.openAppSettings(type: AppSettingsType.internalStorage),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
              _buildSettingCard(
                child: ListTile(
                  leading: _buildIcon(Icons.battery_saver_rounded, Colors.green.shade700),
                  title: const Text('Optimisation batterie', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Désactiver pour des notifications fiables'),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
                  onTap: () => AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),

              const SizedBox(height: 32),

              // App info footer
              Center(
                child: Opacity(
                  opacity: 0.5,
                  child: Column(
                    children: [
                      Text("Panatask v1.6.4", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 2),
                      Text("© 2025 Panasoft Corporation", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }

  Widget _buildIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AidePage extends StatefulWidget {
  const AidePage({super.key});

  @override
  State<AidePage> createState() => _AidePageState();
}

class _AidePageState extends State<AidePage> with SingleTickerProviderStateMixin {
  final _formkey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _commentaireController = TextEditingController();
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _commentaireController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    final nom = _nomController.text.trim();
    final prenom = _prenomController.text.trim();
    final email = _emailController.text.trim();
    final commentaire = _commentaireController.text.trim();

    final subject = Uri.encodeComponent("Commentaire de $prenom $nom");
    final body = Uri.encodeComponent("Nom: $nom\nPrénom: $prenom\nEmail: $email\n\nCommentaire:\n$commentaire");

    final mailtoLink = Uri.parse("mailto:webmasterdjim@gmail.com?subject=$subject&body=$body");

    if (await canLaunchUrl(mailtoLink)) {
      await launchUrl(mailtoLink);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Impossible d'ouvrir le client mail."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final aideItems = [
      {
        "title": "Créer une tâche",
        "text": "Appuyez sur le bouton \"Nouvelle Tâche\" en bas à droite pour ajouter une tâche avec titre, description, priorité et dates.",
        "icon": Icons.add_task_rounded,
        "color": Colors.green,
      },
      {
        "title": "Modifier une tâche",
        "text": "Appuyez sur une tâche pour voir ses détails, puis cliquez sur \"Modifier\" pour éditer les informations.",
        "icon": Icons.edit_note_rounded,
        "color": Colors.orange,
      },
      {
        "title": "Terminer / Rétablir",
        "text": "Cochez la case à gauche d'une tâche, ou glissez vers la droite pour changer son statut (terminée ↔ en cours).",
        "icon": Icons.check_circle_outline_rounded,
        "color": Colors.blue,
      },
      {
        "title": "Supprimer une tâche",
        "text": "Glissez une tâche vers la gauche pour la mettre à la corbeille.",
        "icon": Icons.delete_sweep_rounded,
        "color": Colors.red,
      },
      {
        "title": "Réorganiser les tâches",
        "text": "Effectuez un appui long sur une tâche puis glissez-la pour changer son ordre dans la liste.",
        "icon": Icons.swap_vert_rounded,
        "color": Colors.deepPurple,
      },
      {
        "title": "Rechercher & Filtrer",
        "text": "Utilisez l'icône de recherche pour trouver une tâche, et les filtres rapides pour afficher par statut.",
        "icon": Icons.filter_alt_rounded,
        "color": Colors.teal,
      },
      {
        "title": "Notifications & Rappels",
        "text": "Les rappels sont programmés automatiquement. Pour les tâches longues, un rappel quotidien est envoyé entre la date de début et de fin.",
        "icon": Icons.notifications_active_rounded,
        "color": Colors.amber.shade700,
      },
      {
        "title": "Sauvegarder / Restaurer",
        "text": "Accédez à Sauvegarde depuis le menu pour créer un backup de vos données ou restaurer une sauvegarde.",
        "icon": Icons.backup_rounded,
        "color": Colors.indigo,
      },
    ];

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
          "Aide & Feedback",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header card with gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
                  ],
                ),
                child: const Column(
                  children: [
                    Icon(Icons.menu_book_rounded, color: Colors.white, size: 40),
                    SizedBox(height: 12),
                    Text("Guide d'utilisation", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    SizedBox(height: 6),
                    Text("Découvrez comment utiliser Panatask efficacement",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Guide items - expandable tiles with staggered animation
              ...List.generate(aideItems.length, (index) {
                final item = aideItems[index];
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 400 + (index * 80)),
                  curve: Curves.easeOut,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (item["color"] as Color).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(item["icon"] as IconData, color: item["color"] as Color, size: 22),
                        ),
                        title: Text(
                          item["title"] as String,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        iconColor: Colors.grey.shade400,
                        collapsedIconColor: Colors.grey.shade400,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              item["text"] as String,
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 32),

              // Feedback section header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.chat_bubble_outline_rounded, color: Colors.green.shade600, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Envoyez-nous un commentaire", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        Text("Votre avis nous aide à améliorer l'app", style: TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Feedback form
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                child: Form(
                  key: _formkey,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _nomController,
                              label: "Nom",
                              icon: Icons.person_rounded,
                              validator: (value) => value == null || value.isEmpty ? "Requis" : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _prenomController,
                              label: "Prénom",
                              icon: Icons.person_outline_rounded,
                              validator: (value) => value == null || value.isEmpty ? "Requis" : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _emailController,
                        label: "Adresse E-mail",
                        icon: Icons.email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) => value == null || !value.contains("@") ? "Email valide requis" : null,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _commentaireController,
                        label: "Votre message",
                        icon: Icons.chat_bubble_rounded,
                        maxLines: 4,
                        validator: (value) => value == null || value.isEmpty ? "Commentaire requis" : null,
                      ),
                      const SizedBox(height: 20),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(color: Colors.green),
                              )
                            : SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                  label: const Text("Envoyer le feedback",
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    elevation: 2,
                                    shadowColor: Colors.green.withOpacity(0.3),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  ),
                                  onPressed: () async {
                                    if (_formkey.currentState!.validate()) {
                                      setState(() => _isLoading = true);
                                      await _sendEmail();
                                      setState(() => _isLoading = false);
                                      if (mounted) {
                                        _nomController.clear();
                                        _prenomController.clear();
                                        _emailController.clear();
                                        _commentaireController.clear();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text("🚀 Merci pour votre retour !"),
                                            backgroundColor: Colors.green,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.green.shade400, size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.green.shade400, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade200),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

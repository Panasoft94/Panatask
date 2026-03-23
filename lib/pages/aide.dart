import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AidePage extends StatefulWidget {
  const AidePage({super.key});

  @override
  State<AidePage> createState() => _AidePageState();
}

class _AidePageState extends State<AidePage> {
  final _formkey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _commentaireController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _commentaireController.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible d'ouvrir le client mail."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final aideItems = [
      {
        "text": "Pour créer une nouvelle tâche...",
        "icon": Icons.add_circle_outline,
        "color": Colors.green,
      },
      {
        "text": "Pour modifier une tâche...",
        "icon": Icons.edit_note_rounded,
        "color": Colors.orange,
      },
      {
        "text": "Pour clôturer une tâche...",
        "icon": Icons.check_box_rounded,
        "color": Colors.blue,
      },
      {
        "text": "Pour supprimer une tâche...",
        "icon": Icons.delete_forever_rounded,
        "color": Colors.red,
      },
      {
        "text": "Pour réinitialiser la base de données...",
        "icon": Icons.restart_alt_rounded,
        "color": Colors.purple,
      },
      // Ajout de l'aide pour les paramètres
      {
        "text": "Pour accéder aux paramètres de l'application...",
        "icon": Icons.settings_outlined,
        "color": Colors.blueGrey,
      },
    ];

    const _inputDecoration = InputDecoration(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(30)),
      ),
    );

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
          "Aide & Feedback",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Guide d'utilisation",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 16),
            ...aideItems.map((item) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (item["color"] as Color).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item["icon"] as IconData, color: item["color"] as Color, size: 20),
                    ),
                    title: Text(item["text"] as String, style: const TextStyle(fontSize: 14)),
                  ),
                )),
            const SizedBox(height: 32),
            const Text(
              "Envoyez-nous un commentaire",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Form(
                key: _formkey,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _nomController,
                      label: "Nom",
                      icon: Icons.person_rounded,
                      validator: (value) => value == null || value.isEmpty ? "Nom requis" : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _prenomController,
                      label: "Prénom",
                      icon: Icons.person_outline_rounded,
                      validator: (value) => value == null || value.isEmpty ? "Prénom requis" : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _emailController,
                      label: "Adresse E-mail",
                      icon: Icons.email_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) => value == null || !value.contains("@") ? "Email valide requis" : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _commentaireController,
                      label: "Votre message",
                      icon: Icons.chat_bubble_rounded,
                      maxLines: 4,
                      validator: (value) => value == null || value.isEmpty ? "Commentaire requis" : null,
                    ),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.green)
                          : SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.send_rounded, color: Colors.white),
                                label: const Text("Envoyer le feedback",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                ),
                                onPressed: () async {
                                  if (_formkey.currentState!.validate()) {
                                    setState(() => _isLoading = true);
                                    await _sendEmail();
                                    setState(() => _isLoading = false);
                                    if (mounted) {
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
        prefixIcon: Icon(icon, color: Colors.green.shade400, size: 22),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.green.shade400, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red.shade200),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

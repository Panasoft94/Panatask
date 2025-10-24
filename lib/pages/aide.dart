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
    ];

    return Scaffold(
      appBar: AppBar(
        elevation: 6,
        toolbarHeight: 65,
        backgroundColor: Colors.green,
        title: const Text(
          "Aide & commentaire ",
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
      body: Center(
        child: Card(
          elevation: 4,
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      ...aideItems.map((item) => Column(
                        children: [
                          ListTile(
                            leading: Icon(item["icon"] as IconData, color: item["color"] as Color),
                            title: Text(item["text"] as String),
                          ),
                          const Divider(),
                        ],
                      )),
                      const SizedBox(height: 12),
                      Form(
                        key: _formkey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nomController,
                              validator: (value) => value == null || value.isEmpty ? "Nom requis" : null,
                              decoration: const InputDecoration(
                                labelText: "Nom de la famille",
                                prefixIcon: Icon(Icons.person),
                                filled: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _prenomController,
                              validator: (value) => value == null || value.isEmpty ? "Prénom requis" : null,
                              decoration: const InputDecoration(
                                labelText: "Prénom",
                                prefixIcon: Icon(Icons.person_outline),
                                filled: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailController,
                              validator: (value) => value == null || !value.contains("@") ? "Email valide requis" : null,
                              decoration: const InputDecoration(
                                labelText: "Adresse E-mail",
                                prefixIcon: Icon(Icons.email),
                                filled: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _commentaireController,
                              validator: (value) => value == null || value.isEmpty ? "Commentaire requis" : null,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: "Contenu du commentaire",
                                prefixIcon: Icon(Icons.comment),
                                filled: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 20),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _isLoading
                                  ? const CircularProgressIndicator()
                                  : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.send,color: Colors.white,),
                                  label: const Text("Envoyer", style: TextStyle(fontSize: 18,color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  onPressed: () async {
                                    if (_formkey.currentState!.validate()) {
                                      setState(() => _isLoading = true);
                                      await _sendEmail();
                                      setState(() => _isLoading = false);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("Commentaire envoyé avec succès!", style: TextStyle(color: Colors.white)),
                                          backgroundColor: Colors.green,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
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
      ),
    );
  }
}
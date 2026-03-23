import 'package:flutter/material.dart';

class AproposPage extends StatefulWidget {
  const AproposPage({super.key});

  @override
  State<AproposPage> createState() => _AproposPageState();
}

class _AproposPageState extends State<AproposPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
          "À propos",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Image.asset("assets/img/default.jpg", width: double.infinity, height: 220, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Anicet DJIMTOLOUMA",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            const Text(
              "Co-fondateur & Développeur",
              style: TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 32),
            _buildAboutCard(
              icon: Icons.work_rounded,
              iconColor: Colors.indigo,
              content: "Analyste & Programmeur chevronné chez Panasoft Coorporation.",
            ),
            const SizedBox(height: 16),
            _buildAboutCard(
              icon: Icons.contact_mail_rounded,
              iconColor: Colors.green,
              title: "Contact Direct",
              content: "WhatsApp : (+236) 72395935\nEmail : webmasterdjim@gmail.com",
            ),
            const SizedBox(height: 16),
            _buildAboutCard(
              icon: Icons.business_center_rounded,
              iconColor: Colors.orange,
              title: "Panasoft Coorporation",
              content:
                  "Nous créons des solutions logicielles personnalisées et innovantes pour répondre aux défis uniques de votre entreprise. Notre expertise transforme vos idées en réalité numérique.",
            ),
            const SizedBox(height: 48),
            const Opacity(
              opacity: 0.5,
              child: Column(
                children: [
                  Icon(Icons.copyright_rounded, size: 20),
                  SizedBox(height: 4),
                  Text(
                    "© 2025 Tous Droits Réservés\nPanasoft Coorporation",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard({required IconData icon, required Color iconColor, String? title, required String content}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                Text(
                  content,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
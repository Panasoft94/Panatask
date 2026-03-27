import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
          "À propos",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            // Profile section with animation
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              ),
              child: Column(
                children: [
                  Container(
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
                  const SizedBox(height: 20),
                  const Text(
                    "Anicet DJIMTOLOUMA",
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "Ingénieur Logiciel & CEO",
                      style: TextStyle(fontSize: 14, color: Colors.green.shade700, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // About cards with staggered animation
            _buildAnimatedCard(
              delay: 200,
              child: _buildAboutCard(
                icon: Icons.work_rounded,
                iconColor: Colors.indigo,
                title: "Profil Professionnel",
                content: "Ingénieur logiciel, Développeur web et mobile, CEO Panasoft Corporation. Passionné par la création de solutions innovantes.",
              ),
            ),
            const SizedBox(height: 14),
            _buildAnimatedCard(
              delay: 350,
              child: _buildAboutCard(
                icon: Icons.contact_mail_rounded,
                iconColor: Colors.green,
                title: "Contact Direct",
                content: "WhatsApp : (+236) 72395935\nEmail : webmasterdjim@gmail.com",
              ),
            ),
            const SizedBox(height: 14),
            _buildAnimatedCard(
              delay: 500,
              child: _buildAboutCard(
                icon: Icons.business_center_rounded,
                iconColor: Colors.orange,
                title: "Panasoft Corporation",
                content:
                    "Nous créons des solutions logicielles personnalisées et innovantes pour répondre aux défis uniques de votre entreprise. Notre expertise transforme vos idées en réalité numérique.",
              ),
            ),

            const SizedBox(height: 28),

            // Quick actions
            _buildAnimatedCard(
              delay: 650,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    _buildContactTile(
                      icon: Icons.email_rounded,
                      color: Colors.red,
                      title: "Envoyer un email",
                      subtitle: "webmasterdjim@gmail.com",
                      onTap: () => _launchUrl("mailto:webmasterdjim@gmail.com"),
                    ),
                    Divider(height: 1, indent: 72, color: Colors.grey.shade100),
                    _buildContactTile(
                      icon: Icons.phone_rounded,
                      color: Colors.green,
                      title: "WhatsApp",
                      subtitle: "(+236) 72395935",
                      onTap: () => _launchUrl("https://wa.me/23672395935"),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // App version info
            _buildAnimatedCard(
              delay: 800,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.green.withOpacity(0.15), blurRadius: 10),
                        ],
                      ),
                      child: Image.asset("assets/img/logo.png", width: 40, height: 40),
                    ),
                    const SizedBox(height: 12),
                    const Text("Panatask", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("Version 1.6.4", style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
            Opacity(
              opacity: 0.5,
              child: Column(
                children: [
                  Text(
                    "© 2025 Tous Droits Réservés",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Panasoft Corporation",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
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

  Widget _buildAnimatedCard({required int delay, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOut,
      builder: (context, value, c) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: c,
        ),
      ),
      child: child,
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
      trailing: Icon(Icons.open_in_new_rounded, size: 18, color: Colors.grey.shade400),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildAboutCard({required IconData icon, required Color iconColor, String? title, required String content}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
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
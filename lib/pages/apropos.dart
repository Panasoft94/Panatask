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
      appBar: AppBar(
        elevation: 6,
        toolbarHeight: 65,
        backgroundColor: Colors.green,
        title: const Text(
          "Apropos",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
            letterSpacing: 1.2,
              fontFamily: "BodoniMT"
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 15),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => Opacity(
                  opacity: _opacityAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  ),
                ),
                child: Image.asset("assets/img/default.jpg", width: 600, height: 240),
              ),
              const SizedBox(height: 10),
              const Text(
                "Anicet DJIMTOLOUMA",
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, fontFamily: "BodoniMT"),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    const Divider(),
                    const ListTile(
                      leading: Icon(Icons.work_outline, color: Colors.indigo),
                      title: Text(
                        "Analyste & Programmeur, Co-fondateur de l'Entreprise Panasoft Coorporation.",
                        style: TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Divider(),
                    const ListTile(
                      leading: Icon(Icons.phone_android, color: Colors.green),
                      title: Text("WhatsApp : (+236) 72395935 / 70043963",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Email : webmasterdjim@gmail.com",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const Divider(),
                    const ListTile(
                      leading: Icon(Icons.business_rounded, color: Colors.orange),
                      title: Text(
                        "Panasoft Coorporation est une Entreprise de développement de logiciels. Notre équipe de professionnels chevronnés se consacre à la fourniture de solutions logicielles personnalisées qui répondent aux exigences uniques de votre entreprise. Qu'il s'agit de développer un nouveau logiciel à partir de zéro ou de modifier des systèmes existants, nous disposons de l'expertise nécessaire pour vous aider à atteindre vos objectifs.",
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                    const Divider(),
                    const ListTile(
                      leading: Icon(Icons.copyright, color: Colors.grey),
                      subtitle: Text(
                        "© 2025 Tous Droits Réservés Panasoft Coorporation",
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
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
}
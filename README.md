# ✅ Panatask

**Panatask** est une application de gestion de tâches moderne, conçue pour vous aider à organiser votre quotidien avec clarté, efficacité et élégance. Grâce à une interface intuitive et une base de données locale rapide via SQLite, Panatask vous permet de planifier, suivre et accomplir vos objectifs, même hors ligne.

---

## 🚀 Fonctionnalités

- 📝 **Gestion complète des tâches** : Création et modification intuitives (titre, description, dates de rappel/échéance, définition des priorités).
- 🔄 **Réorganisation Drag & Drop** : Réorganisez l'ordre de vos tâches selon vos envies par un simple appui long.
- ⚡ **Actions Rapides (Swipe)** : Glissez une tâche à gauche pour supprimer ou à droite pour changer le statut (terminée/en cours).
- 🔍 **Recherche Dynamique** : Barre de recherche intégrée de façon transparente directement dans l'AppBar sans surcharger l'interface.
- 🎛️ **Filtres Rapides** : Triez l'affichage ("Toutes", "En cours", "Terminées") d'un seul clic avec les puces (Chips).
- 📊 **Tableau de Bord Moderne** : Jauge de progression repensée avec un design épuré, fond blanc éclatant et ombres élégantes.
- 🎨 **Interface Harmonieuse** : Modales de création et d'édition standardisées ; marges soignées, icônes colorées et un magnifique thème vert cohérent.
- 🔔 **Notifications Intelligentes & Récurrentes** : Alertes programmées gérées localement avec reprogrammation automatique au démarrage de l'application. Support des rappels quotidiens entre deux dates et des rappels uniques.
- 💾 **Base de Données Locale** : Fonctionne via **SQLite** pour une rapidité absolue hors-ligne, incluant des fonctionnalités de sauvegarde/restauration.
- 🗑️ **Corbeille** : Suppression douce (soft delete) avec possibilité de restaurer les tâches supprimées.
- ⚙️ **Paramètres** : Configuration personnalisée des notifications (discrètes, bannières, écran de verrouillage).
- 📬 **Aide & Feedback** : Formulaire intégré pour envoyer vos retours directement par email.

---

## 🐛 Corrections récentes (v1.6.4)

- ✅ **Notifications récurrentes** : Correction du bug empêchant les notifications programmées de fonctionner. Le plugin est maintenant correctement initialisé au démarrage avec les canaux de notification Android.
- ✅ **Reprogrammation automatique** : Toutes les notifications sont reprogrammées au lancement de l'application pour survivre aux redémarrages du téléphone.
- ✅ **Fuseau horaire** : Correction de l'appel `FlutterTimezone.getLocalTimezone()` qui retourne maintenant correctement un `String` (compatible flutter_timezone 5.x).
- ✅ **Limite de notifications** : Plafond de 50 notifications quotidiennes par tâche pour éviter de dépasser la limite d'alarmes exactes d'Android.
- ✅ **Permission alarmes exactes** : Demande automatique de la permission `SCHEDULE_EXACT_ALARM` sur Android 12+.
- ✅ **Sauvegarde/Restauration** : Correction d'une erreur de syntaxe dans la gestion des permissions de stockage.
- ✅ **Statistiques** : Ajout de méthodes pour récupérer les statistiques des tâches.

---

## 📸 Aperçu

> *(Ajoute ici des captures d'écran de l'app une fois disponibles)*

---

## 🛠️ Technologies utilisées

- **Flutter 3.x** – UI rapide et multiplateforme
- **SQFlite** – Base de données locale embarquée
- **Flutter Local Notifications** – Alertes programmées en arrière-plan avec canaux Android
- **Flutter Timezone** – Gestion précise des fuseaux horaires pour les notifications
- **Animations Flutter** – Transitions fluides, ReorderableListView pour Drag & Drop, BottomSheets stylisées
- **Date Field & Intl** – Composants avancés pour les dates et localisation française
- **Permission Handler** – Gestion des permissions Android (notifications, stockage)
- **File Picker** – Sélection de fichiers pour la restauration de sauvegarde

---

## 📦 Installation

```bash
git clone https://github.com/ton-utilisateur/panatask.git
cd panatask
flutter pub get
flutter run
```

---

## 📋 Permissions requises (Android)

| Permission | Usage |
|---|---|
| `POST_NOTIFICATIONS` | Envoi de notifications de rappel |
| `SCHEDULE_EXACT_ALARM` | Programmation d'alarmes exactes (Android 12) |
| `USE_EXACT_ALARM` | Alarmes exactes (Android 13+) |
| `RECEIVE_BOOT_COMPLETED` | Reprogrammation après redémarrage |
| `MANAGE_EXTERNAL_STORAGE` | Sauvegarde/restauration de la base de données |

---

## 📁 Architecture du projet

```
lib/
├── main.dart                  # Point d'entrée, initialisation notifications
├── data/
│   └── db_helper.dart         # Helper SQLite (CRUD, stats, backup)
└── pages/
    ├── home.dart              # Page principale (liste, filtres, CRUD tâches)
    ├── aide.dart              # Guide d'utilisation & formulaire feedback
    ├── apropos.dart           # Page À propos
    ├── backup_db.dart         # Sauvegarde & restauration de la BDD
    └── parametres_page.dart   # Paramètres de notification
```

---

© 2025 Panasoft Corporation – Tous droits réservés

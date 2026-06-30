import 'dart:async';

import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_colors.dart';
import 'core/cat_session.dart';
import 'models/cat_profile.dart';
import 'services/firebase_service.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/schedule/schedule_screen.dart';
import 'screens/activity_logs/activity_logs_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/onboarding/add_cat_screen.dart';

class CatFeederApp extends StatelessWidget {
  const CatFeederApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Cat Feeder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const CatGate(),
    );
  }
}

/// Watches the list of registered cats and makes sure a valid [CatSession]
/// is available to the rest of the app before showing the main UI.
///
/// - No cats yet -> forces [AddCatScreen] (can't be dismissed).
/// - At least one cat -> wraps [MainShell] with [CatSessionScope], keeping
///   the selection valid as cats are added/removed elsewhere.
class CatGate extends StatefulWidget {
  const CatGate({super.key});

  @override
  State<CatGate> createState() => _CatGateState();
}

class _CatGateState extends State<CatGate> {
  final FirebaseService _firebaseService = FirebaseService();
  final CatSession _catSession = CatSession();

  List<CatProfile>? _cats;
  StreamSubscription<List<CatProfile>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = _firebaseService.watchCats().listen((cats) {
      // Update the session outside of the build phase (safe to call
      // notifyListeners here since this runs as a stream callback, not
      // synchronously inside build()).
      _catSession.updateFromList(cats);
      if (mounted) setState(() => _cats = cats);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _catSession.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cats = _cats;

    if (cats == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (cats.isEmpty) {
      return AddCatScreen(firebaseService: _firebaseService);
    }

    return CatSessionScope(
      session: _catSession,
      child: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  late final List<Widget> _screens = [
    DashboardScreen(
      onNavigate: (index) => setState(() => _selectedIndex = index),
    ),
    const ScheduleScreen(),
    const ActivityLogsScreen(),
    const NotificationsScreen(),
    const SettingsScreen(),
  ];

  final List<NavigationDestination> _destinations = const [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_month_outlined),
      selectedIcon: Icon(Icons.calendar_month_rounded),
      label: 'Schedule',
    ),
    NavigationDestination(
      icon: Icon(Icons.list_alt_outlined),
      selectedIcon: Icon(Icons.list_alt_rounded),
      label: 'Logs',
    ),
    NavigationDestination(
      icon: Icon(Icons.notifications_outlined),
      selectedIcon: Icon(Icons.notifications_rounded),
      label: 'Alerts',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings_rounded),
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.divider, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          destinations: _destinations,
        ),
      ),
    );
  }
}

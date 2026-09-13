import 'package:flutter/material.dart';
import 'package:my_app/core/constants/app_colors.dart';
import 'package:my_app/core/database/tables/db.dart';
import 'package:my_app/core/widgets/doctor_logo.dart';
import 'package:my_app/features/dose/screens/dose_log_screen.dart';
import 'package:my_app/features/home/screens/home_screen.dart';
import 'package:my_app/features/medicines/screens/add_medicine_screen.dart';
import 'package:my_app/features/profile/screens/profile_screen.dart';
import 'package:my_app/features/schedules/screens/add_medicine_schedules_screen.dart';
import 'package:my_app/features/user/user_form_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications BEFORE the UI starts.

  runApp(
    const MedicineApp(),
  );
}
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
class MedicineApp extends StatelessWidget {
  const MedicineApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [routeObserver],
      title: 'Medicine Reminder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: kBrandColor,
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: kBrandColor,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: kBrandColor.withOpacity(0.15),
          height: 68,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? kBrandColor : Colors.grey.shade600,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? kBrandColor : Colors.grey.shade500,
            );
          }),

        ),
      ),
      home: const AppEntryPoint(),
    );
  }
}

class AppEntryPoint extends StatelessWidget {
  const AppEntryPoint({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: DBHelper.instance.getLatestUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            body: Center(
              child: DoctorLogo(size: 72, color: kBrandColor),
            ),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          return const MainScreen();
        } else {
          return const UserFormScreen();
        }
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    MedicinesScreen(),
    MedicineSchedulesScreen(),
    DoseLogScreen(),
    ProfileScreen(),
  ];

  final List<String> _titles = const [
    'Home',
    'Medicine',
    'Schedule',
    'Dose Log',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DoctorLogo(size: 28, color: Colors.white),
            const SizedBox(width: 8),
            Text(_titles[_currentIndex]),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication),
            label: 'Add Med',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'Dose Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
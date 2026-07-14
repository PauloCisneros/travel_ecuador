import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/session_provider.dart';
import 'providers/favorito_provider.dart';
import 'providers/visita_provider.dart';

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/profile_screen.dart';

import 'splash_screen.dart'; // Importa el splash screen
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zjjalezwyjrlykkhtwcj.supabase.co',
    publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpqamFsZXp3eWpybHlra2h0d2NqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxNzU1ODQsImV4cCI6MjA5Mzc1MTU4NH0._yegNjxY491ppNIj5BFAgtYK5HwlWVipMFKc9bFCOyg',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionProvider()),
        ChangeNotifierProvider(create: (_) => FavoritoProvider()),
        ChangeNotifierProvider(create: (_) => VisitaProvider()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Cambia esto para mostrar el SplashScreen primero
      home: const SplashScreenWrapper(),
      // home: const AuthGate(), // Ya no usamos esto directamente
    );
  }
}

// Wrapper que decide qué mostrar después del splash
class SplashScreenWrapper extends StatelessWidget {
  const SplashScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();

    if (session.isLoggedIn) {
      return const MainTabsScreen();
    }

    return const LoginScreen();
  }
}

class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({super.key});

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    FavoritesScreen(),
    ProfileScreen(),
  ];

  final List<BottomNavigationBarItem> _bottomNavItems = const [
    BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: 'Inicio',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.favorite),
      label: 'Favoritos',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person),
      label: 'Perfil',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final session = context.read<SessionProvider>();
      if (session.user != null) {
        await context.read<FavoritoProvider>().loadFavoritos(session.user!.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      // Colores heredados de bottomNavigationBarTheme (AppTheme.light),
      // ya no se fijan aquí de forma manual.
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: _bottomNavItems,
      ),
    );
  }
}
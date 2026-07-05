import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/session_provider.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://fdhafcaigmdrcutbejdi.supabase.co',   // URL de tu proyecto
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkaGFmY2FpZ21kcmN1dGJlamRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMyNTU5NTgsImV4cCI6MjA5ODgzMTk1OH0.buiG3ZlIUUTSRhFVBzwNw5dneYt5uTJlUrSihMd78VA',                   // API Key pública
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => SessionProvider(),
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();

    if (session.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Travel Ecuador'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => context.read<SessionProvider>().logout(),
            ),
          ],
        ),
        body: Center(
          child: Text(
            'Sesión iniciada como ${session.user?.email ?? 'usuario'}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return const LoginScreen();
  }
}


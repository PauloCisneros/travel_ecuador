import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool isLogin = true;
  bool loading = false;
  bool obscurePassword = true;

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() => loading = true);
    final session = context.read<SessionProvider>();

    try {
      if (isLogin) {
        await session.login(emailController.text.trim(), passwordController.text);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login correcto')),
        );
      } else {
        await session.register(emailController.text.trim(), passwordController.text);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro creado y perfil guardado en users. Revisa tu correo si Supabase pidió confirmación.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      // Fondo sutil para dar contraste con la tarjeta
      backgroundColor: colorScheme.surfaceContainerLow,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Un icono o logo que represente el turismo
                Icon(Icons.landscape_rounded, size: 80, color: colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  isLogin ? '¡Bienvenido de vuelta!' : 'Comienza tu aventura',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 32),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => (value == null || !value.contains('@')) ? 'Correo inválido' : null,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: passwordController,
                            obscureText: obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => obscurePassword = !obscurePassword),
                              ),
                            ),
                            validator: (value) => (value?.length ?? 0) < 6 ? 'Mínimo 6 caracteres' : null,
                          ),
                          const SizedBox(height: 32),
                          FilledButton(
                            onPressed: loading ? null : submit,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 54),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: loading 
                                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(isLogin ? 'Iniciar sesión' : 'Registrarse', style: const TextStyle(fontSize: 16)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: loading ? null : () => setState(() => isLogin = !isLogin),
                  child: Text(isLogin ? '¿No tienes cuenta? Regístrate' : '¿Ya tienes cuenta? Inicia sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
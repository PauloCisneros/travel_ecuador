import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../services/snackbar_service.dart';
import '../theme/app_theme.dart';

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

  // ---- Lógica sin cambios ----
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
        SnackBarService.mostrarExito(context, 'Inicio de sesión correcto');
      } else {
        await session.register(emailController.text.trim(), passwordController.text);
        if (!mounted) return;
        SnackBarService.mostrarExito(
          context,
          'Registro creado. Revisa tu correo si es necesario confirmar.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarService.mostrarError(context, e);
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
  // ---- Fin lógica sin cambios ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lienzo,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                Image.asset(
                  'assets/icon/icon.png',
                  width: 72,
                  height: 72,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.image_not_supported, size: 72);
                  },
                ),
                const SizedBox(height: 28),
                Text(
                  isLogin ? 'Bienvenido de vuelta' : 'Crea tu cuenta',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  isLogin
                      ? 'Ingresa para seguir explorando Ecuador'
                      : 'Guarda tus destinos favoritos y califica tus visitas',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.musgo,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 40),

                // Formulario sin Card: minimalista, plano, con inputs de línea inferior
                Form(
                  key: formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: AppColors.tinta),
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: (value) =>
                            (value == null || !value.contains('@')) ? 'Correo inválido' : null,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        style: const TextStyle(color: AppColors.tinta),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                            onPressed: () => setState(() => obscurePassword = !obscurePassword),
                          ),
                        ),
                        validator: (value) =>
                            (value?.length ?? 0) < 6 ? 'Mínimo 6 caracteres' : null,
                      ),
                      const SizedBox(height: 36),
                      FilledButton(
                        onPressed: loading ? null : submit,
                        child: loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.4,
                                ),
                              )
                            : Text(isLogin ? 'Iniciar sesión' : 'Registrarse'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                TextButton(
                  onPressed: loading ? null : () => setState(() => isLogin = !isLogin),
                  child: Text(
                    isLogin ? '¿No tienes cuenta? Regístrate' : '¿Ya tienes cuenta? Inicia sesión',
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
import 'package:flutter/material.dart';
import 'main.dart';
import 'theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Controla la secuencia de entrada (ícono → glow → título → indicador).
  late final AnimationController _entrada;
  // Loop independiente y continuo para el indicador de carga (puntos).
  late final AnimationController _pulso;

  late final Animation<double> _iconoEscala;
  late final Animation<double> _iconoOpacidad;
  late final Animation<double> _resplandorOpacidad;
  late final Animation<double> _tituloOpacidad;
  late final Animation<Offset> _tituloDesplazamiento;
  late final Animation<double> _indicadorOpacidad;

  @override
  void initState() {
    super.initState();

    _entrada = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _pulso = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    )..repeat();

    // El ícono entra con un leve "overshoot" (easeOutBack) — se siente
    // más vivo que un fade plano, sin caer en algo juguetón de más.
    _iconoEscala = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrada,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );
    _iconoOpacidad = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrada,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    // Resplandor cálido detrás del ícono — referencia sutil al concepto
    // de marca ("el sol sobre la línea ecuatorial") sin ser literal.
    _resplandorOpacidad = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrada,
        curve: const Interval(0.05, 0.6, curve: Curves.easeOut),
      ),
    );

    _tituloOpacidad = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrada,
        curve: const Interval(0.45, 0.75, curve: Curves.easeOut),
      ),
    );
    _tituloDesplazamiento = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entrada,
        curve: const Interval(0.45, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _indicadorOpacidad = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrada,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );

    _entrada.forward();

    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthGate()),
        );
      }
    });
  }

  @override
  void dispose() {
    _entrada.dispose();
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lienzo,
      body: Center(
        child: AnimatedBuilder(
          animation: _entrada,
          builder: (context, _) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícono + resplandor
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: _resplandorOpacidad.value,
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.solClaro.withValues(alpha: 0.9),
                                AppColors.solClaro.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      FadeTransition(
                        opacity: _iconoOpacidad,
                        child: ScaleTransition(
                          scale: _iconoEscala,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: Image.asset(
                              'assets/icon/icon.png',
                              width: 132,
                              height: 132,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 132,
                                  height: 132,
                                  decoration: BoxDecoration(
                                    color: AppColors.solClaro,
                                    borderRadius: BorderRadius.circular(32),
                                  ),
                                  child: const Icon(
                                    Icons.travel_explore_rounded,
                                    size: 56,
                                    color: AppColors.sol,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Título
                SlideTransition(
                  position: _tituloDesplazamiento,
                  child: FadeTransition(
                    opacity: _tituloOpacidad,
                    child: const Text(
                      'Bienvenido',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: AppColors.tinta,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SlideTransition(
                  position: _tituloDesplazamiento,
                  child: FadeTransition(
                    opacity: _tituloOpacidad,
                    child: const Text(
                      'Descubre Ecuador',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.musgo,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Indicador de carga — puntos pulsando en el naranja de
                // marca, en vez del spinner circular genérico de Material.
                FadeTransition(
                  opacity: _indicadorOpacidad,
                  child: AnimatedBuilder(
                    animation: _pulso,
                    builder: (context, _) => _PuntosDeCarga(progreso: _pulso.value),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Tres puntos que pulsan en cascada — indicador de carga minimalista
/// y en el color de marca, reemplaza el `CircularProgressIndicator` por
/// defecto de Material.
class _PuntosDeCarga extends StatelessWidget {
  final double progreso; // 0.0 – 1.0, loop continuo

  const _PuntosDeCarga({required this.progreso});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        // Cada punto tiene una fase distinta dentro del mismo ciclo,
        // así se ve una ola en vez de tres puntos parpadeando a la vez.
        final fase = (progreso + (index * 0.2)) % 1.0;
        final intensidad = (0.35 + 0.65 * (0.5 - (fase - 0.5).abs()) * 2)
            .clamp(0.35, 1.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Opacity(
            opacity: intensidad,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.sol,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}
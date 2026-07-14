import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/session_provider.dart';
import '../providers/favorito_provider.dart';
import '../models/destino_model.dart';
import '../widgets/destino_card_editable.dart';
import '../screens/add_destino_screen.dart';
import '../screens/destino_detail_screen.dart';
import '../services/visita_service.dart';
import '../services/storage_service.dart';
import '../services/snackbar_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isEditing = false;
  final TextEditingController nombreController = TextEditingController();
  List<Destino> _misDestinos = [];
  bool _cargandoDestinos = false;
  Map<String, int> _resumenResenas = {};
  bool _cargandoAvatar = false;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionProvider>();
    if (session.user != null) {
      nombreController.text = session.user!.nombre;
    }
    _cargarMisDestinos();
  }

  @override
  void dispose() {
    nombreController.dispose();
    super.dispose();
  }

  Future<void> _cargarMisDestinos() async {
    setState(() => _cargandoDestinos = true);

    try {
      final session = context.read<SessionProvider>();
      final supabase = Supabase.instance.client;

      if (session.user == null) return;

      final response = await supabase
          .from('destinos')
          .select()
          .eq('uid', session.user!.uid)
          .order('created_at', ascending: false);

      List<Destino> destinos =
          response.map((map) => Destino.fromMap(map)).toList();

      final visitaService = VisitaService();
      if (destinos.isNotEmpty) {
        final destinoIds = destinos.map((d) => d.id).toList();
        _resumenResenas =
            await visitaService.getResumenCalificacionesForDestinos(destinoIds);
      } else {
        _resumenResenas = {
          'positivas': 0,
          'neutras': 0,
          'negativas': 0,
          'total': 0,
        };
      }

      setState(() {
        _misDestinos = destinos;
      });
    } catch (e) {
      if (mounted) SnackBarService.mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _cargandoDestinos = false);
    }
  }

  Future<void> _eliminarDestino(String destinoId) async {
    try {
      final supabase = Supabase.instance.client;
      final session = context.read<SessionProvider>();

      await supabase
          .from('destinos')
          .delete()
          .eq('id', destinoId)
          .eq('uid', session.user!.uid);

      setState(() {
        _misDestinos.removeWhere((d) => d.id == destinoId);
      });

      if (mounted) SnackBarService.mostrarExito(context, 'Destino eliminado');
    } catch (e) {
      if (mounted) SnackBarService.mostrarError(context, e);
    }
  }

  void _mostrarOpcionesFoto() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.lienzo,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.niebla,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Cambiar foto de perfil',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              _FotoOptionTile(
                icon: Icons.camera_alt_rounded,
                title: 'Cámara',
                onTap: () {
                  Navigator.pop(context);
                  _subirAvatar(ImageSource.camera);
                },
              ),
              _FotoOptionTile(
                icon: Icons.photo_library_rounded,
                title: 'Galería',
                onTap: () {
                  Navigator.pop(context);
                  _subirAvatar(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _subirAvatar(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (pickedFile == null) return;
    if (!mounted) return;

    setState(() => _cargandoAvatar = true);

    try {
      final storageService = StorageService();
      final session = context.read<SessionProvider>();
      final uid = session.user!.uid;

      String avatarUrl;
      try {
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          avatarUrl = await storageService.uploadAvatarWeb(bytes, uid);
        } else {
          avatarUrl =
              await storageService.uploadAvatar(File(pickedFile.path), uid);
        }
      } catch (e) {
        throw Exception('(upload) $e');
      }

      try {
        await session.updateAvatar(avatarUrl);
      } catch (e) {
        throw Exception('(db) $e');
      }

      if (!mounted) return;
      SnackBarService.mostrarExito(context, 'Foto de perfil actualizada');
    } catch (e) {
      if (!mounted) return;
      SnackBarService.mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _cargandoAvatar = false);
    }
  }

  Future<void> _confirmarLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          '¿Estás seguro de que quieres cerrar sesión?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.musgo,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      final favoritoProvider = context.read<FavoritoProvider>();
      final sessionProvider = context.read<SessionProvider>();
      favoritoProvider.clearFavoritos();
      await sessionProvider.logout();
    }
  }

  Destino? _mejorValorado() {
    final conResenas = _misDestinos
        .where((d) => (d.totalCalificaciones ?? 0) > 0)
        .toList();
    if (conResenas.isEmpty) return null;
    conResenas.sort((a, b) =>
        (b.promedioCalificacion ?? 0).compareTo(a.promedioCalificacion ?? 0));
    return conResenas.first;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final user = session.user;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final total = _resumenResenas['total'] ?? 0;
    final positivas = _resumenResenas['positivas'] ?? 0;
    final neutras = _resumenResenas['neutras'] ?? 0;
    final negativas = _resumenResenas['negativas'] ?? 0;
    final mejorDestino = _mejorValorado();
    final esExplorador = _misDestinos.length >= 3;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ========== HEADER ==========
          Center(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: AppColors.solClaro,
                      backgroundImage: user.avatarUrl != null
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                      child: user.avatarUrl == null
                          ? Text(
                              user.nombre.isNotEmpty
                                  ? user.nombre[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 36,
                                color: AppColors.sol,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    if (_cargandoAvatar)
                      const SizedBox(
                        width: 108,
                        height: 108,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.sol,
                        ),
                      ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        elevation: 2,
                        shadowColor: Colors.black26,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _mostrarOpcionesFoto,
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: AppColors.sol,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.nombre,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.tinta,
                      ),
                    ),
                    if (!isEditing) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          setState(() {
                            isEditing = true;
                            nombreController.text = user.nombre;
                          });
                        },
                        borderRadius: BorderRadius.circular(99),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.edit_rounded,
                            size: 18,
                            color: AppColors.musgoClaro,
                          ),
                        ),
                      ),
                    ],
                    if (esExplorador) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.solClaro,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Explorador',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.sol,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.musgo,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lienzoAlterno,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'ID: ${user.uid.substring(0, 8)}...',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.musgo,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (isEditing) ...[
                  TextField(
                    controller: nombreController,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            if (nombreController.text.trim().isNotEmpty) {
                              try {
                                await session.updateProfile(
                                  nombreController.text.trim(),
                                );
                                if (!context.mounted) return;
                                setState(() => isEditing = false);
                                SnackBarService.mostrarExito(
                                  context,
                                  'Nombre actualizado',
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                SnackBarService.mostrarError(context, e);
                              }
                            }
                          },
                          child: const Text('Guardar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              isEditing = false;
                              nombreController.text = user.nombre;
                            });
                          },
                          child: const Text('Cancelar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ========== DASHBOARD ==========
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.niebla),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tinta,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.place_rounded,
                      label: '${_misDestinos.length} destinos',
                    ),
                    const SizedBox(width: 12),
                    _StatChip(
                      icon: Icons.star_rounded,
                      label: '$total reseñas',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (total > 0) ...[
                  Row(
                    children: [
                      SizedBox(
                        width: 130,
                        height: 130,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(130, 130),
                              painter: _DonutChartPainter(
                                positivas: positivas,
                                neutras: neutras,
                                negativas: negativas,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$total',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.tinta,
                                  ),
                                ),
                                const Text(
                                  'reseñas',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.musgo,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _LegendItem(
                              color: AppColors.exito,
                              label: 'Positivas',
                              value: positivas,
                              total: total,
                            ),
                            const SizedBox(height: 6),
                            _LegendItem(
                              color: AppColors.musgoClaro,
                              label: 'Neutras',
                              value: neutras,
                              total: total,
                            ),
                            const SizedBox(height: 6),
                            _LegendItem(
                              color: AppColors.error,
                              label: 'Negativas',
                              value: negativas,
                              total: total,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (mejorDestino != null)
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DestinoDetailScreen(
                              destino: mejorDestino,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.emoji_events_rounded,
                              color: AppColors.sol,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Mejor valorado: ${mejorDestino.nombre} '
                                '(${(mejorDestino.promedioCalificacion ?? 0).toStringAsFixed(1)}★)',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.tinta,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.musgoClaro,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                ] else ...[
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.solClaro,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.bar_chart_rounded,
                            color: AppColors.sol,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Aún no tienes reseñas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.tinta,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Las estadísticas aparecerán cuando\ntus destinos reciban reseñas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.musgo,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ========== MIS DESTINOS ==========
          Row(
            children: [
              const Text(
                'Mis destinos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.tinta,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle_rounded),
                color: AppColors.sol,
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddDestinoScreen(),
                    ),
                  );
                  if (result == true) {
                    _cargarMisDestinos();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                color: AppColors.musgo,
                onPressed: _cargarMisDestinos,
              ),
            ],
          ),

          const SizedBox(height: 4),

          if (_cargandoDestinos)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_misDestinos.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.niebla),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.solClaro,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.travel_explore_rounded,
                      color: AppColors.sol,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No has agregado destinos aún',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.tinta,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Usa el botón + para crear tu primer destino.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.musgo,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _misDestinos.length,
              itemBuilder: (context, index) {
                final destino = _misDestinos[index];
                return DestinoCardEditable(
                  destino: destino,
                  onDelete: () => _eliminarDestino(destino.id),
                  onUpdate: _cargarMisDestinos,
                );
              },
            ),

          const SizedBox(height: 40),
        ],
      ),
    ),
    Positioned(
      top: 90,
      right: 8,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _confirmarLogout,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: const Icon(
              Icons.logout_rounded,
              color: AppColors.musgo,
              size: 22,
            ),
          ),
        ),
      ),
    ),
  ],
);
  }
}

// ====================================================================
//  HELPER WIDGETS
// ====================================================================

class _DonutChartPainter extends CustomPainter {
  final int positivas, neutras, negativas;

  _DonutChartPainter({
    required this.positivas,
    required this.neutras,
    required this.negativas,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = positivas + neutras + negativas;
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 18.0;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    double startAngle = -3.14159 / 2;

    void drawSegment(int value, Color color) {
      if (value == 0) return;
      final sweep = 2 * 3.14159 * (value / total);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }

    drawSegment(positivas, AppColors.exito);
    drawSegment(neutras, AppColors.musgoClaro);
    drawSegment(negativas, AppColors.error);
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.positivas != positivas ||
        oldDelegate.neutras != neutras ||
        oldDelegate.negativas != negativas;
  }
}

class _FotoOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _FotoOptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.solClaro,
        child: Icon(icon, color: AppColors.sol, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.musgoClaro,
      ),
      onTap: onTap,
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.lienzoAlterno,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.musgo),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.tinta,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  final int total;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final percent = total > 0 ? (value / total * 100).round() : 0;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.musgo,
          ),
        ),
        const Spacer(),
        Text(
          '$percent%',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.tinta,
          ),
        ),
      ],
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/session_provider.dart';
import '../providers/favorito_provider.dart';
import '../providers/destino_update_notifier.dart';
import '../models/destino_model.dart';
import '../widgets/destino_card_editable.dart';
import '../screens/add_destino_screen.dart';
import '../screens/destino_detail_screen.dart';
import '../services/visita_service.dart';
import '../services/storage_service.dart';
import '../services/snackbar_service.dart';
import '../utils/dashboard_cache.dart';
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
  bool _cargandoAvatar = false;
  DateTime? _ultimaCarga;

  // Dashboard states
  DashboardStats? _dashboardStats;
  bool _cargandoEstadisticas = false;
  bool _statsError = false;
  String? _categoriaFiltroLocal;
  String? _provinciaFiltroLocal;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionProvider>();
    if (session.user != null) {
      nombreController.text = session.user!.nombre;
      _cargarEstadisticas();
      _cargarMisDestinos();
    }
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

      setState(() {
        _misDestinos = destinos;
      });
    } catch (e) {
      if (mounted) SnackBarService.mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _cargandoDestinos = false);
    }
  }

  Future<void> _cargarEstadisticas({bool forceRefresh = false}) async {
    final session = context.read<SessionProvider>();
    if (session.user == null) return;

    if (!forceRefresh) {
      final cached = await DashboardCache.get(session.user!.uid);
      if (cached != null && mounted) {
        setState(() => _dashboardStats = cached);
      }
    }

    setState(() => _cargandoEstadisticas = true);

    try {
      final visitaService = VisitaService();
      final stats = await visitaService.getEstadisticasDetalladasParaUsuario(session.user!.uid);
      await DashboardCache.save(session.user!.uid, stats);
      if (mounted) {
        setState(() {
          _dashboardStats = stats;
          _statsError = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _statsError = true);
    } finally {
      if (mounted) setState(() => _cargandoEstadisticas = false);
    }
  }

  Future<void> _refreshDashboard() async {
    final session = context.read<SessionProvider>();
    if (session.user != null) {
      await DashboardCache.invalidate(session.user!.uid);
      await Future.wait([
        _cargarMisDestinos(),
        _cargarEstadisticas(forceRefresh: true),
      ]);
    }
  }

  Future<void> _onDestinoChanged() async {
    final session = context.read<SessionProvider>();
    if (session.user != null) {
      await DashboardCache.invalidate(session.user!.uid);
      await Future.wait([
        _cargarMisDestinos(),
        _cargarEstadisticas(forceRefresh: true),
      ]);
      // Notificar a Home y Favorites para que se refresquen automáticamente
      context.read<DestinoUpdateNotifier>().notify();
      context.read<FavoritoProvider>().refreshDestinosFavoritos(session.user!.uid);
    }
  }

  // ========== DASHBOARD HELPER METHODS ==========

  Widget _buildDashboard() {
    if (_cargandoEstadisticas && _dashboardStats == null) {
      return _buildDashboardSkeleton();
    }

    if (_statsError && _dashboardStats == null) {
      return _DashboardEmptyState(
        type: 'error',
        onRetry: _refreshDashboard,
      );
    }

    if (_dashboardStats == null) {
      return _DashboardEmptyState(
        type: 'zeroDestinos',
        onCrearDestino: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddDestinoScreen()),
        ),
        onExplorar: () => _switchToHomeTab(),
      );
    }

    final stats = _dashboardStats!;
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final maxReviews = isTablet ? 5 : 3;

    if (stats.totalDestinos == 0) {
      return _DashboardEmptyState(
        type: 'zeroDestinos',
        onCrearDestino: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddDestinoScreen()),
        ),
        onExplorar: () => _switchToHomeTab(),
      );
    }

    if (stats.totalResenas == 0) {
      return _DashboardEmptyState(
        type: 'zeroResenas',
        onVerDestinos: _scrollToMisDestinos,
      );
    }

    return Container(
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

          // Stat Cards
          Row(
            children: [
              _MetricCard(
                icon: Icons.place_rounded,
                value: stats.totalDestinos.toString(),
                label: 'Destinos',
                color: AppColors.sol,
              ),
              const SizedBox(width: 12),
              _MetricCard(
                icon: Icons.star_rounded,
                value: stats.totalResenas.toString(),
                label: 'Reseñas',
                color: AppColors.solOscuro,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Promedio Global + Distribución Estrellas
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Promedio Global Card
              Expanded(
                flex: 2,
                child: _PromedioGlobalCard(
                  promedio: stats.promedioGlobal,
                  totalResenas: stats.totalResenas,
                ),
              ),
              const SizedBox(width: 20),
              // Distribución de Estrellas
              Expanded(
                flex: 3,
                child: _StarDistributionBars(
                  distribucion: stats.distribucionEstrellas,
                  total: stats.totalResenas,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Top Categorías
          if (stats.topCategorias.isNotEmpty) ...[
            _TopCategoryChips(
              title: 'Categorías',
              icon: Icons.category_outlined,
              items: stats.topCategorias,
              onTap: _filtrarCategoria,
            ),
            const SizedBox(height: 12),
          ],

          // Top Provincias
          if (stats.topProvincias.isNotEmpty) ...[
            _TopCategoryChips(
              title: 'Provincias',
              icon: Icons.location_city_outlined,
              items: stats.topProvincias,
              onTap: _filtrarProvincia,
            ),
            const SizedBox(height: 16),
          ],

          // Reseñas Recientes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Reseñas recientes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.tinta,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...stats.resenasRecientes.take(maxReviews).map((r) => _RecentReviewTile(
                review: r,
                onTap: () => _navigateToDestinoDetail(r['destinoId'] as String),
              )),
        ],
      ),
    );
  }

  void _filtrarCategoria(String categoria) {
    setState(() {
      _categoriaFiltroLocal = _categoriaFiltroLocal == categoria ? null : categoria;
    });
  }

  void _filtrarProvincia(String provincia) {
    setState(() {
      _provinciaFiltroLocal = _provinciaFiltroLocal == provincia ? null : provincia;
    });
  }

  void _scrollToMisDestinos() {
    // The list is in the same scroll view, so it will be visible
  }

  void _switchToHomeTab() {
    SnackBarService.mostrarAdvertencia(context, 'Usa la navegación inferior para ir a Inicio');
  }

  Future<void> _navigateToDestinoDetail(String destinoId) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('destinos')
          .select()
          .eq('id', destinoId)
          .maybeSingle();

      if (response == null) {
        if (!mounted) return;
        SnackBarService.mostrarError(context, 'Destino no encontrado');
        return;
      }

      // Fetch creator name
      final creatorUid = response['uid'] as String;
      String creatorName = 'Usuario';
      final userResponse = await supabase
          .from('users')
          .select('nombre')
          .eq('uid', creatorUid)
          .maybeSingle();
      if (userResponse != null) {
        creatorName = userResponse['nombre'] ?? 'Usuario';
      }

      final destinoMap = Map<String, dynamic>.from(response);
      destinoMap['nombre_creador'] = creatorName;

      final destino = Destino.fromMap(destinoMap);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DestinoDetailScreen(destino: destino),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarService.mostrarError(context, e);
    }
  }

  Widget _buildMisDestinosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  await _onDestinoChanged();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              color: AppColors.musgo,
              onPressed: _refreshDashboard,
            ),
          ],
        ),

        // Removido SizedBox(height: 4) para reducir separación

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
                onUpdate: _onDestinoChanged,
                onGlobalUpdate: _onDestinoChanged,
              );
            },
          ),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildDashboardSkeleton() {
    return Container(
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
          _SkeletonLine(width: 100, height: 24),
          const SizedBox(height: 16),
          Row(
            children: [
              _SkeletonCard(),
              const SizedBox(width: 12),
              _SkeletonCard(),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _SkeletonBox(width: 140, height: 130)),
              const SizedBox(width: 20),
              Expanded(flex: 3, child: _SkeletonBox(width: 200, height: 130)),
            ],
          ),
          const SizedBox(height: 16),
          _SkeletonLine(width: double.infinity, height: 40),
          const SizedBox(height: 12),
          _SkeletonLine(width: double.infinity, height: 40),
          const SizedBox(height: 16),
          _SkeletonLine(width: 120, height: 20),
          const SizedBox(height: 8),
          ...List.generate(3, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SkeletonLine(width: double.infinity, height: 56),
          )),
        ],
      ),
    );
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
      await _onDestinoChanged();
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

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final user = session.user;

    final ahora = DateTime.now();
    if (user != null &&
        (_ultimaCarga == null ||
            ahora.difference(_ultimaCarga!) > const Duration(seconds: 3))) {
      _ultimaCarga = ahora;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_cargandoDestinos) _cargarMisDestinos();
      });
    }

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final esExplorador = _misDestinos.length >= 3;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _refreshDashboard,
          color: AppColors.sol,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                    // Botón cerrar sesión en la esquina superior derecha del avatar
                    Positioned(
                      top: 2,
                      right: 2,
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
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.logout_rounded,
                              color: AppColors.musgo,
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
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _confirmarLogout,
                        borderRadius: BorderRadius.circular(99),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.logout_rounded,
                            size: 20,
                            color: AppColors.musgo,
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

          const SizedBox(height: 8),

          // ========== DASHBOARD + MIS DESTINOS (single scroll with pull-to-refresh) ==========
          _buildDashboard(),
          const SizedBox(height: 8),
          _buildMisDestinosSection(),

          const SizedBox(height: 40),
        ],
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

/// Metric card for dashboard
class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.niebla),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.tinta,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.musgo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Promedio global card
class _PromedioGlobalCard extends StatelessWidget {
  final double promedio;
  final int totalResenas;

  const _PromedioGlobalCard({
    required this.promedio,
    required this.totalResenas,
  });

  Color _getColor() {
    if (promedio >= 4.0) return AppColors.exito;
    if (promedio >= 3.0) return AppColors.sol;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Promedio',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            promedio.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text(
                '$totalResenas reseñas',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.musgo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Star distribution bars
class _StarDistributionBars extends StatelessWidget {
  final Map<int, int> distribucion;
  final int total;

  const _StarDistributionBars({
    required this.distribucion,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final starColors = {
      5: AppColors.exito,
      4: AppColors.sol,
      3: AppColors.musgoClaro,
      2: AppColors.error,
      1: AppColors.error.withValues(alpha: 0.6),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final star = 5 - index;
        final count = distribucion[star] ?? 0;
        final percent = total > 0 ? count / total : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '$star★',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.musgo,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.niebla,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percent,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: starColors[star] ?? AppColors.musgo,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 30,
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.tinta,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Top category/province chips
class _TopCategoryChips extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> items;
  final Function(String) onTap;

  const _TopCategoryChips({
    required this.title,
    required this.icon,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.musgo),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.musgo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: items.map((item) {
              final nombre = item['nombre'] as String;
              final count = item['count'] as int;
              final selected = false; // We don't persist selection in chips

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(nombre),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.solClaro,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.sol,
                          ),
                        ),
                      ),
                    ],
                  ),
                  selected: selected,
                  onSelected: (_) => onTap(nombre),
                  backgroundColor: Colors.white,
                  selectedColor: AppColors.solClaro,
                  checkmarkColor: AppColors.sol,
                  side: BorderSide(color: AppColors.niebla),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  labelStyle: const TextStyle(fontSize: 12, color: AppColors.tinta),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Recent review tile
class _RecentReviewTile extends StatelessWidget {
  final Map<String, dynamic> review;
  final VoidCallback onTap;

  const _RecentReviewTile({
    required this.review,
    required this.onTap,
  });

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 0) {
        return 'Hace ${diff.inDays} día${diff.inDays > 1 ? 's' : ''}';
      } else if (diff.inHours > 0) {
        return 'Hace ${diff.inHours} hora${diff.inHours > 1 ? 's' : ''}';
      } else if (diff.inMinutes > 0) {
        return 'Hace ${diff.inMinutes} minuto${diff.inMinutes > 1 ? 's' : ''}';
      } else {
        return 'Hace un momento';
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final calificacion = review['calificacion'] as int? ?? 0;
    final comentario = review['comentario'] as String?;
    final nombreUsuario = review['nombreUsuario'] as String? ?? 'Usuario';
    final destinoNombre = review['destinoNombre'] as String? ?? 'Destino';
    final createdAt = review['createdAt'] as String? ?? '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.niebla),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.solClaro,
              child: Text(
                nombreUsuario.isNotEmpty ? nombreUsuario[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.solOscuro,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        nombreUsuario,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AppColors.tinta,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...List.generate(5, (i) => Icon(
                        i < calificacion ? Icons.star_rounded : Icons.star_border_rounded,
                        color: Colors.amber,
                        size: 13,
                      )),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    destinoNombre,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.musgo,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (comentario != null && comentario.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      comentario,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.musgo,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(createdAt),
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.musgoClaro,
                    ),
                  ),
                ],
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
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double width;
  final double height;

  const _SkeletonLine({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.niebla,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.niebla),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.niebla,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 8),
            _SkeletonLine(width: 60, height: 28),
            _SkeletonLine(width: 80, height: 12),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;

  const _SkeletonBox({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.niebla,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

/// Empty state for dashboard
class _DashboardEmptyState extends StatelessWidget {
  final String type; // 'zeroDestinos', 'zeroResenas', 'error'
  final VoidCallback? onRetry;
  final VoidCallback? onCrearDestino;
  final VoidCallback? onExplorar;
  final VoidCallback? onVerDestinos;

  const _DashboardEmptyState({
    required this.type,
    this.onRetry,
    this.onCrearDestino,
    this.onExplorar,
    this.onVerDestinos,
  });

  @override
  Widget build(BuildContext context) {
    String title;
    String subtitle;
    IconData icon;
    Color iconColor;
    List<Widget> actions = [];

    switch (type) {
      case 'zeroDestinos':
        title = 'Tu aventura empieza aquí';
        subtitle = 'Aún no has creado ningún destino.\nComparte tus lugares favoritos de Ecuador.';
        icon = Icons.travel_explore_rounded;
        iconColor = AppColors.sol;
        actions = [
          _EmptyAction(
            label: 'Crear mi primer destino',
            icon: Icons.add_rounded,
            onTap: onCrearDestino ?? () {},
            isPrimary: true,
          ),
          _EmptyAction(
            label: 'Explorar destinos',
            icon: Icons.explore_rounded,
            onTap: onExplorar ?? () {},
            isPrimary: false,
          ),
        ];
        break;
      case 'zeroResenas':
        title = 'Sin reseñas aún';
        subtitle = 'Tus destinos están esperando opiniones.\nCuando alguien los visite, aparecerán aquí.';
        icon = Icons.star_border_rounded;
        iconColor = AppColors.sol;
        actions = [
          _EmptyAction(
            label: 'Ver mis destinos',
            icon: Icons.place_rounded,
            onTap: onVerDestinos ?? () {},
            isPrimary: true,
          ),
        ];
        break;
      case 'error':
      default:
        title = 'No se pudo cargar';
        subtitle = 'Ocurrió un error al cargar el dashboard.\nIntenta de nuevo.';
        icon = Icons.error_outline_rounded;
        iconColor = AppColors.error;
        actions = [
          _EmptyAction(
            label: 'Reintentar',
            icon: Icons.refresh_rounded,
            onTap: onRetry ?? () {},
            isPrimary: true,
          ),
        ];
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.niebla),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.tinta,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.musgo,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ...actions,
        ],
      ),
    );
  }
}

class _EmptyAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  const _EmptyAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: isPrimary
            ? FilledButton.icon(
                onPressed: onTap,
                icon: Icon(icon, size: 18),
                label: Text(label),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.sol,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
            : OutlinedButton.icon(
                onPressed: onTap,
                icon: Icon(icon, size: 18),
                label: Text(label),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.sol,
                  side: const BorderSide(color: AppColors.sol),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
      ),
    );
  }
}

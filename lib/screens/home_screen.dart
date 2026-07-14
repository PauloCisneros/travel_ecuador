import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import '../models/destino_model.dart';
import '../models/sitio_osm.dart';
import '../models/categorias_destino.dart';
import '../models/provincias_ec.dart';
import '../providers/session_provider.dart';
import '../providers/favorito_provider.dart';

import '../widgets/destino_card.dart';
import '../widgets/destino_osm_card.dart';
import 'add_destino_screen.dart';
import '../services/snackbar_service.dart';
import '../services/gps_service.dart';
import '../services/overpass_service.dart';
import '../utils/distancia.dart';
import 'chatbot_screen.dart';
import '../theme/app_theme.dart';

// Cuántas opciones se muestran por defecto en cada sección de filtros
// antes de ofrecer "Ver más" (regla de 5-7 elementos).
const int _kFiltrosLimiteVisible = 6;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Destino> _destinos = [];
  bool _isLoading = true;

  static const int _pageSize = 20;
  int _currentPage = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _categoriaFiltro;
  String? _provinciaFiltro;
  int _minRating = 0;

  bool _cercaDeMi = false;
  Position? _userPosicion;
  List<SitioOsm> _sitiosOsm = [];
  bool _cargandoOsm = false;
  bool _osmError = false;
  DateTime? _ultimaActivacion;
  DateTime? _ultimaCargaOsm;
  final Map<String, double> _distancias = {};

  String _sinAcentos(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll('ç', 'c');

  List<Destino> get _destinosFiltrados {
    var result = _destinos.where((d) {
      final q = _sinAcentos(_searchQuery);
      return (q.isEmpty || _sinAcentos(d.nombre).contains(q)) &&
          (_categoriaFiltro == null || d.categoria == _categoriaFiltro) &&
          (_provinciaFiltro == null || d.provincia == _provinciaFiltro) &&
          (_minRating == 0 || (d.promedioCalificacion ?? 0) >= _minRating);
    }).toList();

    if (_cercaDeMi && _userPosicion != null) {
      _distancias.clear();
      for (final d in result) {
        _distancias[d.id] = calcularDistanciaKm(
          _userPosicion!.latitude,
          _userPosicion!.longitude,
          d.latitud,
          d.longitud,
        );
      }
      result.sort((a, b) => _distancias[a.id]!.compareTo(_distancias[b.id]!));
    }

    return result;
  }

  @override
  void initState() {
    super.initState();
    _cargarDestinos();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _cargarMasDestinos();
    }
  }

  Future<void> _cargarDestinos() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _hasMore = true;
    });

    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('destinos')
          .select('*')
          .order('created_at', ascending: false)
          .limit(_pageSize)
          .range(0, _pageSize - 1);

      final uids = response.map((map) => map['uid'] as String).toSet().toList();

      Map<String, String> nombresUsuarios = {};
      if (uids.isNotEmpty) {
        final usersResponse = await supabase
            .from('users')
            .select('uid, nombre')
            .inFilter('uid', uids);

        for (var user in usersResponse) {
          nombresUsuarios[user['uid']] = user['nombre'] ?? 'Usuario';
        }
      }

      _destinos = response.map((map) {
        final destinoMap = Map<String, dynamic>.from(map);
        final uid = map['uid'] as String;
        destinoMap['nombre_creador'] = nombresUsuarios[uid] ?? 'Usuario';
        return Destino.fromMap(destinoMap);
      }).toList();

      _hasMore = response.length == _pageSize;
    } catch (e) {
      if (mounted) {
        SnackBarService.mostrarError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarMasDestinos() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final supabase = Supabase.instance.client;
      final from = (_currentPage + 1) * _pageSize;
      final to = from + _pageSize - 1;

      final response = await supabase
          .from('destinos')
          .select('*')
          .order('created_at', ascending: false)
          .limit(_pageSize)
          .range(from, to);

      if (response.isNotEmpty) {
        final uids = response.map((map) => map['uid'] as String).toSet().toList();

        Map<String, String> nombresUsuarios = {};
        if (uids.isNotEmpty) {
          final usersResponse = await supabase
              .from('users')
              .select('uid, nombre')
              .inFilter('uid', uids);

          for (var user in usersResponse) {
            nombresUsuarios[user['uid']] = user['nombre'] ?? 'Usuario';
          }
        }

        final nuevosDestinos = response.map((map) {
          final destinoMap = Map<String, dynamic>.from(map);
          final uid = map['uid'] as String;
          destinoMap['nombre_creador'] = nombresUsuarios[uid] ?? 'Usuario';
          return Destino.fromMap(destinoMap);
        }).toList();

        _destinos.addAll(nuevosDestinos);
        _currentPage++;
        _hasMore = response.length == _pageSize;
      } else {
        _hasMore = false;
      }
    } catch (e) {
      if (mounted) {
        SnackBarService.mostrarError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.musgo),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      context.read<FavoritoProvider>().clearFavoritos();
      await context.read<SessionProvider>().logout();
    }
  }

  Future<void> _navegarAgregar() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddDestinoScreen()),
    );

    if (result == true) {
      _cargarDestinos();
    }
  }

  void _abrirChatbot() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatbotScreen()),
    );
  }

  Future<void> _toggleCercaDeMi() async {
    if (_cercaDeMi) {
      if (_ultimaActivacion != null &&
          DateTime.now().difference(_ultimaActivacion!).inSeconds < 2) {
        return;
      }
      setState(() {
        _cercaDeMi = false;
        _userPosicion = null;
        _distancias.clear();
      });
      return;
    }

    final gps = GpsService();
    try {
      final pos = await gps.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _userPosicion = pos;
        _cercaDeMi = true;
        _ultimaActivacion = DateTime.now();
      });
      _cargarSitiosOsm(pos.latitude, pos.longitude);
    } catch (e) {
      if (!mounted) return;
      SnackBarService.mostrarError(context, e);
    }
  }

  Future<void> _cargarSitiosOsm(double lat, double lng) async {
    if (_ultimaCargaOsm != null &&
        DateTime.now().difference(_ultimaCargaOsm!).inSeconds < 10) {
      return;
    }
    _ultimaCargaOsm = DateTime.now();

    setState(() {
      _cargandoOsm = true;
      _osmError = false;
    });
    try {
      final overpass = OverpassService();
      final sitios = await overpass.buscarSitiosCercanos(lat, lng);
      if (!mounted) return;
      setState(() => _sitiosOsm = sitios);
    } catch (_) {
      if (!mounted) return;
      setState(() => _osmError = true);
    } finally {
      if (mounted) setState(() => _cargandoOsm = false);
    }
  }
  // ---- Fin lógica sin cambios ----

  int get _filtrosActivos =>
      (_categoriaFiltro != null ? 1 : 0) +
      (_provinciaFiltro != null ? 1 : 0) +
      (_minRating > 0 ? 1 : 0);

  void _abrirBottomSheetFiltros() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.lienzo,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _FiltrosBottomSheet(
        categoriaInicial: _categoriaFiltro,
        provinciaInicial: _provinciaFiltro,
        ratingInicial: _minRating,
        destinos: _destinos,
        searchQuery: _searchQuery,
        onAplicarFiltros: (categoria, provincia, rating) {
          setState(() {
            _categoriaFiltro = categoria;
            _provinciaFiltro = provincia;
            _minRating = rating;
          });
        },
      ),
    );
  }

  Widget _buildSeccionOsm() {
    final tieneCache = _sitiosOsm.isNotEmpty;

    if (_cargandoOsm && !tieneCache) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sol),
            ),
            SizedBox(width: 8),
            Text(
              'Buscando lugares cercanos...',
              style: TextStyle(fontSize: 12, color: AppColors.musgo),
            ),
          ],
        ),
      );
    }

    if (!tieneCache) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.musgoClaro),
            const SizedBox(width: 6),
            Text(
              _osmError
                  ? 'No se pudieron cargar lugares cercanos'
                  : 'No se encontraron lugares turísticos cercanos',
              style: const TextStyle(fontSize: 12, color: AppColors.musgo),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.explore_rounded, size: 16, color: AppColors.sol),
                const SizedBox(width: 6),
                Text(
                  'También cerca de ti',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
                ),
                if (_cargandoOsm) ...[
                  const SizedBox(width: 6),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sol),
                  ),
                ],
                const Spacer(),
                Text(
                  '${_sitiosOsm.length} lugares',
                  style: const TextStyle(fontSize: 11, color: AppColors.musgoClaro),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 125,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16),
              itemCount: _sitiosOsm.length,
              separatorBuilder: (_, _) => const SizedBox(width: 0),
              itemBuilder: (context, index) =>
                  DestinoOsmCard(sitio: _sitiosOsm[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.niebla),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: AppColors.solClaro,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.travel_explore_rounded,
                size: 40,
                color: AppColors.sol,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No hay destinos disponibles',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Agrega tu primer lugar para empezar a descubrir Ecuador.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.musgo, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 64, color: AppColors.musgoClaro),
            const SizedBox(height: 16),
            Text('Sin resultados', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Intenta con otro nombre o ajusta los filtros.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.musgo),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriaChip(String label, String? key) {
    final selected = _categoriaFiltro == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.tinta,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        onSelected: (_) {
          setState(() {
            _categoriaFiltro = selected ? null : key;
          });
        },
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _destinosFiltrados;
    final hayFiltrosExtra = _provinciaFiltro != null || _minRating > 0;

    return Scaffold(
      backgroundColor: AppColors.lienzo,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.sol))
          : _destinos.isEmpty
              ? _buildEmptyState()
              : CustomScrollView(
                  slivers: [
                    // Header plano y minimalista — sin degradado, sin decoración
                    SliverAppBar(
                      pinned: true,
                      floating: true,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      backgroundColor: AppColors.lienzo,
                      foregroundColor: AppColors.tinta,
                      title: const Text('Destinos en Ecuador'),
                      actions: [
                        Badge(
                          isLabelVisible: _filtrosActivos > 0,
                          label: Text('$_filtrosActivos'),
                          child: IconButton(
                            icon: const Icon(Icons.tune_rounded),
                            onPressed: _abrirBottomSheetFiltros,
                            tooltip: 'Filtros',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.smart_toy_outlined),
                          onPressed: _abrirChatbot,
                          tooltip: 'EcuGuía',
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.my_location_rounded,
                            color: _cercaDeMi ? AppColors.sol : null,
                          ),
                          onPressed: _toggleCercaDeMi,
                          tooltip: 'Cerca de mí',
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded),
                          onPressed: _logout,
                          tooltip: 'Cerrar sesión',
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),

                    // Barra de búsqueda
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar destino...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () => _searchController.clear(),
                                  )
                                : null,
                            filled: true,
                            fillColor: AppColors.lienzoAlterno,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),

                    // Categorías + acceso rápido a filtros, en una sola fila
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          height: 36,
                          child: Row(
                            children: [
                              Expanded(
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.only(left: 16),
                                  children: [
                                    _buildCategoriaChip('Todas', null),
                                    ...categoriasKeys.map(
                                      (key) => _buildCategoriaChip(
                                        categoriaLabels[key] ?? key,
                                        key,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: GestureDetector(
                                  onTap: _abrirBottomSheetFiltros,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: hayFiltrosExtra
                                          ? AppColors.sol
                                          : AppColors.lienzoAlterno,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: hayFiltrosExtra ? AppColors.sol : AppColors.niebla,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.tune_rounded,
                                          size: 16,
                                          color: hayFiltrosExtra ? Colors.white : AppColors.musgo,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          hayFiltrosExtra ? 'Filtros' : 'Más',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: hayFiltrosExtra ? Colors.white : AppColors.musgo,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Resumen de filtros extra activos (provincia / calificación)
                    if (hayFiltrosExtra)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (_provinciaFiltro != null)
                                Chip(
                                  label: Text(_provinciaFiltro!),
                                  deleteIcon: const Icon(Icons.close_rounded, size: 15),
                                  onDeleted: () => setState(() => _provinciaFiltro = null),
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (_minRating > 0)
                                Chip(
                                  label: Text('★$_minRating y más'),
                                  deleteIcon: const Icon(Icons.close_rounded, size: 15),
                                  onDeleted: () => setState(() => _minRating = 0),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        ),
                      ),

                    // Cerca de mí — lugares de OpenStreetMap
                    if (_cercaDeMi)
                      SliverToBoxAdapter(
                        child: _buildSeccionOsm(),
                      ),

                    // Resultados
                    if (filtrados.isEmpty)
                      SliverFillRemaining(child: _buildEmptySearchState())
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => DestinoCard(
                              destino: filtrados[index],
                              showFavoriteButton: true,
                              distanciaKm: _distancias[filtrados[index].id],
                            ),
                            childCount: filtrados.length,
                          ),
                        ),
                      ),
                    if (_isLoadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.sol,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navegarAgregar,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo lugar'),
      ),
    );
  }
}

/// Bottom sheet de filtros como StatefulWidget independiente para evitar
/// el error "TextEditingController usado después de dispose" que ocurría
/// con DraggableScrollableSheet + whenComplete.
class _FiltrosBottomSheet extends StatefulWidget {
  final String? categoriaInicial;
  final String? provinciaInicial;
  final int ratingInicial;
  final List<Destino> destinos;
  final String searchQuery;
  final void Function(String? categoria, String? provincia, int rating) onAplicarFiltros;

  const _FiltrosBottomSheet({
    required this.categoriaInicial,
    required this.provinciaInicial,
    required this.ratingInicial,
    required this.destinos,
    required this.searchQuery,
    required this.onAplicarFiltros,
  });

  @override
  State<_FiltrosBottomSheet> createState() => _FiltrosBottomSheetState();
}

class _FiltrosBottomSheetState extends State<_FiltrosBottomSheet> {
  late String? _tempCategoria;
  late String? _tempProvincia;
  late int _tempRating;
  bool _showAllCategorias = false;
  bool _showAllProvincias = false;
  String _provinciaQuery = '';
  late final TextEditingController _provinciaSearchCtrl;

  String _sinAcentos(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll('ç', 'c');

  int _contarConFiltros(String? categoria, String? provincia, int minRating) {
    return widget.destinos.where((d) {
      final q = _sinAcentos(widget.searchQuery);
      return (q.isEmpty || _sinAcentos(d.nombre).contains(q)) &&
          (categoria == null || d.categoria == categoria) &&
          (provincia == null || d.provincia == provincia) &&
          (minRating == 0 || (d.promedioCalificacion ?? 0) >= minRating);
    }).length;
  }

  @override
  void initState() {
    super.initState();
    _tempCategoria = widget.categoriaInicial;
    _tempProvincia = widget.provinciaInicial;
    _tempRating = widget.ratingInicial;
    _provinciaSearchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _provinciaSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriasVisibles = _showAllCategorias
        ? categoriasKeys
        : categoriasKeys.take(_kFiltrosLimiteVisible).toList();

    final provinciasFiltradas = _provinciaQuery.isEmpty
        ? provinciasEcuador
        : provinciasEcuador
            .where((p) => p.toLowerCase().contains(_provinciaQuery.toLowerCase()))
            .toList();

    final provinciasVisibles = (_provinciaQuery.isNotEmpty || _showAllProvincias)
        ? provinciasFiltradas
        : provinciasFiltradas.take(_kFiltrosLimiteVisible).toList();

    final resultados = _contarConFiltros(_tempCategoria, _tempProvincia, _tempRating);

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.niebla,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Text('Filtros', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _tempCategoria = null;
                        _tempProvincia = null;
                        _tempRating = 0;
                        _provinciaQuery = '';
                        _provinciaSearchCtrl.clear();
                        _showAllCategorias = false;
                        _showAllProvincias = false;
                      });
                    },
                    child: const Text('Limpiar todo'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                children: [
                  Text(
                    'Categoría',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  ...categoriasVisibles.map(
                    (key) => _FiltroCheckboxTile(
                      label: categoriaLabels[key] ?? key,
                      selected: _tempCategoria == key,
                      onTap: () => setState(() {
                        _tempCategoria = _tempCategoria == key ? null : key;
                      }),
                    ),
                  ),
                  if (categoriasKeys.length > _kFiltrosLimiteVisible)
                    _VerMasButton(
                      expandido: _showAllCategorias,
                      restantes: categoriasKeys.length - _kFiltrosLimiteVisible,
                      onTap: () => setState(() => _showAllCategorias = !_showAllCategorias),
                    ),

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  Text(
                    'Provincia',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _provinciaSearchCtrl,
                    onChanged: (v) => setState(() => _provinciaQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar provincia...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _provinciaQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => setState(() {
                                _provinciaSearchCtrl.clear();
                                _provinciaQuery = '';
                              }),
                            )
                          : null,
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.lienzoAlterno,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (provinciasFiltradas.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Sin resultados para esa búsqueda',
                        style: TextStyle(color: AppColors.musgoClaro, fontSize: 13),
                      ),
                    )
                  else ...[
                    ...provinciasVisibles.map(
                      (prov) => _FiltroCheckboxTile(
                        label: prov,
                        selected: _tempProvincia == prov,
                        onTap: () => setState(() {
                          _tempProvincia = _tempProvincia == prov ? null : prov;
                        }),
                      ),
                    ),
                    if (_provinciaQuery.isEmpty &&
                        provinciasFiltradas.length > _kFiltrosLimiteVisible)
                      _VerMasButton(
                        expandido: _showAllProvincias,
                        restantes:
                            provinciasFiltradas.length - _kFiltrosLimiteVisible,
                        onTap: () =>
                            setState(() => _showAllProvincias = !_showAllProvincias),
                      ),
                  ],

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  Text(
                    'Calificación mínima',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) {
                          final starVal = i + 1;
                          return IconButton(
                            onPressed: () {
                              setState(() {
                                _tempRating = _tempRating == starVal ? 0 : starVal;
                              });
                            },
                            icon: Icon(
                              starVal <= _tempRating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: starVal <= _tempRating
                                  ? Colors.amber
                                  : AppColors.musgoClaro,
                              size: 32,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 38),
                          );
                        }),
                      ),
                      if (_tempRating > 0)
                        Text(
                          '★$_tempRating y más',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.tinta,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: FilledButton(
                  onPressed: () {
                    widget.onAplicarFiltros(_tempCategoria, _tempProvincia, _tempRating);
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Aplicar filtros · $resultados resultados',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Fila de filtro tipo checkbox, usada para categoría y provincia dentro
/// del bottom sheet. Aunque la selección subyacente sigue siendo única
/// (mismo campo String? de siempre), visualmente se presenta como una
/// lista vertical escaneable en vez de chips en zig-zag.
class _FiltroCheckboxTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FiltroCheckboxTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              color: selected ? AppColors.sol : AppColors.musgoClaro,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: AppColors.tinta,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Enlace progresivo "Ver más" / "Ver menos" para listas de filtros largas
/// (más de 5-7 elementos), evitando saturar la pantalla de entrada.
class _VerMasButton extends StatelessWidget {
  final bool expandido;
  final int restantes;
  final VoidCallback onTap;

  const _VerMasButton({
    required this.expandido,
    required this.restantes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(
          expandido ? Icons.expand_less_rounded : Icons.expand_more_rounded,
          size: 18,
        ),
        label: Text(expandido ? 'Ver menos' : 'Ver más ($restantes)'),
      ),
    );
  }
}
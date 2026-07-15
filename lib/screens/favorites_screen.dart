import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/favorito_provider.dart';
import '../providers/session_provider.dart';
import '../providers/destino_update_notifier.dart';
import '../models/destino_model.dart';
import '../models/categorias_destino.dart';
import '../widgets/destino_card.dart';
import 'destino_detail_screen.dart';
import '../services/snackbar_service.dart';
import '../theme/app_theme.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _categoriaFiltro;
  bool _needsLoad = true;
  String? _lastSessionUid;

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
    return context.read<FavoritoProvider>().destinosFavoritos.where((d) {
      final q = _sinAcentos(_searchQuery);
      return (q.isEmpty || _sinAcentos(d.nombre).contains(q)) &&
          (_categoriaFiltro == null || d.categoria == _categoriaFiltro);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarFavoritos() async {
    final favoritoProvider = context.read<FavoritoProvider>();

    try {
      final session = context.read<SessionProvider>();

      if (session.user != null) {
        await favoritoProvider.loadDestinosFavoritos(session.user!.uid);
      }
    } catch (e) {
      _needsLoad = true;
      if (mounted) {
        SnackBarService.mostrarError(context, e);
      }
    }
  }

  Future<void> _navegarADetalle(Destino destino) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => DestinoDetailScreen(destino: destino),
      ),
    );
    if (result == true && mounted) {
      _cargarFavoritos();
    }
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

  int _ultimaModificacion = 0;
  int _lastDestinoVersion = -1;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final currentUid = session.user?.uid;

    if (currentUid != null && (_needsLoad || _lastSessionUid != currentUid)) {
      _needsLoad = false;
      _lastSessionUid = currentUid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cargarFavoritos();
      });
    }

    final destinoVersion = context.watch<DestinoUpdateNotifier>().version;
    if (destinoVersion != _lastDestinoVersion) {
      _lastDestinoVersion = destinoVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cargarFavoritos();
      });
    }

    final favoritoProvider = context.watch<FavoritoProvider>();
    final version = favoritoProvider.ultimaModificacionDestinos;
    if (version != _ultimaModificacion) {
      _ultimaModificacion = version;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cargarFavoritos();
      });
    }

    final destinos = favoritoProvider.destinosFavoritos;
    final filtrados = _destinosFiltrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis favoritos'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _cargarFavoritos,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: favoritoProvider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.sol),
            )
          : destinos.isEmpty
              ? _buildEmptyState()
              : CustomScrollView(
                  slivers: [
                    // Búsqueda
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar destino...',
                            prefixIcon:
                                const Icon(Icons.search_rounded),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon:
                                        const Icon(Icons.clear_rounded),
                                    onPressed: () =>
                                        _searchController.clear(),
                                  )
                                : null,
                            filled: true,
                            fillColor: AppColors.lienzoAlterno,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),

                    // Categorías
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          height: 36,
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
                      ),
                    ),

                    // Resultados
                    if (filtrados.isEmpty)
                      SliverFillRemaining(
                          child: _buildSinResultadosState())
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => DestinoCard(
                              destino: filtrados[index],
                              showFavoriteButton: true,
                              onTap: () => _navegarADetalle(filtrados[index]),
                            ),
                            childCount: filtrados.length,
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.solClaro,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                size: 40,
                color: AppColors.sol,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No tienes favoritos todavía',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.tinta,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Toca el corazón en un destino para guardarlo aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.musgo,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSinResultadosState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 64,
              color: AppColors.musgoClaro,
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin resultados',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.tinta,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Intenta con otro nombre o categoría.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.musgo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

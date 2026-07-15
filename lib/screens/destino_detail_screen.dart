import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/destino_model.dart';
import '../models/visita_model.dart';
import '../models/categorias_destino.dart';

import '../providers/session_provider.dart';
import '../providers/visita_provider.dart';
import '../providers/favorito_provider.dart';
import '../providers/destino_update_notifier.dart';
import '../services/snackbar_service.dart';
import '../theme/app_theme.dart';
import '../widgets/clima_resumen.dart';
import 'add_destino_screen.dart';

class DestinoDetailScreen extends StatefulWidget {
  final Destino destino;

  const DestinoDetailScreen({
    super.key,
    required this.destino,
  });

  @override
  State<DestinoDetailScreen> createState() => _DestinoDetailScreenState();
}

class _DestinoDetailScreenState extends State<DestinoDetailScreen> {
  late VisitaProvider _visitaProvider;
  late SessionProvider _sessionProvider;
  late Destino _destino;

  int _calificacionSeleccionada = 0;
  final TextEditingController _comentarioController = TextEditingController();
  bool _isEditing = false;
  bool _dataModificada = false;
  final ScrollController _scrollController = ScrollController();


@override
  void initState() {
    super.initState();
    _destino = widget.destino;
    _visitaProvider = context.read<VisitaProvider>();
    _sessionProvider = context.read<SessionProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarDatos());
  }

  Future<void> _recargarDestino() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('destinos')
          .select()
          .eq('id', _destino.id)
          .single();
      final map = Map<String, dynamic>.from(response);
      if (_destino.nombreCreador != null) {
        map['nombre_creador'] = _destino.nombreCreador;
      }
      if (!mounted) return;
      setState(() => _destino = Destino.fromMap(map));
    } catch (_) {}
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    await _visitaProvider.loadVisitas(_destino.id);

    if (_sessionProvider.user != null) {
      await _visitaProvider.checkUserVisited(
        _destino.id,
        _sessionProvider.user!.uid,
      );

      if (_visitaProvider.userHasVisited && _visitaProvider.userVisita != null) {
        _calificacionSeleccionada = _visitaProvider.userVisita!.calificacion;
        _comentarioController.text = _visitaProvider.userVisita!.comentario ?? '';
      }
    }
  }

  // Método para abrir Google Maps
  Future<void> _abrirGoogleMaps() async {
    final lat = _destino.latitud;
    final lng = _destino.longitud;
    final nombre = Uri.encodeComponent(_destino.nombre);

    // URL para Google Maps (funciona en móvil y web)
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$nombre'
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: abrir en el navegador
        final fallbackUrl = Uri.parse('https://www.google.com/maps?q=$lat,$lng');
        if (await canLaunchUrl(fallbackUrl)) {
          await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
        } else {
          throw 'No se puede abrir Google Maps';
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarService.mostrarError(context, e);
      }
    }
  }

  Future<void> _abrirWaze() async {
    final lat = _destino.latitud;
    final lng = _destino.longitud;

    final url = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se puede abrir Waze';
      }
    } catch (e) {
      if (mounted) {
        SnackBarService.mostrarError(context, e);
      }
    }
  }

  // Mostrar opciones de mapa — bottom sheet minimalista, alineado a la paleta
  void _mostrarOpcionesMapa() {
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
                'Ver ubicación en',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              _MapaOptionTile(
                icon: Icons.map_rounded,
                title: 'Google Maps',
                subtitle: 'Abrir ubicación en Google Maps',
                onTap: () {
                  Navigator.pop(context);
                  _abrirGoogleMaps();
                },
              ),
              _MapaOptionTile(
                icon: Icons.navigation_rounded,
                title: 'Waze',
                subtitle: 'Navegar con Waze',
                onTap: () {
                  Navigator.pop(context);
                  _abrirWaze();
                },
              ),
              _MapaOptionTile(
                icon: Icons.copy_rounded,
                title: 'Copiar coordenadas',
                subtitle: '${_destino.latitud}, ${_destino.longitud}',
                onTap: () {
                  Navigator.pop(context);
                  _copiarCoordenadas();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // Método para copiar coordenadas
  Future<void> _copiarCoordenadas() async {
    try {
      final coordenadas = '${_destino.latitud}, ${_destino.longitud}';
      await Clipboard.setData(ClipboardData(text: coordenadas));
      if (mounted) {
        SnackBarService.mostrarExito(context, 'Coordenadas copiadas al portapapeles',
            duration: const Duration(seconds: 2));
      }
    } catch (e) {
      if (mounted) {
        SnackBarService.mostrarError(context, e);
      }
    }
  }

  Future<void> _guardarVisita() async {
    if (_calificacionSeleccionada == 0) {
      SnackBarService.mostrarAdvertencia(
          context, 'Por favor selecciona una calificación');
      return;
    }

    try {
      if (_visitaProvider.userHasVisited && _visitaProvider.userVisita != null) {
        await _visitaProvider.updateVisita(
          visitaId: _visitaProvider.userVisita!.id,
          calificacion: _calificacionSeleccionada,
          comentario: _comentarioController.text.trim().isEmpty
              ? null
              : _comentarioController.text.trim(),
          destinoId: _destino.id,
        );

        if (!mounted) return;
        SnackBarService.mostrarExito(context, 'Reseña actualizada');
      } else {
        await _visitaProvider.addVisita(
          destinoId: _destino.id,
          uid: _sessionProvider.user!.uid,
          calificacion: _calificacionSeleccionada,
          comentario: _comentarioController.text.trim().isEmpty
              ? null
              : _comentarioController.text.trim(),
          nombreUsuario: _sessionProvider.user?.nombre,
        );

        if (!mounted) return;
        SnackBarService.mostrarExito(context, 'Reseña guardada');
      }

      if (!mounted) return;
      setState(() {
        _isEditing = false;
      });
    } catch (e) {
      if (!mounted) return;
      SnackBarService.mostrarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visitaProvider = context.watch<VisitaProvider>();
    final session = context.watch<SessionProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, _dataModificada);
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.lienzo,
      body: CustomScrollView(
        slivers: [
          // Header con la imagen a pantalla ancha, botones circulares
          // translúcidos y degradado para legibilidad — sin AppBar sólido
          // repitiendo el nombre que ya se ve abajo.
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: 300,
            backgroundColor: AppColors.lienzo,
            foregroundColor: AppColors.tinta,
            elevation: 0,
            scrolledUnderElevation: 0,
            leadingWidth: 64,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.pop(context, _dataModificada),
              ),
            ),
            actions: [
              // Editar (solo dueño)
              if (session.isLoggedIn && _destino.uid == session.user?.uid)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _CircleIconButton(
                    icon: Icons.edit_rounded,
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddDestinoScreen(
                            destinoToEdit: _destino,
                          ),
                        ),
                      );
                      if (result == true && mounted) {
                        await _recargarDestino();
                        await _cargarDatos();
                        _dataModificada = true;
                        context.read<DestinoUpdateNotifier>().notify();
                        if (session.user != null && context.mounted) {
                          context
                              .read<FavoritoProvider>()
                              .refreshDestinosFavoritos(session.user!.uid);
                        }
                      }
                    },
                  ),
                ),
              // Eliminar (solo dueño)
              if (session.isLoggedIn && _destino.uid == session.user?.uid)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _CircleIconButton(
                    icon: Icons.delete_outline_rounded,
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Eliminar destino'),
                          content: Text(
                            '¿Estás seguro de que quieres eliminar "${_destino.nombre}"?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.musgo,
                              ),
                              child: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        try {
                          await Supabase.instance.client
                              .from('destinos')
                              .delete()
                              .eq('id', _destino.id);
                          if (!mounted) return;
                          SnackBarService.mostrarExito(
                              context, 'Destino eliminado');
                          
                          // Notificar cambios globales para que Home y Favorites se refresquen
                          context.read<DestinoUpdateNotifier>().notify();
                          if (session.user != null && context.mounted) {
                            context.read<FavoritoProvider>().refreshDestinosFavoritos(session.user!.uid);
                          }
                          
                          Navigator.pop(context);
                        } catch (e) {
                          if (!mounted) return;
                          SnackBarService.mostrarError(context, e);
                        }
                      }
                    },
                  ),
                ),
              if (session.isLoggedIn && !visitaProvider.userHasVisited && !_isEditing)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _CircleIconButton(
                    icon: Icons.reviews_rounded,
                    onTap: () {
                      setState(() {
                        _isEditing = true;
                      });
                    },
                  ),
                ),
              Consumer<FavoritoProvider>(
                builder: (context, favoritoProvider, _) {
                  final isFavorito = favoritoProvider.isFavorito(_destino.id);
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _CircleIconButton(
                      icon: isFavorito ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      iconColor: isFavorito ? AppColors.error : AppColors.musgo,
                      onTap: () async {
                        try {
                          await favoritoProvider.toggleFavorito(
                            session.user!.uid,
                            _destino.id,
                          );
                          if (!context.mounted) return;
                          SnackBarService.mostrarExito(
                            context,
                            isFavorito ? 'Eliminado de favoritos' : 'Agregado a favoritos',
                            duration: const Duration(seconds: 1),
                          );
                          
                          // Notificar cambios globales para que Home y Favorites se refresquen
                          context.read<DestinoUpdateNotifier>().notify();
                          if (session.user != null && context.mounted) {
                            context.read<FavoritoProvider>().refreshDestinosFavoritos(session.user!.uid);
                          }
                        } catch (e) {
                          if (!context.mounted) return;
                          SnackBarService.mostrarError(context, e);
                        }
                      },
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    _destino.imagenUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: AppColors.lienzoAlterno,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.sol,
                            strokeWidth: 2.4,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppColors.lienzoAlterno,
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            size: 48,
                            color: AppColors.musgoClaro,
                          ),
                        ),
                      );
                    },
                  ),
                  // Degradado inferior: mejora contraste de los botones y
                  // funde la foto con el fondo `lienzo` del contenido.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.5, 1.0],
                        colors: [
                          Colors.transparent,
                          AppColors.tinta.withValues(alpha: 0.45),
                        ],
                      ),
                    ),
                  ),
                  if (_destino.categoria.isNotEmpty)
                    Positioned(
                      left: 16,
                      bottom: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.tinta.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          categoriaLabels[_destino.categoria] ?? _destino.categoria,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _destino.nombre,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 17, color: AppColors.musgo),
                      const SizedBox(width: 4),
                      Text(
                        _destino.provincia,
                        style: const TextStyle(fontSize: 14, color: AppColors.musgo),
                      ),
                    ],
                  ),

                  if (_destino.nombreCreador != null &&
                      _destino.nombreCreador!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_rounded, size: 15, color: AppColors.musgoClaro),
                        const SizedBox(width: 4),
                        Text(
                          'Creado por ${_destino.nombreCreador}',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.musgoClaro),
                        ),
                      ],
                    ),
                  ],

                  // Descripción
                  if (_destino.descripcion.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.description_outlined, size: 16, color: AppColors.musgoClaro),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _destino.descripcion,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.musgo,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Mapa interactivo con OpenStreetMap
                  Container(
                    height: 260,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.niebla),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: GestureDetector(
                        onTap: _mostrarOpcionesMapa,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(_destino.latitud, _destino.longitud),
                            initialZoom: 14,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.all,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.travel_ecuador',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(_destino.latitud, _destino.longitud),
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_on_rounded,
                                    color: AppColors.error,
                                    size: 36,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // "Cómo llegar" + acceso al mapa
                  InkWell(
                    onTap: _mostrarOpcionesMapa,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: AppColors.lienzoAlterno,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.map_rounded, size: 18, color: AppColors.sol),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cómo llegar',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.tinta,
                              ),
                            ),
                          ),
                          const Icon(Icons.map_outlined, size: 20, color: AppColors.sol),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  ClimaResumen(destino: _destino),

                  const SizedBox(height: 14),


                  const SizedBox(height: 28),
                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  // ----- Calificaciones -----
                  Row(
                    children: [
                      Text(
                        'Calificaciones',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                      ),
                      const Spacer(),
                      if (visitaProvider.totalVisitas > 0) ...[
                        const Icon(Icons.star_rounded, color: AppColors.sol, size: 20),
                        const SizedBox(width: 3),
                        Text(
                          visitaProvider.promedioCalificacion.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.tinta,
                          ),
                        ),
                        Text(
                          ' (${visitaProvider.totalVisitas})',
                          style: const TextStyle(fontSize: 13, color: AppColors.musgoClaro),
                        ),
                      ],
                    ],
                  ),

                  if (visitaProvider.totalVisitas == 0)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Aún no hay calificaciones',
                        style: TextStyle(fontSize: 14, color: AppColors.musgoClaro),
                      ),
                    ),

                  const SizedBox(height: 18),

                  if (_isEditing) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.niebla),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Encabezado del formulario: distingue "nueva reseña"
                          // de "editar reseña" en vez de un título fijo genérico.
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.solClaro,
                                ),
                                child: const Icon(
                                  Icons.rate_review_rounded,
                                  color: AppColors.sol,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                visitaProvider.userHasVisited
                                    ? 'Editar tu reseña'
                                    : 'Comparte tu experiencia',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppColors.tinta,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Calificación centrada, con etiqueta de texto que
                          // confirma la selección (antes solo eran estrellas
                          // sueltas sin ningún feedback textual).
                          Center(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(5, (index) {
                                    final seleccionada = index < _calificacionSeleccionada;
                                    return InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () {
                                        setState(() {
                                          _calificacionSeleccionada = index + 1;
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                                        child: Icon(
                                          seleccionada ? Icons.star_rounded : Icons.star_border_rounded,
                                          color: AppColors.sol,
                                          size: 32,
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _etiquetaCalificacion(_calificacionSeleccionada),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.musgoClaro,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Campo "filled" sin borde, mismo lenguaje que el
                          // buscador del home, en vez del input con línea
                          // inferior genérica del resto del formulario.
                          TextField(
                            controller: _comentarioController,
                            maxLines: 3,
                            style: const TextStyle(fontSize: 14, color: AppColors.tinta),
                            decoration: InputDecoration(
                              hintText: 'Cuéntanos cómo fue tu visita (opcional)',
                              filled: true,
                              fillColor: AppColors.lienzoAlterno,
                              isDense: false,
                              contentPadding: const EdgeInsets.all(14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppColors.sol, width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _isEditing = false;
                                      _calificacionSeleccionada = 0;
                                      _comentarioController.clear();
                                    });
                                  },
                                  child: const Text('Cancelar'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _guardarVisita,
                                child: Text(
                                  visitaProvider.userHasVisited
                                      ? 'Actualizar reseña'
                                      : 'Publicar reseña',
                                  textAlign: TextAlign.center,
                                ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],
                ],
              ),
            ),
          ),

          if (visitaProvider.isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: AppColors.sol)),
              ),
            )
          else if (visitaProvider.visitas.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: AppColors.solClaro,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 28,
                          color: AppColors.sol,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No hay comentarios aún',
                        style: TextStyle(color: AppColors.musgo, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _VisitaCard(
                    visita: visitaProvider.visitas[index],
                    esPropia: _sessionProvider.user?.uid == visitaProvider.visitas[index].uid,
                    onEditar: () {
                      final visita = visitaProvider.visitas[index];
                      setState(() {
                        _isEditing = true;
                        _calificacionSeleccionada = visita.calificacion;
                        _comentarioController.text = visita.comentario ?? '';
                      });
                    },
                    onEliminar: () async {
                      final visita = visitaProvider.visitas[index];
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Eliminar reseña'),
                          content: const Text('¿Estás seguro de que quieres eliminar tu reseña?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(foregroundColor: AppColors.musgo),
                              child: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          await _visitaProvider.deleteVisita(
                            visita.id,
                            _destino.id,
                          );
                          if (!mounted) return;
                          SnackBarService.mostrarExito(context, 'Reseña eliminada');
                        } catch (e) {
                          if (!mounted) return;
                          SnackBarService.mostrarError(context, e);
                        }
                      }
                    },
                    formatDate: _formatDate,
                  ),
                  childCount: visitaProvider.visitas.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      ),
    );
  }

  /// Etiqueta descriptiva bajo las estrellas del formulario de reseña.
  /// Puramente visual: no afecta el valor guardado en `_calificacionSeleccionada`.
  String _etiquetaCalificacion(int calificacion) {
    switch (calificacion) {
      case 1:
        return 'Muy malo';
      case 2:
        return 'Malo';
      case 3:
        return 'Regular';
      case 4:
        return 'Bueno';
      case 5:
        return 'Excelente';
      default:
        return 'Toca una estrella para calificar';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return 'Hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Hace un momento';
    }
  }
}

/// Botón circular translúcido para acciones sobre la imagen de cabecera
/// (volver, favorito) — mismo lenguaje visual que el corazón de [DestinoCard].
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: Icon(icon, color: iconColor ?? AppColors.musgo, size: 22),
        onPressed: onTap,
      ),
    );
  }
}

/// Fila de opción dentro del bottom sheet de mapa.
class _MapaOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MapaOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.solClaro,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.sol, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.tinta),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.musgo),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de reseña.
///
/// Rediseño: el avatar toma el acento de marca (antes gris plano), la
/// calificación se movió junto al nombre/fecha en vez de quedar aislada
/// arriba a la derecha con un vacío enorme al lado, el comentario queda
/// alineado bajo el encabezado (como una respuesta, no un bloque suelto),
/// y las acciones de editar/eliminar pasan de íconos flotando en el
/// vacío a una fila compacta con etiqueta, separada por un borde superior
/// fino solo cuando hay algo que editar.
class _VisitaCard extends StatelessWidget {
  final Visita visita;
  final bool esPropia;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final String Function(DateTime) formatDate;

  const _VisitaCard({
    required this.visita,
    required this.esPropia,
    required this.onEditar,
    required this.onEliminar,
    required this.formatDate,
  });

  static const double _avatarSize = 36;
  static const double _headerGap = 10;

  @override
  Widget build(BuildContext context) {
    final tieneComentario = visita.comentario != null && visita.comentario!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.niebla),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado: avatar + nombre/fecha + calificación, todo en
          // la misma línea de lectura (antes la calificación quedaba
          // pegada al borde derecho, desconectada del resto).
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: _avatarSize,
                height: _avatarSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.solClaro,
                ),
                child: Center(
                  child: Text(
                    (visita.nombreUsuario?.isNotEmpty ?? false)
                        ? visita.nombreUsuario!.substring(0, 1).toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.solOscuro,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: _headerGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visita.nombreUsuario ?? 'Usuario',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: AppColors.tinta,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatDate(visita.createdAt),
                      style: const TextStyle(fontSize: 11.5, color: AppColors.musgoClaro),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return Icon(
                    index < visita.calificacion ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppColors.sol,
                    size: 15,
                  );
                }),
              ),
            ],
          ),

          if (tieneComentario) ...[
            const SizedBox(height: 10),
            Padding(
              // Alineado bajo el nombre (avatar + gap), no pegado al
              // borde del card, para que se lea como parte del mismo bloque.
              padding: const EdgeInsets.only(left: _avatarSize + _headerGap),
              child: Text(
                visita.comentario!,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.musgo,
                  height: 1.45,
                ),
              ),
            ),
          ],

          if (esPropia) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.niebla),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _AccionTexto(
                  icon: Icons.edit_rounded,
                  label: 'Editar',
                  color: AppColors.musgo,
                  onTap: onEditar,
                ),
                const SizedBox(width: 4),
                _AccionTexto(
                  icon: Icons.delete_outline_rounded,
                  label: 'Eliminar',
                  color: AppColors.musgo,
                  onTap: onEliminar,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Botón de acción compacto (ícono + etiqueta) para las tarjetas de
/// reseña propia — reemplaza los `IconButton` sueltos sin texto que
/// quedaban ambiguos y con demasiado espacio en blanco alrededor.
class _AccionTexto extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AccionTexto({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import '../models/destino_model.dart';
import '../providers/session_provider.dart';
import '../providers/favorito_provider.dart';
import '../providers/visita_provider.dart';

import '../widgets/destino_card.dart';
import 'add_destino_screen.dart';
import '../services/visita_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Destino> _destinos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDestinos();
  }

  Future<void> _cargarDestinos() async {
    setState(() => _isLoading = true);
    
    try {
      final supabase = Supabase.instance.client;
      final visitaService = VisitaService();
      
      // Obtener destinos
      final response = await supabase
          .from('destinos')
          .select('*');
      
      print('Total en BD: ${response.length}');
      
      // Obtener los UIDs únicos de los creadores
      final uids = response.map((map) => map['uid'] as String).toSet().toList();
      
      // Obtener nombres de usuario de la tabla 'users'
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
      
      // Mapear destinos con el nombre del creador
      _destinos = response.map((map) {
        final destinoMap = Map<String, dynamic>.from(map);
        final uid = map['uid'] as String;
        destinoMap['nombre_creador'] = nombresUsuarios[uid] ?? 'Usuario';
        return Destino.fromMap(destinoMap);
      }).toList();

      // Cargar calificaciones
      if (_destinos.isNotEmpty) {
        final destinoIds = _destinos.map((d) => d.id).toList();
        final calificaciones = await visitaService.getCalificacionesForDestinos(destinoIds);

        _destinos = _destinos.map((destino) {
          final data = calificaciones[destino.id];
          if (data != null) {
            return destino.copyWith(
              promedioCalificacion: data['promedio'],
              totalCalificaciones: data['total'],
            );
          }
          return destino;
        }).toList();
      }
      
      // Si no hay destinos, mostrar mensaje
      if (_destinos.isEmpty) {
        print('No hay destinos en la base de datos');
      }
      
    } catch (e) {
      print('Error al cargar destinos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  // Método para cerrar sesión
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
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      context.read<FavoritoProvider>().clearFavoritos();
      await context.read<SessionProvider>().logout();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepOrange.shade200,
                    Colors.deepOrange.shade50,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.travel_explore,
                size: 44,
                color: Colors.deepOrange.shade700,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No hay destinos disponibles',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega tu primer lugar para empezar a descubrir Ecuador.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navegarAgregar() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddDestinoScreen(),
      ),
    );

    if (result == true) {
      _cargarDestinos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _destinos.isEmpty
              ? _buildEmptyState()
              : CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 170.0,
                      floating: true,
                      pinned: true,
                      stretch: true,
                      elevation: 0,
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      flexibleSpace: FlexibleSpaceBar(
                        titlePadding: const EdgeInsetsDirectional.only(
                          start: 16,
                          bottom: 16,
                        ),
                        title: const Text(
                          'Destinos en Ecuador',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                        centerTitle: true,
                        background: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).primaryColor,
                                const Color(0xFFFF8A50),
                              ],
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: -20,
                                right: -10,
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.08),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: -30,
                                left: -20,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.08),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.logout),
                          onPressed: _logout,
                          tooltip: 'Cerrar sesión',
                        ),
                      ],
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: DestinoCard(
                              destino: _destinos[index],
                              showFavoriteButton: true,
                            ),
                          ),
                          childCount: _destinos.length,
                        ),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navegarAgregar,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo lugar'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 6,
      ),
    );
  }
}
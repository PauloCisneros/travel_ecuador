import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travel_ecuador/models/destino_model.dart';
import '../providers/favorito_provider.dart';
import '../providers/session_provider.dart';
import '../providers/visita_provider.dart'; 
import '../widgets/destino_card.dart';
import '../services/visita_service.dart';  

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _isLoading = true;
  List<Destino> _destinosFavoritos = [];

  @override
  void initState() {
    super.initState();
    _cargarFavoritos();
  }

  Future<void> _cargarFavoritos() async {
    setState(() => _isLoading = true);
    
    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final favoritoProvider = Provider.of<FavoritoProvider>(context, listen: false);
      final visitaService = VisitaService(); 
      
      if (session.user != null) {
        await favoritoProvider.loadDestinosFavoritos(session.user!.uid);
        
        // Obtener los destinos favoritos con sus calificaciones
        final destinos = favoritoProvider.destinosFavoritos;
        
        if (destinos.isNotEmpty) {
          final destinoIds = destinos.map((d) => d.id).toList();
          final calificaciones = await visitaService.getCalificacionesForDestinos(destinoIds);
          
          // Asignar calificaciones a cada destino
          _destinosFavoritos = destinos.map((destino) {
            final data = calificaciones[destino.id];
            if (data != null) {
              return destino.copyWith(
                promedioCalificacion: data['promedio'],
                totalCalificaciones: data['total'],
              );
            }
            return destino;
          }).toList();
        } else {
          _destinosFavoritos = destinos;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar favoritos: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Mis Favoritos'),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarFavoritos,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _destinosFavoritos.isEmpty
              ? Center(
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
                        Icon(
                          Icons.favorite_border,
                          size: 76,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No tienes favoritos',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Toca el corazón en los destinos para agregarlos.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: _destinosFavoritos.length,
                  itemBuilder: (context, index) {
                    final destino = _destinosFavoritos[index];
                    return DestinoCard(
                      destino: destino,
                      showFavoriteButton: false,
                    );
                  },
                ),
    );
  }
}
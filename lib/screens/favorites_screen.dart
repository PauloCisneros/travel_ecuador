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
      appBar: AppBar(
        title: const Text('Mis Favoritos'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No tienes favoritos',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Toca el corazón ❤️ en los destinos para agregarlos',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
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
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/destino_model.dart';
import '../models/categorias_destino.dart';
import '../providers/favorito_provider.dart';
import '../providers/session_provider.dart';
import '../screens/destino_detail_screen.dart';
import '../services/snackbar_service.dart';
import '../theme/app_theme.dart';
import 'clima_resumen.dart';

class DestinoCard extends StatelessWidget {
  final Destino destino;
  final bool showFavoriteButton;
  final double? distanciaKm;

  const DestinoCard({
    super.key,
    required this.destino,
    this.showFavoriteButton = true,
    this.distanciaKm,
  });

  @override
  Widget build(BuildContext context) {
    final favoritoProvider = context.watch<FavoritoProvider>();
    final session = context.watch<SessionProvider>();
    final isFavorito = favoritoProvider.isFavorito(destino.id);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DestinoDetailScreen(destino: destino),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.niebla),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen con corazón, categoría
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(
                    destino.imagenUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: double.infinity,
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
                        width: double.infinity,
                        color: AppColors.lienzoAlterno,
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            size: 44,
                            color: AppColors.musgoClaro,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Badge de categoría
                if (destino.categoria.isNotEmpty)
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tinta.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        categoriaLabels[destino.categoria] ?? destino.categoria,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                // Distancia (Cerca de mí)
                if (distanciaKm != null)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tinta.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.near_me_rounded, size: 11, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            distanciaKm! < 1
                                ? '${(distanciaKm! * 1000).toInt()} m'
                                : '${distanciaKm!.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Botón de favoritos (corazón)
                if (showFavoriteButton)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          isFavorito ? Icons.favorite : Icons.favorite_border,
                          color: isFavorito ? Colors.red : AppColors.musgoClaro,
                          size: 26,
                        ),
                        onPressed: () async {
                          try {
                            await favoritoProvider.toggleFavorito(
                              session.user!.uid,
                              destino.id,
                            );

                            if (!context.mounted) return;
                            SnackBarService.mostrarExito(
                              context,
                              isFavorito
                                  ? 'Eliminado de favoritos'
                                  : 'Agregado a favoritos',
                              duration: const Duration(seconds: 1),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            SnackBarService.mostrarError(context, e);
                          }
                        },
                      ),
                    ),
                  ),
                // Etiqueta de favorito
                if (!showFavoriteButton)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Favorito',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // Información
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destino.nombre,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 15,
                        color: AppColors.musgo,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        destino.provincia,
                        style: const TextStyle(
                          color: AppColors.musgo,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),

                  if (destino.nombreCreador != null && destino.nombreCreador!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_rounded,
                          size: 14,
                          color: AppColors.musgoClaro,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Creado por ${destino.nombreCreador}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.musgoClaro,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Calificación
                  if (destino.promedioCalificacion != null &&
                      destino.promedioCalificacion! > 0) ...[
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                        const SizedBox(width: 3),
                        Text(
                          destino.promedioCalificacion!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.tinta,
                          ),
                        ),
                        Text(
                          ' (${destino.totalCalificaciones ?? 0})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.musgoClaro,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Clima — mismo widget compartido que se usa en el detalle,
                  // para que el destino se lea igual en toda la app.
                  ClimaResumen(destino: destino),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
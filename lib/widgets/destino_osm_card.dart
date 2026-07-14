import 'package:flutter/material.dart';
import '../models/sitio_osm.dart';
import '../theme/app_theme.dart';
import '../screens/add_destino_screen.dart';

class DestinoOsmCard extends StatelessWidget {
  final SitioOsm sitio;

  const DestinoOsmCard({super.key, required this.sitio});

  IconData _iconoTipo(String tipo) {
    switch (tipo) {
      case 'attraction':
        return Icons.attractions_rounded;
      case 'museum':
        return Icons.museum_rounded;
      case 'viewpoint':
        return Icons.visibility_rounded;
      case 'gallery':
        return Icons.palette_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  String _labelTipo(String tipo) {
    switch (tipo) {
      case 'attraction':
        return 'Atracción';
      case 'museum':
        return 'Museo';
      case 'viewpoint':
        return 'Mirador';
      case 'gallery':
        return 'Galería';
      default:
        return 'Lugar';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.niebla),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
                Icon(_iconoTipo(sitio.tipo), size: 18, color: AppColors.sol),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _labelTipo(sitio.tipo),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.musgo,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              sitio.nombre,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.tinta,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: Row(
              children: [
                const Icon(Icons.near_me_rounded, size: 13, color: AppColors.musgoClaro),
                const SizedBox(width: 3),
                Text(
                  sitio.distanciaKm < 1
                      ? '${(sitio.distanciaKm * 1000).toInt()} m'
                      : '${sitio.distanciaKm.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.musgoClaro,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            child: SizedBox(
              width: double.infinity,
              height: 32,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddDestinoScreen(
                        nombrePrellenado: sitio.nombre,
                        latPrellenado: sitio.latitud,
                        lngPrellenado: sitio.longitud,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text('Agregar', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.sol,
                  side: const BorderSide(color: AppColors.sol),
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

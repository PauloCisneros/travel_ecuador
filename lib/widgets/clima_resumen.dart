import 'package:flutter/material.dart';
import '../models/destino_model.dart';
import '../theme/app_theme.dart';

/// Resumen de clima de un destino: clima, temperatura y humedad,
/// distribuidos en 3 columnas parejas sobre una superficie tenue.
///
/// Se usa tanto en [DestinoCard] (home / favoritos) como en
/// `DestinoDetailScreen`, para que el mismo destino se "lea" igual
/// en cualquier pantalla de la app.
class ClimaResumen extends StatelessWidget {
  final Destino destino;

  const ClimaResumen({super.key, required this.destino});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.lienzoAlterno,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ClimaItem(
              icon: Icons.wb_cloudy_rounded,
              value: destino.clima,
              label: 'Clima',
            ),
          ),
          const _ClimaDivisor(),
          Expanded(
            child: _ClimaItem(
              icon: Icons.thermostat_rounded,
              value: '${destino.temperatura.toStringAsFixed(1)}°C',
              label: 'Temperatura',
              destacado: true,
            ),
          ),
          const _ClimaDivisor(),
          Expanded(
            child: _ClimaItem(
              icon: Icons.water_drop_rounded,
              value: '${destino.humedad}%',
              label: 'Humedad',
            ),
          ),
        ],
      ),
    );
  }
}

class _ClimaDivisor extends StatelessWidget {
  const _ClimaDivisor();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: AppColors.niebla,
    );
  }
}

class _ClimaItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool destacado;

  const _ClimaItem({
    required this.icon,
    required this.value,
    required this.label,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color acento = destacado ? AppColors.sol : AppColors.musgo;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: acento),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: destacado ? FontWeight.w700 : FontWeight.w600,
            color: destacado ? AppColors.sol : AppColors.tinta,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.musgoClaro,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
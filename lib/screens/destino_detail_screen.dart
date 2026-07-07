import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; 

import '../models/destino_model.dart';
import '../models/visita_model.dart';

import '../providers/session_provider.dart';
import '../providers/visita_provider.dart';
import '../providers/favorito_provider.dart';

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
  late FavoritoProvider _favoritoProvider;
  
  int _calificacionSeleccionada = 0;
  final TextEditingController _comentarioController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    _visitaProvider = context.read<VisitaProvider>();
    _sessionProvider = context.read<SessionProvider>();
    _favoritoProvider = context.read<FavoritoProvider>();
    
    await _visitaProvider.loadVisitas(widget.destino.id);
    
    if (_sessionProvider.user != null) {
      await _visitaProvider.checkUserVisited(
        widget.destino.id,
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
    final lat = widget.destino.latitud;
    final lng = widget.destino.longitud;
    final nombre = Uri.encodeComponent(widget.destino.nombre);
    
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir Google Maps: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Método para abrir en Waze (opcional)
  Future<void> _abrirWaze() async {
    final lat = widget.destino.latitud;
    final lng = widget.destino.longitud;
    
    final url = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se puede abrir Waze';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir Waze: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Mostrar diálogo con opciones de mapa
  void _mostrarOpcionesMapa() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ver ubicación en:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.map, color: Colors.green),
                ),
                title: const Text('Google Maps'),
                subtitle: const Text('Ver ubicación en Google Maps'),
                onTap: () {
                  Navigator.pop(context);
                  _abrirGoogleMaps();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.directions_car, color: Colors.blue),
                ),
                title: const Text('Waze'),
                subtitle: const Text('Navegar con Waze'),
                onTap: () {
                  Navigator.pop(context);
                  _abrirWaze();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.copy, color: Colors.grey),
                ),
                title: const Text('Copiar coordenadas'),
                subtitle: Text(
                  '${widget.destino.latitud}, ${widget.destino.longitud}',
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Copiar coordenadas al portapapeles
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
      final coordenadas = '${widget.destino.latitud}, ${widget.destino.longitud}';
      await Clipboard.setData(ClipboardData(text: coordenadas));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Coordenadas copiadas al portapapeles'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al copiar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _guardarVisita() async {
    if (_calificacionSeleccionada == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una calificación'),
          backgroundColor: Colors.orange,
        ),
      );
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
          destinoId: widget.destino.id,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Reseña actualizada'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await _visitaProvider.addVisita(
          destinoId: widget.destino.id,
          uid: _sessionProvider.user!.uid,
          calificacion: _calificacionSeleccionada,
          comentario: _comentarioController.text.trim().isEmpty 
              ? null 
              : _comentarioController.text.trim(),
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Reseña guardada'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      setState(() {
        _isEditing = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visitaProvider = context.watch<VisitaProvider>();
    final session = context.watch<SessionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.destino.nombre),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          // Botón de favoritos en el detalle
          Consumer<FavoritoProvider>(
            builder: (context, favoritoProvider, _) {
              final isFavorito = favoritoProvider.isFavorito(widget.destino.id);
              return IconButton(
                icon: Icon(
                  isFavorito ? Icons.favorite : Icons.favorite_border,
                  color: isFavorito ? Colors.red : Colors.white,
                ),
                onPressed: () async {
                  try {
                    await favoritoProvider.toggleFavorito(
                      session.user!.uid,
                      widget.destino.id,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isFavorito 
                            ? 'Eliminado de favoritos' 
                            : 'Agregado a favoritos',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del destino
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.destino.imagenUrl,
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 250,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 250,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Título y ubicación con botón de mapa
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.destino.nombre,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 20,
                            color: Colors.deepOrange.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.destino.provincia,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Botón de mapa
                Container(
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.deepOrange.shade200),
                  ),
                  child: IconButton(
                    onPressed: _mostrarOpcionesMapa,
                    icon: Icon(
                      Icons.map,
                      color: Colors.deepOrange.shade700,
                    ),
                    tooltip: 'Ver en mapa',
                    iconSize: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            
            // Mostrar coordenadas
            Row(
              children: [
                Icon(
                  Icons.location_pin,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.destino.latitud}, ${widget.destino.longitud}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Descripción
            Text(
              widget.destino.descripcion,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade800,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            // Datos del clima
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoItem(Icons.wb_cloudy, 'Clima', widget.destino.clima),
                  _buildInfoItem(Icons.thermostat, 'Temperatura', 
                      '${widget.destino.temperatura.toStringAsFixed(1)}°C'),
                  _buildInfoItem(Icons.water_drop, 'Humedad', 
                      '${widget.destino.humedad}%'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sección de calificaciones
            const Divider(thickness: 2),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Calificaciones',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (visitaProvider.totalVisitas > 0) ...[
                  Text(
                    '${visitaProvider.promedioCalificacion.toStringAsFixed(1)} ★',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${visitaProvider.totalVisitas})',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Estrellas de promedio
            if (visitaProvider.totalVisitas > 0) ...[
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < visitaProvider.promedioCalificacion.round()
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.amber,
                    size: 30,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                '${visitaProvider.totalVisitas} ${visitaProvider.totalVisitas == 1 ? 'visita' : 'visitas'}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ] else ...[
              Text(
                'Aún no hay calificaciones',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Botón para agregar/editar reseña
            if (session.isLoggedIn) ...[
              if (!_isEditing) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                      if (visitaProvider.userHasVisited) {
                        _calificacionSeleccionada = visitaProvider.userVisita!.calificacion;
                        _comentarioController.text = visitaProvider.userVisita!.comentario ?? '';
                      }
                    });
                  },
                  icon: Icon(
                    visitaProvider.userHasVisited 
                        ? Icons.edit 
                        : Icons.add_comment,
                  ),
                  label: Text(
                    visitaProvider.userHasVisited 
                        ? 'Editar mi reseña' 
                        : 'Agregar reseña',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ] else ...[
                // Formulario de reseña
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tu calificación',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (index) {
                          return IconButton(
                            onPressed: () {
                              setState(() {
                                _calificacionSeleccionada = index + 1;
                              });
                            },
                            icon: Icon(
                              index < _calificacionSeleccionada
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 40,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _comentarioController,
                        decoration: const InputDecoration(
                          labelText: 'Comentario (opcional)',
                          border: OutlineInputBorder(),
                          hintText: 'Escribe tu experiencia...',
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _guardarVisita,
                              child: Text(
                                visitaProvider.userHasVisited 
                                    ? 'Actualizar' 
                                    : 'Guardar',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],

            // Lista de reseñas
            const Text(
              'Comentarios',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            if (visitaProvider.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (visitaProvider.visitas.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Text(
                    'No hay comentarios aún',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              )
            else
              ...visitaProvider.visitas.map((visita) => _buildVisitaCard(visita)),
            
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue.shade700, size: 28),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildVisitaCard(Visita visita) {
    final isCurrentUser = _sessionProvider.user?.uid == visita.uid;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.deepOrange.shade100,
                  child: Text(
                    visita.nombreUsuario?.substring(0, 1).toUpperCase() ?? '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visita.nombreUsuario ?? 'Usuario',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatDate(visita.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Estrellas
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < visita.calificacion
                          ? Icons.star
                          : Icons.star_border,
                      color: Colors.amber,
                      size: 18,
                    );
                  }),
                ),
              ],
            ),
            if (visita.comentario != null && visita.comentario!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                visita.comentario!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
            if (isCurrentUser) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isEditing = true;
                        _calificacionSeleccionada = visita.calificacion;
                        _comentarioController.text = visita.comentario ?? '';
                      });
                    },
                    child: const Text('Editar'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
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
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          await _visitaProvider.deleteVisita(
                            visita.id,
                            widget.destino.id,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Reseña eliminada'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Eliminar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
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
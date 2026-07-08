import 'dart:io';
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/gps_service.dart';
import '../services/weather_service.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../models/destino_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddDestinoScreen extends StatefulWidget {
  final Destino? destinoToEdit;
  const AddDestinoScreen({super.key, this.destinoToEdit});

  @override
  State<AddDestinoScreen> createState() => _AddDestinoScreenState();
}

class _AddDestinoScreenState extends State<AddDestinoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _provinciaController = TextEditingController();
  final _descripcionController = TextEditingController();

  File? _imagenFile;
  Uint8List? _imagenBytes;
  String? _imagenNombre;
  String? _imagenUrlExistente;
  bool _isLoading = false;
  bool _isEditing = false;
  final ImagePicker _picker = ImagePicker();

  double? _latitud;
  double? _longitud;
  String? _clima;
  double? _temperatura;
  int? _humedad;
  String _loadingMessage = 'Preparando...';

  bool get _hasImage => _imagenFile != null || _imagenBytes != null || (_imagenUrlExistente != null && _imagenUrlExistente!.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _isEditing = widget.destinoToEdit != null;
    
    if (_isEditing) {
      final destino = widget.destinoToEdit!;
      _nombreController.text = destino.nombre;
      _provinciaController.text = destino.provincia;
      _descripcionController.text = destino.descripcion;
      _latitud = destino.latitud;
      _longitud = destino.longitud;
      _clima = destino.clima;
      _temperatura = destino.temperatura;
      _humedad = destino.humedad;
      _imagenUrlExistente = destino.imagenUrl;
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _provinciaController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _obtenerUbicacionYClima() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Solicitando ubicación...';
    });

    try {
      final gpsService = GpsService();
      final position = await gpsService.getCurrentLocation();
      _latitud = position.latitude;
      _longitud = position.longitude;

      if (!mounted) return;
      setState(() {
        _loadingMessage = 'Consultando clima...';
      });

      final weatherService = WeatherService();
      final weatherData = await weatherService.getWeather(_latitud!, _longitud!);
      _clima = weatherData['clima'];
      _temperatura = weatherData['temperatura'];
      _humedad = weatherData['humedad'];

      if (!mounted) return;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = 'Preparando...';
        });
      }
        const SnackBar(content: Text('Ubicación y clima obtenidos correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _seleccionarImagen() async {
    try {
      final XFile? xFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (xFile == null) return;

      if (kIsWeb) {
        final bytes = await xFile.readAsBytes();
        if (bytes.length > 1048576) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('La imagen debe ser menor a 1 MB'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        setState(() {
          _imagenBytes = bytes;
          _imagenFile = null;
          _imagenNombre = xFile.name;
          _imagenUrlExistente = null;
        });
      } else {
        final file = File(xFile.path);
        final bytes = await file.readAsBytes();
        if (bytes.length > 1048576) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('La imagen debe ser menor a 1 MB'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        setState(() {
          _imagenFile = file;
          _imagenBytes = null;
          _imagenNombre = xFile.name;
          _imagenUrlExistente = null;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Imagen seleccionada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error al seleccionar imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _guardarDestino() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una imagen')),
      );
      return;
    }

    if (_latitud == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Obtén la ubicación primero')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final storageService = StorageService();
      final supabase = Supabase.instance.client;

      final user = authService.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      String imageUrl = _imagenUrlExistente ?? '';

      // Si hay una imagen nueva, subirla
      if (_imagenFile != null || _imagenBytes != null) {
        if (kIsWeb && _imagenBytes != null) {
          imageUrl = await storageService.uploadImageWeb(_imagenBytes!, user.id);
        } else if (_imagenFile != null) {
          imageUrl = await storageService.uploadImage(_imagenFile!, user.id);
        } else {
          throw Exception('Formato de imagen no soportado');
        }
      }

      if (_isEditing) {
        // Actualizar destino existente
        final destinoActualizado = widget.destinoToEdit!.copyWith(
          nombre: _nombreController.text.trim(),
          provincia: _provinciaController.text.trim(),
          descripcion: _descripcionController.text.trim(),
          latitud: _latitud!,
          longitud: _longitud!,
          clima: _clima ?? 'No disponible',
          temperatura: _temperatura ?? 0,
          humedad: _humedad ?? 0,
          imagenUrl: imageUrl,
        );

        await supabase
            .from('destinos')
            .update(destinoActualizado.toMap())
            .eq('id', widget.destinoToEdit!.id)
            .eq('uid', user.id);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Destino actualizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Crear nuevo destino
        final destino = Destino.create(
          nombre: _nombreController.text.trim(),
          provincia: _provinciaController.text.trim(),
          descripcion: _descripcionController.text.trim(),
          latitud: _latitud!,
          longitud: _longitud!,
          clima: _clima ?? 'No disponible',
          temperatura: _temperatura ?? 0,
          humedad: _humedad ?? 0,
          imagenUrl: imageUrl,
          uid: user.id,
        );

        await supabase.from('destinos').insert(destino.toMap());

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Destino guardado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context, true);
    } catch (e) {
      print('❌ Error completo: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Destino' : 'Nuevo Destino'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _guardarDestino,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _loadingMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Si tarda mucho, revisa el GPS, los permisos y la conexión a internet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _obtenerUbicacionYClima,
                      icon: const Icon(Icons.gps_fixed),
                      label: Text(
                        _isEditing
                            ? 'Actualizar ubicación y clima'
                            : 'Obtener ubicación y clima',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_latitud != null) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '📍 Ubicación:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('Latitud: $_latitud'),
                              Text('Longitud: $_longitud'),
                              const SizedBox(height: 8),
                              Text(
                                '🌤️ Clima:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('Clima: ${_clima ?? "..."}'),
                              Text('Temperatura: ${_temperatura ?? "..."}°C'),
                              Text('Humedad: ${_humedad ?? "..."}%'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextFormField(
                      controller: _nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del destino',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.place),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa el nombre del destino';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _provinciaController,
                      decoration: const InputDecoration(
                        labelText: 'Provincia',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_city),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa la provincia';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descripcionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa una descripción';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    InkWell(
                      onTap: _seleccionarImagen,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _hasImage
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: kIsWeb && _imagenBytes != null
                                    ? Image.memory(
                                        _imagenBytes!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      )
                                    : _imagenFile != null
                                        ? Image.file(
                                            _imagenFile!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                          )
                                        : _imagenUrlExistente != null && _imagenUrlExistente!.isNotEmpty
                                            ? Image.network(
                                                _imagenUrlExistente!,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                              )
                                            : const SizedBox(),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    size: 50,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Toca para seleccionar una imagen',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                  Text(
                                    'Máximo 1 MB',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_hasImage) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _imagenNombre != null 
                                    ? 'Imagen seleccionada: $_imagenNombre' 
                                    : 'Imagen existente',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/geocoding_service.dart';
import '../services/weather_service.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../services/snackbar_service.dart';
import '../models/destino_model.dart';
import '../models/provincias_ec.dart';
import '../models/categorias_destino.dart';
import '../theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddDestinoScreen extends StatefulWidget {
  final Destino? destinoToEdit;
  final String? nombrePrellenado;
  final double? latPrellenado;
  final double? lngPrellenado;

  const AddDestinoScreen({
    super.key,
    this.destinoToEdit,
    this.nombrePrellenado,
    this.latPrellenado,
    this.lngPrellenado,
  });

  @override
  State<AddDestinoScreen> createState() => _AddDestinoScreenState();
}

class _AddDestinoScreenState extends State<AddDestinoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();

  File? _imagenFile;
  Uint8List? _imagenBytes;
  String? _imagenNombre;
  String? _imagenUrlExistente;
  bool _isLoading = false;
  bool _isEditing = false;

  String? _provinciaSeleccionada;
  String? _categoriaSeleccionada;
  double? _latitud;
  double? _longitud;
  String? _clima;
  double? _temperatura;
  int? _humedad;
  String? _ubicacionEncontrada;
  Timer? _debounceTimer;

  bool get _hasImage =>
      _imagenFile != null ||
      _imagenBytes != null ||
      (_imagenUrlExistente != null && _imagenUrlExistente!.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _isEditing = widget.destinoToEdit != null;

    if (_isEditing) {
      final destino = widget.destinoToEdit!;
      _nombreController.text = destino.nombre;
      _provinciaSeleccionada = destino.provincia;
      _categoriaSeleccionada = destino.categoria;
      _descripcionController.text = destino.descripcion;
      _latitud = destino.latitud;
      _longitud = destino.longitud;
      _clima = destino.clima;
      _temperatura = destino.temperatura;
      _humedad = destino.humedad;
      _imagenUrlExistente = destino.imagenUrl;
    } else if (widget.nombrePrellenado != null) {
      _nombreController.text = widget.nombrePrellenado!;
      _latitud = widget.latPrellenado;
      _longitud = widget.lngPrellenado;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nombreController.addListener(_dispararSiCompleto);
      if (!_isEditing && widget.latPrellenado != null) {
        _obtenerSoloClima();
      }
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _obtenerUbicacionYClima() async {
    final nombre = _nombreController.text.trim();
    final provincia = _provinciaSeleccionada ?? '';

    if (nombre.isEmpty || provincia.isEmpty) {
      SnackBarService.mostrarAdvertencia(
          context, 'Ingresa el nombre y la provincia primero');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final geocodingService = GeocodingService();
      final result = await geocodingService.geocode(nombre, provincia);
      _latitud = result['lat'] as double;
      _longitud = result['lon'] as double;
      _ubicacionEncontrada = result['nombre_ubicacion'] as String?;

      if (!mounted) return;

      final weatherService = WeatherService();
      final weatherData = await weatherService.getWeather(_latitud!, _longitud!);
      _clima = weatherData['clima'];
      _temperatura = weatherData['temperatura'];
      _humedad = weatherData['humedad'];

      if (!mounted) return;
      SnackBarService.mostrarExito(
          context, 'Ubicación encontrada: $_ubicacionEncontrada');
    } catch (e) {
      if (!mounted) return;
      SnackBarService.mostrarError(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _obtenerSoloClima() async {
    if (_latitud == null || _longitud == null) return;
    setState(() => _isLoading = true);
    try {
      final weatherService = WeatherService();
      final weatherData = await weatherService.getWeather(_latitud!, _longitud!);
      if (!mounted) return;
      setState(() {
        _clima = weatherData['clima'];
        _temperatura = weatherData['temperatura'];
        _humedad = weatherData['humedad'];
      });
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _autoObtenerUbicacionYClima() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      _obtenerUbicacionYClima();
    });
  }

  void _dispararSiCompleto() {
    final nombre = _nombreController.text.trim();
    if (nombre.isNotEmpty && _provinciaSeleccionada != null && _provinciaSeleccionada!.isNotEmpty) {
      _autoObtenerUbicacionYClima();
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
            SnackBarService.mostrarAdvertencia(
                context, 'La imagen debe ser menor a 1 MB');
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
            SnackBarService.mostrarAdvertencia(
                context, 'La imagen debe ser menor a 1 MB');
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
        SnackBarService.mostrarExito(context, 'Imagen seleccionada correctamente');
      }
    } catch (e) {
      if (mounted) {
        SnackBarService.mostrarError(context, e);
      }
    }
  }

  Future<void> _guardarDestino() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasImage) {
      SnackBarService.mostrarAdvertencia(context, 'Selecciona una imagen');
      return;
    }

    if (_latitud == null) {
      SnackBarService.mostrarAdvertencia(context, 'Obtén la ubicación primero');
      return;
    }

    if (_provinciaSeleccionada == null || _provinciaSeleccionada!.isEmpty) {
      SnackBarService.mostrarAdvertencia(context, 'Selecciona una provincia');
      return;
    }
    if (_categoriaSeleccionada == null || _categoriaSeleccionada!.isEmpty) {
      SnackBarService.mostrarAdvertencia(context, 'Selecciona una categoría');
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
        final destinoActualizado = widget.destinoToEdit!.copyWith(
          nombre: _nombreController.text.trim(),
          provincia: _provinciaSeleccionada ?? '',
          categoria: _categoriaSeleccionada ?? '',
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
        SnackBarService.mostrarExito(context, 'Destino actualizado exitosamente');
      } else {
        final destino = Destino.create(
          nombre: _nombreController.text.trim(),
          provincia: _provinciaSeleccionada ?? '',
          categoria: _categoriaSeleccionada ?? '',
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
        SnackBarService.mostrarExito(context, 'Destino guardado exitosamente');
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      SnackBarService.mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar destino' : 'Nuevo destino'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            color: AppColors.sol,
            onPressed: _isLoading ? null : _guardarDestino,
          ),
        ],
      ),
      body: _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen — primer elemento, ancla visual de la pantalla
            _buildImagePicker(),
            const SizedBox(height: 28),

            _sectionLabel('Información básica'),
            const SizedBox(height: 4),
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre del destino',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa el nombre del destino';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _provinciaSeleccionada ?? ''),
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) return provinciasEcuador;
                return provinciasEcuador.where((option) =>
                    option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
              },
              onSelected: (value) {
                setState(() => _provinciaSeleccionada = value);
                _dispararSiCompleto();
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onSubmitted) {
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Provincia',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _categoriaSeleccionada ?? ''),
              optionsBuilder: (textEditingValue) {
                final query = textEditingValue.text.toLowerCase();
                if (query.isEmpty) return categoriasKeys;
                return categoriasKeys.where((key) =>
                    (categoriaLabels[key] ?? key).toLowerCase().contains(query));
              },
              displayStringForOption: (key) => categoriaLabels[key] ?? key,
              onSelected: (value) {
                setState(() => _categoriaSeleccionada = value);
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onSubmitted) {
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _descripcionController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa una descripción';
                }
                return null;
              },
            ),

            const SizedBox(height: 28),
            _sectionLabel('Ubicación y clima'),
            const SizedBox(height: 10),
            if (_isLoading && _latitud == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sol),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Buscando ubicación...',
                      style: TextStyle(color: AppColors.musgo, fontSize: 13),
                    ),
                  ],
                ),
              ),

            if (_latitud != null) ...[
              const SizedBox(height: 14),
              _buildUbicacionCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppColors.musgoClaro,
      ),
    );
  }

  Widget _buildImagePicker() {
    return InkWell(
      onTap: _seleccionarImagen,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 190,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.lienzoAlterno,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.niebla),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_hasImage)
              kIsWeb && _imagenBytes != null
                  ? Image.memory(_imagenBytes!, fit: BoxFit.cover)
                  : _imagenFile != null
                      ? Image.file(_imagenFile!, fit: BoxFit.cover)
                      : (_imagenUrlExistente != null &&
                              _imagenUrlExistente!.isNotEmpty)
                          ? Image.network(_imagenUrlExistente!, fit: BoxFit.cover)
                          : const SizedBox()
            else
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: AppColors.solClaro,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_rounded,
                      color: AppColors.sol,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Toca para elegir una imagen',
                    style: TextStyle(
                      color: AppColors.tinta,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Máximo 1 MB',
                    style: TextStyle(color: AppColors.musgoClaro, fontSize: 12),
                  ),
                ],
              ),

            // Overlay inferior con confirmación, sobre la imagen ya elegida
            if (_hasImage)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        AppColors.tinta.withValues(alpha: 0.75),
                        AppColors.tinta.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _imagenNombre ?? 'Imagen actual',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUbicacionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.niebla),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_ubicacionEncontrada != null) ...[
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.exito, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _ubicacionEncontrada!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.exito,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              Expanded(
                child: _infoStat(
                  icon: Icons.explore_outlined,
                  label: 'Latitud',
                  value: _latitud?.toStringAsFixed(4) ?? '—',
                ),
              ),
              Container(width: 1, height: 34, color: AppColors.niebla),
              Expanded(
                child: _infoStat(
                  icon: Icons.explore_outlined,
                  label: 'Longitud',
                  value: _longitud?.toStringAsFixed(4) ?? '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _infoStat(
                  icon: Icons.wb_cloudy_outlined,
                  label: 'Clima',
                  value: _clima ?? '...',
                ),
              ),
              Container(width: 1, height: 34, color: AppColors.niebla),
              Expanded(
                child: _infoStat(
                  icon: Icons.thermostat_outlined,
                  label: 'Temperatura',
                  value: _temperatura != null ? '${_temperatura!.toStringAsFixed(0)}°C' : '...',
                  highlight: true,
                ),
              ),
              Container(width: 1, height: 34, color: AppColors.niebla),
              Expanded(
                child: _infoStat(
                  icon: Icons.water_drop_outlined,
                  label: 'Humedad',
                  value: _humedad != null ? '$_humedad%' : '...',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoStat({
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: highlight ? AppColors.sol : AppColors.musgo),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: highlight ? AppColors.sol : AppColors.tinta,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.musgoClaro),
        ),
      ],
    );
  }
}
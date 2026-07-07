import 'package:flutter/material.dart';
import '../models/visita_model.dart';
import '../services/visita_service.dart';

class VisitaProvider extends ChangeNotifier {
  final VisitaService _visitaService = VisitaService();
  
  List<Visita> _visitas = [];
  double _promedioCalificacion = 0.0;
  int _totalVisitas = 0;
  bool _isLoading = false;
  bool _userHasVisited = false;
  Visita? _userVisita;
  String? _error;

  List<Visita> get visitas => _visitas;
  double get promedioCalificacion => _promedioCalificacion;
  int get totalVisitas => _totalVisitas;
  bool get isLoading => _isLoading;
  bool get userHasVisited => _userHasVisited;
  Visita? get userVisita => _userVisita;
  String? get error => _error;

  // Cargar todas las visitas de un destino
  Future<void> loadVisitas(String destinoId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _visitas = await _visitaService.getVisitasByDestino(destinoId);
      _promedioCalificacion = await _visitaService.getPromedioCalificacion(destinoId);
      _totalVisitas = await _visitaService.countVisitas(destinoId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Verificar si el usuario ya visitó el destino
  Future<void> checkUserVisited(String destinoId, String uid) async {
    try {
      _userVisita = await _visitaService.getVisitaByUser(destinoId, uid);
      _userHasVisited = _userVisita != null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  // Crear una nueva visita
  Future<void> addVisita({
    required String destinoId,
    required String uid,
    required int calificacion,
    String? comentario,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newVisita = await _visitaService.createVisita(
        destinoId: destinoId,
        uid: uid,
        calificacion: calificacion,
        comentario: comentario,
      );
      
      _visitas.insert(0, newVisita);
      _userVisita = newVisita;
      _userHasVisited = true;
      
      // Recalcular promedio
      _promedioCalificacion = await _visitaService.getPromedioCalificacion(destinoId);
      _totalVisitas = await _visitaService.countVisitas(destinoId);
      
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Actualizar una visita existente
  Future<void> updateVisita({
    required int visitaId,
    required int calificacion,
    String? comentario,
    required String destinoId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedVisita = await _visitaService.updateVisita(
        visitaId: visitaId,
        calificacion: calificacion,
        comentario: comentario,
      );
      
      // Actualizar en la lista
      final index = _visitas.indexWhere((v) => v.id == visitaId);
      if (index != -1) {
        _visitas[index] = updatedVisita;
      }
      
      _userVisita = updatedVisita;
      
      // Recalcular promedio
      _promedioCalificacion = await _visitaService.getPromedioCalificacion(destinoId);
      
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Eliminar una visita
  Future<void> deleteVisita(int visitaId, String destinoId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _visitaService.deleteVisita(visitaId);
      
      _visitas.removeWhere((v) => v.id == visitaId);
      _userVisita = null;
      _userHasVisited = false;
      
      // Recalcular promedio
      _promedioCalificacion = await _visitaService.getPromedioCalificacion(destinoId);
      _totalVisitas = await _visitaService.countVisitas(destinoId);
      
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Limpiar datos
  void clear() {
    _visitas = [];
    _promedioCalificacion = 0.0;
    _totalVisitas = 0;
    _userHasVisited = false;
    _userVisita = null;
    notifyListeners();
  }
}
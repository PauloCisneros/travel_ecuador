import 'package:flutter/material.dart';
import '../models/destino_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DestinoProvider extends ChangeNotifier {
  List<Destino> _destinos = [];
  bool _isLoading = false;
  String? _error;

  List<Destino> get destinos => _destinos;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Cargar destinos del usuario
  Future<void> loadDestinos(String uid) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('destinos')
          .select()
          .order('created_at', ascending: false);

      _destinos = response.map((map) => Destino.fromMap(map)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Agregar destino
  Future<void> addDestino(Destino destino) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('destinos').insert(destino.toMap());
      _destinos.insert(0, destino);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Eliminar destino
  Future<void> deleteDestino(String id, String uid) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('destinos')
          .delete()
          .eq('id', id)
          .eq('uid', uid);

      _destinos.removeWhere((d) => d.id == id);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Limpiar destinos (al cerrar sesión)
  void clearDestinos() {
    _destinos = [];
    notifyListeners();
  }
}
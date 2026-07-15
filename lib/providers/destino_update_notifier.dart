import 'package:flutter/material.dart';

class DestinoUpdateNotifier extends ChangeNotifier {
  int _version = 0;
  int get version => _version;

  void notify() {
    _version++;
    notifyListeners();
  }
}

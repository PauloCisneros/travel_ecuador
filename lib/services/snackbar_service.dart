import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SnackBarService {
  SnackBarService._();

  static void mostrarExito(
    BuildContext context,
    String mensaje, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(context, mensaje, Colors.green, duration);
  }

  static void mostrarAdvertencia(
    BuildContext context,
    String mensaje, {
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(context, mensaje, Colors.orange, duration);
  }

  static void mostrarError(BuildContext context, dynamic error,
      {Duration duration = const Duration(seconds: 5)}) {
    _show(context, _mensajeAmigable(error), Colors.red, duration);
  }

  static void _show(
    BuildContext context,
    String mensaje,
    Color color,
    Duration duration,
  ) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static String _mensajeAmigable(dynamic error) {
    if (error == null) return 'Ha ocurrido un error inesperado.';

    final mensaje = error.toString().toLowerCase();

    // Errores de red / conexión
    if (error is SocketException ||
        error is HandshakeException ||
        mensaje.contains('socketexception') ||
        mensaje.contains('connection refused') ||
        mensaje.contains('no internet') ||
        mensaje.contains('network is unreachable') ||
        mensaje.contains('failed host lookup')) {
      return 'Error de conexión. Verifica tu acceso a internet.';
    }

    // Errores de autenticación (Supabase)
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid credentials')) {
        return 'Correo o contraseña incorrectos.';
      }
      if (msg.contains('email not confirmed')) {
        return 'Correo electrónico no confirmado. Revisa tu bandeja de entrada.';
      }
      if (msg.contains('user already registered')) {
        return 'Este correo ya está registrado.';
      }
      if (msg.contains('password') && msg.contains('characters')) {
        return 'La contraseña debe tener al menos 6 caracteres.';
      }
      if (msg.contains('rate limit')) {
        return 'Demasiados intentos. Espera un momento e intenta de nuevo.';
      }
      if (msg.contains('email') && msg.contains('invalid')) {
        return 'El formato del correo electrónico no es válido.';
      }
      return 'Error de autenticación. Verifica tus credenciales.';
    }

    // Errores de base de datos (Supabase Postgrest)
    if (error is PostgrestException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('duplicate') || msg.contains('unique constraint')) {
        return 'Este registro ya existe.';
      }
      if (msg.contains('foreign key') || msg.contains('not found')) {
        return 'El registro referenciado no existe.';
      }
      if (msg.contains('permission denied') || msg.contains('policy')) {
        return 'No tienes permiso para realizar esta acción.';
      }
      if (msg.contains('timeout') || msg.contains('could not connect')) {
        return 'El servidor no respondió a tiempo. Intenta de nuevo.';
      }
      return 'Error al acceder a la base de datos. Intenta de nuevo.';
    }

    // Errores de storage
    if (error is StorageException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('duplicate')) {
        return 'El archivo ya existe.';
      }
      if (msg.contains('not found') || msg.contains('does not exist')) {
        return 'El archivo no se encontró.';
      }
      if (msg.contains('size') || msg.contains('too large')) {
        return 'El archivo excede el tamaño permitido.';
      }
      return 'Error al subir o descargar el archivo. Intenta de nuevo.';
    }

    // Errores HTTP
    if (mensaje.contains('httpexception') ||
        mensaje.contains('http error') ||
        mensaje.contains('status code')) {
      if (mensaje.contains('404')) {
        return 'Recurso no encontrado.';
      }
      if (mensaje.contains('500') || mensaje.contains('502') || mensaje.contains('503')) {
        return 'Error en el servidor. Intenta más tarde.';
      }
      if (mensaje.contains('429')) {
        return 'Demasiadas solicitudes. Espera un momento.';
      }
      return 'Error de comunicación con el servidor.';
    }

    // Errores de formato/parseo
    if (error is FormatException) {
      return 'Error al procesar los datos. Formato inválido.';
    }

    // Errores de plugin (web)
    if (mensaje.contains('missingpluginexception') ||
        mensaje.contains('no implementation')) {
      return 'Esta funcionalidad no está disponible en tu navegador.';
    }

    // Errores de ubicación
    if (mensaje.contains('location') ||
        mensaje.contains('permission') && mensaje.contains('denied')) {
      return 'Permiso de ubicación denegado. Actívalo en la configuración.';
    }

    // Errores de imagen
    if (mensaje.contains('imagen') && mensaje.contains('pesar')) {
      return 'La imagen debe pesar menos de 1 MB.';
    }
    if (mensaje.contains('imagen')) {
      return 'Error al procesar la imagen. Intenta con otra.';
    }

    // Errores de cámara/galería
    if (mensaje.contains('camera') || mensaje.contains('gallery')) {
      return 'Error al acceder a la cámara o galería.';
    }

    // Errores de avatar / storage bucket
    if (mensaje.contains('(upload)')) {
      return 'Error al subir el avatar. Crea el bucket "avatars" en Supabase Dashboard > Storage.';
    }

    // Errores de base de datos en perfil
    if (mensaje.contains('(db)')) {
      return 'Error al guardar el avatar. Agrega la columna "avatar_url" a la tabla "users" en Supabase.';
    }

    // Errores de clima
    if (mensaje.contains('weather') || mensaje.contains('clima')) {
      return 'Error al obtener el clima. Intenta de nuevo.';
    }

    // Errores de mapas
    if (mensaje.contains('maps') || mensaje.contains('google maps') || mensaje.contains('waze')) {
      return 'Error al abrir la aplicación de mapas.';
    }

    // Timeout
    if (mensaje.contains('timeout')) {
      return 'La operación tardó demasiado. Intenta de nuevo.';
    }

    return 'Ha ocurrido un error. Intenta de nuevo.';
  }
}

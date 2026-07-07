import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final SupabaseClient _client = Supabase.instance.client;
  static const String bucketName = 'destinos';

  // Para MÓVIL (File)
  Future<String> uploadImage(File imageFile, String userId) async {
    final bytes = await imageFile.readAsBytes();
    if (bytes.length > 1048576) {
      throw Exception('La imagen debe pesar menos de 1 MB');
    }

    final extension = path.extension(imageFile.path);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$userId$extension';

    // Intentar subir directamente
    try {
      await _client.storage.from(bucketName).upload(
        fileName,
        imageFile,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: false,
        ),
      );
    } catch (e) {
      // Si falla, crear el bucket y reintentar
      try {
        await _client.storage.createBucket(
          bucketName,
          const BucketOptions(public: true),
        );
        // Reintentar la subida
        await _client.storage.from(bucketName).upload(
          fileName,
          imageFile,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
          ),
        );
      } catch (e2) {
        throw Exception('Error al subir la imagen: $e2');
      }
    }

    return _client.storage.from(bucketName).getPublicUrl(fileName);
  }

  // Para WEB (bytes)
  Future<String> uploadImageWeb(Uint8List bytes, String userId) async {
    if (bytes.length > 1048576) {
      throw Exception('La imagen debe pesar menos de 1 MB');
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$userId.jpg';

    try {
      await _client.storage.from(bucketName).uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: false,
          contentType: 'image/jpeg',
        ),
      );
    } catch (e) {
      // Si falla, crear el bucket y reintentar
      try {
        await _client.storage.createBucket(
          bucketName,
          const BucketOptions(public: true),
        );
        // Reintentar la subida
        await _client.storage.from(bucketName).uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: 'image/jpeg',
          ),
        );
      } catch (e2) {
        throw Exception('Error al subir la imagen (web): $e2');
      }
    }

    return _client.storage.from(bucketName).getPublicUrl(fileName);
  }

  // Método para eliminar imagen
  Future<void> deleteImage(String imageUrl) async {
    try {
      final fileName = imageUrl.split('/').last;
      await _client.storage.from(bucketName).remove([fileName]);
    } catch (e) {
      throw Exception('Error al eliminar la imagen: $e');
    }
  }
}
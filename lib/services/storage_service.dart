import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final SupabaseClient _client = Supabase.instance.client;
  static const String bucketName = 'destinos';
  static const String avatarsBucket = 'avatars';

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

  // ============================================================
  //  AVATAR — bucket 'avatars', archivo fijo por uid, upsert true
  // ============================================================

  Future<String> uploadAvatar(File imageFile, String uid) async {
    final bytes = await imageFile.readAsBytes();
    if (bytes.length > 2097152) {
      throw Exception('La imagen debe pesar menos de 2 MB');
    }
    final fileName = '$uid.jpg';

    Future<void> doUpload() => _client.storage.from(avatarsBucket).upload(
          fileName,
          imageFile,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    try {
      await doUpload();
    } catch (e) {
      try {
        await _client.storage.createBucket(
          avatarsBucket,
          const BucketOptions(public: true),
        );
        await doUpload();
      } catch (e2) {
        throw Exception('Error al subir el avatar: $e2');
      }
    }

    final baseUrl = _client.storage.from(avatarsBucket).getPublicUrl(fileName);
    return '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> uploadAvatarWeb(Uint8List bytes, String uid) async {
    if (bytes.length > 2097152) {
      throw Exception('La imagen debe pesar menos de 2 MB');
    }
    final fileName = '$uid.jpg';

    Future<void> doUpload() => _client.storage.from(avatarsBucket).uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    try {
      await doUpload();
    } catch (e) {
      try {
        await _client.storage.createBucket(
          avatarsBucket,
          const BucketOptions(public: true),
        );
        await doUpload();
      } catch (e2) {
        throw Exception('Error al subir el avatar (web): $e2');
      }
    }

    final baseUrl = _client.storage.from(avatarsBucket).getPublicUrl(fileName);
    return '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';
  }
}
import 'dart:io';
import 'dart:typed_data';

abstract class ProfileRepository {
  Future<Map<String, dynamic>> getProfile();

  Future<void> updateProfile(
    Map<String, dynamic> data, {
    File? imageFile,
    Uint8List? imageBytes,
    String? uploadType, // 'avatar' or 'logo'
  });
}

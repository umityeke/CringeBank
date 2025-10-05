import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// Service for handling avatar image uploads to Firebase Storage
class AvatarUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final ImageCropper _cropper = ImageCropper();

  void _log(String message) {
    debugPrint('AvatarUploadService: $message');
  }

  void _logStack(String message, StackTrace stackTrace) {
    debugPrint('AvatarUploadService: $message');
    debugPrintStack(label: 'AvatarUploadService stack', stackTrace: stackTrace);
  }

  /// Pick an image from gallery
  Future<XFile?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      return image;
    } catch (e, stackTrace) {
      _logStack(' AVATAR PICKER ERROR: $e', stackTrace);
      return null;
    }
  }

  /// Pick an image from camera
  Future<XFile?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      return image;
    } catch (e, stackTrace) {
      _logStack(' AVATAR CAMERA ERROR: $e', stackTrace);
      return null;
    }
  }

  /// Launch a cropping UI for the provided image path
  Future<CroppedFile?> cropImage({
    required String sourcePath,
    required BuildContext context,
  }) async {
    try {
      return await _cropper.cropImage(
        sourcePath: sourcePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Profil Fotoğrafını Kırp',
            toolbarWidgetColor: Colors.white,
            toolbarColor: const Color(0xFF0F172A),
            activeControlsWidgetColor: Colors.orange,
            hideBottomControls: false,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Profil Fotoğrafını Kırp',
            aspectRatioLockEnabled: true,
            rotateButtonsHidden: true,
            resetAspectRatioEnabled: false,
          ),
          WebUiSettings(
            context: context,
            enableZoom: true,
            enableResize: true,
            enforceBoundary: true,
            mouseWheelZoom: true,
          ),
        ],
      );
    } catch (e, stackTrace) {
      _logStack(' AVATAR CROPPER ERROR: $e', stackTrace);
      return null;
    }
  }

  /// Upload avatar to Firebase Storage and return download URL
  Future<String?> uploadAvatar({
    required String userId,
    required XFile imageFile,
  }) async {
    try {
      _log('ğ“ AVATAR UPLOAD: Starting upload for user $userId');
      _log('?Ÿ“₺ AVATAR FILE PATH: ${imageFile.path}');

      // Read file as bytes (works on all platforms)
      final bytes = await imageFile.readAsBytes();
      _log('ğ“ AVATAR FILE SIZE: ${bytes.length} bytes');

      return uploadAvatarBytes(userId: userId, bytes: bytes);
    } catch (e, stackTrace) {
      _logStack(' AVATAR UPLOAD ERROR: $e', stackTrace);
      return null;
    }
  }

  /// Upload avatar bytes directly
  Future<String?> uploadAvatarBytes({
    required String userId,
    required Uint8List bytes,
  }) async {
    try {
      _log('ğ“ AVATAR UPLOAD BYTES: user=$userId size=${bytes.length}');

      // Create unique filename with timestamp
      final String fileName =
          'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath =
          'media/users/$userId/$fileName'; // Match storage rules path

      // Create storage reference
      final Reference ref = _storage.ref().child(filePath);

      // Upload using bytes (works on all platforms)
      final UploadTask uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;

      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      _log('… AVATAR UPLOAD SUCCESS: $downloadUrl');
      return downloadUrl;
    } catch (e, stackTrace) {
      _logStack(' AVATAR UPLOAD BYTES ERROR: $e', stackTrace);
      return null;
    }
  }

  /// Delete old avatar from storage (cleanup)
  Future<void> deleteOldAvatar(String avatarUrl) async {
    try {
      _log('?Ÿ—‘️ DELETE CHECK: avatarUrl="$avatarUrl"');

      if (avatarUrl.isEmpty) {
        _log('⏭️ SKIP DELETE: Avatar URL is empty');
        return;
      }

      if (!avatarUrl.contains('firebase')) {
        _log('⏭️ SKIP DELETE: Not a Firebase Storage URL');
        return; // Not a Firebase Storage URL
      }

      _log('?Ÿ—‘️ DELETING: Old avatar at $avatarUrl');
      // Extract path from URL and delete
      final ref = _storage.refFromURL(avatarUrl);
      await ref.delete();
      _log('… AVATAR DELETE: Deleted old avatar successfully');
    } catch (e, stackTrace) {
      _logStack(
        'š️ AVATAR DELETE WARNING: Could not delete old avatar - $e',
        stackTrace,
      );
      // Non-critical error, don't throw
    }
  }

  /// Complete avatar update flow: pick, upload, return URL
  Future<String?> selectAndUploadAvatar({
    required String userId,
    bool useCamera = false,
    String? oldAvatarUrl,
  }) async {
    try {
      // Pick image
      final XFile? imageFile = useCamera
          ? await pickImageFromCamera()
          : await pickImageFromGallery();

      if (imageFile == null) {
        _log('„️ AVATAR SELECTION: User cancelled');
        return null;
      }

      // Upload to Firebase Storage
      final String? downloadUrl = await uploadAvatar(
        userId: userId,
        imageFile: imageFile,
      );

      if (downloadUrl == null) {
        _log(' AVATAR FLOW: Upload failed');
        return null;
      }

      // Delete old avatar if exists
      if (oldAvatarUrl != null && oldAvatarUrl.isNotEmpty) {
        await deleteOldAvatar(oldAvatarUrl);
      }

      return downloadUrl;
    } catch (e, stackTrace) {
      _logStack(' AVATAR FLOW ERROR: $e', stackTrace);
      return null;
    }
  }
}

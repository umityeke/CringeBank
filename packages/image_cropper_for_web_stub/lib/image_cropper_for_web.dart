import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:image_cropper_platform_interface/image_cropper_platform_interface.dart';

/// A lightweight stub implementation to keep Flutter web builds working
/// until the upstream package regains compatibility.
class ImageCropperForWeb extends ImageCropperPlatform {
  /// Registers this class as the default instance of [ImageCropperPlatform].
  static void registerWith(Registrar registrar) {
    ImageCropperPlatform.instance = ImageCropperForWeb();
  }

  @override
  @override
  Future<CroppedFile?> cropImage({
    CropAspectRatio? aspectRatio,
    List<CropAspectRatioPreset>? aspectRatioPresets,
    ImageCompressFormat compressFormat = ImageCompressFormat.jpg,
    int compressQuality = 90,
    CropStyle cropStyle = CropStyle.rectangle,
    int? maxHeight,
    int? maxWidth,
    required String sourcePath,
    List<PlatformUiSettings>? uiSettings,
  }) async {
    debugPrint(
      '[ImageCropperForWeb] Crop not supported on web; returning null for "$sourcePath".',
    );
    return null;
  }
}

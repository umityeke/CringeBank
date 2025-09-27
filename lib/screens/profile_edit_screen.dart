import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../widgets/animated_bubble_background.dart';

class ProfileEditScreen extends StatefulWidget {
  final User user;
  
  const ProfileEditScreen({super.key, required this.user});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _bioController;
  late TextEditingController _emailController;
  
  String? _selectedAvatarPath;
  String? _selectedAvatarBase64;
  bool _isLoading = false;

  // Resmi otomatik olarak boyutlandır ve sıkıştır
  Future<Uint8List> _resizeAndCompressImage(Uint8List bytes) async {
    try {
      // Resmi decode et
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return bytes;

      // Maksimum boyutu belirle (genişlik veya yükseklik)
      const int maxSize = 400;
      
      // Resmi boyutlandır (aspect ratio korunarak)
      img.Image resizedImage;
      if (image.width > image.height) {
        resizedImage = img.copyResize(image, width: maxSize);
      } else {
        resizedImage = img.copyResize(image, height: maxSize);
      }

      // JPEG olarak encode et (yüksek sıkıştırma)
      List<int> compressedBytes = img.encodeJpg(resizedImage, quality: 70);
      
      // Hala büyükse kaliteyi daha da düşür
      while (compressedBytes.length > 80000 && compressedBytes.length < bytes.length) {
        // Kaliteyi %10 düşür
        int newQuality = ((compressedBytes.length / 80000) * 70).round();
        if (newQuality < 20) newQuality = 20;
        compressedBytes = img.encodeJpg(resizedImage, quality: newQuality);
        
        // Sonsuz döngüyü önle
        if (newQuality <= 20) break;
      }

      return Uint8List.fromList(compressedBytes);
    } catch (e) {
        debugPrint('Resim boyutlandırma hatası: $e');
      return bytes;
    }
  }

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user.fullName);
    _bioController = TextEditingController(text: widget.user.bio);
    _emailController = TextEditingController(text: widget.user.email);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // Web'de bytes almak için gerekli
      );

      if (result != null && result.files.single.bytes != null) {
        final originalBytes = result.files.single.bytes!;
        final originalSize = (originalBytes.length / 1024).round();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resim işleniyor... (Orijinal boyut: ${originalSize}KB)'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );

        // Resmi otomatik olarak boyutlandır ve sıkıştır
        final compressedBytes = await _resizeAndCompressImage(originalBytes);

        if (!mounted) return;
        final compressedSize = (compressedBytes.length / 1024).round();

        // Base64 encode et
        final base64String = base64Encode(compressedBytes);

        if (!mounted) return;
        setState(() {
          _selectedAvatarPath = result.files.single.name;
          _selectedAvatarBase64 = 'data:image/jpeg;base64,$base64String';
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Avatar hazırlandı! ${originalSize}KB → ${compressedSize}KB'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Avatar seçim hatası: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avatar seçilirken hata oluştu'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Güncellenmiş kullanıcı bilgileri
      final updatedUser = User(
        id: widget.user.id,
        username: widget.user.username, // Username değişmez
        email: _emailController.text.trim(),
        fullName: _fullNameController.text.trim(),
        bio: _bioController.text.trim(),
        avatar: _selectedAvatarBase64 ?? widget.user.avatar,
        krepScore: widget.user.krepScore,
        krepLevel: widget.user.krepLevel,
        followersCount: widget.user.followersCount,
        followingCount: widget.user.followingCount,
        entriesCount: widget.user.entriesCount,
        joinDate: widget.user.joinDate,
        lastActive: DateTime.now(),
        rozetler: widget.user.rozetler,
        isPremium: widget.user.isPremium,
        isVerified: widget.user.isVerified,
      );

      // UserService ile güncelle
      final success = await UserService.instance.updateProfile(updatedUser);

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil başarıyla güncellendi!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, updatedUser);
      } else {
        throw Exception('Profil güncellenemedi');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Profil Düzenle',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.orange,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'Kaydet',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: AnimatedBubbleBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Avatar Bölümü
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Avatar
                        GestureDetector(
                          onTap: _pickAvatar,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.orange.withOpacity(0.2),
                              border: Border.all(
                                color: Colors.orange,
                                width: 3,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: _selectedAvatarBase64 != null
                                      ? ClipOval(
                                          child: Image.memory(
                                            base64Decode(_selectedAvatarBase64!.split(',')[1]),
                                            width: 114,
                                            height: 114,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : widget.user.avatar.startsWith('data:image')
                                          ? ClipOval(
                                              child: Image.memory(
                                                base64Decode(widget.user.avatar.split(',')[1]),
                                                width: 114,
                                                height: 114,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.person,
                                              color: Colors.orange,
                                              size: 60,
                                            ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Colors.orange,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Avatar Değiştir',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_selectedAvatarPath != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Seçilen: $_selectedAvatarPath',
                              style: TextStyle(
                                color: Colors.orange.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form Alanları
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Profil Bilgileri',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Tam İsim
                        TextFormField(
                          controller: _fullNameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Tam İsim',
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.orange,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Tam isim boş olamaz';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // E-posta
                        TextFormField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'E-posta',
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.orange,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'E-posta boş olamaz';
                            }
                            if (!value.contains('@')) {
                              return 'Geçerli bir e-posta adresi girin';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Bio
                        TextFormField(
                          controller: _bioController,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 4,
                          maxLength: 150,
                          decoration: InputDecoration(
                            labelText: 'Hakkında',
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(bottom: 60),
                              child: Icon(
                                Icons.info_outline,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                            hintText: 'Kendiniz hakkında birkaç kelime yazın...',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.orange,
                                width: 2,
                              ),
                            ),
                            counterStyle: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Kaydet Butonu (Büyük)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveProfile,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _isLoading ? 'Kaydediliyor...' : 'Profili Kaydet',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
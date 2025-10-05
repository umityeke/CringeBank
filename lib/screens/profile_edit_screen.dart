import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;

import '../models/user_model.dart';
import '../services/avatar_upload_service.dart';
import '../services/email_otp_service.dart';
import '../services/phone_otp_service.dart';
import '../services/user_service.dart';
import '../widgets/animated_bubble_background.dart';

const int _displayNameminLength = 2;
const int _displayNameMaxLength = 60;
const int _bioMaxLength = 160;
const int _genderOtherMaxLength = 30;
const int _minAgeYears = 13;
const List<String> _tabTitles = <String>[
  'Temel',
  'İletişim',
  'Demografi',
  'Eğitim',
  'Gizlilik',
];
const List<String> _visibilityOptions = <String>[
  'public',
  'followers',
  'private',
];
const Map<String, String> _visibilityLabels = <String, String>{
  'public': 'Herkese açık',
  'followers': 'Sadece takipçiler',
  'private': 'Gizli',
};
const Map<String, IconData> _visibilityIcons = <String, IconData>{
  'public': Icons.public,
  'followers': Icons.group,
  'private': Icons.lock,
};
const Map<String, String> _educationLabels = <String, String>{
  'primary': 'İlkokul',
  'middle': 'Ortaokul',
  'high': 'Lise',
  'higher': 'Üniversite ve üzeri',
};
const Map<String, String> _genderLabels = <String, String>{
  'female': 'Kadın',
  'male': 'Erkek',
  'prefer_not': 'Belirtmek istemiyorum',
  'other': 'Diğer',
};

final HtmlEscape _htmlEscape = const HtmlEscape(HtmlEscapeMode.element);
final RegExp _linkRegExp = RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);
final RegExp _emojiRegExp = RegExp(
  r'[\u{1F300}-\u{1F6FF}\u{1F900}-\u{1FAFF}\u{2600}-\u{26FF}]',
  unicode: true,
);

class ProfileEditScreen extends StatefulWidget {
  final User user;

  const ProfileEditScreen({super.key, required this.user});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final AvatarUploadService _avatarUploadService = AvatarUploadService();

  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  late final TextEditingController _genderOtherController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  final FocusNode _genderOtherFocus = FocusNode();

  late User _user;
  late Map<String, dynamic> _initialSnapshot;

  Uint8List? _avatarPreviewBytes;
  Uint8List? _pendingAvatarBytes;
  bool _avatarProcessing = false;
  bool _avatarCleared = false;
  int? _avatarOriginalSize;
  int? _avatarCompressedSize;
  int? _avatarQuality;

  String _gender = 'prefer_not';
  DateTime? _birthDate;
  String _educationLevel = 'higher';
  Map<String, String> _visibility = <String, String>{
    'phoneNumber': 'private',
    'email': 'private',
  };
  bool _showActivityStatus = true;
  bool _allowTagging = true;
  bool _allowMessagesFromNonFollowers = false;

  bool _isDirty = false;
  bool _saving = false;
  String? _birthDateError;
  late final DateFormat _dateFormat;
  BuildContext? _loadingDialogContext;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _displayNameController = TextEditingController(text: _user.displayName);
    _bioController = TextEditingController(text: _user.bio);
    _genderOtherController = TextEditingController(text: _user.genderOther);
    _emailController = TextEditingController(text: _user.email);
    _phoneController = TextEditingController(text: _user.phoneNumber ?? '');

    _gender = _normalizeGender(_user.gender);
    _birthDate = _user.birthDate;
    _educationLevel = _normalizeEducation(_user.educationLevel);
    _visibility = <String, String>{
      'phoneNumber': _normalizeVisibility(_user.visibility.phoneNumber),
      'email': _normalizeVisibility(_user.visibility.email),
    };
    _showActivityStatus = _user.preferences.showActivityStatus;
    _allowTagging = _user.preferences.allowTagging;
    _allowMessagesFromNonFollowers =
        _user.preferences.allowMessagesFromNonFollowers;

    _tabController = TabController(length: _tabTitles.length, vsync: this);
    _attachControllerListeners();

    unawaited(initializeDateFormatting('tr_TR'));
    _dateFormat = DateFormat.yMMMMd('tr_TR');

    _avatarPreviewBytes = _decodeAvatarBytes(_user.avatar);
    _pendingAvatarBytes = null;
    _avatarCleared = _isAvatarEmpty(_user.avatar);

    _initialSnapshot = _captureSnapshot();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _genderOtherController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _tabController.dispose();
    _genderOtherFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProfileEditScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user) {
      _user = widget.user;
      _displayNameController.text = _user.displayName;
      _bioController.text = _user.bio;
      _genderOtherController.text = _user.genderOther;
      _emailController.text = _user.email;
      _phoneController.text = _user.phoneNumber ?? '';

      _gender = _normalizeGender(_user.gender);
      _birthDate = _user.birthDate;
      _educationLevel = _normalizeEducation(_user.educationLevel);
      _visibility = <String, String>{
        'phoneNumber': _normalizeVisibility(_user.visibility.phoneNumber),
        'email': _normalizeVisibility(_user.visibility.email),
      };
      _showActivityStatus = _user.preferences.showActivityStatus;
      _allowTagging = _user.preferences.allowTagging;
      _allowMessagesFromNonFollowers =
          _user.preferences.allowMessagesFromNonFollowers;

      _avatarPreviewBytes = _decodeAvatarBytes(_user.avatar);
      _pendingAvatarBytes = null;
      _avatarCleared = _isAvatarEmpty(_user.avatar);

      _initialSnapshot = _captureSnapshot();
      _markDirty();
    }
  }

  void _attachControllerListeners() {
    _displayNameController.addListener(_onFormChanged);
    _bioController.addListener(_onFormChanged);
    _genderOtherController.addListener(_onFormChanged);
  }

  Uint8List? _decodeAvatarBytes(String avatar) {
    if (!avatar.startsWith('data:image')) {
      return null;
    }

    final int commaIndex = avatar.indexOf(',');
    if (commaIndex == -1 || commaIndex >= avatar.length - 1) {
      return null;
    }

    final String base64Segment = avatar.substring(commaIndex + 1).trim();
    if (base64Segment.isEmpty) {
      return null;
    }

    try {
      return base64Decode(base64Segment);
    } catch (error, stackTrace) {
      debugPrint('Avatar decode failed: $error\n$stackTrace');
      return null;
    }
  }

  bool _isAvatarEmpty(String avatar) {
    final trimmed = avatar.trim();
    if (trimmed.isEmpty) return true;
    if (trimmed == '👤') return true;
    return false;
  }

  Future<_AvatarProcessingResult?> _prepareAvatarData(
    Uint8List rawBytes,
  ) async {
    try {
      final img.Image? decodedImage = img.decodeImage(rawBytes);
      if (decodedImage == null) {
        debugPrint('Avatar decode returned null image');
        return null;
      }

      final img.Image normalized = img.bakeOrientation(decodedImage);
      const int maxDimension = 256;
      final img.Image resized = img.copyResize(
        normalized,
        width: normalized.width >= normalized.height ? maxDimension : null,
        height: normalized.height > normalized.width ? maxDimension : null,
        interpolation: img.Interpolation.average,
      );

      const List<int> qualitySteps = <int>[70, 60, 50, 40];
      Uint8List? bestBytes;
      int selectedQuality = qualitySteps.first;

      for (final int quality in qualitySteps) {
        final Uint8List candidate = Uint8List.fromList(
          img.encodeJpg(resized, quality: quality),
        );
        bestBytes = candidate;
        selectedQuality = quality;
        if (candidate.lengthInBytes <= 60 * 1024) {
          break;
        }
      }

      if (bestBytes == null) {
        return null;
      }

      return _AvatarProcessingResult(
        bytes: bestBytes,
        originalSize: rawBytes.length,
        finalSize: bestBytes.length,
        quality: selectedQuality,
      );
    } catch (error, stackTrace) {
      debugPrint('Avatar processing failed: $error\n$stackTrace');
      return null;
    }
  }

  void _onFormChanged() {
    if (!_saving) {
      _markDirty();
    }
  }

  Map<String, dynamic> _captureSnapshot() {
    return <String, dynamic>{
      'avatarState': _avatarCleared
          ? 'cleared'
          : (_pendingAvatarBytes != null ? 'pending' : _user.avatar),
      'displayName': _collapseSpaces(_displayNameController.text),
      'bio': _bioController.text.trim(),
      'gender': _gender,
      'genderOther': _gender == 'other'
          ? _genderOtherController.text.trim()
          : '',
      'birthDate': _birthDate?.toIso8601String(),
      'educationLevel': _educationLevel,
      'visibility': Map<String, String>.from(_visibility),
      'showActivityStatus': _showActivityStatus,
      'allowTagging': _allowTagging,
      'allowMessagesFromNonFollowers': _allowMessagesFromNonFollowers,
    };
  }

  void _markDirty() {
    final Map<String, dynamic> current = _captureSnapshot();
    final bool changed = !_shallowMapEquals(_initialSnapshot, current);
    if (changed != _isDirty) {
      setState(() {
        _isDirty = changed;
      });
    }
  }

  void _resetDirtyTracking() {
    _initialSnapshot = _captureSnapshot();
    _markDirty();
  }

  Future<bool> _onWillPop() async {
    if (!_isDirty || _saving) {
      return true;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Değişiklikler kaydedilmedi'),
        content: const Text(
          'Formdaki değişiklikleri kaydetmeden çıkmak istediğine emin misin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Evet, çık'),
          ),
        ],
      ),
    );

    return confirm ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) {
          return;
        }

        final navigator = Navigator.of(context);
        final shouldPop = await _onWillPop();
        if (!mounted) {
          return;
        }

        if (shouldPop) {
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Row(
            children: [
              const Text(
                'Profil Düzenle',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(width: 12),
              if (_isDirty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.4)),
                  ),
                  child: const Text(
                    'Kaydedilmedi',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
            ],
          ),
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              )
            else
              TextButton(
                onPressed: _handleSavePressed,
                child: const Text(
                  'Kaydet',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: _tabTitles.map((title) => Tab(text: title)).toList(),
            indicatorColor: Colors.orange,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.white54,
          ),
        ),
        body: AnimatedBubbleBackground(
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF121B2E), Color(0xFF090C14)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBasicsTab(),
                      _buildContactTab(),
                      _buildDemographicsTab(),
                      _buildEducationTab(),
                      _buildPrivacyTab(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicsTab() {
    final List<String> links = _extractLinks(_bioController.text);
    final List<String> emojis = _extractEmojis(_bioController.text);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatarSection(),
          const SizedBox(height: 32),
          _sectionHeader(
            title: 'Görünen İsim',
            subtitle:
                'Profilinde gözükecek adın. Boşlukları azaltır ve 2-60 karakter arasında olmalı.',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _displayNameController,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              label: 'Görünen İsim',
              hint: 'Örn. Ümit Kara',
            ),
            maxLength: _displayNameMaxLength,
            validator: _validateDisplayName,
            onEditingComplete: _normalizeDisplayNameInput,
            onTapOutside: (_) => _normalizeDisplayNameInput(),
            inputFormatters: [
              LengthLimitingTextInputFormatter(_displayNameMaxLength),
            ],
          ),
          const SizedBox(height: 28),
          _sectionHeader(
            title: 'Biyografi',
            subtitle:
                '160 karakterlik kısa bir tanım. Linkler otomatik algılanır, HTML temizlenir.',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _bioController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              label: 'Biyografi',
              hint: 'Örn. "Mobil geliştirici • Flutter • Firebase"',
            ),
            minLines: 4,
            maxLines: 6,
            maxLength: _bioMaxLength,
            validator: _validateBio,
          ),
          const SizedBox(height: 16),
          if (_bioController.text.trim().isNotEmpty)
            _buildBioPreview(links: links, emojis: emojis),
        ],
      ),
    );
  }

  Widget _buildContactTab() {
    final String email = _emailController.text.trim();
    final String phone = _phoneController.text.trim();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            title: 'İletişim Bilgileri',
            subtitle:
                'Telefon ve e-posta doğrulama sonrasında güncellenir. Doğrudan düzenlenemez.',
          ),
          const SizedBox(height: 16),
          _contactCard(
            icon: Icons.mail_outline,
            label: 'E-posta',
            value: email.isNotEmpty ? email : 'Henüz doğrulanmamış',
            actionLabel: email.isNotEmpty ? 'Güncelle' : 'Ekle',
            onPressed: _saving ? null : _handleEmailVerification,
            statusChip: email.isNotEmpty
                ? const _StatusChip(label: 'Doğrulandı', color: Colors.green)
                : const _StatusChip(label: 'Eksik', color: Colors.orange),
          ),
          const SizedBox(height: 16),
          _contactCard(
            icon: Icons.phone_iphone,
            label: 'Telefon',
            value: phone.isNotEmpty ? phone : 'Henüz doğrulanmamış',
            actionLabel: phone.isNotEmpty ? 'Güncelle' : 'Ekle',
            onPressed: _saving ? null : _handlePhoneVerification,
            statusChip: phone.isNotEmpty
                ? const _StatusChip(label: 'Doğrulandı', color: Colors.green)
                : const _StatusChip(label: 'Eksik', color: Colors.orange),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Telefon ve e-posta doğrulaması, OTP akışıyla yapılır ve Firebase Auth ile senkronize edilir.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    final double previewSize = 112;
    final bool hasPendingAvatar = _pendingAvatarBytes != null;
    final bool hasStoredAvatar = !_isAvatarEmpty(_user.avatar);
    final bool hasCustomAvatar =
        hasPendingAvatar || (hasStoredAvatar && !_avatarCleared);
    final bool canClearAvatar = !_avatarCleared && hasCustomAvatar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Profil Fotoğrafı',
          subtitle:
              'Kare bir görsel seç, gerekirse kırp. Uygulama otomatik olarak 256px’e düşürüp sıkıştırır.',
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: previewSize,
                  height: previewSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.35),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: previewSize - 12,
                  height: previewSize - 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 2.2,
                    ),
                  ),
                  child: ClipOval(child: _buildAvatarPreview(previewSize - 20)),
                ),
                Positioned(
                  bottom: 4,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _avatarProcessing
                            ? null
                            : () => _handleAvatarSelection(useCamera: false),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galeriden Seç'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8A50),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _avatarProcessing
                            ? null
                            : () => _handleAvatarSelection(useCamera: true),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Kameradan Çek'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                        ),
                      ),
                      if (canClearAvatar)
                        TextButton.icon(
                          onPressed: _avatarProcessing
                              ? null
                              : _clearSelectedAvatar,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Kaldır'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                        ),
                    ],
                  ),
                  if (_avatarProcessing)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Fotoğraf sıkıştırılıyor...',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!_avatarProcessing &&
                      _avatarOriginalSize != null &&
                      _avatarCompressedSize != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Sıkıştırma: '
                        '${(_avatarOriginalSize! / 1024).toStringAsFixed(1)}KB → '
                        '${(_avatarCompressedSize! / 1024).toStringAsFixed(1)}KB '
                        '(kalite %${_avatarQuality ?? 0})',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Fotoğraf otomatik olarak en fazla 256px boyutuna küçültülür '
                      've %40-70 kalite aralığında sıkıştırılır. Böylece profilin '
                      'hızlı yüklenir ve veri tasarrufu sağlanır.',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ),
                  if (hasCustomAvatar && !_avatarProcessing)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Yeni görünümünü kaydetmek için "Kaydet" butonuna basmayı unutma.',
                        style: TextStyle(
                          color: Colors.orange.shade200,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatarPreview(double size) {
    if (_avatarProcessing) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF2C3350), Color(0xFF1F2538)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }

    if (_avatarPreviewBytes != null && !_avatarCleared) {
      return Image.memory(
        _avatarPreviewBytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }

    if (_avatarCleared) {
      return _buildAvatarFallback(size);
    }

    final String trimmedAvatar = _user.avatar.trim();

    if (trimmedAvatar.startsWith('http')) {
      return Image.network(
        trimmedAvatar,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildAvatarFallback(size),
      );
    }

    if (trimmedAvatar.startsWith('data:image')) {
      final Uint8List? decoded =
          _avatarPreviewBytes ?? _decodeAvatarBytes(trimmedAvatar);
      if (decoded != null) {
        return Image.memory(
          decoded,
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      }
    }

    return _buildAvatarFallback(size);
  }

  Widget _buildAvatarFallback(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF2C3350), Color(0xFF1F2538)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          _avatarInitial(),
          style: const TextStyle(
            fontSize: 32,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _handleAvatarSelection({required bool useCamera}) async {
    if (_avatarProcessing) {
      return;
    }

    setState(() {
      _avatarProcessing = true;
      _avatarOriginalSize = null;
      _avatarCompressedSize = null;
      _avatarQuality = null;
    });

    final imageFile = useCamera
        ? await _avatarUploadService.pickImageFromCamera()
        : await _avatarUploadService.pickImageFromGallery();

    if (!mounted) {
      return;
    }

    if (imageFile == null) {
      setState(() {
        _avatarProcessing = false;
      });
      return;
    }

    CroppedFile? croppedFile;
    try {
      croppedFile = await _avatarUploadService.cropImage(
        sourcePath: imageFile.path,
        context: context,
      );
    } catch (_) {
      // Errors already logged within the service
    }

    if (!mounted) {
      return;
    }

    Uint8List? rawBytes;

    if (croppedFile != null) {
      rawBytes = await croppedFile.readAsBytes();
    } else if (kIsWeb) {
      rawBytes = await imageFile.readAsBytes();
      if (mounted) {
        _showSnack(
          'Web sürümünde kırpma henüz desteklenmiyor, görsel kırpılmadan kullanılacak.',
        );
      }
    } else {
      setState(() {
        _avatarProcessing = false;
      });
      _showSnack('Kırpma iptal edildi.');
      return;
    }

    final Uint8List rawBytesNonNull = rawBytes;
    final _AvatarProcessingResult? processed = await _prepareAvatarData(
      rawBytesNonNull,
    );

    if (!mounted) {
      return;
    }

    if (processed == null) {
      setState(() {
        _avatarProcessing = false;
      });
      _showSnack(
        'Fotoğraf işlenemedi. Farklı bir görsel seçmeyi dene.',
        isError: true,
      );
      return;
    }

    setState(() {
      _avatarPreviewBytes = processed.bytes;
      _pendingAvatarBytes = processed.bytes;
      _avatarOriginalSize = processed.originalSize;
      _avatarCompressedSize = processed.finalSize;
      _avatarQuality = processed.quality;
      _avatarProcessing = false;
      _avatarCleared = false;
    });
    _markDirty();
  }

  void _clearSelectedAvatar() {
    if (_avatarProcessing) {
      return;
    }

    setState(() {
      _avatarPreviewBytes = null;
      _pendingAvatarBytes = null;
      _avatarCleared = true;
      _avatarOriginalSize = null;
      _avatarCompressedSize = null;
      _avatarQuality = null;
    });
    _markDirty();
  }

  String _avatarInitial() {
    final List<String> candidates = [
      _displayNameController.text.trim(),
      _user.fullName.trim(),
      _user.username.trim(),
      _user.email.trim(),
    ];

    for (final candidate in candidates) {
      if (candidate.isEmpty) continue;
      final int codePoint = candidate.runes.isNotEmpty
          ? candidate.runes.first
          : candidate.codeUnitAt(0);
      return String.fromCharCode(codePoint).toUpperCase();
    }

    return '👤';
  }

  Widget _buildDemographicsTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            title: 'Cinsiyet',
            subtitle:
                'İsteğe bağlı. Diğer seçilirse 30 karaktere kadar açıklayabilirsin.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _genderLabels.entries.map((entry) {
              final bool selected = _gender == entry.key;
              return ChoiceChip(
                label: Text(entry.value),
                selected: selected,
                onSelected: (bool value) {
                  if (!value) return;
                  setState(() {
                    _gender = entry.key;
                    if (_gender == 'other') {
                      _genderOtherFocus.requestFocus();
                    } else {
                      _genderOtherController.clear();
                    }
                    _onFormChanged();
                  });
                },
                selectedColor: Colors.orange.withOpacity(0.25),
                labelStyle: TextStyle(
                  color: selected ? Colors.orange : Colors.white,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
                backgroundColor: Colors.white.withOpacity(0.06),
                side: BorderSide(
                  color: selected
                      ? Colors.orange.withOpacity(0.7)
                      : Colors.white.withOpacity(0.08),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _gender == 'other'
                ? TextFormField(
                    key: const ValueKey('genderOther'),
                    controller: _genderOtherController,
                    focusNode: _genderOtherFocus,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      label: 'Cinsiyet Açıklaması',
                      hint: 'Örn. Non-binary',
                    ),
                    maxLength: _genderOtherMaxLength,
                    validator: (value) {
                      if (_gender != 'other') {
                        return null;
                      }
                      final String trimmed = value?.trim() ?? '';
                      if (trimmed.isEmpty) {
                        return 'Lütfen kısa bir açıklama gir.';
                      }
                      if (trimmed.length > _genderOtherMaxLength) {
                        return 'En fazla $_genderOtherMaxLength karakter';
                      }
                      return null;
                    },
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          _sectionHeader(
            title: 'Doğum Tarihi',
            subtitle: 'Gelecekte olamaz ve en az 13 yaşında olmalısın.',
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: _inputDecoration(
              label: 'Doğum Tarihi',
              errorText: _birthDateError,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _birthDate != null
                        ? _dateFormat.format(_birthDate!.toLocal())
                        : 'Seçilmedi',
                    style: TextStyle(
                      color: _birthDate != null
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _saving ? null : _pickBirthDate,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Seç'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            title: 'Eğitim Seviyesi',
            subtitle: 'Kod olarak saklanır (primary|middle|high|higher).',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey(_educationLevel),
            initialValue: _educationLevel,
            decoration: _inputDecoration(label: 'Seviye'),
            dropdownColor: const Color(0xFF1B1F2A),
            items: _educationLabels.entries
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      _educationLevel = value;
                      _onFormChanged();
                    });
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            title: 'Alan Gizliliği',
            subtitle:
                'Varsayılan olarak telefon ve e-posta gizli tutulur. Paylaşım seviyesini seçebilirsin.',
          ),
          const SizedBox(height: 16),
          _buildVisibilitySelector(
            fieldKey: 'phoneNumber',
            label: 'Telefon görünürlüğü',
            description: 'Telefon numaranı kimler görebilir?',
          ),
          const SizedBox(height: 20),
          _buildVisibilitySelector(
            fieldKey: 'email',
            label: 'E-posta görünürlüğü',
            description: 'E-posta adresini kimler görebilir?',
          ),
          const SizedBox(height: 28),
          _sectionHeader(
            title: 'Tercihler',
            subtitle: 'Profil davranışlarına dair kontroller.',
          ),
          const SizedBox(height: 12),
          _preferenceSwitch(
            title: 'Aktivite durumunu göster',
            value: _showActivityStatus,
            onChanged: (value) {
              setState(() {
                _showActivityStatus = value;
                _onFormChanged();
              });
            },
          ),
          _preferenceSwitch(
            title: 'Etiketlenmeye izin ver',
            value: _allowTagging,
            onChanged: (value) {
              setState(() {
                _allowTagging = value;
                _onFormChanged();
              });
            },
          ),
          _preferenceSwitch(
            title: 'Takipçi olmayanlardan mesaj al',
            value: _allowMessagesFromNonFollowers,
            onChanged: (value) {
              setState(() {
                _allowMessagesFromNonFollowers = value;
                _onFormChanged();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilitySelector({
    required String fieldKey,
    required String label,
    required String description,
  }) {
    final String selected = _visibility[fieldKey] ?? 'private';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: _visibilityOptions.map((option) {
            final bool isSelected = selected == option;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _visibilityIcons[option],
                    size: 16,
                    color: isSelected ? Colors.orange : Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Text(_visibilityLabels[option] ?? option),
                ],
              ),
              selected: isSelected,
              onSelected: (bool value) {
                if (!value) return;
                setState(() {
                  _visibility[fieldKey] = option;
                  _onFormChanged();
                });
              },
              selectedColor: Colors.orange.withOpacity(0.22),
              backgroundColor: Colors.white.withOpacity(0.05),
              labelStyle: TextStyle(
                color: isSelected ? Colors.orange : Colors.white,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              side: BorderSide(
                color: isSelected
                    ? Colors.orange.withOpacity(0.7)
                    : Colors.white.withOpacity(0.1),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _preferenceSwitch({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: _saving ? null : onChanged,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      activeTrackColor: Colors.orange,
    );
  }

  Widget _buildBioPreview({
    required List<String> links,
    required List<String> emojis,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Önizleme',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            _sanitizeBio(_bioController.text),
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              height: 1.4,
            ),
          ),
          if (links.isNotEmpty || emojis.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...links.map(
                  (link) => Chip(
                    label: Text(link),
                    avatar: const Icon(Icons.link, size: 16),
                  ),
                ),
                ...emojis.map((emoji) => Chip(label: Text(emoji))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.62),
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
      labelStyle: const TextStyle(color: Colors.white70),
      errorText: errorText,
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.orange),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      counterStyle: const TextStyle(color: Colors.white54),
    );
  }

  Widget _contactCard({
    required IconData icon,
    required String label,
    required String value,
    required String actionLabel,
    required VoidCallback? onPressed,
    Widget? statusChip,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (statusChip != null) statusChip,
          const SizedBox(width: 12),
          FilledButton.tonal(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.withOpacity(0.16),
              foregroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String? _validateDisplayName(String? value) {
    final String collapsed = _collapseSpaces(value ?? '');
    if (collapsed.length < _displayNameminLength) {
      return 'En az $_displayNameminLength karakter olmalı.';
    }
    if (collapsed.length > _displayNameMaxLength) {
      return 'En fazla $_displayNameMaxLength karakter.';
    }
    return null;
  }

  String? _validateBio(String? value) {
    if ((value ?? '').length > _bioMaxLength) {
      return 'En fazla $_bioMaxLength karakter.';
    }
    return null;
  }

  void _normalizeDisplayNameInput() {
    final String collapsed = _collapseSpaces(_displayNameController.text);
    if (collapsed != _displayNameController.text) {
      _displayNameController.value = _displayNameController.value.copyWith(
        text: collapsed,
        selection: TextSelection.collapsed(offset: collapsed.length),
      );
    }
  }

  Future<void> _pickBirthDate() async {
    final DateTime now = DateTime.now();
    final DateTime initial =
        _birthDate ?? DateTime(now.year - _minAgeYears, now.month, now.day);
    final DateTime firstDate = DateTime(now.year - 100, 1, 1);
    final DateTime lastDate = DateTime(
      now.year - _minAgeYears,
      now.month,
      now.day,
    );

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('tr', 'TR'),
      helpText: 'Doğum Tarihini Seç',
    );

    if (picked == null) return;

    if (picked.isAfter(DateTime.now())) {
      setState(() {
        _birthDateError = 'Gelecek bir tarih seçilemez.';
      });
      return;
    }

    if (!_meetsMinimumAge(picked, _minAgeYears)) {
      setState(() {
        _birthDateError = 'En az $_minAgeYears yaşında olmalısın.';
      });
      return;
    }

    setState(() {
      _birthDateError = null;
      _birthDate = DateTime.utc(picked.year, picked.month, picked.day);
      _onFormChanged();
    });
  }

  bool _meetsMinimumAge(DateTime birthDate, int minAge) {
    final DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age >= minAge;
  }

  Future<void> _handleSavePressed() async {
    if (_saving) return;
    _normalizeDisplayNameInput();

    if (!(_formKey.currentState?.validate() ?? false)) {
      _showSnack('Lütfen formdaki hataları düzelt.', isError: true);
      return;
    }

    await _submitProfileChanges();
  }

  Future<void> _submitProfileChanges() async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    final String collapsedDisplayName = _collapseSpaces(
      _displayNameController.text,
    );
    final String sanitizedBio = _bioController.text.trim();
    final String genderOther = _gender == 'other'
        ? _genderOtherController.text.trim()
        : '';

    String finalAvatar = _user.avatar;
    String? avatarToDelete;

    try {
      if (_avatarCleared) {
        finalAvatar = '👤';
        if (_user.avatar.trim().startsWith('http')) {
          avatarToDelete = _user.avatar.trim();
        }
      } else if (_pendingAvatarBytes != null) {
        final String? uploadedUrl = await _avatarUploadService
            .uploadAvatarBytes(userId: _user.id, bytes: _pendingAvatarBytes!);

        if (uploadedUrl == null) {
          _showSnack(
            'Profil fotoğrafı yüklenemedi. Lütfen tekrar dene.',
            isError: true,
          );
          setState(() {
            _saving = false;
          });
          return;
        }

        finalAvatar = uploadedUrl;
        if (_user.avatar.trim().startsWith('http')) {
          avatarToDelete = _user.avatar.trim();
        }
      }
    } catch (error, stack) {
      debugPrint('Avatar yükleme hatası: $error\n$stack');
      _showSnack(
        'Profil fotoğrafı yüklenemedi. Lütfen tekrar dene.',
        isError: true,
      );
      setState(() {
        _saving = false;
      });
      return;
    }

    final UserVisibilitySettings updatedVisibility = _user.visibility.copyWith(
      phoneNumber: _visibility['phoneNumber'] ?? 'private',
      email: _visibility['email'] ?? 'private',
    );

    final UserPreferences updatedPreferences = _user.preferences.copyWith(
      showActivityStatus: _showActivityStatus,
      allowTagging: _allowTagging,
      allowMessagesFromNonFollowers: _allowMessagesFromNonFollowers,
    );

    final User updatedUser = _user.copyWith(
      avatar: finalAvatar,
      displayName: collapsedDisplayName,
      bio: sanitizedBio,
      gender: _gender,
      genderOther: genderOther,
      birthDate: _birthDate,
      educationLevel: _educationLevel,
      visibility: updatedVisibility,
      preferences: updatedPreferences,
    );

    try {
      final bool success = await UserService.instance.updateProfile(
        updatedUser,
      );
      if (!success) {
        _showSnack(
          'Profil güncellemesi başarısız oldu. Lütfen tekrar dene.',
          isError: true,
        );
        return;
      }

      if (!mounted) return;

      final Uint8List? pendingPreview = _pendingAvatarBytes;
      final bool cleared = _isAvatarEmpty(updatedUser.avatar);
      setState(() {
        _user = updatedUser;
        _pendingAvatarBytes = null;
        _avatarCleared = cleared;
        if (cleared) {
          _avatarPreviewBytes = null;
        } else if (updatedUser.avatar.startsWith('data:image')) {
          _avatarPreviewBytes = _decodeAvatarBytes(updatedUser.avatar);
        } else if (pendingPreview != null) {
          _avatarPreviewBytes = pendingPreview;
        }
        _avatarOriginalSize = null;
        _avatarCompressedSize = null;
        _avatarQuality = null;
      });

      if (avatarToDelete != null && avatarToDelete != finalAvatar) {
        unawaited(_avatarUploadService.deleteOldAvatar(avatarToDelete));
      }

      _resetDirtyTracking();
      _saving = false;
      final navigator = Navigator.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigator.pushNamedAndRemoveUntil('/main', (route) => false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final messenger = ScaffoldMessenger.maybeOf(navigator.context);
          messenger?.showSnackBar(
            const SnackBar(
              content: Text('Profilin başarıyla güncellendi.'),
              backgroundColor: Colors.green,
            ),
          );
        });
      });
      navigator.pop<User>(updatedUser);
      return;
    } on FirebaseFunctionsException catch (error, stack) {
      debugPrint('Profil güncelleme Firebase hatası: ${error.message}\n$stack');
      _showSnack(
        error.message ?? 'Profil güncellemesi tamamlanamadı.',
        isError: true,
      );
    } catch (error, stack) {
      debugPrint('Profil güncelleme hatası: $error\n$stack');
      _showSnack(
        'Profil güncellemesi tamamlanamadı. Lütfen tekrar dene.',
        isError: true,
      );
    } finally {
      if (mounted && _saving) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _handleEmailVerification() async {
    if (_saving) return;

    final String? newEmail = await _promptForEmailAddress();
    if (newEmail == null) return;

    _showLoadingDialog('Doğrulama kodu gönderiliyor...');
    String? debugCode;
    bool sendSucceeded = false;
    try {
      debugCode = await EmailOtpService.sendOtp(newEmail);
      sendSucceeded = true;
    } on FirebaseFunctionsException catch (error, stack) {
      debugPrint('E-posta OTP gönderilemedi: ${error.message}\n$stack');
      _showSnack(
        error.message ?? 'Doğrulama e-postası gönderilemedi.',
        isError: true,
      );
    } catch (error, stack) {
      debugPrint('E-posta OTP gönderimi beklenmedik hata: $error\n$stack');
      _showSnack(
        'Doğrulama e-postası gönderilemedi. Lütfen tekrar dene.',
        isError: true,
      );
    } finally {
      _dismissLoadingDialog();
    }

    if (!sendSucceeded || !mounted) {
      return;
    }

    final String? code = await _promptForEmailCode(
      email: newEmail,
      debugCode: debugCode,
    );
    if (code == null) {
      return;
    }

    _showLoadingDialog('Kod doğrulanıyor...');
    try {
      final EmailOtpVerificationResult result =
          await EmailOtpService.confirmEmailUpdate(newEmail, code);

      if (!result.success) {
        final String message = _emailVerificationFailureMessage(result);
        _showSnack(message, isError: true);
        return;
      }

      final String normalizedEmail = _normalizeEmail(newEmail);
      if (!mounted) return;
      setState(() {
        _emailController.text = normalizedEmail;
        _user = _user.copyWith(email: normalizedEmail);
      });
      _showSnack('E-posta adresin doğrulandı ve güncellendi.');
    } on FirebaseFunctionsException catch (error, stack) {
      debugPrint('E-posta doğrulaması başarısız: ${error.message}\n$stack');
      final String message = _mapEmailFirebaseError(error);
      _showSnack(message, isError: true);
    } catch (error, stack) {
      debugPrint('E-posta doğrulaması beklenmedik hata: $error\n$stack');
      _showSnack(
        'E-posta doğrulaması tamamlanamadı. Lütfen tekrar dene.',
        isError: true,
      );
    } finally {
      _dismissLoadingDialog();
    }
  }

  Future<void> _handlePhoneVerification() async {
    if (_saving) return;

    final String? newPhone = await _promptForPhoneNumber();
    if (newPhone == null) return;

    _showLoadingDialog('SMS gönderiliyor...');
    String? debugCode;
    bool sendSucceeded = false;
    try {
      debugCode = await PhoneOtpService.sendOtp(newPhone);
      sendSucceeded = true;
    } on FirebaseFunctionsException catch (error, stack) {
      debugPrint('Telefon OTP gönderilemedi: ${error.message}\n$stack');
      _showSnack(
        error.message ?? 'Doğrulama SMS\'i gönderilemedi.',
        isError: true,
      );
    } catch (error, stack) {
      debugPrint('Telefon OTP gönderimi beklenmedik hata: $error\n$stack');
      _showSnack(
        'Doğrulama SMS\'i gönderilemedi. Lütfen tekrar dene.',
        isError: true,
      );
    } finally {
      _dismissLoadingDialog();
    }

    if (!sendSucceeded || !mounted) {
      return;
    }

    final String? code = await _promptForPhoneCode(
      phoneNumber: newPhone,
      debugCode: debugCode,
    );
    if (code == null) {
      return;
    }

    _showLoadingDialog('Kod doğrulanıyor...');
    try {
      final PhoneOtpVerificationResult result =
          await PhoneOtpService.confirmPhoneUpdate(newPhone, code);

      if (!result.success) {
        final String message = _phoneVerificationFailureMessage(result);
        _showSnack(message, isError: true);
        return;
      }

      final String normalizedPhone = _normalizePhone(newPhone);
      if (!mounted) return;
      setState(() {
        _phoneController.text = normalizedPhone;
        _user = _user.copyWith(phoneNumber: normalizedPhone);
      });
      _showSnack('Telefon numaran doğrulandı ve güncellendi.');
    } on FirebaseFunctionsException catch (error, stack) {
      debugPrint('Telefon doğrulaması başarısız: ${error.message}\n$stack');
      final String message = _mapPhoneFirebaseError(error);
      _showSnack(message, isError: true);
    } catch (error, stack) {
      debugPrint('Telefon doğrulaması beklenmedik hata: $error\n$stack');
      _showSnack(
        'Telefon doğrulaması tamamlanamadı. Lütfen tekrar dene.',
        isError: true,
      );
    } finally {
      _dismissLoadingDialog();
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  void _showLoadingDialog(String message) {
    if (!mounted || _loadingDialogContext != null) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _loadingDialogContext = dialogContext;
        return AlertDialog(
          backgroundColor: const Color(0xFF101827),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      _loadingDialogContext = null;
    });
  }

  void _dismissLoadingDialog() {
    final BuildContext? dialogContext = _loadingDialogContext;
    if (dialogContext != null) {
      Navigator.of(dialogContext).pop();
    }
  }

  Future<String?> _promptForEmailAddress() async {
    final TextEditingController controller = TextEditingController(
      text: _emailController.text.trim(),
    );
    String? errorText;

    final String? result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF101827),
              title: const Text(
                'E-posta Güncelle',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'E-posta',
                      labelStyle: const TextStyle(color: Colors.white70),
                      errorText: errorText,
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Yeni e-posta adresine 6 haneli bir doğrulama kodu göndereceğiz.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed: () {
                    final String email = controller.text.trim();
                    if (!_isValidEmail(email)) {
                      setStateDialog(() {
                        errorText = 'Geçerli bir e-posta adresi gir.';
                      });
                      return;
                    }
                    Navigator.of(context).pop(email);
                  },
                  child: const Text('Kod Gönder'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<String?> _promptForEmailCode({
    required String email,
    String? debugCode,
  }) async {
    final TextEditingController controller = TextEditingController();
    String? errorText;

    final String? result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF101827),
              title: const Text(
                'Doğrulama Kodunu Gir',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$email adresine gönderilen 6 haneli kodu gir.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Kod',
                      labelStyle: const TextStyle(color: Colors.white70),
                      errorText: errorText,
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  if (debugCode != null) ...[
                    const SizedBox(height: 10),
                    SelectableText(
                      'Geliştirici kodu: $debugCode',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed: () {
                    final String value = controller.text.trim();
                    if (!_isValidOtp(value)) {
                      setStateDialog(() {
                        errorText = '6 haneli kod gerekli.';
                      });
                      return;
                    }
                    Navigator.of(context).pop(value);
                  },
                  child: const Text('Onayla'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<String?> _promptForPhoneNumber() async {
    final TextEditingController controller = TextEditingController(
      text: _phoneController.text.trim(),
    );
    String? errorText;

    final String? result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF101827),
              title: const Text(
                'Telefon Güncelle',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Telefon',
                      hintText: '+905XXXXXXXXX',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                      ),
                      errorText: errorText,
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Numara E.164 formatında olmalı (örn. +905XXXXXXXXX). SMS ile doğrulama kodu gönderilecek.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed: () {
                    final String phone = _normalizePhone(controller.text);
                    if (!_isValidPhoneNumber(phone)) {
                      setStateDialog(() {
                        errorText =
                            'Telefon numarası + ile başlamalı ve en az 8 hane olmalı.';
                      });
                      return;
                    }
                    Navigator.of(context).pop(phone);
                  },
                  child: const Text('Kod Gönder'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<String?> _promptForPhoneCode({
    required String phoneNumber,
    String? debugCode,
  }) async {
    final TextEditingController controller = TextEditingController();
    String? errorText;

    final String? result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF101827),
              title: const Text(
                'SMS Kodunu Gir',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$phoneNumber numarasına gönderilen 6 haneli kodu gir.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Kod',
                      labelStyle: const TextStyle(color: Colors.white70),
                      errorText: errorText,
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  if (debugCode != null) ...[
                    const SizedBox(height: 10),
                    SelectableText(
                      'Geliştirici kodu: $debugCode',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed: () {
                    final String value = controller.text.trim();
                    if (!_isValidOtp(value)) {
                      setStateDialog(() {
                        errorText = '6 haneli kod gerekli.';
                      });
                      return;
                    }
                    Navigator.of(context).pop(value);
                  },
                  child: const Text('Onayla'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  String _emailVerificationFailureMessage(EmailOtpVerificationResult result) {
    if (result.isInvalidCode) {
      return 'Kod hatalı. Lütfen tekrar dene.';
    }
    if (result.isExpired) {
      return 'Kodun süresi dolmuş. Yeni bir kod iste.';
    }
    if (result.isNotFound) {
      return 'Doğrulama isteği bulunamadı. Yeniden kod gönder.';
    }
    if (result.isTooManyAttempts) {
      return 'Çok fazla hatalı deneme yaptın. Lütfen yeni kod iste.';
    }
    return 'E-posta doğrulaması tamamlanamadı. Lütfen tekrar dene.';
  }

  String _phoneVerificationFailureMessage(PhoneOtpVerificationResult result) {
    if (result.isInvalidCode) {
      return 'Kod hatalı. Lütfen tekrar dene.';
    }
    if (result.isExpired) {
      return 'Kodun süresi dolmuş. Yeni bir kod iste.';
    }
    if (result.isNotFound) {
      return 'Doğrulama isteği bulunamadı. Yeniden kod gönder.';
    }
    if (result.isTooManyAttempts) {
      return 'Çok fazla hatalı deneme yaptın. Lütfen yeni kod iste.';
    }
    return 'Telefon doğrulaması tamamlanamadı. Lütfen tekrar dene.';
  }

  String _mapEmailFirebaseError(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'already-exists':
        return 'Bu e-posta adresi başka bir hesap tarafından kullanılıyor.';
      case 'invalid-argument':
        return 'Geçerli bir e-posta adresi gir.';
      default:
        return error.message ?? 'E-posta doğrulaması tamamlanamadı.';
    }
  }

  String _mapPhoneFirebaseError(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'already-exists':
        return 'Bu telefon numarası başka bir hesapta kayıtlı.';
      case 'invalid-argument':
        return 'Telefon numarası E.164 formatında olmalı (örn. +905XXXXXXXXX).';
      case 'permission-denied':
        return 'Bu doğrulama kodu başka bir kullanıcıya ait.';
      case 'failed-precondition':
        return 'SMS hizmeti yapılandırılmadı. Lütfen daha sonra tekrar dene.';
      default:
        return error.message ?? 'Telefon doğrulaması tamamlanamadı.';
    }
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'\s+'), '').trim();
  }

  bool _isValidEmail(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      return false;
    }
    final RegExp regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(normalized);
  }

  bool _isValidPhoneNumber(String value) {
    final String normalized = value.trim();
    final RegExp regex = RegExp(r'^\+[1-9]\d{7,14}$');
    return regex.hasMatch(normalized);
  }

  bool _isValidOtp(String value) {
    return RegExp(r'^[0-9]{6}$').hasMatch(value.trim());
  }

  List<String> _extractLinks(String text) {
    return _linkRegExp
        .allMatches(text)
        .map((match) => match.group(0) ?? '')
        .where((link) => link.isNotEmpty)
        .toList(growable: false);
  }

  List<String> _extractEmojis(String text) {
    return _emojiRegExp
        .allMatches(text)
        .map((match) => match.group(0) ?? '')
        .where((emoji) => emoji.isNotEmpty)
        .toList(growable: false);
  }

  String _sanitizeBio(String value) {
    return _htmlEscape.convert(value.trim());
  }

  bool _shallowMapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final String key in a.keys) {
      final dynamic valueA = a[key];
      final dynamic valueB = b[key];
      if (valueA is Map && valueB is Map) {
        final Map<String, dynamic> mapA = valueA.map(
          (key, dynamic value) => MapEntry(key.toString(), value),
        );
        final Map<String, dynamic> mapB = valueB.map(
          (key, dynamic value) => MapEntry(key.toString(), value),
        );
        if (!_shallowMapEquals(mapA, mapB)) {
          return false;
        }
      } else if (valueA != valueB) {
        return false;
      }
    }
    return true;
  }

  String _collapseSpaces(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).join(' ');
  }

  String _normalizeGender(String input) {
    return _genderLabels.keys.contains(input) ? input : 'prefer_not';
  }

  String _normalizeEducation(String input) {
    return _educationLabels.containsKey(input) ? input : 'higher';
  }

  String _normalizeVisibility(String value) {
    return _visibilityOptions.contains(value) ? value : 'private';
  }
}

class _AvatarProcessingResult {
  final Uint8List bytes;
  final int originalSize;
  final int finalSize;
  final int quality;

  const _AvatarProcessingResult({
    required this.bytes,
    required this.originalSize,
    required this.finalSize,
    required this.quality,
  });
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

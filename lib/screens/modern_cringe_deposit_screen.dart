import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import '../theme/app_theme.dart';
import '../models/cringe_entry.dart';
import '../widgets/animated_bubble_background.dart';
import '../services/cringe_entry_service.dart';
import '../services/user_service.dart';

class ModernCringeDepositScreen extends StatefulWidget {
  final VoidCallback? onCringeSubmitted;
  final VoidCallback? onCloseRequested;
  
  const ModernCringeDepositScreen({
    super.key,
    this.onCringeSubmitted,
    this.onCloseRequested,
  });

  @override
  State<ModernCringeDepositScreen> createState() => _ModernCringeDepositScreenState();
}

class _ModernCringeDepositScreenState extends State<ModernCringeDepositScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _submitController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;


  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final PageController _pageController = PageController();
  
  CringeCategory _selectedCategory = CringeCategory.fizikselRezillik;
  int _currentStep = 0;
  int _severity = 5;
  bool _isAnonymous = false;
  bool _isSubmitting = false;
  
  // Fotoğraf için yeni değişkenler
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isImageLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _submitController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _submitController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleBackNavigation() {
    if (_currentStep > 0) {
      _goToPreviousStep();
    } else if (widget.onCloseRequested != null) {
      widget.onCloseRequested!.call();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _goToPreviousStep() {
    if (_currentStep <= 0) {
      return;
    }
    setState(() => _currentStep--);
    if (_pageController.hasClients) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canSystemPop = widget.onCloseRequested == null && _currentStep == 0;
    return PopScope(
      canPop: canSystemPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentStep > 0) {
          _goToPreviousStep();
        } else if (widget.onCloseRequested != null) {
          widget.onCloseRequested!.call();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: AnimatedBubbleBackground(
          bubbleCount: 40,
          bubbleColor: AppTheme.accentColor.withValues(alpha: 0.3),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildProgressIndicator(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStepOne(),
                      _buildStepTwo(),
                      _buildStepThree(),
                    ],
                  ),
                ),
                _buildNavigationButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF2A2A2A).withValues(alpha: 0.9),
                    const Color(0xFF1A1A1A).withValues(alpha: 0.7),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _handleBackNavigation,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.accentColor.withValues(alpha: 0.2),
                            AppTheme.accentColor.withValues(alpha: 0.1),
                          ],
                        ),
                        border: Border.all(
                          color: AppTheme.accentColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [AppTheme.accentColor, Colors.white],
                          ).createShader(bounds),
                          child: const Text(
                            'Yeni Krep Paylaş',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Utanç verici anınızı toplulukla paylaşın',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2A2A2A).withValues(alpha: 0.8),
                    const Color(0xFF1A1A1A).withValues(alpha: 0.6),
                  ],
                ),
                border: Border.all(
                  color: AppTheme.accentColor.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStepIndicator(0, 'Bilgiler'),
                      _buildStepIndicator(1, 'Kategori'),
                      _buildStepIndicator(2, 'Özet'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepIndicator(int step, String title) {
    final isActive = step <= _currentStep;
    final isCompleted = step < _currentStep;
    
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isCompleted || isActive
                ? LinearGradient(
                    colors: [AppTheme.accentColor, AppTheme.accentColor.withValues(alpha: 0.7)],
                  )
                : null,
            color: isCompleted || isActive ? null : Colors.white.withValues(alpha: 0.2),
            border: Border.all(
              color: isCompleted || isActive 
                  ? AppTheme.accentColor 
                  : Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Icon(
            isCompleted 
                ? Icons.check 
                : isActive 
                    ? Icons.circle 
                    : Icons.circle_outlined,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.6),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }



  Widget _buildStepOne() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Başlık ve Açıklama',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _titleController,
                  label: 'Başlık',
                  hint: 'Kısa ve öz bir başlık yazın',
                  maxLength: 100,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _descriptionController,
                  label: 'Açıklama',
                  hint: 'Ne oldu? Detayları anlatın...',
                  maxLines: 5,
                  maxLength: 500,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kategori Seçin',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: CringeCategory.values.map((category) {
                    final isSelected = _selectedCategory == category;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = category),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: isSelected
                              ? AppTheme.accentColor.withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.1),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.accentColor
                                : Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _getCategoryText(category),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isSelected 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTwo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '2. Utanç Seviyesi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getSeverityColor().withValues(alpha: 0.2),
                      ),
                      child: Icon(
                        _getSeverityIcon(),
                        color: _getSeverityColor(),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getSeverityText(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '$_severity/10 - ${_getSeverityDescription()}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _getSeverityColor(),
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                    thumbColor: _getSeverityColor(),
                    overlayColor: _getSeverityColor().withValues(alpha: 0.2),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 12,
                    ),
                    trackHeight: 8,
                  ),
                  child: Slider(
                    value: _severity.toDouble(),
                    onChanged: (value) {
                      setState(() => _severity = value.round());
                    },
                    min: 1,
                    max: 10,
                    divisions: 9,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hafif',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Orta',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Aşırı',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Fotoğraf ekleme bölümü
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fotoğraf Ekle (İsteğe Bağlı)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                if (_selectedImageBytes != null) ...[
                  // Seçili fotoğrafı göster
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _selectedImageBytes!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedImageName ?? 'Seçili fotoğraf',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _removeImage,
                        icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                        label: const Text('Kaldır', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ] else ...[
                  // Fotoğraf seçme butonu
                  GestureDetector(
                    onTap: _isImageLoading ? null : _pickImage,
                    child: Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          style: BorderStyle.solid,
                        ),
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isImageLoading)
                            const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            )
                          else ...[
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 40,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Fotoğraf Ekle',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Dokunarak fotoğraf seçin',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepThree() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '3. Gizlilik Ayarları',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  title: const Text(
                    'Anonim Paylaş',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'İsminiz gözükmeyecek, sadece "Anonim" yazacak',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  value: _isAnonymous,
                  onChanged: (value) => setState(() => _isAnonymous = value),
                  activeThumbColor: AppTheme.accentColor,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Özet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSummaryItem('Başlık', _titleController.text.isEmpty 
                    ? 'Belirtilmedi' : _titleController.text),
                _buildSummaryItem('Kategori', _getCategoryText(_selectedCategory)),
                _buildSummaryItem('Utanç Seviyesi', '$_severity/10'),
                _buildSummaryItem('Gizlilik', _isAnonymous ? 'Anonim' : 'Açık'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(color: Colors.white),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.1),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.accentColor,
                width: 2,
              ),
            ),
            counterStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF1A1A1A).withValues(alpha: 0.8),
                  ],
                ),
                border: Border(
                  top: BorderSide(
                    color: AppTheme.accentColor.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _goToPreviousStep,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          side: BorderSide(
                            color: AppTheme.accentColor.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Geri'),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                        shadowColor: AppTheme.accentColor.withValues(alpha: 0.4),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _currentStep == 2 ? 'Paylaş' : 'İleri',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleNext() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submitEntry();
    }
  }

  void _submitEntry() async {
    if (!mounted) return;
    setState(() => _isSubmitting = true);
    
    try {
      // Kullanıcı bilgilerini al
      var currentUser = UserService.instance.currentUser;
      if (currentUser == null) {
        final firebaseUser = UserService.instance.firebaseUser;
        if (firebaseUser != null) {
          await UserService.instance.loadUserData(firebaseUser.uid);
          currentUser = UserService.instance.currentUser;
        }
      }

      if (currentUser == null) {
        throw Exception('Kullanıcı oturum açmamış');
      }
      
      // Fotoğraf varsa base64'e çevir ve imageUrls listesine ekle
      List<String> imageUrls = [];
      if (_selectedImageBytes != null) {
        String base64Image = base64Encode(_selectedImageBytes!);
        imageUrls.add('data:image/jpeg;base64,$base64Image');
      }

      final displayName = currentUser.displayName.trim().isNotEmpty
          ? currentUser.displayName.trim()
          : currentUser.username.trim().isNotEmpty
              ? currentUser.username.trim()
              : 'Anonim';

      final usernameHandle = currentUser.username.trim().isNotEmpty
          ? currentUser.username.trim()
          : (currentUser.email.contains('@')
              ? currentUser.email.split('@').first
              : currentUser.id.substring(0, 6));

      final authorAvatar = _isAnonymous
          ? null
          : (currentUser.avatar.trim().isNotEmpty ? currentUser.avatar.trim() : null);
      
      // Krep entry'sini oluştur
      final entry = CringeEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: currentUser.id,
        authorName: _isAnonymous ? 'Anonim' : displayName,
        authorHandle: _isAnonymous ? '@anonim' : '@$usernameHandle',
        baslik: _titleController.text.trim(),
        aciklama: _descriptionController.text.trim(),
        kategori: _selectedCategory,
        krepSeviyesi: _severity.toDouble(),
        createdAt: DateTime.now(),
        isAnonim: _isAnonymous,
        imageUrls: imageUrls,
        authorAvatarUrl: authorAvatar,
      );
      
  debugPrint('Krep entry oluşturuldu: ${entry.baslik}');
      if (imageUrls.isNotEmpty) {
  debugPrint('Fotoğraf eklendi: ${imageUrls.length} adet');
      }
      
      // Firestore'a kaydet
      final success = await CringeEntryService.instance.addEntry(entry);
      
      if (!success) {
        throw Exception('Krep paylaşılamadı, tekrar deneyin');
      }
      
  debugPrint('Krep başarıyla Firestore\'a kaydedildi!');
      
    } catch (e) {
  debugPrint('Krep paylaşma hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
    
    if (mounted) {
      // Form'u temizle
      _titleController.clear();
      _descriptionController.clear();
      _selectedImageBytes = null;
      _selectedImageName = null;
      setState(() {
        _currentStep = 0;
        _severity = 5;
        _isAnonymous = false;
      });
      
      // İlk adıma geri dön
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      
      // Ana sayfaya geç (eğer callback varsa)
      widget.onCringeSubmitted?.call();
      
      // Başarı mesajını göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selectedImageBytes != null 
            ? 'Fotoğraflı krep başarıyla paylaşıldı!'
            : 'Krep başarıyla paylaşıldı!'),
          backgroundColor: AppTheme.accentColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _getCategoryText(CringeCategory category) {
    return '${category.emoji} ${category.displayName}';
  }

  Color _getSeverityColor() {
    if (_severity <= 3) return Colors.green;
    if (_severity <= 6) return Colors.orange;
    return Colors.red;
  }

  IconData _getSeverityIcon() {
    if (_severity <= 3) return Icons.sentiment_satisfied;
    if (_severity <= 6) return Icons.sentiment_neutral;
    return Icons.sentiment_very_dissatisfied;
  }

  String _getSeverityText() {
    if (_severity <= 3) return 'Hafif Utanç';
    if (_severity <= 6) return 'Orta Düzey';
    return 'Aşırı Utanç';
  }

  String _getSeverityDescription() {
    if (_severity <= 3) return 'Biraz rahatsız edici';
    if (_severity <= 6) return 'Oldukça utandırıcı';
    return 'Çok fazla utanç verici';
  }

  // Fotoğraf seçme fonksiyonu
  Future<void> _pickImage() async {
    setState(() => _isImageLoading = true);
    
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        Uint8List imageBytes = result.files.single.bytes!;
        String fileName = result.files.single.name;

        // Fotoğrafı compress et
        Uint8List compressedBytes = await _resizeAndCompressImage(imageBytes);

        if (!mounted) return;

        setState(() {
          _selectedImageBytes = compressedBytes;
          _selectedImageName = fileName;
          _isImageLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotoğraf eklendi: ${(compressedBytes.length / 1024).toStringAsFixed(1)}KB'),
            backgroundColor: AppTheme.accentColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        if (!mounted) return;
        setState(() => _isImageLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isImageLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fotoğraf seçilirken hata oluştu'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Fotoğrafı yeniden boyutlandır ve sıkıştır
  Future<Uint8List> _resizeAndCompressImage(Uint8List imageBytes) async {
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    // Maksimum boyut: 800px
    img.Image resizedImage = img.copyResize(
      image, 
      width: image.width > image.height ? 800 : null,
      height: image.height > image.width ? 800 : null,
    );

    // JPEG olarak compress et (%70 kalite)
    List<int> compressedBytes = img.encodeJpg(resizedImage, quality: 70);
    
    return Uint8List.fromList(compressedBytes);
  }

  // Fotoğrafı kaldır
  void _removeImage() {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
    });
  }
}
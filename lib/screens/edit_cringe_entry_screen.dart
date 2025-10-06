import 'package:flutter/material.dart';
import '../models/cringe_entry.dart';
import '../services/cringe_entry_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

class EditCringeEntryScreen extends StatefulWidget {
  final CringeEntry entry;

  const EditCringeEntryScreen({super.key, required this.entry});

  @override
  State<EditCringeEntryScreen> createState() => _EditCringeEntryScreenState();
}

class _EditCringeEntryScreenState extends State<EditCringeEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  late double _krepLevel;
  late CringeCategory _selectedCategory;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.entry.aciklama);
    _krepLevel = widget.entry.krepSeviyesi;
    _selectedCategory = widget.entry.kategori;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedDescription = _descriptionController.text.trim();
      final derivedTitle = CringeEntry.deriveTitle('', updatedDescription);

      // Update entry
      final updatedEntry = widget.entry.copyWith(
        baslik: derivedTitle,
        aciklama: updatedDescription,
        krepSeviyesi: _krepLevel,
        kategori: _selectedCategory,
      );

      await CringeEntryService.instance.updateEntry(updatedEntry);

      if (!mounted) return;

      Navigator.of(context).pop(true); // Return true to indicate success

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Krep başarıyla güncellendi'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: AppTheme.cringeRed,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: const Text(
          'Krepi Düzenle',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveChanges,
              child: const Text(
                'Kaydet',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          children: [
            // Description Field
            Text(
              'Açıklama',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              style: const TextStyle(color: AppTheme.textPrimary),
              maxLines: 6,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Krepin detayları...',
                hintStyle: TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Açıklama gerekli';
                }
                if (value.trim().length < 10) {
                  return 'Açıklama en az 10 karakter olmalı';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_fix_high, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Başlık artık otomatik oluşturuluyor. Sadece krebin içeriğini güncelle, geri kalanını biz hallediyoruz.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: isMobile ? 12 : 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Category
            Text(
              'Kategori',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: DropdownButtonFormField<CringeCategory>(
                initialValue: _selectedCategory,
                dropdownColor: const Color(0xFF1A1A2E),
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: CringeCategory.values.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Row(
                      children: [
                        Icon(category.icon, size: 20, color: category.color),
                        const SizedBox(width: 12),
                        Text(category.displayName),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
            ),
            const SizedBox(height: 24),

            // Krep Level
            Text(
              'Krep Seviyesi: ${_krepLevel.toStringAsFixed(1)}/10',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Az Utanç Verici',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: isMobile ? 11 : 12,
                        ),
                      ),
                      Text(
                        'Çok Utanç Verici',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: isMobile ? 11 : 12,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _krepLevel,
                    min: 1,
                    max: 10,
                    divisions: 90,
                    activeColor: _getKrepLevelColor(_krepLevel),
                    inactiveColor: Colors.white.withValues(alpha: 0.1),
                    onChanged: (value) {
                      setState(() => _krepLevel = value);
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: _getKrepLevelColor(_krepLevel),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _krepLevel.toStringAsFixed(1),
                        style: TextStyle(
                          color: _getKrepLevelColor(_krepLevel),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryColor,
                    size: isMobile ? 20 : 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Krepi düzenledikten sonra değişiklikler hemen yansıyacaktır.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: isMobile ? 12 : 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getKrepLevelColor(double level) {
    if (level < 3) return AppTheme.secondaryColor;
    if (level < 6) return AppTheme.warningColor;
    if (level < 8) return AppTheme.cringeOrange;
    return AppTheme.cringeRed;
  }
}

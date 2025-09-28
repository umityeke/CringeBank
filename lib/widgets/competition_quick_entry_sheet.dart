import 'dart:async';

import 'package:flutter/material.dart';

import '../models/cringe_entry.dart';
import '../services/competition_service.dart';
import '../services/cringe_entry_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';

class CompetitionQuickEntrySheet extends StatefulWidget {
  const CompetitionQuickEntrySheet({
    super.key,
    required this.competition,
  });

  final Competition competition;

  @override
  State<CompetitionQuickEntrySheet> createState() =>
      _CompetitionQuickEntrySheetState();
}

class _CompetitionQuickEntrySheetState
    extends State<CompetitionQuickEntrySheet> {
  final TextEditingController _textController = TextEditingController();
  bool _isSubmitting = false;
  bool _stayAnonymous = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const Divider(height: 1, color: Colors.white12),
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: 120,
                    maxHeight: mediaQuery.size.height * 0.45,
                  ),
                  child: Scrollbar(
                    child: TextField(
                      controller: _textController,
                      autofocus: true,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      minLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Anını burada paylaş... (minimum 10 karakter)',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        contentPadding: const EdgeInsets.all(16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide:
                              const BorderSide(color: AppTheme.cringeOrange),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingL,
                ),
                child: Row(
                  children: [
                    Switch.adaptive(
                      value: _stayAnonymous,
                      thumbColor:
                          WidgetStatePropertyAll(AppTheme.cringeOrange),
                      trackColor: WidgetStatePropertyAll(
                        AppTheme.cringeOrange.withValues(alpha: 0.35),
                      ),
                      onChanged: (value) {
                        setState(() => _stayAnonymous = value);
                      },
                    ),
                    const SizedBox(width: AppTheme.spacingXS),
                    Expanded(
                      child: Text(
                        'Anonim kal',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    SizedBox(
                      height: 44,
                      child: FilledButton.icon(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.cringeOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingL,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          _isSubmitting ? 'Gönderiliyor...' : 'Yarışmaya Gönder',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingL),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingL,
        AppTheme.spacingL,
        AppTheme.spacingS,
        AppTheme.spacingS,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.competition.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Anını paylaş ve yarışmaya katılımını tamamla.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubmit() async {
    final rawText = _textController.text.trim();
    if (rawText.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anını paylaşmadan önce en az 10 karakter yazmalısın.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final firebaseUser = UserService.instance.firebaseUser;
      if (firebaseUser == null) {
        throw StateError('Giriş yapmalısın.');
      }

      var user = UserService.instance.currentUser;
      if (user == null || user.id.isEmpty) {
        await UserService.instance.loadUserData(firebaseUser.uid);
        user = UserService.instance.currentUser;
      }

      if (user == null || user.id.isEmpty) {
        throw StateError('Kullanıcı bilgileri bulunamadı.');
      }

  final resolvedUser = user;

      final competition = CompetitionService.currentCompetitions.firstWhere(
        (c) => c.id == widget.competition.id,
        orElse: () => widget.competition,
      );

      if (!competition.participantUserIds.contains(resolvedUser.id)) {
        throw StateError('Önce yarışmaya katılmalısın.');
      }

      final hasSubmitted = competition.entries
          .any((entry) => entry.userId == resolvedUser.id);
      if (hasSubmitted) {
        throw StateError('Bu yarışmaya zaten bir anı gönderdin.');
      }

      final authorName = _stayAnonymous ? 'Anonim' : resolvedUser.displayName;
      final authorHandle = _stayAnonymous
          ? '@anonim'
          : '@${resolvedUser.username.trim().isNotEmpty ? resolvedUser.username.trim() : firebaseUser.email?.split('@').first ?? resolvedUser.id.substring(0, 6)}';

      final authorAvatarUrl = _stayAnonymous
          ? null
          : (resolvedUser.avatar.trim().isNotEmpty ? resolvedUser.avatar.trim() : firebaseUser.photoURL);

      final category = competition.specificCategory ?? CringeCategory.sosyalRezillik;
      final severity = _estimateSeverity(rawText);
      final derivedTitle = _deriveTitle(rawText);

      final entry = CringeEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: resolvedUser.id,
        authorName: authorName,
        authorHandle: authorHandle,
        baslik: derivedTitle,
        aciklama: rawText,
        kategori: category,
        krepSeviyesi: severity,
        createdAt: DateTime.now(),
        isAnonim: _stayAnonymous,
        imageUrls: const [],
        authorAvatarUrl: authorAvatarUrl,
      );

      final submitted = await CompetitionService.submitEntry(
        widget.competition.id,
        entry,
      );

      if (!submitted) {
        throw StateError(
          'Anı yarışmaya gönderilemedi. Daha önce bir anı eklemiş olabilirsin.',
        );
      }

      final added = await CringeEntryService.instance.addEntry(entry);
      if (!added) {
        throw StateError('Krep paylaşımı kaydedilemedi.');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${competition.title}" yarışmasına anın gönderildi!'),
          backgroundColor: AppTheme.cringeOrange,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _deriveTitle(String text) {
    final sanitized = text.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (sanitized.isEmpty) {
      return 'Yarışma Anısı';
    }
    return sanitized.length <= 60
        ? sanitized
        : '${sanitized.substring(0, 57)}...';
  }

  double _estimateSeverity(String text) {
    final lengthScore = (text.length / 200).clamp(0, 5).toDouble();
    final exclamationBonus = RegExp(r'!').allMatches(text).length.clamp(0, 3);
    final questionBonus = RegExp(r'\?').allMatches(text).length.clamp(0, 2);
    final base = 4.0 + lengthScore + exclamationBonus * 0.3 + questionBonus * 0.2;
    return base.clamp(3, 10);
  }
}

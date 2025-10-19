import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cringebank/features/onboarding/application/registration_controller.dart';
import 'package:cringebank/features/onboarding/application/registration_providers.dart';
import '../theme/app_theme.dart';

class RegistrationFlowScreen extends ConsumerStatefulWidget {
	const RegistrationFlowScreen({super.key});

	@override
	ConsumerState<RegistrationFlowScreen> createState() => _RegistrationFlowScreenState();
}

class _RegistrationFlowScreenState extends ConsumerState<RegistrationFlowScreen>
		with SingleTickerProviderStateMixin {
	late final AnimationController _bubbleController;
	late final List<_BubbleConfig> _bubbles;

	final TextEditingController _emailController = TextEditingController();
	final TextEditingController _passwordController = TextEditingController();
	final TextEditingController _confirmPasswordController = TextEditingController();
	final TextEditingController _otpController = TextEditingController();
	final TextEditingController _usernameController = TextEditingController();
	final TextEditingController _fullNameController = TextEditingController();

	Timer? _countdownTicker;
	ProviderSubscription<RegistrationFlowState>? _stateSubscription;

	@override
	void initState() {
		super.initState();
		_bubbleController = AnimationController(
			vsync: this,
			duration: const Duration(seconds: 18),
		)..repeat();

		_bubbles = [
			_BubbleConfig(
				origin: const Offset(0.2, 0.25),
				radius: 110,
				horizontalShift: 0.06,
				verticalShift: 0.08,
				speed: 1.0,
				phase: 0.0,
				colors: [
					const Color(0xFF3C8CE7).withOpacity(0.55),
					const Color(0xFF00EAFF).withOpacity(0.25),
				],
			),
			_BubbleConfig(
				origin: const Offset(0.75, 0.2),
				radius: 140,
				horizontalShift: 0.08,
				verticalShift: 0.06,
				speed: 0.75,
				phase: 0.35,
				colors: [
					const Color(0xFF6A11CB).withOpacity(0.45),
					const Color(0xFF2575FC).withOpacity(0.22),
				],
			),
			_BubbleConfig(
				origin: const Offset(0.3, 0.75),
				radius: 90,
				horizontalShift: 0.05,
				verticalShift: 0.07,
				speed: 1.25,
				phase: 0.6,
				colors: [
					const Color(0xFF00B4DB).withOpacity(0.5),
					const Color(0xFF0083B0).withOpacity(0.2),
				],
			),
			_BubbleConfig(
				origin: const Offset(0.8, 0.72),
				radius: 120,
				horizontalShift: 0.07,
				verticalShift: 0.09,
				speed: 0.9,
				phase: 0.9,
				colors: [
					const Color(0xFFE96443).withOpacity(0.42),
					const Color(0xFF904E95).withOpacity(0.18),
				],
			),
		];

		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (!mounted) return;
			ref.read(registrationControllerProvider.notifier).initialize();
		});

		_stateSubscription = ref.listenManual<RegistrationFlowState>(
			registrationControllerProvider,
			(previous, next) {
				if (!mounted) {
					return;
				}

				if (next.globalMessage != null && next.globalMessage != previous?.globalMessage) {
					_showSnackBar(next.globalMessage!);
					ref.read(registrationControllerProvider.notifier).clearGlobalMessage();
				}

				if (previous?.step != RegistrationFlowStep.success &&
						next.step == RegistrationFlowStep.success) {
					WidgetsBinding.instance.addPostFrameCallback((_) {
						if (mounted) {
							GoRouter.of(context).go('/feed');
						}
					});
				}

				_ensureCountdownTicker(next);
			},
		);
	}

	@override
	void dispose() {
		_countdownTicker?.cancel();
		_stateSubscription?.close();
		_bubbleController.dispose();
		_emailController.dispose();
		_passwordController.dispose();
		_confirmPasswordController.dispose();
		_otpController.dispose();
		_usernameController.dispose();
		_fullNameController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final state = ref.watch(registrationControllerProvider);
		final controller = ref.read(registrationControllerProvider.notifier);

		_syncControllers(state);
		_ensureCountdownTicker(state);

		final mediaQuery = MediaQuery.of(context);
		final horizontalPadding = mediaQuery.size.width * 0.07;
		final availableWidth = mediaQuery.size.width - (horizontalPadding * 2);
		final cardWidth = availableWidth > 0 ? math.min(480.0, availableWidth) : 480.0;
		final canPop = Navigator.of(context).canPop();

		return Scaffold(
			body: Stack(
				children: [
					Positioned.fill(
						child: Container(
							decoration: const BoxDecoration(
								gradient: LinearGradient(
									begin: Alignment.topLeft,
									end: Alignment.bottomRight,
									colors: [
										Color(0xFF0F172A),
										Color(0xFF111827),
										Color(0xFF0B1120),
									],
								),
							),
						),
					),
					Positioned.fill(
						child: AnimatedBuilder(
							animation: _bubbleController,
							builder: (context, _) => CustomPaint(
								painter: _BubblesPainter(
									bubbles: _bubbles,
									progress: _bubbleController.value,
								),
							),
						),
					),
					Positioned.fill(
						child: Container(
							decoration: BoxDecoration(
								gradient: LinearGradient(
									colors: [Colors.black.withOpacity(0.25), Colors.transparent],
									begin: Alignment.topCenter,
									end: Alignment.bottomCenter,
								),
							),
						),
					),
					Center(
						child: SingleChildScrollView(
							padding: EdgeInsets.only(
								left: horizontalPadding,
								right: horizontalPadding,
								top: mediaQuery.padding.top + 40,
								bottom: 40,
							),
							child: Column(
								mainAxisSize: MainAxisSize.min,
								children: [
									_buildRegistrationCard(context, cardWidth, state, controller),
								],
							),
						),
					),
					if (canPop)
						Positioned(
							top: mediaQuery.padding.top + 16,
							left: horizontalPadding,
							child: SafeArea(
								child: IconButton(
									onPressed: () => Navigator.of(context).maybePop(),
									icon: const Icon(Icons.arrow_back_ios_new_rounded),
									color: Colors.white.withOpacity(0.9),
									splashRadius: 24,
								),
							),
						),
				],
			),
		);
	}

	Widget _buildRegistrationCard(
		BuildContext context,
		double cardWidth,
		RegistrationFlowState state,
		RegistrationController controller,
	) {
		final cardColor = Colors.white.withOpacity(0.04);
		final borderColor = Colors.white.withOpacity(0.08);

		return ClipRRect(
			borderRadius: BorderRadius.circular(24),
			child: BackdropFilter(
				filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
				child: Container(
					width: cardWidth,
					decoration: BoxDecoration(
						color: cardColor,
						borderRadius: BorderRadius.circular(24),
						border: Border.all(color: borderColor, width: 1.2),
						boxShadow: [
							BoxShadow(
								color: Colors.black.withOpacity(0.45),
								blurRadius: 30,
								offset: const Offset(0, 22),
								spreadRadius: -18,
							),
						],
					),
					padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
					child: _buildCardContent(context, state, controller),
				),
			),
		);
	}

	Widget _buildCardContent(
		BuildContext context,
		RegistrationFlowState state,
		RegistrationController controller,
	) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			mainAxisSize: MainAxisSize.min,
			children: [
				Text(
					_titleForStep(state.step),
					style: const TextStyle(
						fontSize: 26,
						fontWeight: FontWeight.w700,
						color: Colors.white,
					),
				),
				const SizedBox(height: 8),
				Text(
					'CRINGE Bankası\'na katılmak için birkaç adım kaldı.',
					style: TextStyle(
						fontSize: 14,
						fontWeight: FontWeight.w500,
						color: Colors.white.withOpacity(0.65),
					),
				),
				const SizedBox(height: 28),
				_buildStepIndicator(state.step),
				const SizedBox(height: 28),
				AnimatedSwitcher(
					duration: const Duration(milliseconds: 250),
					transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
					child: _buildCurrentStep(context, state, controller),
				),
			],
		);
	}

	Widget _buildStepIndicator(RegistrationFlowStep activeStep) {
		const steps = [
			RegistrationFlowStep.email,
			RegistrationFlowStep.otp,
			RegistrationFlowStep.profile,
		];

		return Row(
			children: steps.map((step) {
				final index = steps.indexOf(step) + 1;
				final isActive = step.index <= activeStep.index;

				return Expanded(
					child: Column(
						children: [
							Row(
								children: [
									Container(
										padding: const EdgeInsets.all(6),
										decoration: BoxDecoration(
											shape: BoxShape.circle,
											color: isActive ? AppTheme.accentColor : Colors.white.withOpacity(0.2),
										),
										child: Text('$index', style: const TextStyle(color: Colors.white)),
									),
									if (step != steps.last)
										Expanded(
											child: Container(
												height: 2,
												margin: const EdgeInsets.symmetric(horizontal: 8),
												decoration: BoxDecoration(
													gradient: LinearGradient(
														colors: isActive
																? [
																		AppTheme.accentColor,
																		AppTheme.primaryColor.withOpacity(0.7),
																	]
																: [
																		Colors.white.withOpacity(0.1),
																		Colors.white.withOpacity(0.1),
																	],
													),
												),
											),
										),
								],
							),
							const SizedBox(height: 6),
							Text(
								_stepLabel(step),
								style: TextStyle(
									color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
									fontSize: 12,
								),
							),
						],
					),
				);
			}).toList(),
		);
	}

	Widget _buildCurrentStep(
		BuildContext context,
		RegistrationFlowState state,
		RegistrationController controller,
	) {
		switch (state.step) {
			case RegistrationFlowStep.email:
				return _buildEmailStep(context, state, controller);
			case RegistrationFlowStep.otp:
				return _buildOtpStep(context, state, controller);
			case RegistrationFlowStep.profile:
				return _buildProfileStep(context, state, controller);
			case RegistrationFlowStep.success:
				return _buildSuccessStep();
		}
	}

	Widget _buildEmailStep(
		BuildContext context,
		RegistrationFlowState state,
		RegistrationController controller,
	) {
		return Column(
			key: const ValueKey('emailStep'),
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				_buildTextField(
					controller: _emailController,
					label: 'E-posta',
					hint: 'ornek@email.com',
					icon: Icons.alternate_email,
					keyboardType: TextInputType.emailAddress,
					enabled: !state.isLoading,
					errorText: state.emailError,
					onChanged: controller.updateEmail,
				),
				const SizedBox(height: 18),
				_buildTextField(
					controller: _passwordController,
					label: 'Şifre',
					hint: 'En az 8 karakter, harf ve rakam içermeli',
					icon: Icons.lock_outline,
					obscureText: true,
					enabled: !state.isLoading,
					errorText: state.passwordError,
					onChanged: controller.updatePassword,
				),
				const SizedBox(height: 18),
				_buildTextField(
					controller: _confirmPasswordController,
					label: 'Şifre Tekrar',
					hint: 'Şifrenizi doğrulayın',
					icon: Icons.lock_reset,
					obscureText: true,
					enabled: !state.isLoading,
					errorText: state.confirmPasswordError,
					onChanged: controller.updateConfirmPassword,
				),
				const SizedBox(height: 26),
				_GradientButton(
					label: 'Devam Et',
					isLoading: state.isLoading,
					onPressed: state.isLoading ? null : controller.submitEmailStep,
				),
			],
		);
	}

	Widget _buildOtpStep(
		BuildContext context,
		RegistrationFlowState state,
		RegistrationController controller,
	) {
		final countdown = state.otpResendRemaining;

		return Column(
			key: const ValueKey('otpStep'),
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Text(
					'E-posta adresine gönderilen 6 haneli kodu gir.',
					style: TextStyle(
						color: Colors.white.withOpacity(0.8),
						fontSize: 14,
						fontWeight: FontWeight.w500,
					),
				),
				const SizedBox(height: 18),
				_buildTextField(
					controller: _otpController,
					label: 'Doğrulama Kodu',
					hint: kDebugMode && state.devOtp != null ? state.devOtp! : '000000',
					icon: Icons.verified_outlined,
					keyboardType: TextInputType.number,
					enabled: !state.isLoading,
					errorText: state.otpError,
					onChanged: controller.updateOtpCode,
				),
				if (state.otpRemainingAttempts != null) ...[
					const SizedBox(height: 10),
					Text(
						'Kalan deneme: ${state.otpRemainingAttempts}',
						style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
					),
				],
				if (kDebugMode && state.devOtp != null) ...[
					const SizedBox(height: 8),
					Text(
						'Debug OTP: ${state.devOtp}',
						style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
					),
				],
				const SizedBox(height: 26),
				_GradientButton(
					label: 'Doğrula',
					isLoading: state.isLoading,
					onPressed: state.isLoading ? null : controller.verifyOtp,
				),
				const SizedBox(height: 14),
				Align(
					alignment: Alignment.centerRight,
					child: TextButton.icon(
						onPressed: state.isLoading || (countdown != null && countdown > Duration.zero)
								? null
								: () {
										_otpController.clear();
										controller.updateOtpCode('');
										controller.resendOtp();
									},
						icon: const Icon(Icons.refresh),
						label: Text(
							countdown != null && countdown > Duration.zero
									? 'Yeniden gönderilebilir: ${_formatDuration(countdown)}'
									: 'Kod gelmedi mi? Yeniden gönder',
						),
					),
				),
			],
		);
	}

	Widget _buildProfileStep(
		BuildContext context,
		RegistrationFlowState state,
		RegistrationController controller,
	) {
		return Column(
			key: const ValueKey('profileStep'),
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				_buildTextField(
					controller: _usernameController,
					label: 'Kullanıcı Adı',
					hint: 'cringe_master',
					icon: Icons.person_outline,
					enabled: !state.isLoading,
					errorText: state.usernameTouched ? state.usernameError : null,
					onChanged: controller.updateUsername,
					textCapitalization: TextCapitalization.none,
				),
				const SizedBox(height: 8),
				_buildUsernameStatus(state),
				const SizedBox(height: 18),
				_buildTextField(
					controller: _fullNameController,
					label: 'Ad Soyad',
					hint: 'Adın ve soyadın',
					icon: Icons.badge_outlined,
					enabled: !state.isLoading,
					onChanged: controller.updateFullName,
					textCapitalization: TextCapitalization.words,
				),
				const SizedBox(height: 24),
				_buildAgreementCheckbox(
					label: 'Kullanım koşullarını okudum ve kabul ediyorum',
					value: state.acceptTerms,
					onChanged: state.isLoading ? null : (value) => controller.toggleTerms(value ?? false),
				),
				const SizedBox(height: 12),
				_buildAgreementCheckbox(
					label: 'Gizlilik politikasını kabul ediyorum',
					value: state.acceptPrivacy,
					onChanged: state.isLoading ? null : (value) => controller.togglePrivacy(value ?? false),
				),
				const SizedBox(height: 12),
				_buildAgreementCheckbox(
					label: 'Pazarlama iletişimleri almak istiyorum',
					value: state.marketingOptIn,
					onChanged:
							state.isLoading ? null : (value) => controller.toggleMarketingOptIn(value ?? false),
					subtitle: 'İstediğin zaman ayarlardan değiştirebilirsin.',
				),
				if (state.sessionExpiresAt != null) ...[
					const SizedBox(height: 16),
					Text(
						'Doğrulama oturumu ${_formatRemainingSession(state.sessionExpiresAt!)} sürecek.',
						style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
					),
				],
				const SizedBox(height: 26),
				_GradientButton(
					label: 'Kaydı Tamamla',
					isLoading: state.isLoading,
					onPressed: state.isLoading ? null : controller.finalizeRegistration,
				),
			],
		);
	}

	Widget _buildSuccessStep() {
		return Column(
			key: const ValueKey('successStep'),
			crossAxisAlignment: CrossAxisAlignment.center,
			children: const [
				Icon(Icons.celebration_outlined, color: Colors.white, size: 96),
				SizedBox(height: 24),
				Text(
					'Hesabın hazır! 🎉',
					style: TextStyle(
						color: Colors.white,
						fontSize: 22,
						fontWeight: FontWeight.w700,
					),
					textAlign: TextAlign.center,
				),
				SizedBox(height: 12),
				Text(
					'Feed sayfasına yönlendiriliyorsun. Keyifli cringe avları!',
					style: TextStyle(color: Colors.white70, fontSize: 14),
					textAlign: TextAlign.center,
				),
			],
		);
	}

	Widget _buildUsernameStatus(RegistrationFlowState state) {
		if (!state.usernameTouched) {
			return const SizedBox.shrink();
		}

		if (state.usernameError != null) {
			return Row(
				children: [
					const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
					const SizedBox(width: 6),
					Expanded(
						child: Text(
							state.usernameError!,
							style: const TextStyle(color: Colors.redAccent, fontSize: 12),
						),
					),
				],
			);
		}

		switch (state.usernameStatus) {
			case UsernameStatus.initial:
			case UsernameStatus.dirty:
				return Text(
					'Kullanıcı adı küçük harf, rakam ve alt çizgi içerebilir.',
					style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
				);
			case UsernameStatus.checking:
				return Row(
					children: [
						const SizedBox(
							width: 16,
							height: 16,
							child: CircularProgressIndicator(strokeWidth: 2),
						),
						const SizedBox(width: 8),
						Text(
							'Uygunluk kontrol ediliyor...',
							style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
						),
					],
				);
			case UsernameStatus.available:
				return Row(
					children: const [
						Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 18),
						SizedBox(width: 6),
						Expanded(
							child: Text(
								'Bu kullanıcı adı kullanılabilir!',
								style: TextStyle(color: Colors.greenAccent, fontSize: 12),
							),
						),
					],
				);
			case UsernameStatus.unavailable:
			case UsernameStatus.error:
				return Row(
					children: const [
						Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
						SizedBox(width: 6),
						Expanded(
							child: Text(
								'Bu kullanıcı adı kullanılamıyor.',
								style: TextStyle(color: Colors.redAccent, fontSize: 12),
							),
						),
					],
				);
		}
	}

	Widget _buildAgreementCheckbox({
		required String label,
		required bool value,
		required ValueChanged<bool?>? onChanged,
		String? subtitle,
	}) {
		return Theme(
			data: Theme.of(context).copyWith(unselectedWidgetColor: Colors.white54),
			child: CheckboxListTile(
				value: value,
				onChanged: onChanged,
				dense: true,
				activeColor: AppTheme.accentColor,
				checkColor: Colors.black,
				contentPadding: EdgeInsets.zero,
				controlAffinity: ListTileControlAffinity.leading,
				title: Text(
					label,
					style: const TextStyle(color: Colors.white, fontSize: 13),
				),
				subtitle: subtitle != null
						? Text(
								subtitle,
								style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
							)
						: null,
			),
		);
	}

	Widget _buildTextField({
		required TextEditingController controller,
		required String label,
		required String hint,
		required IconData icon,
		required ValueChanged<String> onChanged,
		TextInputType? keyboardType,
		bool obscureText = false,
		bool enabled = true,
		String? errorText,
		TextCapitalization textCapitalization = TextCapitalization.none,
	}) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Text(
					label,
					style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
				),
				const SizedBox(height: 8),
				TextField(
					controller: controller,
					onChanged: onChanged,
					keyboardType: keyboardType,
					obscureText: obscureText,
					enabled: enabled,
					textCapitalization: textCapitalization,
					cursorColor: AppTheme.accentColor,
					style: const TextStyle(color: Colors.white, fontSize: 14),
					decoration: InputDecoration(
						prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.7)),
						hintText: hint,
						hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
						filled: true,
						fillColor: Colors.white.withOpacity(0.05),
						border: OutlineInputBorder(
							borderRadius: BorderRadius.circular(14),
							borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
						),
						enabledBorder: OutlineInputBorder(
							borderRadius: BorderRadius.circular(14),
							borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
						),
						focusedBorder: OutlineInputBorder(
							borderRadius: BorderRadius.circular(14),
							borderSide: BorderSide(color: AppTheme.accentColor, width: 1.6),
						),
						errorBorder: OutlineInputBorder(
							borderRadius: BorderRadius.circular(14),
							borderSide: const BorderSide(color: Colors.redAccent),
						),
						focusedErrorBorder: OutlineInputBorder(
							borderRadius: BorderRadius.circular(14),
							borderSide: const BorderSide(color: Colors.redAccent, width: 1.6),
						),
						errorText: errorText,
						contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
					),
				),
			],
		);
	}

	void _syncControllers(RegistrationFlowState state) {
		_updateController(_emailController, state.email);
		_updateController(_passwordController, state.password);
		_updateController(_confirmPasswordController, state.confirmPassword);
		_updateController(_otpController, state.otpCode);
		_updateController(_usernameController, state.username);
		_updateController(_fullNameController, state.fullName);
	}

	void _updateController(TextEditingController controller, String value) {
		if (controller.text == value) {
			return;
		}
		controller.value = TextEditingValue(
			text: value,
			selection: TextSelection.collapsed(offset: value.length),
		);
	}

	void _ensureCountdownTicker(RegistrationFlowState state) {
		final remaining = state.otpResendRemaining;
		if (remaining != null && remaining > Duration.zero) {
			_countdownTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
				if (!mounted) {
					return;
				}
				setState(() {});
			});
		} else {
			_countdownTicker?.cancel();
			_countdownTicker = null;
		}
	}

	String _formatDuration(Duration duration) {
		final totalSeconds = duration.inSeconds.clamp(0, 3600);
		final minutes = totalSeconds ~/ 60;
		final seconds = totalSeconds % 60;
		if (minutes > 0) {
			return '${minutes}dk ${seconds.toString().padLeft(2, '0')}sn';
		}
		return '${seconds}s';
	}

	String _formatRemainingSession(DateTime expiresAt) {
		final remaining = expiresAt.difference(DateTime.now());
		if (remaining.isNegative) {
			return 'kısa süre önce doldu';
		}
		return _formatDuration(remaining);
	}

	void _showSnackBar(String message) {
		if (!mounted) {
			return;
		}
		ScaffoldMessenger.of(context)
			..clearSnackBars()
			..showSnackBar(
				SnackBar(
					content: Text(message),
					behavior: SnackBarBehavior.floating,
				),
			);
	}

	String _titleForStep(RegistrationFlowStep step) {
		switch (step) {
			case RegistrationFlowStep.email:
				return 'Başlayalım';
			case RegistrationFlowStep.otp:
				return 'E-postanı doğrula';
			case RegistrationFlowStep.profile:
				return 'Profilini tamamla';
			case RegistrationFlowStep.success:
				return 'Hazırsın';
		}
	}

	String _stepLabel(RegistrationFlowStep step) {
		switch (step) {
			case RegistrationFlowStep.email:
				return 'Giriş Bilgileri';
			case RegistrationFlowStep.otp:
				return 'Doğrulama';
			case RegistrationFlowStep.profile:
				return 'Profil';
			case RegistrationFlowStep.success:
				return 'Tamamlandı';
		}
	}
}

class _GradientButton extends StatelessWidget {
	const _GradientButton({
		required this.label,
		required this.onPressed,
		this.isLoading = false,
	});

	final String label;
	final VoidCallback? onPressed;
	final bool isLoading;

	@override
	Widget build(BuildContext context) {
		return SizedBox(
			height: 52,
			width: double.infinity,
			child: DecoratedBox(
				decoration: BoxDecoration(
					borderRadius: BorderRadius.circular(16),
					gradient: onPressed != null
							? LinearGradient(
									colors: [AppTheme.accentColor, AppTheme.primaryColor],
									begin: Alignment.topLeft,
									end: Alignment.bottomRight,
								)
							: LinearGradient(
									colors: [
										Colors.white.withOpacity(0.12),
										Colors.white.withOpacity(0.08),
									],
								),
				),
				child: ElevatedButton(
					style: ElevatedButton.styleFrom(
						backgroundColor: Colors.transparent,
						shadowColor: Colors.transparent,
						shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
					),
					onPressed: onPressed,
					child: isLoading
							? const SizedBox(
									width: 22,
									height: 22,
									child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
								)
							: Text(
									label,
									style: const TextStyle(
										color: Colors.white,
										fontWeight: FontWeight.w600,
										fontSize: 16,
									),
								),
				),
			),
		);
	}
}

class _BubblesPainter extends CustomPainter {
	_BubblesPainter({required this.bubbles, required this.progress});

	final List<_BubbleConfig> bubbles;
	final double progress;

	@override
	void paint(Canvas canvas, Size size) {
		for (final bubble in bubbles) {
			final dx = (bubble.origin.dx + math.sin((progress + bubble.phase) * math.pi * 2) *
							bubble.horizontalShift)
					.clamp(0.0, 1.0);
			final dy = (bubble.origin.dy + math.cos((progress + bubble.phase) * math.pi * 2) *
							bubble.verticalShift)
					.clamp(0.0, 1.0);

			final center = Offset(dx * size.width, dy * size.height);
			final radius = bubble.radius * (0.85 + math.sin((progress + bubble.phase) * math.pi) * 0.15);

			final rect = Rect.fromCircle(center: center, radius: radius);
			final gradient = RadialGradient(
				colors: bubble.colors,
				stops: const [0.2, 1.0],
			);

			final paint = Paint()
				..shader = gradient.createShader(rect)
				..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);

			canvas.drawCircle(center, radius, paint);
		}
	}

	@override
	bool shouldRepaint(covariant _BubblesPainter oldDelegate) {
		return oldDelegate.progress != progress || oldDelegate.bubbles != bubbles;
	}
}

class _BubbleConfig {
	const _BubbleConfig({
		required this.origin,
		required this.radius,
		required this.horizontalShift,
		required this.verticalShift,
		required this.speed,
		required this.phase,
		required this.colors,
	});

	final Offset origin;
	final double radius;
	final double horizontalShift;
	final double verticalShift;
	final double speed;
	final double phase;
	final List<Color> colors;
}

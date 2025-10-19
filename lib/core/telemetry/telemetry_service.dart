enum TelemetryEventName {
  loginAttempt,
  loginSuccess,
  loginFailure,
  mfaChallenge,
  mfaSuccess,
  accountLock,
  captchaRequired,
  sessionRevoked,
  registrationStepCompleted,
  registrationFailure,
  registrationOtpResent,
  registrationCompleted,
  registrationStageViewed,
  storePurchaseInitiated,
  storePurchaseSucceeded,
  storePurchaseFailed,
  storePurchaseRedirectOpened,
  feedScrolled,
  feedEntryLiked,
  feedEntryShared,
  feedEntryReported,
  tagApprovalPreferenceChanged,
  tagApprovalDecision,
  tagApprovalError,
}

extension TelemetryEventNameX on TelemetryEventName {
  String get code {
    switch (this) {
      case TelemetryEventName.loginAttempt:
        return 'login_attempt';
      case TelemetryEventName.loginSuccess:
        return 'login_success';
      case TelemetryEventName.loginFailure:
        return 'login_failure';
      case TelemetryEventName.mfaChallenge:
        return 'mfa_challenge';
      case TelemetryEventName.mfaSuccess:
        return 'mfa_success';
      case TelemetryEventName.accountLock:
        return 'account_lock';
      case TelemetryEventName.captchaRequired:
        return 'captcha_required';
      case TelemetryEventName.sessionRevoked:
        return 'session_revoked';
      case TelemetryEventName.registrationStepCompleted:
        return 'registration_step_completed';
      case TelemetryEventName.registrationFailure:
        return 'registration_failure';
      case TelemetryEventName.registrationOtpResent:
        return 'registration_otp_resent';
      case TelemetryEventName.registrationCompleted:
        return 'registration_completed';
      case TelemetryEventName.registrationStageViewed:
        return 'registration_stage_viewed';
      case TelemetryEventName.storePurchaseInitiated:
        return 'store_purchase_initiated';
      case TelemetryEventName.storePurchaseSucceeded:
        return 'store_purchase_succeeded';
      case TelemetryEventName.storePurchaseFailed:
        return 'store_purchase_failed';
      case TelemetryEventName.storePurchaseRedirectOpened:
        return 'store_purchase_redirect_opened';
      case TelemetryEventName.feedScrolled:
        return 'feed_scrolled';
      case TelemetryEventName.feedEntryLiked:
        return 'feed_entry_liked';
      case TelemetryEventName.feedEntryShared:
        return 'feed_entry_shared';
      case TelemetryEventName.feedEntryReported:
        return 'feed_entry_reported';
      case TelemetryEventName.tagApprovalPreferenceChanged:
        return 'tag_approval_preference_changed';
      case TelemetryEventName.tagApprovalDecision:
        return 'tag_approval_decision';
      case TelemetryEventName.tagApprovalError:
        return 'tag_approval_error';
    }
  }
}

typedef TelemetryAttributes = Map<String, Object?>;

class TelemetryEvent {
  const TelemetryEvent({
    required this.name,
    required this.timestamp,
    required this.attributes,
  });

  final TelemetryEventName name;
  final DateTime timestamp;
  final TelemetryAttributes attributes;
}

abstract class TelemetryService {
  Future<void> record(TelemetryEvent event);
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/telemetry/telemetry_providers.dart';
import '../domain/repositories/tag_approval_repository.dart';
import 'tag_approval_controller.dart';

final tagApprovalRepositoryProvider = Provider<TagApprovalRepository>(
  (ref) => sl<TagApprovalRepository>(),
);

final tagApprovalControllerProvider =
    StateNotifierProvider<TagApprovalController, TagApprovalState>((ref) {
      final repository = ref.watch(tagApprovalRepositoryProvider);
      final telemetry = ref.watch(telemetryServiceProvider);
      return TagApprovalController(
        repository: repository,
        telemetry: telemetry,
      );
    });

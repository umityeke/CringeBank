import '../models/tag_approval_entry.dart';
import '../models/tag_approval_settings.dart';

abstract class TagApprovalRepository {
  Stream<List<TagApprovalEntry>> watchQueue();

  Stream<TagApprovalSettings> watchSettings();

  Future<void> updateSettings(TagApprovalSettings settings);

  Future<void> approve(String entryId);

  Future<void> reject(String entryId);

  Future<void> dispose();
}

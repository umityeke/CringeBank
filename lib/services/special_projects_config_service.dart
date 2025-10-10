import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/special_project_config.dart';

class SpecialProjectsConfigService {
  SpecialProjectsConfigService._();

  static final SpecialProjectsConfigService instance =
      SpecialProjectsConfigService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('config_special_projects');

  Future<List<SpecialProjectConfig>> fetchActiveProjects({
    bool forceRefresh = false,
  }) async {
    final query = _collection.where('enabled', isEqualTo: true);
    final options = forceRefresh
        ? const GetOptions(source: Source.server)
        : const GetOptions(source: Source.serverAndCache);

    final snapshot = await query.get(options);

    final configs =
        snapshot.docs
            .map(SpecialProjectConfig.fromDocument)
            .where((config) => config.isEnabled)
            .toList()
          ..sort((a, b) => a.priority.compareTo(b.priority));

    return configs;
  }

  Stream<List<SpecialProjectConfig>> watchActiveProjects() {
    return _collection.where('enabled', isEqualTo: true).snapshots().map((
      snapshot,
    ) {
      final configs =
          snapshot.docs
              .map(SpecialProjectConfig.fromDocument)
              .where((config) => config.isEnabled)
              .toList()
            ..sort((a, b) => a.priority.compareTo(b.priority));

      return configs;
    });
  }
}

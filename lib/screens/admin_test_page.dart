import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/admin_panel_service.dart';

/// 🛡️ ADMIN TEST PAGE - Test admin functions
class AdminTestPage extends StatefulWidget {
  const AdminTestPage({super.key});

  @override
  State<AdminTestPage> createState() => _AdminTestPageState();
}

class _AdminTestPageState extends State<AdminTestPage> {
  final _adminService = AdminPanelService.instance;
  final _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool? _isSuperAdmin;
  String _output = '';

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    setState(() => _isLoading = true);

    try {
      final isSA = await _adminService.isSuperAdmin;
      setState(() {
        _isSuperAdmin = isSA;
        _output = isSA
            ? '✅ Super Admin: ${_auth.currentUser?.email}'
            : '❌ Not super admin. Please logout and login.';
      });
    } catch (e) {
      setState(() {
        _output = '❌ Error checking status: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runCategoryAdminTest() async {
    setState(() {
      _isLoading = true;
      _output = '🧪 Running category admin test...\n';
    });

    try {
      await _adminService.testAssignCategoryAdmin();
      setState(() {
        _output += '\n✅ Test completed successfully!';
      });
    } catch (e) {
      setState(() {
        _output += '\n❌ Test failed: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runCompetitionTest() async {
    setState(() {
      _isLoading = true;
      _output = '🧪 Running competition test...\n';
    });

    try {
      await _adminService.testCreateCompetition();
      setState(() {
        _output += '\n✅ Test completed successfully!';
      });
    } catch (e) {
      setState(() {
        _output += '\n❌ Test failed: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛡️ Admin Test Panel'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: _isSuperAdmin == true
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isSuperAdmin == true
                              ? Icons.verified_user
                              : Icons.warning,
                          color: _isSuperAdmin == true
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isSuperAdmin == true
                              ? 'Super Admin'
                              : 'Not Super Admin',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _auth.currentUser?.email ?? 'Not logged in',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (_isSuperAdmin == false) ...[
                      const SizedBox(height: 8),
                      const Text(
                        '⚠️ Logout and login again to refresh claims',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Test Buttons
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _checkAdminStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Status'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: (_isLoading || _isSuperAdmin != true)
                  ? null
                  : _runCategoryAdminTest,
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Test: Category Admin'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: (_isLoading || _isSuperAdmin != true)
                  ? null
                  : _runCompetitionTest,
              icon: const Icon(Icons.emoji_events),
              label: const Text('Test: Create Competition'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            // Output Console
            Expanded(
              child: Card(
                color: Colors.grey.shade900,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Text(
                      _output.isEmpty ? '📋 Console output...' : _output,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Loading Indicator
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

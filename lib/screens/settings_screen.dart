import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/downloads_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _savePath = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadPath();
  }

  Future<void> _loadPath() async {
    final dir = await getExternalStorageDirectory();
    if (mounted) {
      setState(() {
        _savePath = '${dir?.path}/Download';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: Theme.of(context).textTheme.titleLarge),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionHeader('Engine'),
          _buildSettingTile(
            icon: Icons.system_update,
            title: 'Update Engine',
            subtitle: 'Recommended before downloading',
            trailing: TextButton(
              onPressed: () => provider.updateEngine(),
              child: const Text('Update'),
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('Storage'),
          _buildSettingTile(
            icon: Icons.folder_open,
            title: 'Download Path',
            subtitle: _savePath,
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('More'),
          _buildSettingTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'Read our terms and conditions',
            onTap: () {
              // Open Privacy Policy
            },
          ),
          _buildSettingTile(
            icon: Icons.info_outline,
            title: 'Version',
            subtitle: '1.0.0 (Production Build)',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: const Color(0xFF0061FF)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        trailing: trailing,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
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
        title: Text(
          'Settings',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionHeader('Download Engine'),
          _buildSettingTile(
            icon: HugeIcons.strokeRoundedAiSearch,
            title: 'Automatic Updates',
            subtitle: 'Engine stays current for better reliability',
            trailing: HugeIcon(
              icon: HugeIcons.strokeRoundedTick02,
              color: Colors.green,
              size: 20,
            ),
          ),
          _buildSettingTile(
            icon: HugeIcons.strokeRoundedDownload01,
            title: 'Force Engine Update',
            subtitle: 'Manual refresh if analysis is failing',
            trailing: TextButton(
              onPressed: provider.isUpdating
                  ? null
                  : () => provider.updateEngine(),
              child: Text(provider.isUpdating ? 'Updating...' : 'Check'),
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('File Management'),
          _buildSettingTile(
            icon: HugeIcons.strokeRoundedFolder02,
            title: 'Storage Location',
            subtitle: _savePath,
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('About AnyVid'),
          _buildSettingTile(
            icon: HugeIcons.strokeRoundedUserShield01,
            title: 'Privacy Policy',
            subtitle: 'Your data stays on your device',
            onTap: () {
              // Open Privacy Policy
            },
          ),
          _buildSettingTile(
            icon: HugeIcons.strokeRoundedInformationCircle,
            title: 'App Version',
            subtitle: '1.0.1 (Production)',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required dynamic icon,
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
        border: Border.all(color: Colors.grey[100]!),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0061FF).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: HugeIcon(icon: icon, color: const Color(0xFF0061FF), size: 18),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        trailing: trailing,
      ),
    );
  }
}

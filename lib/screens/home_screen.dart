import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../providers/downloads_provider.dart';
import 'widgets/analysis_bottom_sheet.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Delay permissions to allow UI to render first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _requestPermissions();
      });
    });
  }

  Future<void> _requestPermissions() async {
    await [Permission.storage, Permission.notification].request();

    // For Android 13+ video/audio permissions
    if (Platform.isAndroid) {
      await [Permission.videos, Permission.audio].request();
    }
  }

  Future<void> _handleAnalyze() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final provider = Provider.of<DownloadsProvider>(context, listen: false);
    await provider.analyzeLink(url);

    if (mounted && provider.currentMetadata != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const AnalysisBottomSheet(),
      );
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      setState(() {
        _urlController.text = data!.text!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadsProvider>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              HugeIcon(
                icon: HugeIcons.strokeRoundedVideo01,
                color: Color(0xFF0061FF),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'AnyVid',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Download any video from YouTube & Instagram for free.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 48),

              // Input Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Link to video',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        hintText: 'Paste link here...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 20,
                        ),
                        prefixIcon: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedLink01,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: TextButton(
                            onPressed: _pasteFromClipboard,
                            child: const Text('Paste'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Analyze Button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: provider.isAnalyzing ? null : _handleAnalyze,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0061FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  icon: provider.isAnalyzing
                      ? const SizedBox.shrink()
                      : HugeIcon(
                          icon: HugeIcons.strokeRoundedSearch01,
                          color: Colors.white,
                          size: 20,
                        ),
                  label: provider.isAnalyzing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Analyze Video',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 32),

              // Supported Apps
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAppBadge('YouTube', HugeIcons.strokeRoundedYoutube),
                    _buildAppBadge(
                      'Instagram',
                      HugeIcons.strokeRoundedInstagram,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBadge(String name, dynamic icon) {
    return Row(
      children: [
        HugeIcon(icon: icon, color: Colors.grey[700]!, size: 18),
        const SizedBox(width: 8),
        Text(
          name,
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

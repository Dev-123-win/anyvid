import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
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
              Text('AnyVid', style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 8),
              Text(
                'Download high-quality videos locally.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 40),

              // Input Field
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
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
                    hintText: 'Paste video link here...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.content_paste,
                        color: Color(0xFF0061FF),
                      ),
                      onPressed: _pasteFromClipboard,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Analyze Button
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed: provider.isAnalyzing ? null : _handleAnalyze,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0061FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: provider.isAnalyzing
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Analyze Link',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 100),

              // Loading Animation Placeholder
              if (provider.isAnalyzing)
                Center(
                  child: Lottie.network(
                    'https://assets9.lottiefiles.com/packages/lf20_76biv8.json', // Search animation
                    height: 200,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

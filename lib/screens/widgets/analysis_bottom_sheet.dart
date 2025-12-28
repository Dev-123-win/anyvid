import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../../providers/downloads_provider.dart';
import '../../models/video_metadata.dart';
import '../../services/ad_service.dart';

class AnalysisBottomSheet extends StatelessWidget {
  const AnalysisBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadsProvider>();
    final metadata = provider.currentMetadata;

    if (metadata == null) return const SizedBox.shrink();

    // Group options
    final videoOptions = metadata.options.where((o) => o.ext != 'mp3').toList();
    final audioOptions = metadata.options.where((o) => o.ext == 'mp3').toList();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Thumbnail & Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  metadata.thumbnail,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey[200],
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedVideo01,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metadata.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0061FF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        metadata.type.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF0061FF),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Scrollable Options
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (videoOptions.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Video Quality',
                      icon: HugeIcons.strokeRoundedVideo01,
                    ),
                    ...videoOptions.map((opt) => _QualityItem(option: opt)),
                    const SizedBox(height: 24),
                  ],
                  if (audioOptions.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Audio Only',
                      icon: HugeIcons.strokeRoundedMusicNote01,
                    ),
                    ...audioOptions.map((opt) => _QualityItem(option: opt)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final dynamic icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          HugeIcon(icon: icon, color: Colors.grey[800]!, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityItem extends StatelessWidget {
  final VideoOption option;

  const _QualityItem({required this.option});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<DownloadsProvider>();
    final isPremium =
        option.label == '1080p' || option.label == '2k' || option.label == '4k';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          if (isPremium) {
            _showUnlockDialog(context, provider);
          } else {
            provider.startDownload(option);
            Navigator.pop(context); // Close sheet
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0061FF).withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: option.ext == 'mp3'
                      ? HugeIcons.strokeRoundedMusicNote01
                      : HugeIcons.strokeRoundedPlayList,
                  color: const Color(0xFF0061FF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${option.ext.toUpperCase()} • ${option.size}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedTick01,
                        color: Colors.amber,
                        size: 12,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Unlock',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 12),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: Colors.grey[400]!,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnlockDialog(BuildContext context, DownloadsProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Download High Quality?'),
        content: const Text(
          'Please watch a short ad to unlock this resolution for free.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Maybe Later',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              AdService.showRewarded((success) {
                if (success && context.mounted) {
                  provider.startDownload(option);
                  Navigator.pop(context); // Close sheet
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0061FF),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Watch & Download'),
          ),
        ],
      ),
    );
  }
}

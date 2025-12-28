import 'package:flutter/material.dart';
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

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.all(24),
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
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  metadata.thumbnail,
                  width: 120,
                  height: 68,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 120,
                    height: 68,
                    color: Colors.grey[200],
                    child: const Icon(Icons.video_library),
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
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      metadata.type.toUpperCase(),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
          Text(
            'Select Quality',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 16),

          // Options List
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: metadata.options.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final option = metadata.options[index];
                return _QualityItem(
                  option: option,
                  onTap: () {
                    final isHighQuality =
                        option.label.contains('1080p') ||
                        option.label.contains('4K');

                    if (isHighQuality) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Unlock High Quality?'),
                          content: const Text(
                            'Watch a short video to unlock 1080p/4K downloads.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                AdService.showRewarded((success) {
                                  if (success) {
                                    provider.startDownload(option);
                                    Navigator.pop(context);
                                  }
                                });
                              },
                              child: const Text('Watch & Unlock'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      provider.startDownload(option);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Download started...')),
                      );
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _QualityItem extends StatelessWidget {
  final VideoOption option;
  final VoidCallback onTap;

  const _QualityItem({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isHighQuality =
        option.label.contains('1080p') || option.label.contains('4K');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              option.ext == 'mp3' ? Icons.headset : Icons.slow_motion_video,
              color: const Color(0xFF0061FF),
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
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            if (isHighQuality)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_open, size: 14, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      'Premium',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_file/open_file.dart';
import '../providers/downloads_provider.dart';
import '../models/download_task.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadsProvider>();
    final history = provider.history;
    final activeTasks = provider.activeTasks;

    return Scaffold(
      appBar: AppBar(
        title: Text('Downloads', style: Theme.of(context).textTheme.titleLarge),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.refreshHistory(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.refreshHistory(),
        child: CustomScrollView(
          slivers: [
            // Active Tasks
            if (activeTasks.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _ActiveTaskItem(task: activeTasks[index]),
                    childCount: activeTasks.length,
                  ),
                ),
              ),

            // History
            if (history.isEmpty && activeTasks.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.download_for_offline_outlined,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No downloads yet',
                        style: TextStyle(color: Colors.grey[400], fontSize: 18),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    // Insert Native Ad every 4th item
                    if (index != 0 && index % 4 == 0) {
                      return const _NativeAdPlaceholder();
                    }

                    // Ajust index for history access if ads are inserted
                    final historyIndex = index - (index ~/ 4);
                    if (historyIndex >= history.length) return null;

                    return _HistoryItem(file: history[historyIndex] as File);
                  }, childCount: history.length + (history.length ~/ 4)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActiveTaskItem extends StatelessWidget {
  final DownloadTask task;
  const _ActiveTaskItem({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF0061FF).withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.downloading, color: Color(0xFF0061FF)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${task.progress.toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: task.progress / 100,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0061FF)),
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                task.eta,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Text(
                'Downloading...',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final File file;
  const _HistoryItem({required this.file});

  @override
  Widget build(BuildContext context) {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final isVideo = fileName.endsWith('.mp4');

    return FutureBuilder<FileStat>(
      future: file.stat(),
      builder: (context, snapshot) {
        final stat = snapshot.data;
        final sizeRaw = stat?.size ?? 0;
        final size = (sizeRaw / 1024 / 1024).toStringAsFixed(1);
        final date = stat?.modified.toLocal().toString().split(' ')[0] ?? '...';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            onTap: () => OpenFile.open(file.path),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: (isVideo ? Colors.blue[50] : Colors.orange[50]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isVideo ? Icons.movie_outlined : Icons.audiotrack_outlined,
                color: isVideo ? Colors.blue : Colors.orange,
              ),
            ),
            title: Text(
              fileName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(stat == null ? 'Loading...' : '$size MB • $date'),
            trailing: const Icon(
              Icons.play_circle_fill,
              color: Color(0xFF0061FF),
              size: 32,
            ),
          ),
        );
      },
    );
  }
}

class _NativeAdPlaceholder extends StatelessWidget {
  const _NativeAdPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Stack(
        children: [
          const Center(child: Text('Native Ad Placeholder')),
          Position8(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Ad',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Fixed Positioned for internal widgets
class Position8 extends Positioned {
  const Position8({
    super.key,
    required super.top,
    required super.right,
    required super.child,
  });
}

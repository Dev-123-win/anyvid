import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/video_metadata.dart';
import '../models/download_task.dart';
import '../services/ad_service.dart';

class DownloadsProvider with ChangeNotifier {
  static const _channel = MethodChannel('com.streamsaver.engine/channel');

  VideoMetadata? _currentMetadata;
  VideoMetadata? get currentMetadata => _currentMetadata;

  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;

  bool _isUpdating = false;
  bool get isUpdating => _isUpdating;

  final Map<String, DownloadTask> _activeTasks = {};
  List<DownloadTask> get activeTasks => _activeTasks.values.toList();

  List<FileSystemEntity> _history = [];
  List<FileSystemEntity> get history => _history;

  DownloadsProvider() {
    _initChannelListeners();
    refreshHistory();
    cleanTemporaryFiles();
  }

  void _initChannelListeners() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onProgress':
          final String url = call.arguments['url'];
          final double progress = (call.arguments['progress'] as num)
              .toDouble();
          final String eta = call.arguments['eta'] ?? '';

          if (_activeTasks.containsKey(url)) {
            _activeTasks[url]!.progress = progress;
            _activeTasks[url]!.eta = eta;
            _activeTasks[url]!.state = DownloadState.downloading;
            notifyListeners();
          }
          break;
        case 'onSuccess':
          final String? path = call.arguments['path'];
          final String? url = call.arguments['url'];
          refreshHistory();

          if (url != null && _activeTasks.containsKey(url)) {
            final task = _activeTasks[url]!;
            task.state = DownloadState.success;
            task.filePath = path;

            // Trigger Interstitial Ad on Success
            AdService.showInterstitial(() {
              // Done
            });
          } else {
            // Fallback for unexpected cases: mark all downloading as success
            for (var task in _activeTasks.values) {
              if (task.state == DownloadState.downloading) {
                task.state = DownloadState.success;
                task.filePath = path;
              }
            }
          }
          notifyListeners();
          break;
      }
    });
  }

  Future<void> analyzeLink(String url) async {
    _isAnalyzing = true;
    _currentMetadata = null;
    notifyListeners();

    try {
      final String result = await _channel.invokeMethod('analyzeLink', {
        'url': url,
      });
      final Map<String, dynamic> data = jsonDecode(result);
      _currentMetadata = VideoMetadata.fromJson(data, url);
    } on PlatformException catch (e) {
      debugPrint("Analysis failed: ${e.message}");
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  Future<void> startDownload(VideoOption option) async {
    if (_currentMetadata == null) return;

    final task = DownloadTask(
      url: _currentMetadata!.originalUrl,
      title: _currentMetadata!.title,
      state: DownloadState.downloading,
    );
    _activeTasks[task.url] = task;
    notifyListeners();

    try {
      if (_currentMetadata!.type == 'instagram') {
        await _channel.invokeMethod('downloadInsta', {
          'url': _currentMetadata!.originalUrl,
        });
      } else {
        await _channel.invokeMethod('downloadVideo', {
          'url': _currentMetadata!.originalUrl,
          'formatId': option.id,
          'isAudio': option.ext == 'mp3',
          'title': _currentMetadata!.title,
        });
      }
    } on PlatformException catch (e) {
      task.state = DownloadState.failed;
      notifyListeners();
      debugPrint("Download failed: ${e.message}");
    }
  }

  Future<void> refreshHistory() async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        final downloadDir = Directory('${directory.path}/Download');
        if (await downloadDir.exists()) {
          final List<FileSystemEntity> entities = await downloadDir
              .list()
              .toList();
          _history = entities
              .where(
                (item) =>
                    item is File &&
                    (item.path.endsWith('.mp4') || item.path.endsWith('.mp3')),
              )
              .toList();
          // Non-blocking sort by pre-fetching stats
          final List<MapEntry<FileSystemEntity, DateTime>> historyWithTime = [];
          for (var entity in _history) {
            final stat = await entity.stat();
            historyWithTime.add(MapEntry(entity, stat.modified));
          }

          historyWithTime.sort((a, b) => b.value.compareTo(a.value));
          _history = historyWithTime.map((e) => e.key).toList();

          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Error refreshing history: $e");
    }
  }

  Future<void> updateEngine() async {
    _isUpdating = true;
    notifyListeners();
    try {
      await _channel.invokeMethod('updateEngine');
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<void> cleanTemporaryFiles() async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        final downloadDir = Directory('${directory.path}/Download');
        if (await downloadDir.exists()) {
          final now = DateTime.now();
          await for (var entity in downloadDir.list()) {
            if (entity is File) {
              final name = entity.path.toLowerCase();
              if (name.endsWith('.part') || name.endsWith('.ytdl')) {
                final stat = await entity.stat();
                // Delete if older than 24 hours
                if (now.difference(stat.modified).inHours > 24) {
                  await entity.delete();
                  debugPrint("Deleted temp file: ${entity.path}");
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error cleaning temporary files: $e");
    }
  }
}

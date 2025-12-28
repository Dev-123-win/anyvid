enum DownloadState { idle, downloading, success, failed }

class DownloadTask {
  final String url;
  final String title;
  double progress;
  String eta;
  DownloadState state;
  String? filePath;

  DownloadTask({
    required this.url,
    required this.title,
    this.progress = 0.0,
    this.eta = '',
    this.state = DownloadState.idle,
    this.filePath,
  });
}

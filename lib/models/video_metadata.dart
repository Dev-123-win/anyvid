class VideoMetadata {
  final String title;
  final String thumbnail;
  final String description;
  final int? duration;
  final List<VideoOption> options;
  final String type; // 'youtube' or 'instagram'
  final String originalUrl;

  VideoMetadata({
    required this.title,
    required this.thumbnail,
    required this.description,
    this.duration,
    required this.options,
    required this.type,
    required this.originalUrl,
  });

  factory VideoMetadata.fromJson(
    Map<String, dynamic> json,
    String originalUrl,
  ) {
    var opts = <VideoOption>[];
    if (json['options'] != null) {
      json['options'].forEach((v) {
        opts.add(VideoOption.fromJson(v));
      });
    }
    return VideoMetadata(
      title: json['title'] ?? 'Unknown Title',
      thumbnail: json['thumbnail'] ?? '',
      description: json['description'] ?? '',
      duration: json['duration'],
      options: opts,
      type: json['type'] ?? 'youtube',
      originalUrl: originalUrl,
    );
  }
}

class VideoOption {
  final String id;
  final String label;
  final String size;
  final String ext;

  VideoOption({
    required this.id,
    required this.label,
    required this.size,
    required this.ext,
  });

  factory VideoOption.fromJson(Map<String, dynamic> json) {
    return VideoOption(
      id: json['id'] ?? '',
      label: json['label'] ?? '',
      size: json['size'] ?? 'Unknown',
      ext: json['ext'] ?? 'mp4',
    );
  }
}

class MirrorLinks {
  final String status;
  final String? directLink;
  final String? linkType;
  final String? fileName;
  final String? r2;
  final String? r2Status;
  final String? gofile;
  final String? gofileDirect;
  final String? vikingfile;
  final String? uploadhub;
  final String? filepress;
  final String? drivehubUrl;
  final String? error;

  MirrorLinks({
    required this.status,
    this.directLink,
    this.linkType,
    this.fileName,
    this.r2,
    this.r2Status,
    this.gofile,
    this.gofileDirect,
    this.vikingfile,
    this.uploadhub,
    this.filepress,
    this.drivehubUrl,
    this.error,
  });

  factory MirrorLinks.fromJson(Map<String, dynamic> json) {
    final mirrors = json['mirrors'] as Map<String, dynamic>? ?? {};

    return MirrorLinks(
      status: json['status'] ?? 'error',
      directLink: json['direct_link'],
      linkType: json['link_type'],
      fileName: json['file_name'],
      r2: mirrors['r2'],
      r2Status: mirrors['r2_status'],
      gofile: mirrors['gofile'],
      gofileDirect: mirrors['gofile_direct'],
      vikingfile: mirrors['vikingfile'],
      uploadhub: mirrors['uploadhub'],
      filepress: mirrors['filepress'],
      drivehubUrl: json['drivehub_url'],
      error: json['error'],
    );
  }

  bool isDirect(String? u) {
    if (u == null || u.isEmpty) return false;
    if (u.contains('gofile.io/d/') || u.contains('vikingfile.com') || u.contains('filepress')) return false;
    return u.contains('.mkv') ||
        u.contains('.mp4') ||
        u.contains('workers.dev') ||
        u.contains('pixeldrain.com/api/file') ||
        u.contains('hubcloud') ||
        u.contains('indi-files') ||
        u.contains('/api/gofile-dl') ||
        u.contains('/api/download');
  }

  String? get bestDirectVideoUrl {
    if (isDirect(directLink)) return directLink;
    if (r2 != null && (r2Status == 'active' || r2Status == null) && isDirect(r2)) return r2;
    if (isDirect(gofileDirect)) return gofileDirect;
    return null;
  }

  bool get hasDirectVideoUrl => bestDirectVideoUrl != null;

  bool get hasActiveLinks => directLink != null || (r2 != null && (r2Status == 'active' || r2Status == null)) || gofile != null || vikingfile != null || filepress != null || uploadhub != null;
  String? get bestDownloadUrl => bestDirectVideoUrl ?? directLink ?? ((r2 != null && (r2Status == 'active' || r2Status == null)) ? r2 : (gofileDirect ?? gofile ?? vikingfile ?? filepress));
}

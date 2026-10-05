class MirrorLinks {
  final String status;
  final String? directLink;
  final String? linkType;
  final String? r2;
  final String? r2Status;
  final String? gofile;
  final String? vikingfile;
  final String? uploadhub;
  final String? filepress;
  final String? drivehubUrl;
  final String? error;

  MirrorLinks({
    required this.status,
    this.directLink,
    this.linkType,
    this.r2,
    this.r2Status,
    this.gofile,
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
      r2: mirrors['r2'],
      r2Status: mirrors['r2_status'],
      gofile: mirrors['gofile'],
      vikingfile: mirrors['vikingfile'],
      uploadhub: mirrors['uploadhub'],
      filepress: mirrors['filepress'],
      drivehubUrl: json['drivehub_url'],
      error: json['error'],
    );
  }

  bool get hasActiveLinks => directLink != null || (r2 != null && (r2Status == 'active' || r2Status == null)) || gofile != null || vikingfile != null || filepress != null || uploadhub != null;
  String? get bestDownloadUrl => directLink ?? ((r2 != null && (r2Status == 'active' || r2Status == null)) ? r2 : (gofile ?? vikingfile ?? filepress));
}

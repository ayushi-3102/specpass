enum AuditStatus {
  pass,
  warning,
  fail,
}

class ComplianceCheckItem {
  final String id;
  final String title;
  final String description;
  final String measuredValue;
  final String requiredSpec;
  final AuditStatus status;

  const ComplianceCheckItem({
    required this.id,
    required this.title,
    required this.description,
    required this.measuredValue,
    required this.requiredSpec,
    required this.status,
  });

  bool get isPassed => status == AuditStatus.pass;
}

class ComplianceAuditResult {
  final double scorePercent; // e.g. 98.4%
  final double measuredHeadRatio; // e.g. 0.62
  final double measuredTiltDegrees; // e.g. 0.2
  final int detectedFaceCount; // 1
  final bool eyesOpenAndDirect;
  final bool backgroundNeutralized;
  final bool glassesDetected;
  final int exportDpi;
  final List<ComplianceCheckItem> items;

  const ComplianceAuditResult({
    required this.scorePercent,
    required this.measuredHeadRatio,
    required this.measuredTiltDegrees,
    required this.detectedFaceCount,
    required this.eyesOpenAndDirect,
    required this.backgroundNeutralized,
    required this.glassesDetected,
    required this.exportDpi,
    required this.items,
  });

  bool get isCompliant => items.every((item) => item.status != AuditStatus.fail);

  static ComplianceAuditResult mockPassingResult({
    required double headRatio,
    required String countryName,
  }) {
    return ComplianceAuditResult(
      scorePercent: 98.4,
      measuredHeadRatio: headRatio,
      measuredTiltDegrees: 0.2,
      detectedFaceCount: 1,
      eyesOpenAndDirect: true,
      backgroundNeutralized: true,
      glassesDetected: false,
      exportDpi: 300,
      items: [
        ComplianceCheckItem(
          id: 'face_geometry',
          title: 'Single Face & Geometry',
          description: 'Single human subject detected with balanced facial symmetry.',
          measuredValue: '1 Face Detected',
          requiredSpec: 'Exact 1 Face',
          status: AuditStatus.pass,
        ),
        ComplianceCheckItem(
          id: 'head_ratio',
          title: 'Chin-to-Crown Ratio',
          description: 'Vertical biometric head proportion relative to frame height.',
          measuredValue: '${(headRatio * 100).toStringAsFixed(1)}% Total Frame',
          requiredSpec: '50% — 69% (US) / 70% — 80% (EU)',
          status: AuditStatus.pass,
        ),
        ComplianceCheckItem(
          id: 'head_tilt',
          title: 'Level & Tilt Alignment',
          description: 'Euler rotational angle roll/pitch deviation from true perpendicular.',
          measuredValue: '0.2° Roll / 0.1° Pitch',
          requiredSpec: '< 3.0° Max Deviation',
          status: AuditStatus.pass,
        ),
        ComplianceCheckItem(
          id: 'eye_gaze',
          title: 'Eye Gaze & Openness',
          description: 'Both pupils visible, forward gaze directly locked at camera sensor.',
          measuredValue: 'Direct Gaze · 100% Open',
          requiredSpec: 'Both Eyes Fully Visible',
          status: AuditStatus.pass,
        ),
        ComplianceCheckItem(
          id: 'background',
          title: 'Background Neutralization',
          description: 'AI-segmented 100% flat background free of shadows or wallpaper.',
          measuredValue: 'Solid Pure White (#FFFFFF)',
          requiredSpec: '100% Shadowless Backdrop',
          status: AuditStatus.pass,
        ),
        ComplianceCheckItem(
          id: 'eyeglasses',
          title: 'Eyeglasses & Occlusion',
          description: 'Checks for frame shadow, tinted lenses, or eye obstruction.',
          measuredValue: 'No Eyeglasses Detected',
          requiredSpec: 'No Glasses (US Dept of State Rule)',
          status: AuditStatus.pass,
        ),
        ComplianceCheckItem(
          id: 'resolution',
          title: 'Physical Print Resolution',
          description: 'Output raster pixel density calibrated for standard lab printers.',
          measuredValue: '300 DPI Lossless RAW',
          requiredSpec: '≥ 300 DPI Required',
          status: AuditStatus.pass,
        ),
      ],
    );
  }
}

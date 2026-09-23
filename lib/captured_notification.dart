class CapturedNotification {
  const CapturedNotification({
    required this.id,
    required this.packageName,
    required this.appName,
    required this.title,
    required this.content,
    required this.timestamp,
    this.importanceScore,
  });

  final String id;
  final String packageName;
  final String appName;
  final String title;
  final String content;
  final DateTime timestamp;
  final double? importanceScore;

  factory CapturedNotification.fromPlatformMap(Map<Object?, Object?> values) {
    String stringValue(String key) => values[key]?.toString().trim() ?? '';
    final timestampValue = stringValue('timestamp');

    return CapturedNotification(
      id: stringValue('id'),
      packageName: stringValue('packageName'),
      appName: stringValue('appName'),
      title: stringValue('title'),
      content: stringValue('content'),
      timestamp: DateTime.tryParse(timestampValue)?.toLocal() ?? DateTime.now(),
      importanceScore: null,
    );
  }
    factory CapturedNotification.fromDatabaseMap(Map<String, Object?> values) {
    String stringValue(String key) => values[key]?.toString().trim() ?? '';
    final timestampValue = stringValue('timestamp');

    return CapturedNotification(
      id: stringValue('id'),
      packageName: stringValue('package_name'),
      appName: stringValue('app_name'),
      title: stringValue('title'),
      content: stringValue('content'),
      timestamp: DateTime.tryParse(timestampValue)?.toLocal() ?? DateTime.now(),
      importanceScore: (values['importance_score'] as num?)?.toDouble(),
    );
  }
}

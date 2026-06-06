class CallLog {
  final String id;
  final String caller;
  final String receiver;
  final String callType; // "voice" | "video"
  final String status;   // "outgoing" | "incoming" | "missed" | "completed"
  final int duration;    // seconds
  final DateTime timestamp;

  const CallLog({
    required this.id,
    required this.caller,
    required this.receiver,
    required this.callType,
    required this.status,
    required this.duration,
    required this.timestamp,
  });

  factory CallLog.fromJson(Map<String, dynamic> json) {
    return CallLog(
      id: json['_id']?.toString() ?? '',
      caller: json['caller']?.toString() ?? '',
      receiver: json['receiver']?.toString() ?? '',
      callType: json['call_type']?.toString() ?? 'voice',
      status: json['status']?.toString() ?? 'incoming',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'caller': caller,
        'receiver': receiver,
        'call_type': callType,
        'status': status,
        'duration': duration,
        'timestamp': timestamp.toIso8601String(),
      };
}

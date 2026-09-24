class VoiceProfile {
  final String id;
  final String name;
  final String? description;
  final String? referenceAudioPath;
  final String speakerId;
  final double speed;
  final VoiceEngine engine;

  const VoiceProfile({
    required this.id,
    required this.name,
    this.description,
    this.referenceAudioPath,
    this.speakerId = 'default',
    this.speed = 1.0,
    this.engine = VoiceEngine.cosyVoice,
  });

  VoiceProfile copyWith({
    String? name,
    String? description,
    String? referenceAudioPath,
    String? speakerId,
    double? speed,
    VoiceEngine? engine,
  }) =>
      VoiceProfile(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        referenceAudioPath: referenceAudioPath ?? this.referenceAudioPath,
        speakerId: speakerId ?? this.speakerId,
        speed: speed ?? this.speed,
        engine: engine ?? this.engine,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'referenceAudioPath': referenceAudioPath,
        'speakerId': speakerId,
        'speed': speed,
        'engine': engine.name,
      };

  factory VoiceProfile.fromMap(Map<String, dynamic> map) => VoiceProfile(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        referenceAudioPath: map['referenceAudioPath'] as String?,
        speakerId: map['speakerId'] as String? ?? 'default',
        speed: (map['speed'] as num?)?.toDouble() ?? 1.0,
        engine: VoiceEngine.values.byName(map['engine'] as String? ?? 'cosyVoice'),
      );
}

enum VoiceEngine { cosyVoice, voicevox }

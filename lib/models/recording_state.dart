enum RecordingState {
  idle,
  recording,
  paused,
  completed,
  playing,
  playingPaused,
}

enum AudioPlayerState {
  stopped,
  playing,
  paused,
  loading,
}

class VoiceRecordingData {
  final String? filePath;
  final Duration duration;
  final List<double> amplitudes;
  final RecordingState state;
  final Duration? playbackPosition;
  final AudioPlayerState playerState;

  const VoiceRecordingData({
    this.filePath,
    this.duration = Duration.zero,
    this.amplitudes = const [],
    this.state = RecordingState.idle,
    this.playbackPosition,
    this.playerState = AudioPlayerState.stopped,
  });

  VoiceRecordingData copyWith({
    String? filePath,
    Duration? duration,
    List<double>? amplitudes,
    RecordingState? state,
    Duration? playbackPosition,
    AudioPlayerState? playerState,
  }) {
    return VoiceRecordingData(
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      amplitudes: amplitudes ?? this.amplitudes,
      state: state ?? this.state,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      playerState: playerState ?? this.playerState,
    );
  }

  bool get isRecording => state == RecordingState.recording;
  bool get isPaused => state == RecordingState.paused;
  bool get isCompleted =>
      state == RecordingState.completed ||
      state == RecordingState.playing ||
      state == RecordingState.playingPaused;
  bool get isIdle => state == RecordingState.idle;
  bool get isPlaying => state == RecordingState.playing;
  bool get hasRecording => filePath != null && filePath!.isNotEmpty;

  String get formattedDuration {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get formattedPlaybackPosition {
    if (playbackPosition == null) return '00:00';
    final minutes = playbackPosition!.inMinutes.toString().padLeft(2, '0');
    final seconds =
        (playbackPosition!.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class RecordingGestureData {
  final bool isLongPressing;
  final bool isLocked;
  final bool isCancelling;
  final double initialX;
  final double initialY;
  final double currentX;
  final double currentY;
  final double cancelThreshold;
  final double lockThreshold;

  const RecordingGestureData({
    this.isLongPressing = false,
    this.isLocked = false,
    this.isCancelling = false,
    this.initialX = 0,
    this.initialY = 0,
    this.currentX = 0,
    this.currentY = 0,
    this.cancelThreshold = 100,
    this.lockThreshold = 80,
  });

  RecordingGestureData copyWith({
    bool? isLongPressing,
    bool? isLocked,
    bool? isCancelling,
    double? initialX,
    double? initialY,
    double? currentX,
    double? currentY,
    double? cancelThreshold,
    double? lockThreshold,
  }) {
    return RecordingGestureData(
      isLongPressing: isLongPressing ?? this.isLongPressing,
      isLocked: isLocked ?? this.isLocked,
      isCancelling: isCancelling ?? this.isCancelling,
      initialX: initialX ?? this.initialX,
      initialY: initialY ?? this.initialY,
      currentX: currentX ?? this.currentX,
      currentY: currentY ?? this.currentY,
      cancelThreshold: cancelThreshold ?? this.cancelThreshold,
      lockThreshold: lockThreshold ?? this.lockThreshold,
    );
  }

  double get horizontalDistance => (currentX - initialX).abs();
  double get verticalDistance => (initialY - currentY).abs();
  bool get shouldCancel => horizontalDistance > cancelThreshold;
  bool get shouldLock => verticalDistance > lockThreshold;
  double get cancelProgress =>
      (horizontalDistance / cancelThreshold).clamp(0.0, 1.0);
}

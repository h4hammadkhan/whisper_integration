import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:just_waveform/just_waveform.dart';
import '../models/recording_state.dart';

class AudioService extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  final SoLoud _soloud = SoLoud.instance;

  Timer? _recordingTimer;
  Timer? _amplitudeTimer;
  Timer? _playbackTimer;

  SoundHandle? _currentSoundHandle;
  StreamSubscription<double>? _amplitudeSubscription;

  VoiceRecordingData _recordingData = const VoiceRecordingData();
  RecordingGestureData _gestureData = const RecordingGestureData();

  VoiceRecordingData get recordingData => _recordingData;
  RecordingGestureData get gestureData => _gestureData;

  bool _isInitialized = false;
  List<double> _amplitudes = [];
  double _currentAmplitude = 0.0;

  AudioService() {
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    try {
      await _soloud.init();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing audio: $e');
    }
  }

  Future<bool> checkPermissions() async {
    return await _recorder.hasPermission();
  }

  Future<String> _generateFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${directory.path}/voice_recording_$timestamp.wav';
  }

  Future<void> startRecording() async {
    if (!await checkPermissions()) {
      throw Exception('Microphone permission not granted');
    }

    try {
      final filePath = await _generateFilePath();

      // Configure recording with higher quality
      final config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        bitRate: 128000,
        numChannels: 1,
      );

      await _recorder.start(config, path: filePath);

      _recordingData = _recordingData.copyWith(
        filePath: filePath,
        state: RecordingState.recording,
        duration: Duration.zero,
        amplitudes: [],
      );

      _amplitudes.clear();
      _startRecordingTimer();
      _startAmplitudeMonitoring();

      notifyListeners();
    } catch (e) {
      debugPrint('Error starting recording: $e');
      throw Exception('Failed to start recording: $e');
    }
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_recordingData.state == RecordingState.recording) {
        _recordingData = _recordingData.copyWith(
          duration: _recordingData.duration + const Duration(milliseconds: 100),
        );
        notifyListeners();
      }
    });
  }

  void _startAmplitudeMonitoring() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer =
        Timer.periodic(const Duration(milliseconds: 50), (timer) async {
      if (_recordingData.state == RecordingState.recording) {
        try {
          final amplitude = await _recorder.getAmplitude();
          _currentAmplitude = amplitude.current;

          // Normalize amplitude (0.0 to 1.0)
          final normalizedAmplitude =
              (_currentAmplitude + 50).clamp(0, 50) / 50;

          _amplitudes.add(normalizedAmplitude);

          // Keep only last 100 amplitude values for performance
          if (_amplitudes.length > 100) {
            _amplitudes.removeAt(0);
          }

          _recordingData =
              _recordingData.copyWith(amplitudes: List.from(_amplitudes));
          notifyListeners();
        } catch (e) {
          debugPrint('Error getting amplitude: $e');
        }
      }
    });
  }

  Future<void> pauseRecording() async {
    try {
      await _recorder.pause();
      _recordingData = _recordingData.copyWith(state: RecordingState.paused);
      _recordingTimer?.cancel();
      _amplitudeTimer?.cancel();
      notifyListeners();
    } catch (e) {
      debugPrint('Error pausing recording: $e');
    }
  }

  Future<void> resumeRecording() async {
    try {
      await _recorder.resume();
      _recordingData = _recordingData.copyWith(state: RecordingState.recording);
      _startRecordingTimer();
      _startAmplitudeMonitoring();
      notifyListeners();
    } catch (e) {
      debugPrint('Error resuming recording: $e');
    }
  }

  Future<void> stopRecording() async {
    try {
      final path = await _recorder.stop();
      _recordingTimer?.cancel();
      _amplitudeTimer?.cancel();

      if (path != null && path.isNotEmpty) {
        _recordingData = _recordingData.copyWith(
          filePath: path,
          state: RecordingState.completed,
        );

        // Generate waveform for visualization
        await _generateWaveform(path);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _generateWaveform(String audioPath) async {
    try {
      final audioFile = File(audioPath);
      if (await audioFile.exists()) {
        final waveformFile = File('$audioPath.waveform');

        final progressStream = JustWaveform.extract(
          audioInFile: audioFile,
          waveOutFile: waveformFile,
        );

        await for (final progress in progressStream) {
          if (progress.waveform != null) {
            // Convert waveform data to amplitude list
            final waveformData = progress.waveform!;
            final samples = waveformData.data;

            // Downsample for UI performance (take every nth sample)
            final downsampleRate = max(1, samples.length ~/ 200);
            final downsampled = <double>[];

            for (int i = 0; i < samples.length; i += downsampleRate) {
              final normalizedSample = samples[i].abs() / 32768.0;
              downsampled.add(normalizedSample.clamp(0.0, 1.0));
            }

            _recordingData = _recordingData.copyWith(amplitudes: downsampled);
            notifyListeners();
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('Error generating waveform: $e');
    }
  }

  Future<void> cancelRecording() async {
    try {
      await _recorder.stop();
      _recordingTimer?.cancel();
      _amplitudeTimer?.cancel();

      // Delete the file if it exists
      if (_recordingData.filePath != null) {
        final file = File(_recordingData.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      _reset();
      notifyListeners();
    } catch (e) {
      debugPrint('Error cancelling recording: $e');
    }
  }

  Future<void> playAudio() async {
    if (!_isInitialized || _recordingData.filePath == null) return;

    try {
      final file = File(_recordingData.filePath!);
      if (!await file.exists()) {
        debugPrint('Audio file does not exist: ${_recordingData.filePath}');
        return;
      }

      final fileSize = await file.length();
      debugPrint('Audio file size: $fileSize bytes');

      // Stop any existing playback first
      if (_currentSoundHandle != null) {
        await _soloud.stop(_currentSoundHandle!);
        _currentSoundHandle = null;
      }

      final audioSource = await _soloud.loadFile(_recordingData.filePath!);
      debugPrint('Audio source loaded successfully');

      _currentSoundHandle = await _soloud.play(audioSource);
      debugPrint('Audio playback started');

      _recordingData = _recordingData.copyWith(
        state: RecordingState.playing,
        playerState: AudioPlayerState.playing,
        playbackPosition: Duration.zero,
      );

      // Start a simple timer that just updates the UI without relying on position
      _startSimplePlaybackTimer();
      notifyListeners();
    } catch (e) {
      debugPrint('Error playing audio: $e');
      // Reset state on error
      _recordingData = _recordingData.copyWith(
        state: RecordingState.completed,
        playerState: AudioPlayerState.stopped,
      );
      notifyListeners();
    }
  }

  Future<void> pauseAudio() async {
    if (_currentSoundHandle != null) {
      try {
        _soloud.pauseSwitch(_currentSoundHandle!);

        _recordingData = _recordingData.copyWith(
          state: RecordingState.playingPaused,
          playerState: AudioPlayerState.paused,
        );

        _playbackTimer?.cancel();
        notifyListeners();
      } catch (e) {
        debugPrint('Error pausing audio: $e');
      }
    }
  }

  Future<void> stopAudio() async {
    if (_currentSoundHandle != null) {
      try {
        await _soloud.stop(_currentSoundHandle!);

        _recordingData = _recordingData.copyWith(
          state: RecordingState.completed,
          playerState: AudioPlayerState.stopped,
          playbackPosition: Duration.zero,
        );

        _playbackTimer?.cancel();
        _currentSoundHandle = null;
        notifyListeners();
      } catch (e) {
        debugPrint('Error stopping audio: $e');
      }
    }
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (_currentSoundHandle != null && _recordingData.isPlaying) {
        try {
          final position = _soloud.getPosition(_currentSoundHandle!);

          // getPosition returns a Duration object
          final positionDuration = position;

          _recordingData =
              _recordingData.copyWith(playbackPosition: positionDuration);

          // Check if playback is complete
          if (positionDuration >= _recordingData.duration) {
            await stopAudio();
          } else {
            notifyListeners();
          }
        } catch (e) {
          debugPrint('Error updating playback position: $e');
          // Don't stop playback for position update errors, just continue
          // The audio might still be playing even if we can't get the position
          notifyListeners();
        }
      } else {
        // Cancel timer if not playing
        timer.cancel();
      }
    });
  }

  void _startSimplePlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_currentSoundHandle != null && _recordingData.isPlaying) {
        // Simple timer that just updates the UI without trying to get position
        // This avoids the position parsing errors
        final currentPosition =
            _recordingData.playbackPosition ?? Duration.zero;
        final newPosition = currentPosition + const Duration(milliseconds: 100);

        _recordingData = _recordingData.copyWith(playbackPosition: newPosition);

        // Check if we've reached the end
        if (newPosition >= _recordingData.duration) {
          stopAudio();
        } else {
          notifyListeners();
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> seekTo(double position) async {
    if (_currentSoundHandle != null && _recordingData.hasRecording) {
      try {
        final seekPosition = _recordingData.duration.inSeconds * position;
        _soloud.seek(
            _currentSoundHandle!, Duration(seconds: seekPosition.toInt()));

        _recordingData = _recordingData.copyWith(
          playbackPosition: Duration(seconds: seekPosition.toInt()),
        );

        notifyListeners();
      } catch (e) {
        debugPrint('Error seeking audio: $e');
      }
    }
  }

  void updateGestureData(RecordingGestureData gestureData) {
    _gestureData = gestureData;
    notifyListeners();
  }

  void _reset() {
    _recordingData = const VoiceRecordingData();
    _gestureData = const RecordingGestureData();
    _amplitudes.clear();
    _currentAmplitude = 0.0;
  }

  Future<void> deleteRecording() async {
    if (_recordingData.filePath != null) {
      try {
        final file = File(_recordingData.filePath!);
        if (await file.exists()) {
          await file.delete();
        }

        // Also delete waveform file if exists
        final waveformFile = File('${_recordingData.filePath!}.waveform');
        if (await waveformFile.exists()) {
          await waveformFile.delete();
        }
      } catch (e) {
        debugPrint('Error deleting recording: $e');
      }
    }

    _reset();
    notifyListeners();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _amplitudeTimer?.cancel();
    _playbackTimer?.cancel();
    _amplitudeSubscription?.cancel();

    _recorder.dispose();

    if (_currentSoundHandle != null) {
      _soloud.stop(_currentSoundHandle!);
    }

    super.dispose();
  }
}

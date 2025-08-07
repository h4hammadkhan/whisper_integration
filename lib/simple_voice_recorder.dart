import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/audio_service.dart';
import 'models/recording_state.dart';
import 'widgets/waveform_widget.dart';

class SimpleVoiceRecorderUI extends StatefulWidget {
  @override
  _SimpleVoiceRecorderUIState createState() => _SimpleVoiceRecorderUIState();
}

class _SimpleVoiceRecorderUIState extends State<SimpleVoiceRecorderUI>
    with TickerProviderStateMixin {
  late AudioService _audioService;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _audioService = AudioService();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Listen to audio service changes
    _audioService.addListener(_onAudioServiceChanged);
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioServiceChanged);
    _audioService.dispose();
    _pulseController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _onAudioServiceChanged() {
    setState(() {
      // Update UI based on audio service state
      if (_audioService.recordingData.isRecording) {
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
      } else {
        if (_pulseController.isAnimating) {
          _pulseController.stop();
          _pulseController.reset();
        }
      }
    });
  }

  void _handleStartRecording() async {
    try {
      if (!await _audioService.checkPermissions()) {
        _showPermissionDialog();
        return;
      }
      await _audioService.startRecording();
      HapticFeedback.mediumImpact();
    } catch (e) {
      _showErrorDialog('Failed to start recording: $e');
    }
  }

  void _handleStopRecording() async {
    try {
      await _audioService.stopRecording();
      HapticFeedback.lightImpact();
    } catch (e) {
      _showErrorDialog('Failed to stop recording: $e');
    }
  }

  void _handleCancelRecording() async {
    try {
      await _audioService.cancelRecording();
      HapticFeedback.mediumImpact();
    } catch (e) {
      _showErrorDialog('Failed to cancel recording: $e');
    }
  }

  void _handlePlayPause() async {
    final recordingData = _audioService.recordingData;

    if (recordingData.isPlaying) {
      await _audioService.pauseAudio();
    } else {
      await _audioService.playAudio();
    }
  }

  void _handleSeek(double position) async {
    await _audioService.seekTo(position);
  }

  void _handleSendRecording() async {
    // TODO: Implement sending logic
    await _audioService.deleteRecording();
    _showSuccessMessage('Voice message sent!');
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Permission'),
        content: const Text(
          'This app needs microphone permission to record voice messages. '
          'Please grant permission in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recordingData = _audioService.recordingData;
    final gestureData = _audioService.gestureData;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Voice Recording Demo'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                child: const Center(
                  child: Text(
                    'Voice messages will appear here',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            _buildRecordingInterface(recordingData, gestureData),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingInterface(
      VoiceRecordingData recordingData, RecordingGestureData gestureData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Recording state UI
          if (recordingData.isRecording && gestureData.isLocked)
            _buildLockedRecordingUI(recordingData)
          else if (recordingData.isCompleted)
            _buildCompletedRecordingUI(recordingData)
          else
            _buildIdleUI(),
        ],
      ),
    );
  }

  Widget _buildIdleUI() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _messageController,
            decoration: InputDecoration(
              hintText: 'Type a message...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            maxLines: null,
          ),
        ),
        const SizedBox(width: 12),
        _buildRecordingButton(),
      ],
    );
  }

  Widget _buildRecordingButton() {
    final recordingData = _audioService.recordingData;
    final isRecording = recordingData.isRecording;

    return GestureDetector(
      onLongPressStart: (details) {
        _handleStartRecording();
      },
      onLongPressEnd: (details) {
        if (isRecording) {
          _handleStopRecording();
        }
      },
      onTap: () {
        if (recordingData.isCompleted) {
          _handlePlayPause();
        } else if (isRecording) {
          _handleStopRecording();
        }
        HapticFeedback.lightImpact();
      },
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Pulse effect during recording
              if (isRecording)
                Container(
                  width: 80 * _pulseAnimation.value,
                  height: 80 * _pulseAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red
                        .withOpacity(0.3 * (2 - _pulseAnimation.value)),
                  ),
                ),

              // Main button
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _getButtonColor(recordingData),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _getButtonColor(recordingData).withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  _getButtonIcon(recordingData),
                  color: Colors.white,
                  size: 28,
                ),
              ),

              // Recording timer overlay
              if (isRecording)
                Positioned(
                  top: -35,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      recordingData.formattedDuration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Color _getButtonColor(VoiceRecordingData recordingData) {
    if (recordingData.isRecording) {
      return recordingData.isPaused ? Colors.orange : Colors.red;
    } else if (recordingData.isCompleted) {
      return Colors.blue;
    }
    return Colors.blue;
  }

  IconData _getButtonIcon(VoiceRecordingData recordingData) {
    if (recordingData.isRecording) {
      return recordingData.isPaused ? Icons.play_arrow : Icons.stop;
    } else if (recordingData.isCompleted) {
      return recordingData.isPlaying ? Icons.pause : Icons.play_arrow;
    }
    return Icons.mic;
  }

  Widget _buildLockedRecordingUI(VoiceRecordingData recordingData) {
    return Column(
      children: [
        // Timer and waveform
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                recordingData.formattedDuration,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 12),
              LiveWaveformWidget(
                amplitudes: recordingData.amplitudes,
                color: Colors.red,
                height: 50,
              ),
            ],
          ),
        ),

        // Control buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              icon: Icons.delete_outline,
              color: Colors.red,
              onPressed: _handleCancelRecording,
              label: 'Delete',
            ),
            _buildActionButton(
              icon: recordingData.isPaused ? Icons.play_arrow : Icons.pause,
              color: Colors.orange,
              onPressed: () async {
                if (recordingData.isPaused) {
                  await _audioService.resumeRecording();
                } else {
                  await _audioService.pauseRecording();
                }
              },
              label: recordingData.isPaused ? 'Resume' : 'Pause',
            ),
            _buildActionButton(
              icon: Icons.stop,
              color: Colors.green,
              onPressed: _handleStopRecording,
              label: 'Stop',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompletedRecordingUI(VoiceRecordingData recordingData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _handlePlayPause,
                icon: Icon(
                  recordingData.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.blue,
                  size: 32,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WaveformWidget(
                      amplitudes: recordingData.amplitudes,
                      currentPosition: recordingData.playbackPosition,
                      totalDuration: recordingData.duration,
                      activeColor: Colors.blue,
                      inactiveColor: Colors.grey,
                      height: 40,
                      showProgress: true,
                      onSeek: _handleSeek,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          recordingData.formattedPlaybackPosition,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          recordingData.formattedDuration,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.delete_outline,
                color: Colors.red,
                onPressed: () async {
                  await _audioService.deleteRecording();
                },
                label: 'Delete',
              ),
              _buildActionButton(
                icon: Icons.send,
                color: Colors.green,
                onPressed: _handleSendRecording,
                label: 'Send',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: color),
            iconSize: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

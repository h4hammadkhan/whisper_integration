import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'services/audio_service.dart';
import 'models/recording_state.dart';
import 'widgets/waveform_widget.dart';
import 'widgets/recording_button.dart';

class VoiceRecorderUI extends StatefulWidget {
  @override
  _VoiceRecorderUIState createState() => _VoiceRecorderUIState();
}

class _VoiceRecorderUIState extends State<VoiceRecorderUI>
    with TickerProviderStateMixin {
  late AudioService _audioService;
  late AnimationController _slideAnimationController;
  late AnimationController _lockAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _lockAnimation;

  final TextEditingController _messageController = TextEditingController();
  bool _showLockIndicator = false;
  bool _showCancelIndicator = false;

  @override
  void initState() {
    super.initState();
    _audioService = AudioService();

    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _lockAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.2, 0),
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOut,
    ));

    _lockAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _lockAnimationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _audioService.dispose();
    _slideAnimationController.dispose();
    _lockAnimationController.dispose();
    _messageController.dispose();
    super.dispose();
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
      _slideAnimationController.reverse();
      _lockAnimationController.reverse();
      setState(() {
        _showLockIndicator = false;
        _showCancelIndicator = false;
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      _showErrorDialog('Failed to cancel recording: $e');
    }
  }

  void _handlePanStart(Offset globalPosition) {
    final gestureData = RecordingGestureData(
      isLongPressing: true,
      initialX: globalPosition.dx,
      initialY: globalPosition.dy,
      currentX: globalPosition.dx,
      currentY: globalPosition.dy,
    );
    _audioService.updateGestureData(gestureData);

    setState(() {
      _showLockIndicator = true;
    });
    _lockAnimationController.forward();
  }

  void _handlePanUpdate(Offset globalPosition) {
    final currentGestureData = _audioService.gestureData;
    final updatedGestureData = currentGestureData.copyWith(
      currentX: globalPosition.dx,
      currentY: globalPosition.dy,
    );

    _audioService.updateGestureData(updatedGestureData);

    // Handle slide to cancel
    if (updatedGestureData.shouldCancel && !_showCancelIndicator) {
      setState(() {
        _showCancelIndicator = true;
      });
      _slideAnimationController.forward();
      HapticFeedback.lightImpact();
    } else if (!updatedGestureData.shouldCancel && _showCancelIndicator) {
      setState(() {
        _showCancelIndicator = false;
      });
      _slideAnimationController.reverse();
    }

    // Handle lock gesture
    if (updatedGestureData.shouldLock && !updatedGestureData.isLocked) {
      final lockedGestureData = updatedGestureData.copyWith(isLocked: true);
      _audioService.updateGestureData(lockedGestureData);
      setState(() {
        _showLockIndicator = false;
        _showCancelIndicator = false;
      });
      _slideAnimationController.reverse();
      _lockAnimationController.reverse();
      HapticFeedback.mediumImpact();
    }
  }

  void _handlePanEnd() {
    final gestureData = _audioService.gestureData;

    if (gestureData.shouldCancel) {
      _handleCancelRecording();
    } else if (!gestureData.isLocked) {
      _handleStopRecording();
    }

    setState(() {
      _showLockIndicator = false;
      _showCancelIndicator = false;
    });
    _slideAnimationController.reverse();
    _lockAnimationController.reverse();
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
    return ChangeNotifierProvider.value(
      value: _audioService,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Container(), // Chat messages would go here
              ),
              _buildRecordingInterface(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingInterface() {
    return Consumer<AudioService>(
      builder: (context, audioService, child) {
        final recordingData = audioService.recordingData;
        final gestureData = audioService.gestureData;

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
              // Lock indicator
              if (_showLockIndicator)
                AnimatedBuilder(
                  animation: _lockAnimation,
                  child: _buildLockIndicator(),
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _lockAnimation.value,
                      child: Opacity(
                        opacity: _lockAnimation.value,
                        child: child,
                      ),
                    );
                  },
                ),

              // Recording state UI
              if (recordingData.isRecording && gestureData.isLocked)
                _buildLockedRecordingUI(recordingData)
              else if (recordingData.isCompleted)
                _buildCompletedRecordingUI(recordingData)
              else
                _buildIdleUI(recordingData, gestureData),

              const SizedBox(height: 8),

              // Cancel indicator
              if (_showCancelIndicator)
                SlideTransition(
                  position: _slideAnimation,
                  child: _buildCancelIndicator(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLockIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Icon(Icons.keyboard_arrow_up, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            'Slide up to lock',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelIndicator() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cancel_outlined, size: 20, color: Colors.red),
          const SizedBox(width: 8),
          const Text(
            'Release to cancel',
            style: TextStyle(
              color: Colors.red,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleUI(
      VoiceRecordingData recordingData, RecordingGestureData gestureData) {
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
        RecordingButton(
          recordingData: recordingData,
          gestureData: gestureData,
          onStartRecording: _handleStartRecording,
          onStopRecording: _handleStopRecording,
          onCancelRecording: _handleCancelRecording,
          onPanStart: _handlePanStart,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
        ),
      ],
    );
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

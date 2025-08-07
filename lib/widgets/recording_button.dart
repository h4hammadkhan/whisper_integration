import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/recording_state.dart';

class RecordingButton extends StatefulWidget {
  final VoiceRecordingData recordingData;
  final RecordingGestureData gestureData;
  final VoidCallback? onStartRecording;
  final VoidCallback? onStopRecording;
  final VoidCallback? onCancelRecording;
  final VoidCallback? onLockRecording;
  final Function(Offset)? onPanUpdate;
  final Function(Offset)? onPanStart;
  final VoidCallback? onPanEnd;
  final double size;

  const RecordingButton({
    Key? key,
    required this.recordingData,
    required this.gestureData,
    this.onStartRecording,
    this.onStopRecording,
    this.onCancelRecording,
    this.onLockRecording,
    this.onPanUpdate,
    this.onPanStart,
    this.onPanEnd,
    this.size = 60,
  }) : super(key: key);

  @override
  State<RecordingButton> createState() => _RecordingButtonState();
}

class _RecordingButtonState extends State<RecordingButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late AnimationController _cancelController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _cancelAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _cancelController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    _cancelAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cancelController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void didUpdateWidget(RecordingButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Start/stop pulse animation based on recording state
    if (widget.recordingData.isRecording &&
        !oldWidget.recordingData.isRecording) {
      _pulseController.repeat(reverse: true);
      _scaleController.forward();
      HapticFeedback.mediumImpact();
    } else if (!widget.recordingData.isRecording &&
        oldWidget.recordingData.isRecording) {
      _pulseController.stop();
      _scaleController.reverse();
    }

    // Handle cancel animation
    if (widget.gestureData.isCancelling &&
        !oldWidget.gestureData.isCancelling) {
      _cancelController.forward();
      HapticFeedback.lightImpact();
    } else if (!widget.gestureData.isCancelling &&
        oldWidget.gestureData.isCancelling) {
      _cancelController.reverse();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    _cancelController.dispose();
    super.dispose();
  }

  Color _getButtonColor() {
    if (widget.recordingData.isRecording) {
      return widget.recordingData.isPaused ? Colors.orange : Colors.red;
    } else if (widget.recordingData.isCompleted) {
      return Colors.blue;
    }
    return Colors.blue;
  }

  IconData _getButtonIcon() {
    if (widget.recordingData.isRecording) {
      return widget.recordingData.isPaused ? Icons.play_arrow : Icons.pause;
    } else if (widget.recordingData.isCompleted) {
      return widget.recordingData.isPlaying ? Icons.pause : Icons.play_arrow;
    }
    return Icons.mic;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) {
        if (!widget.recordingData.isCompleted) {
          widget.onPanStart?.call(details.globalPosition);
          widget.onStartRecording?.call();
        }
      },
      onLongPressMoveUpdate: (details) {
        if (widget.recordingData.isRecording) {
          widget.onPanUpdate?.call(details.globalPosition);
        }
      },
      onLongPressEnd: (details) {
        if (widget.recordingData.isRecording && !widget.gestureData.isLocked) {
          if (widget.gestureData.shouldCancel) {
            widget.onCancelRecording?.call();
          } else {
            widget.onStopRecording?.call();
          }
        }
        widget.onPanEnd?.call();
      },
      onTap: () {
        if (widget.recordingData.isRecording && widget.gestureData.isLocked) {
          // Toggle pause/resume when locked
          if (widget.recordingData.isPaused) {
            widget.onStartRecording?.call(); // Resume
          } else {
            // Pause functionality would need to be implemented
          }
        } else if (widget.recordingData.isCompleted) {
          // Handle play/pause for completed recordings
          // This would need to be connected to audio playback
        }
        HapticFeedback.lightImpact();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _pulseAnimation,
          _scaleAnimation,
          _cancelAnimation,
        ]),
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Pulse rings during recording
              if (widget.recordingData.isRecording &&
                  !widget.recordingData.isPaused)
                ..._buildPulseRings(),

              // Cancel progress indicator
              if (widget.gestureData.isCancelling) _buildCancelIndicator(),

              // Main button
              Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: _getButtonColor(),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _getButtonColor().withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _getButtonIcon(),
                    color: Colors.white,
                    size: widget.size * 0.4,
                  ),
                ),
              ),

              // Recording timer overlay
              if (widget.recordingData.isRecording &&
                  widget.gestureData.isLocked)
                Positioned(
                  top: -30,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.recordingData.formattedDuration,
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

  List<Widget> _buildPulseRings() {
    return List.generate(3, (index) {
      final delay = index * 0.3;
      final controller = AnimationController(
        duration: Duration(milliseconds: 1500),
        vsync: this,
      );

      // Delayed start for each ring
      Future.delayed(Duration(milliseconds: (delay * 500).toInt()), () {
        if (mounted && widget.recordingData.isRecording) {
          controller.repeat();
        }
      });

      return AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final scale = 1.0 + (controller.value * 1.5);
          final opacity = 1.0 - controller.value;

          return Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _getButtonColor().withOpacity(opacity * 0.5),
                  width: 2,
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildCancelIndicator() {
    return Transform.scale(
      scale: 1.0 + (_cancelAnimation.value * 0.2),
      child: Container(
        width: widget.size + 20,
        height: widget.size + 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red.withOpacity(_cancelAnimation.value * 0.3),
          border: Border.all(
            color: Colors.red.withOpacity(_cancelAnimation.value),
            width: 3,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.close,
            color: Colors.red.withOpacity(_cancelAnimation.value),
            size: widget.size * 0.5,
          ),
        ),
      ),
    );
  }
}

class SlideToActButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onComplete;
  final double height;
  final double threshold;

  const SlideToActButton({
    Key? key,
    required this.text,
    required this.icon,
    this.backgroundColor = Colors.grey,
    this.foregroundColor = Colors.white,
    this.onComplete,
    this.height = 60,
    this.threshold = 0.8,
  }) : super(key: key);

  @override
  State<SlideToActButton> createState() => _SlideToActButtonState();
}

class _SlideToActButtonState extends State<SlideToActButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragPosition = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: widget.backgroundColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(widget.height / 2),
        border: Border.all(
          color: widget.backgroundColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Background text
          Center(
            child: Text(
              widget.text,
              style: TextStyle(
                color: widget.foregroundColor.withOpacity(0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Sliding button
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Positioned(
                left: _dragPosition,
                top: 4,
                child: GestureDetector(
                  onPanStart: (details) {
                    _isDragging = true;
                    HapticFeedback.lightImpact();
                  },
                  onPanUpdate: (details) {
                    if (_isDragging) {
                      setState(() {
                        _dragPosition = (_dragPosition + details.delta.dx)
                            .clamp(0.0, widget.height - 8);
                      });

                      // Check if threshold reached
                      final progress = _dragPosition / (widget.height - 8);
                      if (progress >= widget.threshold &&
                          widget.onComplete != null) {
                        widget.onComplete!();
                        HapticFeedback.mediumImpact();
                        _resetPosition();
                      }
                    }
                  },
                  onPanEnd: (details) {
                    _isDragging = false;
                    _resetPosition();
                  },
                  child: Container(
                    width: widget.height - 8,
                    height: widget.height - 8,
                    decoration: BoxDecoration(
                      color: widget.backgroundColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.foregroundColor,
                      size: (widget.height - 8) * 0.5,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _resetPosition() {
    _controller.forward().then((_) {
      setState(() {
        _dragPosition = 0.0;
      });
      _controller.reset();
    });
  }
}

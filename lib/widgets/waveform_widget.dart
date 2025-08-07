import 'package:flutter/material.dart';
import 'dart:math' as math;

class WaveformWidget extends StatefulWidget {
  final List<double> amplitudes;
  final Duration? currentPosition;
  final Duration? totalDuration;
  final Color activeColor;
  final Color inactiveColor;
  final double height;
  final bool isRecording;
  final bool showProgress;
  final Function(double)? onSeek;

  const WaveformWidget({
    Key? key,
    required this.amplitudes,
    this.currentPosition,
    this.totalDuration,
    this.activeColor = Colors.blue,
    this.inactiveColor = Colors.grey,
    this.height = 40,
    this.isRecording = false,
    this.showProgress = false,
    this.onSeek,
  }) : super(key: key);

  @override
  State<WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<WaveformWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    if (widget.isRecording) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(WaveformWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _animationController.repeat();
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _animationController.stop();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onSeek != null ? _handleTap : null,
      child: Container(
        height: widget.height,
        child: widget.amplitudes.isEmpty
            ? _buildEmptyWaveform()
            : AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: WaveformPainter(
                      amplitudes: widget.amplitudes,
                      activeColor: widget.activeColor,
                      inactiveColor: widget.inactiveColor,
                      progress: widget.showProgress ? _getProgress() : 0,
                      isRecording: widget.isRecording,
                      animationValue: _animationController.value,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
      ),
    );
  }

  void _handleTap(TapDownDetails details) {
    if (widget.onSeek != null) {
      final RenderBox box = context.findRenderObject() as RenderBox;
      final localPosition = box.globalToLocal(details.globalPosition);
      final progress = localPosition.dx / box.size.width;
      widget.onSeek!(progress.clamp(0.0, 1.0));
    }
  }

  double _getProgress() {
    if (widget.currentPosition == null || widget.totalDuration == null) {
      return 0.0;
    }
    if (widget.totalDuration!.inMilliseconds == 0) return 0.0;
    return widget.currentPosition!.inMilliseconds /
        widget.totalDuration!.inMilliseconds;
  }

  Widget _buildEmptyWaveform() {
    return CustomPaint(
      painter: EmptyWaveformPainter(
        color: widget.inactiveColor,
        isRecording: widget.isRecording,
        animationValue: _animationController.value,
      ),
      size: Size.infinite,
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color activeColor;
  final Color inactiveColor;
  final double progress;
  final bool isRecording;
  final double animationValue;

  WaveformPainter({
    required this.amplitudes,
    required this.activeColor,
    required this.inactiveColor,
    required this.progress,
    required this.isRecording,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0;

    final barWidth = size.width / amplitudes.length;
    final centerY = size.height / 2;
    final maxHeight = size.height * 0.8;

    for (int i = 0; i < amplitudes.length; i++) {
      final x = i * barWidth + barWidth / 2;
      final amplitude = amplitudes[i];

      // Add some animation to the amplitude during recording
      double animatedAmplitude = amplitude;
      if (isRecording && i >= amplitudes.length - 10) {
        // Animate the last few bars during recording
        final animationOffset =
            math.sin(animationValue * 2 * math.pi + i * 0.5) * 0.1;
        animatedAmplitude = (amplitude + animationOffset).clamp(0.0, 1.0);
      }

      final barHeight = animatedAmplitude * maxHeight;
      final normalizedProgress = progress * amplitudes.length;

      // Determine color based on progress
      paint.color = i < normalizedProgress ? activeColor : inactiveColor;

      // Draw the bar
      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }

    // Draw progress indicator if needed
    if (progress > 0) {
      final progressX = progress * size.width;
      final progressPaint = Paint()
        ..color = activeColor
        ..strokeWidth = 2;

      // Draw progress line
      canvas.drawLine(
        Offset(progressX, 0),
        Offset(progressX, size.height),
        progressPaint,
      );

      // Draw seek dot
      final dotPaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(progressX, centerY),
        4.0,
        dotPaint,
      );

      // Draw white border around dot for better visibility
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(
        Offset(progressX, centerY),
        4.0,
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.amplitudes != amplitudes ||
        oldDelegate.progress != progress ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.isRecording != isRecording;
  }
}

class EmptyWaveformPainter extends CustomPainter {
  final Color color;
  final bool isRecording;
  final double animationValue;

  EmptyWaveformPainter({
    required this.color,
    required this.isRecording,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;

    final centerY = size.height / 2;
    final barCount = 50;
    final barWidth = size.width / barCount;

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth + barWidth / 2;

      // Create some baseline variation
      double barHeight = size.height * 0.1;

      if (isRecording) {
        // Add animation during recording
        final wave = math.sin(animationValue * 2 * math.pi + i * 0.3);
        barHeight += wave * size.height * 0.2;
      }

      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(EmptyWaveformPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isRecording != isRecording;
  }
}

class LiveWaveformWidget extends StatefulWidget {
  final List<double> amplitudes;
  final Color color;
  final double height;
  final int maxBars;

  const LiveWaveformWidget({
    Key? key,
    required this.amplitudes,
    this.color = Colors.green,
    this.height = 40,
    this.maxBars = 50,
  }) : super(key: key);

  @override
  State<LiveWaveformWidget> createState() => _LiveWaveformWidgetState();
}

class _LiveWaveformWidgetState extends State<LiveWaveformWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(LiveWaveformWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.amplitudes.length != oldWidget.amplitudes.length) {
      _animationController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return CustomPaint(
            painter: LiveWaveformPainter(
              amplitudes: widget.amplitudes,
              color: widget.color,
              maxBars: widget.maxBars,
              animationValue: _animationController.value,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class LiveWaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;
  final int maxBars;
  final double animationValue;

  LiveWaveformPainter({
    required this.amplitudes,
    required this.color,
    required this.maxBars,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    final displayAmplitudes = amplitudes.length > maxBars
        ? amplitudes.sublist(amplitudes.length - maxBars)
        : amplitudes;

    if (displayAmplitudes.isEmpty) return;

    final barWidth = size.width / maxBars;
    final centerY = size.height / 2;
    final maxHeight = size.height * 0.8;

    for (int i = 0; i < displayAmplitudes.length; i++) {
      final x = i * barWidth + barWidth / 2;
      final amplitude = displayAmplitudes[i];

      // Apply fade effect to older bars
      final fadeRatio = (i + 1) / displayAmplitudes.length;
      final opacity = (fadeRatio * 0.7 + 0.3).clamp(0.0, 1.0);

      paint.color = color.withOpacity(opacity);

      final barHeight = math.max(amplitude * maxHeight, size.height * 0.05);

      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(LiveWaveformPainter oldDelegate) {
    return oldDelegate.amplitudes != amplitudes ||
        oldDelegate.animationValue != animationValue;
  }
}

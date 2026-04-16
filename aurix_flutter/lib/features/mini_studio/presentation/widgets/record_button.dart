import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// Premium animated record button with breathing glow.
///
/// States: idle (pulse glow), recording (active pulse + scale), disabled.
class RecordButton extends StatefulWidget {
  final bool isRecording;
  final bool enabled;
  final VoidCallback? onTap;

  const RecordButton({
    super.key,
    required this.isRecording,
    this.enabled = true,
    this.onTap,
  });

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with TickerProviderStateMixin {
  late AnimationController _breathController;
  late AnimationController _recordController;
  late AnimationController _tapController;

  late Animation<double> _breathScale;
  late Animation<double> _breathGlow;
  late Animation<double> _recordPulse;
  late Animation<double> _tapScale;

  @override
  void initState() {
    super.initState();

    // Breathing animation (idle state)
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _breathScale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );
    _breathGlow = Tween<double>(begin: 0.15, end: 0.35).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    // Recording pulse animation
    _recordController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _recordPulse = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _recordController, curve: Curves.easeOut),
    );

    // Tap micro-bounce
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _tapScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.92), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _tapController, curve: AurixTokens.cBounce));
  }

  @override
  void didUpdateWidget(RecordButton old) {
    super.didUpdateWidget(old);
    if (widget.isRecording && !old.isRecording) {
      _recordController.repeat(reverse: true);
    } else if (!widget.isRecording && old.isRecording) {
      _recordController.stop();
      _recordController.reset();
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    _recordController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.enabled) return;
    _tapController.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final size = 120.0;
    final isRec = widget.isRecording;
    final color = isRec ? AurixTokens.danger : AurixTokens.accent;

    return AnimatedBuilder(
      animation: Listenable.merge([_breathController, _recordController, _tapController]),
      builder: (context, child) {
        final scale = _tapScale.value *
            (isRec ? 1.0 : _breathScale.value);
        final glowOpacity = isRec ? 0.45 : _breathGlow.value;
        final pulseScale = isRec ? _recordPulse.value : 1.0;

        return SizedBox(
          width: size * 1.8,
          height: size * 1.8,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow rings
              if (isRec) ...[
                Transform.scale(
                  scale: pulseScale,
                  child: Container(
                    width: size * 1.6,
                    height: size * 1.6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withValues(alpha: 0.12 * (2.0 - pulseScale)),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],

              // Glow aura
              Container(
                width: size * 1.35,
                height: size * 1.35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: glowOpacity),
                      blurRadius: 48,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),

              // Main button
              Transform.scale(
                scale: scale,
                child: GestureDetector(
                  onTap: _handleTap,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          color,
                          color.withValues(alpha: 0.7),
                        ],
                        center: const Alignment(-0.2, -0.3),
                        radius: 0.8,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 24,
                          spreadRadius: -4,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: AurixTokens.dMedium,
                        child: isRec
                            ? Container(
                                key: const ValueKey('stop'),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              )
                            : Icon(
                                Icons.mic_rounded,
                                key: const ValueKey('mic'),
                                color: Colors.white,
                                size: 40,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

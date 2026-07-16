import 'package:flutter/material.dart';

/// A small emoji that gently "beats" like a heartbeat.
///
/// Uses a looping scale animation (grow/shrink) so it feels alive without being
/// distracting. Purely decorative — no AI, no logic.
class BeatingHeart extends StatefulWidget {
  const BeatingHeart({
    super.key,
    this.emoji = '💓',
    this.size = 18,
  });

  final String emoji;
  final double size;

  @override
  State<BeatingHeart> createState() => _BeatingHeartState();
}

class _BeatingHeartState extends State<BeatingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween<double>(
    begin: 0.85,
    end: 1.2,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Text(widget.emoji, style: TextStyle(fontSize: widget.size)),
    );
  }
}

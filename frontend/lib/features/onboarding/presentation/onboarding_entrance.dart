import 'package:flutter/material.dart';

import '../../../core/design/zest_tokens.dart';

/// Plays one short entrance (0 → 1, eased) the first time [active] becomes
/// true, and again each later time it becomes true after being false — a
/// swipe back onto the page replays it rather than leaving it frozen at the
/// end. Under reduced motion no [AnimationController] is ever created and
/// [builder] always receives `1.0`, per the M7 motion contract.
class OnboardingEntrance extends StatefulWidget {
  const OnboardingEntrance({
    super.key,
    required this.active,
    required this.duration,
    required this.builder,
  });

  final bool active;
  final Duration duration;
  final Widget Function(BuildContext context, double t) builder;

  @override
  State<OnboardingEntrance> createState() => _OnboardingEntranceState();
}

class _OnboardingEntranceState extends State<OnboardingEntrance>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = ZestMotion.reduced(context);
    if (widget.active && !_reduced && _controller == null) _start();
  }

  @override
  void didUpdateWidget(covariant OnboardingEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active && !_reduced) {
      _start();
    }
  }

  void _start() {
    _controller?.dispose();
    final controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..addListener(() => setState(() {}));
    _controller = controller;
    controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _reduced ? 1.0 : (_controller?.value ?? 0.0);
    return widget.builder(context, Curves.easeOutCubic.transform(t));
  }
}

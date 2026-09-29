import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../utils/tracking_freshness.dart';

class LiveStatusPill extends StatefulWidget {
  final FreshnessClassification classification;

  const LiveStatusPill({super.key, required this.classification});

  factory LiveStatusPill.fromRaw({
    Key? key,
    required bool isOnline,
    required dynamic refreshedAt,
    String? locationTime,
    DateTime? currentTime,
  }) {
    return LiveStatusPill(
      key: key,
      classification: TrackingFreshnessClassifier.classify(
        isOnline: isOnline,
        refreshedAt: refreshedAt,
        locationTime: locationTime,
        currentTime: currentTime,
      ),
    );
  }

  @override
  State<LiveStatusPill> createState() => _LiveStatusPillState();
}

class _LiveStatusPillState extends State<LiveStatusPill>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _checkPulseState();
  }

  @override
  void didUpdateWidget(covariant LiveStatusPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classification.status != widget.classification.status) {
      _checkPulseState();
    }
  }

  void _checkPulseState() {
    if (widget.classification.status == FreshnessStatus.live) {
      if (_pulseController == null) {
        _pulseController = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 3000),
        );
        _pulseAnimation = TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
          TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
        ]).animate(
          CurvedAnimation(
            parent: _pulseController!,
            curve: Curves.easeInOut,
          ),
        );
        _pulseController!.repeat();
      }
    } else {
      _pulseController?.stop();
      _pulseController?.dispose();
      _pulseController = null;
      _pulseAnimation = null;
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLive = widget.classification.status == FreshnessStatus.live;

    return AnimatedContainer(
      duration: AppMotion.medium,
      curve: AppMotion.standard,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: widget.classification.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive && _pulseAnimation != null) ...[
            AnimatedBuilder(
              animation: _pulseAnimation!,
              builder: (context, child) {
                return Transform.scale(
                  scale: AppMotion.isReducedMotion(context)
                      ? 1.0
                      : _pulseAnimation!.value,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 6),
          ] else ...[
            Icon(widget.classification.icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
          ],
          AnimatedSwitcher(
            duration: AppMotion.normal,
            child: Text(
              widget.classification.label,
              key: ValueKey(widget.classification.label),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

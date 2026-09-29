import 'package:flutter/material.dart';

import '../models/apsrtc_service_search_result.dart';
import '../theme/app_motion.dart';
import '../theme/app_tokens.dart';

class ServiceStatusBadge extends StatefulWidget {
  final BusServiceStatus status;
  final String statusText;

  const ServiceStatusBadge({
    super.key,
    required this.status,
    required this.statusText,
  });

  @override
  State<ServiceStatusBadge> createState() => _ServiceStatusBadgeState();
}

class _ServiceStatusBadgeState extends State<ServiceStatusBadge>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _checkPulseState();
  }

  @override
  void didUpdateWidget(covariant ServiceStatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _checkPulseState();
    }
  }

  void _checkPulseState() {
    if (widget.status == BusServiceStatus.running) {
      if (_pulseController == null) {
        _pulseController = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 3500),
        );
        _pulseAnimation = TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 60),
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
    Color backgroundColor;
    Color textColor = Colors.white;

    switch (widget.status) {
      case BusServiceStatus.running:
        backgroundColor = AppColors.successLive;
        break;
      case BusServiceStatus.upcoming:
        backgroundColor = AppColors.info;
        break;
      case BusServiceStatus.completed:
        backgroundColor = AppColors.secondaryText;
        break;
      case BusServiceStatus.trackingUnavailable:
        backgroundColor = AppColors.warning;
        break;
    }

    final bool isLive = widget.status == BusServiceStatus.running;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.chip),
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
          ],
          Text(
            widget.statusText.toUpperCase(),
            style: AppTypography.badgeLabel.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

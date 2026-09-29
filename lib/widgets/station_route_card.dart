import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/apsrtc_station.dart';
import '../theme/app_motion.dart';
import '../theme/app_tokens.dart';

class StationRouteCard extends StatefulWidget {
  final ApsrtcStation? fromStation;
  final ApsrtcStation? toStation;
  final VoidCallback onSelectFrom;
  final VoidCallback onSelectTo;
  final VoidCallback onSwap;
  final VoidCallback? onSearch;
  final bool isSearching;

  const StationRouteCard({
    super.key,
    required this.fromStation,
    required this.toStation,
    required this.onSelectFrom,
    required this.onSelectTo,
    required this.onSwap,
    required this.onSearch,
    this.isSearching = false,
  });

  @override
  State<StationRouteCard> createState() => _StationRouteCardState();
}

class _StationRouteCardState extends State<StationRouteCard> {
  double _swapTurns = 0.0;
  bool _isSearchPressed = false;

  void _handleSwap() {
    HapticFeedback.lightImpact();
    setState(() {
      _swapTurns += 0.5; // 180 degree rotation
    });
    widget.onSwap();
  }

  @override
  Widget build(BuildContext context) {
    final bool canSearch =
        widget.fromStation != null &&
        widget.toStation != null &&
        widget.fromStation!.placeId != widget.toStation!.placeId &&
        !widget.isSearching;

    return Column(
      children: [
        // Main rounded white card container matching Stitch
        Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.horizontalPadding,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                children: [
                  // FROM Block with animated switcher
                  _StationBox(
                    key: const ValueKey('from_box'),
                    context: context,
                    label: 'FROM',
                    iconWidget: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEE2E2), // Light red
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryRed,
                              width: 3.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    station: widget.fromStation,
                    fallbackName: 'Tirupathi',
                    fallbackSubtitle: 'Tirupati Urban • 517501',
                    onTap: widget.onSelectFrom,
                  ),
                  const SizedBox(height: 12),
                  // TO Block with animated switcher
                  _StationBox(
                    key: const ValueKey('to_box'),
                    context: context,
                    label: 'TO',
                    iconWidget: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDBEAFE), // Light blue
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                    station: widget.toStation,
                    fallbackName: 'Kadapa',
                    fallbackSubtitle: 'Kadapa • 516001',
                    onTap: widget.onSelectTo,
                  ),
                ],
              ),
              // Circular Swap Button with 180 rotation
              Positioned(
                child: AnimatedRotation(
                  turns: _swapTurns,
                  duration: AppMotion.medium,
                  curve: AppMotion.standard,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _handleSwap,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: const Icon(
                          Icons.swap_vert_rounded,
                          color: AppColors.primaryRed,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Red primary SEARCH BUSES button with scale feedback
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.horizontalPadding,
          ),
          child: GestureDetector(
            onTapDown: canSearch ? (_) => setState(() => _isSearchPressed = true) : null,
            onTapUp: canSearch ? (_) => setState(() => _isSearchPressed = false) : null,
            onTapCancel: canSearch ? () => setState(() => _isSearchPressed = false) : null,
            child: AnimatedScale(
              scale: _isSearchPressed ? 0.98 : 1.0,
              duration: AppMotion.fast,
              curve: AppMotion.enter,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: canSearch
                      ? () {
                          HapticFeedback.lightImpact();
                          widget.onSearch?.call();
                        }
                      : null,
                  icon: widget.isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search_rounded, size: 22),
                  label: AnimatedSwitcher(
                    duration: AppMotion.fast,
                    child: Text(
                      widget.isSearching ? 'SEARCHING...' : 'SEARCH BUSES',
                      key: ValueKey(widget.isSearching),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canSearch
                        ? AppColors.primaryRed
                        : Colors.grey.shade400,
                    elevation: canSearch ? 3 : 0,
                    shadowColor: AppColors.primaryRed.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StationBox extends StatefulWidget {
  final BuildContext context;
  final String label;
  final Widget iconWidget;
  final ApsrtcStation? station;
  final String fallbackName;
  final String fallbackSubtitle;
  final VoidCallback onTap;

  const _StationBox({
    super.key,
    required this.context,
    required this.label,
    required this.iconWidget,
    required this.station,
    required this.fallbackName,
    required this.fallbackSubtitle,
    required this.onTap,
  });

  @override
  State<_StationBox> createState() => _StationBoxState();
}

class _StationBoxState extends State<_StationBox> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final String name = widget.station?.placeName ?? widget.fallbackName;
    final String subtitle = widget.station != null
        ? widget.station!.displaySubtitle
        : widget.fallbackSubtitle;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.985 : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.enter,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5F7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              widget.iconWidget,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: AppMotion.normal,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.1),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        name,
                        key: ValueKey(name),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: AnimatedSwitcher(
                          duration: AppMotion.normal,
                          child: Text(
                            subtitle,
                            key: ValueKey(subtitle),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, size: 20, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }
}

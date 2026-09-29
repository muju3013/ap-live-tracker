import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_tokens.dart';

enum StopStatus { completed, current, lastKnown, upcoming, skipped }

class RouteWaypointStop {
  final String stationId;
  final String stationName;
  final String? scheduledTime;
  final String? actualTime;
  final StopStatus status;

  const RouteWaypointStop({
    required this.stationId,
    required this.stationName,
    this.scheduledTime,
    this.actualTime,
    this.status = StopStatus.upcoming,
  });
}

class RouteTimeline extends StatelessWidget {
  final List<RouteWaypointStop> stops;

  const RouteTimeline({super.key, required this.stops});

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Text(
            'Route waypoint details unavailable.',
            style: TextStyle(color: AppColors.secondaryText),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stops.length,
      itemBuilder: (context, index) {
        final stop = stops[index];
        final isFirst = index == 0;
        final isLast = index == stops.length - 1;

        return _buildTimelineItem(context, stop, isFirst, isLast);
      },
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    RouteWaypointStop stop,
    bool isFirst,
    bool isLast,
  ) {
    Color dotColor;
    IconData iconData;
    TextStyle titleStyle;
    Color timeColor;

    switch (stop.status) {
      case StopStatus.completed:
        dotColor = AppColors.successLive;
        iconData = Icons.check_circle;
        titleStyle = const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryText,
        );
        timeColor = AppColors.successLive;
        break;
      case StopStatus.current:
        dotColor = AppColors.primaryRed;
        iconData = Icons.directions_bus;
        titleStyle = const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryRed,
        );
        timeColor = AppColors.primaryRed;
        break;
      case StopStatus.lastKnown:
        dotColor = AppColors.warning;
        iconData = Icons.history;
        titleStyle = const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.warning,
        );
        timeColor = AppColors.warning;
        break;
      case StopStatus.skipped:
        dotColor = AppColors.secondaryText;
        iconData = Icons.block;
        titleStyle = const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.secondaryText,
          decoration: TextDecoration.lineThrough,
        );
        timeColor = AppColors.secondaryText;
        break;
      case StopStatus.upcoming:
        dotColor = AppColors.secondaryText.withValues(alpha: 0.5);
        iconData = Icons.radio_button_unchecked;
        titleStyle = const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryText,
        );
        timeColor = AppColors.secondaryText;
        break;
    }

    final bool isSkipped = stop.status == StopStatus.skipped;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: AppMotion.medium,
                    curve: AppMotion.standard,
                    width: 2,
                    color: isFirst
                        ? Colors.transparent
                        : (stop.status == StopStatus.completed
                            ? AppColors.successLive
                            : AppColors.border),
                  ),
                ),
                AnimatedSwitcher(
                  duration: AppMotion.normal,
                  child: Icon(
                    iconData,
                    key: ValueKey(iconData),
                    size: (stop.status == StopStatus.current ||
                            stop.status == StopStatus.lastKnown)
                        ? 22
                        : 18,
                    color: dotColor,
                  ),
                ),
                Expanded(
                  child: AnimatedContainer(
                    duration: AppMotion.medium,
                    curve: AppMotion.standard,
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : (stop.status == StopStatus.completed
                            ? AppColors.successLive
                            : AppColors.border),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: AnimatedOpacity(
              duration: AppMotion.normal,
              opacity: isSkipped ? 0.5 : 1.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: AppMotion.normal,
                        style: titleStyle,
                        child: Text(
                          stop.stationName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    if (stop.actualTime != null && stop.actualTime!.isNotEmpty)
                      Flexible(
                        child: AnimatedDefaultTextStyle(
                          duration: AppMotion.normal,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: timeColor,
                          ),
                          child: Text(
                            stop.actualTime!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                    else if (stop.scheduledTime != null &&
                        stop.scheduledTime!.isNotEmpty)
                      Flexible(
                        child: Text(
                          stop.scheduledTime!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.secondaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

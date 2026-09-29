import 'package:flutter/material.dart';

import '../models/apsrtc_route_stop.dart';
import '../models/apsrtc_service_search_result.dart';
import '../services/apsrtc_route_stops_service.dart';
import '../theme/app_tokens.dart';

/// Modal bottom sheet showing detailed route stops for a service.
class RouteDetailsSheet extends StatefulWidget {
  final ApsrtcServiceSearchResult result;
  final ApsrtcRouteStopsService? routeStopsService;

  const RouteDetailsSheet({
    super.key,
    required this.result,
    this.routeStopsService,
  });

  static Future<void> show(
    BuildContext context, {
    required ApsrtcServiceSearchResult result,
    ApsrtcRouteStopsService? routeStopsService,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RouteDetailsSheet(
        result: result,
        routeStopsService: routeStopsService,
      ),
    );
  }

  @override
  State<RouteDetailsSheet> createState() => _RouteDetailsSheetState();
}

class _RouteDetailsSheetState extends State<RouteDetailsSheet> {
  late final ApsrtcRouteStopsService _routeStopsService;
  late Future<ApsrtcRouteSegmentResult> _routeFuture;

  @override
  void initState() {
    super.initState();
    _routeStopsService = widget.routeStopsService ?? ApsrtcRouteStopsService();
    _routeFuture = _routeStopsService.resolveRouteStops(
      serviceDocId: widget.result.serviceDocId,
      wayPointString: widget.result.wayPointString,
      fromName: widget.result.fromStop,
      toName: widget.result.toStop,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.70,
      minChildSize: 0.40,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.horizontalPadding),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Service ${widget.result.serviceNumber} Route',
                            style: AppTypography.cardTitle,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.result.fromStop} ➔ ${widget.result.toStop}',
                            style: AppTypography.cardSubtitle.copyWith(
                              color: AppColors.primaryRed,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: FutureBuilder<ApsrtcRouteSegmentResult>(
                  future: _routeFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildSkeletonList();
                    }

                    if (snapshot.hasError || !snapshot.hasData) {
                      return const Center(
                        child: Text(
                          'Route stops unavailable',
                          style: TextStyle(color: AppColors.secondaryText),
                        ),
                      );
                    }

                    final data = snapshot.data!;
                    final stops = data.visibleSegmentStops.isNotEmpty
                        ? data.visibleSegmentStops
                        : data.fullRouteStops;

                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(
                        AppSpacing.horizontalPadding,
                      ),
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.alt_route,
                                size: 18,
                                color: AppColors.primaryRed,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  data.viaSummary,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          'Route Stops & Waypoints',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ...List.generate(stops.length, (index) {
                          final stop = stops[index];
                          final isFirst = (index == 0);
                          final isLast = (index == stops.length - 1);
                          return _buildStopRow(
                            stop,
                            isFirst: isFirst,
                            isLast: isLast,
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStopRow(
    ApsrtcRouteStop stop, {
    required bool isFirst,
    required bool isLast,
  }) {
    Color dotColor;
    String badgeText = '';

    if (stop.isBoardingStop || isFirst) {
      dotColor = AppColors.successLive;
      badgeText = 'BOARDING';
    } else if (stop.isDropStop || isLast) {
      dotColor = AppColors.primaryRed;
      badgeText = 'DROP';
    } else {
      dotColor = AppColors.info;
      badgeText = 'VIA';
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 12,
                  color: isFirst ? Colors.transparent : AppColors.border,
                ),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : AppColors.border,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: stop.isBoardingStop || stop.isDropStop
                    ? AppColors.background
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: stop.isBoardingStop || stop.isDropStop
                      ? AppColors.primaryRed.withAlpha(76)
                      : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.placeName,
                          style: TextStyle(
                            fontWeight: stop.isBoardingStop || stop.isDropStop
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.primaryText,
                          ),
                        ),
                        if (stop.mandalName != null &&
                            stop.mandalName!.isNotEmpty)
                          Text(
                            '${stop.mandalName} ${stop.pinCode != null ? '• ${stop.pinCode}' : ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: dotColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: dotColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.horizontalPadding),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 54,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../models/apsrtc_service_search_result.dart';
import '../theme/app_motion.dart';
import '../theme/app_tokens.dart';
import 'service_status_badge.dart';

class BusServiceCard extends StatefulWidget {
  final ApsrtcServiceSearchResult result;
  final VoidCallback onTrackLive;
  final VoidCallback onViewDetails;

  const BusServiceCard({
    super.key,
    required this.result,
    required this.onTrackLive,
    required this.onViewDetails,
  });

  @override
  State<BusServiceCard> createState() => _BusServiceCardState();
}

class _BusServiceCardState extends State<BusServiceCard> {
  bool _isCardPressed = false;
  bool _isChevronPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool showTrackLiveButton =
        widget.result.isTrackingAvailable &&
        widget.result.status != BusServiceStatus.completed;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isCardPressed = true),
      onTapUp: (_) => setState(() => _isCardPressed = false),
      onTapCancel: () => setState(() => _isCardPressed = false),
      child: AnimatedScale(
        scale: _isCardPressed ? 0.99 : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.enter,
        child: Card(
          margin: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: AppSpacing.horizontalPadding,
          ),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            side: const BorderSide(color: AppColors.border, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Service: ${widget.result.serviceNumber}',
                        style: AppTypography.cardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ServiceStatusBadge(
                      status: widget.result.status,
                      statusText: widget.result.statusText,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${widget.result.fromStop} ➔ ${widget.result.toStop}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.result.source != widget.result.fromStop ||
                    widget.result.destination != widget.result.toStop)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Full Route: ${widget.result.source} ➔ ${widget.result.destination}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                // Responsive 2-column Metadata Layout
                Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildMetricTile('Type', widget.result.serviceType),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _buildMetricTile('Depot', widget.result.depot)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            'Departure',
                            widget.result.scheduledDeparture,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricTile(
                            'Arrival',
                            widget.result.scheduledArrival,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            'Journey Date',
                            widget.result.journeyDate,
                          ),
                        ),
                        if (widget.result.vehicleNumber != null &&
                            widget.result.vehicleNumber!.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricTile(
                              'Vehicle',
                              widget.result.vehicleNumber!,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(
                      Icons.alt_route,
                      size: 16,
                      color: AppColors.secondaryText,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.result.viaSummary ?? 'Route details available',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: widget.result.viaSummary != null
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: AppColors.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTapDown: (_) => setState(() => _isChevronPressed = true),
                      onTapUp: (_) => setState(() => _isChevronPressed = false),
                      onTapCancel: () => setState(() => _isChevronPressed = false),
                      child: TextButton.icon(
                        onPressed: widget.onViewDetails,
                        icon: AnimatedContainer(
                          duration: AppMotion.fast,
                          transform: Matrix4.translationValues(
                            _isChevronPressed ? 3.0 : 0.0,
                            0,
                            0,
                          ),
                          child: const Icon(Icons.chevron_right_rounded, size: 18),
                        ),
                        label: const Text(
                          'View route',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: AppColors.primaryRed,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight - 4,
                  child: showTrackLiveButton
                      ? ElevatedButton.icon(
                          onPressed: widget.onTrackLive,
                          icon: const Icon(Icons.location_on, size: 20),
                          label: const Text('TRACK LIVE'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryRed,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.button),
                            ),
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: widget.onViewDetails,
                          icon: const Icon(Icons.route, size: 20),
                          label: Text(
                            widget.result.status == BusServiceStatus.completed
                                ? 'VIEW DETAILS / TRIP COMPLETED'
                                : 'VIEW DETAILS',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryText,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.button),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
        ),
        const SizedBox(height: 2),
        Text(
          value.isNotEmpty ? value : 'N/A',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

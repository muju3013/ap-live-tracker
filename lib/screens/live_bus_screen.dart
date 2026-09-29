import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/apsrtc_route_stop.dart';
import '../models/bus_live_location.dart';
import '../services/apsrtc_live_service.dart';
import '../services/apsrtc_route_stops_service.dart';
import '../theme/app_motion.dart';
import '../theme/app_tokens.dart';
import '../utils/trip_progress_resolver.dart';
import '../widgets/live_status_pill.dart';
import '../widgets/route_timeline.dart';

class LiveBusScreen extends StatefulWidget {
  final String serviceDocId;
  final ApsrtcLiveService? service;
  final ApsrtcRouteStopsService? routeStopsService;
  final Duration pollInterval;

  const LiveBusScreen({
    super.key,
    this.serviceDocId = '27092026_CT24_4_PILER',
    this.service,
    this.routeStopsService,
    this.pollInterval = const Duration(seconds: 10),
  });

  @override
  State<LiveBusScreen> createState() => _LiveBusScreenState();
}

class _LiveBusScreenState extends State<LiveBusScreen>
    with TickerProviderStateMixin {
  late final ApsrtcLiveService _liveService;
  late final ApsrtcRouteStopsService _routeStopsService;
  Timer? _pollTimer;

  BusLiveLocation? _currentLocation;
  ApsrtcRouteSegmentResult? _routeSegment;
  bool _isLoading = true;
  bool _isFetching = false;
  String? _errorMessage;

  final MapController _mapController = MapController();
  bool _hasUserPanned = false;
  bool _hasInitialCentered = false;

  late AnimationController _animController;
  LatLng _animStartLatLng = const LatLng(0, 0);
  LatLng _animTargetLatLng = const LatLng(0, 0);

  double _animStartBearing = 0.0;
  double _animTargetBearing = 0.0;

  @override
  void initState() {
    super.initState();
    _liveService = widget.service ?? ApsrtcLiveService();
    _routeStopsService = widget.routeStopsService ?? ApsrtcRouteStopsService();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _fetchData();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(widget.pollInterval, (_) {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final newLocation = await _liveService.fetchLiveLocation(
        serviceDocId: widget.serviceDocId,
      );

      if (!mounted) return;

      final newLatLng = LatLng(newLocation.latitude, newLocation.longitude);
      final newBearing = newLocation.locationBearing;

      setState(() {
        _errorMessage = null;
        _isLoading = false;

        if (_currentLocation == null) {
          _animStartLatLng = newLatLng;
          _animTargetLatLng = newLatLng;
          _animStartBearing = newBearing;
          _animTargetBearing = newBearing;
          _currentLocation = newLocation;

          if (!_hasInitialCentered) {
            _hasInitialCentered = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _mapController.move(newLatLng, 15.0);
              }
            });
          }
        } else {
          _animStartLatLng = _getAnimatedMarkerLatLng();
          _animTargetLatLng = newLatLng;
          _animStartBearing = _getAnimatedMarkerBearing();
          _animTargetBearing = newBearing;
          _currentLocation = newLocation;

          if (!AppMotion.isReducedMotion(context)) {
            _animController.forward(from: 0.0);
          } else {
            _animController.value = 1.0;
          }

          if (!_hasUserPanned) {
            _mapController.move(newLatLng, _mapController.camera.zoom);
          }
        }
      });

      if (_routeSegment == null) {
        final res = await _routeStopsService.resolveRouteStops(
          serviceDocId: widget.serviceDocId,
        );
        if (mounted) {
          setState(() {
            _routeSegment = res;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Live location temporarily unavailable';
      });
    } finally {
      _isFetching = false;
    }
  }

  LatLng _getAnimatedMarkerLatLng() {
    if (_animStartLatLng.latitude == 0 && _animStartLatLng.longitude == 0) {
      return _animTargetLatLng;
    }
    final t = Curves.easeInOut.transform(_animController.value);
    final lat =
        _animStartLatLng.latitude +
        (_animTargetLatLng.latitude - _animStartLatLng.latitude) * t;
    final lng =
        _animStartLatLng.longitude +
        (_animTargetLatLng.longitude - _animStartLatLng.longitude) * t;
    return LatLng(lat, lng);
  }

  double _getAnimatedMarkerBearing() {
    final t = Curves.easeInOut.transform(_animController.value);
    double delta = ((_animTargetBearing - _animStartBearing + 180) % 360) - 180;
    return _animStartBearing + delta * t;
  }

  void _recenterMap() {
    if (_currentLocation != null) {
      final target = _getAnimatedMarkerLatLng();
      setState(() {
        _hasUserPanned = false;
      });
      _animatedMapMove(target, 15.0);
    }
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final camera = _mapController.camera;
    final latTween = Tween<double>(begin: camera.center.latitude, end: destLocation.latitude);
    final lngTween = Tween<double>(begin: camera.center.longitude, end: destLocation.longitude);
    final zoomTween = Tween<double>(begin: camera.zoom, end: destZoom);

    final controller = AnimationController(
      duration: AppMotion.medium,
      vsync: this,
    );

    final Animation<double> animation = CurvedAnimation(
      parent: controller,
      curve: AppMotion.enter,
    );

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _animController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = _currentLocation;
    final serviceName = loc != null && loc.oprsNo.isNotEmpty
        ? 'Service: ${loc.oprsNo}'
        : 'APSRTC Live Bus Tracking';

    return Scaffold(
      appBar: AppBar(
        title: Text(serviceName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isFetching ? null : _fetchData,
            tooltip: 'Refresh Telemetry',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryRed),
                  SizedBox(height: AppSpacing.lg),
                  Text(
                    'Connecting to APSRTC live GPS feed...',
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                _buildMapSection(),
                if (_errorMessage != null)
                  Positioned(
                    top: 12,
                    left: AppSpacing.horizontalPadding,
                    right: AppSpacing.horizontalPadding,
                    child: _buildErrorBanner(),
                  ),
                if (loc != null)
                  Positioned(
                    top: _errorMessage != null ? 56 : 12,
                    left: AppSpacing.horizontalPadding,
                    child: LiveStatusPill(
                      classification: loc.getFreshnessClassification(),
                    ),
                  ),
                // Animated Recenter Button
                if (_hasUserPanned)
                  Positioned(
                    right: 16,
                    bottom: MediaQuery.of(context).size.height * 0.35 + 16,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: AppMotion.fast,
                      curve: AppMotion.springy,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: child,
                        );
                      },
                      child: FloatingActionButton.small(
                        onPressed: _recenterMap,
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.primaryRed,
                        tooltip: 'Recenter camera on bus',
                        child: const Icon(Icons.my_location),
                      ),
                    ),
                  ),
                _buildDraggableBottomSheet(),
              ],
            ),
    );
  }

  Widget _buildMapSection() {
    final loc = _currentLocation;
    final initialPos = loc != null
        ? LatLng(loc.latitude, loc.longitude)
        : const LatLng(13.6544, 78.9442);

    final markerPos = _getAnimatedMarkerLatLng();
    final markerBearing = _getAnimatedMarkerBearing();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: initialPos,
        initialZoom: 15.0,
        onPositionChanged: (position, hasGesture) {
          if (hasGesture && !_hasUserPanned) {
            setState(() {
              _hasUserPanned = true;
            });
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.ap_live_tracker',
        ),
        if (loc != null)
          MarkerLayer(
            markers: [
              Marker(
                point: markerPos,
                width: 52,
                height: 52,
                child: Transform.rotate(
                  angle: (markerBearing * pi) / 180,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primaryRed,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.navigation_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage ?? 'Live location temporarily unavailable',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableBottomSheet() {
    final loc = _currentLocation;
    if (loc == null) return const SizedBox.shrink();

    final ageSec = loc.getAgeInSeconds();
    final tripInfo = TripProgressResolver.resolve(location: loc);

    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.20,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 10,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vehicle ${loc.vehicleNumber}',
                              style: AppTypography.cardTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Service ${loc.oprsNo} • ${loc.serviceType}',
                              style: AppTypography.cardSubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '${loc.speed.toStringAsFixed(1)} km/h',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryText,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      _buildMetricTile(
                        'Latitude',
                        loc.latitude.toStringAsFixed(5),
                      ),
                      _buildMetricTile(
                        'Longitude',
                        loc.longitude.toStringAsFixed(5),
                      ),
                      _buildMetricTile(
                        'Bearing',
                        '${loc.locationBearing.toStringAsFixed(0)}°',
                      ),
                      _buildMetricTile(
                        'Telemetry',
                        TrackingFreshnessClassifier.formatAge(ageSec),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tripInfo.isCompleted
                                ? 'TRIP COMPLETED'
                                : 'Route Timeline',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: tripInfo.isCompleted
                                  ? AppColors.secondaryText
                                  : AppColors.primaryText,
                            ),
                          ),
                          if (tripInfo.isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.border,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'COMPLETED',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_routeSegment != null &&
                          _routeSegment!.viaSummary.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _routeSegment!.viaSummary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  RouteTimeline(stops: _buildTimelineStops(loc, tripInfo)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<RouteWaypointStop> _buildTimelineStops(
    BusLiveLocation loc,
    TripProgressInfo tripInfo,
  ) {
    final routeSeg = _routeSegment;
    if (routeSeg == null || routeSeg.visibleSegmentStops.isEmpty) {
      if (tripInfo.isCompleted) {
        return [
          RouteWaypointStop(
            stationId: 'src',
            stationName: loc.serviceType.contains('EXPRESS')
                ? 'ORIGIN DEPOT'
                : 'STARTING STOP',
            scheduledTime: loc.locationTime,
            status: StopStatus.completed,
          ),
          const RouteWaypointStop(
            stationId: 'dest',
            stationName: 'DESTINATION STATION',
            actualTime: 'Completed',
            status: StopStatus.completed,
          ),
        ];
      }

      return [
        RouteWaypointStop(
          stationId: 'src',
          stationName: loc.serviceType.contains('EXPRESS')
              ? 'ORIGIN DEPOT'
              : 'STARTING STOP',
          scheduledTime: loc.locationTime,
          status: StopStatus.completed,
        ),
        RouteWaypointStop(
          stationId: 'current',
          stationName:
              'NEAR LAT: ${loc.latitude.toStringAsFixed(3)}, LNG: ${loc.longitude.toStringAsFixed(3)}',
          actualTime: tripInfo.isStale ? 'Last known stop' : 'Current stop',
          status: tripInfo.isStale ? StopStatus.lastKnown : StopStatus.current,
        ),
        const RouteWaypointStop(
          stationId: 'dest',
          stationName: 'DESTINATION STATION',
          status: StopStatus.upcoming,
        ),
      ];
    }

    final rawStops = routeSeg.visibleSegmentStops;
    final List<RouteWaypointStop> stops = [];

    if (tripInfo.isCompleted) {
      for (int i = 0; i < rawStops.length; i++) {
        final s = rawStops[i];
        if (s.isSkipped) {
          stops.add(
            RouteWaypointStop(
              stationId: s.stationId,
              stationName: s.placeName,
              actualTime: 'Skipped',
              status: StopStatus.skipped,
            ),
          );
          continue;
        }

        String? timeLabel;
        if (s.actualDeparture != null && s.actualDeparture!.isNotEmpty) {
          timeLabel = 'Departed ${s.actualDeparture}';
        } else if (s.actualArrival != null && s.actualArrival!.isNotEmpty) {
          timeLabel = 'Arrived ${s.actualArrival}';
        } else if (i == rawStops.length - 1) {
          timeLabel = 'Completed';
        } else if (s.scheduledDeparture != null &&
            s.scheduledDeparture!.isNotEmpty) {
          timeLabel = s.scheduledDeparture;
        } else if (s.scheduledArrival != null &&
            s.scheduledArrival!.isNotEmpty) {
          timeLabel = s.scheduledArrival;
        }

        stops.add(
          RouteWaypointStop(
            stationId: s.stationId,
            stationName: s.placeName,
            scheduledTime: s.scheduledArrival ?? s.scheduledDeparture,
            actualTime: timeLabel,
            status: StopStatus.completed,
          ),
        );
      }
      return stops;
    }

    int currentIdx = -1;
    if (tripInfo.currentBoardingPoint != null &&
        tripInfo.currentBoardingPoint!.isNotEmpty) {
      currentIdx = rawStops.indexWhere(
        (s) => s.stationId == tripInfo.currentBoardingPoint,
      );
    }
    if (currentIdx == -1 &&
        tripInfo.currentSeqNo != null &&
        tripInfo.currentSeqNo! > 0) {
      currentIdx = rawStops.indexWhere(
        (s) => s.sequenceNo == tripInfo.currentSeqNo,
      );
    }
    if (currentIdx == -1) {
      currentIdx = rawStops.indexWhere(
        (s) => s.actualDeparture == null && !s.isSkipped,
      );
      if (currentIdx == -1) currentIdx = 0;
    }

    for (int i = 0; i < rawStops.length; i++) {
      final s = rawStops[i];

      if (s.isSkipped) {
        stops.add(
          RouteWaypointStop(
            stationId: s.stationId,
            stationName: s.placeName,
            actualTime: 'Skipped',
            status: StopStatus.skipped,
          ),
        );
        continue;
      }

      if (i < currentIdx) {
        String? timeLabel;
        if (s.actualDeparture != null && s.actualDeparture!.isNotEmpty) {
          timeLabel = 'Departed ${s.actualDeparture}';
        } else if (s.actualArrival != null && s.actualArrival!.isNotEmpty) {
          timeLabel = 'Arrived ${s.actualArrival}';
        } else if (s.scheduledDeparture != null &&
            s.scheduledDeparture!.isNotEmpty) {
          timeLabel = s.scheduledDeparture;
        } else if (s.scheduledArrival != null &&
            s.scheduledArrival!.isNotEmpty) {
          timeLabel = s.scheduledArrival;
        }

        stops.add(
          RouteWaypointStop(
            stationId: s.stationId,
            stationName: s.placeName,
            scheduledTime: s.scheduledArrival ?? s.scheduledDeparture,
            actualTime: timeLabel,
            status: StopStatus.completed,
          ),
        );
      } else if (i == currentIdx) {
        final isStale = tripInfo.isStale;
        String label;
        if (s.actualArrival != null && s.actualArrival!.isNotEmpty) {
          label = 'Arrived ${s.actualArrival}';
        } else if (isStale) {
          label = 'Last known stop';
        } else {
          label = 'Current stop';
        }

        stops.add(
          RouteWaypointStop(
            stationId: s.stationId,
            stationName: s.placeName,
            scheduledTime: s.scheduledArrival ?? s.scheduledDeparture,
            actualTime: label,
            status: isStale ? StopStatus.lastKnown : StopStatus.current,
          ),
        );
      } else {
        String? timeLabel;
        if (s.eta != null && s.eta!.isNotEmpty) {
          timeLabel = 'ETA ${s.eta}';
        } else if (s.scheduledArrival != null &&
            s.scheduledArrival!.isNotEmpty) {
          timeLabel = 'Scheduled ${s.scheduledArrival}';
        } else if (s.scheduledDeparture != null &&
            s.scheduledDeparture!.isNotEmpty) {
          timeLabel = 'Scheduled ${s.scheduledDeparture}';
        }

        stops.add(
          RouteWaypointStop(
            stationId: s.stationId,
            stationName: s.placeName,
            scheduledTime: s.scheduledArrival ?? s.scheduledDeparture,
            actualTime: timeLabel,
            status: StopStatus.upcoming,
          ),
        );
      }
    }

    return stops;
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
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
      ],
    );
  }
}

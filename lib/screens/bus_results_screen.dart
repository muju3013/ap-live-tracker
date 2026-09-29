import 'package:flutter/material.dart';

import '../models/apsrtc_service_search_result.dart';
import '../models/apsrtc_station.dart';
import '../services/apsrtc_route_stops_service.dart';
import '../services/apsrtc_search_service.dart';
import '../theme/app_motion.dart';
import '../theme/app_tokens.dart';
import '../widgets/bus_service_card.dart';
import '../widgets/route_details_sheet.dart';
import '../widgets/skeleton_loader.dart';
import 'live_bus_screen.dart';

enum ServiceFilterChip { all, liveNow, upcoming, departed }

class BusResultsScreen extends StatefulWidget {
  final ApsrtcStation fromStation;
  final ApsrtcStation toStation;
  final ApsrtcSearchService searchService;
  final ApsrtcRouteStopsService? routeStopsService;

  const BusResultsScreen({
    super.key,
    required this.fromStation,
    required this.toStation,
    required this.searchService,
    this.routeStopsService,
  });

  @override
  State<BusResultsScreen> createState() => _BusResultsScreenState();
}

class _BusResultsScreenState extends State<BusResultsScreen> {
  late final ApsrtcRouteStopsService _routeStopsService;
  List<ApsrtcServiceSearchResult> _allResults = [];
  List<ApsrtcServiceSearchResult> _filteredResults = [];
  ServiceFilterChip _selectedFilter = ServiceFilterChip.all;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _routeStopsService = widget.routeStopsService ?? ApsrtcRouteStopsService();
    _performSearch();
  }

  Future<void> _performSearch() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await widget.searchService.searchServices(
        fromStation: widget.fromStation,
        toStation: widget.toStation,
      );

      if (!mounted) return;

      setState(() {
        _allResults = results;
        _applyFilter(_selectedFilter);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Unable to load APSRTC services. Please check network connection.';
        _isLoading = false;
      });
    }
  }

  void _applyFilter(ServiceFilterChip filter) {
    _selectedFilter = filter;
    switch (filter) {
      case ServiceFilterChip.all:
        _filteredResults = List.from(_allResults);
        break;
      case ServiceFilterChip.liveNow:
        _filteredResults = _allResults
            .where((r) => r.status == BusServiceStatus.running)
            .toList();
        break;
      case ServiceFilterChip.upcoming:
        _filteredResults = _allResults
            .where((r) => r.status == BusServiceStatus.upcoming)
            .toList();
        break;
      case ServiceFilterChip.departed:
        _filteredResults = _allResults
            .where((r) => r.status == BusServiceStatus.completed)
            .toList();
        break;
    }
  }

  void _openLiveTracking(String serviceDocId) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, secondaryAnimation) =>
            LiveBusScreen(serviceDocId: serviceDocId),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          final slideAnimation = Tween<Offset>(
            begin: const Offset(0.05, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: AppMotion.enter,
          ));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: slideAnimation,
              child: child,
            ),
          );
        },
        transitionDuration: AppMotion.normal,
      ),
    );
  }

  void _showRouteDetails(ApsrtcServiceSearchResult item) {
    RouteDetailsSheet.show(
      context,
      result: item,
      routeStopsService: _routeStopsService,
    );
  }

  @override
  Widget build(BuildContext context) {
    final upcomingCount = _allResults
        .where((r) => r.status == BusServiceStatus.upcoming)
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              '${widget.fromStation.placeName} → ${widget.toStation.placeName}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Today • $upcomingCount upcoming services',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppMotion.normal,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.horizontalPadding,
        vertical: AppSpacing.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildChip(ServiceFilterChip.all, 'All (${_allResults.length})'),
            const SizedBox(width: AppSpacing.sm),
            _buildChip(
              ServiceFilterChip.liveNow,
              'Live now (${_allResults.where((r) => r.status == BusServiceStatus.running).length})',
            ),
            const SizedBox(width: AppSpacing.sm),
            _buildChip(
              ServiceFilterChip.upcoming,
              'Upcoming (${_allResults.where((r) => r.status == BusServiceStatus.upcoming).length})',
            ),
            const SizedBox(width: AppSpacing.sm),
            _buildChip(
              ServiceFilterChip.departed,
              'Departed (${_allResults.where((r) => r.status == BusServiceStatus.completed).length})',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(ServiceFilterChip chip, String label) {
    final isSelected = _selectedFilter == chip;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _applyFilter(chip));
      },
      selectedColor: AppColors.primaryRed,
      backgroundColor: AppColors.background,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.primaryText,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        side: BorderSide(
          color: isSelected ? AppColors.primaryRed : AppColors.border,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        key: const ValueKey('loading_list'),
        padding: const EdgeInsets.only(top: AppSpacing.md),
        itemCount: 3,
        itemBuilder: (context, index) => const BusCardSkeleton(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        key: const ValueKey('error_body'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.primaryRed,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: _performSearch,
                icon: const Icon(Icons.refresh),
                label: const Text('RETRY'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredResults.isEmpty) {
      return Center(
        key: const ValueKey('empty_body'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.directions_bus_filled,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'No matching services for this filter.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      key: ValueKey('results_list_${_selectedFilter.name}'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: _filteredResults.length,
      itemBuilder: (context, index) {
        final result = _filteredResults[index];
        final childCard = BusServiceCard(
          result: result,
          onTrackLive: () => _openLiveTracking(result.serviceDocId),
          onViewDetails: () => _showRouteDetails(result),
        );

        // Stagger first 5-6 cards
        if (index < 6 && !AppMotion.isReducedMotion(context)) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 240 + (index * 35)),
            curve: AppMotion.enter,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, (1.0 - value) * 10),
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: childCard,
          );
        }

        return childCard;
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../models/apsrtc_station.dart';
import '../services/apsrtc_place_repository.dart';
import '../services/apsrtc_search_service.dart';
import '../services/recent_search_service.dart';
import '../theme/app_motion.dart';
import '../theme/app_tokens.dart';
import '../widgets/recent_search_card.dart';
import '../widgets/station_route_card.dart';
import 'bus_results_screen.dart';
import 'station_picker_sheet.dart';

class HomeScreen extends StatefulWidget {
  final ApsrtcSearchService? searchService;
  final ApsrtcPlaceRepository? placeRepository;
  final RecentSearchService? recentSearchService;

  const HomeScreen({
    super.key,
    this.searchService,
    this.placeRepository,
    this.recentSearchService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final ApsrtcSearchService _searchService;
  late final ApsrtcPlaceRepository _placeRepository;
  late final RecentSearchService _recentSearchService;

  late final AnimationController _entranceController;
  late final Animation<double> _headerFade;
  late final Animation<double> _cardSlide;
  late final Animation<double> _cardFade;
  late final Animation<double> _trustFade;
  late final Animation<double> _recentFade;

  ApsrtcStation? _fromStation;
  ApsrtcStation? _toStation;
  List<RecentSearchItem> _recentSearches = [];
  bool _isLoadingPlaces = true;

  @override
  void initState() {
    super.initState();
    _searchService = widget.searchService ?? ApsrtcSearchService();
    _placeRepository = widget.placeRepository ?? _searchService.placeRepository;
    _recentSearchService = widget.recentSearchService ?? RecentSearchService();

    // Staggered Entrance Controller
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _headerFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOutCubic),
    );

    _cardFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.20, 0.70, curve: Curves.easeOutCubic),
    );

    _cardSlide = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.20, 0.70, curve: Curves.easeOutCubic),
      ),
    );

    _trustFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.40, 0.85, curve: Curves.easeOutCubic),
    );

    _recentFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.60, 1.0, curve: Curves.easeOutCubic),
    );

    _initData();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await _loadDefaultStations();
    await _loadRecentSearches();

    if (mounted) {
      if (AppMotion.isReducedMotion(context)) {
        _entranceController.value = 1.0;
      } else {
        _entranceController.forward();
      }
    }
  }

  Future<void> _loadRecentSearches() async {
    final list = await _recentSearchService.getRecentSearches();
    if (mounted) {
      setState(() => _recentSearches = list);
    }
  }

  Future<void> _loadDefaultStations() async {
    try {
      await _placeRepository.loadPlaces();
      final loadedFrom = _placeRepository.getPlaceById('14911');
      final loadedTo = _placeRepository.getPlaceById('6021');

      if (mounted) {
        setState(() {
          _fromStation =
              loadedFrom ??
              const ApsrtcStation(
                placeId: '14911',
                linkPlaceId: '14911',
                placeName: 'TIRUPATHI',
                mandalName: 'TIRUPATI URBAN',
                pinCode: '517501',
              );
          _toStation =
              loadedTo ??
              const ApsrtcStation(
                placeId: '6021',
                linkPlaceId: '6021',
                placeName: 'KADAPA',
                mandalName: 'KADAPA',
                pinCode: '516001',
              );
          _isLoadingPlaces = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _fromStation = const ApsrtcStation(
            placeId: '14911',
            linkPlaceId: '14911',
            placeName: 'TIRUPATHI',
            mandalName: 'TIRUPATI URBAN',
            pinCode: '517501',
          );
          _toStation = const ApsrtcStation(
            placeId: '6021',
            linkPlaceId: '6021',
            placeName: 'KADAPA',
            mandalName: 'KADAPA',
            pinCode: '516001',
          );
          _isLoadingPlaces = false;
        });
      }
    }
  }

  void _swapStations() {
    if (_fromStation == null || _toStation == null) return;
    setState(() {
      final temp = _fromStation;
      _fromStation = _toStation;
      _toStation = temp;
    });
  }

  void _openStationPicker(bool isFrom) {
    showModalBottomSheet<ApsrtcStation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StationPickerSheet(
        title: isFrom
            ? 'Select Departure Station'
            : 'Select Destination Station',
        placeRepository: _placeRepository,
        currentSelection: isFrom ? _fromStation : _toStation,
      ),
    ).then((selected) {
      if (selected == null || !mounted) return;

      if (isFrom) {
        if (selected.placeId == _toStation?.placeId) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('FROM and TO stations cannot be identical.'),
            ),
          );
          return;
        }
        setState(() => _fromStation = selected);
      } else {
        if (selected.placeId == _fromStation?.placeId) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('FROM and TO stations cannot be identical.'),
            ),
          );
          return;
        }
        setState(() => _toStation = selected);
      }
    });
  }

  Future<void> _navigateToResults({
    ApsrtcStation? overrideFrom,
    ApsrtcStation? overrideTo,
  }) async {
    final from = overrideFrom ?? _fromStation;
    final to = overrideTo ?? _toStation;

    if (from == null || to == null) return;
    if (from.placeId == to.placeId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('FROM and TO stations cannot have the same placeId.'),
        ),
      );
      return;
    }

    // Save recent search
    await _recentSearchService.addRecentSearch(from, to);
    await _loadRecentSearches();

    if (!mounted) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, secondaryAnimation) => BusResultsScreen(
          fromStation: from,
          toStation: to,
          searchService: _searchService,
        ),
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

  Future<void> _clearRecentSearches() async {
    await _recentSearchService.clearRecentSearches();
    await _loadRecentSearches();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _entranceController,
          builder: (context, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header Entrance
                  FadeTransition(
                    opacity: _headerFade,
                    child: _buildStitchHeader(),
                  ),
                  const SizedBox(height: 16),
                  // 2. Station Route Card Entrance (Slide 12px + Fade)
                  _isLoadingPlaces
                      ? const Padding(
                          padding: EdgeInsets.all(AppSpacing.horizontalPadding),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Transform.translate(
                          offset: Offset(0, _cardSlide.value),
                          child: FadeTransition(
                            opacity: _cardFade,
                            child: StationRouteCard(
                              fromStation: _fromStation,
                              toStation: _toStation,
                              onSelectFrom: () => _openStationPicker(true),
                              onSelectTo: () => _openStationPicker(false),
                              onSwap: _swapStations,
                              onSearch: _navigateToResults,
                            ),
                          ),
                        ),
                  const SizedBox(height: 16),
                  // 3. Trust Row Entrance
                  FadeTransition(
                    opacity: _trustFade,
                    child: _buildTrustRow(),
                  ),
                  const SizedBox(height: 24),
                  // 4. Recent Searches Entrance
                  FadeTransition(
                    opacity: _recentFade,
                    child: RecentSearchSection(
                      items: _recentSearches,
                      onItemTap: (item) {
                        setState(() {
                          _fromStation = item.fromStation;
                          _toStation = item.toStation;
                        });
                        _navigateToResults(
                          overrideFrom: item.fromStation,
                          overrideTo: item.toStation,
                        );
                      },
                      onClear: _clearRecentSearches,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStitchHeader() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.horizontalPadding,
        vertical: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Home',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.primaryRed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.primaryRed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_bus_filled_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'AP BUS LIVE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryRed,
                        letterSpacing: 0.6,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Where are you going?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.black87,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Track APSRTC buses across Andhra Pradesh',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.horizontalPadding,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F5F7),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryRed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Real APSRTC services',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            Container(height: 14, width: 1, color: Colors.grey.shade300),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Live GPS available',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

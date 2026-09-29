import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/home_screen.dart';
import '../screens/track_screen.dart';
import '../services/apsrtc_place_repository.dart';
import '../services/apsrtc_search_service.dart';
import '../services/apsrtc_vehicle_search_service.dart';
import '../services/recent_search_service.dart';
import '../services/recent_track_service.dart';
import '../theme/app_motion.dart';
import '../theme/app_tokens.dart';

class BottomNavShell extends StatefulWidget {
  final int initialIndex;
  final ApsrtcSearchService? searchService;
  final ApsrtcPlaceRepository? placeRepository;
  final RecentSearchService? recentSearchService;
  final ApsrtcVehicleSearchService? vehicleSearchService;
  final RecentTrackService? recentTrackService;

  const BottomNavShell({
    super.key,
    this.initialIndex = 0,
    this.searchService,
    this.placeRepository,
    this.recentSearchService,
    this.vehicleSearchService,
    this.recentTrackService,
  });

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  late int _currentIndex;

  late final HomeScreen _homeScreen;
  late final TrackScreen _trackScreen;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _homeScreen = HomeScreen(
      searchService: widget.searchService,
      placeRepository: widget.placeRepository,
      recentSearchService: widget.recentSearchService,
    );

    _trackScreen = TrackScreen(
      vehicleSearchService: widget.vehicleSearchService,
      recentTrackService: widget.recentTrackService,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: AppMotion.fast,
        switchInCurve: AppMotion.enter,
        switchOutCurve: AppMotion.exit,
        transitionBuilder: (child, animation) {
          final isHome = child.key == const ValueKey(0);
          final slideOffset = isHome ? const Offset(-0.03, 0.0) : const Offset(0.03, 0.0);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: slideOffset,
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: _currentIndex == 0 ? _homeScreen : _trackScreen,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
          border: Border(
            top: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                activeIcon: Icons.home_rounded,
                inactiveIcon: Icons.home_outlined,
                label: 'Home',
              ),
              _buildNavItem(
                index: 1,
                activeIcon: Icons.directions_bus_rounded,
                inactiveIcon: Icons.directions_bus_outlined,
                label: 'Track',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;

    return InkWell(
      onTap: () {
        if (_currentIndex != index) {
          HapticFeedback.lightImpact();
          setState(() => _currentIndex = index);
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppMotion.fast,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFEE2E2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: isSelected ? 1.12 : 1.0),
                duration: AppMotion.fast,
                curve: AppMotion.standard,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: AppMotion.isReducedMotion(context) ? 1.0 : scale,
                    child: Icon(
                      isSelected ? activeIcon : inactiveIcon,
                      color: isSelected ? AppColors.primaryRed : Colors.grey.shade600,
                      size: 22,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primaryRed : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

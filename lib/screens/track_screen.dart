import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/apsrtc_vehicle_search_service.dart';
import '../services/recent_track_service.dart';
import '../theme/app_motion.dart';
import '../theme/app_tokens.dart';
import '../widgets/track_bus_card.dart';
import 'live_bus_screen.dart';

class TrackScreen extends StatefulWidget {
  final ApsrtcVehicleSearchService? vehicleSearchService;
  final RecentTrackService? recentTrackService;

  const TrackScreen({
    super.key,
    this.vehicleSearchService,
    this.recentTrackService,
  });

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  late final ApsrtcVehicleSearchService _vehicleSearchService;
  late final RecentTrackService _recentTrackService;
  final TextEditingController _vehicleController = TextEditingController();

  List<RecentTrackItem> _recentTracks = [];
  bool _isSearching = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _vehicleSearchService =
        widget.vehicleSearchService ?? ApsrtcVehicleSearchService();
    _recentTrackService = widget.recentTrackService ?? RecentTrackService();
    _loadRecentTracks();
  }

  @override
  void dispose() {
    _vehicleController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentTracks() async {
    final list = await _recentTrackService.getRecentTracks();
    if (mounted) {
      setState(() => _recentTracks = list);
    }
  }

  Future<void> _performVehicleSearch([String? rawQuery]) async {
    final query = (rawQuery ?? _vehicleController.text).trim();
    if (query.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a vehicle number.';
      });
      return;
    }

    HapticFeedback.lightImpact();

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final results = await _vehicleSearchService.searchVehicle(query);

      if (!mounted) return;

      if (results.isEmpty) {
        setState(() {
          _isSearching = false;
          _errorMessage =
              'No active APSRTC service found for this vehicle number.';
        });
        return;
      }

      setState(() => _isSearching = false);

      if (results.length == 1) {
        _openLiveTracking(results.first);
      } else {
        _showSelectionBottomSheet(results);
      }
    } catch (e) {
      if (!mounted) return;
      final String safeMsg;
      if (e is SocketException) {
        safeMsg =
            'Network connection unavailable. Please check your internet connection.';
      } else if (e is TimeoutException) {
        safeMsg = 'Vehicle tracking request timed out. Please try again.';
      } else {
        safeMsg =
            'Vehicle search failed (${e.toString().replaceAll('Exception: ', '')}).';
      }
      setState(() {
        _isSearching = false;
        _errorMessage = safeMsg;
      });
    }
  }

  Future<void> _openLiveTracking(ApsrtcVehicleSearchResult result) async {
    final item = RecentTrackItem(
      vehicleNumber: result.vehicleNumber.isNotEmpty
          ? result.vehicleNumber
          : _vehicleController.text.toUpperCase(),
      serviceDocId: result.serviceDocId,
      oprsNo: result.oprsNo,
      serviceType: result.serviceType,
      routeSummary: result.routeSummary,
      lastTrackedAt: DateTime.now(),
    );

    await _recentTrackService.addRecentTrack(item);
    await _loadRecentTracks();

    if (!mounted) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, secondaryAnimation) =>
            LiveBusScreen(serviceDocId: result.serviceDocId),
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

  void _showSelectionBottomSheet(List<ApsrtcVehicleSearchResult> results) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Multiple Active Services Found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Select service to track for vehicle ${_vehicleController.text.toUpperCase()}:',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final item = results[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.directions_bus,
                          color: AppColors.primaryRed,
                        ),
                        title: Text(
                          item.oprsNo.isNotEmpty
                              ? 'Service #${item.oprsNo} (${item.serviceType})'
                              : item.serviceDocId,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(item.routeSummary),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).pop();
                          _openLiveTracking(item);
                        },
                      ),
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

  Future<void> _clearHistory() async {
    await _recentTrackService.clearRecentTracks();
    await _loadRecentTracks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Track Bus'), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderSection(),
              const SizedBox(height: 16),
              _buildSearchCard(),
              AnimatedSize(
                duration: AppMotion.fast,
                curve: AppMotion.enter,
                child: _errorMessage != null
                    ? _buildErrorBanner()
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
              RecentlyTrackedSection(
                items: _recentTracks,
                onItemTap: (item) {
                  _vehicleController.text = item.vehicleNumber;
                  _performVehicleSearch(item.vehicleNumber);
                },
                onClear: _clearHistory,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.horizontalPadding,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Track Bus',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Track APSRTC bus using vehicle number',
            style: TextStyle(fontSize: 14, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    final bool hasText = _vehicleController.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.horizontalPadding,
      ),
      child: Container(
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
          border: Border.all(
            color: hasText ? AppColors.primaryRed.withValues(alpha: 0.5) : Colors.grey.shade200,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: AppMotion.fast,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasText ? AppColors.primaryRed : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _vehicleController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Enter vehicle number',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon: const Icon(
                    Icons.directions_bus_outlined,
                    color: AppColors.primaryRed,
                  ),
                  suffixIcon: _vehicleController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _vehicleController.clear();
                            setState(() => _errorMessage = null);
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (_) => _performVehicleSearch(),
                onChanged: (_) {
                  setState(() {
                    if (_errorMessage != null) {
                      _errorMessage = null;
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Ex: AP39X6803',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSearching ? null : () => _performVehicleSearch(),
                icon: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.radar_rounded, size: 22),
                label: Text(
                  _isSearching ? 'SEARCHING...' : 'TRACK BUS',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.horizontalPadding,
        vertical: 12,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.primaryRed,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

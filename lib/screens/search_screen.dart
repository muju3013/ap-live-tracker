import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/apsrtc_service_search_result.dart';
import '../models/apsrtc_station.dart';
import '../services/apsrtc_place_repository.dart';
import '../services/apsrtc_search_service.dart';
import 'live_bus_screen.dart';

class SearchScreen extends StatefulWidget {
  final ApsrtcSearchService? searchService;
  final ApsrtcPlaceRepository? placeRepository;

  const SearchScreen({super.key, this.searchService, this.placeRepository});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final ApsrtcSearchService _searchService;
  late final ApsrtcPlaceRepository _placeRepository;

  ApsrtcStation _fromStation = const ApsrtcStation(
    placeId: '14911',
    linkPlaceId: '14911',
    placeName: 'TIRUPATHI',
    mandalName: 'TIRUPATI URBAN',
    pinCode: '517501',
  );

  ApsrtcStation _toStation = const ApsrtcStation(
    placeId: '6021',
    linkPlaceId: '6021',
    placeName: 'KADAPA',
    mandalName: 'KADAPA',
    pinCode: '516001',
  );

  List<ApsrtcServiceSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchService = widget.searchService ?? ApsrtcSearchService();
    _placeRepository = widget.placeRepository ?? _searchService.placeRepository;
    _initPlaces();
  }

  Future<void> _initPlaces() async {
    try {
      await _placeRepository.loadPlaces();
      final loadedFrom = _placeRepository.getPlaceById('14911');
      final loadedTo = _placeRepository.getPlaceById('6021');

      if (mounted) {
        setState(() {
          if (loadedFrom != null) _fromStation = loadedFrom;
          if (loadedTo != null) _toStation = loadedTo;
        });
      }
    } catch (_) {
      // Fallback default stations already set
    }
  }

  void _swapStations() {
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _StationSearchModal(
        title: isFrom ? 'Select FROM Station' : 'Select TO Station',
        placeRepository: _placeRepository,
        currentSelection: isFrom ? _fromStation : _toStation,
      ),
    ).then((selected) {
      if (selected == null || !mounted) return;

      if (isFrom) {
        if (selected.placeId == _toStation.placeId) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('FROM and TO stations cannot be identical.'),
            ),
          );
          return;
        }
        setState(() => _fromStation = selected);
      } else {
        if (selected.placeId == _fromStation.placeId) {
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

  Future<void> _performSearch() async {
    if (_fromStation.placeId == _toStation.placeId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('FROM and TO stations cannot have the same placeId.'),
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _errorMessage = null;
    });

    try {
      final results = await _searchService.searchServices(
        fromStation: _fromStation,
        toStation: _toStation,
      );

      if (!mounted) return;

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      final String safeMsg;
      if (e is SocketException) {
        safeMsg =
            'Network connection unavailable. Please check internet connection.';
      } else if (e is TimeoutException) {
        safeMsg = 'Connection timed out while fetching APSRTC services.';
      } else {
        safeMsg =
            'Failed to fetch APSRTC services (${e.toString().replaceAll('Exception: ', '')}).';
      }
      setState(() {
        _errorMessage = safeMsg;
        _isSearching = false;
      });
    }
  }

  void _openLiveTracking(String serviceDocId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveBusScreen(serviceDocId: serviceDocId),
      ),
    );
  }

  void _showRouteDetails(ApsrtcServiceSearchResult item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Service ${item.serviceNumber} - Route Info',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              Text('Route: ${item.source} ➔ ${item.destination}'),
              Text('Service Type: ${item.serviceType}'),
              Text('Depot: ${item.depot}'),
              Text('Departure: ${item.scheduledDeparture}'),
              Text('Arrival: ${item.scheduledArrival}'),
              Text('Journey Date: ${item.journeyDate}'),
              Text('Status: ${item.statusText}'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('APSRTC Live'), centerTitle: true),
      body: Column(
        children: [
          _buildSearchHeaderCard(),
          Expanded(child: _buildResultsSection()),
        ],
      ),
    );
  }

  Widget _buildSearchHeaderCard() {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildStationTile(
                        label: 'FROM Station',
                        icon: Icons.trip_origin,
                        station: _fromStation,
                        onTap: () => _openStationPicker(true),
                      ),
                      const SizedBox(height: 12),
                      _buildStationTile(
                        label: 'TO Station',
                        icon: Icons.location_on,
                        station: _toStation,
                        onTap: () => _openStationPicker(false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.swap_vert_rounded, size: 28),
                  tooltip: 'Swap From and To',
                  onPressed: _swapStations,
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _isSearching ? null : _performSearch,
                icon: const Icon(Icons.search),
                label: const Text(
                  'SEARCH BUSES',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationTile({
    required String label,
    required IconData icon,
    required ApsrtcStation station,
    required VoidCallback onTap,
  }) {
    final subtitle = station.displaySubtitle;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.search, size: 20),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              station.placeName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching current APSRTC buses...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _performSearch,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_bus_filled,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'Select FROM and TO stations to search live buses.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'No matching services found for selected route.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        return _buildServiceResultCard(item);
      },
    );
  }

  Widget _buildServiceResultCard(ApsrtcServiceSearchResult item) {
    Color badgeColor;
    switch (item.status) {
      case BusServiceStatus.running:
        badgeColor = Colors.green.shade700;
        break;
      case BusServiceStatus.upcoming:
        badgeColor = Colors.blue.shade800;
        break;
      case BusServiceStatus.completed:
        badgeColor = Colors.grey.shade700;
        break;
      case BusServiceStatus.trackingUnavailable:
        badgeColor = Colors.amber.shade900;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Service: ${item.serviceNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${item.fromStop} ➔ ${item.toStop}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            if (item.source != item.fromStop || item.destination != item.toStop)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Full Route: ${item.source} ➔ ${item.destination}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoTile('Type', item.serviceType),
                _buildInfoTile('Depot', item.depot),
                _buildInfoTile('Departure', item.scheduledDeparture),
                _buildInfoTile('Arrival', item.scheduledArrival),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoTile('Journey Date', item.journeyDate),
                if (item.vehicleNumber != null &&
                    item.vehicleNumber!.isNotEmpty)
                  _buildInfoTile('Vehicle', item.vehicleNumber!),
                _buildInfoTile('Doc ID', _shortenDocId(item.serviceDocId)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: item.isTrackingAvailable
                  ? ElevatedButton.icon(
                      onPressed: () => _openLiveTracking(item.serviceDocId),
                      icon: const Icon(Icons.location_on),
                      label: const Text('TRACK LIVE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: () => _showRouteDetails(item),
                      icon: const Icon(Icons.route),
                      label: const Text('VIEW ROUTE'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  String _shortenDocId(String docId) {
    if (docId.length > 18) {
      return '${docId.substring(0, 15)}...';
    }
    return docId;
  }
}

class _StationSearchModal extends StatefulWidget {
  final String title;
  final ApsrtcPlaceRepository placeRepository;
  final ApsrtcStation currentSelection;

  const _StationSearchModal({
    required this.title,
    required this.placeRepository,
    required this.currentSelection,
  });

  @override
  State<_StationSearchModal> createState() => _StationSearchModalState();
}

class _StationSearchModalState extends State<_StationSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  List<ApsrtcStation> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _suggestions = widget.placeRepository.searchPlaces('', limit: 30);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _suggestions = widget.placeRepository.searchPlaces(
        _searchController.text,
        limit: 30,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search APSRTC station (e.g. TIRU, KADA, KALLU)...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_suggestions.length} matching stations',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _suggestions.isEmpty
                    ? Center(
                        child: Text(
                          'No stations matching "${_searchController.text}"',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: _suggestions.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final station = _suggestions[index];
                          final isSelected =
                              station.placeId ==
                              widget.currentSelection.placeId;
                          final subtitle = station.displaySubtitle;

                          return ListTile(
                            title: Text(
                              station.placeName,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ),
                            subtitle: subtitle.isNotEmpty
                                ? Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  )
                                : Text(
                                    'ID: ${station.placeId}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  )
                                : const Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey,
                                  ),
                            onTap: () => Navigator.pop(context, station),
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
}

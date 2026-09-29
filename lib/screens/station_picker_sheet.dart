import 'package:flutter/material.dart';

import '../models/apsrtc_station.dart';
import '../services/apsrtc_place_repository.dart';
import '../theme/app_tokens.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/station_picker_tile.dart';

class StationPickerSheet extends StatefulWidget {
  final String title;
  final ApsrtcPlaceRepository placeRepository;
  final ApsrtcStation? currentSelection;

  const StationPickerSheet({
    super.key,
    required this.title,
    required this.placeRepository,
    this.currentSelection,
  });

  @override
  State<StationPickerSheet> createState() => _StationPickerSheetState();
}

class _StationPickerSheetState extends State<StationPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<ApsrtcStation> _suggestions = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _suggestions = widget.placeRepository.searchPlaces('', limit: 30);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() => _isSearching = true);
    final results = widget.placeRepository.searchPlaces(
      _searchController.text,
      limit: 30,
    );
    setState(() {
      _suggestions = results;
      _isSearching = false;
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
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.horizontalPadding,
            vertical: 12,
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search station by name, mandal, or pincode...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.secondaryText,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: AppColors.secondaryText,
                          ),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Showing ${_suggestions.length} matching stations',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: _isSearching
                    ? ListView.builder(
                        itemCount: 5,
                        itemBuilder: (context, index) =>
                            const StationTileSkeleton(),
                      )
                    : _suggestions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No stations found matching "${_searchController.text}"',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: _suggestions.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, index) {
                          final station = _suggestions[index];
                          final isSelected =
                              widget.currentSelection?.placeId ==
                              station.placeId;

                          return StationPickerTile(
                            station: station,
                            isSelected: isSelected,
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

import 'package:flutter/material.dart';

import '../models/apsrtc_station.dart';
import '../theme/app_tokens.dart';

class StationPickerTile extends StatelessWidget {
  final ApsrtcStation station;
  final bool isSelected;
  final VoidCallback onTap;

  const StationPickerTile({
    super.key,
    required this.station,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = station.displaySubtitle;

    return ListTile(
      onTap: onTap,
      minVerticalPadding: AppSpacing.md,
      title: Text(
        station.placeName,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : AppColors.primaryText,
        ),
      ),
      subtitle: subtitle.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
            )
          : null,
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : const Icon(Icons.chevron_right, color: AppColors.secondaryText),
    );
  }
}

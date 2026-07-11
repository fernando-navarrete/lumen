import 'package:flutter/material.dart';
import 'package:lumen/components/brand_lockup.dart';
import 'package:lumen/components/tab_button.dart';
import 'package:lumen/state/home_state.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';

class NavBar extends StatefulWidget {
  const NavBar({super.key, required this.onItemSelected});

  final ValueChanged<NavBarItem> onItemSelected;

  @override
  State<NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<NavBar> {
  NavBarItem _selectedItem = NavBarItem.library;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      height: 74,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(8),
        border: Border(bottom: BorderSide(color: AppColors.border08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: AppSpacing.xs,
        children: [
          const BrandLockup(),
          const SizedBox(width: AppSpacing.md),
          for (final item in NavBarItem.values)
            TabButton(
              label: item.label,
              isSelected: _selectedItem == item,
              onTap: () {
                setState(() {
                  _selectedItem = item;
                });
                widget.onItemSelected(item);
              },
            ),
        ],
      ),
    );
  }
}

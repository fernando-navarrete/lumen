import 'package:flutter/material.dart';
import 'package:gogdl2_flutter/components/brand_lockup.dart';
import 'package:gogdl2_flutter/state/home_state.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';
import 'package:gogdl2_flutter/theme/text_styles.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      height: 74,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(8),
        border: Border(bottom: BorderSide(color: AppColors.border08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 8,
        children: [
          const BrandLockup(),
          const SizedBox(width: 16),
          _NavBarButton(
            label: "Library",
            isSelected: _selectedItem == NavBarItem.library,
            onTap: () {
              setState(() {
                _selectedItem = NavBarItem.library;
              });
              widget.onItemSelected(NavBarItem.library);
            },
          ),
          _NavBarButton(
            label: "Downloads",
            isSelected: _selectedItem == NavBarItem.downloads,
            onTap: () {
              setState(() {
                _selectedItem = NavBarItem.downloads;
              });
              widget.onItemSelected(NavBarItem.downloads);
            },
          ),
          _NavBarButton(
            label: "Settings",
            isSelected: _selectedItem == NavBarItem.settings,
            onTap: () {
              setState(() {
                _selectedItem = NavBarItem.settings;
              });
              widget.onItemSelected(NavBarItem.settings);
            },
          ),
        ],
      ),
    );
  }
}

class _NavBarButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarButton({
    required this.label,
    this.isSelected = false,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: isSelected
            ? BoxDecoration(
                color: AppColors.border12,
                borderRadius: BorderRadius.circular(9),
              )
            : null,
        child: Text(
          label,
          style: AppText.onest(
            size: 13,
            weight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? Colors.white : Colors.white.withAlpha(128),
          ),
        ),
      ),
    );
  }
}

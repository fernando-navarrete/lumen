import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/clickable_container.dart';
import 'package:lumen/components/brand_lockup.dart';
import 'package:lumen/components/search_field.dart';
import 'package:lumen/components/tab_button.dart';
import 'package:lumen/state/downloads_state.dart';
import 'package:lumen/state/home_state.dart';
import 'package:lumen/state/proton_state.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

class NavBar extends ConsumerWidget {
  const NavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NavBarItem selectedItem = ref.watch(navBarItemProvider);
    final int activeDownloads = ref.watch(
      downloadsStateProvider.select(
        (state) => state.tasks.values
            .where((task) => task.status == TaskStatus.running)
            .length,
      ),
    );
    final String? defaultProton = ref.watch(
      protonStateProvider.select((state) => state.defaultVersion),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 13,
      ),
      decoration: const BoxDecoration(
        color: AppColors.navBarFill,
        border: Border(bottom: BorderSide(color: AppColors.border08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const BrandLockup(),
          const SizedBox(width: AppSpacing.sm),
          Row(
            spacing: 4,
            children: [
              for (final item in NavBarItem.values)
                TabButton(
                  label: item.label,
                  isSelected: selectedItem == item,
                  onTap: () =>
                      ref.read(navBarItemProvider.notifier).select(item),
                  badge: item == NavBarItem.downloads && activeDownloads > 0
                      ? _CountBadge(count: activeDownloads)
                      : null,
                ),
            ],
          ),
          const Spacer(),
          SearchField(
            onChanged: (value) =>
                ref.read(librarySearchProvider.notifier).set(value),
          ),
          const SizedBox(width: AppSpacing.xs),
          _ProtonChip(
            label: defaultProton ?? 'No Proton',
            onTap: () => ref
                .read(navBarItemProvider.notifier)
                .select(NavBarItem.settings),
          ),
        ],
      ),
    );
  }
}

/// Teal count pill shown on the Downloads tab while tasks are running.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text('$count', style: AppText.badge()),
    );
  }
}

/// Default-Proton indicator chip; tapping it jumps to Settings.
class _ProtonChip extends StatelessWidget {
  const _ProtonChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClickableContainer(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.fill06,
          border: Border.all(color: AppColors.border10),
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
        child: Row(
          spacing: AppSpacing.xs,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            Text(
              label,
              style: AppText.onest(
                size: 12.5,
                weight: FontWeight.w500,
                color: AppColors.text80,
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

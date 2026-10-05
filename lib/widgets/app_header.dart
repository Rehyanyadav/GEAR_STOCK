import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/sync/data/sync_runner.dart';

class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onSearchTap;
  final VoidCallback? onProfileTap;
  final bool showBack;
  final List<Widget>? actions;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle = 'Workshop OS',
    this.onSearchTap,
    this.onProfileTap,
    this.showBack = false,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    final isCloudUnavailable = syncStatus.isCloudUnavailable;
    return Container(
      color: Theme.of(context).colorScheme.surface.withAlpha(240),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHigh.withAlpha(160),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              if (showBack) ...[
                IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: 'Back',
                  splashRadius: 22,
                ),
                const SizedBox(width: 4),
              ],
              // Logo
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: Image.asset(
                  'assets/images/gearstock_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.settings,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Brand & Subtitle
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: -0.3,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (actions != null) ...actions!,
              if (syncStatus.pendingCount > 0 ||
                  isCloudUnavailable)
                Tooltip(
                  message:
                      syncStatus.message ??
                      '${syncStatus.pendingCount} changes waiting to sync',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      syncStatus.isOffline
                          ? Icons.cloud_off_outlined
                          : syncStatus.kind == SyncStatusKind.failed
                          ? Icons.sync_problem_outlined
                          : Icons.cloud_upload_outlined,
                      color: isCloudUnavailable
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                ),
              if (onSearchTap != null)
                IconButton(
                  icon: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                  onPressed: onSearchTap,
                  splashRadius: 22,
                  tooltip: 'Quick Search',
                ),
              if (onProfileTap != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onProfileTap,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primaryFixed,
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: Image.asset(
                        'assets/images/profile_avatar.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Theme.of(context).colorScheme.primaryFixed,
                          child: Center(
                            child: Text(
                              'R',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

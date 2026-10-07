import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/notifications/domain/notification_model.dart';
import 'package:food_user_application/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:food_user_application/core/widgets/app_refresh_indicator.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    final notificationsAsync = ref.watch(notificationsControllerProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,

        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: colorScheme.onSurface,
          ),
          onPressed: () => context.pop(),
        ),

        title: Text(
          'Notifications',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh_rounded, color: colorScheme.onSurface),
            onPressed: () {
              ref.read(notificationsControllerProvider.notifier).refresh();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),

      body: notificationsAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: AppColors.primary)),

        error: (error, _) => _buildErrorState(context, ref, error),

        data: (state) {
          return AppRefreshIndicator(
            onRefresh: () {
              return ref
                  .read(notificationsControllerProvider.notifier)
                  .refresh();
            },

            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),

              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 32,
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSummaryCard(context, state),

                  if (state.items.isNotEmpty) ...[
                    const SizedBox(height: 14),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          _confirmClearAll(context, ref);
                        },
                        icon: Icon(
                          Icons.delete_sweep_outlined,
                          size: 18,
                          color: colorScheme.error,
                        ),
                        label: Text(
                          'Clear all',
                          style: TextStyle(
                            color: colorScheme.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 2),
                  ],

                  state.items.isEmpty
                      ? _buildEmptyState(context)
                      : _buildNotificationList(context, state.items),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final message = apiErrorMessage(error, 'Failed to load notifications.');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colorScheme.error.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 30,
                color: colorScheme.error,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.70),
                height: 1.4,
              ),
            ),

            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: () {
                ref.read(notificationsControllerProvider.notifier).refresh();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, NotificationsState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.10 : 0.04,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: AppColors.primary,
              size: 25,
            ),
          ),

          const SizedBox(width: 14),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inbox',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '${state.total} Notification${state.total == 1 ? '' : 's'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Unread badge
          Flexible(
            flex: 0,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 105),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.16),
                ),
              ),
              child: Text(
                'Unread: ${state.unreadCount}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 42,
              color: AppColors.primary.withValues(alpha: 0.65),
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'No notifications yet',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            'You’re all caught up. New notifications will appear here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.55),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(
    BuildContext context,
    List<NotificationModel> items,
  ) {
    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _NotificationCard(notification: items[i]),

          if (i < items.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.dialogBackgroundColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          title: Text(
            'Clear all notifications?',
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),

          content: Text(
            'This will remove every notification from your inbox.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.65),
              height: 1.4,
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                'Clear all',
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await ref.read(notificationsControllerProvider.notifier).dismissAll();
    }
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.notification});

  final NotificationModel notification;

  IconData get _icon {
    switch (notification.source) {
      case 'FSSAI_EXPIRY':
        return Icons.warning_amber_rounded;

      case 'SUPPORT_RESPONSE':
        return Icons.support_agent_outlined;

      case 'ADMIN_BROADCAST':
      default:
        return Icons.campaign_outlined;
    }
  }

  Color _iconColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (notification.source) {
      case 'FSSAI_EXPIRY':
        return colorScheme.error;

      case 'SUPPORT_RESPONSE':
        return AppColors.success;

      case 'ADMIN_BROADCAST':
      default:
        // Blue hata diya.
        // Ab app ki primary theme use hogi.
        return AppColors.primary;
    }
  }

  Color _softColor(BuildContext context) {
    final color = _iconColor(context);
    return color.withValues(alpha: 0.10);
  }

  Color _tagTextColor(BuildContext context) {
    return _iconColor(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isRead = notification.isRead;

    final textColor = colorScheme.onSurface;

    final secondaryTextColor = colorScheme.onSurface.withValues(alpha: 0.58);

    final primaryColor = AppColors.primary;

    final cardColor = theme.cardColor;

    final borderColor = isRead
        ? colorScheme.onSurface.withValues(alpha: 0.10)
        : primaryColor.withValues(alpha: 0.35);

    return Dismissible(
      key: ValueKey(notification.id),

      direction: DismissDirection.endToStart,

      confirmDismiss: (_) async {
        return true;
      },

      background: Container(
        width: double.infinity,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),

      onDismissed: (_) {
        ref
            .read(notificationsControllerProvider.notifier)
            .dismiss(notification.id);
      },

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          borderRadius: BorderRadius.circular(18),

          onTap: () {
            ref
                .read(notificationsControllerProvider.notifier)
                .markRead(notification.id);
          },

          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),

            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: isRead ? 1 : 1.2),

              boxShadow: [
                if (!isRead)
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -------------------------------------------------
                // TOP ROW
                // -------------------------------------------------
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _softColor(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_icon, size: 21, color: _iconColor(context)),
                    ),

                    const SizedBox(width: 10),

                    // TAG
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 170),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _softColor(context),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            notification.tag,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _tagTextColor(context),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // CLOSE BUTTON
                    IconButton(
                      tooltip: 'Dismiss',
                      onPressed: () {
                        ref
                            .read(notificationsControllerProvider.notifier)
                            .dismiss(notification.id);
                      },
                      icon: Icon(
                        Icons.close_rounded,
                        size: 19,
                        color: secondaryTextColor,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      splashRadius: 18,
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // -------------------------------------------------
                // TITLE
                // -------------------------------------------------
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isRead) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 8),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],

                    Expanded(
                      child: Text(
                        notification.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 7),

                // -------------------------------------------------
                // MESSAGE
                // -------------------------------------------------
                Text(
                  notification.message,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: secondaryTextColor,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),

                const SizedBox(height: 13),

                // -------------------------------------------------
                // DATE
                // -------------------------------------------------
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: secondaryTextColor,
                    ),

                    const SizedBox(width: 5),

                    Expanded(
                      child: Text(
                        DateFormat(
                          'd MMM, h:mm a',
                        ).format(notification.createdAt.toLocal()),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondaryTextColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    if (!isRead)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Unread',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

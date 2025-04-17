import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/services/notification_service.dart';
import 'package:flutter_application_1/screens/notifications/notification_screen.dart';

class NotificationBadge extends StatelessWidget {
  final Color? badgeColor;
  final Color? iconColor;
  final double iconSize;

  const NotificationBadge({
    Key? key,
    this.badgeColor,
    this.iconColor,
    this.iconSize = 24.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final notificationService = Provider.of<NotificationService>(context);
    final hasUnread = notificationService.unreadCount > 0;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(
            Icons.notifications,
            color: iconColor,
            size: iconSize,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NotificationScreen()),
            );
          },
        ),
        if (hasUnread)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: EdgeInsets.all(notificationService.unreadCount > 9 ? 2 : 4),
              decoration: BoxDecoration(
                color: badgeColor ?? Colors.red,
                shape: notificationService.unreadCount > 9
                    ? BoxShape.rectangle
                    : BoxShape.circle,
                borderRadius: notificationService.unreadCount > 9
                    ? BorderRadius.circular(8)
                    : null,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: notificationService.unreadCount > 99
                  ? const Text(
                      '99+',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    )
                  : notificationService.unreadCount > 9
                      ? Text(
                          '${notificationService.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        )
                      : null,
            ),
          ),
      ],
    );
  }
}
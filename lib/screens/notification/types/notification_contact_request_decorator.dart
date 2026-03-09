import 'package:flutter/material.dart';
import 'package:luia/auth/user_auth.dart';
import 'package:luia/dao/user_dao.dart';
import 'package:luia/models/notification.dart';
import 'package:luia/screens/notification/types/notification_decorator.dart';

class NotificationContactRequestDecorator extends NotificationDecorator {

  @override
  Widget decorate(BuildContext context, AppNotification notification) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.person_add),
            title: Text(notification.title),
            subtitle: Text(notification.message),
            trailing: notification.isRead
                ? null
                : const Icon(Icons.circle, size: 10, color: Colors.blue),
            onTap: () => {},
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _handleReject(context, notification),
                  child: const Text('Rechazar', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _handleAccept(context, notification),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Aceptar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Lógica para aceptar una notificación
  Future<void> _handleAccept(BuildContext context, AppNotification notification) async {
    if (!UserAuth.instance.isUserAuthenticatedAndVerified()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Usuario no autenticado.')),
      );
      return;
    }

    try {
      UserDao().acceptContact(notification: notification);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notificación aceptada.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al procesar la solicitud.')),
      );
    }
  }

  // Lógica para rechazar una notificación
  Future<void> _handleReject(BuildContext context, AppNotification notification) async {
    if (!UserAuth.instance.isUserAuthenticatedAndVerified()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Usuario no autenticado.')),
      );
      return;
    }

    try {
      await UserDao().declineContact(notification: notification);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notificación rechazada.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al procesar la solicitud.')),
      );
    }
  }
}

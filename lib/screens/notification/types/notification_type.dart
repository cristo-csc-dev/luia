import 'package:luia/screens/notification/types/notification_contact_request_decorator.dart';
import 'package:luia/screens/notification/types/notification_decorator.dart';

NotificationDecorator _defaultDecoratorFactory() => NotificationDecorator();
NotificationDecorator _contactRequestDecoratorFactory() => NotificationContactRequestDecorator();

enum NotificationType {
  contactRequest("Tienes una nueva solicitud de contacto", _contactRequestDecoratorFactory),
  eventInvitation("Has sido invitado a un evento", _defaultDecoratorFactory),
  contactAccepted("Tu solicitud de contacto ha sido aceptada", _defaultDecoratorFactory),
  generic("Notificación", _defaultDecoratorFactory);

  final String title;
  final NotificationDecorator Function() notificationDecoratorFactory;

  const NotificationType(this.title, this.notificationDecoratorFactory);

  static NotificationType fromFirestore(String? value) {
    switch (value) {
      case 'contactRequest':
        return NotificationType.contactRequest;
      case 'eventInvitation':
        return NotificationType.eventInvitation;
      case 'contactAccepted':
        return NotificationType.contactAccepted;
      default:
        return generic;
    }
  }

  NotificationDecorator getNotificationDecorator() {
    return Function.apply(notificationDecoratorFactory, []);
  }
}

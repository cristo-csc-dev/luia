import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class ContactAvatar extends StatelessWidget {

  static const double small = 24.0;
  static const double medium = 40.0;
  static const double high = 60.0;

  final String contactId;
  final String displayName;
  final double radius;

  const ContactAvatar({
    super.key, 
    required this.contactId,
    required this.displayName,
    this.radius = small,
  });

  Future<String?> _loadAvatarUrl() async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('user_profiles')
        .child(contactId);

    try {
      return await storageRef.child('profile_$contactId.png').getDownloadURL();
    } catch (_) {
      try {
        return await storageRef.child('profile_$contactId.jpg').getDownloadURL();
      } catch (_) {
        return null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _loadAvatarUrl(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
          return CircleAvatar(
            radius: radius,
            backgroundImage: NetworkImage(snapshot.data!),
          );
        }
        return CircleAvatar(
          radius: radius,
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Text(
            displayName.isNotEmpty
                ? (displayName.length > 1 ? displayName.substring(0, 2) : displayName).toUpperCase()
                : '',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}
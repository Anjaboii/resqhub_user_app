import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static Future<void> addTripNotification({
    required String uid,
    required String status,
    required String providerName,
    required String serviceType,
    String? requestId,
  }) async {
    final Map<String, Map<String, String>> messages = {
      'accepted': {
        'title': 'Provider Assigned',
        'body': '$providerName has accepted your $serviceType request.',
      },
      'en_route': {
        'title': 'Help is on the way!',
        'body': '$providerName is heading to your location.',
      },
      'arrived': {
        'title': 'Provider Arrived',
        'body': '$providerName has arrived at your location.',
      },
      'towing': {
        'title': 'Towing Started',
        'body': 'Your vehicle is being towed by $providerName.',
      },
      'in_progress': {
        'title': 'Service In Progress',
        'body': '$providerName is working on your vehicle.',
      },
      'completed': {
        'title': 'Service Completed ✅',
        'body': 'Your $serviceType service has been completed by $providerName.',
      },
    };

    final msg = messages[status.toLowerCase()];
    if (msg == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .add({
      'title': msg['title'],
      'body': msg['body'],
      'type': 'trip_status',
      'status': status,
      'serviceType': serviceType,
      'providerName': providerName,
      'requestId': requestId,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  static Future<void> markAsRead(String uid, String notificationId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  static Future<void> markAllAsRead(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}

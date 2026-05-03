import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'carrier_tracking_view.dart';
import 'garage_navigation_view.dart';

class TrackingDispatcher extends StatelessWidget {
  final String requestId;

  const TrackingDispatcher({super.key, required this.requestId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('requests').doc(requestId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final reqData = snapshot.data!.data() as Map<String, dynamic>;
        // This is the list logic: it checks if the user chose 'garage' or 'carrier'
        final String role = reqData['providerRole'] ?? 'carrier';

        switch (role) {
          case 'garage':
            return GarageNavigationView(reqData: reqData, requestId: requestId);
          case 'carrier':
          default:
            return CarrierTrackingView(
              requestId: requestId,
              serviceName: reqData['serviceType'] ?? "",
              vehicleName: reqData['vehicle']?['name'] ?? "",
              location: reqData['locationText'] ?? "",
            );
        }
      },
    );
  }
}
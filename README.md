# ResQHub User App

ResQHub User App is the customer-facing mobile application of the ResQHub roadside assistance platform. It empowers vehicle owners to quickly request help, track service providers, and manage their emergency vehicle situations seamlessly.

## 🚀 Features

* **Quick Assistance Requests**: Request immediate help from nearby garages and tow carriers.
* **Real-Time Tracking**: Monitor the live location of the assigned service provider on a map.
* **Detailed Job Context**: Add specific text details, pictures, or notes to provide context to the service provider.
* **In-App Payments & Invoicing**: Generate professional PDF invoices and handle digital payments seamlessly.
* **Service History**: Keep track of past service requests, complete with detailed breakdowns and receipts.
* **User Profiles**: Manage personal vehicle information and profile details.
* **Secure Authentication**: Robust user authentication powered by Firebase.

## 🛠️ Technology Stack

* **Framework**: Flutter (Dart)
* **Backend**: Firebase (Authentication, Cloud Firestore, Cloud Storage, Cloud Functions)
* **Mapping & Location**: `google_maps_flutter`, `geolocator`, `geocoding`
* **State Management**: `provider`
* **Utilities**: `pdf`, `printing`, `webview_flutter`, `shared_preferences`, `image_picker`, `url_launcher`

## 📦 Getting Started

### Prerequisites
* Flutter SDK (v3.8.1 or higher)
* Dart SDK
* Firebase project setup (Ensure `google-services.json` / `GoogleService-Info.plist` are configured)

### Installation
1. Clone the repository.
2. Run `flutter pub get` to fetch all dependencies.
3. Add your Firebase configuration files to the respective Android/iOS directories.
4. Run the app using `flutter run`.

## 📂 Project Architecture Highlights
* Scalable folder structure with separate modules for history tracking, payments, map navigation, and invoice generation.
* Uses the Provider pattern for efficient state management across complex user flows.
* Integrated with Firebase Cloud Functions for secure and centralized backend operations.

---
*This project is part of the final-year academic project of Anjana Herath(10955173) for Plymouth University.*

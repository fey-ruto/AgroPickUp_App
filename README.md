# AgroPickup GH

AgroPickup GH is a Flutter mobile application that connects farmers and aggregators for produce pickup coordination.

Core capabilities include:
- Farmer pickup request submission
- Aggregator request management (accept, schedule, complete, cancel)
- In-app notifications for request lifecycle updates
- Collection point map view with geolocation
- Camera-based produce image capture and upload
- Offline-first behavior with local caching and sync support

## Tech Stack

- Flutter / Dart
- Firebase Auth
- Cloud Firestore
- Cloudinary (image upload)
- sqflite (local database)
- Geolocator + Flutter Map (location and map)

## Project Structure

```text
agro_pickgh/
|-- lib/
|   |-- main.dart
|   |-- models/
|   |-- providers/
|   |-- services/
|   |-- screens/
|   |-- utils/
|   |-- widgets/
|-- assets/
|-- android/
|-- ios/
|-- web/
|-- linux/
|-- macos/
|-- windows/
|-- test/
|-- firestore.rules
|-- pubspec.yaml
```

## Requirements

Before running the project, ensure the following are installed:
- Flutter SDK (compatible with Dart SDK >= 3.0.0 < 4.0.0)
- Android Studio or VS Code with Flutter and Dart extensions
- Firebase project configured for Android
- Android emulator or physical device

## Setup Instructions


1. Firebase setup.
- Place `google-services.json` in `android/app/`.
- Ensure Firestore and Firebase Auth are enabled in your Firebase project.

2. Cloudinary setup (for request image uploads).
- Cloud Name: `dyy3j2gcc`
- Upload Preset: `agropick`
- Upload type: unsigned preset
```

## How To Use The App

### Authentication
- Register as Farmer or Aggregator (Admin role in app logic).
- Login with your account credentials.

### Farmer Flow
1. Open Request Pickup.
2. Select produce type, quantity, pickup date, and collection point.
3. Optionally capture a produce photo with camera.
4. Submit request.
5. Track status and notifications from dashboard and notifications page.

### Aggregator Flow
1. Open Aggregator Dashboard.
2. View incoming pickup requests.
3. Inspect request details, including produce image (if provided).
4. Accept, schedule, complete, or cancel requests.
5. Notifications are sent to both farmer and aggregator on status changes.

### Map and Location
- Farmers can view collection points on map.
- App requests location permission and calculates distance to points.

## Technical Deep Dive: Local Resources

### 1. Image Picker (Camera)

**Location:** `lib/screens/farmer/request_pickup_screen.dart`

**Implementation:**

```dart
import 'package:image_picker/image_picker.dart';
import 'dart:io';

// State variable to hold the captured image
File? _photoFile;

// Method to capture image from device camera
Future<void> _pickImage() async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: ImageSource.camera,  // Opens device camera (not gallery)
    imageQuality: 70             // Compress image to 70% quality for smaller file size
  );
  if (picked != null) {
    setState(() => _photoFile = File(picked.path));  // Store as File object
  }
}
```

**Code Explanation:**

- `ImagePicker()`: Initializes the image picker plugin that wraps platform-specific camera APIs.
- `source: ImageSource.camera`: Opens the native Android camera  instead of photo gallery, giving the farmer direct capture capability.
- `imageQuality: 70`: Reduces image size from full resolution (~3-5MB) to ~500KB, making upload faster without sacrificing visual quality.
- `picked.path`: The temporary file path where Android stores the captured photo.
- `File(picked.path)`: Converts the picked image path into a Dart `File` object that can be read and uploaded.
- `File? _photoFile`: Holds the reference in app state so the image can be previewed and later sent to Cloudinary.

**Usage in Request Submission:**

```dart
// In submitRequest method (lib/providers/request_provider.dart)
if (isOnline && photoFile != null) {
  photoUrl = await _firestoreService.uploadProducePhoto(photoFile, requestId);
}
```

When the farmer submits a request, if the photo exists and network is online, the `File` object is passed to Cloudinary upload service.

**UI Preview:**

```dart
// Show captured image in the form before submission
_photoFile != null
    ? ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(_photoFile!, fit: BoxFit.cover),  // Display local file
      )
    : const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt_outlined, size: 36),
          Text('Take Photo'),
        ],
      )
```

The app uses `Image.file()` to preview the captured photo before upload, giving the farmer confidence that the right image was captured.

---

### 2. Geolocator (GPS Location)

**Location:** `lib/screens/farmer/map_screen.dart`

**Implementation:**

```dart
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

// State variables
LatLng? _userLocation;

// Step 1: Request location permission from user
Future<void> _getUserLocation() async {
  try {
    // Request permission (iOS/Android asks user "Allow location?")
    final permission = await Geolocator.requestPermission();
    
    // If user denies, exit early
    if (permission == LocationPermission.denied || 
        permission == LocationPermission.deniedForever) {
      return;
    }
    
    // Step 2: Get device's current GPS position
    final position = await Geolocator.getCurrentPosition();
    
    // Step 3: Store location and center map
    setState(() => _userLocation = LatLng(
      position.latitude,
      position.longitude
    ));
    
    // Move map view to user's location with zoom level 13
    _mapController.move(_userLocation!, 13);
  } catch (_) {}
}
```

**Code Explanation:**

- `Geolocator.requestPermission()`: Triggers native Android permission dialog (user sees "Allow AgroPickup to access your location?").
- `LocationPermission.denied`: User tapped "Don't Allow"; app cannot proceed.
- `LocationPermission.deniedForever`: User denied and checked "Don't ask again"; app is blocked from future location requests.
- `Geolocator.getCurrentPosition()`: Queries device GPS and returns lat/long coordinates. Takes 2-5 seconds on first call.
- `LatLng(latitude, longitude)`: Converts raw GPS coordinates into a map format that `FlutterMap` understands.
- `_mapController.move(_userLocation!, 13)`: Centers the map on the farmer's current location with zoom level 13 (street level).

**Step 4: Calculate Distance to Collection Points**

```dart
double _distanceTo(CollectionPoint point) {
  if (_userLocation == null) return 0;
  
  // Haversine formula: calculates straight-line distance between two GPS coordinates
  return Geolocator.distanceBetween(
    _userLocation!.latitude,
    _userLocation!.longitude,
    point.latitude,
    point.longitude,
  ) / 1000;  // Convert meters to kilometers
}
```

**Example Output:**
- User location: `7.1234, -1.5678` (Accra, Ghana)
- Collection point: `7.1250, -1.5690`
- Distance: ~200 meters or `0.2 km`

**Step 5: Handle Map Tap to Select Nearest Point**

```dart
void _handleMapTap(LatLng tappedLocation, List<CollectionPoint> points) {
  CollectionPoint? nearestPoint;
  double nearestDistanceMeters = double.infinity;

  // Loop through all collection points
  for (final point in points) {
    final distanceMeters = Geolocator.distanceBetween(
      tappedLocation.latitude,
      tappedLocation.longitude,
      point.latitude,
      point.longitude,
    );
    
    // Keep track of the closest point
    if (distanceMeters < nearestDistanceMeters) {
      nearestDistanceMeters = distanceMeters;
      nearestPoint = point;
    }
  }

  // Only select if tap was within 800 meters of a marker (avoid accidental taps)
  if (nearestPoint != null && nearestDistanceMeters <= 800) {
    setState(() => _selectedPoint = nearestPoint);
  }
}
```

**Logic Breakdown:**
- When farmer taps the map, the app calculates distance from tap location to every collection point.
- If the closest point is ≤ 800m away, it's selected automatically (prevents mis-taps far from markers).
- If no point is within range, nothing is selected.

**Example Workflow on Map Screen:**
1. App starts → requests location permission.
2. User allows → GPS position is retrieved and map centers on user.
3. Farmer sees 5 collection points marked on map.
4. App displays distance to each point: "2.3 km away", "5.1 km away", etc.
5. Farmer taps on the closest point → `_handleMapTap` triggered → distance calculated → if ≤ 800m, point is selected.
6. Bottom card shows selected point details.
7. Farmer confirms selection and returns to request form.

**Permissions Required (AndroidManifest.xml):**
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

These permissions are automatically declared when `geolocator` is added to `pubspec.yaml`.

---

### Offline Behavior
- If network is unavailable during request submission:
	- Request is stored locally (SQLite).
	- Sync occurs when connectivity is restored.

## Important Notes

- Firestore security rules are in `firestore.rules`.
- Local cache/database uses `sqflite`.
- Request images are uploaded to Cloudinary and URL is saved in Firestore.


## AI Declaration and Contribution Report

This project was developed with a combination of human development and AI assistance.

Contribution labels:
- `ME ONLY`: Designed and implemented directly by the student.
- `AI + ME`: Implemented through AI-assisted coding, then reviewed, integrated, and validated by the student.

### File-Level Contribution Summary

`ME ONLY` (core logic ownership):
- `lib/screens/farmer/map_screen.dart`
- `lib/screens/farmer/request_pickup_screen.dart`
- `lib/screens/admin/admin_dashboard.dart`
- `lib/screens/admin/admin_request_detail.dart`
- `lib/providers/request_provider.dart`
- `lib/providers/collection_point_provider.dart`
- `lib/models/models.dart`
- `firestore.rules`

`AI + ME` (complex integrations and optimization support):
- `lib/services/firestore_service.dart` (Cloudinary upload integration, notification query hardening)
- `lib/providers/notification_provider.dart` (notification loading/refinement)
- `lib/services/local_database_service.dart` (offline persistence enhancements)
- `lib/widgets/common_widgets.dart` (shared UI component refinements)
- `README.md` (documentation/report formatting)

### AI Use Scope

AI assistance was used for:
- Refactoring and improving service-layer integrations
- Debugging and hardening notification/image upload flows
- Improving UI presentation of request images
- Documentation structure and reporting support

Final design decisions, testing, and validation were done by the team members.


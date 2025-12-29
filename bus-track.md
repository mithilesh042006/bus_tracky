# Bus Track 🚍  
### Real-Time College Bus Tracking App

## Overview
**Bus Track** is a mobile application designed for day-scholar college students to track college buses in real time. The app enables students to view live bus locations, routes, and estimated arrival times, while administrators manage buses and drivers efficiently.

The system uses **Flutter** for frontend development and **Firebase** for backend services, ensuring scalability, real-time updates, and ease of maintenance.

---

## Objectives
- Reduce student waiting time at bus stops
- Provide real-time bus visibility
- Improve transport management efficiency
- Ensure secure and role-based access
- Optimize battery and data usage

---

## User Roles

### 1. Administrator
**Responsibilities**
- Create and manage buses
- Create and manage routes
- Assign drivers to buses
- Enable or disable live tracking
- View bus activity (optional dashboard)

---

### 2. Driver
**Responsibilities**
- Login and access assigned bus
- Start and end bus trips
- Share live GPS location during trips
- View assigned route and stops

**Note:**  
Location sharing is active **only when a trip is started**.

---

### 3. Student (Day Scholar)
**Responsibilities**
- View available buses and routes
- Track buses live on the map
- View ETA to bus stops
- Enable GPS for accurate ETA calculation

---

## Core Features
- Live bus tracking on Google Maps
- Route visualization with stops
- Role-based authentication
- Real-time updates using Firebase
- Battery-efficient location updates

---

## Optional Enhancements
- Push notifications (bus arriving soon)
- Favorite routes
- Bus crowd status
- Trip history and analytics
- Offline route caching

---

## Tech Stack

### Frontend
- Flutter
- Google Maps Flutter Plugin
- State Management (Provider / Riverpod / Bloc)
- Geolocator (GPS)
- Permission Handler

### Backend (Firebase)
- Firebase Authentication
- Cloud Firestore
- Firebase Realtime Database (optional for high frequency updates)
- Firebase Cloud Messaging
- Cloud Functions
- Firebase Analytics

---

## Database Structure

### Firestore Collections

```plaintext
users/
  userId:
    name
    role (admin / driver / student)
    assignedBusId

buses/
  busId:
    busNumber
    driverId
    routeId
    isActive

routes/
  routeId:
    routeName
    stops: [
      { name, lat, lng }
    ]
    polyline

live_tracking/
  busId:
    lat
    lng
    speed
    updatedAt
```

---

## Live Tracking Implementation

### Driver Side (Location Upload)

#### Step 1: Request GPS Permission
```dart
await Geolocator.requestPermission();
```

#### Step 2: Stream Location Updates
```dart
Geolocator.getPositionStream(
  locationSettings: LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  ),
).listen((position) {
  FirebaseFirestore.instance
    .collection('live_tracking')
    .doc(busId)
    .set({
      'lat': position.latitude,
      'lng': position.longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    });
});
```

- Updates every 10 meters
- Runs only during active trips
- Optimized for battery usage

---

### Student Side (Location Read)

```dart
FirebaseFirestore.instance
  .collection('live_tracking')
  .doc(busId)
  .snapshots()
  .listen((snapshot) {
    final data = snapshot.data();
    final busLatLng = LatLng(data!['lat'], data['lng']);
});
```

---

## ETA Calculation

```dart
distance = Geolocator.distanceBetween(
  busLat, busLng,
  stopLat, stopLng
);

ETA = distance / averageSpeed;
```

---

## Security Rules

```js
match /live_tracking/{busId} {
  allow read: if request.auth != null;
  allow write: if request.auth.token.role == 'driver';
}
```

---

## Application Flow

```plaintext
Admin → Create Bus & Route → Assign Driver
Driver → Start Trip → Send GPS Location
Firebase → Sync Real-Time Updates
Student → Track Bus Live on Map
```

---

## Conclusion
Campus Track is a practical, scalable, and real-world problem-solving application suitable for final-year projects and real deployments.

---

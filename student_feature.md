# Campus Track – Student Feature Enhancements 🚍🎓

This document outlines the refined **student-focused features** planned for the Campus Track application.
These features aim to improve **usability, safety, transparency, and real-world convenience** for day-scholar students.

---

## 1. Driver Information Display

### Objective
To build trust and transparency by allowing students to view basic driver details while tracking a bus.

### Feature Description
When a bus trip is active, students can see limited driver information associated with that bus.

### Information Displayed
- Driver Name
- Driver Photo (optional)
- Bus Number
- Trip Status (Active / Inactive)

### Privacy & Rules
- Driver information is visible **only during an active trip**
- Personal contact details are hidden by default
- Admin controls visibility of driver data

### Suggested Data Model
```plaintext
drivers/
  driverId:
    name
    photoUrl
    assignedBusId
```

---

## 2. Issue Reporting System (Student → Admin)

### Objective
To allow students to report transport-related issues directly to administrators in a structured and trackable way.

### Issue Categories
- Bus delay
- Driver behavior
- Overcrowding
- Route deviation
- Safety concern
- Other

### Student Flow
1. Open "Report Issue"
2. Select issue category
3. Add optional description
4. (Optional) Upload image
5. Submit report

### Admin Capabilities
- View all reported issues
- Filter by bus, date, or issue type
- Update issue status
- Track recurring problems

### Issue Status Lifecycle
- Open
- In Progress
- Resolved

### Firestore Structure
```plaintext
issues/
  issueId:
    studentId
    busId
    issueType
    description
    imageUrl
    status
    createdAt
```

### Access Rules
- Students: create issues and view their own
- Admins: view and update all issues

---

## 3. Smart Alarm System (Core Student Feature)

### Objective
To notify students automatically when the bus is approaching their selected stop, removing the need to continuously monitor the app.

---

### 3.1 Stop-Based Alarm

#### Description
Students select a stop from the route and set an alarm.
The alarm triggers when the bus is within a predefined distance from that stop.

#### Example
- Selected stop: Main Gate
- Alarm triggers at: 300 meters

---

### 3.2 Distance-Based Alarm

#### Description
Students define a custom distance between the bus and their stop.

#### Example
- Notify when bus is 1 km away
- Notify when bus is 500 meters away

---

### Alarm Behavior Rules
- Alarm triggers only once per trip
- Automatically disables after triggering
- Resets when a new trip starts

---

### Technical Logic (Simplified)
```dart
distance = Geolocator.distanceBetween(
  busLat, busLng,
  stopLat, stopLng
);

if (distance <= alarmDistance && !alarmTriggered) {
  triggerAlarm();
}
```

---

### Background & Notification Support
- Works when the app is in background
- Uses local notifications
- Supports sound and vibration modes

---

### Firestore Structure
```plaintext
alarms/
  alarmId:
    studentId
    busId
    stopId
    alarmDistance
    isActive
```

---

## Feature Impact Summary

| Feature | Benefit |
|------|------|
| Driver Information | Transparency & trust |
| Issue Reporting | Safety & accountability |
| Smart Alarm | Convenience & time-saving |

---

## Future Enhancements
- ETA-based alarm
- Voice notifications
- Admin analytics on issue trends
- Emergency alert integration

---

## Conclusion
These features transform Campus Track from a basic tracking app into a **student-centric transport solution**.
They significantly improve usability, safety, and day-to-day convenience for college commuters.

---

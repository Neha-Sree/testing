# Contraction Timer Feature - Documentation

## Overview
A comprehensive contraction timer system for pregnant mothers to track labor contractions with real-time visualization and backend storage for doctor reference.

## Features Implemented

### 1. **Contraction Timer Screen** (`contraction_timer_screen.dart`)
The main timer interface with the following features:

#### UI Components:
- **Baby Feet Graphics**: Two baby feet icons that change color based on phase:
  - Gray: Ready state
  - Red: Contraction phase
  - Blue: Relaxation phase

- **Phase Status**: Clear indicator showing current phase (CONTRACTION, RELAXATION, or Ready to Start)

- **Large Timer Display**: MM:SS format showing elapsed time in current phase

#### Control Buttons:
- **START/PAUSE Button**: Toggle timer on/off
- **LAP Button**: Mark the end of current phase and transition to next phase
  - Contraction → Relaxation → Contraction cycle
- **RESET Button**: Clear all data and start over

#### Statistics Panel:
Shows real-time statistics:
- Total contraction time
- Total relaxation time
- Number of cycles completed

#### Live Timeline Graph:
- Bar chart visualization showing all recorded contractions and relaxations
- Red bars = Contraction time
- Blue bars = Relaxation time
- Helps visualize patterns in labor contractions

#### Save Functionality:
- **SAVE TO HISTORY** button (appears after recording at least 1 cycle)
- Saves session data to backend with timestamp
- Session cleared after successful save

### 2. **Contraction History Screen** (`contraction_history_screen.dart`)
Displays all past contraction sessions for tracking and doctor reference:

#### Features:
- **Chronological List**: Shows all sessions sorted by most recent first
- **Session Cards**: Each card displays:
  - Date and time of session
  - Number of cycles
  - Total contraction time (red indicator)
  - Total relaxation time (blue indicator)
  - Contraction ratio as a progress bar
  - Percentage of time spent contracting

#### Smart UI:
- Empty state message when no sessions exist
- Error handling with user-friendly messages
- Loading state with spinner

### 3. **Backend Integration**

#### Existing Endpoints Used:
- **POST** `/mothers/{patient_id}/contractions` - Save new session
- **GET** `/mothers/{patient_id}/contractions` - Fetch history

#### Database Model:
```python
class ContractionSession(Base):
    __tablename__ = "contraction_sessions"
    
    id: Integer (Primary Key)
    patient_id: String (Foreign Key)
    session_date: DateTime
    contraction_seconds: Integer
    relaxation_seconds: Integer
    lap_count: Integer
    created_at: DateTime (Auto-timestamp)
```

#### API Service Methods:
```dart
// Save a completed session
Future<void> saveContractionSession({
  required String patientId,
  required DateTime sessionDate,
  required int contractionSeconds,
  required int relaxationSeconds,
  required int lapCount,
})

// Fetch all sessions for a patient
Future<List<Map<String, dynamic>>> fetchContractionHistory(String patientId)
```

### 4. **Dashboard Integration**

#### Updated Features:
- **Contraction Timer Tile**: Now fully functional and clickable
- Navigates to `ContractionTimerScreen` passing patient ID
- Added import for `contraction_timer_screen.dart`
- Dynamic tile configuration with route handling

### 5. **Dependencies Added**

New packages in `pubspec.yaml`:
- `fl_chart: ^0.68.0` - For bar chart visualization
- `intl: ^0.19.0` - For date formatting

## How to Use

### For Mothers:
1. Tap "Contraction Timer" on the dashboard
2. Press START to begin timing a contraction
3. Press LAP when contraction ends (relaxation begins)
4. Press LAP again when relaxation ends (next contraction begins)
5. Continue for desired number of cycles
6. View live graph showing your pattern
7. Press SAVE TO HISTORY to store session
8. Access View History icon (top-right) to see past sessions

### For Doctors:
1. Access patient's contraction history through the history screen
2. Analyze patterns:
   - Contraction duration trends
   - Relaxation period consistency
   - Overall cycle frequency
3. Download/export data as needed for medical records

## Technical Implementation Details

### Timer Logic:
- Uses Dart's `Stopwatch` class for precise timing
- Automatic UI updates every 100ms when running
- Maintains state of contractions and relaxations

### Data Structure:
```dart
class ContractionData {
  DateTime startTime;
  DateTime endTime;
  String type; // 'contraction' or 'relaxation'
  int durationSeconds;
}
```

### Graph Rendering:
- Uses `fl_chart`'s `BarChart` widget
- Dynamic Y-axis scaling based on data
- Color-coded bars for easy interpretation

### State Management:
- `StatefulWidget` pattern for timer
- `FutureBuilder` for async data loading
- Error handling with user feedback

## File Structure

```
lib/
├── contraction_timer_screen.dart       # Main timer UI
├── contraction_history_screen.dart     # History view
├── mom_dashboard_screen.dart           # Updated dashboard
└── services/
    └── mom_api_service.dart            # API integration
```

## Backend Endpoints (Already Implemented)

### Save Contraction Session
```
POST /mothers/{patient_id}/contractions
Form Parameters:
  - session_date: ISO8601 datetime
  - contraction_seconds: integer
  - relaxation_seconds: integer
  - lap_count: integer
```

### Get Contraction History
```
GET /mothers/{patient_id}/contractions
Returns: Array of contraction sessions ordered by date (DESC)
```

## Future Enhancement Suggestions

1. **Export to PDF**: Generate shareable reports for doctor appointments
2. **Contraction Alerts**: Notify user if intervals become concerning
3. **Pattern Analysis**: AI-based insights on contraction patterns
4. **Offline Support**: Store sessions locally while offline, sync when online
5. **Video Recording**: Optional video overlay for additional context
6. **Family Notifications**: Alert birth partner or family members
7. **Medication Logging**: Track medication taken during labor
8. **Multi-Session Analysis**: Compare contractions across multiple sessions
9. **Heat Map Visualization**: Show contraction intensity over time
10. **Push Notifications**: Alert when to go to hospital based on contraction patterns

## Testing Notes

To test the feature:
1. Ensure backend is running (`python -m uvicorn app.main:app`)
2. Update `MOM_API_BASE_URL` in environment if needed
3. Create a mother profile first
4. Navigate to her dashboard
5. Tap Contraction Timer
6. Record test contractions
7. Save and verify in history

## Troubleshooting

**Issue**: Timer not starting
- Ensure START button is pressed
- Check if stopwatch state is correct

**Issue**: Data not saving
- Verify backend is running
- Check patient ID format (should be uppercase)
- Ensure network connectivity

**Issue**: History not loading
- Backend may be down
- Patient may have no sessions
- Check network connectivity

## Architecture Notes

The feature follows Flutter best practices:
- Separation of concerns (UI, logic, API)
- Proper error handling
- User feedback via SnackBars and dialogs
- Async operations with FutureBuilder
- Stateful widgets for dynamic content
- Type-safe API communication

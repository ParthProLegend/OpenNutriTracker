// import 'package:flutter_health_connect/flutter_health_connect.dart';

/// Model class for strongly typed activities
class Activity {
  final String name;
  final int duration; // in minutes
  final int calories; // rounded kcal

  Activity({
    required this.name,
    required this.duration,
    required this.calories,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'duration': duration,
        'calories': calories,
      };
}

class HealthConnectService {
  /// Request authorization to access Health Connect
  static Future<bool> authorize() async {
    final isSupported = await HealthConnectFactory.isApiSupported();
    if (!isSupported) {
      print("❌ Health Connect is not supported on this device.");
      return false;
    }

    var types = [
      HealthConnectDataType.Exercise,
      HealthConnectDataType.TotalCaloriesBurned,
    ];

    // Check if already granted
    var hasPermissions = await HealthConnectFactory.hasPermissions(types);
    if (hasPermissions) return true;

    // Request permissions
    try {
      await HealthConnectFactory.requestPermissions(types);
      // Re-check after request
      return await HealthConnectFactory.hasPermissions(types);
    } catch (e) {
      print("❌ Permission request failed: $e");
      return false;
    }
  }

  /// Fetch exercise sessions with calories burned in the last 24h
  static Future<List<Activity>> fetchActivities() async {
    final now = DateTime.now();
    final startTime = now.subtract(const Duration(days: 1));

    List<Activity> activities = [];

    try {
      // Fetch all exercises once
      final exercises = await HealthConnectFactory.getRecord(
        type: HealthConnectDataType.Exercise,
        startTime: startTime,
        endTime: now,
      );

      // Fetch all calories once (optimize instead of per-exercise call)
      final allCalories = await HealthConnectFactory.getRecord(
        type: HealthConnectDataType.TotalCaloriesBurned,
        startTime: startTime,
        endTime: now,
      );

      for (var exercise in exercises) {
        try {
          final start = DateTime.parse(exercise['startTime']);
          final end = DateTime.parse(exercise['endTime']);
          final duration = end.difference(start).inMinutes;

          // Filter calories that fall into this exercise window
          final matchingCalories = allCalories.where((cal) {
            final calTime = DateTime.parse(cal['endTime']);
            return calTime.isAfter(start) && calTime.isBefore(end);
          });

          double caloriesBurned = 0;
          for (var calorieRecord in matchingCalories) {
            caloriesBurned +=
                calorieRecord['energy']?['inKilocalories']?.toDouble() ?? 0.0;
          }

          activities.add(Activity(
            name: exercise['title']?.toString() ?? 'Workout',
            duration: duration,
            calories: caloriesBurned.round(),
          ));
        } catch (innerErr) {
          print("⚠️ Error processing exercise: $innerErr");
        }
      }
    } catch (outerErr) {
      print("❌ Error fetching activities: $outerErr");
    }

    return activities;
  }
}

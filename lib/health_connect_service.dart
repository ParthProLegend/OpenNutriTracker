import 'package:flutter_health_connect/flutter_health_connect.dart';

class HealthConnectService {

  // This function checks for permission and asks the user if we don't have it yet.
  static Future<bool> authorize() async {
    // First, we check if the Health Connect API is even available on the device.
    final isSupported = await HealthConnectFactory.isApiSupported();
    if (!isSupported) {
      print("Health Connect is not supported on this device.");
      return false;
    }

    // These are the specific data types we want to read.
    var types = [
      HealthConnectDataType.Exercise,
      HealthConnectDataType.TotalCaloriesBurned,
    ];

    // Now, we check if we already have permission from the user.
    var hasPermissions = await HealthConnectFactory.hasPermissions(types);
    if (hasPermissions) {
      return true;
    }

    // If we don't have permission, this will show the official pop-up to the user.
    try {
      await HealthConnectFactory.requestPermissions(types);
      return true;
    } catch (e) {
      print("Permission request failed: $e");
      return false;
    }
  }

  // This function fetches the activity data.
  static Future<List<Map<String, dynamic>>> fetchActivities() async {
    final now = DateTime.now();
    // We'll look for activities from the last 24 hours.
    final startTime = now.subtract(const Duration(days: 1));

    // Ask Health Connect for all "Exercise" records in our time window.
    final exercises = await HealthConnectFactory.getRecord(
      type: HealthConnectDataType.Exercise,
      startTime: startTime,
      endTime: now,
    );

    List<Map<String, dynamic>> activityList = [];

    // Loop through each exercise session found.
    for (var exercise in exercises) {
      // Calculate duration in minutes.
      final duration = DateTime.parse(exercise['endTime'])
          .difference(DateTime.parse(exercise['startTime']))
          .inMinutes;

      // Now, for each exercise, let's find the calories burned during that specific time.
      final caloriesData = await HealthConnectFactory.getRecord(
        type: HealthConnectDataType.TotalCaloriesBurned,
        startTime: DateTime.parse(exercise['startTime']),
        endTime: DateTime.parse(exercise['endTime']),
      );

      double caloriesBurned = 0;
      // Add up all calorie entries found during the exercise period.
      for (var calorieRecord in caloriesData) {
        caloriesBurned += calorieRecord['energy']['inKilocalories'];
      }

      activityList.add({
        'name': exercise['title'] ?? 'Workout', // The name of the activity.
        'duration': duration, // The duration in minutes.
        'calories': caloriesBurned.round(), // The calories burned, rounded.
      });
    }

    return activityList;
  }
}

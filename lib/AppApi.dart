import 'dart:convert';
import 'dart:io';
import 'package:http/io_client.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:burtonaletrail_app/Notifications.dart'; // Assumes apiServerCreateTeam is defined here.

String apiServer = 'https://burtonaletrail.pawtul.com'; //Server
// String apiServer = 'http://192.168.1.11:5000';

// final String apiServer = Platform.isAndroid
//     ? 'http://10.0.2.2:5000' // Android device or emulator
//     : 'http://127.0.0.1:5000'; // iOS simulator

// AUTHENTICATION
String apiServerOTP = '$apiServer/api/auth/otp';
String apiServerOTPValidate = '$apiServer/api/auth/otp/validate';
String apiServerAuth = '$apiServer/api/auth/login';
String apiServerSponsers = '$apiServer/api/offers/all';

//PROFILE
String apiServerProfile = '$apiServer/api/profile';
String apiServerEditProfile = '$apiServer/api/profile/edit';
String apiServerGetUserRank = '$apiServer/api/rank/user';
String apiServerGetTeamRank = '$apiServer/api/rank/team';

String apiServerNotification = '$apiServer/api/notification/test';

String apiServerJWTValidate = '$apiServer/api/validate-token';

// BEERS
String apiServerBeerList = '$apiServer/api/beers/all';
String apiServerToggleFavourite = '$apiServer/api/beers/favourite';
String apiServerBeerRate = '$apiServer/api/beers/rate';

//PUBS
String apiServerPubList = '$apiServer/api/pubs/all';
String apiServerPubBeerList = '$apiServer/api/pubs/beers';

//LEADERBOARD

String apiServerLeaderboards = '$apiServer/api/leaderboards/all';
String apiServerLeaderboardsTeamQuery =
    '$apiServer/api/leaderboards/team/query';

//TEAMS
String apiServerLeaveTeam = '$apiServer/api/team/leave';
String apiServerRemoveTeamMember = '$apiServer/api/team/remove';
String apiServerAddTeamMember = '$apiServer/api/team/add';
String apiServerDeleteTeam = '$apiServer/api/team/delete';

String apiServerCreateTeam = '$apiServer/api/team/create';
String apiServerEditTeam = '$apiServer/api/team/edit';
String apiServerGetTeamMembers = '$apiServer/api/team/members';

//TROPHIES
String apiServerTrophys = '$apiServer/api/trophycabinet/all';
String apiServerUnlockStreak = '$apiServer/api/badges/streak';

String apiServerMapInformation = '$apiServer/api/map/all';

String apiServerCheckIn = '$apiServer/checkin/qr/scan/';

void NotificationSetup() async {
  await NotificationService().initialize();
}

class Token {
  Future<bool> refresh() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    final refreshToken = prefs.getString('refresh_token');

    if (accessToken == null) {
      // No token found
      return false;
    }
    bool trustSelfSigned = true;

    HttpClient httpClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => trustSelfSigned;

    IOClient ioClient = IOClient(httpClient);

    try {
      final response = await ioClient.post(
        Uri.parse(apiServerJWTValidate), // Correctly parsing the URI
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'access_token': accessToken,
          'refresh_token': refreshToken,
          'push_token': OneSignal.User.pushSubscription.id?.toString() ?? '',
        }),
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['access_token'] != null) {
          final accessToken = jsonResponse['access_token'];
          final refreshToken = jsonResponse['refresh_token'];
          // Store the access token in shared preferences
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', accessToken);
          await prefs.setString('refresh_token', refreshToken);
        }
        return true;
      } else {
        // Token is invalid or other error
        print('Token validation failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      // Handle any errors during the HTTP request
      print('Error validating token: $e');
      return false;
    }
  }

  Future<int> streak() async {
    // For testing purposes: override the initial streak count.
    // Set this to a non-null integer value to simulate a starting streak count.
    // Set to null to use the value stored in SharedPreferences.
    final int? testingStreakOverride = 1; // <-- Change this value for testing

    final prefs = await SharedPreferences.getInstance();

    // Get today's date without the time portion.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Retrieve the last login date.
    final lastLoginStr = prefs.getString('last_login_date');

    // Use the testing override if available; otherwise, use the stored streak or default to 0.
    int streakCount =
        testingStreakOverride ?? prefs.getInt('login_streak') ?? 0;

    if (lastLoginStr != null) {
      // Parse the last login date.
      final lastLoginDate = DateTime.parse(lastLoginStr);
      final lastLoginDay =
          DateTime(lastLoginDate.year, lastLoginDate.month, lastLoginDate.day);

      // Calculate the difference in days.
      final difference = today.difference(lastLoginDay).inDays;

      if (difference == 1) {
        // Last login was yesterday; increment the streak.
        streakCount += 1;
      } else if (difference == 0) {
        // Already logged in today; do nothing.
        return streakCount;
      } else {
        // More than one day has passed, so reset the streak.
        streakCount = 1;
      }
    } else {
      // No previous login record exists; start streak at 1.
      streakCount = 1;
    }

    // Update SharedPreferences with the new streak count and today's date.
    await prefs.setInt('login_streak', streakCount);
    await prefs.setString('last_login_date', today.toIso8601String());
    return streakCount;
  }
}

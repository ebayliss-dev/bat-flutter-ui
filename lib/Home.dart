import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:burtonaletrail_app/AppApi.dart';
import 'package:burtonaletrail_app/AppDrawer.dart';
import 'package:burtonaletrail_app/AppMenuButton.dart';
import 'package:burtonaletrail_app/Beers.dart';
import 'package:burtonaletrail_app/Leaderboard.dart';
import 'package:burtonaletrail_app/LeaderboardWidget.dart';
import 'package:burtonaletrail_app/LoadingScreen.dart';
import 'package:burtonaletrail_app/Map.dart';
import 'package:burtonaletrail_app/NavBar.dart';
import 'package:burtonaletrail_app/Notifications.dart';
import 'package:burtonaletrail_app/ProfilePage.dart';
import 'package:burtonaletrail_app/Sponsers.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/io_client.dart';
import 'package:rive/rive.dart' as rive;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userId = '';
  String userFirstname = '';
  String userSurname = '';
  String userMobile = '';
  String userEmail = '';
  String userName = '';
  String userPoints = '0';
  String userPosition = '0';
  String userSupport = 'off';
  String userImage = '';
  String userTeam = '';
  String userTeamImage = '';
  String userTeamMembers = '';
  String userTeamPoints = '';
  String userTeamAdmin = '';

  late PageController _pageController;
  late Timer _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _initializeState();

    // Initialize PageController
    _pageController = PageController();

    // Start automatic sliding
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        final nextPage = (_pageController.page?.toInt() ?? 0) + 1;
        _pageController.animateToPage(
          nextPage % 2, // Cycle between 0 and 1 for the two leaderboards
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  _handleStreak(loginSteak) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String awarded = prefs.getString('streakAward') ?? 'false';
    if (awarded == 'false') {
      if (loginSteak >= 3) {
        prefs.setString('streakAward', 'true');

        NotificationSetup();

        // Setup HTTP client with a self-signed certificate callback.
        bool trustSelfSigned = true;
        HttpClient httpClient = HttpClient()
          ..badCertificateCallback =
              (X509Certificate cert, String host, int port) => trustSelfSigned;
        IOClient ioClient = IOClient(httpClient);

        try {
          String? accessToken = prefs.getString('access_token');
          final response = await ioClient.post(
            Uri.parse(apiServerUnlockStreak),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'access_token': accessToken,
            }),
          );

          if (response.statusCode == 200) {
            await NotificationService().showNotification(
              title: "BADGE AWARDED",
              body: "You have unlocked the STEAKER badge",
            );
          }
        } catch (e) {
          // In case of error, you might want to log the error.
          // Here, we return 1 as a fallback, but you can adjust this behavior.
          return 1;
        }
      }
    }
  }

  Future<void> _initializeState() async {
    // Create an instance of the Token class
    final token = Token();

    // Call the refresh method
    bool tokenRefreshed = await token.refresh();
    int loginStreak = await token.streak();

    if (tokenRefreshed) {
      print('JWT token refreshed successfully');
      _handleStreak(loginStreak);
      // Continue with additional initialization logic if necessary
    } else {
      print('Failed to refresh JWT token');
      // Handle the failure case, e.g., navigate to login or show an alert
    }

    // Fetch other user data or perform additional initialization here
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Load locally saved user data
    setState(() {
      userId = prefs.getString('userId') ?? '';
      userName = prefs.getString('userName') ?? '';
      userPoints = prefs.getString('userPoints') ?? '0';
      userPosition = prefs.getString('userPosition') ?? '0';
      userSupport = prefs.getString('userSupport') ?? 'off';
      userImage = prefs.getString('userImage') ?? '';
      userTeam = prefs.getString('userTeam') ?? '';
      userTeamImage = prefs.getString('userTeamImage') ?? '';
      userTeamMembers = prefs.getString('userTeamMembers') ?? '';
      userTeamPoints = prefs.getString('userTeamPoints') ?? '';
      userTeamAdmin = prefs.getString('userTeamAdmin') ?? '';
    });

    // Attempt to fetch updated data from the server
    String? accessToken = prefs.getString('access_token');

    if (accessToken != null) {
      bool trustSelfSigned = true;
      HttpClient httpClient = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => trustSelfSigned;
      IOClient ioClient = IOClient(httpClient);

      try {
        final response = await ioClient.post(
          Uri.parse(apiServerProfile),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'access_token': accessToken,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          // Safely retrieve user and leaderboard data
          setState(() {
            userId = data['userId']?.toString() ?? userId;
            userFirstname = data['userFirstname']?.toString() ?? userFirstname;
            userSurname = data['userSurname']?.toString() ?? userSurname;
            userMobile = data['userMobile']?.toString() ?? userMobile;
            userEmail = data['userEmail']?.toString() ?? userEmail;
            userName = data['userName']?.toString() ?? userName;
            userPoints = data['userPoints']?.toString() ?? userPoints;
            userPosition = data['userPosition']?.toString() ?? userPosition;
            userSupport = data['userSupport']?.toString() ?? userSupport;
            userImage = data['userImage']?.toString() ?? userImage;
            userTeam = data['userTeam']?.toString() ?? userTeam;
            userTeamImage = data['userTeamImage']?.toString() ?? userTeamImage;
            userTeamMembers =
                data['userTeamMembers']?.toString() ?? userTeamMembers;
            userTeamPoints =
                data['userTeamPoints']?.toString() ?? userTeamPoints;
            userTeamAdmin = data['userTeamAdmin']?.toString() ?? userTeamAdmin;

            // Save user data locally
            prefs.setString('userId', userId);
            prefs.setString('userName', userName);
            prefs.setString('userFirstname', userFirstname);
            prefs.setString('userSurname', userSurname);
            prefs.setString('userMobile', userMobile);
            prefs.setString('userEmail', userEmail);
            prefs.setString('userPoints', userPoints);
            prefs.setString('userPosition', userPosition);
            prefs.setString('userSupport', userSupport);
            prefs.setString('userImage', userImage);
            prefs.setString('userTeam', userTeam);
            prefs.setString('userTeamImage', userTeamImage);
            prefs.setString('userTeamMembers', userTeamMembers);
            prefs.setString('userTeamPoints', userTeamPoints);
            prefs.setString('userTeamAdmin', userTeamAdmin);
            // Save leaderboard data
            if (data['soloLeaderboardData'] != null) {
              prefs.setString('soloLeaderboardData',
                  jsonEncode(data['soloLeaderboardData']));
            }
            if (data['teamLeaderboardData'] != null) {
              prefs.setString('teamLeaderboardData',
                  jsonEncode(data['teamLeaderboardData']));
            }
          });
        } else {
          print(
              'Failed to load user data. Status code: ${response.statusCode}');
        }
      } catch (e) {
        print('Error fetching user data: $e');
      }
    } else {
      throw Exception('Access token not found');
    }
  }

  @override
  void dispose() {
    _autoSlideTimer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _getsoloLeaderboardData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? leaderboardJson = prefs.getString('soloLeaderboardData');
    if (leaderboardJson != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(leaderboardJson));
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _getteamLeaderboardData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? leaderboardJson = prefs.getString('teamLeaderboardData');
    if (leaderboardJson != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(leaderboardJson));
    }
    return [];
  }

  Future<List<List<Map<String, dynamic>>>> _getLeaderboardGroups() async {
    try {
      // Fetch solo leaderboard data
      List<Map<String, dynamic>> soloLeaderboardData =
          await _getsoloLeaderboardData();

      // Fetch team leaderboard data
      List<Map<String, dynamic>> teamLeaderboardData =
          await _getteamLeaderboardData();

      // Combine into groups
      return [
        soloLeaderboardData, // Group 1: Solo leaderboard
        teamLeaderboardData, // Group 2: Team leaderboard
      ];
    } catch (e) {
      throw Exception('Failed to fetch leaderboard groups: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.5, // 50% transparency
              child: Image.asset(
                'assets/Backgrounds/Spine.png',
                fit: BoxFit.fill,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGreeting(),
                  const SpecialOfferCarousel(),
                  FutureBuilder<List<List<Map<String, dynamic>>>>(
                    future: _getLeaderboardGroups(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LoadingScreen(
                          loadingText: "",
                        );
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else if (snapshot.hasData) {
                        return SizedBox(
                          height: 250,
                          child: PageView(
                            controller: _pageController,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const LeaderboardScreen(),
                                    ),
                                  );
                                },
                                child: LeaderboardCarousel(
                                  leaderboardGroups: [snapshot.data![0]],
                                  titles: const ["Solo Leaderboard"],
                                  currentTeamName: userTeam,
                                  currentUserName: userName,
                                  currentUserImage: userImage,
                                  currentUserPoints: int.parse(userPoints),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const LeaderboardScreen(),
                                    ),
                                  );
                                },
                                child: LeaderboardCarousel(
                                  leaderboardGroups: [snapshot.data![1]],
                                  titles: const ["Team Leaderboard"],
                                  currentTeamName: userTeam,
                                  currentUserName: userName,
                                  currentUserImage: userImage,
                                  currentUserPoints: int.parse(userPoints),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        return const Text('No leaderboard data available');
                      }
                    },
                  ),
                  // const SizedBox(height: 12),
                  _buildFavouritesSection(),
                  const SizedBox(height: 16),
                  _buildFindPubsSection(),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(activeItem: 1),
      bottomNavigationBar: CustomBottomNavigationBar(),
    );
  }

  Future<bool> _validateJwtToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final refreshToken = prefs.getString('refresh_token');

      if (accessToken == null) {
        // No token found
        return false;
      }

      // Implement logic to refresh token if needed before sending it to the server

      final httpClient = HttpClient();
      final ioClient = IOClient(httpClient);

      final response = await ioClient.post(
        Uri.parse(apiServerJWTValidate),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'refresh_token': refreshToken,
          // Include push_token only if using OneSignal
          'push_token': OneSignal.User.pushSubscription.id?.toString(),
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['access_token'] != null) {
          final newAccessToken = jsonResponse['access_token'];
          final newRefreshToken = jsonResponse['refresh_token'];
          // Store the new tokens in shared preferences
          await prefs.setString('access_token', newAccessToken);
          await prefs.setString('refresh_token', newRefreshToken);
        }

        // Handle OneSignal login if needed
        OneSignal.login(jsonResponse['user_id']);

        return true;
      } else {
        // Token validation failed
        print('Token validation failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      // Handle errors during SharedPreferences or HTTP request
      print('Error validating token: $e');
      return false;
    }
  }

  String getGreeting() {
    var hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Good Morning 👋';
    } else if (hour < 17) {
      return 'Good Afternoon 👋';
    } else {
      return 'Good Evening 👋';
    }
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Builder(
              builder: (context) {
                return AppMenuButton(
                  onTap: () => Scaffold.of(context).openDrawer(),
                );
              },
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  getGreeting(),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.normal),
                ),
                const SizedBox(height: 4),
                Text(
                  userName.isNotEmpty ? userName : 'Loading...',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                )
              ],
            ),
            const Spacer(),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileScreen()),
                );
              },
              child: CircleAvatar(
                backgroundImage: (isValidBase64(userImage))
                    ? MemoryImage(base64Decode(userImage))
                    : null,
                child: (!isValidBase64(userImage))
                    ? const Icon(Icons.person)
                    : null,
              ),
            ),
            const SizedBox(width: 20),
          ],
        ),
      ],
    );
  }

  bool isValidBase64(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return false;
    }

    try {
      final decodedBytes = base64Decode(base64String);
      return decodedBytes.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Widget _buildFavouritesSection() {
    return Row(
      children: [
        Expanded(
          child: _buildFeatureCard(
            title: 'All Beers',
            icon: Icons.shopping_bag,
            color: Colors.pink,
            page: BeersScreen(),
            isActive: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildFeatureCard(
            title: 'Favourite Beers',
            icon: Icons.favorite,
            color: Colors.red,
            page: BeersScreen(startTabIndex: 1),
            isActive: true,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget page,
    bool isActive = true,
  }) {
    return GestureDetector(
      onTap: isActive
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => page),
              );
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive
              ? [BoxShadow(blurRadius: 10, color: Colors.grey.shade200)]
              : [BoxShadow(blurRadius: 2, color: Colors.grey.shade400)],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: isActive ? color : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.black : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFindPubsSection() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MapScreen()),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF061237),
              borderRadius: BorderRadius.circular(20),
              image: DecorationImage(
                image: const AssetImage('assets/images/map.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.5),
                  BlendMode.darken,
                ),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Find Your Nearest Pub →",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Locate pubs near you",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                Text(
                  "Quick and easy",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

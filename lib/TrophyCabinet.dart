import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:burtonaletrail_app/LoadingScreen.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:burtonaletrail_app/AppApi.dart';
import 'package:burtonaletrail_app/AppColors.dart';
import 'package:burtonaletrail_app/AppDrawer.dart';
import 'package:burtonaletrail_app/AppMenuButton.dart';
import 'package:burtonaletrail_app/NavBar.dart';

class TrophyCabinetScreen extends StatefulWidget {
  const TrophyCabinetScreen({Key? key}) : super(key: key);

  @override
  _TrophyCabinetScreenState createState() => _TrophyCabinetScreenState();
}

class _TrophyCabinetScreenState extends State<TrophyCabinetScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
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
  bool _isLoading = true;

  List<Map<String, dynamic>> unlockedBadges = [];
  List<Map<String, dynamic>> lockedBadges = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeState();
    _fetchBadges();
  }

  Future<void> _fetchBadges() async {
    setState(() {
      _isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? accessToken = prefs.getString('access_token');
      if (accessToken == null) {
        throw Exception('Access token not found');
      }

      bool trustSelfSigned = true;
      HttpClient httpClient = HttpClient()
        ..badCertificateCallback = (cert, host, port) => trustSelfSigned;
      IOClient ioClient = IOClient(httpClient);

      final response = await ioClient.post(
        Uri.parse(apiServerTrophys), // Ensure this is properly defined.
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'access_token': accessToken}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          unlockedBadges = data
              .where((badge) => badge['badge_unlocked'] == true)
              .map((badge) => {
                    'imageBase64': badge['badge_graphic'] ?? '',
                    'title': badge['badge_name'] ?? 'Unknown Badge',
                    'description': badge['badge_description'] ?? '',
                    'detailed': badge['badge_detailed_unlocked'] ?? '',
                    'event': badge['badge_event_name'] ?? 'Unknown Event',
                  })
              .toList();

          lockedBadges = data
              .where((badge) => badge['badge_unlocked'] == false)
              .map((badge) => {
                    'imageBase64': badge['badge_graphic'] ?? '',
                    'title': badge['badge_name'] ?? 'Unknown Badge',
                    'description': badge['badge_description'] ?? '',
                    'detailed': badge['badge_detailed'] ?? '',
                    'event': badge['badge_event_name'] ?? 'Unknown Event',
                  })
              .toList();
        });
      } else {
        debugPrint(
            'Failed to fetch badges. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching badges: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeState() async {
    // Create an instance of the Token class
    final token = Token();

    // Call the refresh method
    bool tokenRefreshed = await token.refresh();

    if (tokenRefreshed) {
      print('JWT token refreshed successfully');
      // Continue with additional initialization logic if necessary
    } else {
      print('Failed to refresh JWT token');
      // Handle the failure case, e.g., navigate to login or show an alert
    }

    // Fetch other user data or perform additional initialization here
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      userName = prefs.getString('userName') ?? '';
      userPoints = prefs.getString('userPoints') ?? '0';
      userPosition = prefs.getString('userPosition') ?? '0';
      userSupport = prefs.getString('userSupport') ?? 'off';
      userImage = prefs.getString('userImage') ?? '';
      userTeam = prefs.getString('userTeam') ?? '';
      userTeamImage = prefs.getString('userTeamImage') ?? '';
      userTeamMembers = prefs.getString('userTeamMembers') ?? '';
      userTeamPoints = prefs.getString('userTeamPoints') ?? '';
    });
  }

  /// Builds the grid of badges **grouped by event**.
  Widget _buildGroupedBadges(List<Map<String, dynamic>> badges,
      {bool isDisabled = false}) {
    // Group badges by their event name
    final Map<String, List<Map<String, dynamic>>> groupedBadges = {};
    for (var badge in badges) {
      final eventName = badge['event'] ?? 'Unknown Event';
      if (!groupedBadges.containsKey(eventName)) {
        groupedBadges[eventName] = [];
      }
      groupedBadges[eventName]!.add(badge);
    }

    // For each event category, build a heading + a grid of badges
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: groupedBadges.entries.map((entry) {
          final eventName = entry.key;
          final eventBadges = entry.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event name heading
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  eventName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // The grid of badges for this event
              GridView.builder(
                // Make the grid take up only the needed space
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: eventBadges.length,
                itemBuilder: (context, index) {
                  final badge = eventBadges[index];
                  return _buildBadge(
                    badge['imageBase64'],
                    badge['title'],
                    isDisabled: isDisabled,
                    description: badge['description'],
                    detailed: badge['detailed'],
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// Builds an individual badge widget (tap -> modal bottom sheet).
  Widget _buildBadge(
    String imageBase64,
    String title, {
    bool isDisabled = false,
    String? description = '',
    String? detailed = '',
  }) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          backgroundColor:
              Colors.transparent, // Make the background transparent
          context: context,
          isScrollControlled: true,
          builder: (BuildContext context) {
            return Align(
              alignment:
                  Alignment.bottomCenter, // Align it to the bottom center
              child: FractionallySizedBox(
                widthFactor: 0.9, // 90% of the screen width
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20), // Rounded corners for the modal
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isValidBase64(imageBase64))
                            Image.memory(
                              base64Decode(imageBase64),
                              width: 200,
                              height: 200,
                              fit: BoxFit.contain,
                            )
                          else
                            const Image(
                              image: AssetImage('assets/placeholder.png'),
                              width: 100,
                              height: 100,
                              fit: BoxFit.contain,
                            ),
                          const SizedBox(height: 16),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description ?? 'No description available.',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            detailed ?? '',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black87),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Close',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              image: DecorationImage(
                image: isValidBase64(imageBase64)
                    ? MemoryImage(base64Decode(imageBase64))
                    : const AssetImage('assets/placeholder.png')
                        as ImageProvider,
                fit: BoxFit.contain,
                colorFilter: isDisabled
                    ? const ColorFilter.matrix(<double>[
                        0.2126,
                        0.7152,
                        0.0722,
                        0,
                        0,
                        0.2126,
                        0.7152,
                        0.0722,
                        0,
                        0,
                        0.2126,
                        0.7152,
                        0.0722,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ])
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDisabled ? Colors.grey : Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Check if base64 is valid
  bool isValidBase64(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return false;
    }
    try {
      base64Decode(base64String);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Updated background image position and size
          Positioned.fill(
            child: Opacity(
              opacity: 0.5,
              child: Image.asset(
                'assets/Backgrounds/Spine.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Blur layer over background
          // Positioned.fill(
          //   child: BackdropFilter(
          //     filter: ImageFilter.blur(sigmaX: 20, sigmaY: 10),
          //     child: const SizedBox(),
          //   ),
          // ),
          // Foreground content
          SafeArea(
            child: _isLoading
                ? SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGreeting(),
                        TabBar(
                          controller: _tabController,
                          indicatorColor: AppColors.primaryColor,
                          labelColor: AppColors.primaryColor,
                          unselectedLabelColor: Colors.grey,
                          tabs: const [
                            Tab(text: 'Unlocked Awards'),
                            Tab(text: 'Available Awards'),
                          ],
                        ),
                        const Center(
                          child: LoadingScreen(loadingText: ""),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGreeting(),
                        TabBar(
                          controller: _tabController,
                          indicatorColor: AppColors.primaryColor,
                          labelColor: AppColors.primaryColor,
                          unselectedLabelColor: Colors.grey,
                          tabs: const [
                            Tab(text: 'Unlocked Badges'),
                            Tab(text: 'Available Badges'),
                          ],
                        ),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 20.0),
                            child: SizedBox(
                              width: size.width * 0.9,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      spreadRadius: 2,
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0),
                                  child: SizedBox(
                                    height: size.height * 0.65,
                                    child: TabBarView(
                                      controller: _tabController,
                                      children: [
                                        _buildGroupedBadges(unlockedBadges),
                                        _buildGroupedBadges(lockedBadges,
                                            isDisabled: true),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
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
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trophy Cabinet',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Your trophies and awards',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
            const Spacer(),
            InkWell(
              onTap: () {
                // Navigate to profile screen
              },
              // child: CircleAvatar(
              //   backgroundImage:
              //       (userImage.isNotEmpty && isValidBase64(userImage))
              //           ? MemoryImage(base64Decode(userImage))
              //           : null,
              //   child: (userImage.isEmpty || !isValidBase64(userImage))
              //       ? const Icon(Icons.person)
              //       : null,
              // ),
              child: const SizedBox(
                width: 40, // match CircleAvatar's size
                height: 40,
              ),
            ),
            const SizedBox(width: 20),
          ],
        ),
      ],
    );
  }
}

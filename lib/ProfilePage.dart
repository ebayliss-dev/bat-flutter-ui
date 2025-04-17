import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:burtonaletrail_app/AppApi.dart';
import 'package:burtonaletrail_app/AppColors.dart';
import 'package:burtonaletrail_app/AppDrawer.dart';
import 'package:burtonaletrail_app/AppMenuButton.dart';
import 'package:burtonaletrail_app/CreateTeam.dart';
import 'package:burtonaletrail_app/EditProfile.dart';
import 'package:burtonaletrail_app/EditTeam.dart';
import 'package:burtonaletrail_app/Init.dart';
import 'package:burtonaletrail_app/LoadingScreen.dart';
import 'package:burtonaletrail_app/NavBar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:rive/rive.dart' as rive;

// Import the external initialization function and model.

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

List<Map<String, dynamic>> items = []; // Example with an empty list

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  // User data variables.
  String userId = '';
  String userName = '';
  String userPoints = '0';
  String userPosition = '0';
  String userSupport = 'off';
  String userImage = '';
  String userTeam = '';
  String userTeamImage = '';
  String userTeamMembers = '';
  String userTeamPoints = '';
  List<String> members = [];
  String formattedMembers = '';
  String userTeamAdmin = '';

  // Controllers & image base64.
  late TextEditingController teamNameController;
  String teamImageBase64 = '';
  List<Map<String, dynamic>> teamMembers = [];

  // Loading state for team members.
  bool _isLoadingTeamMembers = false;

  @override
  void initState() {
    super.initState();
    // Initially load data from SharedPreferences.
    _fetchUserData();
    _fetchTeamMembers();
    _initializeUserData();
  }

  /// This method uses local SharedPreferences to populate the UI.
  Future<void> _fetchUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
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
      members = userTeamMembers
          .replaceAll('[', '')
          .replaceAll(']', '')
          .split(', ')
          .map((member) => member.trim())
          .toList();
    });
    formattedMembers =
        members.isEmpty ? 'None' : members.join('\n'); // For display
  }

  /// Calls the external initializeState() function and updates the state.
  Future<void> _initializeUserData() async {
    UserData? userData = await initializeState();
    if (userData != null) {
      setState(() {
        userId = userData.userId;
        userName = userData.userName;
        userPoints = userData.userPoints;
        userPosition = userData.userPosition;
        userSupport = userData.userSupport;
        userImage = userData.userImage;
        userTeam = userData.userTeam;
        userTeamImage = userData.userTeamImage;
        userTeamMembers = userData.userTeamMembers;
        userTeamPoints = userData.userTeamPoints;
        userTeamAdmin = userData.userTeamAdmin;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      extendBody: true,
      drawer: const AppDrawer(activeItem: 1),
      bottomNavigationBar: CustomBottomNavigationBar(),
      body: SizedBox.expand(
        // Ensures the Stack fills the entire screen
        child: Stack(
          children: [
            // Background image with opacity
            Positioned.fill(
              child: Opacity(
                opacity: 0.5,
                child: Image.asset(
                  'assets/Backgrounds/Spine.png',
                  fit: BoxFit
                      .cover, // BoxFit.fill may cause distortion, cover is usually better
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        size.height, // Ensures scroll content fills screen
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGreeting(),
                      _profileStats(),
                      _teamMembersSection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                  MaterialPageRoute(
                      builder: (context) => const ProfileScreen()),
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

  Widget _profileStats() {
    final size = MediaQuery.of(context).size;

    return Center(
      child: SizedBox(
        width: size.width * 0.9, // Set width relative to the screen size
        child: Card(
          color: Colors.white,
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () async {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreen(),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: size.width * 0.2,
                    backgroundImage: userImage.isNotEmpty
                        ? MemoryImage(base64Decode(userImage))
                        : const AssetImage('assets/images/marvin.png')
                            as ImageProvider,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Points: $userPoints',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Position: $userPosition',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                // Text(
                //   'Membership: None',
                //   style: TextStyle(
                //     fontSize: 16,
                //     color: userSupport == 'on' ? Colors.green : Colors.red,
                //   ),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _leaveTeam() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');
    if (accessToken == null) {
      throw Exception('Access token not found');
    }

    bool trustSelfSigned = true;
    HttpClient httpClient = HttpClient()
      ..badCertificateCallback = (cert, host, int port) => trustSelfSigned;
    IOClient ioClient = IOClient(httpClient);

    final response = await ioClient.post(
      Uri.parse(apiServerLeaveTeam),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'access_token': accessToken}),
    );

    if (response.statusCode == 200) {
      // Optionally, reinitialize user data after leaving the team.
      await _initializeUserData();
      setState(() {
        prefs.setString('userTeam', '');
        prefs.setString('userTeamImage', '');
        prefs.setString('userTeamMembers', '');
        prefs.setString('userTeamPoints', '');
      });
    } else {
      debugPrint('Failed to leave team. Status: ${response.statusCode}');
    }
  }

  Future<void> _fetchTeamMembers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');

    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated.')),
      );
      return;
    }

    // Set loading state to true before starting the API call.
    setState(() {
      _isLoadingTeamMembers = true;
    });

    bool trustSelfSigned = true;
    HttpClient httpClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => trustSelfSigned;
    IOClient ioClient = IOClient(httpClient);

    try {
      final response = await ioClient.post(
        Uri.parse(apiServerGetTeamMembers), // Defined in AppApi.dart.
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'access_token': accessToken,
          'teamName': userTeam,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Use the key 'team_members' per your backend response.
        List<dynamic> membersList = data['team_members'] ?? [];
        setState(() {
          teamMembers = List<Map<String, dynamic>>.from(membersList);
        });
      } else {
        print(
            'Failed to fetch team members. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching team members: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching team members')),
      );
    } finally {
      // Reset loading state when finished.
      setState(() {
        _isLoadingTeamMembers = false;
      });
    }
  }

  Widget _teamMembersSection() {
    final size = MediaQuery.of(context).size;

    return Card(
      color: Colors.white,
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top section: Display team stats if the user is in a team.
            if (userTeam.isNotEmpty && userTeam != "No Team") ...[
              Center(
                child: GestureDetector(
                  onTap: () async {
                    if (userTeamAdmin == userId) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditTeamScreen(),
                        ),
                      );
                    }
                  },
                  child: CircleAvatar(
                    radius: size.width * 0.15,
                    backgroundImage: userTeamImage.isNotEmpty
                        ? MemoryImage(base64Decode(userTeamImage))
                        : const AssetImage('assets/images/marvin.png')
                            as ImageProvider,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  userTeam,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Points: $userTeamPoints',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Position: $userPosition',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
              const Divider(height: 30),
            ] else ...[
              // If no team exists, show Create/Join buttons.
              Center(
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        // Navigate to CreateTeamScreen.
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateTeamScreen(),
                          ),
                        );
                        // After returning, call initializeState to update user data.
                        await _initializeUserData();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[850], // Background color
                        foregroundColor: Colors.white, // Text (and icon) color
                      ),
                      child: const Text('Create Team'),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],

            if (userTeam.isNotEmpty && userTeam != "No Team") ...[
              const Text(
                'Team Members',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // If team members are loading, show a progress indicator.
              SizedBox(
                height: 200, // Adjust the height as needed.
                child: _isLoadingTeamMembers
                    ? const Center(
                        child: LoadingScreen(
                          loadingText: "",
                        ),
                      )
                    : ListView.separated(
                        itemCount: teamMembers.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final member = teamMembers[index];
                          return ListTile(
                            leading: (member['user_image'] != null &&
                                    (member['user_image'] as String).isNotEmpty)
                                ? CircleAvatar(
                                    backgroundImage: MemoryImage(
                                      base64Decode(member['user_image']),
                                    ),
                                  )
                                : const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(member['user_name'] ?? ''),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
            ],
            // Additional actions (e.g., Leave or Edit Team) if a team exists.
            if (userTeam.isNotEmpty && userTeam != "No Team") ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (userTeamAdmin != userId)
                    ElevatedButton(
                      onPressed: () {
                        // Show confirmation dialog for leaving the team.
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              backgroundColor: Colors.white,
                              title: const Text('Leave Team'),
                              content: const Text(
                                'Are you sure you want to leave the team? Your points will be removed from this team, potentially lowering their position on the leaderboard.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context)
                                        .pop(); // Close the dialog.
                                  },
                                  child: const Text('Cancel'),
                                ),
                                // Only show the Confirm button if the current user is not the team admin.
                                if (userTeamAdmin != userId)
                                  TextButton(
                                    onPressed: () async {
                                      await _leaveTeam();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const ProfileScreen(),
                                        ),
                                      );
                                    },
                                    child: const Text('Confirm'),
                                  ),
                              ],
                            );
                          },
                        );
                      },
                      child: const Text('Leave Team'),
                    ),
                  // Show the Edit Team button only if the current user is the team admin.
                  if (userTeamAdmin == userId)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditTeamScreen(),
                          ),
                        );
                      },
                      child: const Text('Edit Team'),
                    ),
                  if (userTeamAdmin == userId)
                    ElevatedButton(
                      onPressed: () async {
                        await _deleteTeam(userTeam);
                      },
                      child: const Text('Delete Team'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTeam(String teamName) async {
    // Show the loading dialog.
    showDialog(
      context: context,
      barrierDismissible:
          false, // Prevents closing the dialog by tapping outside.
      builder: (context) => const LoadingScreen(loadingText: "Deleting Team"),
    );

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? accessToken = prefs.getString('access_token');
      if (accessToken == null) return; // The finally block will still execute.

      bool trustSelfSigned = true;
      HttpClient httpClient = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => trustSelfSigned;
      IOClient ioClient = IOClient(httpClient);

      final response = await ioClient.post(
        Uri.parse(apiServerDeleteTeam), // Adjust the URL accordingly.
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'access_token': accessToken,
          'team_name': teamName,
        }),
      );

      if (response.statusCode == 200) {
        // After a successful deletion, update user data.
        await _initializeUserData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team deleted successfully')),
        );
      } else if (response.statusCode == 408) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This user is already in a team')),
        );
      } else if (response.statusCode == 410) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This user does not exist')),
        );
      }
    } catch (e) {
      print('Error deleting team: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error deleting team')),
      );
    } finally {
      // Dismiss the loading dialog.
      Navigator.of(context).pop();
    }
  }
}

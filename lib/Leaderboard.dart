import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
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

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // AnimatedList keys
  late GlobalKey<AnimatedListState> _soloListKey;
  late GlobalKey<AnimatedListState> _teamListKey;

  // Periodic refresh
  late Timer _updateTimer;

  // SOLO
  List<Map<String, dynamic>> soloLeaderboard = [];
  List<Map<String, dynamic>> _oldSoloLeaderboard = [];

  // TEAM
  List<Map<String, dynamic>> teamLeaderboard = [];
  List<Map<String, dynamic>> _oldTeamLeaderboard = [];

  // Arrows/diffs across refreshes
  Map<String, Map<String, int>> _soloArrows = {};
  Map<String, Map<String, int>> _teamArrows = {};

  // User info
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

  // Team members for bottom sheet
  List<Map<String, dynamic>> members = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initialize keys
    _soloListKey = GlobalKey<AnimatedListState>();
    _teamListKey = GlobalKey<AnimatedListState>();

    // Load old saved data first, then render
    _loadOldLeaderboardsFromPrefs().then((_) {
      _forceRender();
    });

    // Start periodic updates
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _updateLeaderboard();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _forceRender() async {
    setState(() => _isLoading = true);

    await _fetchLeaderboardFromCache();
    await _initializeState();
    await _updateLeaderboard();

    // A little visual tab switch effect
    _tabController.animateTo(1);
    await Future.delayed(const Duration(milliseconds: 500));
    _tabController.animateTo(0);

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _updateTimer.cancel(); // Cancel the timer to prevent calls to setState
    super.dispose();
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

  bool _leaderboardListsAreSame(
    List<Map<String, dynamic>> oldList,
    List<Map<String, dynamic>> newList,
  ) {
    if (oldList.length != newList.length) return false;

    for (int i = 0; i < oldList.length; i++) {
      final oldItem = Map<String, dynamic>.from(oldList[i]);
      final newItem = Map<String, dynamic>.from(newList[i]);

      oldItem.remove('positionChange');
      oldItem.remove('pointsDiff');
      newItem.remove('positionChange');
      newItem.remove('pointsDiff');

      if (jsonEncode(oldItem) != jsonEncode(newItem)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _fetchLeaderboardFromCache() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? soloData = prefs.getString('solo_leaderboard');
    String? teamData = prefs.getString('team_leaderboard');

    if (soloData != null && teamData != null) {
      setState(() {
        soloLeaderboard = List<Map<String, dynamic>>.from(jsonDecode(soloData));
        teamLeaderboard = List<Map<String, dynamic>>.from(jsonDecode(teamData));

        if (_oldSoloLeaderboard.isEmpty) {
          _oldSoloLeaderboard =
              List<Map<String, dynamic>>.from(soloLeaderboard);
        }
        if (_oldTeamLeaderboard.isEmpty) {
          _oldTeamLeaderboard =
              List<Map<String, dynamic>>.from(teamLeaderboard);
        }

        // Re-apply any stored arrow info
        _applyStoredArrowsToLeaderboard();
      });
    }
  }

  Future<void> _fetchLeaderboardFromNetwork() async {
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
      Uri.parse(apiServerLeaderboards),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'access_token': accessToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Cache the new data
      await prefs.setString('solo_leaderboard', jsonEncode(data['solo']));
      await prefs.setString('team_leaderboard', jsonEncode(data['team']));

      setState(() {
        soloLeaderboard = List<Map<String, dynamic>>.from(data['solo']);
        teamLeaderboard = List<Map<String, dynamic>>.from(data['team']);
        // Initialize old arrays if empty
        if (_oldSoloLeaderboard.isEmpty) {
          _oldSoloLeaderboard =
              List<Map<String, dynamic>>.from(soloLeaderboard);
        }
        if (_oldTeamLeaderboard.isEmpty) {
          _oldTeamLeaderboard =
              List<Map<String, dynamic>>.from(teamLeaderboard);
        }
      });
    } else {
      debugPrint('Failed to load leaderboard. Status: ${response.statusCode}');
    }
  }

  Future<void> _saveOldLeaderboardsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'old_solo_leaderboard',
      jsonEncode(_oldSoloLeaderboard),
    );
    await prefs.setString(
      'old_team_leaderboard',
      jsonEncode(_oldTeamLeaderboard),
    );
    // Also save arrow maps
    await prefs.setString('solo_arrows', jsonEncode(_soloArrows));
    await prefs.setString('team_arrows', jsonEncode(_teamArrows));
  }

  Future<void> _loadOldLeaderboardsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final oldSoloJson = prefs.getString('old_solo_leaderboard');
    final oldTeamJson = prefs.getString('old_team_leaderboard');
    final soloArrowsJson = prefs.getString('solo_arrows');
    final teamArrowsJson = prefs.getString('team_arrows');

    if (oldSoloJson != null) {
      _oldSoloLeaderboard =
          List<Map<String, dynamic>>.from(jsonDecode(oldSoloJson));
    }
    if (oldTeamJson != null) {
      _oldTeamLeaderboard =
          List<Map<String, dynamic>>.from(jsonDecode(oldTeamJson));
    }

    if (soloArrowsJson != null) {
      final Map<String, dynamic> map =
          jsonDecode(soloArrowsJson) as Map<String, dynamic>;
      _soloArrows = map.map((key, value) => MapEntry(
            key,
            {
              'positionChange': value['positionChange'] ?? 0,
              'pointsDiff': value['pointsDiff'] ?? 0,
            },
          ));
    }
    if (teamArrowsJson != null) {
      final Map<String, dynamic> map =
          jsonDecode(teamArrowsJson) as Map<String, dynamic>;
      _teamArrows = map.map((key, value) => MapEntry(
            key,
            {
              'positionChange': value['positionChange'] ?? 0,
              'pointsDiff': value['pointsDiff'] ?? 0,
            },
          ));
    }
  }

  void _applyStoredArrowsToLeaderboard() {
    // Re-apply SOLO arrows
    for (final player in soloLeaderboard) {
      final name = player['name'];
      if (_soloArrows.containsKey(name)) {
        player['positionChange'] = _soloArrows[name]!['positionChange'];
        player['pointsDiff'] = _soloArrows[name]!['pointsDiff'];
      }
    }
    // Re-apply TEAM arrows
    for (final team in teamLeaderboard) {
      final name = team['name'];
      if (_teamArrows.containsKey(name)) {
        team['positionChange'] = _teamArrows[name]!['positionChange'];
        team['pointsDiff'] = _teamArrows[name]!['pointsDiff'];
      }
    }
  }

  Future<void> _updateLeaderboard() async {
    await _fetchLeaderboardFromNetwork();
    try {
      // Keep old copies
      var oldSolo = List<Map<String, dynamic>>.from(_oldSoloLeaderboard);
      var oldTeam = List<Map<String, dynamic>>.from(_oldTeamLeaderboard);

      // Then fetch updated data from cache
      await _fetchLeaderboardFromCache();

      var newSolo = List<Map<String, dynamic>>.from(soloLeaderboard);
      var newTeam = List<Map<String, dynamic>>.from(teamLeaderboard);

      bool soloSame = _leaderboardListsAreSame(oldSolo, newSolo);
      bool teamSame = _leaderboardListsAreSame(oldTeam, newTeam);

      if (!soloSame) {
        _applyArrowsAndAnimateSolo(oldSolo, newSolo);
      }
      if (!teamSame) {
        _applyArrowsAndAnimateTeam(oldTeam, newTeam);
      }

      // Save updated old data
      await _saveOldLeaderboardsToPrefs();
    } catch (e) {
      debugPrint('Error updating leaderboard: $e');
    }
  }

  // ------------------ SOLO Logic ------------------
  void _applyArrowsAndAnimateSolo(
    List<Map<String, dynamic>> oldSolo,
    List<Map<String, dynamic>> newSolo,
  ) {
    final oldMap = <String, Map<String, dynamic>>{};
    for (int i = 0; i < oldSolo.length; i++) {
      final p = oldSolo[i];
      oldMap[p['name']] = {
        'rank': i,
        'points': p['credits'] ?? 0,
      };
    }

    for (int i = 0; i < newSolo.length; i++) {
      final p = newSolo[i];
      final name = p['name'];
      final newPoints = p['credits'] ?? 0;
      final newRank = i;

      if (!oldMap.containsKey(name)) {
        // brand new user
        _soloArrows[name] = {
          'positionChange': 0,
          'pointsDiff': 0,
        };
        p['positionChange'] = 0;
        p['pointsDiff'] = 0;
        continue;
      }

      final oldRank = oldMap[name]!['rank'] as int;
      final oldPoints = oldMap[name]!['points'] as int;

      final rankDiff = oldRank - newRank;
      final ptsDiff = newPoints - oldPoints;

      final oldArrow =
          _soloArrows[name] ?? {'positionChange': 0, 'pointsDiff': 0};

      if (rankDiff == 0 && ptsDiff == 0) {
        p['positionChange'] = oldArrow['positionChange'] ?? 0;
        p['pointsDiff'] = oldArrow['pointsDiff'] ?? 0;
      } else {
        p['positionChange'] = rankDiff;
        p['pointsDiff'] = ptsDiff;
      }

      // Update stored arrow
      _soloArrows[name] = {
        'positionChange': p['positionChange'],
        'pointsDiff': p['pointsDiff'],
      };
    }

    // Animate changes in AnimatedList

    // 1) Remove items that differ or no longer exist
    for (int i = _oldSoloLeaderboard.length - 1; i >= 0; i--) {
      if (i >= newSolo.length ||
          !_itemsAreSameIgnoringArrows(_oldSoloLeaderboard[i], newSolo[i])) {
        final removedItem = _oldSoloLeaderboard[i];
        _soloListKey.currentState?.removeItem(
          i,
          (context, animation) =>
              _buildAnimatedSoloItem(removedItem, animation, i),
        );
        _oldSoloLeaderboard.removeAt(i);
      }
    }

    // 2) Insert / re-insert
    for (int i = 0; i < newSolo.length; i++) {
      if (i >= _oldSoloLeaderboard.length) {
        _oldSoloLeaderboard.insert(i, newSolo[i]);
        _soloListKey.currentState?.insertItem(i);
      } else if (!_itemsAreSameIgnoringArrows(
          _oldSoloLeaderboard[i], newSolo[i])) {
        final removedItem = _oldSoloLeaderboard[i];
        _soloListKey.currentState?.removeItem(
          i,
          (context, animation) =>
              _buildAnimatedSoloItem(removedItem, animation, i),
        );
        _oldSoloLeaderboard.removeAt(i);

        _oldSoloLeaderboard.insert(i, newSolo[i]);
        _soloListKey.currentState?.insertItem(i);
      } else {
        // identical ignoring arrow fields => just update arrow fields
        _oldSoloLeaderboard[i] = newSolo[i];
      }
    }
  }

  // ------------------ TEAM Logic ------------------
  void _applyArrowsAndAnimateTeam(
    List<Map<String, dynamic>> oldTeam,
    List<Map<String, dynamic>> newTeam,
  ) {
    final oldMap = <String, Map<String, dynamic>>{};
    for (int i = 0; i < oldTeam.length; i++) {
      final t = oldTeam[i];
      oldMap[t['name']] = {
        'rank': i,
        'points': t['credits'] ?? 0,
      };
    }

    for (int i = 0; i < newTeam.length; i++) {
      final t = newTeam[i];
      final name = t['name'];
      final newPoints = t['credits'] ?? 0;
      final newRank = i;

      if (!oldMap.containsKey(name)) {
        // brand new team
        _teamArrows[name] = {
          'positionChange': 0,
          'pointsDiff': 0,
        };
        t['positionChange'] = 0;
        t['pointsDiff'] = 0;
        continue;
      }

      final oldRank = oldMap[name]!['rank'] as int;
      final oldPoints = oldMap[name]!['points'] as int;

      final rankDiff = oldRank - newRank;
      final ptsDiff = newPoints - oldPoints;

      final oldArrow =
          _teamArrows[name] ?? {'positionChange': 0, 'pointsDiff': 0};

      if (rankDiff == 0 && ptsDiff == 0) {
        t['positionChange'] = oldArrow['positionChange'] ?? 0;
        t['pointsDiff'] = oldArrow['pointsDiff'] ?? 0;
      } else {
        t['positionChange'] = rankDiff;
        t['pointsDiff'] = ptsDiff;
      }

      _teamArrows[name] = {
        'positionChange': t['positionChange'],
        'pointsDiff': t['pointsDiff'],
      };
    }

    // Animate changes
    for (int i = _oldTeamLeaderboard.length - 1; i >= 0; i--) {
      if (i >= newTeam.length ||
          !_itemsAreSameIgnoringArrows(_oldTeamLeaderboard[i], newTeam[i])) {
        final removedItem = _oldTeamLeaderboard[i];
        _teamListKey.currentState?.removeItem(
          i,
          (context, animation) =>
              _buildAnimatedTeamItem(removedItem, animation, i),
        );
        _oldTeamLeaderboard.removeAt(i);
      }
    }

    for (int i = 0; i < newTeam.length; i++) {
      if (i >= _oldTeamLeaderboard.length) {
        _oldTeamLeaderboard.insert(i, newTeam[i]);
        _teamListKey.currentState?.insertItem(i);
      } else if (!_itemsAreSameIgnoringArrows(
          _oldTeamLeaderboard[i], newTeam[i])) {
        final removedItem = _oldTeamLeaderboard[i];
        _teamListKey.currentState?.removeItem(
          i,
          (context, animation) =>
              _buildAnimatedTeamItem(removedItem, animation, i),
        );
        _oldTeamLeaderboard.removeAt(i);

        _oldTeamLeaderboard.insert(i, newTeam[i]);
        _teamListKey.currentState?.insertItem(i);
      } else {
        _oldTeamLeaderboard[i] = newTeam[i];
      }
    }
  }

  bool _itemsAreSameIgnoringArrows(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final copyA = Map<String, dynamic>.from(a);
    final copyB = Map<String, dynamic>.from(b);
    copyA.remove('positionChange');
    copyA.remove('pointsDiff');
    copyB.remove('positionChange');
    copyB.remove('pointsDiff');
    return jsonEncode(copyA) == jsonEncode(copyB);
  }

  // ------------------ BUILD ------------------
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

            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: size.height,
                  ),
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
                          Tab(text: 'Solo Leaderboard'),
                          Tab(text: 'Team Leaderboard'),
                        ],
                      ),
                      _isLoading
                          ? const Center(
                              child: LoadingScreen(loadingText: ""),
                            )
                          : Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 20.0),
                                child: SizedBox(
                                  height: size.height * 0.65,
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
                                      child: TabBarView(
                                        controller: _tabController,
                                        children: [
                                          _soloLeaderboardWidget(),
                                          _teamLeaderboardWidget(),
                                        ],
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
            ),
          ],
        ),
      ),
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
                  'Leaderboards',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Who are the top performers?',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
            const Spacer(),
            InkWell(
              onTap: () {
                // Navigate to profile screen
              },
              child: CircleAvatar(
                backgroundImage:
                    (userImage.isNotEmpty && isValidBase64(userImage))
                        ? MemoryImage(base64Decode(userImage))
                        : null,
                child: (userImage.isEmpty || !isValidBase64(userImage))
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
    // Treat the literal string "None" as no image
    if (base64String.toLowerCase() == "none") {
      return false;
    }
    try {
      base64Decode(base64String);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ------------------ SOLO UI ------------------
  Widget _soloLeaderboardWidget() {
    return AnimatedList(
      key: _soloListKey,
      initialItemCount: soloLeaderboard.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index, animation) {
        final player = soloLeaderboard[index];
        return _buildAnimatedSoloItem(player, animation, index);
      },
    );
  }

  void _showPlayerDetails(BuildContext context, Map<String, dynamic> player) {
    Uint8List? imageBytes;
    if (player['image'] != null &&
        player['image'] is String &&
        isValidBase64(player['image'])) {
      imageBytes = base64Decode(player['image']);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imageBytes != null)
                CircleAvatar(
                  radius: 100,
                  backgroundImage: MemoryImage(imageBytes),
                )
              else
                const CircleAvatar(
                  radius: 100,
                  child: Icon(Icons.person, size: 50),
                ),
              const SizedBox(height: 16),
              Text(
                player['name'] ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${player['credits']} pts',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              Text(
                ' ' * 1000,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Close',
                  style: TextStyle(fontSize: 16, color: AppColors.primaryColor),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnimatedSoloItem(
    Map<String, dynamic> player,
    Animation<double> animation,
    int index,
  ) {
    final posChange = player['positionChange'] ?? 0;
    final ptsDiff = player['pointsDiff'] ?? 0;

    Uint8List? imageBytes;
    if (player['image'] != null &&
        player['image'] is String &&
        isValidBase64(player['image'])) {
      imageBytes = base64Decode(player['image']);
    }

    return SizeTransition(
      sizeFactor: animation,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: GestureDetector(
          onTap: () => _showPlayerDetails(context, player),
          child: Row(
            children: [
              // Rank display
              Text(
                '${index + 1}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 16),

              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundImage:
                    (imageBytes != null) ? MemoryImage(imageBytes) : null,
                child: (imageBytes == null) ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 16),

              // Player details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + position change arrow
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            player['name'] ??
                                'Unknown', // Fallback for null names
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (posChange > 0) ...[
                          const Icon(Icons.arrow_drop_up, color: Colors.green),
                          Text(
                            '+$posChange',
                            style: const TextStyle(color: Colors.green),
                          ),
                          if (ptsDiff != 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(+$ptsDiff pts)',
                              style: const TextStyle(color: Colors.green),
                            ),
                          ],
                        ] else if (posChange < 0) ...[
                          const Icon(Icons.arrow_drop_down, color: Colors.red),
                          Text(
                            '$posChange',
                            style: const TextStyle(color: Colors.red),
                          ),
                          if (ptsDiff != 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '${ptsDiff > 0 ? '+' : ''}$ptsDiff pts',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ],
                      ],
                    ),

                    // Player points
                    Text('${player['credits']} pts'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------ TEAM UI ------------------
  Widget _teamLeaderboardWidget() {
    return AnimatedList(
      key: _teamListKey,
      initialItemCount: teamLeaderboard.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index, animation) {
        final team = teamLeaderboard[index];
        return _buildAnimatedTeamItem(team, animation, index);
      },
    );
  }

  Future<void> _showTeamDetails(
      BuildContext context, Map<String, dynamic> team) async {
    // Clear old members each time before fetch
    members = [];

    Uint8List? imageBytes;
    if (team['image'] != null &&
        team['image'] is String &&
        isValidBase64(team['image'])) {
      imageBytes = base64Decode(team['image']);
    }

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
      Uri.parse(apiServerLeaderboardsTeamQuery),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'access_token': accessToken, 'team': team['name']}),
    );

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      // Make sure it’s actually a List before casting.
      if (data['members'] is List) {
        // Convert to List<Map<String, dynamic>>
        setState(() {
          members = List<Map<String, dynamic>>.from(data['members']);
        });
      } else {
        // If it's anything else (like a String, null, etc.),
        // handle gracefully by clearing or showing an error.
        setState(() {
          members = [];
        });
        debugPrint('Warning: data["members"] was not a list!');
      }
    } else {
      debugPrint(
          'Failed to get team information. Status: ${response.statusCode}');
    }

    // Now show the bottom sheet after we've (attempted) to load members
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imageBytes != null)
                CircleAvatar(
                  radius: 100,
                  backgroundImage: MemoryImage(imageBytes),
                )
              else
                const CircleAvatar(
                  radius: 100,
                  child: Icon(Icons.group, size: 50),
                ),
              const SizedBox(height: 16),
              Text(
                team['name'] ?? 'Unknown Team',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${team['credits']} pts',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              // const Text(
              //   'Members:',
              //   style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              // ),
              const SizedBox(height: 16),
              // Display members list
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  // We know index < members.length here, so no out-of-range
                  final member = members[index];
                  final memberName = member['name'] ?? 'Unknown';
                  final memberCredits = member['credits'] ?? 0;

                  Uint8List? memberImageBytes;
                  if (member['image'] != null &&
                      member['image'] is String &&
                      isValidBase64(member['image'])) {
                    memberImageBytes = base64Decode(member['image']);
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: (memberImageBytes != null)
                              ? MemoryImage(memberImageBytes)
                              : null,
                          child: (memberImageBytes == null)
                              ? const Icon(Icons.person, size: 20)
                              : null,
                        ),
                        Text(
                          memberName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          '$memberCredits pts',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Close',
                  style: TextStyle(fontSize: 16, color: Colors.blue),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnimatedTeamItem(
    Map<String, dynamic> team,
    Animation<double> animation,
    int index,
  ) {
    final posChange = team['positionChange'] ?? 0;
    final ptsDiff = team['pointsDiff'] ?? 0;

    Uint8List? imageBytes;
    if (team['image'] != null &&
        team['image'] is String &&
        isValidBase64(team['image'])) {
      imageBytes = base64Decode(team['image']);
    }

    return SizeTransition(
      sizeFactor: animation,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: GestureDetector(
          onTap: () => _showTeamDetails(context, team),
          child: Row(
            children: [
              Text(
                '${index + 1}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 28,
                backgroundImage:
                    (imageBytes != null) ? MemoryImage(imageBytes) : null,
                child: (imageBytes == null) ? const Icon(Icons.group) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            team['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (posChange > 0) ...[
                          const Icon(Icons.arrow_drop_up, color: Colors.green),
                          Text('+$posChange',
                              style: const TextStyle(color: Colors.green)),
                          if (ptsDiff != 0) ...[
                            const SizedBox(width: 4),
                            Text('(+$ptsDiff pts)',
                                style: const TextStyle(color: Colors.green)),
                          ],
                        ] else if (posChange < 0) ...[
                          const Icon(Icons.arrow_drop_down, color: Colors.red),
                          Text('$posChange',
                              style: const TextStyle(color: Colors.red)),
                          if (ptsDiff != 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '${ptsDiff > 0 ? '+' : ''}$ptsDiff pts',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ],
                      ],
                    ),
                    Text('${team['credits']} pts'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

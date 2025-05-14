import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:burtonaletrail_app/AppApi.dart'; // Assumes apiServerCreateTeam is defined here.
import 'package:burtonaletrail_app/AppDrawer.dart';
import 'package:burtonaletrail_app/AppMenuButton.dart';
import 'package:burtonaletrail_app/NavBar.dart';
import 'package:burtonaletrail_app/ProfilePage.dart';
import 'package:http/io_client.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:rive/rive.dart' as rive;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;
import 'package:burtonaletrail_app/Notifications.dart'; // Assumes apiServerCreateTeam is defined here.

class CreateTeamScreen extends StatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController teamNameController;
  String teamImageBase64 = '';

  @override
  void initState() {
    super.initState();
    teamNameController = TextEditingController();
    NotificationSetup();
  }

  @override
  void dispose() {
    teamNameController.dispose();
    super.dispose();
  }

  void NotificationSetup() async {
    await NotificationService().initialize();
  }

  /// This function sends the team name and team image to the server.
  Future<void> _createTeam() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');

    if (teamNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a team name.')),
      );
      return;
    }

    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated.')),
      );
      return;
    }

    // Setup an HTTP client that allows self-signed certificates.
    bool trustSelfSigned = true;
    HttpClient httpClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => trustSelfSigned;
    IOClient ioClient = IOClient(httpClient);

    try {
      final response = await ioClient.post(Uri.parse(apiServerCreateTeam),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'access_token': accessToken,
            'teamName': teamNameController.text,
            'teamImage': teamImageBase64,
          }));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        final String message = responseData['message'] ?? '1';
        print(message);
        // if (message == "0") {
        //   await NotificationService().showNotification(
        //     title: "BADGE AWARDED",
        //     body: "You have unlocked the Rock n Roll Doctor",
        //   );
        //   Future.delayed(Duration(seconds: 10), () async {
        //     await NotificationService().showNotification(
        //       title: "POINTS AWARDED",
        //       body: "You have been awarded with 250 points",
        //     );
        //   });
        // }
        // if (message == "2") {
        //   await NotificationService().showNotification(
        //     title: "BADGE AWARDED",
        //     body: "You have unlocked the Rock n Roll Doctor",
        //   );
        //   Future.delayed(Duration(seconds: 10), () async {
        //     await NotificationService().showNotification(
        //       title: "BADGE AWARDED",
        //       body: "You have unlocked the TEAM PLAYER player badge",
        //     );
        //   });
        //   Future.delayed(Duration(seconds: 10), () async {
        //     await NotificationService().showNotification(
        //       title: "POINTS AWARDED",
        //       body: "You have been awarded with 500 points",
        //     );
        //   });
        // }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team created successfully')),
        );
        // Optionally navigate away or refresh the UI here.
      } else if (response.statusCode == 405) {
        print('You already in team. Status code: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Failed to create team. You are already in a team.')),
        );
      } else {
        print('Failed to create team. Status code: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create team.')),
        );
      }
    } catch (e) {
      print('Error creating team: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error creating team.')),
      );
    }
  }

  /// This function lets the user pick an image from the gallery,
  /// crop it, compress it to ensure it’s under 100KB, and then saves it.
  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile =
          await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Image',
              toolbarColor: Colors.blue,
              toolbarWidgetColor: Colors.white,
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: 'Crop Image',
              aspectRatioLockEnabled: true,
            ),
          ],
        );

        if (croppedFile != null) {
          final originalBytes = await croppedFile.readAsBytes();
          final decodedImage = img.decodeImage(originalBytes);

          if (decodedImage != null) {
            // Compress the image with an initial quality setting.
            var compressedImage = img.encodeJpg(
              decodedImage,
              quality: 70,
            );

            // Adjust quality until the image is under 100KB.
            int targetSize = 100 * 1024; // 100KB
            int quality = 70;
            while (compressedImage.length > targetSize && quality > 10) {
              quality -= 5;
              compressedImage = img.encodeJpg(decodedImage, quality: quality);
            }

            setState(() {
              teamImageBase64 = base64Encode(compressedImage);
            });
          }
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      Get.snackbar(
        'Error',
        'An error occurred while picking or cropping the image.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Background image and effects.
          Positioned(
            width: size.width * 1.7,
            bottom: 100,
            left: 100,
            child: Image.asset('assets/Backgrounds/Spline.png'),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 10),
            ),
          ),
          const rive.RiveAnimation.asset('assets/RiveAssets/shapes.riv'),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 10),
              child: const SizedBox(),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _teamImageSection(),
                  const SizedBox(height: 20),
                  _createTeamForm(),
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

  /// A header that includes a menu button and a title.
  Widget _buildHeader() {
    return Row(
      children: [
        Builder(
          builder: (context) {
            return AppMenuButton(
              onTap: () => Scaffold.of(context).openDrawer(),
            );
          },
        ),
        const SizedBox(width: 10),
        const Text(
          'Create Team',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// Displays the team image (or a default placeholder) with a camera icon for picking an image.
  Widget _teamImageSection() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundImage: teamImageBase64.isNotEmpty
                ? MemoryImage(base64Decode(teamImageBase64))
                : const AssetImage('assets/images/default_team.png')
                    as ImageProvider,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue,
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the form with a team name field and a "Create Team" button.
  Widget _createTeamForm() {
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
            _buildTextField('Team Name', teamNameController),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  await _createTeam();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(),
                    ),
                  );
                },
                child: const Text('Create Team'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper function to build a text field with a label.
  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

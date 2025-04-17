import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:ui';
import 'package:burtonaletrail_app/Notifications.dart';
import 'package:burtonaletrail_app/Pubs.dart';
import 'package:burtonaletrail_app/TrophyCabinet.dart';
import 'package:flutter/material.dart';
import 'package:http/io_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:burtonaletrail_app/AppDrawer.dart';
import 'package:burtonaletrail_app/Home.dart';
import 'package:burtonaletrail_app/AppMenuButton.dart';
import 'package:burtonaletrail_app/UnlockedBadge.dart';
import 'package:burtonaletrail_app/NavBar.dart';
import 'package:http/http.dart' as http;

class QRScanner extends StatefulWidget {
  const QRScanner({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _QRScannerState();
}

class _QRScannerState extends State<QRScanner> {
  Barcode? result;
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  DateTime? lastScanTime;
  String userName = '';
  String userImage = '';
  bool _isLoading = true;
  String accessToken = '';

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _initializeState();
  }

  Future<void> _checkPermissions() async {
    var status = await Permission.camera.status;
    if (status.isDenied || status.isRestricted || status.isPermanentlyDenied) {
      await Permission.camera.request();
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    }
    controller?.resumeCamera();
  }

  Future<void> _initializeState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('userName') ?? '';
      userImage = prefs.getString('userImage') ?? '';
      accessToken = prefs.getString('access_token') ?? '';
      _isLoading = false;
    });
  }

  Future<void> checkIn(String url) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? uuid = prefs.getString('userId');

    if (uuid == null) {
      _showSnackBar('User UUID is missing.');
      return;
    }

    try {
      HttpClient httpClient = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
      IOClient ioClient = IOClient(httpClient);

      final response = await http.post(
        Uri.parse('$url'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'access_token': accessToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          await NotificationService().showNotification(
            title: "PUB UNLOCKED",
            body: data['badgeName'],
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PubsScreen(),
            ),
          );
        }
      } else if (response.statusCode == 700) {
        _showSnackBar('The event has not yet started.', isError: true);
      } else {
        throw Exception('Failed to check in');
      }
    } catch (e) {
      _showSnackBar('Error checking in: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(child: _buildQrView(context)),
                ],
              ),
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(activeItem: 1),
      bottomNavigationBar: const CustomBottomNavigationBar(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Builder(
            builder: (context) => AppMenuButton(
              onTap: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Check In',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Scan the QR code at each pub',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
          CircleAvatar(
            backgroundImage: (userImage.isNotEmpty)
                ? MemoryImage(base64Decode(userImage))
                : null,
            child: userImage.isEmpty ? const Icon(Icons.person) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildQrView(BuildContext context) {
    var scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 150.0
        : 300.0;

    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
        borderColor: Colors.red,
        borderRadius: 10,
        borderLength: 30,
        borderWidth: 10,
        cutOutSize: scanArea,
      ),
      onPermissionSet: (ctrl, p) => _onPermissionSet(ctrl, p),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });
    controller.scannedDataStream.listen((scanData) async {
      DateTime now = DateTime.now();
      if (lastScanTime == null ||
          now.difference(lastScanTime!) >= const Duration(seconds: 1)) {
        setState(() {
          result = scanData;
          lastScanTime = now;
        });
        if (result?.code != null) {
          await checkIn(result!.code!);
        }
      }
    });
  }

  void _onPermissionSet(QRViewController ctrl, bool hasPermission) {
    log('Permission status: $hasPermission');
    if (!hasPermission) {
      _showSnackBar('Camera permission is required.', isError: true);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}

import 'dart:io';
import 'dart:convert';

import 'package:burtonaletrail_app/AppApi.dart';
import 'package:burtonaletrail_app/Home.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rive/rive.dart';
import 'package:http/http.dart' as http;

class SignInForm extends StatefulWidget {
  const SignInForm({super.key});

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _secureCodeController = TextEditingController();

  bool isShowLoading = false;
  bool isShowConfetti = false;
  bool isSecureCodeVisible = false;
  String buttonText = "Let's Get Started";
  String? firstName;
  String? lastName;
  String? mobileNumber;

  late SMITrigger check;
  late SMITrigger error;
  late SMITrigger reset;
  late SMITrigger confetti;

  StateMachineController getRiveController(Artboard artboard) {
    StateMachineController? controller =
        StateMachineController.fromArtboard(artboard, "State Machine 1");
    artboard.addController(controller!);
    return controller;
  }

  Future<void> signIn(BuildContext context) async {
    if (!isSecureCodeVisible) {
      if (_formKey.currentState!.validate()) {
        setState(() {
          isShowLoading = true;
        });

        _formKey.currentState!.save();
        HttpClient httpClient = HttpClient()
          ..badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
        IOClient ioClient = IOClient(httpClient);

        final response = await ioClient.post(
          Uri.parse(apiServerOTP),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "firstName": firstName,
            "lastName": lastName,
            "mobileNumber": mobileNumber,
          }),
        );

        ioClient.close();

        setState(() {
          isShowLoading = false;
        });

        if (response.statusCode == 200) {
          setState(() {
            isSecureCodeVisible = true;
            buttonText = "Sign In";
            _secureCodeController.clear(); // Clear any old value
          });
        } else {
          error.fire();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid details or mobile number")),
          );
        }
      }
    } else {
      if (_formKey.currentState!.validate()) {
        setState(() {
          isShowLoading = true;
        });

        String secureCode = _secureCodeController.text;

        HttpClient httpClient = HttpClient()
          ..badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
        IOClient ioClient = IOClient(httpClient);

        final response = await ioClient.post(
          Uri.parse(apiServerOTPValidate),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "mobileNumber": mobileNumber,
            "secureCode": secureCode,
          }),
        );

        setState(() {
          isShowLoading = false;
        });

        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(response.body);

          if (jsonResponse['access_token'] != null) {
            final accessToken = jsonResponse['access_token'];
            final refreshToken = jsonResponse['refresh_token'];

            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('access_token', accessToken);
            await prefs.setString('refresh_token', refreshToken);

            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HomeScreen()),
            );

            Future.delayed(const Duration(seconds: 2), () {
              setState(() {
                isShowConfetti = true;
              });
              confetti.fire();
            });
          }
        } else {
          error.fire();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid secure code")),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _secureCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isSecureCodeVisible) ...[
                const Text("Firstname",
                    style: TextStyle(color: Colors.black54)),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 16),
                  child: TextFormField(
                    validator: (value) =>
                        value!.isEmpty ? "Please enter your first name." : null,
                    onSaved: (value) => firstName = value,
                    decoration: const InputDecoration(
                      hintText: "Please enter your first name",
                    ),
                  ),
                ),
                const Text("Surname", style: TextStyle(color: Colors.black54)),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 16),
                  child: TextFormField(
                    validator: (value) =>
                        value!.isEmpty ? "Please enter your last name." : null,
                    onSaved: (value) => lastName = value,
                    decoration: const InputDecoration(
                      hintText: "Please enter your last name",
                    ),
                  ),
                ),
                const Text("Mobile", style: TextStyle(color: Colors.black54)),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 16),
                  child: TextFormField(
                    keyboardType: TextInputType.phone,
                    validator: (value) => value!.isEmpty
                        ? "Please enter your mobile number."
                        : null,
                    onSaved: (value) => mobileNumber = value,
                    decoration: const InputDecoration(
                      hintText: "Please enter your mobile number.",
                    ),
                  ),
                ),
              ],
              if (isSecureCodeVisible) ...[
                const Text("Secure Code",
                    style: TextStyle(color: Colors.black54)),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 16),
                  child: TextFormField(
                    controller: _secureCodeController,
                    keyboardType: TextInputType.number,
                    validator: (value) => value!.isEmpty
                        ? "Please enter your secure code."
                        : null,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: "Please enter your secure code.",
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 24),
                child: ElevatedButton.icon(
                  onPressed: () => signIn(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[850],
                    minimumSize: const Size(double.infinity, 56),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(25),
                        bottomRight: Radius.circular(25),
                        bottomLeft: Radius.circular(25),
                      ),
                    ),
                  ),
                  icon: const Icon(CupertinoIcons.arrow_right,
                      color: Colors.white),
                  label: Text(
                    buttonText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isShowLoading)
          CustomPositioned(
            child: RiveAnimation.asset(
              "assets/RiveAssets/check.riv",
              onInit: (artboard) {
                StateMachineController controller = getRiveController(artboard);
                check = controller.findSMI("Check") as SMITrigger;
                error = controller.findSMI("Error") as SMITrigger;
                reset = controller.findSMI("Reset") as SMITrigger;
              },
            ),
          ),
        if (isShowConfetti)
          CustomPositioned(
            child: Transform.scale(
              scale: 6,
              child: RiveAnimation.asset(
                "assets/RiveAssets/confetti.riv",
                onInit: (artboard) {
                  StateMachineController controller =
                      getRiveController(artboard);
                  confetti =
                      controller.findSMI("Trigger explosion") as SMITrigger;
                },
              ),
            ),
          ),
      ],
    );
  }
}

class CustomPositioned extends StatelessWidget {
  const CustomPositioned({super.key, required this.child, this.size = 100});
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Column(
        children: [
          const Spacer(),
          SizedBox(
            height: size,
            width: size,
            child: child,
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

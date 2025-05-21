import 'dart:ui';

import 'package:burtonaletrail_app/AnimatedButton.dart';
import 'package:burtonaletrail_app/CustomSignIn.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isSignInDialogShown = false;
  late rive.RiveAnimationController _btnAnimationController;

  @override
  void initState() {
    _btnAnimationController = rive.OneShotAnimation("active", autoplay: false);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Optional blur layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 10),
              child: const SizedBox(),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.5,
              child: Image.asset(
                'assets/Backgrounds/Spine.png',
                fit: BoxFit.fill,
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 240),
            top: isSignInDialogShown ? -50 : 0,
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24), // Optional spacing
                    const SizedBox(
                      width: 260,
                      child: Column(
                        children: [
                          Text(
                            "Burton Ale Trail 2025",
                            style: TextStyle(
                              fontSize: 60,
                              fontFamily: "Poppins",
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: 16),
                        ],
                      ),
                    ),
                    Center(
                      child: Image.asset(
                        'assets/images/marvin.png',
                        width: 300,
                        height: 300,
                      ),
                    ),
                    const SizedBox(height: 32),
                    AnimatedBtn(
                      btnAnimationController: _btnAnimationController,
                      press: () {
                        _btnAnimationController.isActive = true;
                        Future.delayed(const Duration(milliseconds: 800), () {
                          setState(() {
                            isSignInDialogShown = true;
                          });
                          customSigninDialog(context, onClosed: (_) {
                            setState(() {
                              isSignInDialogShown = false;
                            });
                          });
                        });
                      },
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Text(""),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

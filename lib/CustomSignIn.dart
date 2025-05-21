import 'package:burtonaletrail_app/SignUpScreen.dart';
import 'package:flutter/material.dart';

Future<Object?> customSigninDialog(BuildContext context,
    {required ValueChanged onClosed}) {
  return showGeneralDialog(
    barrierDismissible: true,
    barrierLabel: "Sign up",
    context: context,
    transitionDuration: const Duration(milliseconds: 400),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      Tween<Offset> tween = Tween(begin: const Offset(0, -1), end: Offset.zero);
      return SlideTransition(
        position: tween.animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
        child: child,
      );
    },
    pageBuilder: (context, _, __) => Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 620),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: const BorderRadius.all(Radius.circular(40)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(
                    bottom: 64), // space for the close button
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      "Sign In",
                      style: TextStyle(fontSize: 34, fontFamily: "Poppins"),
                    ),
                    SizedBox(height: 24),
                    SignInForm(),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: -32,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.close, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ).then(onClosed);
}

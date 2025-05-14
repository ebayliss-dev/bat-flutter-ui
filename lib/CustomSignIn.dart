import 'package:burtonaletrail_app/SignUpScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

Future<Object?> customSigninDialog(BuildContext context,
    {required ValueChanged onClosed}) {
  return showGeneralDialog(
      barrierDismissible: true,
      barrierLabel: "Sign up",
      context: context,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        Tween<Offset> tween =
            Tween(begin: const Offset(0, -1), end: Offset.zero);
        return SlideTransition(
            position: tween.animate(
                CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
            child: child);
      },
      pageBuilder: (context, _, __) => Center(
            child: Container(
              height: 620,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: const BorderRadius.all(Radius.circular(40))),
              child: const Scaffold(
                backgroundColor: Colors.transparent,
                resizeToAvoidBottomInset:
                    false, // avoid overflow error when keyboard shows up
                body: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(children: [
                      Text(
                        "Sign In",
                        style: TextStyle(fontSize: 34, fontFamily: "Poppins"),
                      ),
                      // Padding(
                      //   padding: EdgeInsets.symmetric(vertical: 16),
                      //   child: Text(
                      //     "We will text you a secure code, if you already have an account you will be logged in, if not we will create you a new one.",
                      //     textAlign: TextAlign.center,
                      //   ),
                      // ),
                      SignInForm(),
                      // const Row(
                      //   children: [
                      //     Expanded(
                      //       child: Divider(),
                      //     ),
                      //     Padding(
                      //       padding: EdgeInsets.symmetric(horizontal: 16),
                      //       child: Text(
                      //         "OR",
                      //         style: TextStyle(color: Colors.black26),
                      //       ),
                      //     ),
                      //     Expanded(
                      //       child: Divider(),
                      //     ),
                      //   ],
                      // ),
                      // const Padding(
                      //   padding: EdgeInsets.symmetric(vertical: 20.0),
                      //   child: Text("Sign up with Email, Apple or Google",
                      //       style: TextStyle(color: Colors.black54)),
                      // ),
                      // Row(
                      //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      //   children: [
                      //     IconButton(
                      //         padding: EdgeInsets.zero,
                      //         onPressed: () {},
                      //         icon: SvgPicture.asset(
                      //           "assets/icons/email_box.svg",
                      //           height: 64,
                      //           width: 64,
                      //         )),
                      //     IconButton(
                      //         padding: EdgeInsets.zero,
                      //         onPressed: () {},
                      //         icon: SvgPicture.asset(
                      //           "assets/icons/apple_box.svg",
                      //           height: 64,
                      //           width: 64,
                      //         )),
                      //     IconButton(
                      //         padding: EdgeInsets.zero,
                      //         onPressed: () {},
                      //         icon: SvgPicture.asset(
                      //           "assets/icons/google_box.svg",
                      //           height: 64,
                      //           width: 64,
                      //         ))
                      //   ],
                      // )
                    ]),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: -48,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.close, color: Colors.black),
                      ),
                    )
                  ],
                ),
              ),
            ),
          )).then(onClosed);
}

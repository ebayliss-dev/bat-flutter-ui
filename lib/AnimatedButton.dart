import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

class AnimatedBtn extends StatefulWidget {
  const AnimatedBtn({
    super.key,
    required this.btnAnimationController,
    required this.press,
  });

  final RiveAnimationController btnAnimationController;
  final VoidCallback press;

  @override
  State<AnimatedBtn> createState() => _AnimatedBtnState();
}

class _AnimatedBtnState extends State<AnimatedBtn> {
  bool _isLoading = false;

  void _handleTap() async {
    setState(() => _isLoading = true);

    // Optional: you can trigger your animation controller here if needed
    // widget.btnAnimationController.isActive = true;

    await Future.delayed(const Duration(milliseconds: 800)); // mimic delay
    widget.press();

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: _isLoading ? null : _handleTap,
        child: Container(
          height: 64,
          width: 260,
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2.5,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.arrow_right,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Start now",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

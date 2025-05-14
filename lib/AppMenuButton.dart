// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppMenuButton extends StatelessWidget {
  const AppMenuButton({
    Key? key,
    this.onTap,
  }) : super(key: key);

  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    var height = size.height;

    return InkWell(
      onTap: onTap,
      overlayColor: WidgetStateProperty.all<Color>(Colors.transparent),
      child: Container(
        alignment: Alignment.center,
        height: height * 0.045,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(height * 0.012),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'MENU',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

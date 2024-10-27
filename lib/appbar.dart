import 'package:flutter/material.dart';

class CustomAppBaar extends StatelessWidget {
  const CustomAppBaar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: RichText(
          text: TextSpan(children: [
        TextSpan(
            text: "Weather ",
            style: TextStyle(
                color: Colors.red, fontSize: 20, fontWeight: FontWeight.w600)),
        TextSpan(
            text: "Information",
            style: TextStyle(
                color: Colors.blue, fontSize: 20, fontWeight: FontWeight.w600))
      ])),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:gogdl2_flutter/components/gradient_background.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return GradientBackground(
      child: Center(
        child: Container(
          margin: EdgeInsets.all(size.width * 0.1),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Color.fromARGB(90, 0, 0, 0),
                blurRadius: 45,
                spreadRadius: 20,
              ),
            ],
            border: Border.all(
              color: Color.fromARGB(24, 255, 255, 255),
              width: 0.75,
            ),
            borderRadius: BorderRadius.circular(22.0),
          ),
          child: Row(
            children: [
              Container(
                width: (size.width - (size.width * 0.2) - 2) * 0.45,
                height: (size.height - (size.height * 0.1)),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(22.0),
                    bottomLeft: Radius.circular(22.0),
                  ),
                  border: Border(
                    right: BorderSide(
                      color: Color.fromARGB(24, 255, 255, 255),
                      width: 0.75,
                    ),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.fromARGB(25, 45, 212, 191),
                      Color.fromARGB(34, 42, 35, 80),
                    ],
                  ),
                ),
              ),
              Container(
                width: (size.width - (size.width * 0.2) - 2) * 0.55,
                height: (size.height - (size.height * 0.1)),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(22.0),
                    bottomRight: Radius.circular(22.0),
                  ),
                  color: Colors.deepPurple.withAlpha(8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

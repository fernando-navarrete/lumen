import 'package:flutter/material.dart';
import 'package:gogdl2_flutter/components/gradient_background.dart';
import 'package:gogdl2_flutter/theme/text_styles.dart';

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
                child: SingleChildScrollView(
                  child: Container(
                    padding: EdgeInsets.all(32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "SECURE SIGN-IN",
                          style: AppText.monospace(
                            size: 10.0,
                            weight: FontWeight.w100,
                            color: Color.fromARGB(255, 127, 233, 214),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Connect your account",
                          style: AppText.onest(
                            size: 24.0,
                            weight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Three quick steps. You'll authenticate on GOG, then paste the code it gives you hack here.",
                          style: AppText.onest(
                            size: 12.0,
                            weight: FontWeight.w200,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 32),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(90),
                                color: Color.fromARGB(255, 45, 212, 191),
                              ),
                              child: Icon(
                                Icons.check,
                                color: Colors.black,
                                size: 14,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Open the GOG login page",
                                    style: AppText.onest(
                                      size: 14.0,
                                      weight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "This opens your browser at GOG's official sign-in. Enter your email and password there.",
                                    style: AppText.onest(
                                      size: 12.0,
                                      weight: FontWeight.w200,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  GestureDetector(
                                    onTap: () {},
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Color.fromARGB(
                                          255,
                                          45,
                                          212,
                                          191,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          11.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            offset: Offset(0, 2),
                                            blurRadius: 18,
                                            color: Color.fromRGBO(
                                              45,
                                              212,
                                              191,
                                              0.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20.0,
                                          vertical: 11.0,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          spacing: 4.0,
                                          children: [
                                            Icon(
                                              Icons.open_in_browser,
                                              color: Colors.black,
                                            ),
                                            Text(
                                              "Open GOG login",
                                              style: AppText.onest(
                                                size: 14.0,
                                                weight: FontWeight.w600,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(90),
                                color: Color.fromARGB(255, 45, 212, 191),
                              ),
                              child: Icon(
                                Icons.check,
                                color: Colors.black,
                                size: 14,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Copy the code form the address bar",
                                    style: AppText.onest(
                                      size: 14.0,
                                      weight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text:
                                              "After signing in, GOG redirects to a blank page. Copy everything after ",
                                          style: AppText.onest(
                                            size: 12.0,
                                            weight: FontWeight.w200,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        TextSpan(
                                          text: "code= ",
                                          style: AppText.onest(
                                            size: 12.0,
                                            weight: FontWeight.w200,
                                            color: Color.fromARGB(
                                              255,
                                              45,
                                              212,
                                              191,
                                            ),
                                          ),
                                        ),
                                        TextSpan(
                                          text: "in the URL.",
                                          style: AppText.onest(
                                            size: 12.0,
                                            weight: FontWeight.w200,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 11,
                                      vertical: 13,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha(90),
                                      borderRadius: BorderRadius.circular(10.0),
                                      border: Border.all(
                                        color: Colors.white.withAlpha(30),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "REDIRECT URL LOOKS LIKE THIS:",
                                          style: AppText.monospace(
                                            size: 9.0,
                                            weight: FontWeight.w500,
                                            color: Colors.white.withAlpha(90),
                                          ),
                                        ),
                                        SizedBox(height: 6),
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text:
                                                    ".../on_login_success?origin=client&",
                                                style: AppText.monospace(
                                                  size: 12.0,
                                                  weight: FontWeight.w500,
                                                  color: Colors.white.withAlpha(
                                                    90,
                                                  ),
                                                ),
                                              ),
                                              TextSpan(
                                                text: "code=",
                                                style: AppText.monospace(
                                                  size: 12.0,
                                                  weight: FontWeight.w500,
                                                  color: Color.fromARGB(
                                                    255,
                                                    45,
                                                    212,
                                                    191,
                                                  ),
                                                ),
                                              ),
                                              TextSpan(
                                                text: "M0xY7...",
                                                style: AppText.monospace(
                                                  size: 12.0,
                                                  weight: FontWeight.w500,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(90),
                                color: Color.fromARGB(255, 45, 212, 191),
                              ),
                              child: Icon(
                                Icons.check,
                                color: Colors.black,
                                size: 14,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Paste the code to finish",
                                    style: AppText.onest(
                                      size: 14.0,
                                      weight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "Lumen exchanges it for your access tokens. Nothing leaves your machine but the code.",
                                    style: AppText.onest(
                                      size: 12.0,
                                      weight: FontWeight.w200,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    spacing: 12,
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 11.0,
                                            vertical: 13.0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withAlpha(90),
                                            borderRadius: BorderRadius.circular(
                                              10.0,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withAlpha(30),
                                              width: 1.2,
                                            ),
                                          ),
                                          child: RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: "code=",
                                                  style: AppText.monospace(
                                                    size: 12.0,
                                                    weight: FontWeight.w500,
                                                    color: Colors.white
                                                        .withAlpha(90),
                                                  ),
                                                ),
                                                TextSpan(
                                                  text:
                                                      " paste authorization code",
                                                  style: AppText.monospace(
                                                    size: 12.0,
                                                    weight: FontWeight.w500,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {},
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Color.fromARGB(
                                              255,
                                              45,
                                              212,
                                              191,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              11.0,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                offset: Offset(0, 2),
                                                blurRadius: 18,
                                                color: Color.fromRGBO(
                                                  45,
                                                  212,
                                                  191,
                                                  0.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20.0,
                                              vertical: 11.0,
                                            ),
                                            child: Text(
                                              "Sign in",
                                              style: AppText.onest(
                                                size: 14.0,
                                                weight: FontWeight.w600,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Imports so everything works
import 'package:flutter/material.dart';

import 'Screens/home_screen.dart';

void main() {
  runApp(const YTMDCompanion());
}

class YTMDCompanion extends StatelessWidget {
  const YTMDCompanion({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Xenon's YTMD Companion App",
      home: HomeScreenLayout(),
    );
  }
}

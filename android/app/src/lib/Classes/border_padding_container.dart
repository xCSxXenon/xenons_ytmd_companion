import 'package:flutter/cupertino.dart';

import '../app_globals.dart' as globals;

class BorderPaddingContainer extends Container {
  BorderPaddingContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: globals.borderPadding,
    );
  }
}

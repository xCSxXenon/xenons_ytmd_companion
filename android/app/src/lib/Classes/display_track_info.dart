import 'package:flutter/material.dart';

import '../app_globals.dart' as app_globals;
import '../state_globals.dart' as state_globals;

class DisplayArtistAlbum extends StatefulWidget {
  const DisplayArtistAlbum({super.key});

  @override
  State<DisplayArtistAlbum> createState() => _DisplayArtistAlbum();
}

class _DisplayArtistAlbum extends State<DisplayArtistAlbum> {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: app_globals.borderPadding,
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
                style: TextStyle(
                  fontSize: 20,
                  color: app_globals.defaultIconColor,
                ),
                "${state_globals.currentArtist} ${state_globals.currentAlbum == "null" ? "" : "  -   ${state_globals.currentAlbum}"}"),
          ),
        ),
        Container(
          width: app_globals.borderPadding,
        )
      ],
    );
  }
}

class DisplayTitle extends StatefulWidget {
  const DisplayTitle({super.key});

  @override
  State<DisplayTitle> createState() => _DisplayTitle();
}

class _DisplayTitle extends State<DisplayTitle> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: app_globals.borderPadding,
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: app_globals.defaultIconColor,
              ),
              state_globals.currentTitle,
            ),
          ),
        ),
        Container(
          width: app_globals.borderPadding,
        )
      ],
    );
  }
}

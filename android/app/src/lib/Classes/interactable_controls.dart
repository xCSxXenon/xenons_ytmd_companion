import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_globals.dart' as app_globals;
import '../state_globals.dart' as state_globals;
import 'volume_bar.dart';

class DislikeLikeMute extends StatefulWidget {
  const DislikeLikeMute({super.key});

  @override
  State<DislikeLikeMute> createState() => _DislikeLikeMuteState();
}

class _DislikeLikeMuteState extends State<DislikeLikeMute> {
  Future<void> toggleDislike() async {
    Map<String, String> data = {
      "command": "toggleDislike",
    };

    var request = http.Request('POST', app_globals.commandURL);
    request.headers.addAll(app_globals.headers);
    request.body = jsonEncode(data);
    var streamedResponse = await request.send();
  }

  Future<void> toggleLike() async {
    Map<String, String> data = {
      "command": "toggleLike",
    };

    var request = http.Request('POST', app_globals.commandURL);
    request.headers.addAll(app_globals.headers);
    request.body = jsonEncode(data);
    var streamedResponse = await request.send().timeout(const Duration(seconds: 1), onTimeout: () => throw Exception("Timeout"));
  }

  Future<void> toggleMute() async {
    Map<String, String> data = {
      "command": state_globals.muted == true ? "unmute" : "mute",
    };

    var request = http.Request('POST', app_globals.commandURL);
    request.headers.addAll(app_globals.headers);
    request.body = jsonEncode(data);
    var streamedResponse = await request.send();

    state_globals.muted = !state_globals.muted;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: app_globals.borderPadding + 15,
        ),
        IconButton(
          onPressed: () => toggleDislike(),
          icon: Icon(
            state_globals.likeStatus == 0 ? Icons.thumb_down_alt : Icons.thumb_down_off_alt,
            color: state_globals.likeStatus == 0 ? app_globals.activatedColor : app_globals.defaultIconColor,
          ),
        ),
        IconButton(
          onPressed: () => toggleLike(),
          icon: Icon(
            state_globals.likeStatus == 2 ? Icons.thumb_up_alt : Icons.thumb_up_off_alt,
            color: state_globals.likeStatus == 2 ? app_globals.activatedColor : app_globals.defaultIconColor,
          ),
        ),
        Container(
          width: 30,
        ),
        IconButton(
          onPressed: () => toggleMute(),
          icon: Icon(
            state_globals.muted == true ? Icons.volume_off : Icons.volume_up,
            color: app_globals.defaultIconColor,
          ),
        ),
        Expanded(
          child: VolumeBar(),
        ),
        Container(
          width: app_globals.borderPadding + 15,
        ),
      ],
    );
  }
}

class MediaContolButtons extends StatefulWidget {
  const MediaContolButtons({super.key});

  @override
  State<MediaContolButtons> createState() => _MediaContol();
}

class _MediaContol extends State<MediaContolButtons> {
  Future<void> toggleShuffle() async {
    Map<String, String> data = {
      "command": "shuffle",
    };

    var request = http.Request('POST', app_globals.commandURL);
    request.headers.addAll(app_globals.headers);
    request.body = jsonEncode(data);
    var streamedResponse = await request.send();
  }

  Future<void> goToPrevious() async {
    Map<String, String> data = {
      "command": "previous",
    };

    var request = http.Request('POST', app_globals.commandURL);
    request.headers.addAll(app_globals.headers);
    request.body = jsonEncode(data);
    var streamedResponse = await request.send();
  }

  Future<void> playPause() async {
    Map<String, String> data = {
      "command": "playPause",
    };

    var request = http.Request('POST', app_globals.commandURL);
    request.headers.addAll(app_globals.headers);
    request.body = jsonEncode(data);
    var streamedResponse = await request.send().timeout(const Duration(seconds: 1), onTimeout: () => throw Exception("Timeout"));
  }

  SnackBar displaySnackBar(String text) {
    return SnackBar(content: Text(text));
  }

  Future<void> goToNext() async {
    Map<String, String> data = {
      "command": "next",
    };

    var request = http.Request('POST', app_globals.commandURL);
    request.headers.addAll(app_globals.headers);
    request.body = jsonEncode(data);
    var streamedResponse = await request.send();
  }

  Future<void> toggleRepeat() async {
    Map<String, String> data = {
      "command": "repeatMode",
      "data": (state_globals.repeat == 0
              ? 1
              : state_globals.repeat == 1
                  ? 2
                  : 0)
          .toString(),
    };

    var request = http.Request('POST', app_globals.commandURL);
    request.headers.addAll(app_globals.headers);
    request.body = jsonEncode(data);
    var streamedResponse = await request.send();

    setState(() {
      state_globals.repeat = (state_globals.repeat == 0
          ? 1
          : state_globals.repeat == 1
              ? 2
              : 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 25,
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                padding: EdgeInsetsGeometry.zero,
                iconSize: 36,
                icon: Icon(
                  Icons.shuffle,
                  color: state_globals.shuffle ? app_globals.activatedColor : app_globals.defaultIconColor,
                ),
                onPressed: toggleShuffle,
              ),
              IconButton(
                padding: EdgeInsetsGeometry.zero,
                iconSize: 36,
                icon: Icon(
                  Icons.skip_previous,
                  color: app_globals.defaultIconColor,
                ),
                onPressed: goToPrevious,
              ),
              IconButton(
                padding: EdgeInsetsGeometry.zero,
                iconSize: 48,
                icon: Icon(
                  state_globals.isPlaying ? Icons.pause_circle : Icons.play_circle_fill,
                  color: app_globals.defaultIconColor,
                  size: 100,
                ),
                onPressed: playPause,
              ),
              IconButton(
                padding: EdgeInsetsGeometry.zero,
                iconSize: 36,
                icon: Icon(
                  Icons.skip_next,
                  color: app_globals.defaultIconColor,
                ),
                onPressed: goToNext,
              ),
              IconButton(
                padding: EdgeInsetsGeometry.zero,
                iconSize: 36,
                icon: Icon(
                  state_globals.repeat == 2 ? Icons.repeat_one : Icons.repeat,
                  color: state_globals.repeat == 0 ? app_globals.defaultIconColor : app_globals.activatedColor,
                ),
                onPressed: toggleRepeat,
              ),
            ],
          ),
        ),
        Container(
          width: 25,
        ),
      ],
    );
  }
}

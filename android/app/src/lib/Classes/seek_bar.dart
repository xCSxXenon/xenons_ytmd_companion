import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_globals.dart' as globals;
import '../app_globals.dart' as app_globals;
import '../state_globals.dart' as state_globals;

class SeekBar extends StatefulWidget {
  const SeekBar({super.key});

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  Future<void> seekTo(double seekToSecond) async {
    Map<String, dynamic> data = {
      "command": "seekTo",
      "data": seekToSecond,
    };

    var request = http.Request('POST', globals.commandURL);
    request.headers.addAll(globals.headers);
    request.body = jsonEncode(data);
    var streamedResponse = await request.send();
  }

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
          padding: EdgeInsetsGeometry.all(0),
          activeTrackColor: globals.defaultIconColor,
          inactiveTrackColor: globals.sliderInactiveTrackColor,
          thumbColor: Colors.red[800],
          overlayColor: Colors.transparent,
          thumbShape: state_globals.videoProgress > state_globals.durationSeconds ? SliderComponentShape.noThumb : RoundSliderThumbShape()),
      child: Slider(
        value: state_globals.videoProgress > state_globals.durationSeconds ? 0.0 : state_globals.videoProgress,
        min: 0.0,
        max: state_globals.durationSeconds,
        onChanged: (newValue) {
          setState(() {
            state_globals.isSeeking = true;
            state_globals.videoProgress = newValue;
          });
        },
        onChangeEnd: (newValue) {
          setState(() {
            seekTo(newValue);
            Future.delayed(Duration(milliseconds: 500), () => state_globals.isSeeking = false);
          });
        },
      ),
    );
  }
}

class DisplayProgress extends StatefulWidget {
  const DisplayProgress({super.key});

  @override
  State<DisplayProgress> createState() => _DisplayProgressState();
}

class _DisplayProgressState extends State<DisplayProgress> {
  String formatTime(int timeInSeconds) {
    var localDurationSeconds = Duration(seconds: timeInSeconds);
    var durationHours = localDurationSeconds.inHours;
    var durationMinutes = localDurationSeconds.inMinutes - (durationHours * 60);
    var durationSeconds = localDurationSeconds.inSeconds - (durationMinutes * 60 + durationHours * 3600);
    localDurationSeconds = Duration(seconds: localDurationSeconds.inSeconds - (localDurationSeconds.inMinutes * 60));
    return "${durationHours == 0 ? "" : "$durationHours:"}${durationMinutes == 0 ? (durationHours == 0 ? "0:" : "${durationMinutes.toString().padLeft(2, "0")}:") : (durationHours == 0 ? "$durationMinutes:" : "${durationMinutes.toString().padLeft(2, "0")}:")}${durationSeconds.toString().padLeft(2, "0")}";
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      style: TextStyle(
        fontSize: 20,
        color: globals.defaultIconColor,
      ),
      formatTime(state_globals.videoProgress.toInt()),
    );
  }
}

class DisplayDuration extends StatefulWidget {
  const DisplayDuration({super.key});

  @override
  State<DisplayDuration> createState() => _DisplayDurationState();
}

class _DisplayDurationState extends State<DisplayDuration> {
  String formatTime(int timeInSeconds) {
    var localDurationSeconds = Duration(seconds: timeInSeconds);
    var durationHours = localDurationSeconds.inHours;
    var durationMinutes = localDurationSeconds.inMinutes - (durationHours * 60);
    var durationSeconds = localDurationSeconds.inSeconds - (durationMinutes * 60 + durationHours * 3600);
    localDurationSeconds = Duration(seconds: localDurationSeconds.inSeconds - (localDurationSeconds.inMinutes * 60));
    return "${durationHours == 0 ? "" : "$durationHours:"}${durationMinutes == 0 ? (durationHours == 0 ? "0:" : "${durationMinutes.toString().padLeft(2, "0")}:") : (durationHours == 0 ? "$durationMinutes:" : "${durationMinutes.toString().padLeft(2, "0")}:")}${durationSeconds.toString().padLeft(2, "0")}";
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      style: TextStyle(
        fontSize: 20,
        color: app_globals.defaultIconColor,
      ),
      formatTime(state_globals.durationSeconds.toInt()),
    );
  }
}

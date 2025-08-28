import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../Classes/border_padding_container.dart';
import '../Classes/display_thumbnail.dart';
import '../Classes/display_track_info.dart';
import '../Classes/interactable_controls.dart';
import '../Classes/seek_bar.dart';
import '../app_globals.dart' as app_globals;
import '../state_globals.dart' as state_globals;

class HomeScreenLayout extends StatelessWidget {
  const HomeScreenLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: app_globals.backGroundColor,
      body: const Center(
        child: HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    checkStoredSettings();
  }

  void configureWebsocket() {
    var stateSocket = io.io(app_globals.realtimeURL, io.OptionBuilder().setTransports(['websocket']).setAuth({"token": app_globals.token}).build());
    stateSocket.on(
      "state-update",
      (data) => setState(
        () {
          updateStateGlobals(data);
        },
      ),
    );
  }

  Future<void> checkStoredSettings() async {
    var checkServerIP = await sharedPreferences("get", "serverIP");
    if (checkServerIP == null) return;
    var checkToken = await sharedPreferences("get", "token");
    if (checkToken == null) return;
    app_globals.updateServerIP(checkServerIP);
    app_globals.updateToken(checkToken);
    _hostController.text = app_globals.serverIP;
    // If YTMD is opened for the first time but nothing is played, it reports that it is playing.
    // Accordingly, the companion app will show this accurately. Since the app can only send the
    // play command if the current state is "paused", it is locked up.
    // TODO Fix this? maybe? workaround?
    // TODO change SnackBars to kill any current SnackBar
    getInitialState();
  }

  Future<String?> sharedPreferences(String action, String key, [String? value]) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    switch (action) {
      case "set":
        await prefs.setString(key, value!);
      case "get":
        var retrievedValue = prefs.getString(key);
        return retrievedValue;
      case "remove":
        prefs.remove(key);
    }
    return null;
  }

  Future<void> getInitialState() async {
    var request = http.Request('GET', app_globals.stateURL);
    request.headers.addAll(app_globals.headers);

    http.Response? status;

    try {
      var streamedResponse = await request.send().timeout(Duration(seconds: 1));
      status = await http.Response.fromStream(streamedResponse);
    } on TimeoutException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Color.fromRGBO(50, 0, 0, 1.0),
            content: Center(
              child: Text(
                "Saved IP \"${app_globals.serverIP}\"didn't respond!\nIs the server powered on and running YTMD?",
                style: TextStyle(
                  fontSize: 18,
                  color: app_globals.defaultIconColor,
                ),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Color.fromRGBO(50, 0, 0, 1.0),
            content: Center(
              child: Text(
                "Unhandled exception!",
                style: TextStyle(
                  fontSize: 18,
                  color: app_globals.defaultIconColor,
                ),
              ),
            ),
          ),
        );
      }
    }

    if (status?.reasonPhrase == "Unauthorized") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Color.fromRGBO(50, 0, 0, 1.0),
          content: Center(
            child: Text(
              "Connected to server but unauthorized.\nReauthenticate in settings.",
              style: TextStyle(
                fontSize: 18,
                color: app_globals.defaultIconColor,
              ),
            ),
          ),
        ),
      );
      return;
    }
    var data = jsonDecode(status!.body) as Map<String, dynamic>;
    setState(() => updateStateGlobals(data));
    configureWebsocket();
  }

  void updateStateGlobals(Map<String, dynamic> data) {
    setState(
      () {
        if (data["player"]["trackState"] == 0) {
          state_globals.isPlaying = false;
        } else {
          state_globals.isPlaying = true;
        }
        state_globals.currentThumbnailURL = data["video"]["thumbnails"][data["video"]["thumbnails"].length - 1]["url"];
        state_globals.currentTitle = data["video"]["title"];
        state_globals.currentArtist = data["video"]["author"];
        state_globals.currentAlbum = data["video"]["album"] ?? "null";
        if (state_globals.isSeeking == false) {
          state_globals.videoProgress = data["player"]["videoProgress"].toDouble();
        }
        state_globals.durationSeconds = data["video"]["durationSeconds"].toDouble();
        state_globals.repeat = data["player"]["queue"]["repeatMode"];
        state_globals.likeStatus = data["video"]["likeStatus"];
        if (state_globals.isRequestingVolume == false) {
          state_globals.volume = data["player"]["volume"];
        }
      },
    );
  }

  Future<void> getClientAndServerIP([BuildContext? localContext]) async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    app_globals.clientIP = interfaces.firstWhere((element) => element.name == "wlan0").addresses.first.address;
    if (localContext!.mounted) {
      getServerIP(app_globals.clientIP, localContext);
    }
  }

  Future<void> getServerIP(String clientIP, [BuildContext? localContext]) async {
    state_globals.isSearchingForServerIP = true;
    bool serverIP = await getServerIPLoop(clientIP, 1, 255, localContext);
    state_globals.isSearchingForServerIP = false;

    if (serverIP == false) {
      if (localContext!.mounted) {
        ScaffoldMessenger.of(localContext).showSnackBar(
          SnackBar(
            backgroundColor: Color.fromRGBO(50, 0, 0, 1.0),
            content: Center(
              child: Text(
                "Server not found",
                style: TextStyle(
                  fontSize: 18,
                  color: app_globals.defaultIconColor,
                ),
              ),
            ),
          ),
        );
      }
    }
    if (serverIP == true) {
      setState(
        () {
          _hostController.text = app_globals.serverIP;
          ScaffoldMessenger.of(localContext!).showSnackBar(
            SnackBar(
              backgroundColor: Color.fromRGBO(0, 50, 0, 1.0),
              content: Center(
                child: Text(
                  "Server found!",
                  style: TextStyle(
                    fontSize: 18,
                    color: app_globals.defaultIconColor,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
  }

  Future<bool> getServerIPLoop(String clientIP, int min, int max, [BuildContext? localContext]) async {
    var clientIPChunks = clientIP.split(".");
    bool serverFound = false;
    int count = min;
    int loopCount = 1;
    int maxLoops = 3;
    int loopDelay = 50;
    if (localContext!.mounted) {
      ScaffoldMessenger.of(localContext).showSnackBar(
        SnackBar(
          backgroundColor: Color.fromRGBO(0, 50, 0, 1.0),
          content: Center(
            child: Text(
              "Searching...(Attempt $loopCount out of $maxLoops)",
              style: TextStyle(
                fontSize: 18,
                color: app_globals.defaultIconColor,
              ),
            ),
          ),
        ),
      );
    }
    while (serverFound == false && count <= max) {
      try {
        var testServerIP = '${clientIPChunks[0]}.${clientIPChunks[1]}.${clientIPChunks[2]}.$count';
        var request = http.Request('GET', Uri.parse('http://$testServerIP:${app_globals.port}/metadata'));
        var streamedResponse = await request.send().timeout(Duration(milliseconds: loopDelay));
        var status = await http.Response.fromStream(streamedResponse);
        var data = jsonDecode(status.body) as Map<String, dynamic>;
        if (data["apiVersions"][data["apiVersions"].length - 1] == "v1") {
          serverFound = true;
          setState(() {
            app_globals.updateServerIP(testServerIP);
          });
          return serverFound;
        }
      } catch (e) {}
      if (count >= max && loopCount < maxLoops) {
        count = min;
        loopDelay += 25;
        loopCount++;
        if (localContext.mounted) {
          ScaffoldMessenger.of(localContext).showSnackBar(
            SnackBar(
              backgroundColor: Color.fromRGBO(0, 50, 0, 1.0),
              content: Center(
                child: Text(
                  "Searching...(Attempt $loopCount out of $maxLoops)",
                  style: TextStyle(
                    fontSize: 18,
                    color: app_globals.defaultIconColor,
                  ),
                ),
              ),
            ),
          );
        }
      } else if (count >= max && loopCount >= maxLoops) {
        return false;
      }
      count++;
    }
    return false;
  }

  Future<void> connectAndAuthorize(BuildContext localContext) async {
    if (app_globals.serverIP == "") {
      ScaffoldMessenger.of(localContext).showSnackBar(
        SnackBar(
          content: Text("No server IP specified!"),
          // behavior: SnackBarBehavior.floating, // Optional: makes it float
        ),
      );
      return;
    }

    Map<String, String> requestAuthHeaders = {
      'content-type': 'application/json',
    };

    //Requesting auth code
    Map<String, String> requestCodeData = {
      "appId": app_globals.appId,
      "appName": app_globals.appName,
      "appVersion": app_globals.appVersion,
    };

    http.Response? requestCodeResponse;
    var requestCode = http.Request('POST', app_globals.requestCodeURL);
    requestCode.headers.addAll(requestAuthHeaders);
    requestCode.body = jsonEncode(requestCodeData);
    try {
      var requestCodeResponseStream = await requestCode.send();
      requestCodeResponse = await http.Response.fromStream(requestCodeResponseStream);
    } on SocketException {
      if (localContext.mounted) {
        ScaffoldMessenger.of(localContext).showSnackBar(
          SnackBar(
            backgroundColor: Color.fromRGBO(50, 0, 0, 1.0),
            content: Center(
              child: Text(
                "Cannot connect to IP!",
                style: TextStyle(
                  fontSize: 18,
                  color: app_globals.defaultIconColor,
                ),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (localContext.mounted) {
        ScaffoldMessenger.of(localContext).showSnackBar(
          SnackBar(
            backgroundColor: Color.fromRGBO(50, 0, 0, 1.0),
            content: Center(
              child: Text(
                "Unhandled exception!",
                style: TextStyle(
                  fontSize: 18,
                  color: app_globals.defaultIconColor,
                ),
              ),
            ),
          ),
        );
      }
    }

    if (requestCodeResponse?.reasonPhrase == "Forbidden") {
      if (localContext.mounted) {
        ScaffoldMessenger.of(localContext).showSnackBar(
          SnackBar(
            backgroundColor: Color.fromRGBO(50, 0, 0, 1.0),
            content: Center(
              child: Text(
                "Server found but not accepting requests!",
                style: TextStyle(
                  fontSize: 18,
                  color: app_globals.defaultIconColor,
                ),
              ),
            ),
          ),
        );
      }
      return;
    }

    Navigator.of(context).pop();
    //Got auth code
    var authCode = (jsonDecode(requestCodeResponse!.body) as Map<String, dynamic>)["code"];
    await showAuthenticationCode(authCode);

    //Request API token
    Map<String, String> requestTokenData = {
      "appId": app_globals.appId,
      "code": authCode,
    };

    var requestToken = http.Request('POST', app_globals.requestTokenURL);
    requestToken.headers.addAll(requestAuthHeaders);
    requestToken.body = jsonEncode(requestTokenData);
    if (localContext.mounted) {
      ScaffoldMessenger.of(localContext).showSnackBar(
        SnackBar(
          backgroundColor: Color.fromRGBO(0, 50, 0, 1.0),
          content: Center(
            child: Text(
              "Request sent! Check computer for authorization!",
              style: TextStyle(
                fontSize: 18,
                color: app_globals.defaultIconColor,
              ),
            ),
          ),
        ),
      );
    }

    var requestTokenResponseStream = await requestToken.send();
    var requestTokenResponse = await http.Response.fromStream(requestTokenResponseStream);

    if (requestTokenResponse.reasonPhrase == "Forbidden") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Color.fromRGBO(50, 0, 0, 1.0),
          content: Center(
            child: Text(
              "Request denied!",
              style: TextStyle(
                fontSize: 18,
                color: app_globals.defaultIconColor,
              ),
            ),
          ),
        ),
      );
      Navigator.of(context).pop();
      showSettingsBox();

      return;
    }

    Navigator.of(context).pop();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Color.fromRGBO(0, 50, 0, 1.0),
          content: Center(
            child: Text(
              "Successfully connected!",
              style: TextStyle(
                fontSize: 18,
                color: app_globals.defaultIconColor,
              ),
            ),
          ),
        ),
      );
    }

    //Got API token, store it and server IP
    String token = (jsonDecode(requestTokenResponse.body) as Map<String, dynamic>)["token"];
    app_globals.updateToken(token);
    sharedPreferences("set", "serverIP", app_globals.serverIP);
    sharedPreferences("set", "token", app_globals.token);
    getInitialState();
  }

  void deleteSettings(BuildContext localContext) async {
    await sharedPreferences("remove", "serverIP");
    await sharedPreferences("remove", "token");
    if (localContext.mounted) {
      ScaffoldMessenger.of(localContext).showSnackBar(
        SnackBar(
          content: Text("Settings cleared!"),
          // behavior: SnackBarBehavior.floating, // Optional: makes it float
        ),
      );
    }
  }

  Future<void> showSettingsBox() async {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false, // Make the route transparent to see the blur
        pageBuilder: (BuildContext showSettingsBoxContext, _, __) {
          return Scaffold(
            backgroundColor: Colors.transparent, // Transparent background for the Scaffold
            body: Center(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 5.0,
                  sigmaY: 5.0,
                ),
                child: AlertDialog(
                  backgroundColor: Color.fromRGBO(10, 10, 10, 1.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadiusGeometry.circular(25),
                    side: BorderSide(color: app_globals.sliderInactiveTrackColor, width: 2),
                  ),
                  title: Row(
                    children: [
                      Text("Settings"),
                      Expanded(child: Container()),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close,
                          size: 36,
                          color: app_globals.defaultIconColor,
                        ),
                      ),
                    ],
                  ),
                  titleTextStyle: TextStyle(
                    color: app_globals.defaultIconColor,
                    fontSize: 36,
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _hostController,
                        onEditingComplete: () {
                          app_globals.updateServerIP(_hostController.text);
                          FocusManager.instance.primaryFocus?.unfocus();
                        },
                        style: TextStyle(color: app_globals.defaultIconColor),
                        decoration: InputDecoration(
                          labelStyle: TextStyle(color: app_globals.defaultIconColor),
                          labelText: "Server IP address (desktop running YTMD)",
                        ),
                        keyboardType: TextInputType.url,
                        autofillHints: const [AutofillHints.url],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              style: IconButton.styleFrom(backgroundColor: app_globals.sliderInactiveTrackColor),
                              onPressed: () => (
                                _hostController.text = "",
                                getClientAndServerIP(showSettingsBoxContext),
                              ),
                              icon: Icon(
                                Icons.youtube_searched_for,
                                color: app_globals.defaultIconColor,
                              ),
                              label: Text(
                                'Search for server',
                                style: TextStyle(color: app_globals.defaultIconColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            style: IconButton.styleFrom(backgroundColor: app_globals.sliderInactiveTrackColor),
                            onPressed: () => connectAndAuthorize(showSettingsBoxContext),
                            icon: Icon(
                              Icons.link,
                              color: app_globals.defaultIconColor,
                            ),
                            label: Text(
                              "Connect",
                              style: TextStyle(color: app_globals.defaultIconColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> showAuthenticationCode(String authCode) async {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false, // Make the route transparent to see the blur
        pageBuilder: (BuildContext showAuthenticationCodeContext, _, __) {
          return Scaffold(
            backgroundColor: Colors.transparent, // Transparent background for the Scaffold
            body: Center(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 5.0,
                  sigmaY: 5.0,
                ),
                child: AlertDialog(
                  backgroundColor: Color.fromRGBO(10, 10, 10, 1.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadiusGeometry.circular(25),
                    side: BorderSide(color: app_globals.sliderInactiveTrackColor, width: 2),
                  ),
                  title: Center(child: Text("Please ensure the code below matches what YTMD is showing.")),
                  titleTextStyle: TextStyle(
                    color: app_globals.defaultIconColor,
                    fontSize: 24,
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        authCode,
                        style: TextStyle(
                          color: Colors.red[800],
                          fontSize: 42,
                        ),
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              style: IconButton.styleFrom(backgroundColor: app_globals.sliderInactiveTrackColor),
                              onPressed: () => Navigator.of(context).pop(),
                              label: Text(
                                "Close",
                                style: TextStyle(
                                  color: app_globals.defaultIconColor,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  final _hostController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 125,
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.settings,
                size: 36,
              ),
              onPressed: () => showSettingsBox(),
              tooltip: 'Settings',
            ),
            BorderPaddingContainer(),
          ],
        ),
        ThumbnailImage(),
        Container(height: 40),
        DisplayTitle(),
        DisplayArtistAlbum(),
        Container(height: 25),
        Row(
          children: [
            BorderPaddingContainer(),
            Expanded(
              child: SeekBar(),
            ),
            BorderPaddingContainer()
          ],
        ),
        Container(height: 5),
        Row(
          children: [
            BorderPaddingContainer(),
            DisplayProgress(),
            Expanded(child: Container()),
            DisplayDuration(),
            BorderPaddingContainer(),
          ],
        ),
        Container(height: 25),
        DislikeLikeMute(),
        Container(height: 25),
        MediaContolButtons(),
      ],
    );
  }
}

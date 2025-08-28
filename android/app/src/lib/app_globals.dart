library;

import 'package:flutter/material.dart';

//App details
String appId = "xenons_ytmd_companion";
String appName = "Xenon's YTMD Companion";
String appVersion = "1.0.0";

//Variables for client<->server communication
String token = "";
Map<String, String> headers = {
  'Authorization': token,
  'content-type': 'application/json',
};
String serverIP = "";
String clientIP = "";
String port = "9863";
Uri apiVersionURL = Uri.parse('http://$serverIP:$port/metadata');
Uri commandURL = Uri.parse('http://$serverIP:$port/api/v1/command');
Uri stateURL = Uri.parse('http://$serverIP:$port/api/v1/state');
Uri requestCodeURL = Uri.parse('http://$serverIP:$port/api/v1/auth/requestcode');
Uri requestTokenURL = Uri.parse('http://$serverIP:$port/api/v1/auth/request');
String realtimeURL = 'http://$serverIP:$port/api/v1/realtime';

//Colors
Color defaultIconColor = Color.fromRGBO(150, 150, 150, 1);
Color sliderInactiveTrackColor = Color.fromRGBO(50, 50, 50, 1);
Color activatedColor = Color.fromRGBO(255, 255, 255, 1);
Color backGroundColor = Color.fromRGBO(0, 0, 0, 1.0);

//Spacing, Padding, Borders
double borderPadding = 25;

void updateServerIP(String requestedServerIP) {
  serverIP = requestedServerIP;
  apiVersionURL = Uri.parse('http://$requestedServerIP:$port/metadata');
  commandURL = Uri.parse('http://$requestedServerIP:$port/api/v1/command');
  stateURL = Uri.parse('http://$requestedServerIP:$port/api/v1/state');
  realtimeURL = 'http://$requestedServerIP:$port/api/v1/realtime';
  requestCodeURL = Uri.parse('http://$requestedServerIP:$port/api/v1/auth/requestcode');
  requestTokenURL = Uri.parse('http://$requestedServerIP:$port/api/v1/auth/request');
}

void updateToken(String requestedToken) {
  token = requestedToken;
  headers["Authorization"] = requestedToken;
}

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/io.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'dart:math';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نقشه و چت زنده',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LocationChatPage(),
    );
  }
}

class LocationChatPage extends StatefulWidget {
  const LocationChatPage({super.key});

  @override
  State<LocationChatPage> createState() => _LocationChatPageState();
}

class _LocationChatPageState extends State<LocationChatPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _msgController = TextEditingController();
  IOWebSocketChannel? channel;
  String? myName;
  Color? myColor;
  List<String> messages = [];
  Map<String, LatLng> userLocations = {};
  Map<String, Color> userColors = {};
  List<String> onlineUsers = [];

  Future<void> _startApp() async {
    myName = _nameController.text.trim();
    if (myName!.isEmpty) return;

    // انتخاب رنگ تصادفی برای هر کاربر
    myColor = Colors.primaries[Random().nextInt(Colors.primaries.length)];

    channel = IOWebSocketChannel.connect("ws://178.63.171.244:5000");

    channel!.stream.listen((event) {
      final data = jsonDecode(event);

      if (data["type"] == "chat") {
        setState(() {
          messages.add("${data['name']}: ${data['message']}");
        });
      }

      if (data["type"] == "location") {
        setState(() {
          userLocations[data["name"]] = LatLng(data["lat"], data["lon"]);
          userColors[data["name"]] =
              Color(int.parse(data["color"].toString())); // رنگ اختصاصی
          onlineUsers = List<String>.from(data["onlineUsers"]);
        });
      }

      if (data["type"] == "offline") {
        setState(() {
          userLocations.remove(data["name"]);
          userColors.remove(data["name"]);
          onlineUsers = List<String>.from(data["onlineUsers"]);
        });
      }
    });

    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position pos) {
      final data = {
        "type": "location",
        "name": myName,
        "lat": pos.latitude,
        "lon": pos.longitude,
        "color": myColor!.value, // ارسال رنگ اختصاصی
      };
      channel!.sink.add(jsonEncode(data));
    });
  }

  void _sendMessage() {
    if (_msgController.text.trim().isEmpty) return;
    final data = {
      "type": "chat",
      "name": myName ?? "ناشناس",
      "message": _msgController.text.trim(),
    };
    channel!.sink.add(jsonEncode(data));
    _msgController.clear();
  }

  @override
  void dispose() {
    channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("نقشه و چت زنده")),
      body: Column(
        children: [
          if (myName == null) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "نام خود را وارد کنید",
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _startApp,
              child: const Text("شروع"),
            ),
          ] else ...[
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: FlutterMap(
                      options: MapOptions(
                        center: LatLng(32.0, 53.0),
                        zoom: 6,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                        ),
                        MarkerLayer(
                          markers: userLocations.entries.map((entry) {
                            final color =
                                userColors[entry.key] ?? Colors.red;
                            return Marker(
                              width: 40,
                              height: 40,
                              point: entry.value,
                              builder: (ctx) => Icon(
                                Icons.location_on,
                                color: color,
                                size: 30,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        Text("کاربران آنلاین",
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: ListView.builder(
                            itemCount: onlineUsers.length,
                            itemBuilder: (context, index) {
                              final name = onlineUsers[index];
                              final color =
                                  userColors[name] ?? Colors.grey;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: color,
                                  child: Text(name[0]),
                                ),
                                title: Text(name),
                              );
                            },
                          ),
                        ),
                        const Divider(),
                        Expanded(
                          child: ListView.builder(
                            itemCount: messages.length,
                            itemBuilder: (context, index) =>
                                ListTile(title: Text(messages[index])),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _msgController,
                                  decoration: const InputDecoration(
                                    hintText: "پیام خود را بنویسید...",
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.send),
                                onPressed: _sendMessage,
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
          ]
        ],
      ),
    );
  }
}

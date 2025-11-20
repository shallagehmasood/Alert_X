import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'چت مکان‌محور',
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
  List<String> messages = [];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _startApp() async {
    myName = _nameController.text.trim();
    if (myName!.isEmpty) return;

    channel = IOWebSocketChannel.connect("ws://178.63.171.244:5000");

    channel!.stream.listen((event) {
      final data = jsonDecode(event);
      if (data["type"] == "chat") {
        setState(() {
          messages.add("${data['name']}: ${data['message']}");
        });
      }
    });

    // گرفتن اجازه موقعیت
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
      appBar: AppBar(title: const Text("چت مکان‌محور")),
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
              child: ListView.builder(
                itemCount: messages.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text(messages[index]),
                ),
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
          ]
        ],
      ),
    );
  }
}

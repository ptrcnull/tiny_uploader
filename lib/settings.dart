import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class SettingsData {
  const SettingsData({required this.server, required this.token});
  final String server;
  final String token;
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  late TextEditingController _serverController;
  late TextEditingController _tokenController;

  @override
  void initState() {
    super.initState();
    _serverController = TextEditingController();
    _tokenController = TextEditingController();
  }

  Future<SettingsData> getData() async {
    final SharedPreferences prefs = await _prefs;
    return SettingsData(
      server: prefs.getString("server") ?? "",
      token: prefs.getString("token") ?? "",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: FutureBuilder(
        future: getData(),
        builder: (context, snapshot) {
          List<Widget> children;
          if (snapshot.hasData) {
            _serverController.text = snapshot.data!.server;
            _tokenController.text = snapshot.data!.token;
            children = [
              TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Server',
                ),
                controller: _serverController,
              ),
              const SizedBox(height: 10),
              TextField(
                obscureText: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Token',
                ),
                controller: _tokenController,
              )
            ];
          } else if (snapshot.hasError) {
            children = [Text("error: ${snapshot.error.toString()}")];
          } else {
            children = [const Text("Loading...")];
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: children,
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _prefs.then((prefs) {
            prefs.setString("server", _serverController.text);
            prefs.setString("token", _tokenController.text);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Saved!")),
            );
          });
        },
        tooltip: 'Save',
        child: const Icon(Icons.save),
      ),
    );
  }
}

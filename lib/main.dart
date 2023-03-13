import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:http/http.dart' as http;

import 'package:tiny_uploader/settings.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'tiny uploader',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const MyHomePage(title: 'tiny uploader 🥺'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class SharedMediaThumbnail extends StatelessWidget {
  const SharedMediaThumbnail(this.file, {super.key, required this.onClick});

  final SharedMediaFile file;
  final VoidCallback onClick;

  @override
  Widget build(BuildContext context) {
    Widget thumbnail = const Icon(Icons.file_copy, size: 128.0);
    if (file.type == SharedMediaType.IMAGE) {
      thumbnail = Image.file(
        File(file.path),
        width: 128,
        height: 128,
        fit: BoxFit.cover,
      );
    }

    if (file.type == SharedMediaType.VIDEO && file.thumbnail != null) {
      thumbnail = Image.file(
        File(file.thumbnail!),
        width: 128,
        height: 128,
        fit: BoxFit.cover,
      );
    }

    String filename = file.path.split("/").last;

    return InkWell(
      onTap: onClick,
      child: Column(children: [
        thumbnail,
        const SizedBox(height: 10),
        Text(filename),
      ]),
    );
  }
}

class _MyHomePageState extends State<MyHomePage> {
  late StreamSubscription _intentDataStreamSubscription;
  List<SharedMediaFile>? _sharedFiles;
  String? _sharedText;
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  bool buttonLocked = false;

  @override
  void initState() {
    super.initState();
    _intentDataStreamSubscription = ReceiveSharingIntent.getMediaStream()
        .listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        setState(() {
          _sharedFiles = value;
          print("Hot shared files:" +
              (_sharedFiles?.map((f) => f.path).join(",") ?? ""));
        });
      }
    }, onError: (err) {
      print("getIntentDataStream error: $err");
    });

    // For sharing images coming from outside the app while the app is closed
    ReceiveSharingIntent.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        setState(() {
          _sharedFiles = value;
          print("Cold shared files:" +
              (_sharedFiles?.map((f) => f.path).join(",") ?? ""));
        });
      }
    });

    // For sharing or opening urls/text coming from outside the app while the app is in the memory
    _intentDataStreamSubscription =
        ReceiveSharingIntent.getTextStream().listen((String value) {
      if (value.isNotEmpty) {
        setState(() {
          _sharedText = value;
          print("Hot shared text: $_sharedText");
        });
      }
    }, onError: (err) {
      print("getLinkStream error: $err");
    });

    // For sharing or opening urls/text coming from outside the app while the app is closed
    ReceiveSharingIntent.getInitialText().then((String? value) {
      if (value != null) {
        setState(() {
          _sharedText = value;
          print("Cold shared text: $_sharedText");
        });
      }
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  Future<String> upload() async {
    print("uploading...");
    setState(() {
      buttonLocked = true;
    });
    SharedPreferences prefs = await _prefs;
    String? server = prefs.getString("server");
    String? token = prefs.getString("token");
    if (server == null || server == "") {
      throw Exception("Server not set");
    }
    if (token == null || token == "") {
      throw Exception("Token not set");
    }

    Uint8List content = Uint8List(0);
    if (_sharedFiles != null && _sharedFiles!.isNotEmpty) {
      if (_sharedFiles!.length > 1) {
        throw Exception("Cannot upload multiple files");
      }
      content = await File(_sharedFiles![0].path).readAsBytes();
    } else if (_sharedText != null) {
      content = Uint8List.fromList(_sharedText!.codeUnits);
    } else {
      throw Exception("Nothing to upload");
    }

    if (content.isEmpty) {
      throw Exception("Cannot upload empty file");
    }

    http.Response res = await http.post(
      Uri.parse(server),
      headers: {'Authorization': token},
      body: content,
    );
    if (res.statusCode != 200 || res.headers['content-type'] == "text/html") {
      throw Exception("Invalid token");
    }
    print(res.headers);

    return res.body.trim();
  }

  List<Widget> getElements() {
    if (_sharedFiles != null && _sharedFiles!.isNotEmpty) {
      return _sharedFiles!
          .map((file) => SharedMediaThumbnail(file, onClick: () {
                setState(() {
                  _sharedFiles!.remove(file);
                });
              }))
          .toList();
    } else if (_sharedText != null) {
      return [Text("Shared text:\n${_sharedText!}")];
    } else {
      return [const Text("no content to share :3")];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: getElements(),
        ),
      ),
      floatingActionButton: !buttonLocked
          ? FloatingActionButton(
              onPressed: () {
                upload().then((url) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 30),
                      content: Text("Uploaded as $url"),
                      action: SnackBarAction(
                        label: 'Copy',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                            text: url,
                          ));
                        },
                      ),
                    ),
                  );
                }).catchError((error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error: ${error.toString()}"),
                    ),
                  );
                }).whenComplete(() {
                  setState(() {
                    buttonLocked = false;
                  });
                });
              },
              tooltip: 'Upload',
              child: const Icon(Icons.send),
            )
          : FloatingActionButton(
              onPressed: () {},
              tooltip: 'Upload',
              backgroundColor: Colors.grey,
              child: const Icon(Icons.send),
            ),
    );
  }
}

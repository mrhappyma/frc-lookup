import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:frc_lookup/util/settings.dart';
import 'package:frc_lookup/util/team.dart';
import 'package:frc_lookup/screens/settings.dart';
import 'package:frc_lookup/screens/team_download.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => Settings(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
      return MaterialApp(
        home: const MainView(),
        theme: lightDynamic != null
            ? ThemeData.from(colorScheme: lightDynamic)
            : ThemeData.light(),
        darkTheme: darkDynamic != null
            ? ThemeData.from(colorScheme: darkDynamic)
            : ThemeData.dark(),
      );
    }
    );
  }
}

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  Team? _team;
  bool _imageVisible = false;
  String _imagePath = "";
  late TeamProvider teamProvider;
  late Directory directory;
  late Settings settings;

  @override
  void initState() {
    teamProvider = TeamProvider();
    teamProvider.open('frclu.db');
    directory = Directory.systemTemp;
    settings = Provider.of<Settings>(context, listen: false);

    super.initState();
    _initImageDirectory();
    _setup();
  }

  _initImageDirectory() async {
    directory = await getApplicationSupportDirectory();
  }

  _setup() async {
    await settings.loadPreferences();
    if (!settings.setupDone) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DownloadTeamsScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('FRC Lookup'),
          actions: [
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const DownloadTeamsScreen()),
                );
              },
            ),
            IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SettingsScreen()),
                  );
                },
                icon: const Icon(Icons.settings))
          ],
        ),
        body: Column(
          children: [
            Center(
              child: IntrinsicWidth(
                child: TextFormField(
                  onChanged: (value) => updateTeam(value),
                  decoration:
                      const InputDecoration(hintText: "#", counterText: ""),
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLines: 1,
                  maxLength: 5,
                  style: const TextStyle(
                    fontSize: 50,
                  ),
                ),
              ),
            ),
            _team != null
                ? Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Text(
                          _team!.nickname,
                          style: const TextStyle(fontSize: 24),
                        ),
                        Text(_team!.city ?? ""),
                        Text(_team!.rookieYear?.toString() ?? ""),
                        _imageVisible
                            ? Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Image.file(File(_imagePath)),
                              )
                            : Container()
                      ],
                    ),
                  )
                : Container()
          ],
        ));
  }

  Future<Team?> updateTeam(String value) async {
    if (value.isEmpty) {
      setState(() {
        _team = null;
        _imageVisible = false;
      });
      return null;
    }
    Team? team = await teamProvider.getTeam(int.parse(value));
    setState(() {
      _team = team;
    });

    String path = '${directory.path}/frc$value-${settings.photoYear}';
    if (await File("$path.png").exists()) {
      setState(() {
        _imagePath = "$path.png";
        _imageVisible = true;
      });
    } else if (await File("$path.jpg").exists()) {
      setState(() {
        _imagePath = "$path.jpg";
        _imageVisible = true;
      });
    } else {
      setState(() {
        _imageVisible = false;
      });
    }

    return team;
  }
}

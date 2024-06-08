import 'package:flutter/material.dart';
import 'package:frc_lookup/util/settings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SharedPreferences prefs;

  Future<void> _loadSettings() async {
    prefs = await SharedPreferences.getInstance();
    return;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body:
          Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        FutureBuilder<void>(
            future: _loadSettings(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              return Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      title: const Text('Download Photos'),
                      trailing: DropdownButton<PhotoDownloadSetting>(
                        value: Provider.of<Settings>(context).downloadPhotos,
                        items: PhotoDownloadSetting.values
                            .map((e) => DropdownMenuItem<PhotoDownloadSetting>(
                                  value: e,
                                  child: Text(e.toString().split('.').last),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            Provider.of<Settings>(context, listen: false)
                                .setDownloadPhotos(value);
                          }
                        },
                      ),
                    ),
                    ListTile(
                      title: const Text('Photo Year'),
                      trailing: DropdownButton<int>(
                        value: Provider.of<Settings>(context).photoYear,
                        items: List<int>.generate(35, (i) => 2024 - i)
                            .map((e) => DropdownMenuItem<int>(
                                  value: e,
                                  child: Text(e.toString()),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            Provider.of<Settings>(context, listen: false)
                                .setPhotoYear(value);
                          }
                        },
                      ),
                    ),
                    Visibility(
                      visible: Provider.of<Settings>(context).downloadPhotos ==
                          PhotoDownloadSetting.comps,
                      child: Column(
                        children: [
                          const ListTile(
                            title: Text(
                                'Photo Competitions - space seperated event codes'),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextFormField(
                              initialValue: Provider.of<Settings>(context)
                                  .photoComps
                                  .join(' '),
                              onChanged: (value) {
                                Provider.of<Settings>(context, listen: false)
                                    .setPhotoComps(value
                                        .split(' ')
                                        .map((e) => e.trim())
                                        .toList());
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('powered by '),
                InkWell(
                    child: const Text('The Blue Alliance',
                        style: TextStyle(color: Colors.blue)),
                    onTap: () => launchUrl(
                        Uri.parse('https://thebluealliance.com/'),
                        mode: LaunchMode.inAppBrowserView)),
                const Text(' - open source on '),
                InkWell(
                    child: const Text('GitHub',
                        style: TextStyle(color: Colors.blue)),
                    onTap: () => launchUrl(
                        Uri.parse('https://github.com/mrhappyma/frc-lookup'),
                        mode: LaunchMode.inAppBrowserView)),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:frc_lookup/util/settings.dart';
import 'package:frc_lookup/util/team.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class DownloadTeamsScreen extends StatefulWidget {
  const DownloadTeamsScreen({super.key});

  @override
  State<DownloadTeamsScreen> createState() => _DownloadTeamsScreenState();
}

class _DownloadTeamsScreenState extends State<DownloadTeamsScreen> {
  String _downloadStatus = 'downloading data...';
  double? _downloadProgress;

  @override
  void initState() {
    super.initState();
    downloadData();
  }

  Future<void> downloadData() async {
    TeamProvider teamProvider = TeamProvider();
    await teamProvider.open('frclu.db');

    const tbaToken =
        "flbmZznlhOGjL2YNKK18b84Amc7TkvnzONJ7rgYUj7QBiIrcswHgauoxNnKUZAqe";
    const tbaBaseUrl = "https://www.thebluealliance.com/api/v3";
    const backendBaseUrl = "https://frc-lookup-api.userexe.me";

    setState(() {
      _downloadStatus = "downloading teams";
    });
    var teamsResponse = await http.get(Uri.parse('$backendBaseUrl/teams'));
    if (teamsResponse.statusCode != 200) {
      setState(() {
        _downloadProgress = 0;
        _downloadStatus =
            "Failed to download teams - ${teamsResponse.statusCode}";
      });
      return;
    }
    var teamsBody = (jsonDecode(teamsResponse.body) as List)
        .map((item) => Team.fromJson(item))
        .toList();
    await teamProvider.insertMany(teamsBody);

    Settings settings = Provider.of<Settings>(context, listen: false);
    await settings.setSetupDone(true);
    await settings.loadPreferences();

    if (settings.downloadPhotos != PhotoDownloadSetting.none) {
      setState(() {
        _downloadProgress = null;
        _downloadStatus = "downloading robot photos";
      });
      List<Team> teams = await teamProvider.getAllTeams();

      if (settings.downloadPhotos == PhotoDownloadSetting.comps) {
        List<int> allCompTeams = [];
        for (String comp in settings.photoComps) {
          var compResponse = await http.get(
              Uri.parse('$tbaBaseUrl/event/$comp/teams/simple'),
              headers: {"X-TBA-Auth-Key": tbaToken});
          if (compResponse.statusCode == 200) {
            var compBody = jsonDecode(compResponse.body);
            List<Map<String, dynamic>> compTeamsData =
                List<Map<String, dynamic>>.from(compBody);
            List<int> compTeams =
                compTeamsData.map((e) => e["team_number"]).cast<int>().toList();
            allCompTeams.addAll(compTeams);
          } else {
            setState(() {
              _downloadProgress = 0;
              _downloadStatus =
                  "Failed to download teams at $comp - ${compResponse.statusCode}";
            });
            return;
          }
        }
        teams = teams
            .where((element) => allCompTeams.contains(element.number))
            .toList();
      }

      Directory directory = await getApplicationSupportDirectory();
      var photoUrlsResponse = await http
          .get(Uri.parse('$backendBaseUrl/photos/${settings.photoYear}'));
      if (photoUrlsResponse.statusCode != 200) {
        setState(() {
          _downloadProgress = 0;
          _downloadStatus =
              "Failed to download photo urls - ${photoUrlsResponse.statusCode}";
        });
        return;
      }
      var photoUrlsBody = (jsonDecode(photoUrlsResponse.body) as List)
          .map((item) => TeamPhotoUrl.fromJson(item))
          .toList();

      Future<void> downloadTeamPhoto(Team team, Directory directory) async {
        if (await File(
                    '${directory.path}/frc${team.number}-${settings.photoYear}.jpg')
                .exists() ||
            await File(
                    '${directory.path}/frc${team.number}-${settings.photoYear}.png')
                .exists()) {
          return;
        }

        late String preferredPhotoUrl;
        try {
          preferredPhotoUrl = photoUrlsBody
              .firstWhere((element) => element.teamNumber == team.number)
              .url;
        } catch (e) {
          return;
        }
        String path =
            '${directory.path}/frc${team.number}-${settings.photoYear}.${preferredPhotoUrl.split('.').last}';

        if (await File(path).exists()) {
          return;
        }
        var photoResponse = await http.get(Uri.parse(preferredPhotoUrl));
        if (photoResponse.statusCode == 200) {
          File file = File(path);
          await file.writeAsBytes(photoResponse.bodyBytes);
        } else {
          setState(() {
            _downloadProgress = 0;
            _downloadStatus =
                "Failed to download photo for team ${team.number} - ${photoResponse.statusCode}";
          });
          throw Exception(
              "Failed to download photo for team ${team.number} - ${photoResponse.statusCode}");
        }
      }

      for (int i = 0; i < teams.length; i += 10) {
        int end = ((i + 10) < (teams.length - 1)) ? i + 10 : (teams.length - 1);
        setState(() {
          _downloadProgress = i / teams.length;
          _downloadStatus =
              "downloading robot photos ${teams[i].number} to ${teams[end].number}";
        });
        List<Future<void>> futures = [];
        futures.addAll(teams
            .sublist(i, end)
            .map((team) => downloadTeamPhoto(team, directory)));
        await Future.wait(futures);
      }
    }

    setState(() {
      _downloadProgress = 1;
      _downloadStatus = "Download complete!";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Download Data'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _downloadProgress == 1
                  ? const Text("🎉")
                  : CircularProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 20),
              Text(_downloadStatus),
            ],
          ),
        ));
  }
}

class TeamPhotoUrl {
  final int teamNumber;
  final String url;

  TeamPhotoUrl(this.teamNumber, this.url);

  factory TeamPhotoUrl.fromJson(Map<String, dynamic> json) {
    return TeamPhotoUrl(
      json['teamNumber'],
      json['url'],
    );
  }
}

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
  String _downloadStatus = 'Downloading teams...';
  double? _downloadProgress;

  @override
  void initState() {
    super.initState();
    downloadTeams();
  }

  Future<void> downloadTeams() async {
    setState(() {
      _downloadStatus = "downloading teams";
    });
    TeamProvider teamProvider = TeamProvider();
    await teamProvider.open('frclu.db');

    const token =
        "flbmZznlhOGjL2YNKK18b84Amc7TkvnzONJ7rgYUj7QBiIrcswHgauoxNnKUZAqe";
    const baseUrl = "https://www.thebluealliance.com/api/v3";

    for (int i = 0; i < 20; i += 1) {
      setState(() {
        _downloadStatus =
            "downloading teams ${(((i - 1) / 2) * 1000).toInt()} to ${((i / 2) * 1000).toInt()}";
      });
      var response = await http.get(Uri.parse("$baseUrl/teams/$i"),
          headers: {"X-TBA-Auth-Key": token});
      if (response.statusCode == 200) {
        var body = jsonDecode(response.body);
        List<Map<String, dynamic>> teamsData =
            List<Map<String, dynamic>>.from(body);
        List<Team> teams = teamsData
            .map((e) => Team(e["team_number"], e["nickname"],
                "${e['city']}, ${e['state_prov']}", e["rookie_year"]))
            .toList();
        await teamProvider.insertMany(teams);
        setState(() {
          _downloadProgress = i / 20;
        });
      } else {
        setState(() {
          _downloadProgress = 0;
          _downloadStatus = "Failed to download teams - ${response.statusCode}";
        });
        return;
      }
    }

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
              Uri.parse('$baseUrl/event/$comp/teams/simple'),
              headers: {"X-TBA-Auth-Key": token});
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
      Future<void> downloadTeamPhoto(Team team, Directory directory) async {
        if (await File(
                    '${directory.path}/frc${team.number}-${settings.photoYear}.png')
                .exists() ||
            await File(
                    '${directory.path}/frc${team.number}-${settings.photoYear}.jpg')
                .exists()) {
          return;
        }
        var mediaResponse = await http.get(
            Uri.parse(
                '$baseUrl/team/frc${team.number}/media/${settings.photoYear}'),
            headers: {"X-TBA-Auth-Key": token});
        if (mediaResponse.statusCode == 200) {
          var mediaBody = jsonDecode(mediaResponse.body);
          List<Map<String, dynamic>> mediaData =
              List<Map<String, dynamic>>.from(mediaBody);
          if (mediaData.isEmpty) {
            return;
          }
          String preferredPhotoUrl;
          try {
            preferredPhotoUrl = mediaData.firstWhere((element) =>
                element["preferred"] == true &&
                element["direct_url"]
                    .toString()
                    .startsWith('http'))["direct_url"];
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
          title: const Text('Download Teams'),
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

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PhotoDownloadSetting { none, comps, all }

class Settings extends ChangeNotifier {
  PhotoDownloadSetting _downloadPhotos = PhotoDownloadSetting.none;
  List<String> _photoComps = [];
  int _photoYear = 2024;
  bool _setupDone = false;

  Settings() {
    loadPreferences();
  }

  PhotoDownloadSetting get downloadPhotos => _downloadPhotos;
  int get photoYear => _photoYear;
  List<String> get photoComps => _photoComps;
  bool get setupDone => _setupDone;

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _downloadPhotos = PhotoDownloadSetting
        .values[prefs.getInt('settings.downloadPhotos') ?? 0];
    _photoYear = prefs.getInt('settings.photoYear') ?? 2024;
    _photoComps = prefs.getStringList('settings.photoComps') ?? [];
    _setupDone = prefs.getBool('status.setupDone') ?? false;
    notifyListeners();
  }

  Future<void> setDownloadPhotos(PhotoDownloadSetting value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('settings.downloadPhotos', value.index);
    _downloadPhotos = value;
    notifyListeners();
  }

  Future<void> setPhotoYear(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('settings.photoYear', value);
    _photoYear = value;
    notifyListeners();
  }

  Future<void> setPhotoComps(List<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('settings.photoComps', value);
    _photoComps = value;
    notifyListeners();
  }

  Future<void> setSetupDone(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('status.setupDone', value);
    _setupDone = value;
    notifyListeners();
  }
}

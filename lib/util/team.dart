import 'package:sqflite/sqflite.dart';

const String tableTeam = 'team';
const String columnNumber = 'number';
const String columnNickname = 'nickname';
const String columnCity = 'city';
const String columnRookieYear = 'rookie_year';

class Team {
  final int number;
  final String nickname;
  final String? city;
  final int? rookieYear;

  Map<String, Object?> toMap() {
    var map = <String, Object?>{
      columnNumber: number,
      columnNickname: nickname,
      columnCity: city,
      columnRookieYear: rookieYear,
    };
    return map;
  }

  Team(this.number, this.nickname, this.city, this.rookieYear);

  Team.fromMap(Map<String, Object?> map)
      : number = map[columnNumber] as int,
        nickname = map[columnNickname] as String,
        city = map[columnCity] as String?,
        rookieYear = map[columnRookieYear] as int?;

  factory Team.fromJson(item) {
    return Team(
        item['number'], item['nickname'], item['city'], item['rookieYear']);
  }
}

class TeamProvider {
  late Database db;

  Future open(String path) async {
    db = await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
      await db.execute('''
create table $tableTeam ( 
  $columnNumber integer primary key, 
  $columnNickname text not null,
  $columnCity text,
  $columnRookieYear integer)
''');
    });
  }

  Future<Team> insert(Team team) async {
    await db.insert(tableTeam, team.toMap());
    return team;
  }

  Future<List<Team>> insertMany(List<Team> teams) async {
    await db.transaction((txn) async {
      var batch = txn.batch();
      for (var team in teams) {
        batch.insert(tableTeam, team.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
    return teams;
  }

  Future<Team?> getTeam(int id) async {
    List<Map> maps = await db.query(tableTeam,
        columns: [columnNumber, columnNickname, columnCity, columnRookieYear],
        where: '$columnNumber = ?',
        whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Team.fromMap(maps.first as Map<String, Object?>);
    }
    return null;
  }

  Future<List<Team>> getAllTeams() async {
    List<Map> maps = await db.query(tableTeam,
        columns: [columnNumber, columnNickname, columnCity, columnRookieYear]);
    return maps.map((e) => Team.fromMap(e as Map<String, Object?>)).toList();
  }

  Future close() async => db.close();
}

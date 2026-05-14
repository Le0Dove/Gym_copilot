import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/exercise.dart';
import '../models/workout_record.dart';
import '../data/exercise_data.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static List<Exercise> _webExercises = [];
  static final List<WorkoutRecord> _webRecords = [];
  static int _webIdCounter = 1;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (kIsWeb) {
      return _WebDatabase();
    }
    if (_database != null) return _database!;
    _database = await _initDB('gym_copilot.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);

      return await openDatabase(
        path,
        version: 7,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      );
    } catch (e) {
      debugPrint('数据库初始化失败: $e');
      rethrow;
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        tag TEXT NOT NULL,
        isBuiltIn INTEGER NOT NULL DEFAULT 0,
        targetMuscles TEXT DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE exercise_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exerciseId INTEGER NOT NULL UNIQUE,
        exerciseName TEXT NOT NULL,
        useCount INTEGER NOT NULL DEFAULT 0,
        lastUsedDate TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dateTime TEXT NOT NULL,
        bodyPart TEXT NOT NULL,
        durationMinutes INTEGER NOT NULL,
        fatigueLevel INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE exercise_sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recordId INTEGER NOT NULL,
        exerciseId INTEGER NOT NULL,
        exerciseName TEXT NOT NULL,
        exerciseTag TEXT NOT NULL,
        weight REAL NOT NULL,
        reps INTEGER NOT NULL,
        setNumber INTEGER NOT NULL,
        isTemplate INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (recordId) REFERENCES workout_records (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_in_progress (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        startTime TEXT NOT NULL,
        bodyPart TEXT,
        fatigueLevel INTEGER NOT NULL DEFAULT 5,
        setsJson TEXT NOT NULL DEFAULT '[]'
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        daysPerWeek INTEGER NOT NULL,
        workoutDays TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        bodyPart TEXT NOT NULL,
        exercisesJson TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE user_body_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        weight REAL,
        height REAL,
        bodyFat REAL,
        muscleMass REAL,
        recordDate TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    final builtInExercises = ExerciseData.getBuiltInExercises();
    for (var exercise in builtInExercises) {
      await db.insert('exercises', exercise.toMap());
    }

    if (version >= 2) {
      // 版本2: 添加 exercise_usage 表
      // 旧版本没有数据，这是新功能
    }
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // 版本3: 添加 lastUsedDate 列到 exercise_usage 表
      await db
          .execute('ALTER TABLE exercise_usage ADD COLUMN lastUsedDate TEXT');
    }
    if (oldVersion < 4) {
      // 版本4: 添加 workout_in_progress 和 workout_templates 表
      await db.execute('''
        CREATE TABLE workout_in_progress (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          startTime TEXT NOT NULL,
          bodyPart TEXT,
          fatigueLevel INTEGER NOT NULL DEFAULT 5,
          setsJson TEXT NOT NULL DEFAULT '[]'
        )
      ''');
      await db.execute('''
        CREATE TABLE workout_templates (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          bodyPart TEXT NOT NULL,
          exercisesJson TEXT NOT NULL,
          createdAt TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      // 版本5: 添加 user_body_data 表
      await db.execute('''
        CREATE TABLE user_body_data (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          weight REAL,
          height REAL,
          bodyFat REAL,
          muscleMass REAL,
          recordDate TEXT NOT NULL,
          createdAt TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 6) {
      // 版本6: 添加 targetMuscles 列到 exercises 表
      await db.execute(
          'ALTER TABLE exercises ADD COLUMN targetMuscles TEXT DEFAULT \'\'');
    }
    if (oldVersion < 7) {
      // 版本7: 添加 isTemplate 列到 exercise_sets 表
      await db.execute(
          'ALTER TABLE exercise_sets ADD COLUMN isTemplate INTEGER NOT NULL DEFAULT 0');
    }
  }

  Future<List<Exercise>> getExercises() async {
    if (kIsWeb) {
      if (_webExercises.isEmpty) {
        _webExercises = ExerciseData.getBuiltInExercises();
      }
      return _webExercises;
    }
    final db = await database;
    final result = await db.query('exercises', orderBy: 'tag ASC, name ASC');
    return result.map((map) => Exercise.fromMap(map)).toList();
  }

  Future<List<Exercise>> getExercisesByTag(String tag) async {
    final exercises = await getExercises();
    return exercises.where((e) => e.tag == tag).toList();
  }

  Future<int> insertExercise(Exercise exercise) async {
    if (kIsWeb) {
      exercise.id = _webIdCounter++;
      _webExercises.add(exercise);
      return exercise.id!;
    }
    final db = await database;
    return await db.insert('exercises', exercise.toMap());
  }

  Future<int> deleteExercise(int id) async {
    if (kIsWeb) {
      _webExercises.removeWhere((e) => e.id == id && !e.isBuiltIn);
      return 1;
    }
    final db = await database;
    return await db.delete(
      'exercises',
      where: 'id = ? AND isBuiltIn = 0',
      whereArgs: [id],
    );
  }

  Future<int> insertWorkoutRecord(WorkoutRecord record) async {
    if (kIsWeb) {
      record.id = _webIdCounter++;
      _webRecords.insert(0, record);
      return record.id!;
    }
    try {
      final db = await database;
      return await db.transaction((txn) async {
        debugPrint('插入训练记录: ${record.toMap()}');
        final recordId = await txn.insert('workout_records', record.toMap());
        debugPrint('训练记录插入成功，ID=$recordId');
        for (var set in record.exerciseSets) {
          set.recordId = recordId;
          debugPrint('插入动作组: ${set.toMap()}');
          await txn.insert('exercise_sets', set.toMap());
          await _updateExerciseUsage(
              txn, set.exerciseId, set.exerciseName, record.dateTime);
        }
        return recordId;
      });
    } catch (e, stackTrace) {
      debugPrint('保存训练记录失败: $e');
      debugPrint('堆栈跟踪: $stackTrace');
      rethrow;
    }
  }

  Future<void> _updateExerciseUsage(DatabaseExecutor dbOrTxn, int exerciseId,
      String exerciseName, DateTime dateTime) async {
    final existing = await dbOrTxn.query(
      'exercise_usage',
      where: 'exerciseId = ?',
      whereArgs: [exerciseId],
    );
    final dateStr = dateTime.toIso8601String().split('T')[0];
    if (existing.isEmpty) {
      await dbOrTxn.insert('exercise_usage', {
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'useCount': 1,
        'lastUsedDate': dateStr,
      });
    } else {
      final currentCount = existing.first['useCount'] as int;
      await dbOrTxn.update(
        'exercise_usage',
        {
          'useCount': currentCount + 1,
          'lastUsedDate': dateStr,
        },
        where: 'exerciseId = ?',
        whereArgs: [exerciseId],
      );
    }
  }

  Future<List<Map<String, dynamic>>> getExerciseUsageStats() async {
    if (kIsWeb) return [];
    final db = await database;
    return await db.query(
      'exercise_usage',
      orderBy: 'useCount DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getExerciseHistory(int exerciseId) async {
    if (kIsWeb) return [];
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        wr.dateTime,
        es.weight,
        es.reps,
        es.setNumber,
        wr.fatigueLevel
      FROM exercise_sets es
      INNER JOIN workout_records wr ON es.recordId = wr.id
      WHERE es.exerciseId = ?
      ORDER BY wr.dateTime DESC, es.setNumber ASC
    ''', [exerciseId]);
  }

  Future<List<WorkoutRecord>> getWorkoutRecords() async {
    if (kIsWeb) {
      return _webRecords;
    }
    try {
      final db = await database;
      final result = await db.query(
        'workout_records',
        orderBy: 'dateTime DESC',
      );
      debugPrint('查询到 ${result.length} 条训练记录');
      List<WorkoutRecord> records = [];
      for (var map in result) {
        try {
          final record = WorkoutRecord.fromMap(map);
          debugPrint('处理记录 ID=${record.id}, 时间=${record.dateTime}, 部位=${record.bodyPart}');
          if (record.id != null) {
            record.exerciseSets = await getExerciseSetsByRecordId(record.id!);
            debugPrint('记录 ID=${record.id} 有 ${record.exerciseSets.length} 个动作组');
          }
          records.add(record);
        } catch (e) {
          debugPrint('处理单条记录时出错: $e');
        }
      }
      return records;
    } catch (e, stackTrace) {
      debugPrint('查询训练记录失败: $e');
      debugPrint('堆栈跟踪: $stackTrace');
      rethrow;
    }
  }

  Future<List<ExerciseSet>> getExerciseSetsByRecordId(int recordId) async {
    if (kIsWeb) {
      final record = _webRecords.firstWhere(
        (r) => r.id == recordId,
        orElse: () => WorkoutRecord(
          dateTime: DateTime.now(),
          bodyPart: '',
          durationMinutes: 0,
          fatigueLevel: 0,
        ),
      );
      return record.exerciseSets;
    }
    final db = await database;
    final result = await db.query(
      'exercise_sets',
      where: 'recordId = ?',
      whereArgs: [recordId],
      orderBy: 'setNumber ASC',
    );
    return result.map((map) => ExerciseSet.fromMap(map)).toList();
  }

  Future<WorkoutRecord?> getLatestWorkoutRecord() async {
    if (kIsWeb) {
      return _webRecords.isNotEmpty ? _webRecords.first : null;
    }
    final db = await database;
    final result = await db.query(
      'workout_records',
      orderBy: 'dateTime DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      final record = WorkoutRecord.fromMap(result.first);
      record.exerciseSets = await getExerciseSetsByRecordId(record.id!);
      return record;
    }
    return null;
  }

  // ===== Streak 功能 =====

  /// 获取所有训练日期的唯一列表（按日期去重，仅含日期部分）
  Future<List<DateTime>> getUniqueWorkoutDates() async {
    if (kIsWeb) {
      final dates = _webRecords
          .map((r) => DateTime(r.dateTime.year, r.dateTime.month, r.dateTime.day))
          .toSet()
          .toList();
      dates.sort((a, b) => b.compareTo(a));
      return dates;
    }
    final db = await database;
    final result = await db.rawQuery('''
      SELECT DISTINCT 
        substr(dateTime, 1, 10) as dateStr
      FROM workout_records
      ORDER BY dateStr DESC
    ''');
    return result
        .map((row) => DateTime.parse(row['dateStr'] as String))
        .toList();
  }

  /// 计算当前连续训练天数（Streak）
  Future<int> getCurrentStreak() async {
    final dates = await getUniqueWorkoutDates();
    if (dates.isEmpty) return 0;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));

    // 检查今天或昨天是否有训练
    bool hasToday = dates.any((d) => d.isAtSameMomentAs(todayDate));
    bool hasYesterday = dates.any((d) => d.isAtSameMomentAs(yesterdayDate));

    if (!hasToday && !hasYesterday) {
      // 今天和昨天都没训练，streak 已断
      return 0;
    }

    int streak = 0;
    DateTime checkDate = hasToday ? todayDate : yesterdayDate;

    for (final date in dates) {
      if (date.isAtSameMomentAs(checkDate)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (date.isBefore(checkDate)) {
        break;
      }
    }

    return streak;
  }

  /// 获取最长连续训练天数记录
  Future<int> getLongestStreak() async {
    final dates = await getUniqueWorkoutDates();
    if (dates.isEmpty) return 0;

    // 按升序排列以便计算
    dates.sort((a, b) => a.compareTo(b));

    int maxStreak = 1;
    int currentStreak = 1;

    for (int i = 1; i < dates.length; i++) {
      final diff = dates[i].difference(dates[i - 1]).inDays;
      if (diff == 1) {
        currentStreak++;
        if (currentStreak > maxStreak) {
          maxStreak = currentStreak;
        }
      } else if (diff > 1) {
        currentStreak = 1;
      }
    }

    return maxStreak;
  }

  /// 检查是否已经断签（超过1天没有训练）
  Future<bool> isStreakBroken() async {
    final dates = await getUniqueWorkoutDates();
    if (dates.isEmpty) return false;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));

    bool hasToday = dates.any((d) => d.isAtSameMomentAs(todayDate));
    bool hasYesterday = dates.any((d) => d.isAtSameMomentAs(yesterdayDate));

    return !hasToday && !hasYesterday;
  }

  /// 获取断签天数
  Future<int> getDaysSinceLastWorkout() async {
    final dates = await getUniqueWorkoutDates();
    if (dates.isEmpty) return -1;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final latestDate = dates.first;

    return todayDate.difference(latestDate).inDays;
  }

  /// 获取某个月的训练日期列表（用于热力图）
  Future<List<DateTime>> getWorkoutDatesInMonth(int year, int month) async {
    if (kIsWeb) {
      return _webRecords
          .where((r) => r.dateTime.year == year && r.dateTime.month == month)
          .map((r) => DateTime(r.dateTime.year, r.dateTime.month, r.dateTime.day))
          .toSet()
          .toList();
    }
    final db = await database;
    final result = await db.rawQuery('''
      SELECT DISTINCT substr(dateTime, 1, 10) as dateStr
      FROM workout_records
      WHERE substr(dateTime, 1, 7) = ?
      ORDER BY dateStr ASC
    ''', ['$year-${month.toString().padLeft(2, '0')}']);
    return result.map((row) => DateTime.parse(row['dateStr'] as String)).toList();
  }

  Future<int> deleteWorkoutRecord(int id) async {
    if (kIsWeb) {
      _webRecords.removeWhere((r) => r.id == id);
      return 1;
    }
    final db = await database;
    return await db.delete(
      'workout_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }



  Future<void> deleteAllRecords() async {
    if (kIsWeb) {
      _webRecords.clear();
      return;
    }
    final db = await database;
    await db.delete('exercise_usage');
    await db.delete('exercise_sets');
    await db.delete('workout_records');
    await db.delete('workout_templates');
    await db.delete('workout_in_progress');
    await db.delete('user_body_data');
    // 不删除 exercises 表，保留内置动作
  }

  // 保存进行中的训练状态
  Future<void> saveWorkoutInProgress({
    required DateTime startTime,
    String? bodyPart,
    required int fatigueLevel,
    required List<Map<String, dynamic>> sets,
  }) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert(
      'workout_in_progress',
      {
        'id': 1,
        'startTime': startTime.toIso8601String(),
        'bodyPart': bodyPart,
        'fatigueLevel': fatigueLevel,
        'setsJson': jsonEncode(sets),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // 获取进行中的训练状态
  Future<Map<String, dynamic>?> getWorkoutInProgress() async {
    if (kIsWeb) return null;
    final db = await database;
    final result = await db.query('workout_in_progress', where: 'id = 1');
    if (result.isEmpty) return null;
    return result.first;
  }

  // 清除进行中的训练状态
  Future<void> clearWorkoutInProgress() async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('workout_in_progress', where: 'id = 1');
  }

  // 保存训练模板
  Future<int> saveWorkoutTemplate({
    required String name,
    required String bodyPart,
    required List<Map<String, dynamic>> exercises,
  }) async {
    if (kIsWeb) return -1;
    final db = await database;
    return await db.insert('workout_templates', {
      'name': name,
      'bodyPart': bodyPart,
      'exercisesJson': jsonEncode(exercises),
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  // 获取所有训练模板
  Future<List<Map<String, dynamic>>> getWorkoutTemplates() async {
    if (kIsWeb) return [];
    final db = await database;
    return await db.query(
      'workout_templates',
      orderBy: 'createdAt DESC',
    );
  }

  // 删除训练模板
  Future<int> deleteWorkoutTemplate(int id) async {
    if (kIsWeb) return 0;
    final db = await database;
    return await db.delete(
      'workout_templates',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 保存个人身体数据
  Future<int> saveBodyData({
    required double? weight,
    required double? height,
    required double? bodyFat,
    required double? muscleMass,
    required String recordDate,
  }) async {
    if (kIsWeb) return -1;
    final db = await database;
    return await db.insert('user_body_data', {
      'weight': weight,
      'height': height,
      'bodyFat': bodyFat,
      'muscleMass': muscleMass,
      'recordDate': recordDate,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  // 获取所有个人身体数据
  Future<List<Map<String, dynamic>>> getBodyData() async {
    if (kIsWeb) return [];
    final db = await database;
    return await db.query(
      'user_body_data',
      orderBy: 'recordDate DESC',
    );
  }

  // 删除个人身体数据
  Future<int> deleteBodyData(int id) async {
    if (kIsWeb) return 0;
    final db = await database;
    return await db.delete(
      'user_body_data',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 导出所有数据为JSON
  Future<Map<String, dynamic>> exportAllData() async {
    if (kIsWeb) return {};
    final db = await database;

    final exercises = await db.query('exercises', where: 'isBuiltIn = ?', whereArgs: [0]);
    final usageStats = await db.query('exercise_usage');
    final records = await db.query('workout_records');
    final sets = await db.query('exercise_sets');
    final templates = await db.query('workout_templates');
    final bodyData = await db.query('user_body_data');

    return {
      'version': 1,
      'exportTime': DateTime.now().toIso8601String(),
      'exercises': exercises,
      'exercise_usage': usageStats,
      'workout_records': records,
      'exercise_sets': sets,
      'workout_templates': templates,
      'user_body_data': bodyData,
    };
  }

  // 从JSON导入所有数据
  Future<void> importAllData(Map<String, dynamic> data) async {
    if (kIsWeb) return;
    final db = await database;

    await db.transaction((txn) async {
      // 清除现有用户数据（保留内置动作）
      await txn.delete('exercises', where: 'isBuiltIn = ?', whereArgs: [0]);
      await txn.delete('exercise_usage');
      await txn.delete('exercise_sets');
      await txn.delete('workout_records');
      await txn.delete('workout_templates');
      await txn.delete('user_body_data');

      // 导入自定义动作
      final exercises = data['exercises'] as List<dynamic>?;
      if (exercises != null) {
        for (var exercise in exercises) {
          await txn.insert('exercises', exercise as Map<String, dynamic>);
        }
      }

      // 导入使用统计
      final usageStats = data['exercise_usage'] as List<dynamic>?;
      if (usageStats != null) {
        for (var stat in usageStats) {
          await txn.insert('exercise_usage', stat as Map<String, dynamic>);
        }
      }

      // 导入训练记录
      final records = data['workout_records'] as List<dynamic>?;
      if (records != null) {
        for (var record in records) {
          await txn.insert('workout_records', record as Map<String, dynamic>);
        }
      }

      // 导入动作组
      final sets = data['exercise_sets'] as List<dynamic>?;
      if (sets != null) {
        for (var set in sets) {
          await txn.insert('exercise_sets', set as Map<String, dynamic>);
        }
      }

      // 导入模板
      final templates = data['workout_templates'] as List<dynamic>?;
      if (templates != null) {
        for (var template in templates) {
          await txn.insert('workout_templates', template as Map<String, dynamic>);
        }
      }

      // 导入身体数据
      final bodyData = data['user_body_data'] as List<dynamic>?;
      if (bodyData != null) {
        for (var data in bodyData) {
          await txn.insert('user_body_data', data as Map<String, dynamic>);
        }
      }
    });
  }
}

class _WebDatabase implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

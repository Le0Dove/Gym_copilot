class Exercise {
  int? id;
  String name;
  String tag;
  bool isBuiltIn;
  String targetMuscles;

  Exercise({
    this.id,
    required this.name,
    required this.tag,
    this.isBuiltIn = false,
    this.targetMuscles = '',
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'tag': tag,
      'isBuiltIn': isBuiltIn ? 1 : 0,
      'targetMuscles': targetMuscles,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'],
      name: map['name'],
      tag: map['tag'],
      isBuiltIn: map['isBuiltIn'] == 1,
      targetMuscles: map['targetMuscles'] ?? '',
    );
  }
}

class ExerciseSet {
  int? id;
  int recordId;
  int exerciseId;
  String exerciseName;
  String exerciseTag;
  double weight;
  int reps;
  int setNumber;

  ExerciseSet({
    this.id,
    required this.recordId,
    required this.exerciseId,
    required this.exerciseName,
    required this.exerciseTag,
    required this.weight,
    required this.reps,
    required this.setNumber,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'recordId': recordId,
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'exerciseTag': exerciseTag,
      'weight': weight,
      'reps': reps,
      'setNumber': setNumber,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory ExerciseSet.fromMap(Map<String, dynamic> map) {
    return ExerciseSet(
      id: map['id'],
      recordId: map['recordId'],
      exerciseId: map['exerciseId'],
      exerciseName: map['exerciseName'],
      exerciseTag: map['exerciseTag'],
      weight: map['weight'],
      reps: map['reps'],
      setNumber: map['setNumber'],
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/exercise.dart';
import '../models/workout_record.dart';
import '../data/exercise_data.dart';

class WorkoutScreen extends StatefulWidget {
  final String? templateBodyPart;
  final List<Map<String, dynamic>>? templateExercises;

  const WorkoutScreen({
    super.key,
    this.templateBodyPart,
    this.templateExercises,
  });

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  String? _selectedBodyPart;
  List<Exercise> _exercises = [];
  final List<ExerciseSet> _sets = [];
  int _fatigueLevel = 5;
  DateTime _startTime = DateTime.now();
  DateTime? _backgroundTime;
  Timer? _timer;
  Timer? _saveTimer;
  bool _isSaving = false;
  bool _isRestoring = false;
  bool _isTimerRunning = false;
  bool _isUsingTemplate = false;

  // 动画控制器
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 初始化脉冲动画
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // 初始化发光动画
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    _restoreWorkoutState();
    _loadExercises();
    _applyTemplate();

    // 启动脉冲动画
    _pulseController.repeat(reverse: true);
  }

  void _applyTemplate() {
    if (widget.templateExercises != null && widget.templateExercises!.isNotEmpty) {
      setState(() {
        _isUsingTemplate = true;
      });
      _loadTemplateExercises();
    }
  }

  // 加载模板中的动作到训练列表
  void _loadTemplateExercises() {
    if (widget.templateExercises == null) return;

    int setNumber = 1;
    setState(() {
      for (var exerciseData in widget.templateExercises!) {
        // 根据组数创建多个动作组
        final sets = exerciseData['sets'] as int? ?? 1;
        final weight = (exerciseData['weight'] as num?)?.toDouble() ?? 0;
        final reps = exerciseData['reps'] as int? ?? 0;

        for (int i = 0; i < sets; i++) {
          final exerciseSet = ExerciseSet(
            recordId: 0,
            exerciseId: exerciseData['exerciseId'] as int,
            exerciseName: exerciseData['exerciseName'] as String,
            exerciseTag: exerciseData['exerciseTag'] as String,
            weight: weight,
            reps: reps,
            setNumber: setNumber++,
            isTemplate: true,
          );
          _sets.add(exerciseSet);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _saveTimer?.cancel();
    _pulseController.dispose();
    _glowController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundTime = DateTime.now();
      _persistWorkoutState();
    } else if (state == AppLifecycleState.resumed && _backgroundTime != null) {
      _backgroundTime = null;
      if (mounted) {
        setState(() {});
      }
    }
  }

  // 恢复训练状态
  Future<void> _restoreWorkoutState() async {
    setState(() {
      _isRestoring = true;
    });

    try {
      final savedState = await DatabaseHelper.instance.getWorkoutInProgress();
      if (savedState != null && mounted) {
        final startTimeStr = savedState['startTime'] as String;
        final bodyPart = savedState['bodyPart'] as String?;
        final fatigueLevel = savedState['fatigueLevel'] as int;
        final setsJson = savedState['setsJson'] as String;

        // 解析保存的组数据
        final List<dynamic> setsList = jsonDecode(setsJson);
        final restoredSets = setsList.map((setMap) {
          return ExerciseSet(
            recordId: 0,
            exerciseId: setMap['exerciseId'] as int,
            exerciseName: setMap['exerciseName'] as String,
            exerciseTag: setMap['exerciseTag'] as String,
            weight: (setMap['weight'] as num).toDouble(),
            reps: setMap['reps'] as int,
            setNumber: setMap['setNumber'] as int,
            isTemplate: setMap['isTemplate'] == true,
          );
        }).toList();

        setState(() {
          _startTime = DateTime.parse(startTimeStr);
          _selectedBodyPart = bodyPart ?? 'mixed';
          _fatigueLevel = fatigueLevel;
          _sets.clear();
          _sets.addAll(restoredSets);
          _isTimerRunning = true;
          _isRestoring = false;
        });

        // 恢复计时器
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() {});
          }
        });
        _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
          _persistWorkoutState();
        });

        // 停止脉冲动画，启动计时器动画
        _pulseController.stop();
        _glowController.repeat(reverse: true);

        // 显示恢复提示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已恢复之前的训练'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        setState(() {
          _isRestoring = false;
        });
      }
    } catch (e) {
      setState(() {
        _isRestoring = false;
      });
    }
  }

  // 持久化训练状态
  Future<void> _persistWorkoutState() async {
    if (_sets.isEmpty) return;

    final setsData = _sets.map((set) {
      return {
        'exerciseId': set.exerciseId,
        'exerciseName': set.exerciseName,
        'exerciseTag': set.exerciseTag,
        'weight': set.weight,
        'reps': set.reps,
        'setNumber': set.setNumber,
        'isTemplate': set.isTemplate,
      };
    }).toList();

    await DatabaseHelper.instance.saveWorkoutInProgress(
      startTime: _startTime,
      bodyPart: _selectedBodyPart ?? 'mixed',
      fatigueLevel: _fatigueLevel,
      sets: setsData,
    );
  }

  Future<void> _loadExercises() async {
    final exercises = await DatabaseHelper.instance.getExercises();
    setState(() {
      _exercises = exercises;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elapsed = _isTimerRunning
        ? DateTime.now().difference(_startTime)
        : const Duration(seconds: 0);
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('记录训练'),
            if (_isUsingTemplate) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(51),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '模板',
                  style: theme.textTheme.labelSmall!.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _showDiscardDialog(),
        ),
        actions: [
          if (!_isSaving)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton(
                onPressed: _finishWorkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  '完成',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isRestoring
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // 顶部固定区域：计时器 + 训练部位
                  _buildHeaderSection(minutes, seconds, theme),

                  // 中间可滚动区域：动作列表
                  _buildSetsList(theme),

                  // 底部固定区域：疲劳度（独占一行）
                  _buildBottomSection(theme),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExerciseSet,
        elevation: 6,
        highlightElevation: 12,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showDiscardDialog() {
    if (_sets.isEmpty) {
      _timer?.cancel();
      _saveTimer?.cancel();
      Navigator.pop(context);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃训练？'),
        content: const Text('确定要放弃当前训练吗？已记录的数据将不会保存。'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('继续训练'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop();
              _timer?.cancel();
              _saveTimer?.cancel();
              await DatabaseHelper.instance.clearWorkoutInProgress();
              if (mounted) {
                navigator.pop();
              }
            },
            child: const Text('放弃'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSet(int index) {
    final set = _sets[index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除记录'),
        content: Text('确定要删除 "${set.exerciseName}" 的第${set.setNumber}组记录吗？'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _sets.removeAt(index);
              });
              _persistWorkoutState();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  // 顶部区域：计时器
  Widget _buildHeaderSection(int minutes, int seconds, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withAlpha(25),
            width: 1,
          ),
        ),
      ),
      child: _buildCompactTimer(minutes, seconds, theme),
    );
  }

  // 紧凑的计时器显示
  Widget _buildCompactTimer(int minutes, int seconds, ThemeData theme) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.center,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: !_isTimerRunning
          ? Container(
              key: const ValueKey('startButton'),
              height: MediaQuery.of(context).size.height * 0.30,
              alignment: Alignment.center,
              child: _buildStartButton(theme),
            )
          : Container(
              key: const ValueKey('timerDisplay'),
              height: MediaQuery.of(context).size.height * 0.30,
              alignment: Alignment.center,
              child: _buildTimerDisplay(minutes, seconds, theme),
            ),
    );
  }

  Widget _buildStartButton(ThemeData theme) {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // 柔和呼吸光环
              Transform.scale(
                scale: _pulseAnimation.value * 1.2,
                child: Container(
                  width: 148,
                  height: 148,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withAlpha(15),
                  ),
                ),
              ),
              child!,
            ],
          );
        },
            child: GestureDetector(
              onTap: _startTimer,
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.surface,
                  border: Border.all(
                    color: theme.colorScheme.primary.withAlpha(102),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withAlpha(38),
                      blurRadius: 30,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      size: 42,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '开始',
                      style: theme.textTheme.titleSmall!.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildTimerDisplay(int minutes, int seconds, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface.withAlpha(204),
            theme.colorScheme.surface.withAlpha(102),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(51),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 计时器数字
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 分钟
              _buildTimeDigit(minutes.toString().padLeft(2, '0'), ValueKey<int>(minutes), theme),
              _buildTimeSeparator(theme),
              // 秒数
              _buildTimeDigit(seconds.toString().padLeft(2, '0'), ValueKey<int>(seconds), theme),
            ],
          ),
          const SizedBox(width: 16),
          // 状态指示器
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(
                    ((0.5 + 0.5 * _glowAnimation.value) * 255).toInt(),
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withAlpha(
                        ((0.6 * _glowAnimation.value) * 255).toInt(),
                      ),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _startTimer() {
    setState(() {
      _isTimerRunning = true;
      _startTime = DateTime.now();
    });

    // 启动发光呼吸动画
    _glowController.repeat(reverse: true);

    // 停止脉冲动画
    _pulseController.stop();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    // 每10秒自动保存训练状态
    _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _persistWorkoutState();
    });
  }

  Widget _buildTimeDigit(String value, Key key, ThemeData theme) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.3),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          value,
          style: theme.textTheme.displayLarge!.copyWith(
            fontSize: 44,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSeparator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        ':',
        style: theme.textTheme.displayLarge!.copyWith(
          fontSize: 40,
          fontWeight: FontWeight.w300,
          color: theme.colorScheme.primary.withAlpha(153),
        ),
      ),
    );
  }

  Widget _buildSetsList(ThemeData theme) {
    if (_sets.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withAlpha(25),
                      theme.colorScheme.primary.withAlpha(5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.fitness_center_outlined,
                  size: 48,
                  color: theme.colorScheme.primary.withAlpha(102),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '点击右下角按钮添加训练动作',
                style: theme.textTheme.bodyLarge!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(178),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '开始你的训练吧',
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(127),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _sets.length,
      itemBuilder: (context, index) {
        final set = _sets[index];
        final isTemplateSet = set.isTemplate;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surface.withAlpha(242),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(51),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withAlpha(12),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
            border: Border.all(
              color: isTemplateSet
                  ? theme.colorScheme.primary.withAlpha(76)
                  : theme.colorScheme.outline.withAlpha(38),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isTemplateSet ? () => _editTemplateSet(index) : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // 序号
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isTemplateSet
                                ? [
                                    theme.colorScheme.primary.withAlpha(51),
                                    theme.colorScheme.primary.withAlpha(25),
                                  ]
                                : [
                                    theme.colorScheme.primary,
                                    theme.colorScheme.primary.withAlpha(216),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: isTemplateSet
                              ? null
                              : [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withAlpha(76),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: theme.textTheme.labelMedium!.copyWith(
                              color: isTemplateSet
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 动作信息
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              set.exerciseName,
                              style: theme.textTheme.titleMedium!.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            isTemplateSet
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withAlpha(25),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '模板动作 - 点击修改',
                                      style: theme.textTheme.labelSmall!.copyWith(
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  )
                                : Text(
                                    '${set.weight} kg × ${set.reps} 次',
                                    style: theme.textTheme.bodyMedium!.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                          ],
                        ),
                      ),
                      // 删除按钮
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _confirmDeleteSet(index),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.delete_outline,
                              size: 22,
                              color: theme.colorScheme.error.withAlpha(153),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _editTemplateSet(int index) async {
    // 编辑模板动作
    final set = _sets[index];

    final result = await showModalBottomSheet<ExerciseSet?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditSetBottomSheet(
        exercises: _exercises,
        set: set,
        setNumber: set.setNumber,
      ),
    );

    if (result != null) {
      setState(() {
        _sets[index] = result;
      });
      _persistWorkoutState();
    }
  }

  // 底部区域：疲劳度（独占一行）
  Widget _buildBottomSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withAlpha(25),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: _buildFatigueSlider(theme),
      ),
    );
  }

  Widget _buildFatigueSlider(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '疲劳度',
              style: theme.textTheme.titleSmall!.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '$_fatigueLevel / 10',
                style: theme.textTheme.labelSmall!.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: theme.colorScheme.primary,
            inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
            thumbColor: theme.colorScheme.primary,
            overlayColor: theme.colorScheme.primary.withAlpha(38),
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 14,
              elevation: 4,
            ),
            overlayShape: const RoundSliderOverlayShape(
              overlayRadius: 24,
            ),
          ),
          child: Slider(
            value: _fatigueLevel.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (value) {
              setState(() {
                _fatigueLevel = value.toInt();
              });
            },
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.sentiment_satisfied_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(153),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '轻松',
                    style: theme.textTheme.labelSmall!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(153),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '力竭',
                    style: theme.textTheme.labelSmall!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(153),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.sentiment_very_dissatisfied_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(153),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _addExerciseSet() async {
    final result = await showModalBottomSheet<List<ExerciseSet>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddSetBottomSheet(
        exercises: _exercises,
        setNumber: _sets.length + 1,
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _sets.addAll(result);
      });
      // 立即保存状态
      _persistWorkoutState();
    }
  }

  void _finishWorkout() {
    // 如果没有添加动作，询问是否结束
    if (_sets.isEmpty) {
      if (_isUsingTemplate) {
        _showEmptyWorkoutConfirmDialog();
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请添加至少一个动作')),
        );
        return;
      }
    }

    // 检查是否所有动作都是未编辑的模板动作
    final allTemplateUnedited = _sets.every((s) => s.isTemplate && s.weight == 0 && s.reps == 0);
    if (allTemplateUnedited) {
      _showEmptyWorkoutConfirmDialog();
      return;
    }

    _timer?.cancel();
    _saveTimer?.cancel();
    final elapsed = _isTimerRunning
        ? DateTime.now().difference(_startTime)
        : const Duration(seconds: 0);
    final finalDurationMinutes = elapsed.inMinutes < 1 ? 1 : elapsed.inMinutes;

    // 从动作中推断训练部位
    final bodyParts = _sets.map((s) => s.exerciseTag).toSet().toList();
    final bodyPartDisplay = bodyParts.length > 1
        ? '混合 (${bodyParts.map((tag) => ExerciseData.getTagDisplayName(tag)).join('、')})'
        : ExerciseData.getTagDisplayName(bodyParts.first);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('训练总结'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summaryText('训练部位', bodyPartDisplay),
              _summaryText('训练时长', '$finalDurationMinutes 分钟'),
              _summaryText('动作组数', '${_sets.length} 组'),
              _summaryText('疲劳度', '$_fatigueLevel / 10'),
            ],
          ),
          actions: [
            OutlinedButton(
              child: const Text('继续训练'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _timer = Timer.periodic(const Duration(seconds: 1), (_) {
                  if (mounted) {
                    setState(() {});
                  }
                });
                _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
                  _persistWorkoutState();
                });
              },
            ),
            ElevatedButton(
              child: const Text('保存记录'),
              onPressed: () async {
                if (_isSaving) return;
                setState(() {
                  _isSaving = true;
                });
                Navigator.of(dialogContext).pop();

                // 从动作中推断训练部位
                final bodyParts = _sets.map((s) => s.exerciseTag).toSet().toList();
                final primaryBodyPart = bodyParts.length > 1 ? 'mixed' : bodyParts.first;

                final record = WorkoutRecord(
                  dateTime: _startTime,
                  bodyPart: primaryBodyPart,
                  durationMinutes: finalDurationMinutes,
                  fatigueLevel: _fatigueLevel,
                  exerciseSets: _sets,
                );

                try {
                  await DatabaseHelper.instance.insertWorkoutRecord(record);
                  // 清除进行中的训练状态
                  await DatabaseHelper.instance.clearWorkoutInProgress();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('训练记录已保存')),
                    );
                  }

                  await Future.delayed(const Duration(milliseconds: 300));

                  if (mounted) {
                    // 返回 true 表示训练已成功保存
                    Navigator.of(context).pop(true);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('保存失败: $e'),
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      _isSaving = false;
                    });
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _summaryText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  // 显示空训练确认对话框（模板训练未添加动作）
  void _showEmptyWorkoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('结束训练？'),
          content: const Text('您尚未记录任何动作，确定要结束本次训练吗？'),
          actions: [
            OutlinedButton(
              child: const Text('继续训练'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              child: const Text('结束训练'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _saveEmptyWorkout();
              },
            ),
          ],
        );
      },
    );
  }

  // 保存空训练记录（模板训练未添加动作）
  Future<void> _saveEmptyWorkout() async {
    _timer?.cancel();
    _saveTimer?.cancel();

    final elapsed = _isTimerRunning
        ? DateTime.now().difference(_startTime)
        : const Duration(seconds: 0);
    final finalDurationMinutes = elapsed.inMinutes < 1 ? 1 : elapsed.inMinutes;

    final record = WorkoutRecord(
      dateTime: _startTime,
      bodyPart: _selectedBodyPart ?? 'mixed',
      durationMinutes: finalDurationMinutes,
      fatigueLevel: _fatigueLevel,
      exerciseSets: [],
    );

    try {
      await DatabaseHelper.instance.insertWorkoutRecord(record);
      await DatabaseHelper.instance.clearWorkoutInProgress();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('训练记录已保存')),
        );
      }

      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

class _AddSetBottomSheet extends StatefulWidget {
  final List<Exercise> exercises;
  final int setNumber;

  const _AddSetBottomSheet({
    required this.exercises,
    required this.setNumber,
  });

  @override
  State<_AddSetBottomSheet> createState() => _AddSetBottomSheetState();
}

class _AddSetBottomSheetState extends State<_AddSetBottomSheet> {
  String? _selectedTag;
  Exercise? _selectedExercise;
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _setsController = TextEditingController(text: '1');

  List<Exercise> get _filteredExercises {
    if (_selectedTag == null) return widget.exercises;
    return widget.exercises.where((e) => e.tag == _selectedTag).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = ExerciseData.getAllTags();

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '添加第 ${widget.setNumber} 组',
            style: theme.textTheme.headlineSmall!,
          ),
          const SizedBox(height: 16),
          // 部位选择标签
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tags.length,
              itemBuilder: (context, index) {
                final tag = tags[index];
                final isSelected = _selectedTag == tag;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(ExerciseData.getTagDisplayName(tag)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedTag = selected ? tag : null;
                        _selectedExercise = null;
                      });
                    },
                    selectedColor: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Exercise>(
                value: _selectedExercise,
                hint: Text(
                  _selectedTag == null ? '请先选择部位' : '选择动作',
                  style: theme.textTheme.bodyMedium!,
                ),
                isExpanded: true,
                dropdownColor: theme.colorScheme.surfaceContainerHighest,
                style: theme.textTheme.bodyMedium!,
                items: _filteredExercises.map((exercise) {
                  return DropdownMenuItem(
                    value: exercise,
                    child: Text(exercise.name),
                  );
                }).toList(),
                onChanged: _selectedTag == null
                    ? null
                    : (value) {
                        setState(() {
                          _selectedExercise = value;
                        });
                      },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.bodyMedium!,
                    decoration: InputDecoration(
                      hintText: '重量',
                      hintStyle: theme.textTheme.bodyMedium!.copyWith( 
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      suffixText: 'kg',
                      suffixStyle: theme.textTheme.bodySmall!,
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _repsController,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.bodyMedium!,
                    decoration: InputDecoration(
                      hintText: '次数',
                      hintStyle: theme.textTheme.bodyMedium!.copyWith( 
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      suffixText: '次',
                      suffixStyle: theme.textTheme.bodySmall!,
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _setsController,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.bodyMedium!,
                    decoration: InputDecoration(
                      hintText: '组数',
                      hintStyle: theme.textTheme.bodyMedium!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      suffixText: '组',
                      suffixStyle: theme.textTheme.bodySmall!,
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_selectedExercise == null ||
                    _weightController.text.isEmpty ||
                    _repsController.text.isEmpty ||
                    _setsController.text.isEmpty) {
                  return;
                }

                final weight = double.tryParse(_weightController.text);
                final reps = int.tryParse(_repsController.text);
                final sets = int.tryParse(_setsController.text);

                if (weight == null ||
                    reps == null ||
                    sets == null ||
                    weight <= 0 ||
                    reps <= 0 ||
                    sets <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入有效的重量、次数和组数')),
                  );
                  return;
                }

                final exercise = _selectedExercise!;
                if (exercise.id == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('动作数据异常')),
                  );
                  return;
                }

                // 根据组数创建多个动作组
                final List<ExerciseSet> exerciseSets = [];
                for (int i = 0; i < sets; i++) {
                  exerciseSets.add(ExerciseSet(
                    recordId: 0,
                    exerciseId: exercise.id!,
                    exerciseName: exercise.name,
                    exerciseTag: exercise.tag,
                    weight: weight,
                    reps: reps,
                    setNumber: widget.setNumber + i,
                  ));
                }

                Navigator.pop(context, exerciseSets);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '添加',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _setsController.dispose();
    super.dispose();
  }
}

// 编辑模板动作底部弹窗
class _EditSetBottomSheet extends StatefulWidget {
  final List<Exercise> exercises;
  final ExerciseSet set;
  final int setNumber;

  const _EditSetBottomSheet({
    required this.exercises,
    required this.set,
    required this.setNumber,
  });

  @override
  State<_EditSetBottomSheet> createState() => _EditSetBottomSheetState();
}

class _EditSetBottomSheetState extends State<_EditSetBottomSheet> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: widget.set.weight > 0 ? widget.set.weight.toString() : '',
    );
    _repsController = TextEditingController(
      text: widget.set.reps > 0 ? widget.set.reps.toString() : '',
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '编辑 ${widget.set.exerciseName}',
            style: theme.textTheme.headlineSmall!,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.bodyMedium!,
                    decoration: InputDecoration(
                      hintText: '重量',
                      hintStyle: theme.textTheme.bodyMedium!.copyWith( 
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      suffixText: 'kg',
                      suffixStyle: theme.textTheme.bodySmall!,
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _repsController,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.bodyMedium!,
                    decoration: InputDecoration(
                      hintText: '次数',
                      hintStyle: theme.textTheme.bodyMedium!.copyWith( 
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      suffixText: '次',
                      suffixStyle: theme.textTheme.bodySmall!,
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_weightController.text.isEmpty ||
                    _repsController.text.isEmpty) {
                  return;
                }

                final weight = double.tryParse(_weightController.text);
                final reps = int.tryParse(_repsController.text);

                if (weight == null ||
                    reps == null ||
                    weight <= 0 ||
                    reps <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入有效的重量和次数')),
                  );
                  return;
                }

                final updatedSet = ExerciseSet(
                  recordId: widget.set.recordId,
                  exerciseId: widget.set.exerciseId,
                  exerciseName: widget.set.exerciseName,
                  exerciseTag: widget.set.exerciseTag,
                  weight: weight,
                  reps: reps,
                  setNumber: widget.setNumber,
                );

                Navigator.pop(context, updatedSet);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '保存',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

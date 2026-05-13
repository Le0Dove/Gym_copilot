import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';

import '../database/database_helper.dart';
import '../main.dart';
import '../models/workout_record.dart';
import '../data/exercise_data.dart';
import 'workout_screen.dart';
import 'workout_templates_screen.dart';
import 'workout_calendar_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, RouteAware {
  List<WorkoutRecord> _records = [];
  bool _isLoading = true;
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _daysSinceLastWorkout = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // 从其他页面返回时刷新数据
    loadData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadData();
    }
  }

  Future<void> loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final records = await DatabaseHelper.instance.getWorkoutRecords();
      final currentStreak = await DatabaseHelper.instance.getCurrentStreak();
      final longestStreak = await DatabaseHelper.instance.getLongestStreak();
      final daysSince = await DatabaseHelper.instance.getDaysSinceLastWorkout();

      if (mounted) {
        setState(() {
          _records = records;
          _currentStreak = currentStreak;
          _longestStreak = longestStreak;
          _daysSinceLastWorkout = daysSince;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('加载数据失败: $e');
      debugPrint('堆栈跟踪: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载数据失败: $e')),
        );
      }
    }
  }

  int get _weeklyWorkoutDays {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final dates = _records
        .where((r) {
          final recordDate =
              DateTime(r.dateTime.year, r.dateTime.month, r.dateTime.day);
          return !recordDate.isBefore(startOfWeek);
        })
        .map((r) => DateFormat('yyyy-MM-dd').format(r.dateTime))
        .toSet();
    return dates.length;
  }

  int get _weeklyDuration {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return _records
        .where((r) {
          final recordDate =
              DateTime(r.dateTime.year, r.dateTime.month, r.dateTime.day);
          return !recordDate.isBefore(startOfWeek);
        })
        .fold(0, (sum, r) => sum + r.durationMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: loadData,
                color: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surface,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildStreakCard(theme),
                    ),
                    SliverToBoxAdapter(
                      child: _buildHeader(theme),
                    ),
                    SliverToBoxAdapter(
                      child: _buildSectionTitle('训练记录', theme),
                    ),
                    if (_records.isEmpty)
                      SliverToBoxAdapter(
                        child: _buildEmptyState(theme),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => FadeInUp(
                            duration: const Duration(milliseconds: 400),
                            delay: Duration(milliseconds: index * 80),
                            child: _buildRecordCard(
                              _records[index],
                              theme,
                            ),
                          ),
                          childCount: _records.length,
                        ),
                      ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 100),
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WorkoutScreen(),
                      ),
                    );
                    debugPrint('WorkoutScreen 返回结果: $result');
                    // 延迟确保数据库操作完成
                    await Future.delayed(const Duration(milliseconds: 500));
                    loadData();
                  },
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text(
                    '开始训练',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFFE8E4E1),
                    foregroundColor: const Color(0xFF0A0A0A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WorkoutTemplatesScreen(),
                      ),
                    );
                    loadData();
                  },
                  icon: const Icon(Icons.folder_outlined, size: 18),
                  label: const Text('模板'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: const Color(0xFF8B8680),
                    side: const BorderSide(color: Color(0xFF2A2A2A)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildStreakCard(ThemeData theme) {
    return FadeInDown(
      duration: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WorkoutCalendarScreen(),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _currentStreak > 0
                    ? [
                        const Color(0xFFFF6B35).withAlpha(38),
                        const Color(0xFFFF8C42).withAlpha(20),
                      ]
                    : [
                        theme.colorScheme.surfaceContainerHighest.withAlpha(127),
                        theme.colorScheme.surfaceContainerHighest.withAlpha(51),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _currentStreak > 0
                    ? const Color(0xFFFF6B35).withAlpha(76)
                    : theme.colorScheme.outline.withAlpha(76),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: _currentStreak > 0
                        ? const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [
                              theme.colorScheme.onSurfaceVariant.withAlpha(51),
                              theme.colorScheme.onSurfaceVariant.withAlpha(25),
                            ],
                          ),
                    shape: BoxShape.circle,
                    boxShadow: _currentStreak > 0
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFF6B35).withAlpha(76),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    _currentStreak > 0 ? Icons.local_fire_department : Icons.local_fire_department_outlined,
                    size: 28,
                    color: _currentStreak > 0 ? Colors.white : theme.colorScheme.onSurfaceVariant.withAlpha(127),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentStreak > 0
                            ? '连续训练 $_currentStreak 天'
                            : _daysSinceLastWorkout > 0
                                ? '已休息 $_daysSinceLastWorkout 天'
                                : '开始你的训练之旅',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _currentStreak > 0
                              ? const Color(0xFFFF8C42)
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentStreak > 0
                            ? '最长纪录: $_longestStreak 天 🔥'
                            : _daysSinceLastWorkout > 1
                                ? '你的 $_longestStreak 天纪录中断了，今天重新开始！'
                                : '坚持训练，建立你的连续纪录',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_currentStreak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withAlpha(76),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      '$_currentStreak',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            duration: const Duration(milliseconds: 500),
            child: Text(
              '本周概览',
              style: theme.textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: 20),
          FadeInUp(
            duration: const Duration(milliseconds: 600),
            delay: const Duration(milliseconds: 100),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.surface,
                    theme.colorScheme.surface.withAlpha(204),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.outline.withAlpha(127),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(51),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: theme.colorScheme.primary.withAlpha(12),
                    blurRadius: 40,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatBlock(
                      '$_weeklyWorkoutDays',
                      '训练天数',
                      Icons.calendar_today_outlined,
                      theme,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          theme.colorScheme.outline.withAlpha(127),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  Expanded(
                    child: _buildStatBlock(
                      '$_weeklyDuration',
                      '总时长(分钟)',
                      Icons.schedule_outlined,
                      theme,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBlock(String value, String label, IconData icon, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: theme.textTheme.displayMedium?.copyWith(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            height: 1.1,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withAlpha(38),
                      theme.colorScheme.primary.withAlpha(12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.fitness_center_outlined,
                  size: 56,
                  color: theme.colorScheme.primary.withAlpha(153),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                '还没有历史记录',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '点击下方的"开始训练"按钮\n记录你的第一次健身',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(178),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WorkoutScreen(),
                    ),
                  );
                  loadData();
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('开始第一次训练'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                  shadowColor: theme.colorScheme.primary.withAlpha(102),
                ),
              ),
              const SizedBox(height: 16),
              // 调试按钮：插入测试数据
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await DatabaseHelper.instance.insertTestData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('测试数据已插入')),
                      );
                      loadData();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('插入失败: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.bug_report, size: 16),
                label: const Text('插入测试数据（调试用）'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                  side: BorderSide(
                    color: theme.colorScheme.outline.withAlpha(127),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordCard(WorkoutRecord record, ThemeData theme) {
    final tagColor = _getTagColor(record.bodyPart);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        child: InkWell(
          onTap: () => _showRecordDetail(record, theme),
          borderRadius: BorderRadius.circular(20),
          splashColor: tagColor.withAlpha(25),
          highlightColor: tagColor.withAlpha(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.surface,
                  theme.colorScheme.surface.withAlpha(242),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: tagColor.withAlpha(76),
                              shape: BoxShape.circle,
                              border: Border.all(color: tagColor, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: tagColor.withAlpha(76),
                                  blurRadius: 6,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            ExerciseData.getTagDisplayName(record.bodyPart),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withAlpha(153),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          DateFormat('MM/dd HH:mm').format(record.dateTime),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _buildInfoChip(
                        '${record.durationMinutes}分钟',
                        theme,
                        Icons.timer_outlined,
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        '${record.exerciseSets.length}组',
                        theme,
                        Icons.format_list_numbered_outlined,
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        '疲劳${record.fatigueLevel}',
                        theme,
                        Icons.battery_alert_outlined,
                      ),
                    ],
                  ),
                  if (record.exerciseSets.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withAlpha(102),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          ...record.exerciseSets.take(4).map((set) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface.withAlpha(153),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${set.exerciseName} ${set.weight}kg×${set.reps}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            );
                          }),
                          if (record.exerciseSets.length > 4)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withAlpha(38),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '+${record.exerciseSets.length - 4}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, ThemeData theme, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surfaceContainerHighest.withAlpha(178),
            theme.colorScheme.surfaceContainerHighest.withAlpha(102),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(76),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  void _showRecordDetail(WorkoutRecord record, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getTagColor(record.bodyPart).withAlpha(51),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getTagColor(record.bodyPart),
                        width: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ExerciseData.getTagDisplayName(record.bodyPart),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('yyyy年MM月dd日 HH:mm').format(record.dateTime),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildInfoChip('${record.durationMinutes}分钟', theme, Icons.timer_outlined),
                  const SizedBox(width: 8),
                  _buildInfoChip('${record.exerciseSets.length}组', theme, Icons.format_list_numbered_outlined),
                  const SizedBox(width: 8),
                  _buildInfoChip('疲劳${record.fatigueLevel}', theme, Icons.battery_alert_outlined),
                ],
              ),
              const SizedBox(height: 20),
              Divider(color: theme.colorScheme.outline.withAlpha(51)),
              const SizedBox(height: 12),
              Text(
                '动作详情',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (record.exerciseSets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      '该记录未添加动作',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: record.exerciseSets.length,
                  itemBuilder: (context, index) {
                    final set = record.exerciseSets[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  set.exerciseName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${set.weight}kg × ${set.reps}次',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getTagColor(String tag) {
    final colors = {
      'chest': const Color(0xFFFF8A65),    // 温暖的橙红色
      'back': const Color(0xFF4FC3F7),     // 清新的蓝色
      'legs': const Color(0xFF81C784),     // 健康的绿色
      'shoulders': const Color(0xFFFFB74D), // 活力的橙色
      'arms': const Color(0xFF9575CD),      // 稳重的紫色
      'core': const Color(0xFF4DB6AC),      // 平静的青绿色
    };
    return colors[tag] ?? const Color(0xFF8B8680);
  }
}

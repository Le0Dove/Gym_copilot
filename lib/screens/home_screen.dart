import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../main.dart';
import '../models/workout_record.dart';
import '../data/exercise_data.dart';
import 'workout_screen.dart';
import 'workout_templates_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, RouteAware {
  List<WorkoutRecord> _records = [];
  bool _isLoading = true;

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
      if (mounted) {
        setState(() {
          _records = records;
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
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final dates = _records
        .where((r) =>
            r.dateTime.isAfter(startOfWeek.subtract(const Duration(days: 1))))
        .map((r) => DateFormat('yyyy-MM-dd').format(r.dateTime))
        .toSet();
    return dates.length;
  }

  int get _weeklyDuration {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return _records
        .where((r) =>
            r.dateTime.isAfter(startOfWeek.subtract(const Duration(days: 1))))
        .fold(0, (sum, r) => sum + r.durationMinutes);
  }

  List<WorkoutRecord> get _todayRecords {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _records
        .where((r) => DateFormat('yyyy-MM-dd').format(r.dateTime) == today)
        .toList();
  }

  List<WorkoutRecord> get _pastRecords {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _records
        .where((r) => DateFormat('yyyy-MM-dd').format(r.dateTime) != today)
        .toList();
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
                      child: _buildHeader(theme),
                    ),
                    // 调试信息：显示记录数量
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '总记录: ${_records.length} | 今日: ${_todayRecords.length} | 历史: ${_pastRecords.length}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_todayRecords.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: _buildSectionTitle('今日训练', theme),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildRecordCard(
                            _todayRecords[index],
                            theme,
                          ),
                          childCount: _todayRecords.length,
                        ),
                      ),
                    ],
                    SliverToBoxAdapter(
                      child: _buildSectionTitle('历史记录', theme),
                    ),
                    if (_pastRecords.isEmpty && _todayRecords.isEmpty)
                      SliverToBoxAdapter(
                        child: _buildEmptyState(theme),
                      )
                    else if (_pastRecords.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 20),
                          child: Center(
                            child: Text(
                              '今日有训练记录，历史记录为空',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildRecordCard(
                            _pastRecords[index],
                            theme,
                          ),
                          childCount: _pastRecords.length,
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

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '本周概览',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatBlock(
                  '$_weeklyWorkoutDays',
                  '训练天数',
                  theme,
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: theme.colorScheme.outline,
                margin: const EdgeInsets.symmetric(horizontal: 20),
              ),
              Expanded(
                child: _buildStatBlock(
                  '$_weeklyDuration',
                  '总时长(分钟)',
                  theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBlock(String value, String label, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: theme.textTheme.displayMedium?.copyWith(
            fontSize: 40,
            fontWeight: FontWeight.w300,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fitness_center_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 20),
            Text(
              '还没有历史记录',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方的"开始训练"按钮\n记录你的第一次健身',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 调试按钮：插入测试数据
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await DatabaseHelper.instance.insertTestData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('测试数据已插入')),
                  );
                  loadData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('插入失败: $e')),
                  );
                }
              },
              icon: const Icon(Icons.bug_report, size: 16),
              label: const Text('插入测试数据（调试用）'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
                side: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.5),
                ),
              ),
            ),
          ],
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
          onTap: () {},
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: tagColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: tagColor, width: 2),
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
                    Text(
                      DateFormat('MM/dd HH:mm').format(record.dateTime),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildInfoChip(
                      '${record.durationMinutes}分钟',
                      theme,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      '${record.exerciseSets.length}组',
                      theme,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      '疲劳${record.fatigueLevel}',
                      theme,
                    ),
                  ],
                ),
                if (record.exerciseSets.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ...record.exerciseSets.take(4).map((set) {
                        return Text(
                          '${set.exerciseName} ${set.weight}kg×${set.reps}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        );
                      }),
                      if (record.exerciseSets.length > 4)
                        Text(
                          '+${record.exerciseSets.length - 4}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
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

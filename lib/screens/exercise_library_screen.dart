import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/exercise.dart';
import '../data/exercise_data.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  List<Exercise> _exercises = [];
  List<Exercise> _filteredExercises = [];
  Map<int, Map<String, dynamic>> _exerciseUsageStats = {};
  String? _selectedTag;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customNameController = TextEditingController();
  final TextEditingController _customTargetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    try {
      final exercises = await DatabaseHelper.instance.getExercises();
      final usageStats = await DatabaseHelper.instance.getExerciseUsageStats();
      final usageMap = <int, Map<String, dynamic>>{};
      for (var stat in usageStats) {
        usageMap[stat['exerciseId'] as int] = {
          'useCount': stat['useCount'] as int,
          'lastUsedDate': stat['lastUsedDate'] as String?,
        };
      }
      exercises.sort((a, b) {
        final countA = usageMap[a.id]?['useCount'] ?? 0;
        final countB = usageMap[b.id]?['useCount'] ?? 0;
        return countB.compareTo(countA);
      });
      if (mounted) {
        setState(() {
          _exercises = exercises;
          _exerciseUsageStats = usageMap;
          _filterExercises();
        });
      }
    } catch (e) {
      debugPrint('加载动作失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('加载动作失败，请重试')),
        );
      }
    }
  }

  void _filterExercises() {
    final search = _searchController.text.toLowerCase();
    setState(() {
      _filteredExercises = _exercises.where((e) {
        final matchesTag = _selectedTag == null || e.tag == _selectedTag;
        final matchesSearch =
            search.isEmpty || e.name.toLowerCase().contains(search);
        return matchesTag && matchesSearch;
      }).toList();
      _filteredExercises.sort((a, b) {
        final countA = _exerciseUsageStats[a.id]?['useCount'] ?? 0;
        final countB = _exerciseUsageStats[b.id]?['useCount'] ?? 0;
        return countB.compareTo(countA);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('动作库'),
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  style: theme.textTheme.bodyMedium,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: '搜索动作',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _filterExercises();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (_) => _filterExercises(),
                ),
              ),
            ),
          ),
          // 部位筛选标签
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                const SizedBox(width: 4),
                ...ExerciseData.getAllTags().map((tag) => _buildTagChip(
                    tag, ExerciseData.getTagDisplayName(tag), theme)),
                const SizedBox(width: 4),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 动作列表
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadExercises,
              color: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surface,
              child: _filteredExercises.isEmpty
                  ? _buildEmptyState(theme)
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filteredExercises.length,
                itemBuilder: (context, index) {
                  final exercise = _filteredExercises[index];
                  final stats = _exerciseUsageStats[exercise.id];
                  final useCount = stats?['useCount'] ?? 0;
                  final lastUsedDate = stats?['lastUsedDate'] as String?;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: InkWell(
                      onTap: () =>
                          _showExerciseDetail(exercise, useCount, lastUsedDate),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // 左侧图标
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _getTagColor(exercise.tag).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Icon(
                                  _getTagIcon(exercise.tag),
                                  color: _getTagColor(exercise.tag),
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // 中间信息
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    exercise.name,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      if (useCount > 0) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme
                                                .colorScheme.surfaceVariant,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.fitness_center,
                                                size: 10,
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$useCount 次',
                                                style: theme
                                                    .textTheme.labelSmall
                                                    ?.copyWith(
                                                  color: theme.colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // 右侧信息
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (lastUsedDate != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme.surfaceVariant,
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 10,
                                          color: theme.colorScheme
                                              .onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatDate(lastUsedDate),
                                          style: theme
                                              .textTheme.labelSmall
                                              ?.copyWith(
                                            color: theme.colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            // 删除按钮已移至详情页
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomExerciseDialog,
        child: const Icon(Icons.add, size: 20),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MM/dd').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildTagChip(String? tag, String label, ThemeData theme) {
    final isSelected = _selectedTag == tag;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTag = isSelected ? null : tag;
          _filterExercises();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  IconData _getTagIcon(String tag) {
    final icons = {
      'chest': Icons.fitness_center,
      'back': Icons.arrow_back,
      'legs': Icons.directions_walk,
      'shoulders': Icons.accessibility,
      'arms': Icons.pan_tool,
      'core': Icons.circle,
    };
    return icons[tag] ?? Icons.fitness_center;
  }

  Color _getTagColor(String tag) {
    final colors = {
      'chest': const Color(0xFFFF8A65),
      'back': const Color(0xFF4FC3F7),
      'legs': const Color(0xFF81C784),
      'shoulders': const Color(0xFFFFB74D),
      'arms': const Color(0xFF9575CD),
      'core': const Color(0xFF4DB6AC),
    };
    return colors[tag] ?? const Color(0xFF8B8680);
  }

  void _showExerciseDetail(
      Exercise exercise, int useCount, String? lastUsedDate) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
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
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getTagColor(exercise.tag).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        _getTagIcon(exercise.tag),
                        color: _getTagColor(exercise.tag),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.name,
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ExerciseData.getTagDisplayName(exercise.tag),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              _buildDetailRow(
                icon: Icons.fitness_center,
                label: '训练次数',
                value: '$useCount 次',
                theme: theme,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.calendar_today,
                label: '上次训练',
                value:
                    lastUsedDate != null ? _formatDate(lastUsedDate) : '从未训练',
                theme: theme,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.fitness_center,
                label: '关联部位',
                value: exercise.targetMuscles.isNotEmpty
                    ? exercise.targetMuscles
                    : '暂无',
                theme: theme,
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showExerciseHistory(exercise);
                  },
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('查看历史记录'),
                ),
              ),
              if (!exercise.isBuiltIn) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteExercise(exercise);
                    },
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    label: Text(
                      '删除动作',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme.colorScheme.error.withOpacity(0.3)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  void _showExerciseHistory(Exercise exercise) async {
    if (exercise.id == null) return;

    final history =
        await DatabaseHelper.instance.getExerciseHistory(exercise.id!);

    if (!mounted) return;

    final theme = Theme.of(context);

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
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getTagColor(exercise.tag).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        _getTagIcon(exercise.tag),
                        color: _getTagColor(exercise.tag),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.name,
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '历史记录',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (history.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      '暂无历史记录',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final record = history[index];
                      final dateTime =
                          DateTime.parse(record['dateTime'] as String);
                      final weight = (record['weight'] as num).toDouble();
                      final reps = record['reps'] as int;
                      final setNumber = record['setNumber'] as int;
                      final fatigueLevel = record['fatigueLevel'] as int;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '$setNumber',
                                    style:
                                        theme.textTheme.labelMedium?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('yyyy/MM/dd HH:mm')
                                          .format(dateTime),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${weight}kg × $reps次',
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '疲劳$fatigueLevel',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _deleteExercise(Exercise exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogTheme = Theme.of(context);
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除动作 "${exercise.name}" 吗？\n此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: dialogTheme.colorScheme.error,
                foregroundColor: dialogTheme.colorScheme.onError,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && exercise.id != null) {
      await DatabaseHelper.instance.deleteExercise(exercise.id!);
      _loadExercises();
    }
  }

  Future<void> _showAddCustomExerciseDialog() async {
    String? selectedTag;

    final result = await showDialog<Exercise?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('添加自定义动作'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _customNameController,
                decoration: const InputDecoration(
                  labelText: '动作名称',
                  hintText: '例如：单臂哑铃划船',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedTag,
                hint: const Text('选择部位'),
                items: ExerciseData.getAllTags().map((tag) {
                  return DropdownMenuItem(
                    value: tag,
                    child: Text(ExerciseData.getTagDisplayName(tag)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedTag = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _customTargetController,
                decoration: const InputDecoration(
                  labelText: '关联部位',
                  hintText: '例如：胸肌、肩前束',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (_customNameController.text.isEmpty || selectedTag == null) {
                  return;
                }
                final exercise = Exercise(
                  name: _customNameController.text,
                  tag: selectedTag!,
                  isBuiltIn: false,
                  targetMuscles: _customTargetController.text,
                );
                Navigator.pop(context, exercise);
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await DatabaseHelper.instance.insertExercise(result);
      _customNameController.clear();
      _customTargetController.clear();
      _loadExercises();
    }
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '没有找到匹配的动作',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '试试其他关键词或清除筛选条件',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedTag != null || _searchController.text.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedTag = null;
                    _searchController.clear();
                    _filterExercises();
                  });
                },
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('清除筛选'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customNameController.dispose();
    _customTargetController.dispose();
    super.dispose();
  }
}

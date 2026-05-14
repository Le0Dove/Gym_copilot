import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';

import '../database/database_helper.dart';
import '../models/exercise.dart';
import '../data/exercise_data.dart';
import 'exercise_detail_screen.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  // 新设计系统
  static const Color _background = Color(0xFF0B0F19);
  static const Color _surface = Color(0xFF1A1F2E);
  static const Color _surfaceVariant = Color(0xFF242B3D);
  static const Color _primary = Color(0xFFF97316);
  static const Color _foreground = Color(0xFFF8FAFC);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFF2D3748);
  static const Color _error = Color(0xFFEF4444);

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
          const SnackBar(
            content: Text(
              '加载动作失败，请重试',
              style: TextStyle(color: _foreground),
            ),
            backgroundColor: _surface,
          ),
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
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        title: const Text(
          '动作库',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _foreground,
          ),
        ),
        iconTheme: const IconThemeData(color: _foreground),
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: _surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _border,
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 14, color: _foreground),
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: '搜索动作',
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: _muted,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: _muted,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: _muted,
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
            child: FadeIn(
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  const SizedBox(width: 4),
                  ...ExerciseData.getAllTags().asMap().entries.map((entry) {
                    final index = entry.key;
                    final tag = entry.value;
                    return FadeInLeft(
                      delay: Duration(milliseconds: index * 50),
                      child: _buildTagChip(
                        tag,
                        ExerciseData.getTagDisplayName(tag),
                      ),
                    );
                  }),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 动作列表
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadExercises,
              color: _primary,
              backgroundColor: _surface,
              child: _filteredExercises.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _filteredExercises.length,
                      itemBuilder: (context, index) {
                        final exercise = _filteredExercises[index];
                        final stats = _exerciseUsageStats[exercise.id];
                        final useCount = stats?['useCount'] ?? 0;
                        final lastUsedDate = stats?['lastUsedDate'] as String?;

                        return FadeInUp(
                          delay: Duration(milliseconds: index * 50),
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 0,
                            color: _surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(
                                color: _border,
                                width: 1,
                              ),
                            ),
                            child: InkWell(
                              onTap: () => _showExerciseDetail(
                                  exercise, useCount, lastUsedDate),
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
                                        color: _getTagColor(exercise.tag)
                                            .withAlpha(38),
                                        borderRadius:
                                            BorderRadius.circular(16),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            exercise.name,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: _foreground,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              if (useCount > 0) ...[
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _surfaceVariant,
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.fitness_center,
                                                        size: 10,
                                                        color: _muted,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '$useCount 次',
                                                        style:
                                                            const TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: _muted,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        if (lastUsedDate != null) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _surfaceVariant,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.calendar_today,
                                                  size: 10,
                                                  color: _muted,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _formatDate(lastUsedDate),
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
                                                    color: _muted,
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
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FadeInUp(
        child: FloatingActionButton(
          onPressed: _showAddCustomExerciseDialog,
          backgroundColor: _primary,
          foregroundColor: _foreground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.add, size: 20),
        ),
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

  Widget _buildTagChip(String? tag, String label) {
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
          color: isSelected ? _primary : _surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _primary : _border,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primary.withAlpha(76),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: _foreground,
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
        return FadeInUp(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: _surface,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
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
                      color: _border,
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
                        color: _getTagColor(exercise.tag).withAlpha(38),
                        borderRadius: BorderRadius.circular(16),
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
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _foreground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ExerciseData.getTagDisplayName(exercise.tag),
                            style: const TextStyle(
                              fontSize: 14,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(color: _border),
                const SizedBox(height: 16),
                _buildDetailRow(
                  icon: Icons.fitness_center,
                  label: '训练次数',
                  value: '$useCount 次',
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.calendar_today,
                  label: '上次训练',
                  value: lastUsedDate != null
                      ? _formatDate(lastUsedDate)
                      : '从未训练',
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.fitness_center,
                  label: '关联部位',
                  value: exercise.targetMuscles.isNotEmpty
                      ? exercise.targetMuscles
                      : '暂无',
                ),
                const SizedBox(height: 24),
                const Divider(color: _border),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ExerciseDetailScreen(exercise: exercise),
                        ),
                      );
                    },
                    icon: const Icon(Icons.insights, size: 18),
                    label: const Text(
                      '查看数据分析',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: _foreground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
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
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: _error,
                      ),
                      label: const Text(
                        '删除动作',
                        style: TextStyle(
                          color: _error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _error.withAlpha(76)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: _muted,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _foreground,
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
        return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '确认删除',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _foreground,
            ),
          ),
          content: Text(
            '确定要删除动作 "${exercise.name}" 吗？\n此操作不可撤销。',
            style: const TextStyle(
              fontSize: 14,
              color: _foreground,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                '取消',
                style: TextStyle(color: _muted),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: _error,
                foregroundColor: _foreground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '删除',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
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
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '添加自定义动作',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _foreground,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _customNameController,
                style: const TextStyle(color: _foreground),
                decoration: const InputDecoration(
                  labelText: '动作名称',
                  hintText: '例如：单臂哑铃划船',
                  labelStyle: TextStyle(color: _muted),
                  hintStyle: TextStyle(color: _muted),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _border),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedTag,
                hint: const Text(
                  '选择部位',
                  style: TextStyle(color: _muted),
                ),
                style: const TextStyle(color: _foreground),
                dropdownColor: _surfaceVariant,
                decoration: const InputDecoration(
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _border),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _primary),
                  ),
                ),
                items: ExerciseData.getAllTags().map((tag) {
                  return DropdownMenuItem(
                    value: tag,
                    child: Text(
                      ExerciseData.getTagDisplayName(tag),
                      style: const TextStyle(color: _foreground),
                    ),
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
                style: const TextStyle(color: _foreground),
                decoration: const InputDecoration(
                  labelText: '关联部位',
                  hintText: '例如：胸肌、肩前束',
                  labelStyle: TextStyle(color: _muted),
                  hintStyle: TextStyle(color: _muted),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _border),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _primary),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                '取消',
                style: TextStyle(color: _muted),
              ),
            ),
            FilledButton(
              onPressed: () {
                if (_customNameController.text.isEmpty ||
                    selectedTag == null) {
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
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: _foreground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '添加',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
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

  Widget _buildEmptyState() {
    return Center(
      child: FadeIn(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: _muted.withAlpha(127),
              ),
              const SizedBox(height: 16),
              const Text(
                '没有找到匹配的动作',
                style: TextStyle(
                  fontSize: 16,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '试试其他关键词或清除筛选条件',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: _muted.withAlpha(178),
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
                  icon: const Icon(
                    Icons.clear,
                    size: 18,
                    color: _primary,
                  ),
                  label: const Text(
                    '清除筛选',
                    style: TextStyle(color: _primary),
                  ),
                ),
            ],
          ),
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

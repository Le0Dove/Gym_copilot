import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

import '../data/exercise_data.dart';
import '../database/database_helper.dart';
import '../models/exercise.dart';
import 'workout_screen.dart';

class WorkoutTemplatesScreen extends StatefulWidget {
  const WorkoutTemplatesScreen({super.key});

  @override
  State<WorkoutTemplatesScreen> createState() => _WorkoutTemplatesScreenState();
}

class _WorkoutTemplatesScreenState extends State<WorkoutTemplatesScreen> {
  List<Map<String, dynamic>> _templates = [];
  bool _isLoading = true;
  List<Exercise> _exercises = [];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final exercises = await DatabaseHelper.instance.getExercises();
    setState(() {
      _exercises = exercises;
    });
  }

  Future<void> _loadTemplates() async {
    final templates = await DatabaseHelper.instance.getWorkoutTemplates();
    setState(() {
      _templates = templates;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('训练模板'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? _buildEmptyState(theme)
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final template = _templates[index];
                    return FadeInUp(
                      delay: Duration(milliseconds: index * 50),
                      child: _buildTemplateCard(template, theme),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTemplateDialog,
        icon: const Icon(Icons.add),
        label: const Text('新建模板'),
        elevation: 4,
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: FadeInUp(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 72,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 20),
            Text(
              '还没有训练模板',
              style: TextStyle(
                  fontSize: 16, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右下角按钮创建新模板',
              style: TextStyle(
                  fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // 显示创建模板对话框
  void _showCreateTemplateDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _CreateTemplateBottomSheet(
          exercises: _exercises,
          onTemplateCreated: () {
            _loadTemplates();
          },
          scrollController: scrollController,
        ),
      ),
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template, ThemeData theme) {
    final name = template['name'] as String;
    final bodyPart = template['bodyPart'] as String;
    final exercisesJson = template['exercisesJson'] as String;
    final createdAt = DateTime.parse(template['createdAt'] as String);

    final List<dynamic> exercises = jsonDecode(exercisesJson);

    return Card(
      elevation: 2,
      shadowColor: theme.colorScheme.shadow.withAlpha(76),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _useTemplate(template),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => _deleteTemplate(template['id'] as int),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '部位: $bodyPart',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              // 显示动作详情（包含重量、次数、组数）
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: exercises.map((exercise) {
                  final weight = exercise['weight'] ?? 0;
                  final reps = exercise['reps'] ?? 0;
                  final sets = exercise['sets'] ?? 1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            exercise['exerciseName'] as String,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Text(
                          '$weight kg × $reps 次 × $sets 组',
                          style: TextStyle(
                              fontSize: 11, color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                '创建时间: ${_formatDate(createdAt)}',
                style: TextStyle(
                    fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  void _useTemplate(Map<String, dynamic> template) async {
    final bodyPart = template['bodyPart'] as String;
    final exercisesJson = template['exercisesJson'] as String;
    final List<dynamic> exercises = jsonDecode(exercisesJson);

    // 导航到训练页面并传入模板数据
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutScreen(
          templateBodyPart: bodyPart,
          templateExercises: exercises.cast<Map<String, dynamic>>(),
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _deleteTemplate(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除模板'),
        content: const Text('确定要删除这个训练模板吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteWorkoutTemplate(id);
      _loadTemplates();
    }
  }
}

// 创建模板底部弹窗
class _CreateTemplateBottomSheet extends StatefulWidget {
  final List<Exercise> exercises;
  final VoidCallback onTemplateCreated;
  final ScrollController scrollController;

  const _CreateTemplateBottomSheet({
    required this.exercises,
    required this.onTemplateCreated,
    required this.scrollController,
  });

  @override
  State<_CreateTemplateBottomSheet> createState() =>
      _CreateTemplateBottomSheetState();
}

// 模板动作配置类
class TemplateExerciseConfig {
  final Exercise exercise;
  double weight;
  int reps;
  int sets;

  TemplateExerciseConfig({
    required this.exercise,
    this.weight = 0,
    this.reps = 0,
    this.sets = 1,
  });
}

class _CreateTemplateBottomSheetState
    extends State<_CreateTemplateBottomSheet> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedBodyPart;
  final List<TemplateExerciseConfig> _selectedExercises = [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部固定区域
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
          const SizedBox(height: 16),
          const Text(
            '新建训练模板',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          // 模板名称输入
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: _nameController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: '模板名称',
                hintStyle: TextStyle(
                    fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 训练部位选择
          const Text('选择训练部位', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: ExerciseData.getAllTags().map((tag) {
              final isSelected = _selectedBodyPart == tag;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Material(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedBodyPart = isSelected ? null : tag;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          ExerciseData.getTagDisplayName(tag),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              color: isSelected
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurface,
                              fontWeight: isSelected ? FontWeight.w600 : null),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // 动作选择标题
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('选择动作', style: TextStyle(fontSize: 14)),
              if (_selectedBodyPart != null)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedExercises.clear();
                    });
                  },
                  child: const Text('清空'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // 可滚动的动作列表区域 - 使用Expanded占据大部分空间
          Expanded(
            flex: 3,
            child: _selectedBodyPart == null
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        '请先选择训练部位',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withAlpha(76),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ListView.builder(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _getFilteredExercises().length,
                      itemBuilder: (context, index) {
                        final exercise = _getFilteredExercises()[index];
                        final isSelected = _selectedExercises
                            .any((e) => e.exercise.id == exercise.id);
                        return CheckboxListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          title: Text(
                            exercise.name,
                            style: const TextStyle(fontSize: 14),
                          ),
                          value: isSelected,
                          onChanged: (value) async {
                            if (value == true) {
                              // 显示配置弹窗
                              final config =
                                  await _showExerciseConfigDialog(exercise);
                              if (config != null) {
                                setState(() {
                                  _selectedExercises.add(config);
                                });
                              }
                            } else {
                              setState(() {
                                _selectedExercises.removeWhere(
                                    (e) => e.exercise.id == exercise.id);
                              });
                            }
                          },
                        );
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          // 已选择的动作列表（可编辑）- 使用Wrap显示为标签
          if (_selectedExercises.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 100),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedExercises.asMap().entries.map((entry) {
                    final index = entry.key;
                    final config = entry.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.primary.withAlpha(76),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            config.exercise.name,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${config.weight}kg×${config.reps}次',
                            style: TextStyle(
                                fontSize: 11, color: theme.colorScheme.primary),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _editExerciseConfig(index),
                            child: Icon(
                              Icons.edit,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedExercises.removeAt(index);
                              });
                            },
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 8),
          // 保存按钮 - 固定在底部
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedExercises.isEmpty ||
                      _nameController.text.isEmpty ||
                      _selectedBodyPart == null
                  ? null
                  : _saveTemplate,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                '保存模板',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Exercise> _getFilteredExercises() {
    if (_selectedBodyPart == null) return [];
    return widget.exercises.where((e) => e.tag == _selectedBodyPart).toList();
  }

  // 显示动作配置弹窗
  Future<TemplateExerciseConfig?> _showExerciseConfigDialog(
      Exercise exercise) async {
    final weightController = TextEditingController();
    final repsController = TextEditingController();
    final setsController = TextEditingController(text: '1');

    return showModalBottomSheet<TemplateExerciseConfig?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    exercise.name,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // 输入区域
              Row(
                children: [
                  // 重量
                  Expanded(
                    child: _buildConfigInput(
                      controller: weightController,
                      label: '重量',
                      unit: 'kg',
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 次数
                  Expanded(
                    child: _buildConfigInput(
                      controller: repsController,
                      label: '次数',
                      unit: '次',
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 组数
                  Expanded(
                    child: _buildConfigInput(
                      controller: setsController,
                      label: '组数',
                      unit: '组',
                      theme: theme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // 按钮
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, null),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final weight =
                            double.tryParse(weightController.text) ?? 0;
                        final reps = int.tryParse(repsController.text) ?? 0;
                        final sets = int.tryParse(setsController.text) ?? 1;

                        Navigator.pop(
                          context,
                          TemplateExerciseConfig(
                            exercise: exercise,
                            weight: weight,
                            reps: reps,
                            sets: sets,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('确定'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // 构建配置输入框
  Widget _buildConfigInput({
    required TextEditingController controller,
    required String label,
    required String unit,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(
                        fontSize: 22,
                        color: theme.colorScheme.onSurfaceVariant),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Text(
                unit,
                style: TextStyle(
                    fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 编辑动作配置
  Future<void> _editExerciseConfig(int index) async {
    final config = _selectedExercises[index];
    final weightController =
        TextEditingController(text: config.weight.toString());
    final repsController = TextEditingController(text: config.reps.toString());
    final setsController = TextEditingController(text: config.sets.toString());

    final result = await showModalBottomSheet<TemplateExerciseConfig?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '编辑 ${config.exercise.name}',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // 输入区域
              Row(
                children: [
                  // 重量
                  Expanded(
                    child: _buildConfigInput(
                      controller: weightController,
                      label: '重量',
                      unit: 'kg',
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 次数
                  Expanded(
                    child: _buildConfigInput(
                      controller: repsController,
                      label: '次数',
                      unit: '次',
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 组数
                  Expanded(
                    child: _buildConfigInput(
                      controller: setsController,
                      label: '组数',
                      unit: '组',
                      theme: theme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // 按钮
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, null),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final weight =
                            double.tryParse(weightController.text) ?? 0;
                        final reps = int.tryParse(repsController.text) ?? 0;
                        final sets = int.tryParse(setsController.text) ?? 1;

                        Navigator.pop(
                          context,
                          TemplateExerciseConfig(
                            exercise: config.exercise,
                            weight: weight,
                            reps: reps,
                            sets: sets,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedExercises[index] = result;
      });
    }
  }

  Future<void> _saveTemplate() async {
    final exercisesData = _selectedExercises.map((config) {
      return {
        'exerciseId': config.exercise.id,
        'exerciseName': config.exercise.name,
        'exerciseTag': config.exercise.tag,
        'weight': config.weight,
        'reps': config.reps,
        'sets': config.sets,
      };
    }).toList();

    await DatabaseHelper.instance.saveWorkoutTemplate(
      name: _nameController.text,
      bodyPart: _selectedBodyPart!,
      exercises: exercisesData,
    );

    if (mounted) {
      Navigator.pop(context);
      widget.onTemplateCreated();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('模板已保存')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/workout_record.dart';
import '../data/exercise_data.dart';
import '../services/update_service.dart';
import 'personal_data_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<WorkoutRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final records = await DatabaseHelper.instance.getWorkoutRecords();
    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  int get _totalWorkouts => _records.length;

  int get _totalDuration =>
      _records.fold(0, (sum, r) => sum + r.durationMinutes);

  int get _totalSets =>
      _records.fold(0, (sum, r) => sum + r.exerciseSets.length);

  double get _avgFatigue {
    if (_records.isEmpty) return 0;
    return _records.fold(0, (sum, r) => sum + r.fatigueLevel) / _records.length;
  }

  Map<String, int> get _bodyPartStats {
    final Map<String, int> stats = {};
    for (var record in _records) {
      stats[record.bodyPart] = (stats[record.bodyPart] ?? 0) + 1;
    }
    return stats;
  }

  String get _favoriteBodyPart {
    if (_bodyPartStats.isEmpty) return '-';
    final sorted = _bodyPartStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ExerciseData.getTagDisplayName(sorted.first.key);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                color: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surface,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildHeader(theme),
                    ),
                    SliverToBoxAdapter(
                      child: _buildStatsGrid(theme),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
                        child: Text(
                          '设置',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _buildSettingsList(theme),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 32),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              Icons.fitness_center,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '健身达人',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '已坚持训练 $_totalWorkouts 次',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child:
                      _buildStatCard('总训练时长', '$_totalDuration', '分钟', theme)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('总组数', '$_totalSets', '组', theme)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildStatCard(
                  '平均疲劳度',
                  _avgFatigue.toStringAsFixed(1),
                  '/10',
                  theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '最常练',
                  _favoriteBodyPart,
                  '部位',
                  theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, String unit, ThemeData theme) {
    return Card(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 110),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsList(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _buildSettingItem(
              icon: Icons.monitor_weight_outlined,
              title: '个人数据',
              subtitle: '记录体重、身高、体脂等数据',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PersonalDataScreen(),
                  ),
                );
              },
              theme: theme,
            ),
            const Divider(height: 1, indent: 56),
            _buildSettingItem(
              icon: Icons.file_download_outlined,
              title: '导出备份',
              subtitle: '导出所有数据为JSON备份文件',
              onTap: _exportBackup,
              theme: theme,
            ),
            const Divider(height: 1, indent: 56),
            _buildSettingItem(
              icon: Icons.file_upload_outlined,
              title: '导入备份',
              subtitle: '从JSON备份文件恢复数据',
              onTap: _importBackup,
              theme: theme,
            ),
            const Divider(height: 1, indent: 56),
            _buildSettingItem(
              icon: Icons.notifications_outlined,
              title: '休息提醒',
              subtitle: '训练结束后2分钟提醒',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('休息提醒已开启')),
                );
              },
              theme: theme,
            ),
            const Divider(height: 1, indent: 56),
            _buildSettingItem(
              icon: Icons.system_update_outlined,
              title: '检查更新',
              subtitle: '检查是否有新版本可用',
              onTap: _checkForUpdate,
              theme: theme,
            ),
            const Divider(height: 1, indent: 56),
            _buildSettingItem(
              icon: Icons.delete_outline,
              title: '删除所有记录',
              subtitle: '清除所有训练数据、计划、模板及身体数据',
              onTap: _deleteAllRecords,
              theme: theme,
            ),
            const Divider(height: 1, indent: 56),
            _buildSettingItem(
              icon: Icons.info_outline,
              title: '关于',
              subtitle: 'Gym Copilot v1.0.0',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Gym Copilot',
                  applicationVersion: '1.0.0',
                  applicationIcon: Icon(
                    Icons.fitness_center,
                    color: theme.colorScheme.primary,
                  ),
                  children: [
                    const Text('你的智能健身助手'),
                  ],
                );
              },
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall,
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }

  void _checkForUpdate() async {
    final service = UpdateService.instance;
    if (!service.isSupported) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前平台不支持热更新')),
        );
      }
      return;
    }

    await service.checkForUpdate();

    if (!mounted) return;

    switch (UpdateService.statusNotifier.value) {
      case UpdateStatus.updateAvailable:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('发现新版本'),
            content: const Text('检测到可用的更新补丁，是否立即下载？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('稍后'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('下载'),
              ),
            ],
          ),
        );

        if (confirmed == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('正在下载更新...')),
          );
          final success = await service.downloadUpdate();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(success
                    ? '更新已就绪，重启应用后生效'
                    : '下载失败，请稍后重试'),
              ),
            );
          }
        }
        break;
      case UpdateStatus.upToDate:
        final patchNum = await service.currentPatchVersion;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已是最新版本 (补丁 #${patchNum ?? 0})'),
            ),
          );
        }
        break;
      case UpdateStatus.error:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('检查更新失败，请检查网络连接')),
        );
        break;
      default:
        break;
    }
  }

  void _deleteAllRecords() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除所有记录'),
        content: const Text('确定要删除所有训练记录、训练计划、模板和个人身体数据吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除所有'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteAllRecords();
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('所有记录已删除')),
        );
      }
    }
  }

  Future<void> _exportBackup() async {
    final data = await DatabaseHelper.instance.exportAllData();

    if (!mounted) return;

    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无数据可导出')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出备份'),
        content: const Text('备份数据包含你的体重、体脂等个人身体数据，将以明文JSON格式导出。请妥善保管，勿在不信任的环境中分享。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('继续导出'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final jsonString = const JsonEncoder.withIndent('  ').convert(data);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出备份'),
        content: Container(
          constraints: const BoxConstraints(maxHeight: 400, maxWidth: double.maxFinite),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '将下方JSON文本复制保存，更新版本后可导入恢复数据',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      jsonString,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _importBackup() async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入备份'),
        content: Container(
          constraints: const BoxConstraints(maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '将之前导出的JSON文本粘贴到下方',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      hintText: '粘贴JSON数据...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('导入'),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.isNotEmpty) {
      try {
        final data = jsonDecode(controller.text) as Map<String, dynamic>;

        if (data['version'] == null) {
          throw Exception('无效的备份文件');
        }

        await DatabaseHelper.instance.importAllData(data);

        _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('数据导入成功')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('导入失败: $e')),
          );
        }
      }
    }

    controller.dispose();
  }
}

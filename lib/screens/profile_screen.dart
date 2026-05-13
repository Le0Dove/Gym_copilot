import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

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
  String _appVersion = '1.0.0';

  static const Color _bgColor = Color(0xFF0B0F19);
  static const Color _surfaceColor = Color(0xFF1A1F2E);
  static const Color _surfaceVariant = Color(0xFF242B3D);
  static const Color _primaryColor = Color(0xFFF97316);
  static const Color _foregroundColor = Color(0xFFF8FAFC);
  static const Color _mutedColor = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFF2D3748);

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final version = await UpdateService.instance.currentVersion;
    if (mounted) {
      setState(() {
        _appVersion = version;
      });
    }
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
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _primaryColor))
            : RefreshIndicator(
                onRefresh: _loadData,
                color: _primaryColor,
                backgroundColor: _surfaceColor,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: FadeInDown(
                        duration: const Duration(milliseconds: 600),
                        child: _buildHeader(),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        delay: const Duration(milliseconds: 100),
                        child: _buildStatsGrid(),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: FadeInLeft(
                        duration: const Duration(milliseconds: 500),
                        delay: const Duration(milliseconds: 200),
                        child: const Padding(
                          padding: EdgeInsets.fromLTRB(20, 32, 20, 12),
                          child: Text(
                            '设置',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: _foregroundColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        delay: const Duration(milliseconds: 300),
                        child: _buildSettingsList(),
                      ),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: _surfaceVariant,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withAlpha(38),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.fitness_center,
              size: 40,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '健身达人',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: _foregroundColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '已坚持训练 $_totalWorkouts 次',
            style: const TextStyle(
              fontSize: 14,
              color: _mutedColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: _buildStatCard(
                      '总训练时长', '$_totalDuration', '分钟')),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('总组数', '$_totalSets', '组')),
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
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '最常练',
                  _favoriteBodyPart,
                  '部位',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String unit) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
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
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _mutedColor,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                      height: 1.1,
                      color: _foregroundColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _mutedColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderColor),
        ),
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
            ),
            const Divider(height: 1, indent: 56, color: _borderColor),
            _buildSettingItem(
              icon: Icons.file_download_outlined,
              title: '导出备份',
              subtitle: '导出所有数据为JSON备份文件',
              onTap: _exportBackup,
            ),
            const Divider(height: 1, indent: 56, color: _borderColor),
            _buildSettingItem(
              icon: Icons.file_upload_outlined,
              title: '导入备份',
              subtitle: '从JSON备份文件恢复数据',
              onTap: _importBackup,
            ),
            const Divider(height: 1, indent: 56, color: _borderColor),
            _buildSettingItem(
              icon: Icons.system_update_outlined,
              title: '检查更新',
              subtitle: '检查是否有新版本可用',
              onTap: _checkForUpdate,
            ),
            const Divider(height: 1, indent: 56, color: _borderColor),
            _buildSettingItem(
              icon: Icons.delete_outline,
              title: '删除所有记录',
              subtitle: '清除所有训练数据、计划、模板及身体数据',
              onTap: _deleteAllRecords,
            ),
            const Divider(height: 1, indent: 56, color: _borderColor),
            _buildSettingItem(
              icon: Icons.info_outline,
              title: '关于',
              subtitle: 'Gym Copilot v$_appVersion',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Gym Copilot',
                  applicationVersion: _appVersion,
                  applicationIcon: const Icon(
                    Icons.fitness_center,
                    color: _primaryColor,
                  ),
                  children: [
                    const Text(
                      '你的智能健身助手',
                      style: TextStyle(color: _foregroundColor),
                    ),
                  ],
                );
              },
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
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _surfaceVariant.withAlpha(153),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: _primaryColor,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _foregroundColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: _mutedColor,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: _mutedColor,
      ),
      onTap: onTap,
    );
  }

  void _checkForUpdate() async {
    final service = UpdateService.instance;
    if (!service.isSupported) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('当前平台不支持热更新'),
            backgroundColor: _surfaceVariant,
          ),
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
            backgroundColor: _surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: _borderColor),
            ),
            title: const Text(
              '发现新版本',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _foregroundColor,
              ),
            ),
            content: const Text(
              '检测到可用的更新补丁，是否立即下载？',
              style: TextStyle(color: _foregroundColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  '稍后',
                  style: TextStyle(color: _mutedColor),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  '下载',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );

        if (confirmed == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('正在下载更新...'),
              backgroundColor: _surfaceVariant,
            ),
          );
          final success = await service.downloadUpdate();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  success ? '更新已就绪，重启应用后生效' : '下载失败，请稍后重试',
                  style: const TextStyle(),
                ),
                backgroundColor: _surfaceVariant,
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
              content: Text(
                '已是最新版本 (补丁 #${patchNum ?? 0})',
                style: const TextStyle(),
              ),
              backgroundColor: _surfaceVariant,
            ),
          );
        }
        break;
      case UpdateStatus.error:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '检查更新失败，请检查网络连接',
              style: TextStyle(),
            ),
            backgroundColor: _surfaceVariant,
          ),
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
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _borderColor),
        ),
        title: const Text(
          '删除所有记录',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _foregroundColor,
          ),
        ),
        content: const Text(
          '确定要删除所有训练记录、训练计划、模板和个人身体数据吗？此操作不可恢复。',
          style: TextStyle(color: _foregroundColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              '取消',
              style: TextStyle(color: _mutedColor),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '删除所有',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteAllRecords();
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '所有记录已删除',
              style: TextStyle(),
            ),
            backgroundColor: _surfaceVariant,
          ),
        );
      }
    }
  }

  Future<void> _exportBackup() async {
    final data = await DatabaseHelper.instance.exportAllData();

    if (!mounted) return;

    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '暂无数据可导出',
            style: TextStyle(),
          ),
          backgroundColor: _surfaceVariant,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _borderColor),
        ),
        title: const Text(
          '导出备份',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _foregroundColor,
          ),
        ),
        content: const Text(
          '备份数据包含你的体重、体脂等个人身体数据，将以明文JSON格式导出。请妥善保管，勿在不信任的环境中分享。',
          style: TextStyle(color: _foregroundColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              '取消',
              style: TextStyle(color: _mutedColor),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '继续导出',
              style: TextStyle(color: Colors.white),
            ),
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
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _borderColor),
        ),
        title: const Text(
          '导出备份',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _foregroundColor,
          ),
        ),
        content: Container(
          constraints: const BoxConstraints(
              maxHeight: 400, maxWidth: double.maxFinite),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '将下方JSON文本复制保存，更新版本后可导入恢复数据',
                style: TextStyle(
                  fontSize: 12,
                  color: _mutedColor,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _borderColor),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      jsonString,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _foregroundColor,
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
            child: const Text(
              '关闭',
              style: TextStyle(color: _mutedColor),
            ),
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
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _borderColor),
        ),
        title: const Text(
          '导入备份',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _foregroundColor,
          ),
        ),
        content: Container(
          constraints: const BoxConstraints(maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '将之前导出的JSON文本粘贴到下方',
                style: TextStyle(
                  fontSize: 12,
                  color: _mutedColor,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _borderColor),
                  ),
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(color: _foregroundColor),
                    decoration: const InputDecoration(
                      hintText: '粘贴JSON数据...',
                      hintStyle: TextStyle(color: _mutedColor),
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
            child: const Text(
              '取消',
              style: TextStyle(color: _mutedColor),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '导入',
              style: TextStyle(color: Colors.white),
            ),
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
            const SnackBar(
              content: Text(
                '数据导入成功',
                style: TextStyle(),
              ),
              backgroundColor: _surfaceVariant,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '导入失败: $e',
                style: const TextStyle(),
              ),
              backgroundColor: _surfaceVariant,
            ),
          );
        }
      }
    }

    controller.dispose();
  }
}

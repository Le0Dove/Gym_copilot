import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:animate_do/animate_do.dart';

import '../database/database_helper.dart';
import '../models/exercise.dart';
import '../data/exercise_data.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (widget.exercise.id == null) return;
    final history =
        await DatabaseHelper.instance.getExerciseHistory(widget.exercise.id!);
    if (mounted) {
      setState(() {
        _history = history;
        _isLoading = false;
      });
    }
  }

  double get _bestWeight {
    if (_history.isEmpty) return 0;
    return _history
        .map((r) => (r['weight'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);
  }

  int get _bestReps {
    if (_history.isEmpty) return 0;
    return _history
        .map((r) => r['reps'] as int)
        .reduce((a, b) => a > b ? a : b);
  }

  /// 数据点：按日期聚合，取每天的最大重量
  List<FlSpot> get _weightSpots {
    if (_history.isEmpty) return [];

    final dailyMax = <DateTime, double>{};
    for (final r in _history) {
      final dt = DateTime.parse(r['dateTime'] as String);
      final date = DateTime(dt.year, dt.month, dt.day);
      final weight = (r['weight'] as num).toDouble();
      if (!dailyMax.containsKey(date) || weight > dailyMax[date]!) {
        dailyMax[date] = weight;
      }
    }

    final sorted = dailyMax.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return List.generate(sorted.length, (i) {
      return FlSpot(i.toDouble(), sorted[i].value);
    });
  }

  List<String> get _dateLabels {
    final dailyMax = <DateTime, double>{};
    for (final r in _history) {
      final dt = DateTime.parse(r['dateTime'] as String);
      final date = DateTime(dt.year, dt.month, dt.day);
      final weight = (r['weight'] as num).toDouble();
      if (!dailyMax.containsKey(date) || weight > dailyMax[date]!) {
        dailyMax[date] = weight;
      }
    }
    final sorted = dailyMax.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return sorted.map((e) => DateFormat('M/d').format(e.key)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.exercise.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(theme),
                  _buildStatsCards(theme),
                  _buildWeightChart(theme),
                  _buildHistoryList(theme),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final tagColor = _getTagColor(widget.exercise.tag);

    return FadeInDown(
      duration: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                tagColor.withAlpha(38),
                tagColor.withAlpha(7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: tagColor.withAlpha(51),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: tagColor.withAlpha(51),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _getTagIcon(widget.exercise.tag),
                  color: tagColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.exercise.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: tagColor.withAlpha(38),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            ExerciseData.getTagDisplayName(widget.exercise.tag),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: tagColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (widget.exercise.targetMuscles.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.exercise.targetMuscles,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards(ThemeData theme) {
    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      delay: const Duration(milliseconds: 100),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          children: [
            Expanded(
              child: _buildSingleStatCard(
                '${_bestWeight.toStringAsFixed(1)} kg',
                '最佳重量',
                Icons.monitor_weight_outlined,
                theme.colorScheme.primary,
                theme,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSingleStatCard(
                '$_bestReps 次',
                '最多次数',
                Icons.repeat,
                const Color(0xFF4FC3F7),
                theme,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withAlpha(30),
            color.withAlpha(10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withAlpha(38),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color.withAlpha(178)),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightChart(ThemeData theme) {
    if (_history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withAlpha(51),
              width: 1,
            ),
          ),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.show_chart,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(76),
                ),
                const SizedBox(height: 16),
                Text(
                  '暂无训练数据',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '开始训练后将显示重量趋势图',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(178),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final spots = _weightSpots;
    final labels = _dateLabels;
    final maxWeight = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      delay: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '重量趋势',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '每次训练最大重量变化',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 240,
              padding: const EdgeInsets.fromLTRB(16, 20, 20, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.surface,
                    theme.colorScheme.surface.withAlpha(204),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withAlpha(51),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(38),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxWeight / 5,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.colorScheme.outline.withAlpha(38),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: maxWeight > 20 ? maxWeight / 4 : 10,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              '${value.toInt()}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: spots.length > 7 ? (spots.length / 5).ceilToDouble() : 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= labels.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              labels[idx],
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: theme.colorScheme.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: spots.length <= 14,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: theme.colorScheme.primary,
                            strokeWidth: 2,
                            strokeColor: theme.colorScheme.surface,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withAlpha(51),
                            theme.colorScheme.primary.withAlpha(0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) => theme.colorScheme.surfaceContainerHighest,
                      getTooltipItems: (spots) {
                        return spots.map((spot) {
                          final idx = spot.x.toInt();
                          final dateStr = idx >= 0 && idx < labels.length
                              ? labels[idx]
                              : '';
                          return LineTooltipItem(
                            '$dateStr\n${spot.y.toStringAsFixed(1)} kg',
                            TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(ThemeData theme) {
    if (_history.isEmpty) return const SizedBox.shrink();

    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      delay: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '训练历史',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '共 ${_history.length} 组记录',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ..._history.map((record) {
              final dateTime = DateTime.parse(record['dateTime'] as String);
              final weight = (record['weight'] as num).toDouble();
              final reps = record['reps'] as int;
              final setNumber = record['setNumber'] as int;
              final fatigueLevel = record['fatigueLevel'] as int;
              final volume = weight * reps;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.surfaceContainerHighest.withAlpha(102),
                      theme.colorScheme.surfaceContainerHighest.withAlpha(38),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.colorScheme.outline.withAlpha(38),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(38),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '#$setNumber',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${weight.toStringAsFixed(1)} kg',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '  ×  $reps 次',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('MM/dd HH:mm').format(dateTime),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          volume.toStringAsFixed(0),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'kg·次',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getFatigueColor(fatigueLevel).withAlpha(38),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'RPE$fatigueLevel',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _getFatigueColor(fatigueLevel),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getFatigueColor(int level) {
    if (level <= 3) return const Color(0xFF4CAF50);
    if (level <= 6) return const Color(0xFFFFB74D);
    if (level <= 8) return const Color(0xFFFF6B35);
    return const Color(0xFFEF4444);
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

  IconData _getTagIcon(String tag) {
    final icons = {
      'chest': Icons.accessibility_new,
      'back': Icons.airline_seat_flat,
      'legs': Icons.directions_run,
      'shoulders': Icons.front_hand,
      'arms': Icons.sports_martial_arts,
      'core': Icons.fitness_center,
    };
    return icons[tag] ?? Icons.fitness_center;
  }
}

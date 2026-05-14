import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';

import '../database/database_helper.dart';

class WorkoutCalendarScreen extends StatefulWidget {
  const WorkoutCalendarScreen({super.key});

  @override
  State<WorkoutCalendarScreen> createState() => _WorkoutCalendarScreenState();
}

class _WorkoutCalendarScreenState extends State<WorkoutCalendarScreen> {
  DateTime _currentMonth = DateTime.now();
  List<DateTime> _workoutDates = [];
  bool _isLoading = true;
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalWorkouts = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final dates = await DatabaseHelper.instance.getUniqueWorkoutDates();
    final currentStreak = await DatabaseHelper.instance.getCurrentStreak();
    final longestStreak = await DatabaseHelper.instance.getLongestStreak();

    setState(() {
      _workoutDates = dates;
      _currentStreak = currentStreak;
      _longestStreak = longestStreak;
      _totalWorkouts = dates.length;
      _isLoading = false;
    });
  }

  Future<void> _loadMonthData() async {
    final dates = await DatabaseHelper.instance.getWorkoutDatesInMonth(
      _currentMonth.year,
      _currentMonth.month,
    );
    setState(() {
      _workoutDates = dates;
    });
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _loadMonthData();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _loadMonthData();
  }

  bool _isWorkoutDay(DateTime date) {
    return _workoutDates.any((d) =>
        d.year == date.year && d.month == date.month && d.day == date.day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('训练日历'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildStatsCards(theme),
                ),
                SliverToBoxAdapter(
                  child: _buildCalendar(theme),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 40),
                ),
              ],
            ),
    );
  }

  Widget _buildStatsCards(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              '$_currentStreak',
              '当前连续',
              Icons.local_fire_department,
              const Color(0xFFFF6B35),
              theme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              '$_longestStreak',
              '最长纪录',
              Icons.emoji_events,
              const Color(0xFFFFD700),
              theme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              '$_totalWorkouts',
              '总训练日',
              Icons.fitness_center,
              theme.colorScheme.primary,
              theme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withAlpha(38),
            color.withAlpha(12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withAlpha(51),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(ThemeData theme) {
    final daysInMonth = _getDaysInMonth(_currentMonth);
    final firstWeekday = daysInMonth.first.weekday % 7;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // 月份导航
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _previousMonth,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                DateFormat('yyyy年MM月').format(_currentMonth),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: _nextMonth,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 星期标题
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['日', '一', '二', '三', '四', '五', '六']
                .map((day) => SizedBox(
                      width: 36,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // 日期网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: daysInMonth.length + firstWeekday,
            itemBuilder: (context, index) {
              if (index < firstWeekday) {
                return const SizedBox.shrink();
              }
              final day = daysInMonth[index - firstWeekday];
              final isWorkout = _isWorkoutDay(day);
              final isToday = day.isAtSameMomentAs(today);

              return FadeInUp(
                duration: const Duration(milliseconds: 300),
                delay: Duration(milliseconds: index * 20),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isWorkout
                        ? const Color(0xFFFF6B35).withAlpha(204)
                        : isToday
                            ? theme.colorScheme.primary.withAlpha(51)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday
                        ? Border.all(
                            color: theme.colorScheme.primary,
                            width: 2,
                          )
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isWorkout || isToday ? FontWeight.w700 : FontWeight.w400,
                        color: isWorkout
                            ? Colors.white
                            : isToday
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          // 图例
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withAlpha(204),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '训练日',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 20),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(51),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '今天',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<DateTime> _getDaysInMonth(DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final days = <DateTime>[];
    for (int i = 1; i <= lastDay.day; i++) {
      days.add(DateTime(month.year, month.month, i));
    }
    return days;
  }
}

import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';

class PersonalDataScreen extends StatefulWidget {
  const PersonalDataScreen({super.key});

  @override
  State<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends State<PersonalDataScreen> {
  List<Map<String, dynamic>> _bodyData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await DatabaseHelper.instance.getBodyData();
    data.sort((a, b) {
      final dateA = DateTime.parse(a['recordDate'] as String);
      final dateB = DateTime.parse(b['recordDate'] as String);
      return dateB.compareTo(dateA);
    });
    setState(() {
      _bodyData = data;
      _isLoading = false;
    });
  }

  Map<String, dynamic>? get _latestData =>
      _bodyData.isEmpty ? null : _bodyData.first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('个人数据'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              color: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surface,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildLatestCard(theme),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '历史记录',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w600),
                          ),
                          TextButton.icon(
                            onPressed: _showAddDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('记录'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _bodyData.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: FadeInUp(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.monitor_weight_outlined,
                                      size: 72,
                                      color: theme.colorScheme.onSurfaceVariant
                                          .withAlpha(127),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      '暂无身体数据',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: theme
                                              .colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : SliverList.builder(
                          itemCount: _bodyData.length,
                          itemBuilder: (context, index) {
                            return FadeInUp(
                              delay: Duration(milliseconds: index * 50),
                              child: _buildHistoryItem(_bodyData[index], theme),
                            );
                          },
                        ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 32),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLatestCard(ThemeData theme) {
    final data = _latestData;

    return FadeInUp(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '最新数据',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    if (data != null)
                      Text(
                        data['recordDate'] as String,
                        style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                if (data == null)
                  Center(
                    child: Text(
                      '点击右上角记录第一条数据',
                      style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildDataItem(
                        '体重',
                        data['weight']?.toString() ?? '-',
                        'kg',
                        Icons.monitor_weight_outlined,
                        theme,
                      ),
                      _buildDataItem(
                        '身高',
                        data['height']?.toString() ?? '-',
                        'cm',
                        Icons.height_outlined,
                        theme,
                      ),
                      _buildDataItem(
                        '体脂',
                        data['bodyFat']?.toString() ?? '-',
                        '%',
                        Icons.percent_outlined,
                        theme,
                      ),
                      _buildDataItem(
                        '肌肉',
                        data['muscleMass']?.toString() ?? '-',
                        'kg',
                        Icons.fitness_center_outlined,
                        theme,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataItem(
    String label,
    String value,
    String unit,
    IconData icon,
    ThemeData theme,
  ) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                    fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> data, ThemeData theme) {
    final date = data['recordDate'] as String;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Card(
        elevation: 1,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(
            date,
            style: const TextStyle(fontSize: 14),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 16,
              children: [
                if (data['weight'] != null)
                  _buildTag('体重 ${data['weight']}kg', theme),
                if (data['height'] != null)
                  _buildTag('身高 ${data['height']}cm', theme),
                if (data['bodyFat'] != null)
                  _buildTag('体脂 ${data['bodyFat']}%', theme),
                if (data['muscleMass'] != null)
                  _buildTag('肌肉 ${data['muscleMass']}kg', theme),
              ],
            ),
          ),
          trailing: IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: theme.colorScheme.error.withAlpha(178),
            ),
            onPressed: () => _deleteItem(data['id'] as int),
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }

  void _showAddDialog() {
    final weightController = TextEditingController();
    final heightController = TextEditingController();
    final bodyFatController = TextEditingController();
    final muscleMassController = TextEditingController();
    final dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );

    showModalBottomSheet(
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
              const Text(
                '记录身体数据',
                style: TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 24),
              _buildInputField('日期', dateController, theme, readOnly: true,
                  onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                              surface: theme.colorScheme.surface,
                            ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                }
              }),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInputField('体重 (kg)', weightController, theme,
                        keyboardType: TextInputType.number),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInputField('身高 (cm)', heightController, theme,
                        keyboardType: TextInputType.number),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInputField('体脂 (%)', bodyFatController, theme,
                        keyboardType: TextInputType.number),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInputField(
                        '肌肉 (kg)', muscleMassController, theme,
                        keyboardType: TextInputType.number),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _saveBodyData(
                    weightController.text,
                    heightController.text,
                    bodyFatController.text,
                    muscleMassController.text,
                    dateController.text,
                  ),
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    ThemeData theme, {
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
              fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Future<void> _saveBodyData(
    String weightText,
    String heightText,
    String bodyFatText,
    String muscleMassText,
    String recordDate,
  ) async {
    final weight = double.tryParse(weightText);
    final height = double.tryParse(heightText);
    final bodyFat = double.tryParse(bodyFatText);
    final muscleMass = double.tryParse(muscleMassText);

    if (weight == null &&
        height == null &&
        bodyFat == null &&
        muscleMass == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请至少填写一项数据')),
        );
      }
      return;
    }

    await DatabaseHelper.instance.saveBodyData(
      weight: weight,
      height: height,
      bodyFat: bodyFat,
      muscleMass: muscleMass,
      recordDate: recordDate,
    );

    if (mounted) {
      Navigator.pop(context);
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('数据已保存')),
      );
    }
  }

  void _deleteItem(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定要删除这条身体数据记录吗？'),
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
      await DatabaseHelper.instance.deleteBodyData(id);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('记录已删除')),
        );
      }
    }
  }
}

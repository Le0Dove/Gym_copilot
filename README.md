# Gym Copilot

<p align="center">
  <img src="assets/logo.png" width="120" alt="Gym Copilot Logo">
</p>

<p align="center">
  <b>你的智能健身助手 · Pro Edition</b>
</p>

<p align="center">
  <a href="#功能特性">功能特性</a> •
  <a href="#安装">安装</a> •
  <a href="#技术栈">技术栈</a> •
  <a href="#项目结构">项目结构</a> •
  <a href="#热更新">热更新</a>
</p>

---

## 简介

Gym Copilot 是一款专为健身爱好者设计的 Flutter 应用，采用**力量橙**深色主题设计，帮助你记录每一次训练、管理动作库、追踪身体数据，让训练有迹可循、进步肉眼可见。

> **Pro Edition** - 集成 Shorebird 热更新，无需等待应用商店审核，随时推送功能更新至用户设备。

## 功能特性

### 训练记录
- ⏱️ 训练计时器（呼吸脉冲动画 + 发光指示器）
- 🏋️ **多部位混合训练** - 一次训练可添加胸、背、腿等多个部位的动作
- 📊 逐组记录：重量（kg）× 次数 × 组数
- 😫 疲劳度评分（1-10 可视化滑块）
- 💾 训练状态自动保存（每 10 秒），意外退出可恢复
- 🧩 训练模板一键加载

### 动作库
- 💪 **77 个内置动作**，覆盖胸、背、腿、肩、臂、腹 6 大部位
- 🎯 每个动作显示目标肌群（如：杠铃卧推 → 胸大肌、肩前束、肱三头肌）
- 🔍 搜索 + 部位筛选
- 📈 按使用次数智能排序，常用动作优先
- 📋 查看动作历史记录
- ➕ 支持添加自定义动作

### 训练模板
- 📝 创建个性化训练模板
- ⚙️ 为每个动作预设：重量、次数、组数
- 🚀 一键加载模板开始训练
- 🏷️ 标签式管理动作列表

### 个人数据中心
- 📏 记录体重、身高、体脂率、肌肉量
- 📈 历史趋势追踪
- 📅 日期选择器支持回溯记录

### 数据统计
- 📊 训练时长趋势图（近 7 天）
- 🥧 部位训练分布饼图
- 📉 疲劳度波动曲线
- 📋 总训练天数、总组数统计

### 数据备份
- 📤 **导出备份** - 生成 JSON 备份文件
- 📥 **导入备份** - 更新版本后一键恢复
- 🔄 跨版本数据迁移，防止更新丢失

### Shorebird 热更新
- 🔥 **无需重新安装** - 功能更新自动推送
- ⚡ **秒级生效** - 重启应用即可体验新功能
- 📱 **静默下载** - 后台下载，不影响使用

### 其他功能
- 🔔 训练结束 2 分钟后休息提醒
- 🌙 深色极简 UI，沉浸式体验
- 🎨 力量橙主题（#F97316）搭配深色背景

## 安装

### 方法一：直接安装 APK

1. 从 [Releases](https://github.com/Log-Cab1n/Gym_copilot/releases) 下载最新 APK
2. 允许"未知来源"安装
3. 点击 APK 完成安装

### 方法二：自行构建

```bash
git clone https://github.com/Log-Cab1n/Gym_copilot.git
cd Gym_copilot/gym_copilot
flutter pub get
flutter build apk --release
```

**环境要求：**
- Flutter SDK >= 3.19.0
- Dart SDK >= 3.3.0
- Android SDK
- Java 17

## 热更新

Gym Copilot 使用 [Shorebird](https://shorebird.dev) 实现热更新：

```bash
# 安装 Shorebird CLI
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh | bash

# 登录并创建 Release
shorebird login
shorebird release android --artifact apk --flutter-version=3.24.5

# 发布热更新补丁
shorebird patch android --flutter-version=3.24.5
```

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter 3.x + Dart |
| 状态管理 | StatefulWidget |
| 本地存储 | SQLite (sqflite) |
| 图表 | fl_chart |
| 通知 | flutter_local_notifications |
| 热更新 | Shorebird Code Push |
| 动画 | animate_do, shimmer |
| 图标 | Material Design 3 |

## 项目结构

```
gym_copilot/
├── android/            # Android 配置
├── assets/             # 图标与资源
├── lib/                # 源代码
│   ├── data/           # 内置动作数据（77 个）
│   ├── database/       # SQLite 数据库操作
│   ├── models/         # 数据模型
│   ├── screens/        # 页面
│   │   ├── home_screen.dart          # 首页
│   │   ├── workout_screen.dart       # 训练记录
│   │   ├── exercise_library_screen.dart  # 动作库
│   │   ├── stats_screen.dart         # 数据统计
│   │   ├── profile_screen.dart       # 我的
│   │   ├── plan_screen.dart          # 训练计划
│   │   ├── workout_templates_screen.dart # 训练模板
│   │   └── personal_data_screen.dart # 个人数据
│   └── services/       # 通知 & 更新服务
├── test/               # 测试
├── shorebird.yaml      # Shorebird 配置
├── pubspec.yaml        # 依赖配置
└── README.md
```

## 许可证

MIT License

---

<p align="center">Made with ❤️ for fitness enthusiasts</p>

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

enum UpdateStatus {
  checking,
  upToDate,
  updateAvailable,
  downloading,
  ready,
  error,
}

class UpdateService {
  static final UpdateService instance = UpdateService._init();

  final _shorebirdCodePush = ShorebirdCodePush();

  static final ValueNotifier<UpdateStatus> statusNotifier =
      ValueNotifier(UpdateStatus.upToDate);

  static final ValueNotifier<bool> isNewPatchReady =
      ValueNotifier(false);

  UpdateService._init();

  bool get isSupported => !kIsWeb && !Platform.isLinux && !Platform.isWindows;

  Future<void> checkForUpdate() async {
    if (!isSupported) return;

    statusNotifier.value = UpdateStatus.checking;

    try {
      final isAvailable =
          await _shorebirdCodePush.isNewPatchAvailableForDownload();

      if (!isAvailable) {
        statusNotifier.value = UpdateStatus.upToDate;
        return;
      }

      statusNotifier.value = UpdateStatus.updateAvailable;
    } catch (e) {
      debugPrint('检查更新失败: $e');
      statusNotifier.value = UpdateStatus.error;
    }
  }

  Future<bool> downloadUpdate() async {
    if (!isSupported) return false;

    statusNotifier.value = UpdateStatus.downloading;

    try {
      await _shorebirdCodePush.downloadUpdateIfAvailable();
      isNewPatchReady.value = true;
      statusNotifier.value = UpdateStatus.ready;
      return true;
    } catch (e) {
      debugPrint('下载更新失败: $e');
      statusNotifier.value = UpdateStatus.error;
      return false;
    }
  }

  Future<int?> get currentPatchVersion async {
    if (!isSupported) return null;
    return _shorebirdCodePush.currentPatchNumber();
  }

  Future<int?> get nextPatchVersion async {
    if (!isSupported) return null;
    return _shorebirdCodePush.nextPatchNumber();
  }

  Future<void> checkAndUpdateOnStartup() async {
    await checkForUpdate();

    if (statusNotifier.value == UpdateStatus.updateAvailable) {
      debugPrint('发现新版本，开始下载...');
      final success = await downloadUpdate();
      if (success) {
        debugPrint('热更新补丁已就绪，下次启动生效');
      }
    }
  }
}

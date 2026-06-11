import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:erp/services/update_service.dart';

enum UpdateStatus {
  idle,
  checking,
  upToDate,
  updateAvailable,
  downloading,
  installing,
  error,
}

class UpdateState {
  const UpdateState({
    this.status = UpdateStatus.idle,
    this.message,
    this.downloadProgress = 0.0,
    this.appVersion = 'v2.4.0',
  });

  final UpdateStatus status;
  final String? message;
  final double downloadProgress;
  final String appVersion;

  UpdateState copyWith({
    UpdateStatus? status,
    String? message,
    double? downloadProgress,
    String? appVersion,
  }) {
    return UpdateState(
      status: status ?? this.status,
      message: message ?? this.message,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      appVersion: appVersion ?? this.appVersion,
    );
  }
}

class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier() : super(const UpdateState());

  final UpdateService _updateService = UpdateService();

  Future<void> checkForUpdates() async {
    if (state.status == UpdateStatus.checking ||
        state.status == UpdateStatus.downloading) {
      return; // Already in progress
    }

    state = state.copyWith(
      status: UpdateStatus.checking,
      message: 'Checking for updates...',
    );

    final result = await _updateService.checkForUpdates(
      onProgress: (double progress) {
        state = state.copyWith(
          status: UpdateStatus.downloading,
          downloadProgress: progress,
          message: 'Downloading update... ${progress.toStringAsFixed(0)}%',
        );
      },
    );

    switch (result) {
      case UpdateResult.upToDate:
        state = state.copyWith(
          status: UpdateStatus.upToDate,
          message: 'App is up to date.',
        );
        break;
      case UpdateResult.updateAvailable:
        state = state.copyWith(
          status: UpdateStatus.updateAvailable,
          message: 'Update available! Downloading...',
        );
        break;
      case UpdateResult.downloading:
        // Progress is handled via onProgress callback above
        break;
      case UpdateResult.installing:
        state = state.copyWith(
          status: UpdateStatus.installing,
          message: 'Installing update...',
        );
        break;
      case UpdateResult.error:
        state = state.copyWith(
          status: UpdateStatus.error,
          message: 'Update check failed. Try again later.',
        );
        break;
    }
  }

  void resetStatus() {
    state = state.copyWith(
      status: UpdateStatus.idle,
      message: null,
      downloadProgress: 0.0,
    );
  }

  void clearMessage() {
    state = state.copyWith(message: null);
  }
}

final updateProvider = StateNotifierProvider<UpdateNotifier, UpdateState>(
  (_) => UpdateNotifier(),
);

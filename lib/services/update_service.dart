import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';

enum UpdateResult { upToDate, updateAvailable, downloading, installing, error }

class UpdateService {
  // Replace with your local machine IP for testing, or your production domain
  static const String _apiUrl = 'https://ms3technology.com.bd/api/app-version';

  /// Checks for updates and returns the result.
  ///
  /// Provide an [onProgress] callback to receive download progress updates
  /// (values from 0.0 to 100.0) when an update is being downloaded.
  Future<UpdateResult> checkForUpdates({
    void Function(double progress)? onProgress,
  }) async {
    try {
      // 1. Get current app version information
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      int currentVersionCode = int.parse(packageInfo.buildNumber);

      // 2. Fetch latest version info from Laravel
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final int serverVersionCode = data['version_code'];
        final String downloadUrl = data['download_url'];

        // 3. Compare version codes
        if (serverVersionCode > currentVersionCode) {
          return _executeOtaUpdate(downloadUrl, onProgress: onProgress);
        } else {
          return UpdateResult.upToDate;
        }
      } else {
        return UpdateResult.error;
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error checking for updates: $e');
      return UpdateResult.error;
    }
  }

  Future<UpdateResult> _executeOtaUpdate(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final completer = Completer<UpdateResult>();

    try {
      OtaUpdate()
          .execute(url, destinationFilename: 'app-update.apk')
          .listen(
            (OtaEvent event) {
              switch (event.status) {
                case OtaStatus.DOWNLOADING:
                  final progress = double.tryParse(event.value ?? '0') ?? 0.0;
                  onProgress?.call(progress);
                  break;
                case OtaStatus.INSTALLING:
                  completer.complete(UpdateResult.installing);
                  break;
                case OtaStatus.ALREADY_RUNNING_ERROR:
                  completer.complete(UpdateResult.error);
                  break;
                case OtaStatus.DOWNLOAD_ERROR:
                case OtaStatus.INTERNAL_ERROR:
                  if (!completer.isCompleted) {
                    completer.complete(UpdateResult.error);
                  }
                  break;
                default:
                  break;
              }
            },
            onDone: () {
              if (!completer.isCompleted) {
                completer.complete(UpdateResult.installing);
              }
            },
            onError: (e) {
              if (!completer.isCompleted) {
                completer.complete(UpdateResult.error);
              }
            },
          );

      return completer.future;
    } catch (e) {
      // ignore: avoid_print
      print('OTA Execution failed: $e');
      return UpdateResult.error;
    }
  }
}

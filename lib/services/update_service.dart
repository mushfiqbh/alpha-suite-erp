import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';

class UpdateService {
  // Replace with your local machine IP for testing, or your production domain
  static const String _apiUrl = 'https://ms3technology.com.bd/api/app-version';

  Future<void> checkForUpdates() async {
    try {
      // 1. Get current app version information
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      int currentVersionCode = int.parse(packageInfo.buildNumber); // e.g., 19

      // 2. Fetch latest version info from Laravel
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        int serverVersionCode = data['version_code']; // e.g., 20
        String downloadUrl = data['download_url'];

        // 3. Compare version codes
        if (serverVersionCode > currentVersionCode) {
          // ignore: avoid_print
          print('New version available! Triggering update...');
          _executeOtaUpdate(downloadUrl);
        } else {
          // ignore: avoid_print
          print('App is up to date.');
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error checking for updates: $e');
    }
  }

  void _executeOtaUpdate(String url) {
    try {
      OtaUpdate().execute(url, destinationFilename: 'app-update.apk').listen((
        OtaEvent event,
      ) {
        switch (event.status) {
          case OtaStatus.DOWNLOADING:
            // ignore: avoid_print
            print('Downloading from Laravel: ${event.value}%');
            break;
          case OtaStatus.INSTALLING:
            // ignore: avoid_print
            print('Download complete. Handing over to Android OS...');
            break;
          case OtaStatus.ALREADY_RUNNING_ERROR:
            // ignore: avoid_print
            print('Download is already running.');
            break;
          case OtaStatus.DOWNLOAD_ERROR:
          case OtaStatus.INTERNAL_ERROR:
            // ignore: avoid_print
            print('Update failed due to a server or download error.');
            break;
          default:
            break;
        }
      });
    } catch (e) {
      // ignore: avoid_print
      print('OTA Execution failed: $e');
    }
  }
}

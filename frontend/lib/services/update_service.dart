import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String _distributorBaseUrl =
      'https://heidyvivas.github.io/Qr_Lichen-Dreams/';

  Future<String?> getAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } on Exception catch (_) {
      return null;
    }
  }

  Future<void> openDistributor() async {
    final version = await getAppVersion();
    if (version == null) return;

    final uri = Uri.parse(_distributorBaseUrl).replace(
      queryParameters: {'version': version},
    );

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception catch (_) {
    }
  }

  String buildDistributorUrl(String version) {
    return Uri.parse(_distributorBaseUrl).replace(
      queryParameters: {'version': version},
    ).toString();
  }
}

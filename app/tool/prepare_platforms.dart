import 'dart:io';

Future<void> main() async {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (!await manifest.exists()) {
    stdout.writeln('Android runner is absent; skipping Android BLE setup.');
    return;
  }
  var xml = await manifest.readAsString();
  if (!xml.contains('android.permission.BLUETOOTH_SCAN')) {
    const permissions = '''
    <uses-feature android:name="android.hardware.bluetooth_le" android:required="false" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
''';
    final appTag = RegExp(r'<application\b');
    if (!appTag.hasMatch(xml)) throw const FormatException('Could not find application element in AndroidManifest.xml.');
    xml = xml.replaceFirst(appTag, '$permissions    <application');
    await manifest.writeAsString(xml);
  }
  final kts = File('android/app/build.gradle.kts');
  final groovy = File('android/app/build.gradle');
  final gradleFile = await kts.exists() ? kts : groovy;
  if (!await gradleFile.exists()) throw StateError('Could not find generated Android app Gradle file.');
  var gradle = await gradleFile.readAsString();
  final kp = RegExp(r'(?m)^(\s*)minSdk\s*=\s*flutter\.minSdkVersion\s*$');
  final gp = RegExp(r'(?m)^(\s*)minSdkVersion\s+flutter\.minSdkVersion\s*$');
  if (kp.hasMatch(gradle)) {
    gradle = gradle.replaceAllMapped(kp, (m) => '${m.group(1)}minSdk = 24');
  } else if (gp.hasMatch(gradle)) {
    gradle = gradle.replaceAllMapped(gp, (m) => '${m.group(1)}minSdkVersion 24');
  } else {
    final match = RegExp(r'(?m)^\s*(?:minSdk\s*=\s*|minSdkVersion\s+)(\d+)\s*$').firstMatch(gradle);
    final version = int.tryParse(match?.group(1) ?? '');
    if (version == null || version < 24) throw StateError('Could not safely set Android minSdk to 24.');
  }
  await gradleFile.writeAsString(gradle);
  stdout.writeln('Android BLE permissions and minSdk are configured.');
}

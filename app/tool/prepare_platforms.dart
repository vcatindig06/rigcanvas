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
    final applicationIndex = xml.indexOf('<application');
    if (applicationIndex < 0) {
      throw const FormatException(
        'Could not find application element in AndroidManifest.xml.',
      );
    }
    xml = '${xml.substring(0, applicationIndex)}$permissions'
        '${xml.substring(applicationIndex)}';
    await manifest.writeAsString(xml);
  }

  final kts = File('android/app/build.gradle.kts');
  final groovy = File('android/app/build.gradle');
  final gradleFile = await kts.exists() ? kts : groovy;
  if (!await gradleFile.exists()) {
    throw StateError('Could not find generated Android app Gradle file.');
  }

  var gradle = await gradleFile.readAsString();
  const kotlinTemplate = 'minSdk = flutter.minSdkVersion';
  const groovyTemplate = 'minSdkVersion flutter.minSdkVersion';

  if (gradle.contains(kotlinTemplate)) {
    gradle = gradle.replaceAll(kotlinTemplate, 'minSdk = 24');
  } else if (gradle.contains(groovyTemplate)) {
    gradle = gradle.replaceAll(groovyTemplate, 'minSdkVersion 24');
  } else if (!gradle.contains('minSdk = 24') &&
      !gradle.contains('minSdkVersion 24')) {
    throw StateError(
      'Could not safely set Android minSdk to 24 in ${gradleFile.path}.',
    );
  }

  await gradleFile.writeAsString(gradle);
  stdout.writeln('Android BLE permissions and minSdk are configured.');
}

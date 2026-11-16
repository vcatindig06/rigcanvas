import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final logger = Logger('rigcanvas-dsp')
      ..level = Level.ALL
      ..onRecord.listen((record) => print(record.message));

    final builder = CBuilder.library(
      name: 'rigcanvas_dsp',
      assetName: 'src/audio/rigcanvas_dsp_bindings.dart',
      sources: [
        'native/rigcanvas_dsp.cpp',
        'native/include/rigcanvas_dsp.h',
      ],
      includes: ['native/include'],
      language: Language.cpp,
      std: 'c++17',
      cppLinkStdLib: 'c++_static',
    );

    await builder.run(input: input, output: output, logger: logger);
  });
}

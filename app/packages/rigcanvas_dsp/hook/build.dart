import 'dart:io';

import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final logger = Logger('rigcanvas-dsp')
      ..onRecord.listen((record) => stdout.writeln(record.message));

    final builder = CBuilder.library(
      name: 'rigcanvas_dsp',
      assetName: 'src/rigcanvas_dsp_bindings.dart',
      sources: [
        'src/rigcanvas_dsp.cpp',
        'src/rigcanvas_dsp.h',
      ],
      includes: ['src'],
      language: Language.cpp,
      std: 'c++17',
      cppLinkStdLib: 'c++_static',
    );
    await builder.run(input: input, output: output, logger: logger);
  });
}

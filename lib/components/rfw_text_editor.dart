import 'package:flutter/material.dart';

import 'package:rfw/formats.dart';
import 'package:rfw/rfw.dart';

import 'package:code_text_field/code_text_field.dart';
import 'package:code_text_field/code_text_field.dart';

import 'package:highlight/languages/dart.dart';

class RfwTextEditor extends StatefulWidget {
  const RfwTextEditor({super.key});

  @override
  State<RfwTextEditor> createState() => _RfwTextEditor();
}

class _RfwTextEditor extends State<RfwTextEditor> {
  static const LibraryName coreName = LibraryName(<String>['core', 'widgets']);
  static const LibraryName materialName =
      LibraryName(<String>['material', 'widgets']);
  static const LibraryName mainName = LibraryName(<String>['main']);
  static const String _initialRfwText = '''
    // The "import" keyword is used to specify dependencies, in this case,
    // the built-in widgets that are added by initState below.
    import core.widgets;
    import material.widgets;

    widget Button = ElevatedButton(
      child: args.child,
      onPressed: event "pressed" { }
    );
    
    // The "widget" keyword is used to define a new widget constructor.
    // The "root" widget is specified as the one to render in the build
    // method below.
    widget root = Container(
      color: 0xFFFFFFFF,
      child: Center(
        child: Column(
          children: [
            Text(text: ["Hello, ", data.greet.name, "!"], textDirection: "ltr"),
            Button(child: Text(text: 'press me')),
            ...for item in data.list:
              Text(text: item)
          ]
        )
      ),
    );
  ''';

  final Runtime _runtime = Runtime();
  final DynamicContent _data = DynamicContent();
  final CodeController _codeController = CodeController(
    text: _initialRfwText,
    language: dart,
  );

  Object? _latestRfwError;

  @override
  void initState() {
    super.initState();

    _runtime
      ..update(coreName, createCoreWidgets())
      ..update(materialName, createMaterialWidgets())
      ..update(mainName, parseLibraryFile(_initialRfwText));

    _data
      ..update('greet', <String, Object>{'name': 'World'})
      ..update('list', <String>['a', 'b', 'c', 'd', 'e']);
  }

  @override
  void dispose() {
    super.dispose();
    _codeController.dispose();
  }

  void _onRfwTextChanged(String rfwText) {
    Object? rfwError;
    try {
      _runtime.update(mainName, parseLibraryFile(rfwText));
    } catch (e) {
      rfwError = e;
    } finally {
      setState(() {
        _latestRfwError = rfwError;
      });
    }
  }

  void _onRfwEvent(String name, DynamicMap arguments) {
    print('user triggered event "$name" with data: $arguments');
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        decoration: BoxDecoration(border: Border.all(color: Colors.blueAccent)),
        child: SizedBox(
          width: 800,
          height: double.infinity,
          child: CodeField(
            controller: _codeController,
            textStyle: const TextStyle(fontFamily: 'SourceCode'),
            minLines: null,
            maxLines: null,
            expands: true,
            onChanged: _onRfwTextChanged,
          ),
        ),
      ),
      Expanded(
        child: _latestRfwError == null
            ? RemoteWidget(
                runtime: _runtime,
                data: _data,
                widget: const FullyQualifiedWidgetName(mainName, 'root'),
                onEvent: _onRfwEvent,
              )
            : ErrorWidget(_latestRfwError!),
      ),
    ]);
  }
}

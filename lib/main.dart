import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:rfw/formats.dart';
import 'package:rfw/rfw.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:highlight/languages/dart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'RFW PlayGround',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: Scaffold(
            appBar: AppBar(title: const Text('RFW Playground')),
            body: RFWTextEditor()));
  }
}

class RFWTextEditor extends StatefulWidget {
  const RFWTextEditor({super.key});

  @override
  State<RFWTextEditor> createState() => _RFWTextEditor();
}

class _RFWTextEditor extends State<RFWTextEditor> {
  final Runtime _runtime = Runtime();
  final DynamicContent _data = DynamicContent();

  static const LibraryName coreName = LibraryName(<String>['core', 'widgets']);
  static const LibraryName materialName =
      LibraryName(<String>['material', 'widgets']);
  static const LibraryName mainName = LibraryName(<String>['main']);

  CodeController? _codeController;
  RemoteWidgetLibrary? _remoteWidgetLibrary;
  Object? _latestError;

  String _rfwText = '''
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

  @override
  void initState() {
    super.initState();
    _codeController = CodeController(text: _rfwText, language: dart);
    _runtime.update(coreName, createCoreWidgets());
    _runtime.update(materialName, createMaterialWidgets());
    updateRemoteWidgetLibrary();
    // Configuration data:
    _data.update('greet', <String, Object>{'name': 'World'});
    _data.update('list', <String>['a', 'b', 'c', 'd', 'e']);
  }

  @override
  void dispose() {
    _codeController?.dispose();
    super.dispose();
  }

  set rfwText(String rfwText) {
    if (_rfwText == rfwText) {
      return;
    }
    setState(() {
      _rfwText = rfwText;
      updateRemoteWidgetLibrary();
    });
  }

  void updateRemoteWidgetLibrary() {
    try {
      RemoteWidgetLibrary remoteLib = parseLibraryFile(_rfwText);
      _remoteWidgetLibrary = remoteLib;
      _runtime.update(mainName, _remoteWidgetLibrary!);
      _latestError = null;
    } catch (e) {
      _latestError = e;
      print(_latestError);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          decoration:
              BoxDecoration(border: Border.all(color: Colors.blueAccent)),
          child: SizedBox(
              width: 800,
              height: double.infinity,
              child: CodeField(
                controller: _codeController!,
                textStyle: const TextStyle(fontFamily: 'SourceCode'),
                minLines: null,
                maxLines: null,
                expands: true,
                onChanged: (String text) {
                  rfwText = text;
                },
              ))),
      Expanded(
          child: _latestError == null
              ? RemoteWidget(
                  runtime: _runtime,
                  data: _data,
                  widget: const FullyQualifiedWidgetName(mainName, 'root'),
                  onEvent: (String name, DynamicMap arguments) {
                    // The example above does not have any way to trigger events, but if it
                    // did, they would result in this callback being invoked.
                    print('user triggered event "$name" with data: $arguments');
                  })
              : ErrorWidget(_latestError!)),
    ]);
  }
}

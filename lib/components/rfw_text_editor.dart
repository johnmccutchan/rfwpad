import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

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

(int, int) lineCol(SourceLocation l) {
  final source = l.source;
  int line = -1;
  int column = -1;
  if ((source is String)) {
    line = 1;
    column = 0;
    int offset = 0;
    for (final ch in source.characters) {
      if (ch == '\n') {
        line++;
        column = 0;
      } else {
        column++;
      }
      if (offset == l.offset) {
        return (line, column);
      }
      offset++;
    }
  }
  return (line, column);
}

class _RfwTextEditor extends State<RfwTextEditor> {
  static const LibraryName coreName = LibraryName(<String>['core', 'widgets']);
  static const LibraryName materialName =
      LibraryName(<String>['material', 'widgets']);
  static const LibraryName mainName = LibraryName(<String>['main']);
  static const String _initialRfwData = '''
   {
    "greet": {
      "name": "World!"
     },
    "list": ["a", "b", "c", "d", "e"]
   }
  ''';
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

  String _rfwText = _initialRfwText;

  final Runtime _runtime = Runtime();
  final DynamicContent _data = DynamicContent();
  final CodeController _codeController = CodeController(
    text: _initialRfwText,
    language: dart,
  );
  final CodeController _rfwDataController = CodeController(
    text: _initialRfwData,
    language: dart,
  );

  Object? _latestRfwError;

  SourceRange? _hoverRange;

  @override
  void initState() {
    super.initState();

    _runtime
      ..update(coreName, createCoreWidgets())
      ..update(materialName, createMaterialWidgets())
      ..update(
          mainName, parseLibraryFile(_rfwText, sourceIdentifier: _rfwText));

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
      _runtime.update(
          mainName, parseLibraryFile(rfwText, sourceIdentifier: rfwText));
      _rfwText = rfwText;
    } catch (e) {
      rfwError = e;
    } finally {
      setState(() {
        _latestRfwError = rfwError;
      });
    }
  }

  void _onRfwDataChanged(String rfwData) {
    Object? rfwError;
    try {
      _data.updateAll(jsonDecode(rfwData));
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

  void _onHover(PointerHoverEvent event) {
    final view = WidgetsFlutterBinding.ensureInitialized().renderViews.first;
    final hitTestResult = HitTestResult();
    if (view.hitTest(hitTestResult, position: event.position)) {
      SourceRange? loc;
      for (final segment in hitTestResult.path) {
        final target = segment.target;
        if (target is RenderObject) {
          final debugCreator = target.debugCreator;
          if (debugCreator is DebugCreator) {
            final element = debugCreator.element;
            final blob = Runtime.blobNodeFor(element);
            if (blob != null && blob.source != null) {
              if (loc == null) {
                loc = blob.source;
              } else {
                // Keep track of the tightest source range we see.
                int locLength = loc.end.offset - loc.start.offset;
                int blobLength =
                    blob.source!.end.offset - blob.source!.start.offset;
                if (blobLength < locLength) {
                  loc = blob.source;
                }
              }
            }
          }
        }
      }
      if (loc != null) {
        setState(() {
          _hoverRange = loc;
          _codeController.selection = TextSelection(
              baseOffset: loc!.start.offset, extentOffset: loc!.end.offset);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // RFW code.
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

      /// RFW data.
      Container(
        decoration: BoxDecoration(border: Border.all(color: Colors.blueAccent)),
        child: SizedBox(
          width: 800,
          height: double.infinity,
          child: CodeField(
            controller: _rfwDataController,
            textStyle: const TextStyle(fontFamily: 'SourceCode'),
            minLines: null,
            maxLines: null,
            expands: true,
            onChanged: _onRfwDataChanged,
          ),
        ),
      ),

      // RFW UI.
      Expanded(
        child: MouseRegion(
            onHover: _onHover,
            child: _latestRfwError == null
                ? RemoteWidget(
                    runtime: _runtime,
                    data: _data,
                    widget: const FullyQualifiedWidgetName(mainName, 'root'),
                    onEvent: _onRfwEvent,
                  )
                : ErrorWidget(_latestRfwError!)),
      ),
    ]);
  }
}

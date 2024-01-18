import 'dart:convert';

import 'package:flutter_resizable_container/flutter_resizable_container.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:highlight/languages/dart.dart';
import 'package:rfw/formats.dart';
import 'package:rfw/rfw.dart';

import '../infra/rfw_event.dart';

class RfwPad extends StatefulWidget {
  const RfwPad({super.key});

  @override
  State<RfwPad> createState() => _RfwPad();
}

class _RfwPad extends State<RfwPad> {
  static const LibraryName coreName = LibraryName(<String>['core', 'widgets']);
  static const LibraryName materialName =
      LibraryName(<String>['material', 'widgets']);
  static const LibraryName mainName = LibraryName(<String>['main']);
  static const JsonEncoder _jsonEncoder = JsonEncoder.withIndent('  ');
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
  final List<RfwEvent> _rfwEvents = <RfwEvent>[];

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
    setState(() {
      _rfwEvents.add(RfwEvent(name, arguments));
    });
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
            baseOffset: loc!.start.offset,
            extentOffset: loc!.end.offset,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResizableContainer(
        direction: Axis.horizontal,
        children: [
          ResizableChildData(
            startingRatio: 0.3,
            child: ResizableContainer(
              direction: Axis.vertical,
              children: [
                ResizableChildData(
                  startingRatio: 0.7,
                  child: _rfwTextEditor,
                ),
                ResizableChildData(
                  startingRatio: 0.3,
                  child: _rfwDataEditor,
                ),
              ],
            ),
          ),
          ResizableChildData(
            startingRatio: 0.7,
            child: ResizableContainer(
              direction: Axis.vertical,
              children: [
                ResizableChildData(
                  startingRatio: 0.8,
                  child: _rfwApp,
                ),
                ResizableChildData(
                  startingRatio: 0.2,
                  child: _rfwEventsInspector,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget get _rfwTextEditor => CodeField(
        controller: _codeController,
        textStyle: const TextStyle(fontFamily: 'SourceCode'),
        minLines: null,
        maxLines: null,
        expands: true,
        onChanged: _onRfwTextChanged,
      );

  Widget get _rfwDataEditor => CodeField(
        controller: _rfwDataController,
        textStyle: const TextStyle(fontFamily: 'SourceCode'),
        minLines: null,
        maxLines: null,
        expands: true,
        onChanged: _onRfwDataChanged,
      );

  Widget get _rfwEventsInspector => ListView.builder(
        itemCount: _rfwEvents.length,
        itemBuilder: (context, index) {
          // Reverse order.
          final event = _rfwEvents[_rfwEvents.length - 1 - index];
          final name = event.name;
          final arguments = event.arguments;
          return ExpansionTile(
            title: Text('Event: $name'),
            children: [Text(_jsonEncoder.convert(arguments))],
          );
        },
      );

  Widget get _rfwApp => MouseRegion(
        onHover: _onHover,
        child: RemoteWidget(
          runtime: _runtime,
          data: _data,
          widget: const FullyQualifiedWidgetName(mainName, 'root'),
          onEvent: _onRfwEvent,
        ),
      );
}

import 'dart:convert';

import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_highlight/themes/solarized-light.dart';
import 'package:flutter_highlight/themes/solarized-dark.dart';
import 'package:highlight/languages/dart.dart';
import 'package:rfw/formats.dart';
import 'package:rfw/rfw.dart';

import '../widgets/tree.dart';
import '../infra/rfw_event.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.toggleTheme});

  final void Function() toggleTheme;

  @override
  State<HomeScreen> createState() => _HomeScreen();
}

class _HomeScreen extends State<HomeScreen> {
  static const LibraryName coreName = LibraryName(<String>['core', 'widgets']);
  static const LibraryName materialName =
      LibraryName(<String>['material', 'widgets']);
  static const LibraryName mainName = LibraryName(<String>['main']);
  static const JsonEncoder _jsonEncoder = JsonEncoder.withIndent('  ');
  static const DynamicMap _initialRfwData = <String, Object>{
    'greet': {
      'name': 'World',
    },
    'cities': [
      {
        'name': 'San Francisco',
        "image": "https://source.unsplash.com/random/200x200/?san+francisco",
      },
      {
        'name': 'New york',
        "image": "https://source.unsplash.com/random/200x200/?new+york",
      },
      {
        'name': 'Los Angeles',
        "image": "https://source.unsplash.com/random/200x200/?los+angeles",
      },
    ],
  };
  static const String _initialRfwText = '''
    // The "import" keyword is used to specify dependencies, in this case,
    // the built-in widgets that are added by initState below.
    import core.widgets;
    import material.widgets;

    // The "widget" keyword is used to define a new widget constructor.
    // The "root" widget is specified as the one to render in the build
    // method below.
    widget root = Container(
      child: Center(
        child: Column(
          children: [
            Space(),
            Title(title: ["Hello, ", data.greet.name, "!"]),
            Title(title: "What's your favorite city?"),
            Space(),
            FavoriteCities(cities: data.cities),
          ]
        )
      ),
    );

    widget Title = Text(
      text: args.title,
      style: {
         fontSize: 20.0,
         fontWeight: 'bold',
      },
    );

    widget Space = SizedBox(height: 30.0);

    widget FavoriteCities = Row(
      mainAxisAlignment: 'center',
      children: [
        ...for city in args.cities:
          City(name: city.name, image: city.image),
      ],
    );

    widget City = Column(
      children: [
         CityName(name: args.name),
         Space(),
         Image(source: args.image, width: 200.0, height: 200.0),
         Space(),
         LikeButton(city: args.name),
      ],
    );

    widget CityName = Text(
      text: args.name,
      style: {
        fontSize: 14,
      },
    );

    widget LikeButton = ElevatedButton(
      child: Text(text: ["I like ", args.city]),
      onPressed: event "pressed" {"city": args.city }
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
    text: _jsonEncoder.convert(_initialRfwData),
    language: dart,
  );
  final List<RfwEvent> _rfwEvents = <RfwEvent>[];

  SourceRange? _hoverRange;

  @override
  void initState() {
    super.initState();

    _runtime
      ..update(coreName, createCoreWidgets())
      ..update(materialName, createMaterialWidgets())
      ..update(
          mainName, parseLibraryFile(_rfwText, sourceIdentifier: _rfwText));

    for (final key in _initialRfwData.keys) {
      _data.update(key, _initialRfwData[key]!);
    }
  }

  @override
  void dispose() {
    super.dispose();
    _codeController.dispose();
  }

  Object? _latestRfwTextError;
  void _onRfwTextChanged(BuildContext context, String rfwText) {
    Object? rfwTextError;
    try {
      _runtime.update(
          mainName, parseLibraryFile(rfwText, sourceIdentifier: rfwText));
      _rfwText = rfwText;
    } catch (e) {
      rfwTextError = e;
    } finally {
      setState(() {
        _latestRfwTextError = rfwTextError;
      });
    }
  }

  Object? _latestRfwDataError;
  void _onRfwDataChanged(BuildContext context, String rfwData) {
    Object? rfwDataError;
    try {
      _data.updateAll(jsonDecode(rfwData));
    } catch (e) {
      rfwDataError = e;
    } finally {
      setState(() {
        _latestRfwDataError = rfwDataError;
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

  bool _showEvents = false;
  bool _showData = false;
  bool _lightMode = true;

  @override
  Widget build(BuildContext context) {
    _lightMode = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      drawer: Drawer(width: 400, child: RFWTreeView(runtime: _runtime)),
      appBar: AppBar(
        title: Text('rfw dbg'),
        actions: [
          Padding(
            padding: EdgeInsets.all(10),
            child: IconButton(
              onPressed: widget.toggleTheme,
              icon: Icon(_lightMode ? Icons.dark_mode : Icons.light_mode),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(10),
            child: OutlinedButton(
              onPressed: () => setState(() => _showData = !_showData),
              child: _showData ? Text('Hide data') : Text('Show data'),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(10),
            child: OutlinedButton(
              onPressed: () => setState(() => _showEvents = !_showEvents),
              child: _showEvents ? Text('Hide events') : Text('Show events'),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: Column(children: [
              Expanded(child: _rfwTextEditor(context)),
              if (_showData) Expanded(child: _rfwDataEditor(context)),
            ]),
          ),
          Expanded(
            child: Column(children: [
              Expanded(child: _rfwApp),
              if (_showEvents) Expanded(child: _rfwEventsInspector),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _rfwTextEditor(BuildContext context) => _textEditor(
        context,
        _codeController,
        _onRfwTextChanged,
        _latestRfwTextError,
      );

  Widget _rfwDataEditor(BuildContext context) => _textEditor(
        context,
        _rfwDataController,
        _onRfwDataChanged,
        _latestRfwDataError,
      );

  Widget get _rfwApp => MouseRegion(
        onHover: _onHover,
        child: Container(
          decoration: BoxDecoration(border: Border.all()),
          child: SingleChildScrollView(
            child: RemoteWidget(
              runtime: _runtime,
              data: _data,
              widget: const FullyQualifiedWidgetName(mainName, 'root'),
              onEvent: _onRfwEvent,
            ),
          ),
        ),
      );

  Widget get _rfwEventsInspector => Container(
        decoration: BoxDecoration(border: Border.all()),
        child: _rfwEvents.isEmpty
            ? Center(child: Text('No events have been fired'))
            : ListView.builder(
                itemCount: _rfwEvents.length,
                itemBuilder: (context, index) {
                  final event = _rfwEvents[index];
                  final name = event.name;
                  final arguments = event.arguments;
                  return ExpansionTile(
                    title: Text('Event: $name'),
                    children: [Text(_jsonEncoder.convert(arguments))],
                  );
                },
              ),
      );

  Widget _textEditor(
    BuildContext context,
    CodeController controller,
    Function(BuildContext, String) onChanged,
    Object? error,
  ) =>
      Column(
        children: [
          Expanded(
            child: CodeTheme(
              data: CodeThemeData(
                styles: _lightMode ? solarizedLightTheme : solarizedDarkTheme,
              ),
              child: CodeField(
                controller: controller,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: error == null ? Colors.black : Colors.red,
                  ),
                ),
                textStyle: const TextStyle(fontFamily: 'SourceCode'),
                minLines: null,
                maxLines: null,
                expands: true,
                onChanged: (value) => onChanged(context, value),
              ),
            ),
          ),
          if (error != null)
            Container(
              color: Colors.red,
              width: double.infinity,
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Text(error.toString(), maxLines: 1),
              ),
            ),
        ],
      );
}

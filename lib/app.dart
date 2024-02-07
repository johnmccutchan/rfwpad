import 'package:flutter/material.dart';
import 'package:rfwpad/screens/home_screen.dart';
import 'package:rfwpad/infra/builtin.dart';

const String _initialRfwText = '''
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

final Map<String, Object> _initialData = <String, Object>{
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

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(
        toggleTheme: _toggleTheme,
        builtinLocalWidgetLibraries: createLocalWidgetsMap(),
        builtinRemoteWidgetLibraries: const {},
        initialData: _initialData,
        initialRfwTxt: _initialRfwText,
      ),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: _themeMode,
    );
  }
}

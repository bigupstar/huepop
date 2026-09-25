import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:varityskirja/colorpicker.dart';
import 'package:varityskirja/drawingarea.dart';
import 'package:varityskirja/overlayimage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Color color = Colors.red;
  String imagePath = 'assets/car.png';
  List<String> assets = ['assets/car.png'];

  @override
  void initState() {
    super.initState();
    loadAssets();
  }

  void loadAssets() async {
    final AssetManifest assetManifest =
        await AssetManifest.loadFromAssetBundle(rootBundle);
    final List<String> assets = assetManifest.listAssets();
    setState(() {
      this.assets = assets.where((asset) => asset.endsWith('.png')).toList();
    });
  }

  void setColor(Color color) {
    setState(() {
      this.color = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentAssetidex = assets.indexOf(imagePath);
    final nextAssetIndex = (currentAssetidex + 1) % assets.length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          OverlayImage(
            image: Image.asset(imagePath),
            child: DrawingArea(
              color: color,
              key: Key(imagePath),
            ),
          ),
          ColorPicker(
            onColorChanged: setColor,
            currentColor: color,
          ),
          Positioned(
              bottom: 15,
              right: -10,
              child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      imagePath = assets[nextAssetIndex];
                    });
                  },
                  style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(
                          side: BorderSide(color: Colors.black))),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: Image.asset(
                      assets[nextAssetIndex],
                      cacheWidth: 150,
                      cacheHeight: 150,
                    ),
                  ))),
        ],
      ),
    );
  }
}

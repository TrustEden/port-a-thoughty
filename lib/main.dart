import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // Import for MethodChannel

import 'screens/capture_screen.dart';
import 'screens/docs_screen.dart';
import 'screens/queue_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/app_header.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Future.delayed(const Duration(seconds: 2)); // Keep splash screen for 2 seconds
  runApp(const PortaThoughtyApp());
}

class PortaThoughtyApp extends StatelessWidget {
  const PortaThoughtyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PortaThoughtyState(),
      child: MaterialApp(
        title: 'Pot-A-Thoughty',
        theme: AppTheme.light(),
        home: const HomeShell(),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late PageController _pageController;
  static const platform = MethodChannel('com.example.porta_thoughty/widget'); // Define MethodChannel

  static final _destinations = [
    NavigationDestination(
      icon: Image.asset('assets/capture.png', width: 48, height: 48),
      selectedIcon: Image.asset('assets/capture.png', width: 48, height: 48),
      label: 'Capture',
    ),
    NavigationDestination(
      icon: Image.asset('assets/queue.png', width: 48, height: 48),
      selectedIcon: Image.asset('assets/queue.png', width: 48, height: 48),
      label: 'Raw Notes',
    ),
    NavigationDestination(
      icon: Image.asset('assets/docsnotes.png', width: 48, height: 48),
      selectedIcon: Image.asset('assets/docsnotes.png', width: 48, height: 48),
      label: 'Docs',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
    _setupMethodChannel(); // Setup MethodChannel listener
  }

  void _setupMethodChannel() {
    platform.setMethodCallHandler((call) async {
      print('MethodChannel call received: ${call.method}');
      if (call.method == "handleWidgetClick") {
        final String? uriString = call.arguments as String?;
        print('Received URI string: $uriString');
        if (uriString != null) {
          final Uri uri = Uri.parse(uriString);
          print('Parsed URI: $uri');
          if (uri.host == 'home_widget' && uri.pathSegments.contains('record')) {
            print('URI matches recording intent. Navigating to CaptureScreen.');
            _onDestinationSelected(0); // Navigate to CaptureScreen
            Future.delayed(const Duration(milliseconds: 350), () {
              if (mounted) {
                print('Delayed execution: context mounted.');
                final state = Provider.of<PortaThoughtyState>(context, listen: false);
                print('PortaThoughtyState instance obtained. isRecording: ${state.isRecording}');
                if (!state.isRecording) {
                  print('Calling startRecording().');
                  state.startRecording();
                } else {
                  print('Already recording, not calling startRecording().');
                }
              } else {
                print('Delayed execution: context not mounted.');
              }
            });
          } else {
            print('URI does not match recording intent.');
          }
        } else {
          print('URI string is null.');
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _index = index;
    });
  }

  void _onDestinationSelected(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: AppTheme.backgroundGradient,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Fixed header area
              _FixedHeader(currentIndex: _index),
              // Scrollable content area
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  physics: const NeverScrollableScrollPhysics(), // Disable swipe
                  children: const [CaptureScreen(), QueueScreen(), DocsScreen()],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _onDestinationSelected,
          destinations: _destinations,
        ),
      ),
    );
  }
}

class _FixedHeader extends StatelessWidget {
  const _FixedHeader({required this.currentIndex});

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    // Different subtitles for each screen
    final subtitles = [
      'Capture first, clean later. Porta-Thoughty keeps your brain clear.',
      'Review and select notes to process into organized documents.',
      'Your processed documents, ready to share and review.',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
      child: AppHeader(subtitle: subtitles[currentIndex]),
    );
  }
}
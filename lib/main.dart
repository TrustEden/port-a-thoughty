import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // Import for MethodChannel
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'screens/capture_screen.dart';
import 'screens/docs_screen.dart';
import 'screens/queue_screen.dart';
import 'services/pip_service.dart';
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

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 1;
  late PageController _pageController;
  static const platform = MethodChannel('com.example.porta_thoughty/widget'); // Define MethodChannel
  StreamSubscription? _intentMediaStreamSubscription;
  bool _isInPipMode = false;

  static final _destinations = [
    NavigationDestination(
      icon: Image.asset('assets/queue.png', width: 48, height: 48, gaplessPlayback: true),
      selectedIcon: Image.asset('assets/queue.png', width: 48, height: 48, gaplessPlayback: true),
      label: 'Raw Notes',
    ),
    NavigationDestination(
      icon: Image.asset('assets/capture.png', width: 48, height: 48, gaplessPlayback: true),
      selectedIcon: Image.asset('assets/capture.png', width: 48, height: 48, gaplessPlayback: true),
      label: 'Capture',
    ),
    NavigationDestination(
      icon: Image.asset('assets/docsnotes.png', width: 48, height: 48, gaplessPlayback: true),
      selectedIcon: Image.asset('assets/docsnotes.png', width: 48, height: 48, gaplessPlayback: true),
      label: 'Docs',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
    _setupMethodChannel(); // Setup MethodChannel listener
    _initSharingListener(); // Setup share intent listeners
    WidgetsBinding.instance.addObserver(this); // Add lifecycle observer
    debugPrint('PiP Debug: Lifecycle observer registered in initState');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _handleLifecycleChange(state);
  }

  Future<void> _handleLifecycleChange(AppLifecycleState state) async {
    debugPrint('PiP Debug: Lifecycle state changed to: $state');
    if (!mounted) {
      debugPrint('PiP Debug: Widget not mounted, returning');
      return;
    }

    final appState = Provider.of<PortaThoughtyState>(context, listen: false);

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      debugPrint('PiP Debug: App going to background');
      debugPrint('PiP Debug: _isInPipMode = $_isInPipMode');
      debugPrint('PiP Debug: pipEnabled = ${appState.settings.pipEnabled}');

      // App going to background - enter PiP if enabled in settings
      if (!_isInPipMode && appState.settings.pipEnabled) {
        debugPrint('PiP Debug: Attempting to enter PiP mode...');
        final success = await PipService.enterPipMode();
        debugPrint('PiP Debug: Enter PiP result: $success');
        if (success) {
          setState(() {
            _isInPipMode = true;
          });
          debugPrint('PiP Debug: Successfully entered PiP mode');
        } else {
          debugPrint('PiP Debug: Failed to enter PiP mode');
        }
      } else {
        debugPrint('PiP Debug: Skipping PiP - already in PiP or disabled');
      }
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('PiP Debug: App resumed');
      // App came back to foreground
      if (_isInPipMode) {
        setState(() {
          _isInPipMode = false;
        });
        debugPrint('PiP Debug: Exited PiP mode');
      }
    }
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
            _onDestinationSelected(1); // Navigate to CaptureScreen (now index 1)
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

  void _initSharingListener() {
    // Handle media and text shared from other apps while app is running
    // Note: In receive_sharing_intent 1.8.1+, text is included in the media stream
    _intentMediaStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        print('Received shared content: ${value.length} items');
        _handleSharedContent(value);
      },
      onError: (err) {
        print('Error receiving shared content: $err');
      },
    );

    // Handle media and text shared when app was closed/not running
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        print('Received initial shared content: ${value.length} items');
        _handleSharedContent(value);
      }
    });
  }

  void _handleSharedContent(List<SharedMediaFile> sharedFiles) {
    for (var file in sharedFiles) {
      // Check if this is text content (type will be text or path contains text)
      if (file.type == SharedMediaType.text || file.mimeType?.startsWith('text/') == true) {
        _handleSharedText(file.path);
      } else {
        // Handle as media file
        _handleSharedMedia([file]);
      }
    }
  }

  Future<void> _handleSharedText(String text) async {
    if (!mounted) return;
    final state = Provider.of<PortaThoughtyState>(context, listen: false);
    await state.addTextNote(text);

    // Navigate to Queue screen to show the new note
    _onDestinationSelected(0);

    // Show a snackbar confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shared text added to your notes'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleSharedMedia(List<SharedMediaFile> media) async {
    if (!mounted) return;
    final state = Provider.of<PortaThoughtyState>(context, listen: false);

    for (final file in media) {
      if (file.path.isEmpty) continue;

      // Only process images
      final path = file.path;
      final isImage = path.toLowerCase().endsWith('.jpg') ||
          path.toLowerCase().endsWith('.jpeg') ||
          path.toLowerCase().endsWith('.png') ||
          path.toLowerCase().endsWith('.gif') ||
          path.toLowerCase().endsWith('.webp');

      if (isImage) {
        try {
          // Perform OCR on the shared image
          final inputImage = InputImage.fromFilePath(path);
          final textRecognizer = TextRecognizer();
          final recognizedText = await textRecognizer.processImage(inputImage);
          await textRecognizer.close();

          // Create image note with OCR text
          await state.addImageNote(
            ocrText: recognizedText.text.isNotEmpty
                ? recognizedText.text
                : 'Image (no text detected)',
            includeImage: true,
            imagePath: path,
          );

          print('Added shared image note with OCR: ${recognizedText.text}');
        } catch (e) {
          print('Error processing shared image: $e');
          // If OCR fails, still create a note with a placeholder
          await state.addImageNote(
            ocrText: 'Shared image',
            includeImage: true,
            imagePath: path,
          );
        }
      }
    }

    // Navigate to Queue screen to show the new notes
    _onDestinationSelected(0);

    // Show a snackbar confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${media.length} shared ${media.length == 1 ? "image" : "images"} added to your notes'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _intentMediaStreamSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _index = index;
    });
  }

  void _onDestinationSelected(int index) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    _pageController.animateToPage(
      index,
      duration: disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: const Cubic(0.4, 0.0, 0.2, 1.0), // Material motion curve
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<PortaThoughtyState>();

    // Show minimal PiP UI when in PiP mode
    if (_isInPipMode) {
      return _PipRecordingWidget(state: appState);
    }

    // Normal full UI
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
                  children: const [QueueScreen(), CaptureScreen(), DocsScreen()],
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
      'Review and select notes to process into organized documents.',
      'Capture first, clean later. Porta-Thoughty keeps your brain clear.',
      'Your processed documents, ready to share and review.',
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.backgroundGradient[0],
            AppTheme.backgroundGradient[0].withValues(alpha: 0.95),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
        child: AppHeader(subtitle: subtitles[currentIndex]),
      ),
    );
  }
}

/// Minimal widget shown in Picture-in-Picture mode with just the recording button
class _PipRecordingWidget extends StatefulWidget {
  const _PipRecordingWidget({required this.state});

  final PortaThoughtyState state;

  @override
  State<_PipRecordingWidget> createState() => _PipRecordingWidgetState();
}

class _PipRecordingWidgetState extends State<_PipRecordingWidget> {
  final List<DateTime> _tapTimes = [];
  static const _tripleTapWindow = Duration(milliseconds: 500);

  void _handleTap() {
    final now = DateTime.now();

    // Add current tap
    _tapTimes.add(now);

    // Remove old taps outside the time window
    _tapTimes.removeWhere(
      (time) => now.difference(time) > _tripleTapWindow,
    );

    // Check for triple tap
    if (_tapTimes.length >= 3) {
      HapticFeedback.heavyImpact();
      _tapTimes.clear();
      // Exit PiP mode by finishing the activity
      SystemNavigator.pop();
    } else {
      // Single tap - toggle recording
      HapticFeedback.mediumImpact();
      if (widget.state.isRecording) {
        widget.state.stopRecording();
      } else {
        widget.state.startRecording();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = widget.state.isRecording;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.white,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Use 60% of the smaller dimension for the icon
              final iconSize = (constraints.maxHeight * 0.6).clamp(60.0, 100.0);

              return Center(
                child: AnimatedSwitcher(
                  duration: disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: Image.asset(
                    key: ValueKey(isRecording ? 'stop' : 'mic'),
                    isRecording ? 'assets/stoprecording.png' : 'assets/mic.png',
                    width: iconSize,
                    height: iconSize,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
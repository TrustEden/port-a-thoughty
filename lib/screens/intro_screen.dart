import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'onboarding_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  Future<void> _onFinish() async {
    final state = context.read<PortaThoughtyState>();
    await state.markIntroAsSeen();

    if (!mounted) return;

    // If no projects exist, navigate to onboarding instead of just closing
    if (state.projects.isEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const OnboardingScreen(),
          fullscreenDialog: true,
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _onSkip() {
    _onFinish();
  }

  void _onNext() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _onFinish();
    }
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
              // Skip button
              if (_currentPage < 4)
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _onSkip,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 1),
                            blurRadius: 4,
                            color: Colors.black.withValues(alpha: 0.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Page content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  children: const [
                    _WelcomePage(),
                    _CaptureMethodsPage(),
                    _QueuePage(),
                    _ProcessingPage(),
                    _ReadyPage(),
                  ],
                ),
              ),
              // Page indicators
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? Colors.white
                            : Colors.white38,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              // Next/Get Started button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4A53FF),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentPage < 4 ? 'Next' : 'Get Started',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/logo.png',
            width: 180,
            height: 180,
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to\nPorta-Thoughty',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
              shadows: [
                Shadow(
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Capture thoughts instantly,\norganize them later',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
              height: 1.4,
              shadows: [
                Shadow(
                  offset: const Offset(0, 1),
                  blurRadius: 6,
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureMethodsPage extends StatelessWidget {
  const _CaptureMethodsPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Three Ways to Capture',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _CaptureMethodItem(
            imagePath: 'assets/mic.png',
            title: 'Voice',
            description: 'Speak your thoughts naturally',
          ),
          const SizedBox(height: 32),
          _CaptureMethodItem(
            imagePath: 'assets/written.png',
            title: 'Text',
            description: 'Type quick notes',
          ),
          const SizedBox(height: 32),
          _CaptureMethodItem(
            imagePath: 'assets/camera.png',
            title: 'Image',
            description: 'Snap photos with text',
          ),
          const SizedBox(height: 48),
          Text(
            'No need to organize while capturing\n— just get it out of your head',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontStyle: FontStyle.italic,
              shadows: [
                Shadow(
                  offset: const Offset(0, 1),
                  blurRadius: 6,
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureMethodItem extends StatelessWidget {
  const _CaptureMethodItem({
    required this.imagePath,
    required this.title,
    required this.description,
  });

  final String imagePath;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Image.asset(
            imagePath,
            width: 56,
            height: 56,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 1),
                      blurRadius: 6,
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 1),
                      blurRadius: 4,
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QueuePage extends StatelessWidget {
  const _QueuePage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/queue.png',
            width: 140,
            height: 140,
          ),
          const SizedBox(height: 32),
          Text(
            'Your Raw Notes Queue',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'All your captured thoughts collect here.\n\nSelect multiple notes, organize by project, and decide when you\'re ready to process them.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              height: 1.5,
              shadows: [
                Shadow(
                  offset: const Offset(0, 1),
                  blurRadius: 6,
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessingPage extends StatelessWidget {
  const _ProcessingPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/queue.png',
                width: 50,
                height: 50,
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward,
                size: 28,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Image.asset(
                'assets/bulb icon.png',
                width: 50,
                height: 50,
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward,
                size: 28,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Image.asset(
                'assets/docsnotes.png',
                width: 50,
                height: 50,
              ),
            ],
          ),
          const SizedBox(height: 48),
          Text(
            'Processing Magic',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Transform your raw notes into organized documents with AI-powered organization.\n\nCreate projects with custom prompts to structure your thoughts exactly how you need them.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              height: 1.5,
              shadows: [
                Shadow(
                  offset: const Offset(0, 1),
                  blurRadius: 6,
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyPage extends StatelessWidget {
  const _ReadyPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/capture.png',
            width: 160,
            height: 160,
          ),
          const SizedBox(height: 32),
          Text(
            'You\'re All Set!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Start capturing your thoughts.\n\nDon\'t worry about organization —\njust capture first, organize later.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
              height: 1.5,
              shadows: [
                Shadow(
                  offset: const Offset(0, 1),
                  blurRadius: 6,
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

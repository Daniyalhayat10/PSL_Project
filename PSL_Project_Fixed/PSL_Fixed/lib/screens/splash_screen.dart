import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/model_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleAnim;
  String _statusText = 'ماڈل لوڈ ہو رہا ہے...';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
    _loadAndNavigate();
  }

  Future<void> _loadAndNavigate() async {
    final modelService = context.read<ModelService>();
    await Future.delayed(const Duration(milliseconds: 800));
    await modelService.loadModel();

    if (modelService.loadError.isNotEmpty) {
      setState(() => _statusText = 'ڈیمو موڈ میں چل رہا ہے');
    } else {
      setState(() => _statusText = 'تیار ہے!');
    }

    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFF0D2B0D), Color(0xFF0A0A1A)],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeIn,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF006400), Color(0xFF00A300)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF006400).withOpacity(0.6),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.sign_language,
                      size: 70,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'پاکستان اشارہ زبان',
                  style: TextStyle(
                    fontFamily: 'JameelNooriNastaleeq',
                    fontSize: 32,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 8),
                const Text(
                  'PSL Urdu Detector',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFFC8A951),
                    letterSpacing: 3,
                    fontWeight: FontWeight.w300,
                  ),
                ),
               const Text(
  'FYP Project 2026',
  style: TextStyle(
    fontSize: 12,
    color: Colors.white38,
    letterSpacing: 2,
  ),
),
const SizedBox(height: 6),
const Text(
  'Designed by Mehnail Jawad',
  style: TextStyle(
    fontSize: 11,
    color: Colors.white38,
    letterSpacing: 1.5,
    fontStyle: FontStyle.italic,
  ),
),
const SizedBox(height: 60),
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white12,
                    color: const Color(0xFF00C853),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _statusText,
                  style: const TextStyle(
                    fontFamily: 'JameelNooriNastaleeq',
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

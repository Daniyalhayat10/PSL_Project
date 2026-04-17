import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/model_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ModelService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D2B0D), Color(0xFF0A0A1A), Color(0xFF0A0A1A)],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 8),
                _buildStatusBadge(model),
                const SizedBox(height: 36),
                _buildMainDetectButton(context),
                const SizedBox(height: 24),
                _buildFeatureGrid(context),
                const SizedBox(height: 24),
              _buildInfoCard(),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Designed by Mehnail Jawad',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white24,
                      letterSpacing: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ]
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF006400), Color(0xFF00A300)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF006400).withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(Icons.sign_language, size: 56, color: Colors.white),
        ),
        const SizedBox(height: 16),
        const Text(
          'پاکستان اشارہ زبان',
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: 'JameelNooriNastaleeq',
            fontSize: 30,
            color: Colors.white,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'PSL Urdu Sign Language Detector',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFC8A951),
            fontSize: 13,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(ModelService model) {
    final isReady = model.isLoaded;
    final color = isReady ? const Color(0xFF00C853) : const Color(0xFFFFD600);
    final text = isReady ? 'ماڈل تیار ہے ✓' : 'لوڈ ہو رہا ہے...';

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontFamily: 'JameelNooriNastaleeq',
            fontSize: 14,
          ),
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }

  Widget _buildMainDetectButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/detection'),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF006400), Color(0xFF00A300), Color(0xFF006400)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF006400).withOpacity(0.5),
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                Icons.sign_language,
                size: 120,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.camera_alt, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'شناخت شروع کریں',
                        style: TextStyle(
                          fontFamily: 'JameelNooriNastaleeq',
                          color: Colors.white,
                          fontSize: 22,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start Sign Detection',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Real-time Detection →',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureGrid(BuildContext context) {
    final features = [
      _FeatureItem(
        icon: Icons.menu_book,
        title: 'حروف تہجی',
        subtitle: 'Alphabet Guide',
        color: const Color(0xFF1565C0),
        route: '/alphabet',
      ),
      _FeatureItem(
        icon: Icons.info_outline,
        title: 'معلومات',
        subtitle: 'About PSL',
        color: const Color(0xFF6A1B9A),
        route: '/about',
      ),
    ];

    return Row(
      children: features.map((f) {
        return Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, f.route),
            child: Container(
              margin: EdgeInsets.only(
                right: f == features.first ? 8 : 0,
                left: f == features.last ? 8 : 0,
              ),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: f.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: f.color.withOpacity(0.4)),
              ),
              child: Column(
                children: [
                  Icon(f.icon, color: f.color, size: 36),
                  const SizedBox(height: 10),
                  Text(
                    f.title,
                    style: TextStyle(
                      fontFamily: 'JameelNooriNastaleeq',
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  Text(
                    f.subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'کیسے استعمال کریں؟',
            style: TextStyle(
              fontFamily: 'JameelNooriNastaleeq',
              color: Color(0xFFC8A951),
              fontSize: 18,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 12),
          _buildStep('١', 'کیمرہ کی طرف ہاتھ رکھیں', 'Hold your hand toward the camera'),
          _buildStep('٢', 'اشارہ مستحکم رکھیں', 'Keep the sign stable for detection'),
          _buildStep('٣', 'حرف کی شناخت دیکھیں', 'See the detected Urdu letter'),
        ],
      ),
    );
  }

  Widget _buildStep(String num, String urdu, String english) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  urdu,
                  style: const TextStyle(
                    fontFamily: 'JameelNooriNastaleeq',
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                Text(
                  english,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFF006400).withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                num,
                style: const TextStyle(
                  color: Color(0xFF00C853),
                  fontSize: 14,
                  fontFamily: 'JameelNooriNastaleeq',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String route;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.route,
  });
}

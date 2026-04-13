import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'معلومات',
          style: TextStyle(
            fontFamily: 'JameelNooriNastaleeq',
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildLogoSection(),
            const SizedBox(height: 24),
            _buildProjectCard(),
            const SizedBox(height: 16),
            _buildTechCard(),
            const SizedBox(height: 16),
            _buildDatasetCard(),
            const SizedBox(height: 16),
            _buildTeamCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF006400), Color(0xFF00A300)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF006400).withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(Icons.sign_language, size: 64, color: Colors.white),
        ),
        const SizedBox(height: 16),
        const Text(
          'PSL Urdu Detector',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Final Year Project 2025',
          style: TextStyle(color: Color(0xFFC8A951), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildProjectCard() {
    return _InfoCard(
      title: 'پروجیکٹ کے بارے میں',
      titleEnglish: 'About Project',
      icon: Icons.info_outline,
      color: const Color(0xFF1565C0),
      children: [
        _InfoRow(
          'مقصد',
          'پاکستانی اشارہ زبان کی اردو حروف تہجی کی خودکار شناخت',
        ),
        _InfoRow(
          'Goal',
          'Automatic recognition of PSL Urdu alphabet signs using deep learning',
        ),
        _InfoRow('Classes', '36 Urdu alphabet letters'),
        _InfoRow('Method', 'Hand landmark extraction + Neural Network'),
      ],
    );
  }

  Widget _buildTechCard() {
    return _InfoCard(
      title: 'تکنیکی تفصیلات',
      titleEnglish: 'Technology Stack',
      icon: Icons.code,
      color: const Color(0xFF6A1B9A),
      children: [
        _InfoRow('Detection', 'Google MediaPipe Hand Tracking'),
        _InfoRow('Model', 'Keras Neural Network (hand_landmark_nn.h5)'),
        _InfoRow('Input', '63 values (21 landmarks × 3 coords)'),
        _InfoRow('Mobile', 'Flutter + TFLite'),
        _InfoRow('TTS', 'Urdu Text-to-Speech'),
      ],
    );
  }

  Widget _buildDatasetCard() {
    return _InfoCard(
      title: 'ڈیٹاسیٹ',
      titleEnglish: 'Dataset',
      icon: Icons.folder_open,
      color: const Color(0xFF00695C),
      children: [
        _InfoRow('Language', 'Pakistan Sign Language (PSL)'),
        _InfoRow('Script', 'Urdu / Nastaleeq'),
        _InfoRow('Alphabet', '36 letters (حروف تہجی)'),
        _InfoRow(
            'Source', 'Custom collected dataset for PSL Urdu recognition'),
        _InfoRow('Font', 'Jameel Noori Nastaleeq'),
      ],
    );
  }

  Widget _buildTeamCard() {
    return _InfoCard(
      title: 'ٹیم',
      titleEnglish: 'Development Team',
      icon: Icons.group,
      color: const Color(0xFFB71C1C),
      children: [
        _InfoRow('Project', 'Pakistan Sign Language Urdu Detection'),
        _InfoRow('Repository', 'github.com/kashafnn/Pakistan-Sign-Language-URDU-'),
        _InfoRow('Platform', 'Android Mobile App'),
        _InfoRow('Year', '2025'),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String titleEnglish;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.titleEnglish,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Text(
                  titleEnglish,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'JameelNooriNastaleeq',
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text('  ·  ',
              style: TextStyle(color: Colors.white24, fontSize: 12)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

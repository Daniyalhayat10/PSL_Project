import 'package:flutter/material.dart';

class AlphabetGuideScreen extends StatelessWidget {
  const AlphabetGuideScreen({super.key});

  static const List<Map<String, String>> _alphabets = [
    {'urdu': 'الف', 'roman': 'Alif', 'desc': 'Closed fist with thumb up'},
    {'urdu': 'ب', 'roman': 'Bay', 'desc': 'Index finger pointing up'},
    {'urdu': 'پ', 'roman': 'Pay', 'desc': 'Index & middle up, spread'},
    {'urdu': 'ت', 'roman': 'Tay', 'desc': 'Three fingers up'},
    {'urdu': 'ٹ', 'roman': 'Ttay', 'desc': 'Three fingers curled'},
    {'urdu': 'ث', 'roman': 'Say', 'desc': 'Four fingers spread'},
    {'urdu': 'ج', 'roman': 'Jeem', 'desc': 'Index & middle V-sign'},
    {'urdu': 'چ', 'roman': 'Chay', 'desc': 'Curved index finger'},
    {'urdu': 'ح', 'roman': 'Hay', 'desc': 'Open palm facing out'},
    {'urdu': 'خ', 'roman': 'Khay', 'desc': 'Open palm facing in'},
    {'urdu': 'د', 'roman': 'Daal', 'desc': 'Thumb & index circle'},
    {'urdu': 'ڈ', 'roman': 'Ddaal', 'desc': 'Thumb & index pinch'},
    {'urdu': 'ذ', 'roman': 'Zal', 'desc': 'Index pointing sideways'},
    {'urdu': 'ر', 'roman': 'Ray', 'desc': 'Index down curved'},
    {'urdu': 'ڑ', 'roman': 'Rray', 'desc': 'Two fingers down'},
    {'urdu': 'ز', 'roman': 'Zay', 'desc': 'Fist with pinky up'},
    {'urdu': 'ژ', 'roman': 'Zhay', 'desc': 'Spread all fingers'},
    {'urdu': 'س', 'roman': 'Seen', 'desc': 'Three fingers side'},
    {'urdu': 'ش', 'roman': 'Sheen', 'desc': 'Four fingers wave'},
    {'urdu': 'ص', 'roman': 'Suad', 'desc': 'Thumb across palm'},
    {'urdu': 'ض', 'roman': 'Zuad', 'desc': 'Thumb & pinky extend'},
    {'urdu': 'ط', 'roman': 'Toay', 'desc': 'All fingers curled in'},
    {'urdu': 'ظ', 'roman': 'Zoay', 'desc': 'Wrist bent forward'},
    {'urdu': 'ع', 'roman': 'Ain', 'desc': 'Ring & middle crossed'},
    {'urdu': 'غ', 'roman': 'Ghain', 'desc': 'Index hook forward'},
    {'urdu': 'ف', 'roman': 'Fay', 'desc': 'Flat hand side view'},
    {'urdu': 'ق', 'roman': 'Qaaf', 'desc': 'Two finger L-shape'},
    {'urdu': 'ک', 'roman': 'Kaaf', 'desc': 'All 5 fingers open'},
    {'urdu': 'گ', 'roman': 'Gaaf', 'desc': 'C-shape hand'},
    {'urdu': 'ل', 'roman': 'Laam', 'desc': 'L-shape index & thumb'},
    {'urdu': 'م', 'roman': 'Meem', 'desc': 'Fingers touching palm'},
    {'urdu': 'ن', 'roman': 'Noon', 'desc': 'Index over middle'},
    {'urdu': 'ں', 'roman': 'Noon G.', 'desc': 'Nasal n variation'},
    {'urdu': 'و', 'roman': 'Wao', 'desc': 'O-shape with fingers'},
    {'urdu': 'ہ', 'roman': 'Hay', 'desc': 'Two hands touch tips'},
    {'urdu': 'ی', 'roman': 'Yay', 'desc': 'Pinky extended down'},
  ];

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
          'اردو حروف تہجی',
          style: TextStyle(
            fontFamily: 'JameelNooriNastaleeq',
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Header
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF006400), Color(0xFF004D00)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sign_language, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text(
                  'PSL - 36 Urdu Letters',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          // Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.85,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _alphabets.length,
              itemBuilder: (context, index) {
                final alpha = _alphabets[index];
                return _AlphabetCard(
                  urdu: alpha['urdu']!,
                  roman: alpha['roman']!,
                  description: alpha['desc']!,
                  index: index,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AlphabetCard extends StatelessWidget {
  final String urdu;
  final String roman;
  final String description;
  final int index;

  const _AlphabetCard({
    required this.urdu,
    required this.roman,
    required this.description,
    required this.index,
  });

  static const List<Color> _colors = [
    Color(0xFF006400),
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
    Color(0xFF00695C),
    Color(0xFF827717),
    Color(0xFFB71C1C),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[index % _colors.length];

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.5)),
              ),
              child: Center(
                child: Text(
                  urdu,
                  style: const TextStyle(
                    fontFamily: 'JameelNooriNastaleeq',
                    fontSize: 28,
                    color: Colors.white,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              roman,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                description,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final color = _colors[index % _colors.length];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color, width: 2),
              ),
              child: Center(
                child: Text(
                  urdu,
                  style: const TextStyle(
                    fontFamily: 'JameelNooriNastaleeq',
                    fontSize: 56,
                    color: Colors.white,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              roman,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hand Sign: $description',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              label: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class AlphabetGuideScreen extends StatefulWidget {
  const AlphabetGuideScreen({super.key});
  @override
  State<AlphabetGuideScreen> createState() => _AlphabetGuideScreenState();
}

class _AlphabetGuideScreenState extends State<AlphabetGuideScreen>
    with TickerProviderStateMixin {
  int? _expanded;
  late AnimationController _headerCtrl;
  late Animation<double> _headerAnim;
  String _search = '';

  static const List<Map<String, dynamic>> _signs = [
    {'urdu':'ا','roman':'Alif',   'desc':'Open hand, all fingers extended upward — palm faces forward','color1':0xFF667EEA,'color2':0xFF764BA2,'fingers':'11111'},
    {'urdu':'ب','roman':'Bay',    'desc':'Index finger pointing straight up, rest closed','color1':0xFFFF6B6B,'color2':0xFFEE5A24,'fingers':'01000'},
    {'urdu':'پ','roman':'Pay',    'desc':'Index and middle fingers spread in V shape upward','color1':0xFF26de81,'color2':0xFF20bf6b,'fingers':'01100'},
    {'urdu':'ت','roman':'Tay',    'desc':'Three fingers (index, middle, ring) up together','color1':0xFFfd9644,'color2':0xFFe55039,'fingers':'01110'},
    {'urdu':'ٹ','roman':'Taay',   'desc':'Three fingers bent/curled slightly forward','color1':0xFFa55eea,'color2':0xFF8854d0,'fingers':'01110'},
    {'urdu':'ث','roman':'Say',    'desc':'Four fingers spread wide, thumb tucked in','color1':0xFF2bcbba,'color2':0xFF0fb9b1,'fingers':'11110'},
    {'urdu':'ج','roman':'Jeem',   'desc':'Index and middle fingers form a V, rest closed','color1':0xFFFC427A,'color2':0xFFfd79a8,'fingers':'01100'},
    {'urdu':'چ','roman':'Chay',   'desc':'Curved index finger pointing sideways','color1':0xFF4b7bec,'color2':0xFF3867d6,'fingers':'01000'},
    {'urdu':'ح','roman':'Hay',    'desc':'Open palm facing outward, fingers together','color1':0xFF20bf6b,'color2':0xFF0be881,'fingers':'11111'},
    {'urdu':'خ','roman':'Khay',   'desc':'Open palm facing inward toward chest','color1':0xFFf7b731,'color2':0xFFfed330,'fingers':'11111'},
    {'urdu':'د','roman':'Daal',   'desc':'Thumb and index finger form a circle (OK sign)','color1':0xFFfc5c65,'color2':0xFFeb3b5a,'fingers':'10001'},
    {'urdu':'ڈ','roman':'Dal Drwaza','desc':'Thumb and index pinch together, others spread','color1':0xFF2d98da,'color2':0xFF0a3d62,'fingers':'10001'},
    {'urdu':'ذ','roman':'Zaal',   'desc':'Index finger pointing sideways/horizontally','color1':0xFFe55039,'color2':0xFFc0392b,'fingers':'01000'},
    {'urdu':'ر','roman':'Ray',    'desc':'Index finger curved/pointing downward','color1':0xFF8e44ad,'color2':0xFF6c3483,'fingers':'01000'},
    {'urdu':'ڑ','roman':'Rdy',    'desc':'Index and middle fingers pointing down','color1':0xFF16a085,'color2':0xFF1abc9c,'fingers':'01100'},
    {'urdu':'ز','roman':'Zay',    'desc':'Closed fist with pinky finger raised up','color1':0xFF2980b9,'color2':0xFF3498db,'fingers':'00001'},
    {'urdu':'س','roman':'Say2',   'desc':'Three fingers pointing sideways','color1':0xFFd35400,'color2':0xFFe67e22,'fingers':'01110'},
    {'urdu':'ش','roman':'Sheen',  'desc':'Four fingers waving/spread sideways','color1':0xFF27ae60,'color2':0xFF2ecc71,'fingers':'01111'},
    {'urdu':'ص','roman':'Suaad',  'desc':'Thumb crosses over closed palm','color1':0xFFc0392b,'color2':0xFFe74c3c,'fingers':'10000'},
    {'urdu':'ض','roman':'Duaad',  'desc':'Thumb and pinky both extended out','color1':0xFF8e44ad,'color2':0xFF9b59b6,'fingers':'10001'},
    {'urdu':'ط','roman':'Tua',    'desc':'All fingers curled inward into fist','color1':0xFF2c3e50,'color2':0xFF34495e,'fingers':'00000'},
    {'urdu':'ظ','roman':'Zua',    'desc':'Wrist bent forward, fingers curled','color1':0xFF16a085,'color2':0xFF1abc9c,'fingers':'00000'},
    {'urdu':'ع','roman':'Ain',    'desc':'Ring and middle fingers crossed over each other','color1':0xFFe74c3c,'color2':0xFFc0392b,'fingers':'01110'},
    {'urdu':'غ','roman':'Gaaf',   'desc':'Index finger pointing up with slight curve','color1':0xFF2980b9,'color2':0xFF1a5276,'fingers':'01000'},
    {'urdu':'ف','roman':'Fay',    'desc':'All fingers pinched together at tips (beak)','color1':0xFFf39c12,'color2':0xFFd35400,'fingers':'11111'},
    {'urdu':'ق','roman':'Kaaf',   'desc':'Index and middle fingers together, bent at knuckle','color1':0xFF6c3483,'color2':0xFF8e44ad,'fingers':'01100'},
    {'urdu':'ک','roman':'Kaaf',   'desc':'Index finger bent like a hook','color1':0xFF1a5276,'color2':0xFF2980b9,'fingers':'01000'},
    {'urdu':'گ','roman':'Gaaf',   'desc':'Pointing index with thumb out to side','color1':0xFF117a65,'color2':0xFF16a085,'fingers':'11000'},
    {'urdu':'ل','roman':'Laam',   'desc':'L-shape: index up, thumb out sideways','color1':0xFF922b21,'color2':0xFFc0392b,'fingers':'11000'},
    {'urdu':'م','roman':'Meem',   'desc':'Thumb tucked under curved fingers','color1':0xFF1f618d,'color2':0xFF2e86c1,'fingers':'00000'},
    {'urdu':'ن','roman':'Noon',   'desc':'Index finger bent into hook shape facing down','color1':0xFF196f3d,'color2':0xFF27ae60,'fingers':'01000'},
    {'urdu':'و','roman':'Wow',    'desc':'Closed fist with thumb pointing sideways','color1':0xFF7d6608,'color2':0xFFf39c12,'fingers':'10000'},
    {'urdu':'ہ','roman':'Hay2',   'desc':'Open palm facing up like holding something','color1':0xFF4a235a,'color2':0xFF7d3c98,'fingers':'11111'},
    {'urdu':'ء','roman':'Hamza',  'desc':'Index and thumb form a small circle','color1':0xFF154360,'color2':0xFF1f618d,'fingers':'11000'},
    {'urdu':'ی','roman':'Yaay',   'desc':'Pinky finger raised, others closed','color1':0xFF0e6655,'color2':0xFF17a589,'fingers':'00001'},
    {'urdu':'ے','roman':'Bari Yay','desc':'Index and pinky both raised (horns shape)','color1':0xFF6e2f1a,'color2':0xFFca6f1e,'fingers':'01001'},
    {'urdu':'أ','roman':'Alif Hamza','desc':'Open hand slightly tilted with thumb out','color1':0xFF512e5f,'color2':0xFF8e44ad,'fingers':'11111'},
  ];

  List<Map<String, dynamic>> get _filtered => _search.isEmpty
      ? _signs
      : _signs.where((s) =>
          s['roman'].toString().toLowerCase().contains(_search.toLowerCase()) ||
          s['urdu'].toString().contains(_search)).toList();

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600));
    _headerAnim = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerCtrl.forward();
  }

  @override
  void dispose() { _headerCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildSearchBar()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildSignCard(i),
                childCount: _filtered.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: const Color(0xFF667EEA),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _headerAnim,
              child: Column(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  const Text('حروف تہجی رہنما',
                    style: TextStyle(fontFamily: 'JameelNooriNastaleeq',
                        color: Colors.white, fontSize: 26,
                        fontWeight: FontWeight.bold),
                    textDirection: TextDirection.rtl),
                  const SizedBox(height: 6),
                  Text('${_signs.length} Urdu Sign Language Gestures',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
            ),
          ),
        ),
        title: const Text('Alphabet Guide',
          style: TextStyle(color: Colors.white, fontSize: 16,
              fontWeight: FontWeight.bold)),
        titlePadding: const EdgeInsets.only(left: 60, bottom: 16),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF667EEA).withOpacity(0.15),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: TextField(
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'Search letter... (e.g. Alif, Bay)',
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF667EEA)),
          suffixIcon: _search.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => setState(() => _search = ''))
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSignCard(int i) {
    final sign = _filtered[i];
    final c1 = Color(sign['color1'] as int);
    final c2 = Color(sign['color2'] as int);
    final isExpanded = _expanded == i;

    return GestureDetector(
      onTap: () => setState(() => _expanded = isExpanded ? null : i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: c1.withOpacity(isExpanded ? 0.35 : 0.15),
              blurRadius: isExpanded ? 20 : 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isExpanded ? c1.withOpacity(0.5) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(children: [
          // Gradient header with hand drawing
          Container(
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [c1, c2]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Stack(children: [
              // Background circles for depth
              Positioned(right: -15, top: -15,
                child: Container(width: 70, height: 70,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1)))),
              Positioned(left: -10, bottom: -10,
                child: Container(width: 50, height: 50,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08)))),
              // Hand gesture drawing
              Center(child: _HandGesture(
                  fingers: sign['fingers'] as String,
                  color: Colors.white)),
              // Urdu letter badge
              Positioned(top: 8, right: 10,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      shape: BoxShape.circle),
                  child: Center(child: Text(sign['urdu'] as String,
                    style: const TextStyle(
                        fontFamily: 'JameelNooriNastaleeq',
                        color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.bold),
                    textDirection: TextDirection.rtl)),
                )),
            ]),
          ),
          // Info section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(sign['roman'] as String,
                        style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.bold, color: c1)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: c1.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(sign['urdu'] as String,
                          style: TextStyle(fontFamily: 'JameelNooriNastaleeq',
                              color: c1, fontSize: 14,
                              fontWeight: FontWeight.bold),
                          textDirection: TextDirection.rtl),
                      ),
                    ]),
                  if (isExpanded) ...[
                    const SizedBox(height: 6),
                    Text(sign['desc'] as String,
                      style: const TextStyle(fontSize: 11,
                          color: Color(0xFF555555), height: 1.4)),
                  ] else ...[
                    const SizedBox(height: 4),
                    const Row(children: [
                      Icon(Icons.touch_app, size: 11, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('Tap to see details',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Custom Hand Gesture Painter ───────────────────────────────────────────────

/// fingers: 5-char string "01110"
///   char[0]=thumb, [1]=index, [2]=middle, [3]=ring, [4]=pinky
///   '1'=extended, '0'=closed
class _HandGesture extends StatelessWidget {
  final String fingers;
  final Color color;
  const _HandGesture({required this.fingers, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70, height: 80,
      child: CustomPaint(
        painter: _HandPainter(fingers: fingers, color: color),
      ),
    );
  }
}

class _HandPainter extends CustomPainter {
  final String fingers;
  final Color color;
  _HandPainter({required this.fingers, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final palmPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final cx = size.width / 2;
    final palmTop = size.height * 0.52;
    final palmBottom = size.height * 0.92;
    final palmLeft = cx - 18;
    final palmRight = cx + 18;

    // Draw palm
    final palmPath = Path()
      ..moveTo(palmLeft, palmTop)
      ..lineTo(palmLeft, palmBottom)
      ..quadraticBezierTo(cx, palmBottom + 4, palmRight, palmBottom)
      ..lineTo(palmRight, palmTop)
      ..close();
    canvas.drawPath(palmPath, palmPaint);
    canvas.drawPath(palmPath, outlinePaint);

    // Finger positions (x offset from center, width)
    final fingerData = [
      // [xOffset, width, heightExtended, heightClosed]
      [-22.0, 9.0, 28.0, 12.0], // thumb (angled)
      [-12.0, 8.0, 32.0, 10.0], // index
      [-2.0,  8.0, 35.0, 10.0], // middle
      [ 8.0,  8.0, 30.0, 10.0], // ring
      [18.0,  7.0, 24.0,  9.0], // pinky
    ];

    for (int i = 0; i < 5; i++) {
      final fd = fingerData[i];
      final isExtended = i < fingers.length && fingers[i] == '1';
      final fx = cx + fd[0];
      final fw = fd[1];
      final fh = isExtended ? fd[2] : fd[3];

      final fy = isExtended
          ? palmTop - fh
          : palmTop - fh * 0.35;

      // Thumb is slightly angled
      if (i == 0) {
        final thumbPath = Path()
          ..moveTo(fx - 2, palmTop)
          ..quadraticBezierTo(
              fx - fw * 0.5, fy + fh * 0.3,
              fx - fw,       fy)
          ..quadraticBezierTo(
              fx, fy - fw * 0.3,
              fx + fw * 0.5, fy + fh * 0.2)
          ..lineTo(fx + 2, palmTop)
          ..close();
        canvas.drawPath(thumbPath, palmPaint);
        canvas.drawPath(thumbPath, outlinePaint);
      } else {
        // Regular finger (rounded rectangle)
        final rRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(fx - fw / 2, fy, fw, fh),
          Radius.circular(fw / 2),
        );
        canvas.drawRRect(rRect, palmPaint);
        canvas.drawRRect(rRect, outlinePaint);

        // Knuckle lines
        if (!isExtended) {
          canvas.drawLine(
            Offset(fx - fw / 2 + 2, palmTop - 3),
            Offset(fx + fw / 2 - 2, palmTop - 3),
            outlinePaint,
          );
        }
      }
    }

    // Wrist
    final wristPaint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(palmLeft + 2, palmBottom - 2, palmRight - palmLeft - 4, 8),
        const Radius.circular(4),
      ),
      wristPaint,
    );
  }

  @override
  bool shouldRepaint(_HandPainter old) => old.fingers != fingers;
}

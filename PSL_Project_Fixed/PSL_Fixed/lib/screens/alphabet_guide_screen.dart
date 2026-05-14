import 'package:flutter/material.dart';

class AlphabetGuideScreen extends StatefulWidget {
  const AlphabetGuideScreen({super.key});
  @override State<AlphabetGuideScreen> createState() => _AlphabetGuideScreenState();
}

class _AlphabetGuideScreenState extends State<AlphabetGuideScreen>
    with SingleTickerProviderStateMixin {
  String _search = '';
  int? _selected;
  late TabController _tab;

  // Signs matching the PSL dataset reference image (Urdu alphabet order)
  static const List<Map<String, dynamic>> _signs = [
    // Row 1
    {'u':'ا','r':'Alif',      'g':'Index finger pointing straight up, fist closed around others','f':'01000','c':[0xFF667EEA,0xFF764BA2]},
    {'u':'ب','r':'Bay',       'g':'Four fingers extended flat and horizontal, thumb tucked under','f':'01111','c':[0xFFFF6B6B,0xFFEE5A24]},
    {'u':'پ','r':'Pay',       'g':'Flat hand with four fingers pointing forward, palm down','f':'01111','c':[0xFF26de81,0xFF20bf6b]},
    {'u':'ت','r':'Tay',       'g':'Index + middle fingers pointing up (V/peace sign), others closed','f':'01100','c':[0xFFfd9644,0xFFe55039]},
    {'u':'ٹ','r':'Taay',      'g':'Closed fist, all fingers curled tightly','f':'00000','c':[0xFFa55eea,0xFF8854d0]},
    {'u':'ث','r':'Say',       'g':'Index + middle + ring fingers spread upward, pinky and thumb closed','f':'01110','c':[0xFF2bcbba,0xFF0fb9b1]},
    {'u':'ج','r':'Jeem',      'g':'Index + middle fingers bent/hooked forward together','f':'01100','c':[0xFFFC427A,0xFFfd79a8]},
    {'u':'چ','r':'Chay',      'g':'Index finger curved into C-shape, all other fingers closed','f':'01000','c':[0xFF4b7bec,0xFF3867d6]},
    {'u':'ح','r':'Hay',       'g':'Open palm facing outward, all fingers together and extended','f':'11111','c':[0xFF20bf6b,0xFF0be881]},
    {'u':'خ','r':'Khay',      'g':'Open hand with all fingers spread wide apart, palm forward','f':'11111','c':[0xFFf7b731,0xFFfed330]},
    // Row 2
    {'u':'د','r':'Daal',      'g':'Index finger pointing sideways (left), other fingers closed in fist','f':'01000','c':[0xFFfc5c65,0xFFeb3b5a]},
    {'u':'ڈ','r':'Ddal',      'g':'Thumb and index form an L/D-shape, remaining fingers closed','f':'11000','c':[0xFF2d98da,0xFF0a3d62]},
    {'u':'ذ','r':'Zaal',      'g':'Index finger pointing forward-down, fist closed','f':'01000','c':[0xFFe55039,0xFFc0392b]},
    {'u':'ر','r':'Ray',       'g':'Index finger hooked/bent downward, other fingers curled','f':'01000','c':[0xFF8e44ad,0xFF6c3483]},
    {'u':'ڑ','r':'Rra',       'g':'Index + middle fingers crossed or bent together downward','f':'01100','c':[0xFF16a085,0xFF1abc9c]},
    {'u':'ز','r':'Zay',       'g':'Index finger up + thumb extended out (pistol/L shape)','f':'11000','c':[0xFF2980b9,0xFF3498db]},
    {'u':'س','r':'Seen',      'g':'Index + middle + ring fingers pointing sideways, thumb and pinky closed','f':'01110','c':[0xFFd35400,0xFFe67e22]},
    {'u':'ش','r':'Sheen',     'g':'Index + middle + ring fingers spread wide and fanned out upward','f':'01110','c':[0xFF27ae60,0xFF2ecc71]},
    {'u':'ص','r':'Suaad',     'g':'Thumb extended to side, index slightly curved, other fingers curled','f':'11000','c':[0xFFc0392b,0xFFe74c3c]},
    // Row 3
    {'u':'ض','r':'Duaad',     'g':'Thumb + pinky extended outward (shaka/Y-shape), middle fingers closed','f':'10001','c':[0xFF8e44ad,0xFF9b59b6]},
    {'u':'ط','r':'Tua',       'g':'All fingers curled into a tight fist, palm facing forward','f':'00000','c':[0xFF2c3e50,0xFF34495e]},
    {'u':'ظ','r':'Zua',       'g':'Fist with wrist angled, back of hand facing forward','f':'00000','c':[0xFF16a085,0xFF1abc9c]},
    {'u':'ع','r':'Ain',       'g':'Index + middle + ring fingers overlapping or crossing each other','f':'01110','c':[0xFFe74c3c,0xFFc0392b]},
    {'u':'غ','r':'Ghain',     'g':'Index finger bent at knuckle and pointing sideways, others closed','f':'01000','c':[0xFF2980b9,0xFF1a5276]},
    {'u':'ف','r':'Fay',       'g':'All five fingertips pinched together (beak shape), pointing forward','f':'11111','c':[0xFFf39c12,0xFFd35400]},
    {'u':'ق','r':'Qaaf',      'g':'Index + middle up (V-sign), thumb touches ring finger','f':'01100','c':[0xFF6c3483,0xFF8e44ad]},
    {'u':'ک','r':'Kaaf',      'g':'Index finger bent into a hook/hook shape, pointing sideways','f':'01000','c':[0xFF1a5276,0xFF2980b9]},
    {'u':'گ','r':'Gaaf',      'g':'Index + thumb form an L-shape (gun), other fingers closed','f':'11000','c':[0xFF117a65,0xFF16a085]},
    {'u':'ل','r':'Laam',      'g':'Index pointing straight up + thumb extended out to side (L-shape)','f':'11000','c':[0xFF922b21,0xFFc0392b]},
    // Row 4
    {'u':'م','r':'Meem',      'g':'Closed fist with thumb tucked beneath all curled fingers','f':'00000','c':[0xFF1f618d,0xFF2e86c1]},
    {'u':'ن','r':'Noon',      'g':'Index finger pointing forward/slightly curved, others curled','f':'01000','c':[0xFF196f3d,0xFF27ae60]},
    {'u':'و','r':'Wow',       'g':'Closed fist with thumb pointing out to the side','f':'10000','c':[0xFF7d6608,0xFFf39c12]},
    {'u':'ہ','r':'Hay2',      'g':'Open palm facing upward, all five fingers relaxed and spread','f':'11111','c':[0xFF4a235a,0xFF7d3c98]},
    {'u':'ع','r':'Ain2',      'g':'Index finger pointing slightly forward and up, others curled','f':'01000','c':[0xFF154360,0xFF1f618d]},
    {'u':'ی','r':'Choti Yay', 'g':'Pinky finger raised straight up, all other fingers closed','f':'00001','c':[0xFF0e6655,0xFF17a589]},
    {'u':'ے','r':'Bari Yay',  'g':'Index + pinky raised (rock sign / ILY), middle fingers closed','f':'01001','c':[0xFF6e2f1a,0xFFca6f1e]},
    {'u':'أ','r':'Alif Hamza','g':'Open hand with all fingers extended, thumb slightly raised','f':'11111','c':[0xFF512e5f,0xFF8e44ad]},
  ];

  List<Map<String,dynamic>> get _filtered => _search.isEmpty ? _signs
      : _signs.where((s) => s['r'].toString().toLowerCase()
          .contains(_search.toLowerCase()) || s['u'].toString().contains(_search)).toList();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f1a),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildAppBar()],
        body: Column(children: [
          _buildSearchBar(),
          _buildTabBar(),
          Expanded(child: TabBarView(controller: _tab, children: [
            _buildGrid(),
            _buildList(),
          ])),
        ]),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: const Color(0xFF0f0f1a),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context)),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF1a1a3e), Color(0xFF0f0f1a)])),
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end, children: [
              const Text('Sign Language Guide',
                  style: TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${_signs.length} Urdu PSL Gestures  •  Pakistan Sign Language',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ])))),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12))),
        child: TextField(
          onChanged: (v) => setState(() { _search = v; }),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search by name, e.g. Alif, Bay...',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            prefixIcon: const Icon(Icons.search, color: Colors.white38),
            suffixIcon: _search.isNotEmpty
                ? IconButton(icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                    onPressed: () => setState(() => _search=''))
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14)),
        )));
  }

  Widget _buildTabBar() {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14)),
        child: TabBar(
          controller: _tab,
          indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)])),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: '  Grid View  '), Tab(text: '  List View  ')],
        )));
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 12,
          crossAxisSpacing: 12, childAspectRatio: 0.82),
      itemCount: _filtered.length,
      itemBuilder: (_, i) => _buildGridCard(i),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filtered.length,
      itemBuilder: (_, i) => _buildListCard(i),
    );
  }

  Widget _buildGridCard(int i) {
    final s = _filtered[i];
    final c1 = Color((s['c'] as List)[0] as int);
    final c2 = Color((s['c'] as List)[1] as int);
    final sel = _selected == i;

    return GestureDetector(
      onTap: () => setState(() => _selected = sel ? null : i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? c1 : Colors.white.withOpacity(0.08),
              width: sel ? 2 : 1),
          boxShadow: sel ? [BoxShadow(color: c1.withOpacity(0.3),
              blurRadius: 16, offset: const Offset(0, 4))] : [],
        ),
        child: Column(children: [
          // Header with gradient + hand drawing
          Container(height: 105,
            decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft,
                    end: Alignment.bottomRight, colors: [c1, c2]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(19))),
            child: Stack(children: [
              // Decorative circles
              Positioned(right:-15, top:-15, child: Container(width:60, height:60,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1)))),
              // Hand illustration
              Center(child: _HandIllustration(fingers: s['f'] as String)),
              // Urdu letter top-right
              Positioned(top:8, right:10,
                child: Container(width:34, height:34,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2)),
                  child: Center(child: Text(s['u'] as String,
                    style: const TextStyle(fontFamily: 'JameelNooriNastaleeq',
                        color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    textDirection: TextDirection.rtl)))),
            ])),
          // Body
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(s['r'] as String, style: TextStyle(color: c1, fontSize: 14,
                      fontWeight: FontWeight.bold)),
                  Text(s['u'] as String, style: const TextStyle(
                      fontFamily: 'JameelNooriNastaleeq',
                      color: Colors.white70, fontSize: 14),
                      textDirection: TextDirection.rtl),
                ]),
                const SizedBox(height: 5),
                if (sel)
                  Expanded(child: Text(s['g'] as String,
                      style: const TextStyle(color: Colors.white60,
                          fontSize: 10, height: 1.4),
                      maxLines: 4, overflow: TextOverflow.ellipsis))
                else
                  const Text('Tap to see gesture details',
                      style: TextStyle(color: Colors.white30, fontSize: 10)),
              ])),
          ),
        ]),
      ),
    );
  }

  Widget _buildListCard(int i) {
    final s = _filtered[i];
    final c1 = Color((s['c'] as List)[0] as int);
    final c2 = Color((s['c'] as List)[1] as int);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Row(children: [
        // Gradient circle with hand
        Container(width: 60, height: 60,
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c1, c2]),
              borderRadius: BorderRadius.circular(16)),
          child: Center(child: _HandIllustration(fingers: s['f'] as String, size: 40))),
        const SizedBox(width: 14),
        // Info
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(s['r'] as String, style: TextStyle(color: c1,
                  fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: c1.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(s['u'] as String, style: TextStyle(
                    fontFamily: 'JameelNooriNastaleeq', color: c1,
                    fontSize: 14, fontWeight: FontWeight.bold),
                    textDirection: TextDirection.rtl)),
            ]),
            const SizedBox(height: 4),
            Text(s['g'] as String, style: const TextStyle(
                color: Colors.white54, fontSize: 11, height: 1.4),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ])),
      ]),
    );
  }
}

// ── Custom hand illustration with 3D look ──────────────────────────────────────

class _HandIllustration extends StatelessWidget {
  final String fingers;
  final double size;
  const _HandIllustration({required this.fingers, this.size = 56});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: size, height: size * 1.15,
      child: CustomPaint(painter: _Hand3DPainter(fingers: fingers)));
}

class _Hand3DPainter extends CustomPainter {
  final String fingers;
  _Hand3DPainter({required this.fingers});

  bool get(int i) => i < fingers.length && fingers[i] == '1';

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width; final h = s.height;
    final cx = w * 0.5;
    final palmTop = h * 0.48; final palmBot = h * 0.88;

    // Shadow paint
    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // Palm fill
    final palmFill = Paint()..color = Colors.white.withOpacity(0.92)..style = PaintingStyle.fill;
    final palmEdge = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw palm shadow
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - 16, palmTop + 2, 32, palmBot - palmTop),
            const Radius.circular(8)),
        shadow);

    // Draw palm
    final palmPath = Path()
      ..moveTo(cx - 16, palmTop + 4)
      ..lineTo(cx - 16, palmBot - 6)
      ..quadraticBezierTo(cx - 16, palmBot + 2, cx - 8, palmBot + 4)
      ..quadraticBezierTo(cx, palmBot + 6, cx + 8, palmBot + 4)
      ..quadraticBezierTo(cx + 16, palmBot + 2, cx + 16, palmBot - 6)
      ..lineTo(cx + 16, palmTop + 4)
      ..close();
    canvas.drawPath(palmPath, palmFill);
    canvas.drawPath(palmPath, palmEdge);

    // Finger specs: [xOff, width, extendedH, closedH]
    final specs = [
      [-20.0, 7.0, h*0.28, h*0.08], // thumb
      [-10.0, 7.0, h*0.36, h*0.09], // index
      [-1.5,  7.0, h*0.40, h*0.09], // middle
      [ 8.0,  6.5, h*0.34, h*0.08], // ring
      [16.5,  5.5, h*0.26, h*0.07], // pinky
    ];

    for (int i = 0; i < 5; i++) {
      final sp = specs[i];
      final extended = get(i);
      final fx = cx + sp[0];
      final fw = sp[1];
      final fh = extended ? sp[2] : sp[3];
      final fy = extended ? palmTop - fh : palmTop - fh * 0.6;

      // Shadow
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(fx - fw/2 + 1, fy + 2, fw, fh),
              Radius.circular(fw/2)),
          shadow);

      if (i == 0) {
        // Thumb — angled
        final tPath = Path();
        if (extended) {
          tPath
            ..moveTo(fx + 2, palmTop + 4)
            ..quadraticBezierTo(fx - fw*1.2, palmTop - fh*0.4,
                fx - fw*0.8, fy)
            ..quadraticBezierTo(fx + fw*0.5, fy - fw*0.2,
                fx + fw, fy + fh*0.3)
            ..lineTo(fx + 4, palmTop + 4)
            ..close();
        } else {
          tPath
            ..moveTo(fx - 2, palmTop + 2)
            ..quadraticBezierTo(fx - fw*0.8, palmTop - fh*0.4,
                fx - fw*0.4, fy)
            ..quadraticBezierTo(fx + fw*0.3, fy + fh*0.2,
                fx + fw*0.2, palmTop + 2)
            ..close();
        }
        canvas.drawPath(tPath, palmFill);
        canvas.drawPath(tPath, palmEdge);
      } else {
        // Regular finger
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(fx - fw/2, fy, fw, fh),
                Radius.circular(fw/2)),
            palmFill);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(fx - fw/2, fy, fw, fh),
                Radius.circular(fw/2)),
            palmEdge);
        // Knuckle detail
        if (!extended && fh > 6) {
          final knPaint = Paint()
            ..color = Colors.white.withOpacity(0.3)
            ..strokeWidth = 0.8
            ..style = PaintingStyle.stroke;
          canvas.drawLine(
              Offset(fx - fw/2 + 2, palmTop - 2),
              Offset(fx + fw/2 - 2, palmTop - 2),
              knPaint);
        }
        // Fingernail for extended fingers
        if (extended && fh > 10) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromLTWH(fx - fw/2 + 1.5, fy + 2, fw - 3, fh*0.25),
                  const Radius.circular(3)),
              Paint()..color = Colors.white.withOpacity(0.35));
        }
      }
    }

    // Wrist joint line
    canvas.drawLine(
        Offset(cx - 14, palmBot - 3),
        Offset(cx + 14, palmBot - 3),
        Paint()..color = Colors.white.withOpacity(0.25)..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(_Hand3DPainter o) => o.fingers != fingers;
}

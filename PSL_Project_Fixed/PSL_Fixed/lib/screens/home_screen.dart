import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/model_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade  = CurvedAnimation(parent: _fadeCtrl,  curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    Future.delayed(const Duration(milliseconds: 100), () {
      _fadeCtrl.forward(); _slideCtrl.forward();
    });
  }

  @override
  void dispose() { _fadeCtrl.dispose(); _slideCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: CustomScrollView(slivers: [
        _buildAppBar(),
        SliverToBoxAdapter(
          child: FadeTransition(opacity: _fade,
            child: SlideTransition(position: _slide,
              child: Padding(padding: const EdgeInsets.all(20),
                child: Column(children: [
                  _buildModelStatus(),
                  const SizedBox(height: 24),
                  _buildDetectButton(),
                  const SizedBox(height: 20),
                  _buildFeatureCards(),
                  const SizedBox(height: 20),
                  _buildHowToUse(),
                  const SizedBox(height: 20),
                  _buildStatsRow(),
                  const SizedBox(height: 20),
                  _buildDesignerCredit(),
                  const SizedBox(height: 12),
                ])))),
        ),
      ]),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200, pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFF667EEA),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)])),
          child: SafeArea(child: Stack(children: [
            Positioned(right: -30, top: -30, child: Container(width: 160, height: 160,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.07)))),
            Positioned(left: -20, bottom: -20, child: Container(width: 120, height: 120,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05)))),
            Padding(padding: const EdgeInsets.fromLTRB(24,20,24,16),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(height: 10),
                Container(padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.2),
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20)]),
                  child: const Icon(Icons.sign_language, size: 44, color: Colors.white)),
                const SizedBox(height: 14),
                const Text('پاکستان اشارہ زبان',
                    style: TextStyle(fontFamily: 'JameelNooriNastaleeq',
                        color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                    textDirection: TextDirection.rtl),
                const SizedBox(height: 4),
                const Text('PSL Urdu Sign Language Detector',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ])),
          ])),
        ),
      ),
    );
  }

  Widget _buildModelStatus() {
    return Consumer<ModelService>(builder: (_, model, __) {
      final ready = model.isLoaded; final loading = model.isLoading;
      return AnimatedContainer(duration: const Duration(milliseconds: 500),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: ready ? const Color(0xFF00C853).withOpacity(0.1)
              : loading ? const Color(0xFFFFD600).withOpacity(0.1)
              : const Color(0xFFFF5252).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ready ? const Color(0xFF00C853).withOpacity(0.4)
              : loading ? const Color(0xFFFFD600).withOpacity(0.4)
              : const Color(0xFFFF5252).withOpacity(0.4))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (loading)
            const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD600)))
          else
            Icon(ready ? Icons.check_circle : Icons.error_outline,
                color: ready ? const Color(0xFF00C853) : const Color(0xFFFF5252), size: 18),
          const SizedBox(width: 10),
          Text(ready ? 'AI Model Ready — Start Detecting!'
              : loading ? 'Loading AI Model...' : 'Model failed to load',
              style: TextStyle(fontWeight: FontWeight.w600,
                  color: ready ? const Color(0xFF00C853)
                      : loading ? const Color(0xFFF57F17) : const Color(0xFFFF5252))),
        ]));
    });
  }

  Widget _buildDetectButton() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/detection'),
      child: Container(height: 130,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: const Color(0xFF667EEA).withOpacity(0.45),
              blurRadius: 25, offset: const Offset(0, 10))]),
        child: Stack(children: [
          Positioned(right: -10, bottom: -10, child: Icon(Icons.sign_language,
              size: 130, color: Colors.white.withOpacity(0.06))),
          Positioned(right: 20, top: 16, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20)),
            child: const Row(children: [
              Icon(Icons.circle, color: Color(0xFF00E676), size: 8),
              SizedBox(width: 5),
              Text('LIVE', style: TextStyle(color: Colors.white,
                  fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ]))),
          Padding(padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, children: [
              const Row(children: [
                Icon(Icons.camera_alt, color: Colors.white, size: 26),
                SizedBox(width: 12),
                Text('Start Detection', style: TextStyle(color: Colors.white,
                    fontSize: 22, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Text('شناخت شروع کریں',
                    style: TextStyle(fontFamily: 'JameelNooriNastaleeq',
                        color: Colors.white.withOpacity(0.85), fontSize: 16),
                    textDirection: TextDirection.rtl),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Row(children: [
                    Text('Open Camera', style: TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w600)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
                  ])),
              ]),
            ])),
        ])),
    );
  }

  Widget _buildFeatureCards() {
    final cards = [
      {'icon': Icons.menu_book_rounded, 'title': 'Alphabet Guide',
        'sub': 'حروف تہجی', 'desc': '37 PSL signs',
        'c1': const Color(0xFF26de81), 'c2': const Color(0xFF20bf6b), 'route': '/alphabet'},
      {'icon': Icons.info_outline_rounded, 'title': 'About PSL',
        'sub': 'معلومات', 'desc': 'Learn more',
        'c1': const Color(0xFFfd9644), 'c2': const Color(0xFFe55039), 'route': '/about'},
    ];
    return Row(children: cards.asMap().entries.map((e) {
      final i = e.key; final c = e.value;
      return Expanded(child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, c['route'] as String),
        child: Container(
          margin: EdgeInsets.only(right: i == 0 ? 8 : 0, left: i == 1 ? 8 : 0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [c['c1'] as Color, c['c2'] as Color]),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: (c['c1'] as Color).withOpacity(0.35),
                blurRadius: 15, offset: const Offset(0, 6))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(c['icon'] as IconData, color: Colors.white, size: 26)),
            const SizedBox(height: 14),
            Text(c['title'] as String, style: const TextStyle(color: Colors.white,
                fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text(c['sub'] as String, style: const TextStyle(
                fontFamily: 'JameelNooriNastaleeq', color: Colors.white70, fontSize: 13),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(c['desc'] as String, style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
          ]),
        )));
    }).toList());
  }

  Widget _buildHowToUse() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
            blurRadius: 15, offset: const Offset(0, 5))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(Icons.help_outline_rounded, color: Color(0xFF667EEA), size: 22),
          Text('کیسے استعمال کریں؟', style: TextStyle(fontFamily: 'JameelNooriNastaleeq',
              color: Color(0xFF667EEA), fontSize: 18, fontWeight: FontWeight.bold),
              textDirection: TextDirection.rtl),
        ]),
        const SizedBox(height: 16),
        _step(1,'📱','Open Camera','Tap "Start Detection" to open live camera',const Color(0xFF667EEA)),
        _step(2,'✋','Place Your Hand','Hold hand inside the white guide box',const Color(0xFF26de81)),
        _step(3,'🔤','See the Letter','Detected Urdu letter appears with confidence',const Color(0xFFfd9644)),
        _step(4,'📝','Build Words','Use Space/Undo buttons to form sentences',const Color(0xFFFC427A)),
      ]),
    );
  }

  Widget _step(int n, String em, String title, String desc, Color color) {
    return Padding(padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.15),
              shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.3))),
          child: Center(child: Text(em, style: const TextStyle(fontSize: 16)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
          Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 11, height: 1.3)),
        ])),
      ]));
  }

  Widget _buildStatsRow() {
    return Row(children: [
      _stat('37','Letters',Icons.abc,const Color(0xFF667EEA)),
      const SizedBox(width: 10),
      _stat('Live','Detection',Icons.speed,const Color(0xFF26de81)),
      const SizedBox(width: 10),
      _stat('AI','Powered',Icons.psychology,const Color(0xFFFC427A)),
    ]);
  }

  Widget _stat(String v, String l, IconData icon, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: color.withOpacity(0.15),
            blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(v, textAlign: TextAlign.center, style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.bold, color: color, height: 1.1)),
        const SizedBox(height: 3),
        Text(l, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
      ]),
    ));
  }

  Widget _buildDesignerCredit() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFF667EEA).withOpacity(0.08),
          const Color(0xFF764BA2).withOpacity(0.08)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF667EEA).withOpacity(0.15))),
      child: const Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.brush_rounded, size: 15, color: Color(0xFF764BA2)),
          SizedBox(width: 6),
          Text('Designed by Mehnail Jawad', style: TextStyle(fontSize: 13,
              color: Color(0xFF764BA2), fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        ]),
        SizedBox(height: 4),
        Text('FYP Project 2026', style: TextStyle(fontSize: 11,
            color: Colors.grey, letterSpacing: 1)),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'dart:math' as math;
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

// ── Global theme notifier ──
final themeNotifier = ValueNotifier<bool>(false);

Future<void> setTheme(bool isDark) async {
  themeNotifier.value = isDark;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('isDark', isDark);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final prefs  = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDark') ?? false;
  themeNotifier.value = isDark;
  await NotificationService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindSpace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF000000),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 7000), () {
      if (mounted) {
        FirebaseAuth.instance.authStateChanges().first.then((user) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => user != null
                    ? const HomeScreen()
                    : const OnboardingScreen(),
                transitionsBuilder: (_, anim, __, child) =>
                    FadeTransition(opacity: anim, child: child),
                transitionDuration: const Duration(milliseconds: 600),
              ),
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) => const SplashScreen();
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgCtrl;
  late AnimationController _logoCtrl;
  late AnimationController _ringsCtrl;
  late AnimationController _tagCtrl;
  late AnimationController _loadCtrl;
  final List<AnimationController> _letterCtrls = [];
  final List<Animation<double>> _letterY = [];
  final List<Animation<double>> _letterO = [];
  final _mind  = ['M','i','n','d'];
  final _space = ['S','p','a','c','e'];
  double _bgV=0,_lScale=0.2,_lRot=-8,_lOp=0;

  double _ease(double t) =>
      t<0.5?2*t*t:1-math.pow(-2*t+2,2)/2;
  double _lerp(double a,double b,double t)=>a+(b-a)*t;

  final _keys=[
    [0.00,0.2,-8.0,0.0],[0.30,1.12,2.0,1.0],
    [0.55,0.95,-1.0,1.0],[0.75,1.03,0.0,1.0],[1.00,1.00,0.0,1.0],
  ];

  @override
  void initState() {
    super.initState();
    _bgCtrl=AnimationController(vsync:this,duration:const Duration(seconds:7))
      ..addListener(()=>setState(()=>_bgV=_bgCtrl.value))
      ..repeat(reverse:true);
    _logoCtrl=AnimationController(vsync:this,duration:const Duration(milliseconds:2200))
      ..addListener(_onLogoTick);
    Future.delayed(const Duration(milliseconds:400),(){if(mounted)_logoCtrl.forward();});
    _ringsCtrl=AnimationController(vsync:this,duration:const Duration(milliseconds:1000));
    Future.delayed(const Duration(milliseconds:1200),(){if(mounted)_ringsCtrl.forward();});
    final all=[..._mind,..._space];
    for(int i=0;i<all.length;i++){
      final c=AnimationController(vsync:this,duration:const Duration(milliseconds:800));
      _letterCtrls.add(c);
      _letterY.add(Tween<double>(begin:-30,end:0).animate(CurvedAnimation(parent:c,curve:Curves.elasticOut)));
      _letterO.add(Tween<double>(begin:0,end:1).animate(CurvedAnimation(parent:c,curve:const Interval(0,0.35,curve:Curves.easeIn))));
      final delay=i<4?2500+i*180:3200+(i-4)*180;
      Future.delayed(Duration(milliseconds:delay),(){if(mounted)c.forward();});
    }
    _tagCtrl=AnimationController(vsync:this,duration:const Duration(milliseconds:1200));
    Future.delayed(const Duration(milliseconds:4500),(){if(mounted)_tagCtrl.forward();});
    _loadCtrl=AnimationController(vsync:this,duration:const Duration(milliseconds:2500));
    Future.delayed(const Duration(milliseconds:4800),(){if(mounted)_loadCtrl.forward();});
  }

  void _onLogoTick(){
    final raw=_logoCtrl.value;
    int i=0;
    while(i<_keys.length-2&&_keys[i+1][0]<=raw)i++;
    final k0=_keys[i],k1=_keys[i+1];
    final seg=((raw-k0[0])/(k1[0]-k0[0])).clamp(0.0,1.0);
    final e=_ease(seg);
    setState((){_lScale=_lerp(k0[1],k1[1],e);_lRot=_lerp(k0[2],k1[2],e);_lOp=_lerp(k0[3],k1[3],e);});
  }

  @override
  void dispose(){
    _bgCtrl.dispose();_logoCtrl.dispose();_ringsCtrl.dispose();
    _tagCtrl.dispose();_loadCtrl.dispose();
    for(final c in _letterCtrls)c.dispose();
    super.dispose();
  }

  Widget _letter(int i,String ch,Color col)=>AnimatedBuilder(
    animation:_letterCtrls[i],
    builder:(_,__)=>Opacity(opacity:_letterO[i].value,
      child:Transform.translate(offset:Offset(0,_letterY[i].value),
        child:Text(ch,style:TextStyle(fontSize:42,fontWeight:FontWeight.w600,color:col,letterSpacing:3,height:1.1)))));

  Widget _aurora(double x,double y,double r,Color c,double phase)=>Positioned(
    left:x-r,top:y-r,
    child:AnimatedBuilder(animation:_bgCtrl,builder:(_,__){
      final op=0.6+math.sin(_bgV*math.pi*2+phase)*0.2;
      return Container(width:r*2,height:r*2,decoration:BoxDecoration(shape:BoxShape.circle,
        gradient:RadialGradient(colors:[c.withOpacity(op),Colors.transparent])));
    }));

  @override
  Widget build(BuildContext context){
    final sz=MediaQuery.of(context).size;
    return Scaffold(backgroundColor:Colors.black,
      body:Stack(children:[
        _aurora(142,0,280,const Color(0xFF0A2814),0),
        _aurora(sz.width,sz.height,300,const Color(0xFF082312),1),
        _aurora(0,sz.height*0.5,200,const Color(0xFF06180E),0.5),
        Center(child:AnimatedBuilder(animation:_bgCtrl,builder:(_,__)=>Container(width:220,height:220,
          decoration:BoxDecoration(shape:BoxShape.circle,gradient:RadialGradient(colors:[
            const Color(0xFF143C20).withOpacity(0.12+math.sin(_bgV*math.pi*2)*0.04),Colors.transparent]))))),
        Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
          SizedBox(width:130,height:130,child:Stack(alignment:Alignment.center,children:[
            AnimatedBuilder(animation:_ringsCtrl,builder:(_,__)=>Opacity(
              opacity:(_ringsCtrl.value*3-2).clamp(0.0,1.0)*(0.4+math.sin(_bgV*math.pi*2)*0.25),
              child:Container(width:130,height:130,decoration:BoxDecoration(shape:BoxShape.circle,
                border:Border.all(color:const Color(0xFF52B788).withOpacity(0.05),width:0.5))))),
            AnimatedBuilder(animation:_ringsCtrl,builder:(_,__)=>Opacity(
              opacity:(_ringsCtrl.value*2-0.5).clamp(0.0,1.0)*(0.5+math.sin(_bgV*math.pi*2+1)*0.25),
              child:Container(width:108,height:108,decoration:BoxDecoration(shape:BoxShape.circle,
                border:Border.all(color:const Color(0xFF52B788).withOpacity(0.09),width:0.5))))),
            AnimatedBuilder(animation:_ringsCtrl,builder:(_,__)=>Opacity(
              opacity:_ringsCtrl.value.clamp(0.0,1.0)*(0.65+math.sin(_bgV*math.pi*2+2)*0.2),
              child:Container(width:86,height:86,decoration:BoxDecoration(shape:BoxShape.circle,
                border:Border.all(color:const Color(0xFF52B788).withOpacity(0.18),width:0.5))))),
            Opacity(opacity:_lOp,child:Transform.scale(scale:_lScale,child:Transform.rotate(angle:_lRot*math.pi/180,
              child:Container(width:80,height:80,decoration:BoxDecoration(
                borderRadius:BorderRadius.circular(24),
                gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,
                  colors:[Color(0xFF0F2E1A),Color(0xFF071A0D)]),
                border:Border.all(color:const Color(0xFF52B788).withOpacity(0.3),width:0.5),
                boxShadow:[BoxShadow(color:const Color(0xFF52B788).withOpacity(0.15),blurRadius:50,spreadRadius:8)]),
                child:Center(child:CustomPaint(size:const Size(44,44),painter:_LogoPainter())))))),
          ])),
          const SizedBox(height:22),
          Row(mainAxisSize:MainAxisSize.min,children:List.generate(_mind.length,(i)=>_letter(i,_mind[i],const Color(0xFFE8F5EE)))),
          Row(mainAxisSize:MainAxisSize.min,children:List.generate(_space.length,(i)=>_letter(i+_mind.length,_space[i],const Color(0xFF52B788)))),
          const SizedBox(height:14),
          FadeTransition(opacity:_tagCtrl,child:SlideTransition(
            position:Tween<Offset>(begin:const Offset(0,0.4),end:Offset.zero)
              .animate(CurvedAnimation(parent:_tagCtrl,curve:Curves.easeOut)),
            child:const Text('WELLNESS · CLARITY · GROWTH',
              style:TextStyle(fontSize:10,color:Color(0x5552B788),letterSpacing:3.5)))),
        ])),
        Positioned(bottom:48,left:0,right:0,child:AnimatedBuilder(animation:_loadCtrl,builder:(_,__)=>Column(children:[
          Center(child:SizedBox(width:48,height:1.5,child:ClipRRect(borderRadius:BorderRadius.circular(1),
            child:Stack(children:[
              Container(color:Colors.white.withOpacity(0.06)),
              FractionallySizedBox(widthFactor:_loadCtrl.value,child:Container(decoration:BoxDecoration(
                gradient:LinearGradient(colors:[Colors.transparent,
                  const Color(0xFF52B788).withOpacity(0.4+_loadCtrl.value*0.5),Colors.transparent])))),
            ])))),
          const SizedBox(height:8),
          Opacity(opacity:_loadCtrl.value>0.05?1.0:0.0,
            child:const Text('LOADING',style:TextStyle(fontSize:9,color:Color(0x4052B788),letterSpacing:3))),
        ]))),
      ]));
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas,Size size){
    final cx=size.width/2,cy=size.height*0.43,r=size.height*0.214;
    final white=Paint()..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=2.2..strokeCap=StrokeCap.round;
    final green=Paint()..color=const Color(0xFF52B788)..style=PaintingStyle.stroke..strokeWidth=2.2..strokeCap=StrokeCap.round;
    canvas.drawCircle(Offset(cx,cy),r,white);
    final wave=Path()..moveTo(cx-r*0.75,cy)..quadraticBezierTo(cx-r*0.35,cy-r*0.6,cx,cy)..quadraticBezierTo(cx+r*0.35,cy+r*0.6,cx+r*0.75,cy);
    canvas.drawPath(wave,green);
    final dot=Paint()..color=Colors.white;
    canvas.drawCircle(Offset(cx-r*0.42,cy-r*0.35),2.2,dot);
    canvas.drawCircle(Offset(cx+r*0.42,cy-r*0.35),2.2,dot);
    final body=Paint()..color=Colors.white..strokeWidth=2.0..strokeCap=StrokeCap.round;
    canvas.drawLine(Offset(cx,cy+r),Offset(cx,cy+r*1.65),body);
    canvas.drawLine(Offset(cx-r*0.6,cy+r*1.4),Offset(cx,cy+r*1.65),body);
    canvas.drawLine(Offset(cx+r*0.6,cy+r*1.4),Offset(cx,cy+r*1.65),body);
  }
  @override bool shouldRepaint(_)=>false;
}
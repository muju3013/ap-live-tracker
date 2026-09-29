import 'package:flutter/material.dart';
import '../theme/app_motion.dart';
import '../widgets/bottom_nav_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Staggered Animations for route, bus marker, GPS pulse & home crossfade exit
  late Animation<double> _routeProgress;
  late Animation<double> _busProgress;
  late Animation<double> _gpsPulse;
  late Animation<double> _exitFade;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Total splash timeline: 1200ms
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // A. ROUTE DRAW (100ms–550ms) -> Interval 0.08 to 0.46
    _routeProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.08, 0.46, curve: Curves.easeInOutCubic),
      ),
    );

    // B. BUS MARKER MOTION (240ms–700ms) -> Interval 0.20 to 0.58
    _busProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.20, 0.58, curve: Curves.easeInOutCubic),
      ),
    );

    // C. GPS PULSE (600ms–900ms) -> Interval 0.50 to 0.75
    _gpsPulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.50, 0.75, curve: Curves.easeOut),
      ),
    );

    // D. CONTENT EXIT FADE during Home crossfade (900ms–1200ms) -> Interval 0.75 to 1.0
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
      ),
    );

    // Trigger navigation at 900ms (as soon as GPS pulse completes)
    _controller.addListener(() {
      if (_controller.value >= 0.75 && !_navigated) {
        _navigateToHome();
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToHome();
      }
    });

    _startAnimation();
  }

  void _startAnimation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (AppMotion.isReducedMotion(context)) {
        _navigateToHome();
      } else {
        _controller.forward();
      }
    });
  }

  void _navigateToHome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const BottomNavShell(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1B36),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo: Centered, static and fully visible from frame 1 for seamless native handoff.
                // Fades out smoothly only during Home crossfade transition.
                Opacity(
                  opacity: _exitFade.value.clamp(0.0, 1.0),
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Route Draw, Bus Motion & GPS Pulse Canvas
                Opacity(
                  opacity: _exitFade.value.clamp(0.0, 1.0),
                  child: SizedBox(
                    width: 220,
                    height: 48,
                    child: CustomPainterWidget(
                      routeProgress: _routeProgress.value,
                      busProgress: _busProgress.value,
                      gpsPulseScale: _gpsPulse.value,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class CustomPainterWidget extends StatelessWidget {
  final double routeProgress;
  final double busProgress;
  final double gpsPulseScale;

  const CustomPainterWidget({
    super.key,
    required this.routeProgress,
    required this.busProgress,
    required this.gpsPulseScale,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SplashRoutePainter(
        routeProgress: routeProgress,
        busProgress: busProgress,
        gpsPulseScale: gpsPulseScale,
      ),
    );
  }
}

class SplashRoutePainter extends CustomPainter {
  final double routeProgress;
  final double busProgress;
  final double gpsPulseScale;

  SplashRoutePainter({
    required this.routeProgress,
    required this.busProgress,
    required this.gpsPulseScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final startPoint = Offset(20, size.height / 2);
    final endPoint = Offset(size.width - 20, size.height / 2);
    final controlPoint1 = Offset(size.width * 0.35, size.height * 0.15);
    final controlPoint2 = Offset(size.width * 0.65, size.height * 0.85);

    path.moveTo(startPoint.dx, startPoint.dy);
    path.cubicTo(
      controlPoint1.dx,
      controlPoint1.dy,
      controlPoint2.dx,
      controlPoint2.dy,
      endPoint.dx,
      endPoint.dy,
    );

    // Draw background track line
    final trackPaint = Paint()
      ..color = const Color(0xFF1E2F4D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, trackPaint);

    // Draw route line with smooth red-to-blue brand gradient accent
    if (routeProgress > 0) {
      final pMetrics = path.computeMetrics();
      for (final metric in pMetrics) {
        final extractPath = metric.extractPath(0, metric.length * routeProgress);

        final routePaint = Paint()
          ..shader = const LinearGradient(
              colors: [Color(0xFFD71920), Color(0xFF2970FF)],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round;

        canvas.drawPath(extractPath, routePaint);
      }
    }

    // Bus Marker along path
    if (busProgress > 0) {
      final pMetrics = path.computeMetrics();
      for (final metric in pMetrics) {
        final tangent = metric.getTangentForOffset(metric.length * busProgress);
        if (tangent != null) {
          final busPaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;

          final busGlowPaint = Paint()
            ..color = const Color(0xFF2970FF).withValues(alpha: 0.7)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

          canvas.drawCircle(tangent.position, 6.5, busGlowPaint);
          canvas.drawCircle(tangent.position, 4, busPaint);
        }
      }
    }

    // Destination GPS Pulse
    if (routeProgress >= 0.9) {
      final pulseRadius = 8.0 * gpsPulseScale;
      final pulsePaint = Paint()
        ..color = const Color(0xFFD71920).withValues(alpha: (2.0 - gpsPulseScale).clamp(0.0, 0.8))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(endPoint, pulseRadius, pulsePaint);

      final dotPaint = Paint()
        ..color = const Color(0xFFD71920)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(endPoint, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SplashRoutePainter oldDelegate) {
    return oldDelegate.routeProgress != routeProgress ||
        oldDelegate.busProgress != busProgress ||
        oldDelegate.gpsPulseScale != gpsPulseScale;
  }
}


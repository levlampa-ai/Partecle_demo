import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ParticleApp());
}

class ParticleApp extends StatelessWidget {
  const ParticleApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Particle Demo',
      theme: ThemeData.dark(useMaterial3: true),
      home: const Scaffold(body: SafeArea(child: ParticleHome())),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ParticleHome extends StatefulWidget {
  const ParticleHome({super.key});
  @override
  State<ParticleHome> createState() => _ParticleHomeState();
}

class _ParticleHomeState extends State<ParticleHome> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<Particle> _particles = [];
  final Random _rnd = Random();
  ui.Image? _particleImage;
  Size _screenSize = Size.zero;
  Offset? _pointer;
  double _time = 0.0;
  int _targetParticles = 220;
  ui.FragmentProgram? _bloomProg;
  double _lastFpsMeasure = 0;
  int _frames = 0;
  double _fps = 60;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    try {
      final bytes = await rootBundle.load('assets/particle.png');
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final fi = await codec.getNextFrame();
      _particleImage = fi.image;
    } catch (_) {
      _particleImage = null;
    }

    if (!kIsWeb) {
      try {
        _bloomProg = await ui.FragmentProgram.fromAsset('shaders/bloom.frag');
      } catch (_) {
        _bloomProg = null;
      }
    } else {
      _bloomProg = null;
    }

    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = 1 / 60;
    _time += dt;
    _updateFPS(elapsed);
    _updateParticles(dt);
    setState(() {});
  }

  void _updateFPS(Duration elapsed) {
    _frames++;
    final t = elapsed.inMilliseconds / 1000.0;
    if (t - _lastFpsMeasure > 1.0) {
      _fps = _frames / (t - _lastFpsMeasure).clamp(0.001, double.infinity);
      _frames = 0;
      _lastFpsMeasure = t;
      if (_fps < 35 && _targetParticles > 40) {
        _targetParticles = max(40, (_targetParticles * 0.9).toInt());
      } else if (_fps > 50 && _targetParticles < 600) {
        _targetParticles = min(600, (_targetParticles * 1.05).toInt());
      }
    }
  }

  void _updateParticles(double dt) {
    final spawn = ((_targetParticles - _particles.length) / 10).ceil();
    for (int i = 0; i < max(0, spawn); i++) {
      _particles.add(_createParticle(randomPos: true));
    }

    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.update(dt, pointer: _pointer, bounds: _screenSize);
      if (p.dead) _particles.removeAt(i);
    }
  }

  Particle _createParticle({Offset? position, bool randomPos = false}) {
    final size = (_rnd.nextDouble() * 16.0) + 6.0;
    final dir = _rnd.nextDouble() * pi * 2;
    final sp = Offset(cos(dir), sin(dir)) * (_rnd.nextDouble() * 80 + 20);
    final pos = randomPos
        ? Offset(_rnd.nextDouble() * (_screenSize.width == 0 ? 360 : _screenSize.width),
            _rnd.nextDouble() * (_screenSize.height == 0 ? 800 : _screenSize.height))
        : (position ?? Offset((_screenSize.width / 2), (_screenSize.height / 2)));
    final hue = _rnd.nextDouble() * 360;
    final color = HSVColor.fromAHSV(1.0, hue, 0.75, 1.0).toColor();
    return Particle(
      position: pos,
      velocity: sp,
      size: size,
      life: 3 + _rnd.nextDouble() * 3,
      maxLife: 3 + _rnd.nextDouble() * 3,
      color: color,
      rotation: _rnd.nextDouble() * pi * 2,
      spin: (_rnd.nextDouble() - 0.5) * 2.0,
      image: _particleImage,
      rnd: _rnd,
    );
  }

  void _spawnBurst(Offset p) {
    for (int i = 0; i < 60; i++) {
      final part = _createParticle(position: p);
      part.velocity *= (1.0 + _rnd.nextDouble() * 4.0);
      part.size *= (0.5 + _rnd.nextDouble() * 1.5);
      part.color = HSVColor.fromAHSV(1.0, _rnd.nextDouble() * 80 + 160, 0.9, 1.0).toColor();
      _particles.add(part);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      _screenSize = Size(cons.maxWidth, cons.maxHeight);
      return GestureDetector(
        onPanDown: (e) {
          _pointer = e.localPosition;
          _spawnBurst(_pointer!);
        },
        onPanUpdate: (e) {
          _pointer = e.localPosition;
          for (int i = 0; i < 3; i++) {
            final p = _createParticle(position: _pointer);
            p.velocity *= 0.2 + _rnd.nextDouble() * 0.8;
            p.size *= 0.6 + _rnd.nextDouble() * 1.2;
            _particles.add(p);
          }
        },
        onPanEnd: (_) => _pointer = null,
        onTapUp: (e) {
          _spawnBurst(e.localPosition);
        },
        child: CustomPaint(
          size: Size.infinite,
          painter: ScenePainter(
            particles: _particles,
            time: _time,
            bloomProgram: _bloomProg,
            bloomStrength: (_pointer != null ? 0.9 : 0.45),
            fps: _fps,
          ),
        ),
      );
    });
  }
}

class Particle {
  Offset position;
  Offset velocity;
  double size;
  double life;
  final double maxLife;
  Color color;
  double rotation;
  final double spin;
  final ui.Image? image;
  final Random rnd;
  bool dead = false;

  Particle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.life,
    required this.maxLife,
    required this.color,
    required this.rotation,
    required this.spin,
    required this.image,
    required this.rnd,
  });

  void update(double dt, {Offset? pointer, required Size bounds}) {
    life -= dt;
    if (life <= 0) {
      dead = true;
      return;
    }

    if (pointer != null) {
      final diff = pointer - position;
      final dist = diff.distance;
      if (dist > 1) {
        final force = diff / dist * (1200 / (dist + 200));
        velocity += force * dt;
      }
    } else {
      velocity += Offset(sin(rotation) * 6.0, cos(rotation) * 4.0) * dt;
    }

    velocity *= 0.995;
    position += velocity * dt;

    if (position.dx < -100) position = Offset(bounds.width + 100, position.dy);
    if (position.dx > bounds.width + 100) position = Offset(-100, position.dy);
    if (position.dy < -100) position = Offset(position.dx, bounds.height + 100);
    if (position.dy > bounds.height + 100) position = Offset(position.dx, -100);

    rotation += spin * dt;

    final t = (life / maxLife).clamp(0.0, 1.0);
    size = size * (0.985 + t * 0.01);
    final alpha = pow(t, 1.1).toDouble();
    color = color.withOpacity(alpha);
  }
}

class ScenePainter extends CustomPainter {
  final List<Particle> particles;
  final double time;
  final ui.FragmentProgram? bloomProgram;
  final double bloomStrength;
  final double fps;

  ScenePainter({
    required this.particles,
    required this.time,
    required this.bloomProgram,
    required this.bloomStrength,
    required this.fps,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFF020617), const Color(0xFF07122A)],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, Colors.black.withOpacity(0.25)],
        stops: [0.6, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);

    final paint = Paint()..blendMode = BlendMode.plus;

    for (final p in particles) {
      final pos = p.position;
      final s = p.size;
      final matrix = Matrix4.identity()
        ..translate(pos.dx, pos.dy)
        ..rotateZ(p.rotation)
        ..scale(s / (p.image?.width ?? 32), s / (p.image?.height ?? 32));
      canvas.save();
      canvas.transform(matrix.storage);
      if (p.image != null) {
        paint.color = p.color;
        final src = Rect.fromLTWH(0, 0, p.image!.width.toDouble(), p.image!.height.toDouble());
        final dst = Rect.fromLTWH(-p.image!.width / 2.0, -p.image!.height / 2.0, p.image!.width.toDouble(), p.image!.height.toDouble());
        canvas.drawImageRect(p.image!, src, dst, paint);
      } else {
        paint.color = p.color;
        canvas.drawCircle(Offset.zero, 1.0, paint);
      }
      canvas.restore();

      final halo = Paint()
        ..shader = RadialGradient(colors: [p.color.withOpacity(0.8), p.color.withOpacity(0.0)]).createShader(Rect.fromCircle(center: pos, radius: s * 3))
        ..blendMode = BlendMode.screen;
      canvas.drawCircle(pos, s * 2.2, halo);
    }

    final textStyle = TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12);
    final textSpan = TextSpan(text: 'Particles: ${particles.length}  FPS: ${fps.toStringAsFixed(1)}', style: textStyle);
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, const Offset(12, 12));

    if (bloomProgram != null) {
      // shader postprocess requires render-to-image; omitted for simplicity
    } else {
      final glowPaint = Paint()
        ..shader = RadialGradient(colors: [Colors.blue.withOpacity(0.06), Colors.transparent]).createShader(rect)
        ..blendMode = BlendMode.screen;
      canvas.drawRect(rect, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ScenePainter oldDelegate) => true;
}

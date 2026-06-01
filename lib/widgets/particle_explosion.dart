import 'dart:math';
import 'package:flutter/material.dart';

class ParticleExplosion extends StatefulWidget {
  const ParticleExplosion({super.key});

  @override
  State<ParticleExplosion> createState() => _ParticleExplosionState();
}

class _ParticleExplosionState extends State<ParticleExplosion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;
  late final double _maxLifetime;
  bool _active = true;

  @override
  void initState() {
    super.initState();

    final rng = Random();
    _particles = List.generate(60, (_) {
      final angle = rng.nextDouble() * 2 * pi;
      final speed = 150 + rng.nextDouble() * 250; // 150–400
      final lifetime = 0.6 + rng.nextDouble() * 0.6;
      final radius = 3 + rng.nextDouble() * 3;
      final colors = [
        const Color(0xFF00FFFF),
        const Color(0xFFFF00FF),
        const Color(0xFFFFD700),
        const Color(0xFF00FF88),
      ];
      return _Particle(
        velocity: Offset(cos(angle) * speed, sin(angle) * speed),
        radius: radius,
        lifetime: lifetime,
        color: colors[rng.nextInt(colors.length)],
      );
    });

    _maxLifetime = _particles.map((p) => p.lifetime).reduce(max);

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_maxLifetime * 1000).round()),
    )..addListener(() {
        if (mounted) setState(() {});
        final t = _controller.lastElapsedDuration?.inMilliseconds ?? 0;
        if (t >= (_maxLifetime * 1000)) {
          _active = false;
        }
      });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return const SizedBox.shrink();
    return CustomPaint(
      painter: _ParticlePainter(
        particles: _particles,
        time: (_controller.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _Particle {
  final Offset velocity;
  final double radius;
  final double lifetime;
  final Color color;

  _Particle({
    required this.velocity,
    required this.radius,
    required this.lifetime,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double time;

  _ParticlePainter({
    required this.particles,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const gravity = 80.0;

    for (final p in particles) {
      if (time > p.lifetime) continue;
      final t = time;
      final dx = p.velocity.dx * t;
      final dy = p.velocity.dy * t + 0.5 * gravity * t * t;
      final pos = center + Offset(dx, dy);
      final lifeProgress = (t / p.lifetime).clamp(0.0, 1.0);
      final opacity = (1.0 - lifeProgress);

      final paint = Paint()..color = p.color.withOpacity(opacity);
      canvas.drawCircle(pos, p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.time != time;
  }
}

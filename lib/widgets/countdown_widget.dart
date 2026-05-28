import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';

class CountdownWidget extends StatefulWidget {
  final VoidCallback onComplete;

  const CountdownWidget({super.key, required this.onComplete});

  @override
  State<CountdownWidget> createState() => _CountdownWidgetState();
}

class _CountdownWidgetState extends State<CountdownWidget>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  int _currentNumber = 3;
  bool _showGo = false;
  bool _finished = false;
  final AudioService _audio = AudioService.getInstance();

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeOut));

    _startCountdown();
  }

  Future<void> _startCountdown() async {
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() {
        _currentNumber = i;
        _showGo = false;
      });
      _scaleController.reset();
      _scaleController.forward();
      HapticFeedback.mediumImpact();
      _audio.playCountdownBeep(i);
      await Future.delayed(const Duration(milliseconds: 800));
    }

    if (!mounted) return;
    setState(() {
      _showGo = true;
    });
    _scaleController.reset();
    _scaleController.forward();
    HapticFeedback.heavyImpact();
    _audio.playGo();

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _finished = true;
    });
    widget.onComplete();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return const SizedBox.shrink();

    return Center(
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: _showGo
            ? Text(
                'GO',
                style: AppTheme.countdownDisplay.copyWith(
                  color: AppTheme.cyan,
                  shadows: [
                    Shadow(
                      color: AppTheme.cyan.withValues(alpha: 0.8),
                      blurRadius: 40,
                    ),
                  ],
                ),
              )
            : Text(
                '$_currentNumber',
                style: AppTheme.countdownDisplay.copyWith(
                  color: _getNumberColor(_currentNumber),
                  shadows: [
                    Shadow(
                      color: _getNumberColor(_currentNumber).withValues(alpha: 0.8),
                      blurRadius: 40,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Color _getNumberColor(int number) {
    switch (number) {
      case 3:
        return AppTheme.purple;
      case 2:
        return AppTheme.purple;
      case 1:
        return AppTheme.cyan;
      default:
        return AppTheme.white;
    }
  }
}

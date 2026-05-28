import 'package:flutter/material.dart';
import '../models/rank.dart';
import '../theme/app_theme.dart';

class RankBadge extends StatefulWidget {
  final Rank rank;
  final double size;
  final bool animate;

  const RankBadge({
    super.key,
    required this.rank,
    this.size = 48,
    this.animate = true,
  });

  @override
  State<RankBadge> createState() => _RankBadgeState();
}

class _RankBadgeState extends State<RankBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    if (widget.animate) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.cardBg,
            border: Border.all(
              color: widget.rank.color.withValues(alpha: 0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.rank.color.withValues(alpha: _glowAnimation.value),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.rank.emoji,
              style: TextStyle(fontSize: widget.size * 0.45),
            ),
          ),
        );
      },
    );
  }
}

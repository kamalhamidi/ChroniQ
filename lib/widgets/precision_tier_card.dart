import 'package:flutter/material.dart';
import '../models/game_result.dart';
import '../theme/app_theme.dart';

class PrecisionTierCard extends StatefulWidget {
  final PrecisionTier tier;
  final bool animate;
  final Animation<double>? glitchOffset;

  const PrecisionTierCard({
    super.key,
    required this.tier,
    this.animate = true,
    this.glitchOffset,
  });

  @override
  State<PrecisionTierCard> createState() => _PrecisionTierCardState();
}

class _PrecisionTierCardState extends State<PrecisionTierCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    if (widget.animate) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.tier.color.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.tier.color.withValues(alpha: 0.5),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.tier.emoji,
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 12),
              _buildTierLabel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierLabel() {
    final baseStyle = AppTheme.headingMedium.copyWith(
      color: widget.tier.color,
      letterSpacing: 3,
    );

    if (widget.glitchOffset == null) {
      return Text(widget.tier.displayName, style: baseStyle);
    }

    return AnimatedBuilder(
      animation: widget.glitchOffset!,
      builder: (context, _) {
        final offset = widget.glitchOffset!.value;
        return Stack(
          children: [
            Text(widget.tier.displayName, style: baseStyle),
            Transform.translate(
              offset: Offset(offset, 0),
              child: Text(
                widget.tier.displayName,
                style: baseStyle.copyWith(
                  color: const Color(0xFFFF3B3B).withOpacity(0.4),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(-offset, 0),
              child: Text(
                widget.tier.displayName,
                style: baseStyle.copyWith(
                  color: const Color(0xFF3B6BFF).withOpacity(0.4),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

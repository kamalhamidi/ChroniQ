import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FakePlayerCard extends StatefulWidget {
  final String username;
  final String flagEmoji;
  final bool isUser;
  final bool showReady;
  final int readyDelay; // ms before "Ready" appears
  final String? reaction;
  final bool isOnline;

  const FakePlayerCard({
    super.key,
    required this.username,
    required this.flagEmoji,
    this.isUser = false,
    this.showReady = false,
    this.readyDelay = 0,
    this.reaction,
    this.isOnline = true,
  });

  @override
  State<FakePlayerCard> createState() => _FakePlayerCardState();
}

class _FakePlayerCardState extends State<FakePlayerCard>
    with SingleTickerProviderStateMixin {
  bool _isReady = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.showReady) {
      Future.delayed(Duration(milliseconds: widget.readyDelay), () {
        if (mounted) setState(() => _isReady = true);
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isUser
              ? AppTheme.purple.withValues(alpha: 0.4)
              : AppTheme.dimWhite.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: widget.isUser
            ? [
                BoxShadow(
                  color: AppTheme.purple.withValues(alpha: 0.2),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Flag
          Text(widget.flagEmoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),

          // Username + ready status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.username,
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: widget.isUser ? AppTheme.purple : AppTheme.white,
                      ),
                    ),
                    if (widget.isUser) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(YOU)',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.purple,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                if (widget.reaction != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.reaction!,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.dimWhite,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Ready status or online indicator
          if (widget.showReady)
            AnimatedOpacity(
              opacity: _isReady ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Text(
                '✓ Ready',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            // Green online dot
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, _) {
                return Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isOnline
                        ? AppTheme.green.withValues(alpha: _pulseAnimation.value)
                        : AppTheme.red.withValues(alpha: 0.5),
                    boxShadow: widget.isOnline
                        ? [
                            BoxShadow(
                              color: AppTheme.green.withValues(alpha: _pulseAnimation.value * 0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

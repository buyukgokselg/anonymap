import 'package:flutter/material.dart';
import '../theme/colors.dart';

class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(
      begin: -1,
      end: 2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment((_animation.value - 1).clamp(-1.0, 1.0), 0),
              end: Alignment(_animation.value.clamp(-1.0, 1.0), 0),
              colors: [
                AppColors.bgCard,
                AppColors.bgCard.withValues(alpha: 0.5),
                AppColors.bgCard,
              ],
            ),
          ),
        );
      },
    );
  }
}

class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerLoading(width: 40, height: 40, borderRadius: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerLoading(width: 120, height: 14),
                    SizedBox(height: 6),
                    ShimmerLoading(width: 80, height: 10),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          ShimmerLoading(height: 12),
          SizedBox(height: 8),
          ShimmerLoading(width: 200, height: 12),
        ],
      ),
    );
  }
}

class ShimmerSuggestionCard extends StatelessWidget {
  const ShimmerSuggestionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ShimmerLoading(width: 28, height: 28, borderRadius: 8),
              SizedBox(width: 10),
              Expanded(child: ShimmerLoading(height: 14)),
            ],
          ),
          Row(
            children: [
              Expanded(child: ShimmerLoading(height: 10)),
              SizedBox(width: 20),
              ShimmerLoading(width: 40, height: 22, borderRadius: 8),
            ],
          ),
        ],
      ),
    );
  }
}

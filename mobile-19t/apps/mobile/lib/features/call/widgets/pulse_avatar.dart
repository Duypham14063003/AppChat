import 'package:flutter/material.dart';

class PulseAvatar extends StatefulWidget {
  final String? avatarUrl;
  final double radius;
  final Color pulseColor;

  const PulseAvatar({
    super.key,
    this.avatarUrl,
    this.radius = 60,
    this.pulseColor = Colors.white,
  });

  @override
  State<PulseAvatar> createState() => _PulseAvatarState();
}

class _PulseAvatarState extends State<PulseAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.pulseColor.withOpacity(0.3),
                blurRadius: widget.radius * _animation.value,
                spreadRadius: widget.radius * (_animation.value - 1.0),
              ),
            ],
          ),
          child: child,
        );
      },
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: Colors.grey.shade800,
        backgroundImage: widget.avatarUrl != null 
          ? NetworkImage(widget.avatarUrl!) 
          : null,
        child: widget.avatarUrl == null 
          ? Icon(Icons.person, size: widget.radius, color: Colors.white) 
          : null,
      ),
    );
  }
}

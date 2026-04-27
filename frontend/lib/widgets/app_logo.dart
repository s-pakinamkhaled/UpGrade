import 'package:flutter/material.dart';
import '../core/theme.dart';

/// App Logo Widget with Staircase Icon
/// Matches the design: rounded square with gradient background and white staircase icon
class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool showShadow;
  
  const AppLogo({
    super.key,
    this.size = 60,
    this.showText = false,
    this.showShadow = true,
  });
  
  const AppLogo.small({super.key}) 
      : size = 40, showText = false, showShadow = false;
  const AppLogo.large({super.key}) 
      : size = 80, showText = true, showShadow = true;
  
  @override
  Widget build(BuildContext context) {
    final logoWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(size * 0.2), // Rounded square
        boxShadow: showShadow ? [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Circular outline (semi-transparent)
          Container(
            width: size * 0.75,
            height: size * 0.75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
          ),
          // Staircase icon
          CustomPaint(
            size: Size(size * 0.5, size * 0.5),
            painter: StaircasePainter(),
          ),
        ],
      ),
    );
    
    if (showText) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          logoWidget,
          const SizedBox(height: 12),
          const Text(
            'UpGrade',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
              letterSpacing: -0.5,
            ),
          ),
        ],
      );
    }
    
    return logoWidget;
  }
}

/// Custom painter for the staircase icon
class StaircasePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final width = size.width;
    final height = size.height;
    
    // Draw 4-step staircase ascending from bottom-left to top-right
    final stepHeight = height / 4;
    final stepWidth = width / 4;
    
    // Step 1 (bottom)
    canvas.drawLine(
      Offset(0, height - stepHeight),
      Offset(stepWidth, height - stepHeight),
      paint,
    );
    canvas.drawLine(
      Offset(stepWidth, height - stepHeight),
      Offset(stepWidth, height - stepHeight * 2),
      paint,
    );
    
    // Step 2
    canvas.drawLine(
      Offset(stepWidth, height - stepHeight * 2),
      Offset(stepWidth * 2, height - stepHeight * 2),
      paint,
    );
    canvas.drawLine(
      Offset(stepWidth * 2, height - stepHeight * 2),
      Offset(stepWidth * 2, height - stepHeight * 3),
      paint,
    );
    
    // Step 3
    canvas.drawLine(
      Offset(stepWidth * 2, height - stepHeight * 3),
      Offset(stepWidth * 3, height - stepHeight * 3),
      paint,
    );
    canvas.drawLine(
      Offset(stepWidth * 3, height - stepHeight * 3),
      Offset(stepWidth * 3, height - stepHeight * 4),
      paint,
    );
    
    // Step 4 (top) - with rounded end
    canvas.drawLine(
      Offset(stepWidth * 3, height - stepHeight * 4),
      Offset(width, height - stepHeight * 4),
      paint,
    );
    
    // Draw rounded end on top step
    final roundedEndPaint = Paint()
      ..color = AppTheme.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(width, height - stepHeight * 4),
      2.5,
      roundedEndPaint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Shared StudyAI-style visuals: page mesh gradient, proportional [UpGradeRem],
/// gradient-framed cards, and primary gradient buttons.
///
/// [UpGradePageDecor.pageBackground] is used behind secondary routes and is also
/// painted behind the main content pane in [DashboardShellRow].

/// Single [rem] from layout width drives proportional typography.
class UpGradeRem {
  UpGradeRem(double layoutWidth) : rem = (layoutWidth / 92).clamp(13.0, 17.5);

  final double rem;

  double space(double mult) => rem * mult;

  double get pageTitle => rem * 1.95;
  double get pageSubtitle => rem * 0.92;
  double get cardTitle => rem * 1.05;
  double get cardBody => rem * 0.82;
  double get inputText => rem * 0.88;
  double get sectionTitle => rem * 1.12;
  double get listTitle => rem * 0.95;
  double get listSubtitle => rem * 0.78;
  double get buttonLabel => rem * 0.88;
  double get iconSmall => rem * 1.05;
}

/// Shared page background (light: blue–lavender wash; dark: slate–violet depth).
class UpGradePageDecor {
  UpGradePageDecor._();

  static BoxDecoration pageBackground(bool isDark) {
    if (isDark) {
      return const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B1220),
            Color(0xFF111827),
            Color(0xFF1A1033),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      );
    }
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE8EEFF),
          Color(0xFFF5F0FF),
          Color(0xFFF8FAFC),
        ],
        stops: [0.0, 0.42, 1.0],
      ),
    );
  }
}

/// Large page title with blue–purple gradient in light mode.
class UpGradeGradientTitle extends StatelessWidget {
  const UpGradeGradientTitle(
    this.text, {
    super.key,
    required this.rem,
    this.isDark,
  });

  final String text;
  final UpGradeRem rem;
  final bool? isDark;

  @override
  Widget build(BuildContext context) {
    final dark = isDark ?? Theme.of(context).brightness == Brightness.dark;
    final style = TextStyle(
      fontSize: rem.pageTitle,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      height: 1.1,
      color: dark ? Colors.white : const Color(0xFF0F172A),
    );
    if (dark) {
      return Text(text, style: style);
    }
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}

class UpGradeMutedSubtitle extends StatelessWidget {
  const UpGradeMutedSubtitle(
    this.text, {
    super.key,
    required this.rem,
    this.isDark,
  });

  final String text;
  final UpGradeRem rem;
  final bool? isDark;

  @override
  Widget build(BuildContext context) {
    final dark = isDark ?? Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: rem.pageSubtitle,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
      ),
    );
  }
}

/// Gradient outer frame + soft inner fill.
class UpGradeGradientFrameCard extends StatelessWidget {
  const UpGradeGradientFrameCard({
    super.key,
    required this.rem,
    required this.isDark,
    required this.child,
  });

  final UpGradeRem rem;
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final innerRadius = BorderRadius.circular(20.0);
    if (isDark) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryBlue.withOpacity(0.55),
              AppTheme.secondaryPurple.withOpacity(0.45),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.secondaryPurple.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(2),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: innerRadius,
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
          padding: EdgeInsets.all(rem.space(1.2)),
          child: child,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: AppTheme.primaryGradient,
        boxShadow: AppTheme.mediumShadow,
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFDF4FF),
            ],
          ),
          borderRadius: innerRadius,
          border: Border.all(color: const Color(0xFFE8E0EF)),
        ),
        padding: EdgeInsets.all(rem.space(1.2)),
        child: child,
      ),
    );
  }
}

/// White / dark card with vertical gradient accent stripe on the leading edge.
class UpGradeAccentStripeCard extends StatelessWidget {
  const UpGradeAccentStripeCard({
    super.key,
    required this.rem,
    required this.isDark,
    required this.stripeGradient,
    required this.child,
  });

  final UpGradeRem rem;
  final bool isDark;
  final List<Color> stripeGradient;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isDark ? const Color(0xFF111827) : Colors.white,
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(isDark ? 0.12 : 0.08),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppTheme.secondaryPurple.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: rem.space(0.35).clamp(4.0, 6.0) + 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: stripeGradient,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(rem.space(1.15)),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft tinted panel for list sections (manual courses, tasks, etc.).
class UpGradeListSectionPanel extends StatelessWidget {
  const UpGradeListSectionPanel({
    super.key,
    required this.rem,
    required this.isDark,
    required this.tintTop,
    required this.borderAccent,
    required this.child,
  });

  final UpGradeRem rem;
  final bool isDark;
  final Color tintTop;
  final Color borderAccent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF111827),
                  const Color(0xFF1E1B4B).withOpacity(0.4),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tintTop,
                  Colors.white,
                ],
              ),
        border: Border.all(
          color:
              isDark ? const Color(0xFF334155) : borderAccent.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(rem.space(1.05)),
      child: child,
    );
  }
}

/// Primary CTA with app gradient (disabled: grey gradient).
class UpGradeGradientFilledButton extends StatelessWidget {
  const UpGradeGradientFilledButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.padding,
  });

  final VoidCallback? onPressed;
  final Icon icon;
  final Widget label;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: enabled
            ? AppTheme.primaryGradient
            : LinearGradient(
                colors: [
                  Colors.grey.shade400,
                  Colors.grey.shade500,
                ],
              ),
        boxShadow: enabled ? AppTheme.softShadow : const [],
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: label,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          elevation: 0,
          padding: padding,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.white.withOpacity(0.75),
        ),
      ),
    );
  }
}

/// Form fields styled like My courses (tint, blue outline, purple focus).
class UpGradeInputDecor {
  UpGradeInputDecor._();

  static InputDecoration themed(
    BuildContext context,
    UpGradeRem rem,
    String hint, {
    Widget? prefix,
    Color? fillTint,
  }) {
    final theme = Theme.of(context);
    final onSurfaceMuted = theme.colorScheme.onSurface.withOpacity(0.55);
    final baseFill = fillTint ?? AppTheme.primaryBlue.withOpacity(0.07);
    return InputDecoration(
      hintText: hint,
      hintStyle:
          TextStyle(fontSize: rem.inputText * 0.95, color: onSurfaceMuted),
      prefixIcon: prefix,
      filled: true,
      fillColor: baseFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppTheme.primaryBlue.withOpacity(0.12),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppTheme.primaryBlue.withOpacity(0.14),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppTheme.secondaryPurple,
          width: 2,
        ),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: rem.space(1.0),
        vertical: rem.space(0.85),
      ),
    );
  }
}

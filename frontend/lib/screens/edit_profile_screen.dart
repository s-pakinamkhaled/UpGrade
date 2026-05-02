import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

<<<<<<< HEAD
import '../widgets/upgrade_page_shell.dart';
=======
import '../core/constants.dart';
import '../core/theme.dart';
import '../core/profile_display_name.dart';
import '../services/api_service.dart';
import '../widgets/dashboard_secondary_shell.dart';
>>>>>>> origin/continue

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
<<<<<<< HEAD
  bool _isSaving = false;
  String? _error;

=======
  final _majorController = TextEditingController();
  final _yearController = TextEditingController();
  final _gpaController = TextEditingController();
  bool _isSaving = false;
  bool _isLoadingProfile = true;
  String? _error;

  String get _userId {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? user?.email ?? 'guest_user';
  }

>>>>>>> origin/continue
  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
<<<<<<< HEAD
    _nameController.text = user?.displayName ?? '';
    _emailController.text = user?.email ?? '';
=======
    final uEmail = user?.email?.trim() ?? '';
    final dn = user?.displayName?.trim() ?? '';
    _nameController.text = (dn.isNotEmpty && !isPlaceholderProfileName(dn))
        ? dn
        : displayNameFromEmail(uEmail);
    _emailController.text = uEmail.isNotEmpty ? uEmail : '';
    _majorController.text = 'Computer Science';
    _yearController.text = 'Junior';
    _gpaController.text = '3.85';
    _loadProfileFromBackend();
>>>>>>> origin/continue
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
<<<<<<< HEAD
=======
    _majorController.dispose();
    _yearController.dispose();
    _gpaController.dispose();
>>>>>>> origin/continue
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await user.updateDisplayName(_nameController.text.trim());
      final newEmail = _emailController.text.trim();
      if (newEmail.isNotEmpty && newEmail != user.email) {
        await user.updateEmail(newEmail);
      }

<<<<<<< HEAD
=======
      await ApiService().updateUserProfile(
        userId: _userId,
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        major: _majorController.text.trim(),
        academicYear: _yearController.text.trim(),
        gpa: _gpaController.text.trim(),
      );

>>>>>>> origin/continue
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

<<<<<<< HEAD
  @override
  Widget build(BuildContext context) {
    return UpGradePageShell(
      title: 'Edit Profile',
      subtitle: 'Update your name and email',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Enter your name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Enter your email';
                }
                if (!value.contains('@')) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save changes'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
=======
  Future<void> _loadProfileFromBackend() async {
    final profile = await ApiService().getUserProfile(_userId);
    if (!mounted) return;

    if (profile != null) {
      final rawName = (profile['fullName'] as String?)?.trim() ?? '';
      if (rawName.isNotEmpty && !isPlaceholderProfileName(rawName)) {
        _nameController.text = rawName;
      } else {
        final em = (profile['email'] as String?)?.trim().isNotEmpty == true
            ? profile['email'] as String
            : _emailController.text;
        _nameController.text = displayNameFromEmail(
            em.isNotEmpty ? em : FirebaseAuth.instance.currentUser?.email);
      }
      final rawEmail = (profile['email'] as String?)?.trim() ?? '';
      if (rawEmail.isNotEmpty && !isPlaceholderProfileEmail(rawEmail)) {
        _emailController.text = rawEmail;
      } else {
        final fe = FirebaseAuth.instance.currentUser?.email?.trim() ?? '';
        if (fe.isNotEmpty) {
          _emailController.text = fe;
        }
      }
      _majorController.text = (profile['major'] as String?)?.trim().isNotEmpty == true
          ? profile['major'] as String
          : _majorController.text;
      _yearController.text =
          (profile['academicYear'] as String?)?.trim().isNotEmpty == true
              ? profile['academicYear'] as String
              : _yearController.text;
      _gpaController.text = (profile['gpa'] as String?)?.trim().isNotEmpty == true
          ? profile['gpa'] as String
          : _gpaController.text;
    }

    setState(() {
      _isLoadingProfile = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final page = _buildPage(context);
    return DashboardSecondaryShell(
      highlightRoute: AppConstants.routeProfile,
      narrow: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(title: const Text('Edit Profile')),
        body: page,
      ),
      wideBody: page,
    );
  }

  Widget _buildPage(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 760;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Profile',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Update your personal information',
                  style: TextStyle(
                    fontSize: 24,
                    color: isDark ? const Color(0xFF9CA3AF) : AppTheme.darkText.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF111827) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isLoadingProfile) ...[
                        const LinearProgressIndicator(minHeight: 2),
                        const SizedBox(height: 10),
                      ],
                      if (_error != null) ...[
                        Text(_error!, style: const TextStyle(color: AppTheme.errorRed)),
                        const SizedBox(height: 10),
                      ],
                      _fieldLabel('Full Name', isDark),
                      _styledField(
                        controller: _nameController,
                        icon: Icons.person_outline,
                        hint: 'John Doe',
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Enter your full name'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _fieldLabel('Email Address', isDark),
                      _styledField(
                        controller: _emailController,
                        icon: Icons.mail_outline,
                        hint: 'john.doe@university.edu',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Enter your email';
                          if (!value.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      if (wide)
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel('Major', isDark),
                                  _styledField(
                                    controller: _majorController,
                                    icon: Icons.school_outlined,
                                    hint: 'Computer Science',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel('Academic Year', isDark),
                                  _styledField(
                                    controller: _yearController,
                                    hint: 'Junior',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _fieldLabel('Major', isDark),
                        _styledField(
                          controller: _majorController,
                          icon: Icons.school_outlined,
                          hint: 'Computer Science',
                        ),
                        const SizedBox(height: 14),
                        _fieldLabel('Academic Year', isDark),
                        _styledField(
                          controller: _yearController,
                          hint: 'Junior',
                        ),
                      ],
                      const SizedBox(height: 14),
                      _fieldLabel('GPA', isDark),
                      _styledField(
                        controller: _gpaController,
                        hint: '3.85',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _isSaving ? null : _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  elevation: 0,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(46),
                                ),
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined, size: 18),
                                label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _fieldLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
>>>>>>> origin/continue
        ),
      ),
    );
  }
<<<<<<< HEAD
=======

  Widget _styledField({
    required TextEditingController controller,
    String? hint,
    IconData? icon,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF9CA3AF)) : null,
        filled: true,
        fillColor: isDark ? const Color(0xFF0B1220) : const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.2),
        ),
      ),
      style: TextStyle(color: isDark ? Colors.white : AppTheme.darkText),
    );
  }
>>>>>>> origin/continue
}


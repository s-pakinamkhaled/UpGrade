/// Derives a friendly display name from an email's local part, e.g.
/// `pakinam@example.com` → "Pakinam", `pakinam.ali@x.com` → "Pakinam Ali".
String displayNameFromEmail(String? email) {
  if (email == null || email.trim().isEmpty) {
    return 'User';
  }
  final local = email.trim().split('@').first;
  if (local.isEmpty) {
    return 'User';
  }
  final parts = local
      .replaceAll('.', ' ')
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty);
  if (parts.isEmpty) {
    return 'User';
  }
  return parts.map((s) {
    if (s.isEmpty) {
      return '';
    }
    final lower = s.toLowerCase();
    return lower[0].toUpperCase() + (lower.length > 1 ? lower.substring(1) : '');
  }).join(' ');
}

/// Backend / legacy placeholder; treat as "no name set" and derive from email instead.
bool isPlaceholderProfileName(String? name) {
  final t = name?.trim().toLowerCase() ?? '';
  return t.isEmpty || t == 'john doe';
}

/// Default profile email from API before the user saves a real one.
bool isPlaceholderProfileEmail(String? email) {
  final t = email?.trim().toLowerCase() ?? '';
  return t.isEmpty || t == 'john.doe@university.edu';
}

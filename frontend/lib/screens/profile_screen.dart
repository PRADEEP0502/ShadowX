import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../theme/app_colors.dart';
import '../widgets/premium_gradient_button.dart';
import '../widgets/premium_text_field.dart';

class ProfileScreen extends StatefulWidget {
  final String currentUsername;
  final Function(String newUsername) onUsernameChanged;

  const ProfileScreen({
    super.key,
    required this.currentUsername,
    required this.onUsernameChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  String _username = '';
  String _email = '';
  String? _avatar;
  String _status = 'Online';

  bool _pushEnabled = true;
  bool _soundEnabled = true;
  bool _vibrateEnabled = true;
  bool _previewEnabled = true;



  // Gradients for initials-based avatars
  final List<LinearGradient> _avatarGradients = [
    const LinearGradient(colors: [Color(0xFF7B2FF7), Color(0xFF3A8DFF)]),
    const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)]),
    const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEF4444)]),
    const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF3B82F6)]),
    const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)]),
  ];

  final List<String> _presetPhotos = [
    'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=200&q=80',
    'https://images.unsplash.com/photo-1618005198143-e5283b519a7f?auto=format&fit=crop&w=200&q=80',
    'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?auto=format&fit=crop&w=200&q=80',
    'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=200&q=80',
    'https://images.unsplash.com/photo-1462331940025-496dfbfc7564?auto=format&fit=crop&w=200&q=80',
  ];

  @override
  void initState() {
    super.initState();
    _username = widget.currentUsername;
    _fetchProfile();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentUsername != oldWidget.currentUsername) {
      setState(() {
        _username = widget.currentUsername;
        _isLoading = true;
      });
      _fetchProfile();
    }
  }

  Future<void> _fetchProfile() async {
    if (_username.isEmpty) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }
    try {
      final profile = await ApiService.fetchUserProfile(_username);
      if (!mounted) return;
      setState(() {
        _email = profile['email']?.toString() ?? '';
        _avatar = profile['avatar']?.toString();
        _status = profile['status']?.toString() ?? 'Online';
        _pushEnabled = profile['notification_push'] as bool? ?? true;
        _soundEnabled = profile['notification_sound'] as bool? ?? true;
        _vibrateEnabled = profile['notification_vibrate'] as bool? ?? true;
        _previewEnabled = profile['notification_preview'] as bool? ?? true;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Failed to load profile details: $e');
    }
  }

  Future<void> _saveProfile({String? newName, String? newEmail}) async {
    final updatedName = newName ?? _username;
    final updatedEmail = newEmail ?? _email;

    setState(() => _isSaving = true);
    try {
      await ApiService.updateUserProfile(
        currentUsername: _username,
        newUsername: updatedName,
        email: updatedEmail,
        avatar: _avatar,
        status: _status,
        notificationPush: _pushEnabled,
        notificationSound: _soundEnabled,
        notificationVibrate: _vibrateEnabled,
        notificationPreview: _previewEnabled,
      );

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _username = updatedName;
        _email = updatedEmail;
      });

      if (updatedName != widget.currentUsername) {
        await AuthStorage.saveUsername(updatedName);
        widget.onUsernameChanged(updatedName);
      }

      _showSnack('Profile updated successfully!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.cardDark,
        margin: const EdgeInsets.all(12),
        content: Text(msg, style: const TextStyle(color: AppColors.textPrimary)),
      ),
    );
  }

  // Helper to draw the premium profile photo
  Widget _buildAvatarWidget({double radius = 48}) {
    final initials = _username.isNotEmpty ? _username.substring(0, min(2, _username.length)).toUpperCase() : 'U';

    if (_avatar != null && (_avatar!.startsWith('http://') || _avatar!.startsWith('https://'))) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.cardDark,
        backgroundImage: NetworkImage(_avatar!),
      );
    }

    if (_avatar == null) {
      // Default Gradient Initial avatar
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _avatarGradients[0],
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7B2FF7).withValues(alpha: 0.3),
              blurRadius: 16,
              spreadRadius: 2,
            )
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: GoogleFonts.montserrat(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
    }

    if (_avatar!.startsWith('initials:')) {
      final parts = _avatar!.split(':');
      final gradIdx = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      final grad = _avatarGradients[gradIdx.clamp(0, _avatarGradients.length - 1)];

      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: grad,
          boxShadow: [
            BoxShadow(
              color: grad.colors[0].withValues(alpha: 0.3),
              blurRadius: 16,
              spreadRadius: 2,
            )
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: GoogleFonts.montserrat(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
    }

    // Preset avatar icons
    if (_avatar!.startsWith('preset:')) {
      final index = int.tryParse(_avatar!.split(':')[1]) ?? 0;
      final List<IconData> icons = [
        Icons.face_retouching_natural_rounded,
        Icons.rocket_launch_rounded,
        Icons.sports_esports_rounded,
        Icons.palette_rounded,
        Icons.auto_awesome_rounded,
        Icons.cookie_rounded,
      ];
      final List<Color> colors = [
        Colors.purpleAccent,
        Colors.blueAccent,
        Colors.orangeAccent,
        Colors.pinkAccent,
        Colors.tealAccent,
        Colors.amberAccent,
      ];
      final icon = icons[index.clamp(0, icons.length - 1)];
      final color = colors[index.clamp(0, colors.length - 1)];

      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 16,
              spreadRadius: 2,
            )
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: radius * 1.0,
          color: color,
        ),
      );
    }

    // Base64 or generic mock URL string
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.cardDark,
      backgroundImage: const NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80'),
    );
  }

  int min(int a, int b) => a < b ? a : b;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryPurple),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.amoledBlack,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                // Premium Avatar Profile Header
                Center(
                  child: Stack(
                    children: [
                      _buildAvatarWidget(radius: 54),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showPhotoPickerSheet,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.primaryGradient,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _username,
                    style: GoogleFonts.montserrat(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    _email,
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // SECTION 1: Account (Glass Card)
                _buildSectionHeader('Account Settings'),
                _buildGlassCard(
                  child: Column(
                    children: [
                      _buildListTile(
                        icon: Icons.edit_rounded,
                        title: 'Edit Profile Details',
                        subtitle: 'Change your username or email',
                        onTap: _showEditProfileDialog,
                      ),
                      _buildDivider(),
                      _buildListTile(
                        icon: Icons.lock_reset_rounded,
                        title: 'Change Password',
                        subtitle: 'Update account login credentials',
                        onTap: _showChangePasswordDialog,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 2: Presence Status
                _buildSectionHeader('My Presence'),
                _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Online Status Indicator',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatusChip('Online', const Color(0xFF10B981)),
                            _buildStatusChip('Away', const Color(0xFFF59E0B)),
                            _buildStatusChip('DND', const Color(0xFFEF4444)),
                            _buildStatusChip('Offline', const Color(0xFF6B7280)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const SizedBox(height: 36),

                // SECTION 3: Logout
                PremiumGradientButton(
                  text: 'Log out from Account',
                  onPressed: _logout,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          if (_isSaving)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryPurple),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // UI builders
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.montserrat(
          color: AppColors.primaryPurple,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.glassBorder.withValues(alpha: 0.25),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      color: AppColors.divider,
      indent: 12,
      endIndent: 12,
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryPurple, size: 20),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textTertiary,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textHint,
        size: 20,
      ),
      onTap: onTap,
    );
  }



  Widget _buildStatusChip(String name, Color color) {
    final isSelected = _status == name;
    return GestureDetector(
      onTap: () {
        setState(() => _status = name);
        _saveProfile();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.glassBorder.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dynamic Avatar Photo Picker Sheet
  void _showPhotoPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Customize Avatar Photo',
                  style: GoogleFonts.montserrat(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // Option 1: Custom Gradient Initials
                Text(
                  'Initials Gradient Profile',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _avatarGradients.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, idx) {
                      final grad = _avatarGradients[idx];
                      return GestureDetector(
                        onTap: () {
                          setState(() => _avatar = 'initials:$idx');
                          Navigator.pop(context);
                          _saveProfile();
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: grad,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                // Option 2: Choose preset cartoon icons
                Text(
                  'Select Preset Icon',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (idx) {
                    final List<IconData> icons = [
                      Icons.face_retouching_natural_rounded,
                      Icons.rocket_launch_rounded,
                      Icons.sports_esports_rounded,
                      Icons.palette_rounded,
                      Icons.auto_awesome_rounded,
                      Icons.cookie_rounded,
                    ];
                    return GestureDetector(
                      onTap: () {
                        setState(() => _avatar = 'preset:$idx');
                        Navigator.pop(context);
                        _saveProfile();
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.glassBorder.withValues(alpha: 0.3),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(icons[idx], size: 18, color: AppColors.primaryPurple),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                // Option 3: Preset Photos
                Text(
                  'Select Premium Abstract Photo',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _presetPhotos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, idx) {
                      final url = _presetPhotos[idx];
                      return GestureDetector(
                        onTap: () {
                          setState(() => _avatar = url);
                          Navigator.pop(context);
                          _saveProfile();
                        },
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryPurple.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                // Option 4: Custom URL / File Simulator
                _buildListTile(
                  icon: Icons.link_rounded,
                  title: 'Enter Custom Photo URL',
                  subtitle: 'Paste any image address from the web',
                  onTap: () {
                    Navigator.pop(context);
                    _showCustomUrlDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCustomUrlDialog() {
    final urlCtrl = TextEditingController(text: _avatar != null && _avatar!.startsWith('http') ? _avatar : '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Custom Profile Photo URL',
            style: GoogleFonts.montserrat(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PremiumTextField(controller: urlCtrl, label: 'Image URL'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
            ),
            TextButton(
              onPressed: () {
                final url = urlCtrl.text.trim();
                if (url.isNotEmpty && !url.startsWith('http')) {
                  _showSnack('Please enter a valid HTTP or HTTPS image link');
                  return;
                }
                Navigator.pop(context);
                setState(() {
                  _avatar = url.isEmpty ? null : url;
                });
                _saveProfile();
              },
              child: const Text('Apply', style: TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  // Dialog: Edit Name / Email
  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _username);
    final emailCtrl = TextEditingController(text: _email);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Edit Profile Details',
            style: GoogleFonts.montserrat(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PremiumTextField(controller: nameCtrl, label: 'Username'),
              const SizedBox(height: 16),
              PremiumTextField(controller: emailCtrl, label: 'Email'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
            ),
            TextButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final email = emailCtrl.text.trim();
                if (name.isEmpty || email.isEmpty) {
                  _showSnack('Fields cannot be empty');
                  return;
                }
                Navigator.pop(context);
                _saveProfile(newName: name, newEmail: email);
              },
              child: const Text('Save Changes', style: TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  // Dialog: Change Password
  void _showChangePasswordDialog() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Change Password',
            style: GoogleFonts.montserrat(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PremiumTextField(controller: oldCtrl, label: 'Current Password', obscureText: true),
                const SizedBox(height: 16),
                PremiumTextField(controller: newCtrl, label: 'New Password', obscureText: true),
                const SizedBox(height: 16),
                PremiumTextField(controller: confirmCtrl, label: 'Confirm New Password', obscureText: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
            ),
            TextButton(
              onPressed: () async {
                final oldPass = oldCtrl.text;
                final newPass = newCtrl.text;
                final confirmPass = confirmCtrl.text;

                if (oldPass.isEmpty || newPass.isEmpty) {
                  _showSnack('Password fields cannot be empty');
                  return;
                }
                if (newPass != confirmPass) {
                  _showSnack('Passwords do not match');
                  return;
                }
                if (newPass.length < 6) {
                  _showSnack('Password must be at least 6 characters');
                  return;
                }

                Navigator.pop(context);
                setState(() => _isSaving = true);
                try {
                  await ApiService.changePassword(
                    username: _username,
                    oldPassword: oldPass,
                    newPassword: newPass,
                  );
                  if (!mounted) return;
                  setState(() => _isSaving = false);
                  _showSnack('Password updated successfully!');
                } catch (e) {
                  if (!mounted) return;
                  setState(() => _isSaving = false);
                  _showSnack(e.toString().replaceFirst('Exception: ', ''));
                }
              },
              child: const Text('Change', style: TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    await AuthStorage.clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }
}

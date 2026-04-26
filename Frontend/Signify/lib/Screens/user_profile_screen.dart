import 'package:flutter/material.dart';
import '../state/app_state.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _showAccessibility = false;

  @override
  void initState() {
    super.initState();
    final fbUser = FirebaseAuth.instance.currentUser;
    String finalName = fbUser?.displayName ?? AppState.prefs?.getString('user_name') ?? '';
    String finalEmail = fbUser?.email ?? AppState.prefs?.getString('user_email') ?? '';

    if (finalName.isEmpty) finalName = 'User';
    if (finalEmail.isEmpty) finalEmail = 'No Email';

    _nameController = TextEditingController(text: finalName);
    _emailController = TextEditingController(text: finalEmail);
    debugPrint("Profile loaded: ${_nameController.text} / ${_emailController.text}");
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fbUser = FirebaseAuth.instance.currentUser;
    String finalName = fbUser?.displayName ?? AppState.prefs?.getString('user_name') ?? '';
    String finalEmail = fbUser?.email ?? AppState.prefs?.getString('user_email') ?? '';

    if (finalName.isEmpty) finalName = 'User';
    if (finalEmail.isEmpty) finalEmail = 'No Email';

    if (!_isEditing) {
      if (_nameController.text != finalName) _nameController.text = finalName;
      if (_emailController.text != finalEmail) _emailController.text = finalEmail;
    }

    return ValueListenableBuilder(
      valueListenable: AppState.localeNotifier,
      builder: (context, _, __) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              AppState.getString('profile'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(_isEditing ? Icons.check : Icons.edit),
                onPressed: () {
                  setState(() {
                    if (_isEditing) {
                      AppState.prefs?.setString('user_name', _nameController.text);
                      AppState.prefs?.setString('user_email', _emailController.text);
                    }
                    _isEditing = !_isEditing;
                  });
                },
              )
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Avatar
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.green[100],
                        child: Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.green[800],
                        ),
                      ),
                      if (_isEditing)
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                            onPressed: () {},
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // User Info
                if (_isEditing) ...[
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: AppState.getString('name'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: AppState.getString('email'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  Text(
                    _nameController.text,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _emailController.text,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                // Options List
                _buildProfileOption(
                  icon: Icons.person_outline,
                  title: AppState.getString('edit_profile'),
                  onTap: () {
                    setState(() {
                      _isEditing = !_isEditing;
                    });
                  },
                ),
                _buildProfileOption(
                  icon: Icons.language,
                  title: AppState.getString('language'),
                  onTap: () {
                    Navigator.pushNamed(context, '/settings');
                  },
                ),
                _buildProfileOption(
                  icon: Icons.accessibility_new,
                  title: AppState.getString('accessibility'),
                  onTap: () {
                    setState(() {
                      _showAccessibility = !_showAccessibility;
                    });
                  },
                ),
                if (_showAccessibility) ...[
                  ValueListenableBuilder(
                    valueListenable: AppState.highContrastNotifier,
                    builder: (context, bool highContrast, __) {
                      return SwitchListTile(
                        title: Text(AppState.getString('high_contrast')),
                        value: highContrast,
                        onChanged: (val) {
                          AppState.highContrastNotifier.value = val;
                        },
                      );
                    }
                  ),
                  ValueListenableBuilder(
                    valueListenable: AppState.textScaleNotifier,
                    builder: (context, double textScale, __) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(AppState.getString('text_size')),
                          ),
                          Slider(
                            value: textScale,
                            min: 0.8,
                            max: 1.5,
                            onChanged: (val) {
                              AppState.textScaleNotifier.value = val;
                            },
                          ),
                        ],
                      );
                    }
                  ),
                ],
                const SizedBox(height: 24),
                _buildProfileOption(
                  icon: Icons.logout,
                  title: AppState.getString('logout'),
                  isDestructive: true,
                  onTap: () {
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/login', (route) => false);
                  },
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isDestructive ? Colors.red : Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? Colors.red : null,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: isDestructive ? Colors.red[200] : Colors.grey[400],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

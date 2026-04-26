import 'package:flutter/material.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _vibration = true;
  double _voiceSpeed = 1.0;
  double _volume = 0.8;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppState.localeNotifier,
      builder: (context, _, __) {
        return ValueListenableBuilder(
          valueListenable: AppState.themeNotifier,
          builder: (context, ThemeMode themeMode, __) {
            bool isDark = themeMode == ThemeMode.dark;
            return Scaffold(
              appBar: AppBar(
                title: Text(
                  AppState.getString('settings'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              body: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  _buildSectionHeader(AppState.getString('preferences')),
                  _buildToggleOption(
                    icon: Icons.dark_mode_outlined,
                    title: AppState.getString('dark_mode'),
                    value: isDark,
                    onChanged: (val) {
                      AppState.themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                    },
                  ),
                  _buildToggleOption(
                    icon: Icons.vibration,
                    title: 'Vibration Feedback',
                    value: _vibration,
                    onChanged: (val) => setState(() => _vibration = val),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Voice & Audio'),
                  _buildSliderOption(
                    icon: Icons.speed,
                    title: 'Voice Speed',
                    value: _voiceSpeed,
                    min: 0.5,
                    max: 2.0,
                    onChanged: (val) => setState(() => _voiceSpeed = val),
                  ),
                  _buildSliderOption(
                    icon: Icons.volume_up_outlined,
                    title: 'Volume',
                    value: _volume,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (val) => setState(() => _volume = val),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader(AppState.getString('language')),
                  _buildDropdownOption(
                    icon: Icons.language,
                    title: AppState.getString('language'),
                    value: AppState.localeNotifier.value.languageCode,
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        AppState.localeNotifier.value = Locale(val);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Emergency Contacts'),
                  _buildEmergencyContactsSection(),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildEmergencyContactsSection() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<List<Map<String, String>>>(
            valueListenable: AppState.emergencyContactsNotifier,
            builder: (context, contacts, child) {
              if (contacts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('No emergency contacts added.', style: TextStyle(fontStyle: FontStyle.italic)),
                );
              }
              return Column(
                children: contacts.asMap().entries.map((entry) {
                  int index = entry.key;
                  Map<String, String> contact = entry.value;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(contact['name'] ?? ''),
                    subtitle: Text(contact['phone'] ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showContactDialog(contact: contact, index: index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            final newList = List<Map<String, String>>.from(AppState.emergencyContactsNotifier.value);
                            newList.removeAt(index);
                            AppState.saveEmergencyContacts(newList);
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _showContactDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Contact'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContactDialog({Map<String, String>? contact, int? index}) {
    final nameController = TextEditingController(text: contact?['name'] ?? '');
    final phoneController = TextEditingController(text: contact?['phone'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(contact == null ? 'Add Contact' : 'Edit Contact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();
                if (name.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name and phone cannot be empty.')),
                  );
                  return;
                }
                
                final newList = List<Map<String, String>>.from(AppState.emergencyContactsNotifier.value);
                final newContact = {'name': name, 'phone': phone};
                
                if (index != null) {
                  newList[index] = newContact;
                } else {
                  newList.add(newContact);
                }
                
                AppState.saveEmergencyContacts(newList);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, left: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildToggleOption({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildSliderOption({
    required IconData icon,
    required String title,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: value,
            min: min,
            max: max,
            activeColor: Colors.green,
            inactiveColor: Colors.green[100],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownOption({
    required IconData icon,
    required String title,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.primary),
            items: items,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

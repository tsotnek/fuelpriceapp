import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/product_idea.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';

class ProductIdeaScreen extends StatefulWidget {
  const ProductIdeaScreen({super.key});

  @override
  State<ProductIdeaScreen> createState() => _ProductIdeaScreenState();
}

class _ProductIdeaScreenState extends State<ProductIdeaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitIdea() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final userProvider = context.read<UserProvider>();
      final userId = userProvider.isAuthenticated
          ? userProvider.user.id
          : 'anonymous';

      // Gather device info
      final deviceInfo = DeviceInfoPlugin();
      String deviceName = 'unknown';
      String osVersion = 'unknown';

      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        deviceName = webInfo.browserName.toString();
        osVersion = webInfo.platform ?? 'web';
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            final androidInfo = await deviceInfo.androidInfo;
            deviceName = '${androidInfo.manufacturer} ${androidInfo.model}';
            osVersion = 'Android ${androidInfo.version.release}';
            break;
          case TargetPlatform.iOS:
            final iosInfo = await deviceInfo.iosInfo;
            deviceName = iosInfo.name;
            osVersion = 'iOS ${iosInfo.systemVersion}';
            break;
          default:
            deviceName = 'unknown';
            osVersion = defaultTargetPlatform.toString();
        }
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

      final idea = ProductIdea(
        id: const Uuid().v4(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        timestamp: DateTime.now(),
        userId: userId,
        deviceName: deviceName,
        osVersion: osVersion,
        appVersion: appVersion,
      );

      await FirestoreService.submitProductIdea(idea);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Idea submitted. We appreciate your feedback!'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to submit idea: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suggest an Idea')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Have a great idea for the app? We would love to hear it!',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Idea Title',
                hintText: 'e.g., Add dark mode for maps',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title for your idea';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Details',
                hintText:
                    'Tell us more about your idea and how it would help...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 8,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please provide some details';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submitIdea,
              icon: const Icon(Icons.lightbulb_outline),
              label: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit Idea'),
            ),
            const SizedBox(height: 16),
            Text(
              'Your idea will be shared with the community on our GitHub Discussions board.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

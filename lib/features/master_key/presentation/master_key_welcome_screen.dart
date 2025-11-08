import 'package:flutter/material.dart';
import 'package:local_sync/features/master_key/presentation/generate_master_key_screen.dart';
import 'package:local_sync/features/master_key/presentation/import_master_key_screen.dart';

class MasterKeyWelcomeScreen extends StatelessWidget {
  const MasterKeyWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome to LocalSync',
                style: textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'To use the "Secure Vault" feature, you must first create a Master Key.',
                style: textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This key is a 24-word phrase that encrypts your vault and allows you to recover it on other devices. No one else can access it.',
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const GenerateMasterKeyScreen(),
                    ),
                  );
                },
                child: const Text('Create New Master Key'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ImportMasterKeyScreen(),
                    ),
                  );
                },
                child: const Text('Import Existing Key'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class ImportMasterKeyScreen extends StatelessWidget {
  const ImportMasterKeyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Master Key')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Placeholder for key import UI.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Text(
                'This screen will soon show a text field for the mnemonic and an "Import" button.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

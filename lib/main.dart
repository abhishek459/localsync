import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_sync/features/discovery/presentation/peer_list_view.dart';
import 'package:local_sync/features/identity/data/identity_providers.dart';
import 'package:local_sync/features/master_key/data/master_key_providers.dart';
import 'package:local_sync/features/master_key/presentation/master_key_welcome_screen.dart';
import 'package:local_sync/features/pairing/data/pairing_providers.dart';
import 'package:local_sync/features/pairing/presentation/pairing_screen.dart';
import 'package:local_sync/features/shared/application/app_notification_provider.dart';
import 'package:local_sync/features/shared/domain/app_notification.dart';
import 'package:local_sync/features/shared/presentation/app_theme.dart';
import 'package:local_sync/features/vault/presentation/secure_vault_screen.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LocalSync',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AppEntry(),
    );
  }
}

/// AppEntry is now the main entry point.
/// It watches the masterKeyProvider to decide which screen to show.
class AppEntry extends ConsumerWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masterKeyAsync = ref.watch(masterKeyProvider);

    ref.listen(appNotificationStreamProvider, (previous, next) {
      next.whenData((AppNotification notification) {
        // We have a notification, decide how to show it
        switch (notification.type) {
          case NotificationType.toast:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(notification.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
            break;
          case NotificationType.success:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(notification.message),
                backgroundColor: Colors.green, // Or your theme's success color
              ),
            );
            break;
          case NotificationType.info:
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(notification.message)));
            break;
          case NotificationType.dialog:
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('An Error Occurred'),
                content: Text(notification.message),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            break;
          case NotificationType.critical:
            debugPrint('CRITICAL ERROR: ${notification.message}');
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Critical Error'),
                content: Text(
                  '${notification.message}\nThe app may not function correctly.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            break;
        }
      });
    });

    return masterKeyAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Fatal Error: Could not load master key.\n$err',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (mnemonic) {
        if (mnemonic == null) {
          // No key exists, force user to create/import one.
          return const MasterKeyWelcomeScreen();
        } else {
          // Key exists, proceed to the main application.
          return const HomeScreen();
        }
      },
    );
  }
}

// Converted to ConsumerStatefulWidget to manage the _isModalOpen state.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // State variable to prevent opening multiple modals.
  bool _isModalOpen = false;

  int _currentIndex = 0;

  final _screens = [
    const _PeersTab(), // The original body, refactored below
    const SecureVaultScreen(), // The screen you want to navigate to
  ];

  @override
  Widget build(BuildContext context) {
    // Watch our identity provider
    // final identityAsync = ref.watch(deviceIdentityProvider); // No longer needed here

    // --- Robust Bridge Listener (Refactored) ---
    ref.listen(pairingRequestProvider, (previous, next) {
      // If a request is made (next == true) AND the modal isn't already open
      if (next == true && !_isModalOpen) {
        // Set state to true immediately to block concurrent requests
        setState(() {
          _isModalOpen = true;
        });

        showModalBottomSheet(
          context: context,
          isScrollControlled: true, // Required for fractional height
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAliasWithSaveLayer,
          builder: (context) {
            // Use FractionallySizedBox to control the height
            return const FractionallySizedBox(
              heightFactor: 0.85, // Replaces the old heightFactor parameter
              child: PairingScreen(),
            );
          },
        ).whenComplete(() {
          // When the sheet is dismissed (for any reason), update our state.
          setState(() {
            _isModalOpen = false;
          });
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(pairingRequestProvider.notifier).consume();
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'LocalSync - Peers' : 'Secure Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: 'Add a new device',
            onPressed: () {
              ref.read(pairingRequestProvider.notifier).request();
            },
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.hub_outlined),
            activeIcon: Icon(Icons.hub),
            label: 'Peers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lock_outline),
            activeIcon: Icon(Icons.lock),
            label: 'Secure Vault',
          ),
        ],
      ),
    );
  }
}

class _PeersTab extends ConsumerWidget {
  const _PeersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(deviceIdentityProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Identity Card ---
          Card(
            elevation: 4,
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'MY DEVICE IDENTITY',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  // Use AsyncValue.when for clean loading/error states
                  identityAsync.when(
                    data: (identity) => SelectableText(
                      identity.fingerprint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (err, stack) => Text(
                      'Error loading identity:\n$err',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'DISCOVERED PEERS',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Expanded(child: PeerListView()),
        ],
      ),
    );
  }
}

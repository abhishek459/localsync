import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_sync/features/connection/application/auto_connection_manager.dart';
import 'package:local_sync/features/discovery/presentation/peer_list_view.dart';
import 'package:local_sync/features/master_key/data/master_key_providers.dart';
import 'package:local_sync/features/master_key/presentation/master_key_welcome_screen.dart';
import 'package:local_sync/features/pairing/data/pairing_providers.dart';
import 'package:local_sync/features/pairing/presentation/pairing_dialog_layout.dart';
import 'package:local_sync/features/pairing/presentation/pairing_screen.dart';
import 'package:local_sync/features/shared/application/app_notification_provider.dart';
import 'package:local_sync/features/shared/domain/app_notification.dart';
import 'package:local_sync/features/shared/presentation/adaptive_scaffold.dart';
import 'package:local_sync/features/shared/presentation/app_sizes.dart';
import 'package:local_sync/features/shared/presentation/app_theme.dart';
import 'package:local_sync/features/vault/presentation/secure_vault_screen.dart';
import 'package:local_sync/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
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

class AppEntry extends ConsumerWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masterKeyAsync = ref.watch(masterKeyProvider);

    // PRODUCTION READY FIX:
    // We use ref.listen for side effects.
    ref.listen(appNotificationStreamProvider, (previous, next) {
      // 1. Check if we have valid data to act on
      if (!next.hasValue || next.hasError || next.isLoading) return;

      final notification = next.value!;

      // 2. Schedule UI work for *after* the current frame is painted.
      // This guarantees the context is mounted and valid, and avoids
      // "setState called during build" errors.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 3. Always check mounted before acting on context asynchronously
        if (!context.mounted) return;

        switch (notification.type) {
          case NotificationType.toast:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  notification.message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                backgroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
            );
            break;
          case NotificationType.success:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  notification.message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
            );
            break;
          case NotificationType.info:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  notification.message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            );
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
            padding: const EdgeInsets.all(AppSizes.p4),
            child: Text(
              'Fatal Error: Could not load master key.\n$err',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (mnemonic) {
        if (mnemonic == null) {
          return const MasterKeyWelcomeScreen();
        } else {
          return const HomeScreen();
        }
      },
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isModalOpen = false;
  int _currentIndex = 0;

  final _pages = [const _PeersTab(), const SecureVaultScreen()];

  final _destinations = [
    const AdaptiveDestination(
      icon: Icons.hub_outlined,
      selectedIcon: Icons.hub,
      label: 'Peers',
    ),
    const AdaptiveDestination(
      icon: Icons.lock_outline,
      selectedIcon: Icons.lock,
      label: 'Secure Vault',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Initialize the manager (which now sets up listeners once)
    ref.watch(autoConnectionManagerProvider);

    final bool isDesktop = !Platform.isAndroid && !Platform.isIOS;

    ref.listen(pairingRequestProvider, (previous, next) {
      if (next == true && !_isModalOpen) {
        setState(() => _isModalOpen = true);

        // Using postFrameCallback here as well ensures the modal transition
        // starts cleanly after the current build cycle.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          if (isDesktop) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) {
                return const Dialog(
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    width: 800,
                    height: 550,
                    child: PairingDialogLayout(),
                  ),
                );
              },
            ).whenComplete(() {
              if (mounted) {
                setState(() => _isModalOpen = false);
                ref.read(pairingRequestProvider.notifier).consume();
              }
            });
          } else {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) {
                return const FractionallySizedBox(
                  heightFactor: 0.85,
                  child: PairingScreen(),
                );
              },
            ).whenComplete(() {
              if (mounted) {
                setState(() => _isModalOpen = false);
                ref.read(pairingRequestProvider.notifier).consume();
              }
            });
          }
        });
      }
    });

    return AdaptiveScaffold(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) => setState(() => _currentIndex = index),
      destinations: _destinations,
      pages: _pages,
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
    );
  }
}

class _PeersTab extends ConsumerWidget {
  const _PeersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairingDataAsync = ref.watch(myPairingDataProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSizes.p6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.p4),
              child: Column(
                children: [
                  Text(
                    'MY DEVICE IDENTITY',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSizes.p4),
                  pairingDataAsync.when(
                    data: (identity) => SelectableText(
                      identity.deviceId,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (err, stack) => Text(
                      'Error loading identity:\n$err',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
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
          const SizedBox(height: AppSizes.p4),
          const Expanded(child: PeerListView()),
        ],
      ),
    );
  }
}

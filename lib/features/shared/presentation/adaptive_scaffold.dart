import 'dart:io';
import 'package:flutter/material.dart';

/// A simple data class to hold the navigation destination data.
/// This is used by [AdaptiveScaffold] to build the appropriate
/// mobile or desktop navigation.
class AdaptiveDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const AdaptiveDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// A scaffold that adapts its navigation element based on the platform.
///
/// On mobile (Android/iOS), it uses a [BottomNavigationBar].
/// On desktop (all other platforms), it uses a [NavigationRail].
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.pages,
    this.appBar,
    this.floatingActionButton,
  });

  /// The app bar to display at the top of the scaffold.
  final PreferredSizeWidget? appBar;

  /// The list of destinations (tabs) for navigation.
  final List<AdaptiveDestination> destinations;

  /// The list of page widgets to display. The length must
  /// match the length of [destinations].
  final List<Widget> pages;

  /// The index of the currently selected page.
  final int selectedIndex;

  /// Callback for when a new destination is selected.
  final ValueChanged<int> onDestinationSelected;

  /// The floating action button to display.
  final FloatingActionButton? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    // We determine the platform.
    final bool isDesktop = !Platform.isAndroid && !Platform.isIOS;

    // We build the [IndexedStack] of pages.
    final Widget body = IndexedStack(index: selectedIndex, children: pages);

    if (isDesktop) {
      // --- DESKTOP LAYOUT ---
      return Scaffold(
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              backgroundColor: Theme.of(context).colorScheme.surface,
              labelType: NavigationRailLabelType.all,
              destinations: destinations.map((d) {
                return NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                );
              }).toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: body),
          ],
        ),
      );
    } else {
      // --- MOBILE LAYOUT ---
      return Scaffold(
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: destinations.map((d) {
            return NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            );
          }).toList(),
        ),
      );
    }
  }
}

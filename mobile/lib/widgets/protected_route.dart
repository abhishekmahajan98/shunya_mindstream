import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class ProtectedRoute extends ConsumerWidget {
  final Widget child;
  final String requiredRole;

  const ProtectedRoute({
    super.key,
    required this.child,
    required this.requiredRole,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    // If still rehydrating or logging in, show simple splash loader matching React loading spinner
    if (auth.loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Role mismatch check, handles redirect fallback elegantly
    final profile = auth.profile;
    if (profile == null || profile.role != requiredRole) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 48, color: Colors.orange),
                const SizedBox(height: 16),
                const Text('Role Access Denied', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('This page requires the role of $requiredRole.', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    return child;
  }
}

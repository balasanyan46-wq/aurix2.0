import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/screens/subscription/subscription_screen.dart';

class SubscriptionRouteScreen extends ConsumerWidget {
  const SubscriptionRouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SubscriptionScreen();
  }
}

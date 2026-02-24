import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/core/l10n.dart';

final appStateProvider = ChangeNotifierProvider<AppState>((ref) => AppState());

/// Mock app state — holds screen, role, subscription, locale.
/// No persistence, no network.
class AppState extends ChangeNotifier {
  AppScreen _currentScreen = AppScreen.home;
  String? _selectedReleaseId;
  String _searchQuery = '';
  UserRole _currentUserRole = UserRole.artist;
  bool _isSubscribed = true;
  SubscriptionPlan _subscriptionPlan = SubscriptionPlan.breakthrough;
  AppLocale _locale = AppLocale.ru;

  AppScreen get currentScreen => _currentScreen;
  String? get selectedReleaseId => _selectedReleaseId;
  String get searchQuery => _searchQuery;

  void setSearchQuery(String q) {
    if (_searchQuery != q) {
      _searchQuery = q;
      notifyListeners();
    }
  }
  UserRole get currentUserRole => _currentUserRole;
  AppLocale get locale => _locale;
  bool get isSubscribed => _isSubscribed;
  SubscriptionPlan get subscriptionPlan => _subscriptionPlan;

  bool get isAdmin => _currentUserRole == UserRole.admin;

  void navigateTo(AppScreen screen, {String? releaseId}) {
    _currentScreen = screen;
    _selectedReleaseId = releaseId;
    notifyListeners();
  }

  void goBack() {
    if (_currentScreen == AppScreen.releaseDetails) {
      _currentScreen = AppScreen.releases;
      _selectedReleaseId = null;
    } else {
      _currentScreen = AppScreen.home;
    }
    notifyListeners();
  }
  bool get canSubmitRelease =>
      _isSubscribed && (_subscriptionPlan == SubscriptionPlan.empire || _subscriptionPlan == SubscriptionPlan.breakthrough || (_subscriptionPlan == SubscriptionPlan.start && _activeReleasesThisMonth < 1));
  int _activeReleasesThisMonth = 0; // mock: 0 for pro = unlimited, 1 for basic limit

  int get activeReleasesThisMonth => _activeReleasesThisMonth;

  void setRole(UserRole role) {
    if (_currentUserRole != role) {
      _currentUserRole = role;
      notifyListeners();
    }
  }

  void setSubscription(bool subscribed, SubscriptionPlan plan) {
    if (_isSubscribed != subscribed || _subscriptionPlan != plan) {
      _isSubscribed = subscribed;
      _subscriptionPlan = plan;
      _activeReleasesThisMonth = plan == SubscriptionPlan.start ? 1 : 0;
      notifyListeners();
    }
  }

  void activateSubscription(SubscriptionPlan plan) {
    _isSubscribed = true;
    _subscriptionPlan = plan;
    _activeReleasesThisMonth = 0;
    notifyListeners();
  }

  void setLocale(AppLocale locale) {
    if (_locale != locale) {
      _locale = locale;
      notifyListeners();
    }
  }
}

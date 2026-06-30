import 'package:flutter/material.dart';
import '../models/cat_profile.dart';

/// Holds the currently selected cat for the whole app session.
///
/// Updated whenever the live list of cats changes (cat added/removed) or
/// when the user explicitly switches cats via [CatSwitcher].
class CatSession extends ChangeNotifier {
  CatProfile? _currentCat;

  CatProfile? get currentCat => _currentCat;
  String? get currentCatId => _currentCat?.id;

  /// Explicitly switch to a different cat (e.g. user tapped one in the
  /// switcher sheet).
  void selectCat(CatProfile cat) {
    if (_currentCat?.id == cat.id) return;
    _currentCat = cat;
    notifyListeners();
  }

  /// Called whenever the live `cats` collection stream emits. Keeps the
  /// selection valid (falls back to the first cat if the selected one was
  /// deleted) and refreshes the cached data for the selected cat (e.g. if
  /// its name changed elsewhere).
  void updateFromList(List<CatProfile> cats) {
    if (cats.isEmpty) {
      if (_currentCat != null) {
        _currentCat = null;
        notifyListeners();
      }
      return;
    }

    final selectedId = _currentCat?.id;
    final stillExists = selectedId != null &&
        cats.any((c) => c.id == selectedId);

    final next =
        stillExists ? cats.firstWhere((c) => c.id == selectedId) : cats.first;

    _currentCat = next;
    notifyListeners();
  }
}

/// Exposes a [CatSession] to the widget tree. Use [CatSessionScope.of] to
/// read the current selection and listen for changes.
class CatSessionScope extends InheritedNotifier<CatSession> {
  const CatSessionScope({
    super.key,
    required CatSession session,
    required super.child,
  }) : super(notifier: session);

  static CatSession of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<CatSessionScope>();
    assert(scope != null, 'No CatSessionScope found in context');
    return scope!.notifier!;
  }
}

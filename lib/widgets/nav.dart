import 'package:flutter/material.dart';

/// Route name [openPage] gives [page]: its type, plus [id] for pages showing one record
/// (a session, a planned workout …).
String pageRouteName(Widget page, [Object? id]) => id == null ? '${page.runtimeType}' : '${page.runtimeType}/$id';

/// The route for [page], named by [pageRouteName] – for pages pushed directly (after closing a sheet,
/// replacing the current page …), so [openPage] still recognises them as "this page is already open".
MaterialPageRoute<T> pageRoute<T>(Widget page, {Object? id, bool fullscreenDialog = false}) =>
    MaterialPageRoute<T>(settings: RouteSettings(name: pageRouteName(page, id)), fullscreenDialog: fullscreenDialog, builder: (_) => page);

/// The navigator's top route (the page being pushed, while its transition still runs).
Route<dynamic>? _topRoute(NavigatorState nav) {
  Route<dynamic>? top;
  nav.popUntil((r) {
    top = r;
    return true; // the first (topmost) route: nothing is popped
  });
  return top;
}

/// Opens [page] from a tile, card or row – at most once per tap:
/// - a second tap that lands while the first page is already being pushed (a fast double tap, or
///   a tap during the transition) is ignored, since the tapped widget's route is no longer on top;
/// - a tile shown on the very page it opens (e.g. the body-composition card on the body page)
///   does nothing instead of stacking the same page again, which then had to be closed twice.
///
/// The tapped widget's route is looked up through its settings only ([ModalRoute.settingsOf]), which
/// never change – no dependency that rebuilds the tile whenever a page is pushed above it or popped.
///
/// Returns the page's result, or null when nothing was opened.
Future<T?> openPage<T>(BuildContext context, Widget page, {Object? id, bool fullscreenDialog = false}) async {
  final name = pageRouteName(page, id);
  final nav = Navigator.of(context);
  final here = ModalRoute.settingsOf(context);
  final top = _topRoute(nav);
  if (top != null && (top.settings.name == name || (here != null && !identical(top.settings, here)))) return null;
  return nav.push<T>(pageRoute<T>(page, id: id, fullscreenDialog: fullscreenDialog));
}

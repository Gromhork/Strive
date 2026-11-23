import 'package:flutter/material.dart';

/// Route name [openPage] gives [page]: its type, plus [id] for pages showing one record
/// (a session, a planned workout …).
String pageRouteName(Widget page, [Object? id]) => id == null ? '${page.runtimeType}' : '${page.runtimeType}/$id';

/// Opens [page] from a tile, card or row – at most once per tap:
/// - a second tap that lands while the first page is already being pushed (a fast double tap, or
///   a tap during the transition) is ignored, since the tapped widget's route is no longer on top;
/// - a tile shown on the very page it opens (e.g. the body-composition card on the body page)
///   does nothing instead of stacking the same page again, which then had to be closed twice.
///
/// Returns the page's result, or null when nothing was opened.
Future<T?> openPage<T>(BuildContext context, Widget page, {Object? id, bool fullscreenDialog = false}) async {
  final name = pageRouteName(page, id);
  final here = ModalRoute.of(context);
  if (here != null && (!here.isCurrent || here.settings.name == name)) return null;
  return Navigator.of(
    context,
  ).push<T>(MaterialPageRoute<T>(settings: RouteSettings(name: name), fullscreenDialog: fullscreenDialog, builder: (_) => page));
}

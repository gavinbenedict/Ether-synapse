/// Route exports barrel file.
///
/// Re-exports everything needed to navigate between routes from a single
/// import. Use this in screen files to avoid importing router internals.
///
/// Usage:
///   import 'package:ether_synapse/routes/routes.dart';
library;

export '../core/router/routes.dart';
export '../core/router/app_router.dart' show appRouterProvider;

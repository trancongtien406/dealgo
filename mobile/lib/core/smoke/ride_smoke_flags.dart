/// Local smoke-only flags. Never set in production UI.
abstract final class RideSmokeFlags {
  /// When true, [RideRouteOverviewPage] continues to fare after quote loads.
  static bool autoContinueAfterQuote = false;
}

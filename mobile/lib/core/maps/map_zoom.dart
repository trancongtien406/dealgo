/// Shared zoom limits for every DealGo map (customer, driver, ride, food).
///
/// [kMapMinZoom] stops users pinching out to a whole-country/world view:
/// ~11 still shows a full city (e.g. all of Đà Nẵng) so long rides fit.
const double kMapMinZoom = 11;

/// Street-level detail; raster tiles stop adding detail past this.
const double kMapMaxZoom = 19;

/// Max zoom when auto-framing a route/stops so short trips are not too tight.
const double kMapFitMaxZoom = 17;

/// Clamp any requested zoom into the allowed range.
double clampMapZoom(double zoom) =>
    zoom.clamp(kMapMinZoom, kMapMaxZoom).toDouble();

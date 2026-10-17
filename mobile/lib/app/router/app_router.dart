import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion/dealgo_page_transitions.dart';
import '../../features/driver/domain/usecases/list_open_driver_rides.dart';
import '../../features/driver/domain/usecases/list_ready_driver_orders.dart';
import '../../features/driver/presentation/cubit/driver_feed_cubit.dart';
import '../../features/driver/presentation/pages/driver_active_ride_page.dart';
import '../../features/driver/presentation/pages/driver_food_page.dart';
import '../../features/driver/presentation/pages/driver_job_completed_page.dart';
import '../../features/driver/presentation/pages/driver_job_failed_page.dart';
import '../../features/driver/presentation/pages/driver_passenger_otp_page.dart';
import '../../features/driver/presentation/pages/driver_ride_page.dart';
import '../../features/driver/presentation/pages/driver_services_page.dart';
import '../../features/driver/presentation/utils/driver_routes.dart';
import '../../features/driver/presentation/widgets/driver_widgets.dart';
import '../../features/food/domain/entities/food_models.dart';
import '../../features/merchant/domain/usecases/list_merchant_order_queue.dart';
import '../../features/merchant/presentation/pages/merchant_accept_settings_page.dart';
import '../../features/merchant/presentation/pages/merchant_busy_page.dart';
import '../../features/merchant/presentation/pages/merchant_hours_page.dart';
import '../../features/merchant/presentation/pages/merchant_item_variants_page.dart';
import '../../features/merchant/presentation/pages/merchant_order_page.dart';
import '../../features/merchant/presentation/cubit/merchant_queue_cubit.dart';
import '../../features/merchant/presentation/utils/merchant_routes.dart';
import '../../features/food/presentation/pages/food_cancel_page.dart';
import '../../features/food/presentation/pages/food_cart_page.dart';
import '../../features/food/presentation/pages/food_category_page.dart';
import '../../features/food/presentation/pages/food_checkout_page.dart';
import '../../features/food/presentation/pages/food_invoice_page.dart';
import '../../features/food/presentation/pages/food_item_options_page.dart';
import '../../features/food/presentation/pages/food_order_success_page.dart';
import '../../features/food/presentation/pages/food_search_page.dart';
import '../../features/food/presentation/utils/food_routes.dart';
import '../../features/food/presentation/pages/food_store_page.dart';
import '../../features/food/presentation/pages/food_tracking_page.dart';
import '../../features/ride/domain/entities/ride_models.dart';
import '../../features/ride/domain/entities/ride_money.dart';
import '../../features/ride/domain/entities/ride_vehicle.dart';
import '../../features/ride/presentation/pages/ride_cancel_page.dart';
import '../../features/ride/presentation/pages/ride_confirm_page.dart';
import '../../features/ride/presentation/pages/ride_fare_breakdown_page.dart';
import '../../features/ride/presentation/pages/ride_fare_page.dart';
import '../../features/ride/presentation/pages/ride_matching_page.dart';
import '../../features/ride/presentation/pages/ride_offer_detail_page.dart';
import '../../features/ride/presentation/pages/ride_offers_page.dart';
import '../../features/ride/presentation/pages/ride_pickup_code_page.dart';
import '../../features/ride/presentation/pages/ride_receipt_page.dart';
import '../../features/ride/presentation/pages/ride_route_overview_page.dart';
import '../../features/ride/presentation/utils/ride_routes.dart';
import '../../features/ride/presentation/pages/ride_safety_page.dart';
import '../../features/ride/presentation/pages/ride_tracking_page.dart';
import '../../features/ride/presentation/pages/ride_vehicle_page.dart';
import '../../features/shell/presentation/payment_history_page.dart';
import '../../features/identity/domain/entities/app_role.dart';
import '../../features/identity/domain/auth_redirect.dart';
import '../../features/identity/domain/entities/auth_state.dart';
import '../../features/identity/domain/usecases/create_phone_challenge.dart';
import '../../features/identity/domain/usecases/verify_phone_challenge.dart';
import '../../features/identity/presentation/cubit/auth_cubit.dart';
import '../../features/identity/presentation/pages/otp_page.dart';
import '../../features/identity/presentation/cubit/phone_auth_cubit.dart';
import '../../features/identity/presentation/pages/phone_login_page.dart';
import '../../features/identity/presentation/pages/splash_page.dart';
import '../../features/onboarding/presentation/pages/customer_onboarding_page.dart';
import '../../features/onboarding/presentation/pages/driver_kyc_pages.dart';
import '../../features/onboarding/presentation/utils/driver_kyc_routes.dart';
import '../../features/onboarding/presentation/pages/merchant_kyb_pages.dart';
import '../../features/onboarding/presentation/utils/merchant_kyb_routes.dart';
import '../../features/shell/presentation/account_routes.dart';
import '../../features/shell/presentation/help_center_page.dart';
import '../../features/shell/presentation/notifications_inbox_page.dart';
import '../../features/shell/presentation/place_search_page.dart';
import '../../features/shell/presentation/role_picker_page.dart';
import '../../features/shell/presentation/role_shell.dart';
import '../../features/shell/presentation/saved_addresses_page.dart';
import '../../features/shell/presentation/shell_tab.dart';
import '../../features/shell/presentation/shell_tab_page.dart';

GoRouter createAppRouter({
  required AuthCubit auth,
  required Listenable refreshListenable,
  String initialLocation = AuthRoutes.splash,
}) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    refreshListenable: refreshListenable,
    redirect: (context, state) => authRedirect(auth.state, state.uri),
    routes: [
      GoRoute(
        path: AuthRoutes.splash,
        pageBuilder: (context, state) => dealgoFadeSlidePage(
          key: state.pageKey,
          child: const DealGoSplashScreen(),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return BlocProvider(
            create: (context) => PhoneAuthCubit(
              createPhoneChallenge: context.read<CreatePhoneChallenge>(),
              verifyPhoneChallenge: context.read<VerifyPhoneChallenge>(),
              auth: context.read<AuthCubit>(),
            ),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: AuthRoutes.login,
            builder: (context, state) => const PhoneLoginPage(),
            routes: [
              GoRoute(
                path: 'otp',
                builder: (context, state) {
                  final challengeId = state.uri.queryParameters['challengeId'];
                  final phone = state.uri.queryParameters['phone'];
                  if (challengeId == null ||
                      challengeId.isEmpty ||
                      phone == null ||
                      phone.isEmpty) {
                    return const PhoneLoginPage();
                  }
                  return OtpPage(challengeId: challengeId, phone: phone);
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AuthRoutes.onboarding,
        pageBuilder: (context, state) => dealgoFadeSlidePage(
          key: state.pageKey,
          child: const CustomerOnboardingPage(),
        ),
      ),
      GoRoute(
        path: AuthRoutes.roles,
        pageBuilder: (context, state) {
          final authState = context.watch<AuthCubit>().state;
          final roles = authState is AuthSignedIn
              ? authState.profile.activeAppRoles
              : const <AppRole>[];
          return dealgoFadeSlidePage(
            key: state.pageKey,
            child: RolePickerPage(roles: roles),
          );
        },
      ),
      _roleShell(customerShellTabs, fadeSlideEntry: true),
      _merchantScopedShell(),
      _driverScopedShell(),
      for (final shellPath in const [
        '/customer/account',
        '/merchant/account',
        '/driver/account',
      ])
        ..._accountOverlayRoutes(rootNavigatorKey, shellPath),
      GoRoute(
        path: FoodRoutes.search,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => dealgoFadeSlidePage(
          key: state.pageKey,
          child: const FoodSearchPage(),
        ),
      ),
      GoRoute(
        path: FoodRoutes.category,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final name = state.uri.queryParameters['name'];
          return dealgoFadeSlidePage(
            key: state.pageKey,
            child: FoodCategoryPage(category: name),
          );
        },
      ),
      GoRoute(
        path: '/customer/food/stores/:storeId',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final storeId = state.pathParameters['storeId'] ?? '';
          return dealgoFadeSlidePage(
            key: state.pageKey,
            child: FoodStorePage(storeId: storeId),
          );
        },
        routes: [
          GoRoute(
            path: 'items/:itemId',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) {
              final extra = state.extra;
              if (extra is FoodItemOptionsArgs) {
                return dealgoFadeSlidePage(
                  key: state.pageKey,
                  child: FoodItemOptionsPage(args: extra),
                );
              }
              final storeId = state.pathParameters['storeId'] ?? '';
              return dealgoFadeSlidePage(
                key: state.pageKey,
                child: FoodStorePage(storeId: storeId),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: FoodRoutes.cart,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => dealgoFadeSlidePage(
          key: state.pageKey,
          child: const FoodCartPage(),
        ),
      ),
      GoRoute(
        path: FoodRoutes.checkout,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => dealgoFadeSlidePage(
          key: state.pageKey,
          child: const FoodCheckoutPage(),
        ),
      ),
      GoRoute(
        path: FoodRoutes.orderSuccess,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final extra = state.extra;
          return dealgoFadeSlidePage(
            key: state.pageKey,
            child: extra is FoodOrderSuccessArgs
                ? FoodOrderSuccessPage(args: extra)
                : const FoodCheckoutPage(),
          );
        },
      ),
      GoRoute(
        path: RideRoutes.routeOverview,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final extra = state.extra;
          final places = extra is RidePlaces
              ? extra
              : const RidePlaces(
                  pickupLabel: rideSamplePickupLabel,
                  dropoffLabel: rideSampleDropoffLabel,
                );
          return dealgoFadeSlidePage(
            key: state.pageKey,
            child: RideRouteOverviewPage(places: places),
          );
        },
      ),
      GoRoute(
        path: RideRoutes.vehicle,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final extra = state.extra;
          final places = extra is RidePlaces
              ? extra
              : const RidePlaces(
                  pickupLabel: rideSamplePickupLabel,
                  dropoffLabel: rideSampleDropoffLabel,
                );
          return dealgoFadeSlidePage(
            key: state.pageKey,
            child: RideVehiclePage(places: places),
          );
        },
      ),
      GoRoute(
        path: RideRoutes.fareBreakdown,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final extra = state.extra;
          final draft = extra is RideBookingDraft
              ? extra
              : RideBookingDraft(
                  places: extra is RidePlaces
                      ? extra
                      : const RidePlaces(
                          pickupLabel: rideSamplePickupLabel,
                          dropoffLabel: rideSampleDropoffLabel,
                        ),
                );
          return dealgoFadeSlidePage(
            key: state.pageKey,
            child: RideFareBreakdownPage(draft: draft),
          );
        },
      ),
      GoRoute(
        path: RideRoutes.fare,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final extra = state.extra;
          final Widget child;
          if (extra is RideBookingDraft) {
            child = RideFarePage(
              places: extra.places,
              initialFareVnd: extra.suggestedFareVnd,
              vehicleLabel: extra.vehicleLabel,
            );
          } else {
            final places = extra is RidePlaces
                ? extra
                : const RidePlaces(
                    pickupLabel: rideSamplePickupLabel,
                    dropoffLabel: rideSampleDropoffLabel,
                  );
            child = RideFarePage(places: places);
          }
          return dealgoFadeSlidePage(key: state.pageKey, child: child);
        },
      ),
      GoRoute(
        path: '/customer/ride/matching/:rideId',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final rideId = state.pathParameters['rideId'] ?? '';
          return dealgoFadeSlidePage(
            key: state.pageKey,
            child: RideMatchingPage(rideId: rideId),
          );
        },
      ),
      GoRoute(
        path: '/customer/ride/tracking/:rideId',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final rideId = state.pathParameters['rideId'] ?? '';
          return dealgoFadeSlidePage(
            key: state.pageKey,
            child: RideTrackingPage(rideId: rideId),
          );
        },
        routes: [
          GoRoute(
            path: 'pickup-code',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) {
              final rideId = state.pathParameters['rideId'] ?? '';
              return dealgoFadeSlidePage(
                key: state.pageKey,
                child: RidePickupCodePage(rideId: rideId),
              );
            },
          ),
          GoRoute(
            path: 'safety',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) {
              final rideId = state.pathParameters['rideId'] ?? '';
              return dealgoFadeSlidePage(
                key: state.pageKey,
                child: RideSafetyPage(rideId: rideId),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/customer/ride/cancel/:rideId',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final rideId = state.pathParameters['rideId'] ?? '';
          return dealgoFadeSlidePage(
            key: state.pageKey,
            child: RideCancelPage(rideId: rideId),
          );
        },
      ),
      GoRoute(
        path: '/customer/ride/receipt/:rideId',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final rideId = state.pathParameters['rideId'] ?? '';
          return dealgoFadeSlidePage(
            key: state.pageKey,
            child: RideReceiptPage(rideId: rideId),
          );
        },
      ),
      GoRoute(
        path: '/customer/food/orders/:orderId',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final orderId = state.pathParameters['orderId'] ?? '';
          return dealgoFadeSlidePage(
            key: state.pageKey,
            child: FoodTrackingPage(orderId: orderId),
          );
        },
        routes: [
          GoRoute(
            path: 'invoice',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) {
              final orderId = state.pathParameters['orderId'] ?? '';
              return dealgoFadeSlidePage(
                key: state.pageKey,
                child: FoodInvoicePage(orderId: orderId),
              );
            },
          ),
          GoRoute(
            path: 'cancel',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) {
              final orderId = state.pathParameters['orderId'] ?? '';
              return dealgoFadeSlidePage(
                key: state.pageKey,
                child: FoodCancelPage(orderId: orderId),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/customer/ride/offers/:rideId',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final rideId = state.pathParameters['rideId'] ?? '';
          return dealgoFadeSlidePage(
            key: state.pageKey,
            child: RideOffersPage(rideId: rideId),
          );
        },
        routes: [
          GoRoute(
            path: 'detail',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) {
              final rideId = state.pathParameters['rideId'] ?? '';
              final offerId = state.uri.queryParameters['offerId'];
              final extra = state.extra;
              return dealgoFadeSlidePage(
                key: state.pageKey,
                child: RideOfferDetailPage(
                  rideId: rideId,
                  offerId: offerId,
                  args: extra is RideOfferDetailArgs ? extra : null,
                ),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/customer/ride/confirm/:rideId',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final extra = state.extra;
          return dealgoFadeSlidePage(
            key: state.pageKey,
            child: extra is RideConfirmArgs
                ? RideConfirmPage(args: extra)
                : RideOffersPage(rideId: state.pathParameters['rideId'] ?? ''),
          );
        },
      ),
      GoRoute(
        path: DriverKycRoutes.root,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DriverKycGatePage(),
        routes: [
          GoRoute(
            path: 'intro',
            builder: (context, state) => const DriverKycIntroPage(),
          ),
          GoRoute(
            path: 'steps',
            builder: (context, state) => const DriverKycStepsPage(),
          ),
          GoRoute(
            path: 'status',
            builder: (context, state) => const DriverKycStatusPage(),
          ),
          GoRoute(
            path: 'rejected',
            builder: (context, state) => const DriverKycRejectedPage(),
          ),
        ],
      ),
      GoRoute(
        path: MerchantKybRoutes.root,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MerchantKybGatePage(),
        routes: [
          GoRoute(
            path: 'intro',
            builder: (context, state) => const MerchantKybIntroPage(),
          ),
          GoRoute(
            path: 'steps',
            builder: (context, state) => const MerchantKybStepsPage(),
          ),
          GoRoute(
            path: 'status',
            builder: (context, state) => const MerchantKybStatusPage(),
          ),
          GoRoute(
            path: 'rejected',
            builder: (context, state) => const MerchantKybRejectedPage(),
          ),
        ],
      ),
    ],
  );
}

OpenRide? _openRide(BuildContext context, GoRouterState state) {
  final extra = state.extra;
  final id = state.pathParameters['rideId'] ?? '';
  if (extra is OpenRide && (id.isEmpty || extra.id == id)) {
    return extra;
  }
  return openRideFrom(context.read<DriverFeedCubit>().state, id);
}

MerchantQueueOrder? _merchantOrder(BuildContext context, GoRouterState state) {
  final extra = state.extra;
  final id = state.pathParameters['orderId'] ?? '';
  if (extra is MerchantQueueOrder && (id.isEmpty || extra.id == id)) {
    return extra;
  }
  return merchantOrderFrom(context.read<MerchantQueueCubit>().state, id);
}

ReadyFoodJob? _readyFood(BuildContext context, GoRouterState state) {
  final extra = state.extra;
  final id = state.pathParameters['orderId'] ?? '';
  if (extra is ReadyFoodJob && (id.isEmpty || extra.id == id)) {
    return extra;
  }
  return readyFoodFrom(context.read<DriverFeedCubit>().state, id);
}

class AuthRefreshListenable extends ChangeNotifier {
  AuthRefreshListenable(AuthCubit auth) {
    _subscription = auth.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

ShellRoute _driverScopedShell() {
  return ShellRoute(
    builder: (context, state, child) {
      return BlocProvider(
        create: (context) => DriverFeedCubit(
          listOpenDriverRides: context.read<ListOpenDriverRides>(),
          listReadyDriverOrders: context.read<ListReadyDriverOrders>(),
        ),
        child: child,
      );
    },
    routes: [
      _roleShell(driverShellTabs),
      GoRoute(
        path: DriverRoutes.services,
        builder: (context, state) => const DriverServicesPage(),
      ),
      GoRoute(
        path: '/driver/rides/:rideId',
        builder: (context, state) {
          final ride = _openRide(context, state);
          if (ride == null) {
            return const DriverMissingJobPage();
          }
          return DriverRideDetailPage(ride: ride);
        },
        routes: [
          GoRoute(
            path: 'offer',
            builder: (context, state) {
              final ride = _openRide(context, state);
              if (ride == null) {
                return const DriverMissingJobPage();
              }
              return DriverOfferPage(ride: ride);
            },
          ),
          GoRoute(
            path: 'active',
            builder: (context, state) {
              final rideId = state.pathParameters['rideId'] ?? '';
              final extra = state.extra;
              OpenRide? ride;
              var phase = DriverRidePhase.navigatePickup;
              if (extra is OpenRide) {
                ride = extra;
              } else if (extra is Map) {
                final mapped = extra['ride'];
                if (mapped is OpenRide) {
                  ride = mapped;
                }
                phase = parseDriverRidePhase(extra['phase']);
              }
              ride ??= _openRide(context, state);
              return DriverActiveRidePage(
                rideId: rideId,
                ride: ride,
                initialPhase: phase,
              );
            },
          ),
          GoRoute(
            path: 'otp',
            builder: (context, state) {
              final rideId = state.pathParameters['rideId'] ?? '';
              final ride = state.extra is OpenRide
                  ? state.extra as OpenRide
                  : _openRide(context, state);
              return DriverPassengerOtpPage(rideId: rideId, ride: ride);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/driver/food/:orderId',
        builder: (context, state) {
          final job = _readyFood(context, state);
          if (job == null) {
            return const DriverMissingJobPage();
          }
          return DriverFoodDetailPage(job: job);
        },
      ),
      GoRoute(
        path: '/driver/jobs/failed/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId'] ?? '';
          return DriverJobFailedPage(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/driver/jobs/completed/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId'] ?? '';
          return DriverJobCompletedPage(jobId: jobId);
        },
      ),
    ],
  );
}

ShellRoute _merchantScopedShell() {
  return ShellRoute(
    builder: (context, state, child) {
      return BlocProvider(
        create: (context) => MerchantQueueCubit(
          listMerchantOrderQueue: context.read<ListMerchantOrderQueue>(),
        ),
        child: child,
      );
    },
    routes: [
      _roleShell(merchantShellTabs),
      GoRoute(
        path: '/merchant/orders/:orderId',
        builder: (context, state) {
          final order = _merchantOrder(context, state);
          if (order == null) {
            return const MerchantMissingOrderPage();
          }
          return MerchantOrderPage(order: order);
        },
      ),
      GoRoute(
        path: MerchantRoutes.acceptSettings,
        builder: (context, state) => const MerchantAcceptSettingsPage(),
      ),
      GoRoute(
        path: MerchantRoutes.hours,
        builder: (context, state) => const MerchantHoursPage(),
      ),
      GoRoute(
        path: MerchantRoutes.busy,
        builder: (context, state) => const MerchantBusyPage(),
      ),
      GoRoute(
        path: '/merchant/products/:itemId/variants',
        builder: (context, state) {
          final itemId = state.pathParameters['itemId'] ?? '';
          final name = state.uri.queryParameters['name'];
          return MerchantItemVariantsPage(itemId: itemId, itemName: name);
        },
      ),
    ],
  );
}

StatefulShellRoute _roleShell(
  List<ShellTab> tabs, {
  bool fadeSlideEntry = false,
}) {
  final branches = [
    for (final tab in tabs)
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: tab.path,
            builder: (context, state) => ShellTabPage(tab: tab),
            routes: [
              if (tab.kind == ShellTabKind.account)
                GoRoute(
                  path: 'notifications',
                  builder: (context, state) => const NotificationsInboxPage(),
                ),
            ],
          ),
        ],
      ),
  ];

  if (fadeSlideEntry) {
    return StatefulShellRoute.indexedStack(
      pageBuilder: (context, state, navigationShell) {
        return dealgoFadeSlidePage(
          key: state.pageKey,
          child: RoleShell(navigationShell: navigationShell, tabs: tabs),
        );
      },
      branches: branches,
    );
  }

  return StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) {
      return RoleShell(navigationShell: navigationShell, tabs: tabs);
    },
    branches: branches,
  );
}

List<GoRoute> _accountOverlayRoutes(
  GlobalKey<NavigatorState> rootNavigatorKey,
  String shellPath,
) {
  return [
    GoRoute(
      path: AccountRoutes.addresses(shellPath),
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => SavedAddressesPage(shellPath: shellPath),
    ),
    GoRoute(
      path: AccountRoutes.places(shellPath),
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => PlaceSearchPage(shellPath: shellPath),
    ),
    GoRoute(
      path: AccountRoutes.help(shellPath),
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const HelpCenterPage(),
    ),
    GoRoute(
      path: AccountRoutes.payments(shellPath),
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const PaymentHistoryPage(),
    ),
  ];
}

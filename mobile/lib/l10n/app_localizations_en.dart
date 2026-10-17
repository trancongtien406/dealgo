// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionSeeAll => 'See all';

  @override
  String get actionExplore => 'Explore now';

  @override
  String get actionBookRideNow => 'Book a ride';

  @override
  String get actionVerifyContinue => 'Verify and continue';

  @override
  String get actionBack => 'Back';

  @override
  String get actionSend => 'Send';

  @override
  String get actionChange => 'Change';

  @override
  String get actionResend => 'Resend';

  @override
  String get actionResendCode => 'Resend code';

  @override
  String get actionChangePhone => 'Change phone number';

  @override
  String get actionKeepEnteringCode => 'Keep entering code';

  @override
  String get actionHuntDeals => 'Hunt deals';

  @override
  String get errorNetwork => 'Unable to reach the server';

  @override
  String get errorSessionExpired => 'Your session is no longer valid';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get errorLoadFailed => 'Could not load data';

  @override
  String get errorOffline =>
      'You appear to be offline. Check the connection and try again.';

  @override
  String get errorUnauthorized => 'Please sign in again';

  @override
  String get emptyGeneric => 'Nothing here yet';

  @override
  String get emptyStoresNearby => 'No stores nearby yet';

  @override
  String get emptyActivity => 'No activity in this filter yet';

  @override
  String get emptyNotifications => 'No notifications in this group';

  @override
  String get emptyOffers => 'No driver offers yet';

  @override
  String get emptyOrders => 'No orders in the queue';

  @override
  String get statusOnline => 'Online';

  @override
  String get statusOffline => 'Offline';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusProcessing => 'Processing';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusSearching => 'Finding a driver';

  @override
  String get statusAssigned => 'Driver assigned';

  @override
  String get statusOnTrip => 'On trip';

  @override
  String get statusPreparing => 'Preparing';

  @override
  String get statusReady => 'Ready for pickup';

  @override
  String get statusDelivering => 'Out for delivery';

  @override
  String get tabHome => 'Home';

  @override
  String get tabTrips => 'Trips';

  @override
  String get tabBook => 'Book';

  @override
  String get tabShop => 'Shop';

  @override
  String get tabAccount => 'Account';

  @override
  String get tabOverview => 'Overview';

  @override
  String get tabOrders => 'Orders';

  @override
  String get tabProducts => 'Products';

  @override
  String get tabStats => 'Insights';

  @override
  String get tabJobs => 'Jobs';

  @override
  String get tabEarnings => 'Earnings';

  @override
  String get tabNotifications => 'Alerts';

  @override
  String get filterAll => 'All';

  @override
  String get filterRides => 'Trips';

  @override
  String get filterFood => 'Food';

  @override
  String get filterShopping => 'Shopping';

  @override
  String get filterOrders => 'Orders';

  @override
  String get filterSystem => 'System';

  @override
  String get filterNearby => 'Near me';

  @override
  String get filterSaved => 'Saved';

  @override
  String get filterJobs => 'Jobs';

  @override
  String get filterEarnings => 'Earnings';

  @override
  String get authWelcomeTitle => 'Welcome to DealGo!';

  @override
  String get authWelcomePrefix => 'Welcome to\n';

  @override
  String get authWelcomeBrand => 'DealGo';

  @override
  String get authWelcomeSuffix => '!';

  @override
  String get authWelcomeBody =>
      'Enter your phone number to sign in or create an account. One account works across roles.';

  @override
  String get authPhoneLabel => 'Phone number';

  @override
  String get authPhoneHint => 'Enter phone number';

  @override
  String get authOtpInfo =>
      'An OTP will be sent to verify and protect your account.';

  @override
  String get authTermsPrefix => 'By continuing, you agree to DealGo’s ';

  @override
  String get authTermsOfUse => 'Terms of Use';

  @override
  String get authTermsAnd => ' and ';

  @override
  String get authPrivacyPolicy => 'Privacy Policy';

  @override
  String get authTermsSuffix => '.';

  @override
  String get authMockDemo => 'Enter demo (mock)';

  @override
  String get otpTitle => 'Verify OTP';

  @override
  String get otpHeading => 'Verify phone number';

  @override
  String get otpBodyPrefix => 'Enter the 6-digit OTP sent to\n';

  @override
  String get otpNotReceived => 'Didn’t get a code?';

  @override
  String get otpSending => 'Sending';

  @override
  String otpResendAfter(String time) {
    return 'Resend in $time';
  }

  @override
  String get otpProtectTitle => 'Protect your account';

  @override
  String get otpProtectBody =>
      'OTP codes expire. Never share this code with anyone.';

  @override
  String get otpInvalidTitle => 'Incorrect verification code';

  @override
  String get otpExpiredTitle => 'Verification code expired';

  @override
  String get otpLockedBody =>
      'Too many incorrect attempts. Request a new code later.';

  @override
  String get otpInvalidBody =>
      'The 6-digit code does not match or was already used. Check and try again.';

  @override
  String get otpInvalidShort => 'Invalid OTP.';

  @override
  String get otpCannotResendTitle => 'Cannot send a new code yet';

  @override
  String get otpCannotResendBody =>
      'Wait until the cooldown ends before requesting another OTP.';

  @override
  String get otpResendLabel => 'Send new code';

  @override
  String get otpResendCooldown => 'Resend after';

  @override
  String get otpServerGateHint =>
      '“Send new code” stays disabled until the server allows another send.';

  @override
  String get otpPrivacyNote =>
      'We do not reveal whether an account exists. Attempt limits are enforced by the server.';

  @override
  String get otpFieldLabel => 'Verification code';

  @override
  String get roleHubTitle => 'Role hub';

  @override
  String get roleHubSubtitle => 'One account · Three operating modes';

  @override
  String get roleContinueCustomer => 'Continue as Customer';

  @override
  String get roleContinueMerchant => 'Continue as Shop';

  @override
  String get roleContinueDriver => 'Continue as Driver';

  @override
  String get roleCustomerTitle => 'Customer mode';

  @override
  String get roleCustomerHeadline => 'Book rides, food, and shopping';

  @override
  String get roleCustomerDetail => 'Use DealGo services';

  @override
  String get roleMerchantTitle => 'Shop mode';

  @override
  String get roleMerchantHeadline => 'Manage your store';

  @override
  String get roleMerchantDetail => 'New orders · Menu · Revenue';

  @override
  String get roleDriverTitle => 'Driver mode';

  @override
  String get roleDriverHeadline => 'Accept jobs and earn';

  @override
  String get roleDriverDetail => 'Rides · Food delivery · Earnings';

  @override
  String get roleOnboardingTitle => 'Finish partner onboarding';

  @override
  String get rideTrackContact => 'Message';

  @override
  String get rideTrackRetry => 'Retry';

  @override
  String get ridePickup => 'Pickup';

  @override
  String get rideDropoff => 'Drop-off';

  @override
  String get foodCheckoutContinue => 'Continue to payment';

  @override
  String get homeTagline => 'Go anywhere · Buy everything';

  @override
  String get homeCitySample => 'Da Nang';

  @override
  String get chatTitle => 'Messages';

  @override
  String get chatEmpty => 'No messages yet';

  @override
  String get chatInputHint => 'Type a message';

  @override
  String get chatSend => 'Send';

  @override
  String get chatContact => 'Message';

  @override
  String get voiceCall => 'Voice call';

  @override
  String get voiceTitle => 'In-trip voice call';

  @override
  String get voiceRoomLabel => 'Room';

  @override
  String get voiceStubHint =>
      'LiveKit joins when the server issues a token. Showing the room name for now.';

  @override
  String get bannerOfflineTitle => 'You’re offline';

  @override
  String get bannerEmptyTitle => 'Nothing here';

  @override
  String get commonSelected => 'Selected';

  @override
  String get commonNew => 'New';

  @override
  String get commonCodUnpaid => 'COD · Not collected';

  @override
  String get actionSeeDetail => 'View details →';

  @override
  String get rideOfferDetailTitle => 'Offer & driver details';

  @override
  String get rideDriverLabel => 'Driver';

  @override
  String get rideOfferAmountLabel => 'Driver offer';

  @override
  String get rideYourBidLabel => 'Your bid';

  @override
  String get rideTripInfoTitle => 'Trip';

  @override
  String get rideOfferDetailHint =>
      'Confirming this offer creates the trip. Unselected offers may expire.';

  @override
  String get rideSelectOfferCta => 'Continue with this offer';

  @override
  String get ridePickupCodeTitle => 'Pickup verification code';

  @override
  String get ridePickupCodeChip => 'Show to driver';

  @override
  String get ridePickupCodeHeadline => 'Your pickup code';

  @override
  String get ridePickupCodeBody =>
      'Share this code only when the vehicle and plate match.';

  @override
  String get ridePickupCodeSafetyTitle => 'Keep the code private';

  @override
  String get ridePickupCodeSafetyBody =>
      'Do not send the code in chat before the driver arrives.';

  @override
  String get rideSafetyTitle => 'Safety center';

  @override
  String get rideSafetyBannerTitle => 'Stay safe on this trip';

  @override
  String get rideSafetyBannerBody =>
      'Share your trip and keep emergency contacts handy. Emergency calling uses your phone — DealGo does not fake an SOS backend.';

  @override
  String get rideSafetyShareTitle => 'Share trip';

  @override
  String get rideSafetyShareBody =>
      'Copy a trip link to send to someone you trust.';

  @override
  String get rideSafetyShareCta => 'Copy trip link';

  @override
  String get rideSafetyShareCopied => 'Trip link copied';

  @override
  String get rideSafetyContactsTitle => 'Emergency contacts';

  @override
  String get rideSafetyContactsBody =>
      'Contacts below are stored on this device for demo only.';

  @override
  String get rideSafetyContactLocal => 'Local';

  @override
  String get rideSafetyAddContact => 'Add contact (mock)';

  @override
  String get rideSafetyContactsMockHint =>
      'Contact editing is local mock — not synced to the server.';

  @override
  String get rideSafetyEmergencyTitle => 'Emergency help';

  @override
  String get rideSafetyEmergencyBody =>
      'Use your phone dialer for local emergency numbers. No in-app SOS is claimed here.';

  @override
  String get rideCancelTitle => 'Cancel trip';

  @override
  String get rideCancelPickReason => 'Why are you cancelling?';

  @override
  String get rideCancelPolicyHint =>
      'Cancellation fees or penalties are set by the server when available — this screen does not invent them.';

  @override
  String get rideCancelReasonWait => 'Waiting too long';

  @override
  String get rideCancelReasonPlans => 'Plans changed';

  @override
  String get rideCancelReasonAddress => 'Wrong pickup / drop-off';

  @override
  String get rideCancelReasonDriver => 'Issue with the driver';

  @override
  String get rideCancelReasonOther => 'Other';

  @override
  String get rideCancelConfirm => 'Confirm cancel';

  @override
  String get rideCancelKeep => 'Keep this trip';

  @override
  String get rideCancelSuccess => 'Trip cancelled';

  @override
  String get rideCancelSubmitted => 'Cancel requested';

  @override
  String get rideCancelSoftFail =>
      'Could not reach the server. Your reason was kept locally — try again when online.';

  @override
  String get foodCancelTitle => 'Cancel order';

  @override
  String get foodCancelPickReason => 'Why are you cancelling?';

  @override
  String get foodCancelPolicyHint =>
      'Refund or fee outcomes come from the server. This picker does not invent policies.';

  @override
  String get foodCancelReasonWrong => 'Ordered the wrong items';

  @override
  String get foodCancelReasonWait => 'Waiting too long';

  @override
  String get foodCancelReasonAddress => 'Need a different delivery address';

  @override
  String get foodCancelReasonOther => 'Other';

  @override
  String get foodCancelConfirm => 'Confirm cancel';

  @override
  String get foodCancelKeep => 'Keep this order';

  @override
  String get foodCancelSoftFail =>
      'Cancel is shown locally for now — server cancel will soft-fail until the API is available.';

  @override
  String get driverJobFailedTitle => 'Delivery failed';

  @override
  String get driverJobFailedChip => 'Failed';

  @override
  String get driverJobFailedBody =>
      'Record why the delivery could not be completed. Settlement follows server rules — no client-side fees invented.';

  @override
  String get driverJobFailedPick => 'Outcome';

  @override
  String get driverFailAbsent => 'Customer absent';

  @override
  String get driverFailAddress => 'Wrong address';

  @override
  String get driverFailRefused => 'Refused';

  @override
  String get driverFailOther => 'Other';

  @override
  String get driverJobFailedSubmit => 'Submit outcome';

  @override
  String get driverJobFailedPolicyHint =>
      'This is a UI shell. Nest soft-fails when no failure API is present.';

  @override
  String get driverJobFailedSoftFail =>
      'Outcome saved on device for demo. Server sync will soft-fail without an API.';

  @override
  String get driverOpenCompletedSample => 'Open completed job sample';

  @override
  String get driverJobIdLabel => 'Job';

  @override
  String get driverJobCompletedTitle => 'Completed job';

  @override
  String get driverBackToJobs => 'Back to jobs';

  @override
  String get driverCompletedRouteSample => 'Hai Chau → Airport (sample)';

  @override
  String get driverCompletedTimeSample => 'Completed · today (fixture)';

  @override
  String get driverCompletedEarningsTitle => 'Earnings snapshot';

  @override
  String get driverCompletedFareLabel => 'Accepted fare';

  @override
  String get driverCompletedBonusLabel => 'Bonus';

  @override
  String get driverCompletedEarningsHint =>
      'Amounts are layout fixtures — not live ledger balances.';

  @override
  String get driverCompletedFixtureHint =>
      'Completed detail uses mock data until history APIs are wired.';

  @override
  String get driverJobsHistorySection => 'Job outcomes (demo)';

  @override
  String get driverServicesTitle => 'Choose services';

  @override
  String get driverServicesHeadline => 'Choose services to receive work';

  @override
  String get driverServicesBody =>
      'You can enable each approved work type separately.';

  @override
  String get driverServicesOnlineTitle => 'Online';

  @override
  String get driverServicesOnlineBody => 'Ready to receive new requests';

  @override
  String get driverServicesApprovedSection => 'Approved services';

  @override
  String get driverServicesRideTitle => 'Passenger rides (motorbike)';

  @override
  String get driverServicesRideBody => 'Nearby trips · Flexible pricing';

  @override
  String get driverServicesFoodTitle => 'Food delivery';

  @override
  String get driverServicesFoodBody =>
      'Pick up from Shop and deliver to customer';

  @override
  String get driverServicesApprovedChip => 'Approved';

  @override
  String get driverServicesVehicleSection => 'Active vehicle';

  @override
  String get driverServicesVehicleInUse => 'In use';

  @override
  String get driverServicesAreaSection => 'Request area';

  @override
  String get driverServicesAreaEdit => 'Edit';

  @override
  String get driverServicesAreaFromGps => 'From the driver’s current location';

  @override
  String get driverServicesSave => 'Save configuration';

  @override
  String get driverServicesPolicyHint =>
      'The system only sends jobs that match valid documents, driver status, and vehicle.';

  @override
  String driverServicesCount(int count) {
    return '$count services';
  }

  @override
  String get driverOtpTitle => 'Passenger pickup OTP';

  @override
  String get driverOtpHeadline => 'Verify passenger boarding';

  @override
  String get driverOtpBody =>
      'Enter the 4-digit code from the passenger to start the trip.';

  @override
  String get driverOtpVerifyTitle => 'Passenger verification';

  @override
  String driverOtpValidFor(String rideId) {
    return 'OTP is valid only for trip #$rideId';
  }

  @override
  String get driverOtpWaitingHint =>
      'Waiting to match code · Illustrative display';

  @override
  String get driverOtpWrong =>
      'OTP does not match. Check again with the passenger.';

  @override
  String get driverOtpGuide =>
      'Only start the trip after verifying the passenger and confirmation code.';

  @override
  String get driverOtpPrivacy =>
      'Do not share the pickup OTP in chat or with unrelated people.';

  @override
  String get driverOtpConfirm => 'Confirm and start trip';

  @override
  String get driverOtpWaitingChip => 'WAITING';

  @override
  String get driverActiveNavTitle => 'Navigate to pickup';

  @override
  String get driverActiveArrivedTitle => 'Arrived at pickup';

  @override
  String get driverActiveOnTripTitle => 'Trip in progress';

  @override
  String get driverActiveCompleteTitle => 'End trip';

  @override
  String get driverActiveArrivedCta => 'Arrived at pickup';

  @override
  String get driverActiveOpenOtp => 'Enter passenger OTP';

  @override
  String get driverActiveWaitingBody =>
      'Wait for the passenger. Verify OTP before starting the trip.';

  @override
  String get driverActiveOnTripBody =>
      'In-trip map (mock). Follow the route to the dropoff.';

  @override
  String get driverActiveCompleteCta => 'Complete / collect payment';

  @override
  String get driverActiveCompleteBody =>
      'Collect the server-locked fare. Do not invent surcharges on device.';

  @override
  String get driverActiveReportIssue => 'Report issue';

  @override
  String get driverFoodPhaseNavTitle => 'Navigate to store';

  @override
  String get driverFoodPhaseWaitTitle => 'Waiting at store';

  @override
  String get driverFoodPhasePickupTitle => 'Confirm pickup';

  @override
  String get driverFoodPhaseDeliverTitle => 'Deliver to customer';

  @override
  String get driverFoodPhaseCompleteTitle => 'Delivery confirmed';

  @override
  String get driverFoodArrivedStore => 'Arrived at store';

  @override
  String get driverFoodConfirmPickup => 'Picked up order';

  @override
  String get driverFoodArrivedCustomer => 'Arrived at dropoff';

  @override
  String get driverFoodCompleteDelivery => 'Complete delivery';

  @override
  String get driverFoodWaitBody =>
      'Wait until the Shop finishes. Do not mark pickup before bags are ready.';

  @override
  String get driverFoodPickupBody =>
      'Match bag count and handoff code with the Shop before leaving.';

  @override
  String get driverFoodDeliverBody =>
      'Delivery map (mock). Collect COD using the server order total.';

  @override
  String get driverFoodCompleteBody =>
      'Collecting COD is not driver income. Settlement follows the server.';

  @override
  String get driverFoodIncomePending => 'Per server settlement';

  @override
  String get driverFoodNoClientFee =>
      'Do not compute income/commission on the client — show server amounts only when present.';

  @override
  String get driverFoodCodCollect => 'COD to collect on delivery';

  @override
  String get merchantRejectOrder => 'Reject';

  @override
  String get merchantAcceptOrder => 'Confirm order';

  @override
  String get merchantRejectConfirmTitle => 'Reject this order?';

  @override
  String get merchantRejectConfirmBody =>
      'Device-only reject (mock). Nest reject API is not wired — no server mutation.';

  @override
  String get merchantRejectConfirmCta => 'Confirm reject';

  @override
  String get merchantRejectKeep => 'Keep order';

  @override
  String get merchantRejectDone => 'Reject recorded on device (demo).';

  @override
  String get merchantHomeFinanceTitle => 'Today’s finances';

  @override
  String get merchantHomeGrossFood => 'Food revenue (gross)';

  @override
  String get merchantHomePendingSettle => 'Pending settlement';

  @override
  String get merchantHomeAvailable => 'Available balance';

  @override
  String get merchantHomeFinanceHint =>
      'Revenue is not withdrawable balance; COD and refunds settle separately. Figures are queue layout — not a withdraw ledger.';

  @override
  String get merchantHomeCompletedToday => 'Completed';

  @override
  String get merchantHomeFoodToday => 'Food total on queue';

  @override
  String get merchantOrderItemsTitle => 'Items';

  @override
  String get merchantOrderValueTitle => 'Order value';

  @override
  String get merchantOrderCodTotal => 'COD total';

  @override
  String get merchantOrderFoodRevenue => 'Food revenue';

  @override
  String get merchantOrderDiscount => 'Discount';

  @override
  String get merchantOrderCodNote =>
      'Shop does not keep the full COD: delivery fee belongs to driver/platform; COD is not collected at accept.';

  @override
  String get merchantSettingsShellTitle => 'Shop settings';

  @override
  String get kybIntroBrand => 'DealGo';

  @override
  String get kybIntroPartnerMode => 'Partner mode';

  @override
  String get kycIntroBrand => 'DealGo';

  @override
  String get kycIntroPartnerMode => 'Partner mode';

  @override
  String get merchantSettingsSection => 'Shop settings';

  @override
  String get merchantSettingsMockHint =>
      'Settings on this screen are local mock toggles until Nest shop-config APIs exist.';

  @override
  String get merchantAcceptTitle => 'Order accept mode';

  @override
  String get merchantAcceptModeLabel => 'How new orders are accepted';

  @override
  String get merchantAcceptManual => 'Manual';

  @override
  String get merchantAcceptAuto => 'Auto';

  @override
  String get merchantAcceptManualHint =>
      'You confirm each new order in the queue.';

  @override
  String get merchantAcceptAutoHint =>
      'Eligible new orders can be accepted automatically on this device mock.';

  @override
  String get merchantHoursTitle => 'Hours & closed days';

  @override
  String get merchantHoursOpen => 'Open';

  @override
  String get merchantHoursClosed => 'Closed';

  @override
  String get merchantBusyTitle => 'Busy / pause';

  @override
  String get merchantBusyModeLabel => 'Store availability';

  @override
  String get merchantBusyOpen => 'Open';

  @override
  String get merchantBusyBusy => 'Busy';

  @override
  String get merchantBusyPaused => 'Paused';

  @override
  String get merchantBusyOpenHint =>
      'Customers can place orders normally (mock).';

  @override
  String get merchantBusyBusyHint =>
      'Show busy — new orders may be limited on this device mock.';

  @override
  String get merchantBusyPausedHint =>
      'Temporarily stop accepting orders on this device mock.';

  @override
  String get merchantVariantsTitle => 'Sizes & toppings';

  @override
  String get merchantVariantsCta => 'Edit variants';

  @override
  String get merchantVariantsItem => 'Item';

  @override
  String get merchantVariantsShellChip => 'Editor shell';

  @override
  String get merchantVariantsSizeLabel => 'Size';

  @override
  String get merchantVariantsToppingsLabel => 'Toppings';

  @override
  String get merchantVariantsSave => 'Save locally';

  @override
  String get merchantVariantsSavedLocal => 'Variants saved on device (mock)';

  @override
  String get merchantVariantsPriceHint =>
      'Do not invent topping fees here — prices come from catalog/server when available.';

  @override
  String get merchantSizeS => 'S';

  @override
  String get merchantSizeM => 'M';

  @override
  String get merchantSizeL => 'L';

  @override
  String get merchantToppingEgg => 'Egg';

  @override
  String get merchantToppingCheese => 'Cheese';

  @override
  String get merchantToppingSpice => 'Extra spice';

  @override
  String get dayMon => 'Monday';

  @override
  String get dayTue => 'Tuesday';

  @override
  String get dayWed => 'Wednesday';

  @override
  String get dayThu => 'Thursday';

  @override
  String get dayFri => 'Friday';

  @override
  String get daySat => 'Saturday';

  @override
  String get daySun => 'Sunday';

  @override
  String get rideRouteOverviewTitle => 'Check your route';

  @override
  String get rideRouteOverviewSubtitle => 'Estimated path before booking';

  @override
  String get rideRouteOverviewMapBadge => '4.8 km · ~12 min';

  @override
  String get rideRouteSwapTooltip => 'Swap pickup and dropoff';

  @override
  String get rideRouteInService => 'In service area';

  @override
  String get rideRouteDistance => 'Distance';

  @override
  String get rideRouteDistanceSample => '4.8 km';

  @override
  String get rideRouteDuration => 'Time';

  @override
  String get rideRouteDurationSample => '~12 min';

  @override
  String get rideRouteRefPrice => 'Ref. price';

  @override
  String get rideRoutePriceHint =>
      'Official price appears when you choose a vehicle.';

  @override
  String get rideRouteContinueVehicle => 'Continue to vehicles';

  @override
  String get rideFareBreakdownTitle => 'Fare details';

  @override
  String get rideFareEstimatedFee => 'Estimated fee';

  @override
  String get rideFareVersionChip => 'Quote v1';

  @override
  String get rideFareComponentsTitle => 'Fare components';

  @override
  String get rideFareBase => 'Base fare';

  @override
  String get rideFareDistance => 'Distance fare';

  @override
  String get rideFareSurcharge => 'Included surcharges';

  @override
  String get rideFareDiscount => 'Promotion';

  @override
  String get rideFareProposedTotal => 'Proposed total';

  @override
  String get rideFareTripInfoTitle => 'Trip information';

  @override
  String get rideFareBreakdownNote =>
      'The fare is locked to the quote you confirm. Later surcharges need notice and your consent.';

  @override
  String get rideFareProposeCta => 'Propose trip fare';

  @override
  String get rideTrackingEtaChip => 'Driver about 4 min away';

  @override
  String get rideTrackingMovingChip => 'Heading to pickup';

  @override
  String get rideTrackingInProgressTitle => 'Trip in progress';

  @override
  String get rideTrackingProgressSample => 'Traveled 3.1 / 5.2 km (fixture)';

  @override
  String get rideTrackingRunningChip => 'Running';

  @override
  String get rideShareTrip => 'Share trip';

  @override
  String get foodSearchTitle => 'Find dishes & stores';

  @override
  String get foodSearchHint => 'bun bo';

  @override
  String get foodSearchFilterAll => 'All';

  @override
  String get foodSearchFilterStores => 'Restaurants';

  @override
  String get foodSearchFilterDishes => 'Dishes';

  @override
  String get foodSearchFilterNear => 'Near me';

  @override
  String get foodSearchSuggestions => 'Search suggestions';

  @override
  String get foodSearchSuggestionsHint => 'Results matching your keyword';

  @override
  String get foodSearchEmpty => 'No matching stores yet';

  @override
  String get foodSearchHistory => 'Search history';

  @override
  String get foodSearchClearHistory => 'Clear all';

  @override
  String get foodSearchPopular => 'Popular keywords';

  @override
  String get foodCategoryTitle => 'Restaurants & categories';

  @override
  String get foodCategorySearchPlaceholder => 'Food in Da Nang';

  @override
  String get foodCategorySortNear => 'Nearest';

  @override
  String get foodCategorySortRating => 'Top rated';

  @override
  String get foodCategorySortFreeship => 'Free shipping';

  @override
  String get foodCategoryFilter => 'Filter';

  @override
  String get foodCategoryAroundYou => 'Restaurants around you';

  @override
  String foodCategoryAroundHint(int count) {
    return '$count stores · Deliver to Hai Chau';
  }

  @override
  String get foodCategoryVietnamese => 'Vietnamese';

  @override
  String get foodFreeshipChip => 'Freeship 0đ';

  @override
  String get foodItemOptionsTitle => 'Item options';

  @override
  String get foodItemOptionsRating => '★ 4.8 (320 reviews) · Sold 2.4k';

  @override
  String get foodItemOptionsDescription =>
      'Hue-style beef noodle with soft beef, crab cake, herbs, and hot broth.';

  @override
  String get foodItemOptionsNoGroups => 'No options for this item.';

  @override
  String get foodItemOptionsTotal => 'Total';

  @override
  String get foodItemOptionsAdd => 'Add to cart';

  @override
  String get foodItemOptionsRequired => 'Required';

  @override
  String get foodItemOptionsOptional => 'Optional';

  @override
  String get foodInvoiceTitle => 'Order receipt';

  @override
  String get foodInvoiceDelivered => 'Delivered successfully';

  @override
  String get foodInvoiceOrderId => 'Order';

  @override
  String get foodInvoiceSyncChip => 'v1 · Synced';

  @override
  String get foodInvoiceDeliveredChip => 'DELIVERED';

  @override
  String get foodInvoiceStore => 'Store';

  @override
  String get foodInvoiceRecipient => 'Recipient';

  @override
  String get foodInvoiceRecipientSample => 'Tran Thi Mai';

  @override
  String get foodInvoiceItemsTitle => 'Items received';

  @override
  String get foodInvoiceItemsEmpty => 'No line items on this order yet.';

  @override
  String get foodInvoiceReceiptTitle => 'Receipt';

  @override
  String get foodInvoiceSubtotal => 'Items';

  @override
  String get foodInvoiceDelivery => 'Delivery fee';

  @override
  String get foodInvoiceDiscount => 'Discount';

  @override
  String get foodInvoiceCodTotal => 'COD total';

  @override
  String get foodInvoiceMethod => 'Method';

  @override
  String get foodInvoiceMethodCollected => 'COD · Collected';

  @override
  String foodInvoiceCodNote(String amount) {
    return 'COD $amount is collected by the driver and recorded once on successful delivery.';
  }

  @override
  String get foodInvoiceRateCta => 'Rate order';

  @override
  String get foodTrackingStatusTitle => 'Live status';

  @override
  String get foodTrackingSyncChip => 'v1 · Synced';

  @override
  String get foodTrackingMapChip => 'Order is being delivered';

  @override
  String get foodTrackingMapCity => 'Da Nang · Simulation';

  @override
  String get foodTrackingDriverTitle => 'Driver delivering';

  @override
  String get foodTrackingDriverSample => 'Tran Minh Anh';

  @override
  String get foodTrackingDriverMeta => 'Honda Vision · bike · 43H1-123.45';

  @override
  String get foodTrackingVerified => 'Verified';

  @override
  String get foodTrackingEtaLabel => 'ETA (fixture)';

  @override
  String get foodTrackingEtaSample => '~8 min';

  @override
  String get foodTrackingPayOnDelivery => 'Pay on delivery';

  @override
  String get foodTrackingCodDue => 'COD due';

  @override
  String get foodTrackingCodHint => 'Not collected until delivery succeeds.';

  @override
  String get paymentHistoryTitle => 'Payment history';

  @override
  String get paymentHistoryMonthTotal => 'Total paid this month';

  @override
  String get paymentHistoryMonthMeta => 'October 2026 · 12 transactions';

  @override
  String get paymentHistoryTestOnly => 'TEST_ONLY fixture';

  @override
  String get paymentHistoryFilterAll => 'All';

  @override
  String get paymentHistoryFilterPaid => 'Paid';

  @override
  String get paymentHistoryFilterRefund => 'Refund';

  @override
  String get paymentHistoryRecent => 'Recent transactions';

  @override
  String get paymentHistoryMonthPicker => 'October ▼';

  @override
  String get paymentHistoryTodayGroup => 'TODAY, 11/10';

  @override
  String get paymentHistoryFoodSample => 'Order Bun Bo Hue O Co';

  @override
  String get paymentHistoryFoodMeta => '10:32 · DealGo Wallet · #DG123456';

  @override
  String get paymentHistoryRideSample => 'Airport ride';

  @override
  String get paymentHistoryRideMeta => '09:15 · COD · #Q-CAR-0007';

  @override
  String get paymentHistoryRefundSample => 'Refund · cancelled order';

  @override
  String get paymentHistoryRefundMeta => '08:40 · Wallet · #RF-001';

  @override
  String get paymentHistoryNote =>
      'Each transaction has a reconciliation code and receipt so you can review payments or refunds.';
}

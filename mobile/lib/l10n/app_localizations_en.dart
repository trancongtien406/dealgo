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
  String get actionBack => 'Back';

  @override
  String get actionChangePhone => 'Change phone number';

  @override
  String get actionKeepEnteringCode => 'Keep entering code';

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
  String get emptyStoresNearby => 'No stores nearby yet';

  @override
  String get emptyOffers => 'No driver offers yet';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get tabHome => 'Home';

  @override
  String get tabTrips => 'Trips';

  @override
  String get tabBook => 'Book';

  @override
  String get tabShop => 'Shop';

  @override
  String get tabAccount => 'Me';

  @override
  String get tabOverview => 'Overview';

  @override
  String get tabOrders => 'Orders';

  @override
  String get tabProducts => 'Menu';

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
  String get authPhoneLabel => 'Phone number';

  @override
  String get authTermsAnd => ' and ';

  @override
  String get authPrivacyPolicy => 'Privacy Policy';

  @override
  String get otpHeading => 'Verify phone number';

  @override
  String get otpSending => 'Sending';

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
      'You can request a new code once the timer ends.';

  @override
  String get otpPrivacyNote => 'For your security, wrong attempts are limited.';

  @override
  String get otpFieldLabel => 'Verification code';

  @override
  String get actionChangeEmail => 'Change email';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get otpEmailHeadingPrefix => 'Verify ';

  @override
  String get otpEmailHeadingAccent => 'email';

  @override
  String get otpEmailBodyPrefix => 'Enter the 6-digit code sent to ';

  @override
  String get emailErrorNotVerified =>
      'This email is not verified yet. Sign in again to get a verification code, or reset your password by email.';

  @override
  String get emailErrorTooManyAttempts =>
      'Too many attempts. Please try again later.';

  @override
  String get emailErrorDeliveryFailed =>
      'We could not send the verification email. Please try again later.';

  @override
  String get otpEmailLockedBody =>
      'Too many incorrect codes. Go back and start again to get a new code.';

  @override
  String get ridePickup => 'Pickup';

  @override
  String get rideDropoff => 'Drop-off';

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
  String get chatContact => 'Message';

  @override
  String get voiceCall => 'Voice call';

  @override
  String get voiceTitle => 'In-trip voice call';

  @override
  String get voiceRoomLabel => 'Room';

  @override
  String get voiceStubHint => 'In-app calling is coming soon.';

  @override
  String get bannerOfflineTitle => 'You’re offline';

  @override
  String get commonSelected => 'Selected';

  @override
  String get actionSeeDetail => 'View details →';

  @override
  String get rideOfferDetailTitle => 'Offer & driver details';

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
      'Share your trip and save emergency contacts. In an emergency, call 113/115 directly from your phone.';

  @override
  String get rideSafetyShareTitle => 'Share trip';

  @override
  String get rideSafetyShareBody =>
      'Send a trip-tracking link to family. It only shows the trip status, the driver\'s masked name and plate, and expires after 12 hours or 30 minutes after the trip ends.';

  @override
  String get rideSafetyShareCta => 'Copy trip link';

  @override
  String get rideSafetyShareCopied => 'Trip link copied';

  @override
  String get rideSafetyContactsTitle => 'Emergency contacts';

  @override
  String get rideSafetyContactsBody =>
      'Emergency contacts are saved on this device.';

  @override
  String get rideSafetyAddContact => 'Add contact';

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
      'Cancellation fees, if any, follow DealGo policy.';

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
      'Couldn\'t connect. Please try again when you\'re online.';

  @override
  String get foodCancelTitle => 'Cancel order';

  @override
  String get foodCancelPickReason => 'Why are you cancelling?';

  @override
  String get foodCancelPolicyHint =>
      'You can cancel only before the shop accepts the order. Refunds, if any, follow DealGo policy.';

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
  String get driverJobFailedTitle => 'Delivery failed';

  @override
  String get driverJobFailedChip => 'Failed';

  @override
  String get driverJobFailedBody =>
      'Tell us why this job couldn\'t be completed.';

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
      'DealGo will review and settle according to driver policy.';

  @override
  String get driverJobFailedSoftFail => 'Reason saved on this device.';

  @override
  String get driverOpenCompletedSample => 'View trip details';

  @override
  String get driverJobIdLabel => 'Job';

  @override
  String get driverJobCompletedTitle => 'Completed job';

  @override
  String get driverBackToJobs => 'Back to jobs';

  @override
  String get driverCompletedEarningsTitle => 'Earnings for this job';

  @override
  String get driverCompletedFareLabel => 'Accepted fare';

  @override
  String get driverCompletedEarningsHint =>
      'The platform fee is fixed when the job completes.';

  @override
  String get driverJobsHistorySection => 'Job outcomes';

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
  String get driverOtpWaitingHint => 'Ask the customer for their pickup code';

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
      'Follow the route to the destination and drive safely.';

  @override
  String get driverActiveCompleteCta => 'Complete / collect payment';

  @override
  String get driverActiveCompleteBody =>
      'Collect the fare agreed with the customer.';

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
      'Hand the order to the customer and collect COD for the order total.';

  @override
  String get driverFoodCompleteBody =>
      'COD is collected on behalf of the shop and settled with DealGo.';

  @override
  String get driverFoodIncomePending => 'Updated after settlement';

  @override
  String get driverFoodNoClientFee => 'Your net income shows after settlement.';

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
      'Are you sure you want to reject this order?';

  @override
  String get merchantRejectConfirmCta => 'Confirm reject';

  @override
  String get merchantRejectKeep => 'Keep order';

  @override
  String get merchantRejectDone =>
      'Order declined. The customer is notified it was cancelled.';

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
      'Sales are the food subtotal of orders delivered today (Vietnam time). Withdrawable balance comes from settlement and isn\'t shown in the app yet.';

  @override
  String get merchantHomeCompletedToday => 'Completed today';

  @override
  String get merchantHomeFoodToday => 'Food sales today';

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
  String get merchantSettingsMockHint =>
      'These settings are saved on this device only for now.';

  @override
  String get merchantAcceptTitle => 'Order acceptance';

  @override
  String get merchantAcceptModeLabel => 'Order confirmation mode';

  @override
  String get merchantAcceptManual => 'Manual';

  @override
  String get merchantAcceptAuto => 'Automatic when eligible';

  @override
  String get merchantAcceptManualHint =>
      'The shop reviews and accepts each order.';

  @override
  String get merchantAcceptAutoHint =>
      'Orders are accepted only while open and under capacity.';

  @override
  String get merchantHoursTitle => 'Hours & days off';

  @override
  String get merchantHoursOpen => 'Open';

  @override
  String get merchantHoursClosed => 'Off';

  @override
  String get merchantBusyTitle => 'Busy & pause mode';

  @override
  String get merchantBusyModeLabel => 'Service mode';

  @override
  String get merchantBusyOpen => 'Operating normally';

  @override
  String get merchantBusyBusy => 'Kitchen busy';

  @override
  String get merchantBusyPaused => 'Pause new orders';

  @override
  String get merchantBusyOpenHint => 'Take orders during opening hours.';

  @override
  String get merchantBusyBusyHint =>
      'Still taking orders; customers see the kitchen is busy.';

  @override
  String get merchantBusyPausedHint =>
      'No new orders; existing orders continue.';

  @override
  String get merchantVariantsTitle => 'Size, variants & toppings';

  @override
  String get merchantVariantsCta => 'Edit variants';

  @override
  String get merchantVariantsSave => 'Save options';

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
  String get rideRouteSwapTooltip => 'Swap pickup and dropoff';

  @override
  String get rideRouteDistance => 'Distance';

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
  String get rideFareComponentsTitle => 'Fare components';

  @override
  String get rideFareTripInfoTitle => 'Trip information';

  @override
  String get rideFareBreakdownNote =>
      'The fare is locked to the quote you confirm. Later surcharges need notice and your consent.';

  @override
  String get rideFareProposeCta => 'Propose trip fare';

  @override
  String get rideShareTrip => 'Share trip';

  @override
  String get foodSearchTitle => 'Find dishes & stores';

  @override
  String get foodSearchHint => 'bun bo';

  @override
  String get foodSearchFilterAll => 'All';

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
  String get foodCategoryTitle => 'Restaurants & categories';

  @override
  String get foodCategorySortNear => 'Nearest';

  @override
  String get foodCategorySortRating => 'Top rated';

  @override
  String get foodCategoryAroundYou => 'Restaurants around you';

  @override
  String foodCategoryAroundHint(int count) {
    return '$count stores';
  }

  @override
  String get foodItemOptionsTitle => 'Item options';

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
  String get foodInvoiceCodTotal => 'Total paid';

  @override
  String get foodInvoiceMethod => 'Method';

  @override
  String get foodInvoiceMethodCollected => 'Cash · Paid';

  @override
  String foodInvoiceCodNote(String amount) {
    return 'You paid $amount in cash to the driver on delivery.';
  }

  @override
  String get foodInvoiceRateCta => 'Rate order';

  @override
  String get foodTrackingStatusTitle => 'Live status';

  @override
  String get foodTrackingMapChip => 'Order is being delivered';

  @override
  String get foodTrackingDriverTitle => 'Driver delivering';

  @override
  String get foodTrackingPayOnDelivery => 'Pay on delivery';

  @override
  String get foodTrackingCodDue => 'Due on delivery';

  @override
  String get foodTrackingCodHint => 'Not collected until delivery succeeds.';

  @override
  String get paymentHistoryTitle => 'Payment history';

  @override
  String get paymentHistoryFilterAll => 'All';

  @override
  String get paymentHistoryRecent => 'Recent transactions';

  @override
  String get paymentHistoryNote =>
      'Each row is a completed ride or delivered food order, paid in cash on delivery.';

  @override
  String get stateErrorTitle => 'Something went wrong';

  @override
  String get stateErrorBody =>
      'We couldn\'t load this right now. Please try again.';

  @override
  String get fieldShowPassword => 'Show password';

  @override
  String get fieldHidePassword => 'Hide password';

  @override
  String get authHelp => 'Help';

  @override
  String get authHelpHotline => 'DealGo help center: 1900 6868';

  @override
  String get authLegalPrefix => 'By continuing, you agree to the ';

  @override
  String get authLegalTerms => 'Terms';

  @override
  String get authTermsSoon => 'DealGo Terms of Service are coming soon.';

  @override
  String get authPrivacySoon => 'DealGo Privacy Policy is coming soon.';

  @override
  String get authWelcomeTo => 'Welcome to';

  @override
  String get authMethodPasskey => 'Passkey';

  @override
  String get authMethodsEmptyTitle =>
      'No sign-in method is available right now.';

  @override
  String get authMethodsEmptyBody => 'Please try again later or contact Help.';

  @override
  String get authPhoneTitle => 'Sign in with phone number';

  @override
  String get authPhoneOtpNote => 'We\'ll send an OTP to verify it.';

  @override
  String get authPhoneRequired => 'Please enter your phone number';

  @override
  String get authPhoneInvalid => 'Invalid phone number (9 to 11 digits)';

  @override
  String get authOtherMethods => 'Use another sign-in method';

  @override
  String get emailErrRequired => 'Please enter your email address';

  @override
  String get emailErrInvalid => 'Invalid email address';

  @override
  String get passwordErrRequired => 'Please enter your password';

  @override
  String get passwordErrTooShort => 'Password must be at least 8 characters';

  @override
  String get passwordErrConfirm => 'Please confirm your password';

  @override
  String get passwordErrMismatch => 'Passwords do not match';

  @override
  String get emailErrWrongCredentials => 'Incorrect email or password';

  @override
  String get emailErrInUse => 'This email is already registered';

  @override
  String get emailLoginTitle => 'Sign in with Email';

  @override
  String get emailRegisterTitle => 'Sign up with Email';

  @override
  String get emailLoginSubtitle =>
      'Use the email and password you registered with.';

  @override
  String get emailRegisterSubtitle =>
      'Create a DealGo account with email and password.';

  @override
  String get emailFieldPassword => 'Password';

  @override
  String get emailFieldConfirmPassword => 'Confirm password';

  @override
  String get emailFieldDisplayName => 'Display name (optional)';

  @override
  String get emailTabLogin => 'Sign in';

  @override
  String get emailTabRegister => 'Sign up';

  @override
  String otpSeconds(int count) {
    return '${count}s';
  }

  @override
  String get otpChangePhone => 'Change number';

  @override
  String get otpPhoneHeadingPrefix => 'Verify ';

  @override
  String get otpPhoneHeadingAccent => 'phone number';

  @override
  String get otpResendIn => 'Resend code in';

  @override
  String get otpShieldNote => 'The OTP keeps your account safe.';

  @override
  String get otpConfirm => 'Confirm';

  @override
  String get passkeyErrMissing => 'Enter a phone number or email';

  @override
  String get passkeyErrBoth => 'Use only one: phone or email';

  @override
  String get passkeyTitle => 'Sign in with Passkey';

  @override
  String get passkeyBody =>
      'Enter the phone number or email linked to your passkey.';

  @override
  String get passkeyOr => 'or';

  @override
  String get passkeyContinue => 'Continue with Passkey';

  @override
  String get passkeySignIn => 'Sign in with Passkey';

  @override
  String get passkeySignUp => 'Create account with Passkey';

  @override
  String get splashTagline => 'Go anywhere · Eat everything';

  @override
  String get splashPreparing => 'Getting things ready for you...';

  @override
  String get serviceRideTitle => 'Ride';

  @override
  String get serviceRideBlurb => 'Go anywhere\nsafe and easy';

  @override
  String get serviceFoodTitle => 'Food';

  @override
  String get serviceFoodBlurb => 'Thousands of dishes\nevery day';

  @override
  String get onbSlide1Title => 'One app,\n';

  @override
  String get onbSlide1Accent => 'endless experiences';

  @override
  String get onbSlide1Body =>
      'Rides, great food and daily shopping — all in DealGo.';

  @override
  String get onbSlide2Title => 'Move fast,\n';

  @override
  String get onbSlide2Accent => 'safe & affordable';

  @override
  String get onbSlide2Body =>
      'Local drivers pick you up, live trip tracking, transparent fares and the freedom to negotiate.';

  @override
  String get onbSlide2Pill1Title => 'Bikes & cars';

  @override
  String get onbSlide2Pill1Body => 'Pickup in\nas little as 3 min';

  @override
  String get onbSlide2Pill2Title => 'Negotiated fares';

  @override
  String get onbSlide2Pill2Body => 'Lock in a price\nyou like';

  @override
  String get onbSlide3Title => 'Hot, tasty food,\n';

  @override
  String get onbSlide3Accent => 'delivered fast';

  @override
  String get onbSlide3Body =>
      'Thousands of authentic Da Nang eateries ready to serve. Order easily, delivered in about 20 minutes.';

  @override
  String get onbSlide3Pill1Title => 'Local specialties';

  @override
  String get onbSlide3Pill1Body =>
      'Mi Quang, fish cake noodles,\ncrispy banh mi';

  @override
  String get onbSlide3Pill2Title => '20\' express delivery';

  @override
  String get onbSlide3Pill2Body => 'Always arrives\npiping hot';

  @override
  String get onbSkip => 'Skip';

  @override
  String get onbStart => 'Get started';

  @override
  String get profileSetupTitle => 'Complete your profile';

  @override
  String get profileSetupHeadline => 'Just one more step!';

  @override
  String get profileSetupLead =>
      'Complete your details to get the most out of ';

  @override
  String get profileAvatarOptional => 'Profile photo (optional)';

  @override
  String get profileFullName => 'Full name';

  @override
  String get profileBirthdayOptional => 'Date of birth (optional)';

  @override
  String get profileGender => 'Gender';

  @override
  String get profileGenderMale => 'Male';

  @override
  String get profileGenderFemale => 'Female';

  @override
  String get profileGenderOther => 'Other';

  @override
  String get profilePersonalizeNote =>
      'This helps personalise your experience on ';

  @override
  String get profileDone => 'Done';

  @override
  String get profileLater => 'Add later';

  @override
  String get permTitlePrefix => 'Allow ';

  @override
  String get permTitleAccent => 'access';

  @override
  String get permSubtitle =>
      'Turn on the permissions DealGo needs to work smoothly.';

  @override
  String get permLocation => 'Location';

  @override
  String get permLocationBody => 'Find rides, food and shops near you';

  @override
  String get permNotifications => 'Notifications';

  @override
  String get permNotificationsBody => 'Get trip, order and deal updates';

  @override
  String get permMic => 'Microphone / Calls';

  @override
  String get permMicBody => 'Contact your driver or shop when needed';

  @override
  String get permAllowAll => 'Allow all';

  @override
  String get permLater => 'Set up later';

  @override
  String get permFootnote =>
      'You can change these anytime in the app Settings.';

  @override
  String get permGranted => 'On';

  @override
  String get permAllow => 'Allow';

  @override
  String get rolePickerPrefix => 'How do you want to use ';

  @override
  String get rolePickerSuffix => '?';

  @override
  String get rolePickerSubtitle => 'You can switch roles anytime.';

  @override
  String get rolePickerPartnerSection => 'Complete partner profile';

  @override
  String get rolePickerLearnMore => 'Learn more';

  @override
  String get actionGotIt => 'Got it';

  @override
  String get rolePickerInfoTitle => 'Three roles, one app';

  @override
  String get roleCustomer => 'Customer';

  @override
  String get roleCustomerBody => 'Rides, food and daily shopping';

  @override
  String get roleMerchant => 'Shop';

  @override
  String get roleMerchantBody => 'Manage menus, take orders, track revenue';

  @override
  String get roleDriver => 'Driver';

  @override
  String get roleDriverBody => 'Take rides, deliver food, earn more';

  @override
  String get rolePartnerDriver => 'Become a driver partner';

  @override
  String get rolePartnerShop => 'Become a shop partner';

  @override
  String get rolePartnerPending => 'Application under review';

  @override
  String get rolePartnerRejected => 'Application needs more information';

  @override
  String get rolePartnerStart => 'Complete your profile to activate this role';

  @override
  String onbStep(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get rolePickerHelpBody =>
      'Pick a role to get started. You can switch later in Account.';

  @override
  String get rolePickerInfoBody =>
      'DealGo serves Customers, Shops and Drivers on one account. Switching roles only changes the interface — active orders and trips stay as they are.';

  @override
  String get driverActionFailed =>
      'Couldn\'t update the status. Please try again.';

  @override
  String get driverActionConflict =>
      'The status changed on the server. Go back to your jobs to refresh.';

  @override
  String get driverAgreedFare => 'Agreed fare';

  @override
  String get driverCollect => 'Collect';

  @override
  String get driverCollectBody => 'Using the customer\'s chosen payment method';

  @override
  String get driverPhasePickup => 'Picking up';

  @override
  String get driverPhaseWaiting => 'Waiting';

  @override
  String get driverPhaseOnTrip => 'On trip';

  @override
  String get driverPhaseDone => 'Done';

  @override
  String driverItemsCount(int count) {
    return '$count items';
  }

  @override
  String driverCodNote(String amount) {
    return 'The $amount COD is collected on behalf of the shop, not personal income.';
  }

  @override
  String get actionSkip => 'Skip';

  @override
  String get driverClaimJob => 'Accept job';

  @override
  String get driverClaimFailed => 'Couldn\'t accept the job. Please try again.';

  @override
  String get driverFoodRequestTitle => 'Delivery request';

  @override
  String get driverJobInfo => 'Job details';

  @override
  String get driverPickupStore => 'DealGo partner store';

  @override
  String get driverDeliveryStops => 'Pickup and drop-off';

  @override
  String get driverPickupPoint => 'Pickup';

  @override
  String get driverDropoffPoint => 'Deliver to customer';

  @override
  String get driverFinance => 'Payment details';

  @override
  String get driverFoodSubtotal => 'Food subtotal';

  @override
  String get driverFoodDeliveryFee => 'Delivery fee';

  @override
  String get driverFoodFeeCustomerPays => 'Delivery fee paid by customer';

  @override
  String get driverFoodExpectedIncome => 'Expected driver income';

  @override
  String get driverDeliveredTitle => 'Delivered';

  @override
  String get driverHeadToStore => 'Head to the store';

  @override
  String get driverHeadToCustomer => 'Head to drop-off';

  @override
  String get driverFoodNavigateBody =>
      'Go to the store and confirm when you arrive.';

  @override
  String get driverFoodPhaseWait => 'Waiting for food';

  @override
  String get driverFoodPhasePicked => 'Picked up';

  @override
  String get driverFoodPhaseDelivering => 'Delivering';

  @override
  String get driverNearbyRequests => 'Nearby requests';

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get driverFindOtherJobs => 'Find other jobs';

  @override
  String get driverJobTakenTitle => 'Request already taken';

  @override
  String get driverJobTakenBody =>
      'This request went to another driver or its hold time expired.';

  @override
  String get driverJobUnavailable => 'Request no longer available';

  @override
  String get driverRequestId => 'Request ID';

  @override
  String get driverService => 'Service';

  @override
  String get driverServiceFood => 'Food delivery';

  @override
  String get driverJobTakenHint => 'Refresh the list to see other requests.';

  @override
  String get driverOtpMatched => 'Code matches — starting the trip.';

  @override
  String get driverHeadToPickup => 'Head to pickup';

  @override
  String get driverFollowRoute => 'Follow the route to the destination';

  @override
  String get driverPassenger => 'Customer';

  @override
  String get driverPickupLabel => 'Pickup';

  @override
  String get driverDropoffLabel => 'Destination';

  @override
  String get driverRideNavigateNote =>
      'Open your phone\'s maps app to navigate; DealGo keeps the customer updated.';

  @override
  String get driverCallCustomer => 'Call customer';

  @override
  String get driverChatCustomer => 'Message customer';

  @override
  String get rideTrackTitle => 'Track your driver';

  @override
  String get rideTrackAssigned => 'Driver is on the way';

  @override
  String get rideTrackArrived => 'Driver has arrived';

  @override
  String get rideTrackInTrip => 'On your trip';

  @override
  String get rideTrackCompleted => 'Trip completed';

  @override
  String get rideTrackNegotiating => 'Waiting for a driver';

  @override
  String get rideTrackExpired => 'Ride expired';

  @override
  String get rideTrackCancelled => 'Ride cancelled';

  @override
  String get rideTrackDriverFallback => 'DealGo driver';

  @override
  String get foodCancelNotAllowed =>
      'The shop has already accepted this order, so it can\'t be cancelled. Please contact the shop.';

  @override
  String get foodCancelFailed =>
      'Couldn\'t cancel the order. Please try again.';

  @override
  String get foodCancelDone => 'Order cancelled.';

  @override
  String voucherValid(String code, String amount) {
    return '$code is valid · $amount off';
  }

  @override
  String get voucherLabel => 'Promo code';

  @override
  String get voucherHint => 'Enter a promo code';

  @override
  String get voucherApply => 'Apply';

  @override
  String get voucherRemove => 'Remove code';

  @override
  String get voucherErrEmpty => 'Please enter a promo code';

  @override
  String get voucherErrInvalid => 'This promo code isn\'t valid';

  @override
  String get voucherErrFailed => 'Couldn\'t check the code. Please try again.';

  @override
  String get voucherPreviewNote =>
      'The discount is confirmed again when you place the order and taken off the amount due.';

  @override
  String get driverOfflineNote =>
      'You\'re offline. Go online to start receiving jobs.';

  @override
  String get driverNoShiftHistory => 'No shift history yet.';

  @override
  String get vouchersEmptyTitle => 'No vouchers yet';

  @override
  String get vouchersEmptyBody =>
      'No offers for you right now. New DealGo campaigns will show up here.';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountNotifications => 'Notifications';

  @override
  String get accountVouchers => 'My vouchers';

  @override
  String get accountVouchersBody => 'Your available promo codes';

  @override
  String get accountSectionServices => 'Account & services';

  @override
  String get accountActivity => 'My activity';

  @override
  String get accountActivityBody => 'Trips and orders';

  @override
  String get accountAddresses => 'Saved addresses';

  @override
  String get accountAddressesBody => 'Home, work and other places';

  @override
  String get accountPayments => 'Payment history';

  @override
  String get accountPaymentsBody => 'Receipts and refunds';

  @override
  String get accountRoles => 'Role center';

  @override
  String get accountSwitchRole => 'Switch role';

  @override
  String get accountAcceptMode => 'Auto / manual accept';

  @override
  String get accountAcceptModeBody => 'Choose how new orders are accepted';

  @override
  String get accountHours => 'Opening hours';

  @override
  String get accountHoursBody => 'Open and closed schedule';

  @override
  String get accountBusy => 'Busy mode';

  @override
  String get accountBusyBody => 'Pause new orders';

  @override
  String get accountSectionHelp => 'Help & settings';

  @override
  String get accountSupport => 'Help center';

  @override
  String get accountSupportBody => 'FAQs and complaints';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountDriverPartner => 'Driver partner profile';

  @override
  String get accountShopPartner => 'Shop partner profile';

  @override
  String get partnerStatusDraft => 'Not submitted';

  @override
  String get partnerStatusPending => 'Under review';

  @override
  String get partnerStatusRejected => 'Needs more information';

  @override
  String get partnerStatusActive => 'Active';

  @override
  String get partnerActionRegister => 'Register';

  @override
  String get partnerActionTrack => 'Track';

  @override
  String get partnerActionUpdate => 'Update';

  @override
  String get partnerActionView => 'View';

  @override
  String get accountRoleShop => 'Shop';

  @override
  String get activityEmptyTitle => 'No activity yet';

  @override
  String get activityEmptyBody => 'Your trips and orders will show up here.';

  @override
  String get activityRecent => 'Recent';

  @override
  String get activityOfflineBody => 'Your activity history may be out of date.';

  @override
  String get statusExpired => 'Expired';

  @override
  String get statusFailed => 'Failed';

  @override
  String get statusRejected => 'Rejected';

  @override
  String get statusInProgress => 'In progress';

  @override
  String get emptyStoresNearbyBody =>
      'DealGo is expanding its service area. Please check back soon.';

  @override
  String get notificationsEmptyTitle => 'No notifications yet';

  @override
  String get notificationsEmptyBody =>
      'Updates about your trips, orders and deals will show up here.';

  @override
  String get helpAnswersNote =>
      'Can\'t find an answer? Send a support request and DealGo will reply right in the app.';

  @override
  String get helpNoResults => 'No articles match this keyword.';

  @override
  String get driverOpenRequests => 'Open requests';

  @override
  String get driverOfflineTitle => 'You are offline';

  @override
  String get driverJobsOfflineBody => 'Go online to see requests near you.';

  @override
  String get checkoutVoucherRejected =>
      'This voucher can no longer be used for this order. Remove it or try another code.';

  @override
  String get checkoutErrOrderOpen =>
      'You already have a food order in progress.';

  @override
  String get checkoutErrItemUnavailable =>
      'An item just sold out. Please review the menu.';

  @override
  String get checkoutErrFareRange =>
      'The delivery fee is outside the allowed range.';

  @override
  String get checkoutErrStoreNotFound => 'Store not found.';

  @override
  String get checkoutErrGeneric =>
      'Couldn\'t send the order. Your cart is still on this device.';

  @override
  String get checkoutMenuChangedEmpty =>
      'The menu changed and none of your items are left.';

  @override
  String get checkoutTitleSubmitting => 'Confirming order';

  @override
  String get checkoutTitleOffline => 'Order payment';

  @override
  String get checkoutTitleRepriced => 'Review your cart again';

  @override
  String get checkoutTitle => 'Food checkout';

  @override
  String get checkoutBackToCart => 'Back to cart';

  @override
  String get checkoutRetry => 'Try again';

  @override
  String get checkoutBackToCartShort => 'Back to cart';

  @override
  String get checkoutRecipient => 'Recipient';

  @override
  String get checkoutRecipientAddress => 'Recipient and address';

  @override
  String get checkoutItems => 'Items';

  @override
  String get checkoutTotalSection => 'Payment summary';

  @override
  String get checkoutSubtotal => 'Items';

  @override
  String get checkoutDeliveryFee => 'Delivery fee';

  @override
  String get checkoutDiscount => 'Discount';

  @override
  String get checkoutCodTotal => 'Total due';

  @override
  String get checkoutPayment => 'Payment';

  @override
  String get checkoutCodUncollected => 'Cash · Not paid yet';

  @override
  String get checkoutPlacedNote =>
      'Your order is in. You pay in cash on delivery.';

  @override
  String get checkoutPayLaterNote =>
      'Payment is collected on delivery, not at this step.';

  @override
  String get checkoutProcessingTitle => 'Processing your order';

  @override
  String get checkoutProcessingBody =>
      'Your order was sent and is waiting for confirmation. Please don\'t place it again.';

  @override
  String get checkoutPendingRequest => 'Pending request';

  @override
  String get checkoutCartRef => 'Cart';

  @override
  String get checkoutExpectedAmount => 'Expected amount';

  @override
  String get checkoutLockedNote =>
      'Ordering is paused for a moment so the order isn\'t placed twice.';

  @override
  String get checkoutOfflineTitle => 'You\'re offline';

  @override
  String get checkoutOfflineBody =>
      'We couldn\'t send the order yet. Your cart is kept on this device.';

  @override
  String get checkoutUnsentCart => 'Unsent cart';

  @override
  String get checkoutExpectedTotal => 'Expected total';

  @override
  String get checkoutCodShort => 'Cash · Unpaid';

  @override
  String get checkoutOfflineNote =>
      'No order is created until the server confirms it.';

  @override
  String get checkoutRepricedTitle => 'Cart prices changed';

  @override
  String get checkoutRepricedBody =>
      'The store updated prices or the delivery fee. Please confirm the new total before ordering.';

  @override
  String get checkoutCompare => 'What changed';

  @override
  String get checkoutPreviousTotal => 'Previous total';

  @override
  String get checkoutDeliveryIncrease => 'Delivery fee increase';

  @override
  String get checkoutNewTotal => 'New total';

  @override
  String get checkoutRepricedDraftNote =>
      'Nothing is ordered until you accept the new prices.';

  @override
  String get checkoutRepricedPlacedNote =>
      'Your order is in at the new price. You pay in cash on delivery.';

  @override
  String checkoutAcceptTotal(String amount) {
    return 'Accept $amount';
  }

  @override
  String checkoutPlaceTotal(String amount) {
    return 'Place order · $amount';
  }

  @override
  String get inboxRideAssignedTitle => 'A driver accepted your ride';

  @override
  String get inboxRideAssignedBody =>
      'Your driver is getting ready to come to the pickup point.';

  @override
  String get inboxRideDriverEnRouteTitle => 'Your driver is on the way';

  @override
  String get inboxRideDriverEnRouteBody =>
      'Your driver is heading to the pickup point.';

  @override
  String get inboxRideDriverArrivedTitle => 'Your driver has arrived';

  @override
  String get inboxRideDriverArrivedBody =>
      'Go to the pickup point and tell the driver your code.';

  @override
  String get inboxRideInTripTitle => 'Your trip has started';

  @override
  String get inboxRideInTripBody => 'Have a safe trip.';

  @override
  String get inboxRideCompletedTitle => 'Trip completed';

  @override
  String get inboxRideCompletedBody => 'Thanks for riding with DealGo.';

  @override
  String get inboxRideCancelledTitle => 'Ride cancelled';

  @override
  String get inboxRideCancelledBody => 'The ride was cancelled.';

  @override
  String get inboxRideExpiredTitle => 'Ride request expired';

  @override
  String get inboxRideExpiredBody =>
      'No driver accepted in time. You can book again.';

  @override
  String get inboxFoodPreparingTitle => 'The store is preparing your food';

  @override
  String get inboxFoodPreparingBody => 'The store confirmed your order.';

  @override
  String get inboxFoodReadyTitle => 'Your food is ready';

  @override
  String get inboxFoodReadyBody => 'Finding a driver to deliver it.';

  @override
  String get inboxFoodAssignedTitle => 'A driver took your order';

  @override
  String get inboxFoodAssignedBody => 'The driver is heading to the store.';

  @override
  String get inboxFoodPickedUpTitle => 'Your food was picked up';

  @override
  String get inboxFoodPickedUpBody => 'Your order is on its way.';

  @override
  String get inboxFoodDeliveredTitle => 'Order delivered';

  @override
  String get inboxFoodDeliveredBody => 'Enjoy your meal.';

  @override
  String get inboxFoodFailedTitle => 'Delivery failed';

  @override
  String get inboxFoodFailedBody =>
      'The order could not be delivered. Contact support if needed.';

  @override
  String get inboxFoodCancelledTitle => 'Order cancelled';

  @override
  String get inboxFoodCancelledBody => 'The food order was cancelled.';

  @override
  String get inboxMarkAllRead => 'Mark all read';

  @override
  String get inboxSectionToday => 'Today';

  @override
  String get inboxSectionYesterday => 'Yesterday';

  @override
  String get inboxSectionEarlier => 'Earlier';

  @override
  String get inboxFilterPromos => 'Offers';

  @override
  String get inboxUnread => 'Unread';

  @override
  String get inboxLoading => 'Loading notifications';

  @override
  String get inboxJustNow => 'Just now';

  @override
  String inboxMinutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String inboxHoursAgo(int count) {
    return '$count h ago';
  }

  @override
  String get addrBookTitle => 'Saved addresses';

  @override
  String get addrBookIntro =>
      'Pick these quickly when booking a ride or ordering food.';

  @override
  String get addrBookAdd => 'Add address';

  @override
  String get addrBookAddTitle => 'New address';

  @override
  String get addrBookEditTitle => 'Edit address';

  @override
  String get addrBookFull =>
      'You have saved the maximum of 20 addresses. Delete one to add another.';

  @override
  String get addrBookLoading => 'Loading addresses';

  @override
  String get addrBookEmptyTitle => 'No saved addresses yet';

  @override
  String get addrBookEmptyBody =>
      'Save home, work or places you visit often to book faster.';

  @override
  String get addrBookDefault => 'Default';

  @override
  String get addrBookNoPin => 'No map pin yet';

  @override
  String get addrBookPinned => 'Pinned to your current location';

  @override
  String get addrBookPinHere => 'Pin current location';

  @override
  String get addrBookLocating => 'Locating…';

  @override
  String get addrBookPinFailed =>
      'Could not get your location. Allow location access and try again.';

  @override
  String get addrBookMore => 'Options';

  @override
  String get addrBookEdit => 'Edit';

  @override
  String get addrBookMakeDefault => 'Set as default';

  @override
  String get addrBookDelete => 'Delete';

  @override
  String get addrBookCancel => 'Cancel';

  @override
  String get addrBookDeleteTitle => 'Delete address?';

  @override
  String get addrBookDeleted => 'Address deleted';

  @override
  String get addrBookSaved => 'Address saved';

  @override
  String get addrBookKindHome => 'Home';

  @override
  String get addrBookKindWork => 'Work';

  @override
  String get addrBookKindOther => 'Other';

  @override
  String get addrBookLabel => 'Name';

  @override
  String get addrBookLabelHint => 'e.g. Mum\'s place, Gym';

  @override
  String get addrBookLabelRequired => 'Enter a name';

  @override
  String get addrBookLine => 'Address';

  @override
  String get addrBookLineHint => 'Street number, street, ward/district';

  @override
  String get addrBookLineRequired => 'Enter an address (at least 3 characters)';

  @override
  String get addrBookNote => 'Note for the driver (optional)';

  @override
  String get addrBookNoteHint => 'e.g. green gate, call on arrival';

  @override
  String get addrBookSave => 'Save address';

  @override
  String get addrBookErrKindTaken =>
      'You already saved this type. Choose \"Other\" or edit the existing one.';

  @override
  String get addrBookErrNotFound =>
      'This address no longer exists. The list was refreshed.';

  @override
  String get addrBookErrOffline => 'No connection. Try again later.';

  @override
  String get addrBookErrGeneric => 'Could not save. Try again later.';

  @override
  String addrBookDeleteBody(String label) {
    return '\"$label\" will be removed from your address book.';
  }

  @override
  String get rateRidePrompt => 'How was your trip?';

  @override
  String get rateOrderPrompt => 'How was your order?';

  @override
  String get rateWhy =>
      'Ratings help DealGo keep drivers and stores at their best.';

  @override
  String get rateRideAction => 'Rate this trip';

  @override
  String get rateOrderAction => 'Rate this order';

  @override
  String get rateRideTitle => 'Rate your trip';

  @override
  String get rateOrderTitle => 'Rate your order';

  @override
  String get rateDriverLabel => 'Driver';

  @override
  String get rateStoreLabel => 'Store';

  @override
  String get rateTagsLabel => 'What stood out';

  @override
  String get rateCommentLabel => 'Comments (optional)';

  @override
  String get rateCommentHint => 'Tell us about your experience';

  @override
  String get rateSubmit => 'Submit rating';

  @override
  String get rateThanks => 'Thanks for your rating!';

  @override
  String get rateErrAlready => 'You have already rated this.';

  @override
  String get rateErrNotAllowed =>
      'You can rate only after the trip or order is finished.';

  @override
  String get rateErrOffline => 'No connection. Try again later.';

  @override
  String get rateErrGeneric => 'Could not send your rating. Try again later.';

  @override
  String get rateTagOnTime => 'On time';

  @override
  String get rateTagFriendly => 'Friendly';

  @override
  String get rateTagSafeDriving => 'Safe driving';

  @override
  String get rateTagCleanVehicle => 'Clean vehicle';

  @override
  String get rateTagTastyFood => 'Tasty food';

  @override
  String get rateTagWellPacked => 'Well packed';

  @override
  String get rateTagLate => 'Late';

  @override
  String get rateTagRude => 'Impolite';

  @override
  String get rateTagUnsafeDriving => 'Unsafe driving';

  @override
  String get rateTagWrongItems => 'Wrong items';

  @override
  String get rateTagColdFood => 'Food was cold';

  @override
  String rateDone(int stars) {
    return 'You rated $stars stars. Thank you!';
  }

  @override
  String rateStarTooltip(int star) {
    return '$star stars';
  }

  @override
  String get drvHistTitle => 'Earnings & history';

  @override
  String get drvHistSubtitle => 'Based on finished jobs';

  @override
  String get drvHistToday => 'Today';

  @override
  String get drvHistWeek => '7 days';

  @override
  String get drvHistEarnedToday => 'Earned today';

  @override
  String get drvHistEarnedWeek => 'Earned in 7 days';

  @override
  String get drvHistRides => 'Rides';

  @override
  String get drvHistFood => 'Food delivery';

  @override
  String get drvHistRating => 'Rating';

  @override
  String get drvHistNoRating => 'No ratings yet';

  @override
  String get drvHistRecent => 'Job history';

  @override
  String get drvHistFilterAll => 'All';

  @override
  String get drvHistEmptyTitle => 'No jobs yet';

  @override
  String get drvHistEmptyBody =>
      'Go online to get rides and deliveries. Finished jobs show up here.';

  @override
  String get drvHistLoadMore => 'Load more';

  @override
  String get drvHistLoadMoreFailed => 'Couldn\'t load more. Retry';

  @override
  String get drvHistOutcomeCancelled => 'Cancelled';

  @override
  String get drvHistOutcomeFailed => 'Delivery failed';

  @override
  String get drvHistLoading => 'Loading history';

  @override
  String drvHistJobs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jobs',
      one: '1 job',
    );
    return '$_temp0';
  }

  @override
  String drvHistCancelled(int count) {
    return '$count cancelled';
  }

  @override
  String drvHistStars(int stars) {
    return '$stars/5 stars';
  }

  @override
  String drvHistRatingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ratings',
      one: '1 rating',
    );
    return '$_temp0';
  }

  @override
  String drvHistGrossLine(String gross, String fee) {
    return 'Gross fares $gross · Platform fee −$fee';
  }

  @override
  String get drvHistNetNote => 'Net after fees · excludes COD collected';

  @override
  String drvHistItemFee(String percent, String fee) {
    return 'Fee $percent% −$fee';
  }

  @override
  String rateDeadline(String date) {
    return 'You can rate until $date.';
  }

  @override
  String get rateErrExpired =>
      'The rating window for this trip/order has closed.';

  @override
  String get placePickerPickupTitle => 'Choose pickup';

  @override
  String get placePickerDropoffTitle => 'Where to?';

  @override
  String get placePickerDeliveryTitle => 'Delivery address';

  @override
  String get placePickerHint => 'Search places or addresses';

  @override
  String get placeCurrentLocation => 'Your current location';

  @override
  String get placeCurrentLocationHint => 'Use your phone\'s GPS';

  @override
  String get placeLocating => 'Getting your location…';

  @override
  String get placeLocationDenied =>
      'Location access is off. Turn it on in Settings or pick another address.';

  @override
  String get placeLocationFailed =>
      'Couldn\'t get your location. Please try again.';

  @override
  String get placeCurrentNamed => 'Current location';

  @override
  String get placeSavedTitle => 'Saved addresses';

  @override
  String get placeSavedManage => 'Manage';

  @override
  String get placeRecentTitle => 'Recent trips';

  @override
  String get placeResultsTitle => 'Search results';

  @override
  String get placeSearchEmptyTitle => 'No places found';

  @override
  String get placeSearchEmptyBody =>
      'Try another street, district or landmark.';

  @override
  String get placeSearchUnavailable =>
      'Place search is unavailable right now. Use your current location or a saved address.';

  @override
  String get placeSearchError => 'Couldn\'t load search results.';

  @override
  String get placeNothingYet =>
      'Search for a place or use your current location to start.';

  @override
  String get rideBookTitle => 'Book a ride';

  @override
  String get rideBookSubtitle => 'Explore the city with DealGo';

  @override
  String get rideModeNow => 'Ride now';

  @override
  String get rideModeSchedule => 'Schedule';

  @override
  String get mapRecenter => 'Recenter on me';

  @override
  String get rideWhereTo => 'Where to?';

  @override
  String get ridePickupPlaceholder => 'Choose pickup';

  @override
  String get rideDropoffPlaceholder => 'Choose destination';

  @override
  String get rideSuggestionsTitle => 'Suggested for you';

  @override
  String get rideOpenPendingOffers => 'View pending offers';

  @override
  String get rideCheckRoute => 'Review route';

  @override
  String get rideSamePlaces => 'Pickup and destination are the same.';

  @override
  String rideDistanceKm(String km) {
    return '$km km';
  }

  @override
  String get rideQuoteLoading => 'Calculating the reference fare…';

  @override
  String get rideQuoteError =>
      'Couldn\'t get a fare. Check your connection and try again.';

  @override
  String rideFareRange(String min, String max) {
    return 'Allowed from $min to $max';
  }

  @override
  String get rideFareInvalid => 'Enter a valid amount.';

  @override
  String get rideFareReferenceExplain =>
      'The reference fare uses the distance and DealGo\'s price table. You can propose another amount within the allowed range.';

  @override
  String get rideFareAllowedRange => 'Allowed range';

  @override
  String get rideVehicleBikeTitle => 'Motorbike';

  @override
  String get rideVehicleBikeSubtitle => 'Quick · 1 passenger';

  @override
  String rideVehicleFrom(String amount) {
    return 'From $amount';
  }

  @override
  String get rideVehicleTitle => 'Choose a vehicle';

  @override
  String get rideVehicleRouteTitle => 'Your route';

  @override
  String get rideVehicleContinue => 'View fare details';

  @override
  String get homeQuickBookTitle => 'Quick ride';

  @override
  String get homeQuickBookPickup => '123 Nguyen Van Linh, Hai Chau, Da Nang';

  @override
  String get homeQuickBookVehicle => '4-seater';

  @override
  String get homeQuickBookEstimate => 'Estimate';

  @override
  String get homeQuickBookEtaPrice => '~ 42,000đ';

  @override
  String get homeQuickBookEtaTime => 'Time ~ 12 min';

  @override
  String get foodCartTitle => 'Cart';

  @override
  String get foodCartEmpty => 'Your cart is empty';

  @override
  String get foodCartEstimate => 'Estimated payment';

  @override
  String get foodCartContinue => 'Continue to checkout';

  @override
  String get foodDropoffTitle => 'Delivery address';

  @override
  String get foodDropoffChoose => 'Choose a delivery address';

  @override
  String get foodDropoffChange => 'Change';

  @override
  String get foodFareNeedAddress => 'Pick an address first';

  @override
  String get foodFareQuoting => 'Calculating…';

  @override
  String get foodFareQuoteError =>
      'Couldn\'t get the delivery fee. Check your connection and try again.';

  @override
  String get driverOtpLocked =>
      'Too many wrong codes. Contact support to continue this ride.';

  @override
  String get ridePickupCodeUnavailable =>
      'Your pickup code appears once a driver accepts the ride.';

  @override
  String get driverCardNoRating => 'No ratings yet';

  @override
  String driverCardRating(String rating, int count) {
    return '$rating · $count ratings';
  }

  @override
  String get actionReload => 'Reload';

  @override
  String get rideAgreedFare => 'Agreed fare';

  @override
  String get rideTripInfo => 'Trip details';

  @override
  String get rideDriverAssignedTitle => 'Your driver accepted';

  @override
  String get rideVehicleLabel => 'Vehicle';

  @override
  String get rideViewReceipt => 'View receipt';

  @override
  String get ridePickupCodeHint => 'Only share the code once the plate matches';

  @override
  String get rideOfflineTitle => 'Connection lost';

  @override
  String get rideOfflineBody =>
      'You are seeing the last loaded status, not a live one.';

  @override
  String get rideOfflineNote =>
      'We never assume the driver has arrived when this refresh fails.';

  @override
  String get rideTripSummary => 'Trip summary';

  @override
  String rideSelectOfferAmount(String amount) {
    return 'Choose $amount';
  }

  @override
  String get rideSelectOfferPrompt => 'Choose an offer';

  @override
  String get rideReceiptTitle => 'Trip receipt';

  @override
  String get rideReceiptHelp => 'Get help';

  @override
  String get rideReceiptDone => 'Trip completed!';

  @override
  String get rideReceiptThanks => 'Thanks for riding with DealGo';

  @override
  String get rideReceiptNoFare =>
      'The server has not returned the agreed fare yet.';

  @override
  String get rideReceiptCash => 'Paid in cash to the driver';

  @override
  String get rideReceiptFinishedAt => 'Time';

  @override
  String get rideReceiptPayment => 'Payment details';

  @override
  String get rideReceiptOffline =>
      'Could not load the receipt. The agreed fare is not shown.';

  @override
  String rideReceiptRef(String ref) {
    return 'Receipt $ref';
  }

  @override
  String get foodTrackingTitle => 'Track food order';

  @override
  String get foodTrackingDeliverTo => 'Deliver to';

  @override
  String get paymentHistoryTotal => 'Total paid';

  @override
  String get paymentHistoryFilterRides => 'Rides';

  @override
  String get paymentHistoryFilterFood => 'Food';

  @override
  String get paymentHistoryCash => 'Cash';

  @override
  String get paymentHistoryEmpty =>
      'No payments yet. Completed rides and delivered orders appear here.';

  @override
  String get paymentHistoryLoadFailed =>
      'Could not load your payment history. Try again later.';

  @override
  String paymentHistoryCount(int count) {
    return '$count payments';
  }

  @override
  String get driverStatTodayJobs => 'Jobs today';

  @override
  String get driverStatTodayEarnings => 'Earnings today';

  @override
  String get driverStatRating => 'Average rating';

  @override
  String get driverStatWeekJobs => 'Jobs, last 7 days';

  @override
  String get helpTitle => 'Help center';

  @override
  String get helpSubtitle => 'How can we help you?';

  @override
  String get helpSearchHint => 'Search answers or guides...';

  @override
  String get helpTopicsTitle => 'Popular topics';

  @override
  String get helpTopicRide => 'Rides';

  @override
  String get helpTopicRideSub => 'Booking & cancelling';

  @override
  String get helpTopicFood => 'Food';

  @override
  String get helpTopicFoodSub => 'Orders & delivery';

  @override
  String get helpTopicPayment => 'Payments';

  @override
  String get helpTopicPaymentSub => 'Cash & refunds';

  @override
  String get helpTopicAccount => 'Account';

  @override
  String get helpTopicAccountSub => 'Sign-in & security';

  @override
  String get helpTopicSelected => 'Topic for your request';

  @override
  String get helpFaqTitle => 'Frequently asked questions';

  @override
  String get helpSeeAll => 'See all';

  @override
  String get helpStillNeedTitle => 'Still need help?';

  @override
  String get helpStillNeedBody =>
      'See the requests you sent and chat with the support team.';

  @override
  String get helpMyTickets => 'Your requests';

  @override
  String get helpCreateTicket => 'Send a support request';

  @override
  String get supportListTitle => 'Support requests';

  @override
  String get supportListHeading => 'Your requests';

  @override
  String get supportListSubtitle =>
      'Track progress and talk directly with the support team.';

  @override
  String get supportListEmptyTitle => 'No requests yet';

  @override
  String get supportListEmptyBody =>
      'Need help with a ride, an order or a payment? Create a new request.';

  @override
  String get supportListLoadFailed =>
      'Couldn\'t load your requests. Check your connection and try again.';

  @override
  String get supportNewTicket => 'New request';

  @override
  String get supportRetry => 'Try again';

  @override
  String get supportStatusOpen => 'Received';

  @override
  String get supportStatusInProgress => 'In progress';

  @override
  String get supportStatusReplied => 'Replied';

  @override
  String get supportStatusResolved => 'Resolved';

  @override
  String get supportStatusClosed => 'Closed';

  @override
  String get supportCategoryRide => 'Ride';

  @override
  String get supportCategoryFood => 'Food';

  @override
  String get supportCategoryPayment => 'Payment';

  @override
  String get supportCategoryAccount => 'Account';

  @override
  String get supportCategorySafety => 'Safety';

  @override
  String get supportCategoryOther => 'Other';

  @override
  String get supportPriorityLow => 'Low';

  @override
  String get supportPriorityNormal => 'Normal';

  @override
  String get supportPriorityHigh => 'High';

  @override
  String get supportPriorityUrgent => 'Urgent';

  @override
  String get supportCreateTitle => 'New support request';

  @override
  String get supportCreateHeading => 'Need help?';

  @override
  String get supportCreateSubtitle =>
      'Describe the issue so DealGo can help with the right transaction.';

  @override
  String get supportFieldCategory => 'Issue type';

  @override
  String get supportFieldRelated => 'Related ride / order';

  @override
  String get supportRelatedNone => 'Not about a specific ride or order';

  @override
  String get supportRelatedPickTitle => 'Pick a ride or order';

  @override
  String get supportRelatedEmpty => 'No finished rides or orders yet.';

  @override
  String get supportFieldSubject => 'Subject';

  @override
  String get supportSubjectHint => 'e.g. Question about my ride fare';

  @override
  String get supportFieldDescription => 'Details';

  @override
  String get supportDescriptionHint =>
      'Tell us what happened, when, and anything related...';

  @override
  String get supportPrivacyNote =>
      'This is only used to handle your request. Never send passwords, OTP codes or card data.';

  @override
  String get supportSubmit => 'Send support request';

  @override
  String get supportSubjectTooShort =>
      'The subject needs at least 3 characters.';

  @override
  String get supportDescriptionTooShort =>
      'The details need at least 10 characters.';

  @override
  String get supportLimitReached =>
      'You have several open requests. Add to an existing one or wait for a reply.';

  @override
  String get supportTextTooLong => 'The text is too long. Please shorten it.';

  @override
  String get supportSendFailed =>
      'Couldn\'t send. Check your connection and try again.';

  @override
  String get supportCreated => 'Support request sent.';

  @override
  String get supportDetailTitle => 'Request details';

  @override
  String get supportInfoCategory => 'Issue type';

  @override
  String get supportInfoRelated => 'Related to';

  @override
  String get supportInfoPriority => 'Priority';

  @override
  String get supportProgressTitle => 'Progress';

  @override
  String get supportProgressReceived => 'Received';

  @override
  String get supportProgressInProgress => 'In progress';

  @override
  String get supportProgressInProgressBody =>
      'The support team is looking into your request.';

  @override
  String get supportProgressResolved => 'Resolved';

  @override
  String get supportProgressClosed => 'Closed';

  @override
  String get supportThreadTitle => 'Conversation';

  @override
  String get supportStaffName => 'DealGo Support';

  @override
  String get supportYou => 'You';

  @override
  String get supportReplyHint => 'Type your reply...';

  @override
  String get supportReplySend => 'Send reply';

  @override
  String get supportClosedNote =>
      'This request is closed. Create a new one if you need more help.';

  @override
  String get supportResolvedNote =>
      'This request was resolved. Reply if the issue persists and it will reopen.';

  @override
  String get supportDetailLoadFailed => 'Couldn\'t load this request.';

  @override
  String get supportRelatedRide => 'Ride';

  @override
  String get supportRelatedFood => 'Order';

  @override
  String get inboxSupportReplyTitle => 'DealGo replied to your support request';

  @override
  String get inboxSupportResolvedTitle => 'Your support request was resolved';

  @override
  String supportFilterAll(int count) {
    return 'All · $count';
  }

  @override
  String supportFilterActive(int count) {
    return 'In progress · $count';
  }

  @override
  String supportFilterDone(int count) {
    return 'Done · $count';
  }

  @override
  String supportCodeCreated(String code, String time) {
    return 'Request $code · Created $time';
  }

  @override
  String supportProgressReceivedAt(String time) {
    return 'Request received at $time';
  }

  @override
  String supportProgressAt(String time) {
    return 'At $time';
  }

  @override
  String get helpBannerBadge => 'DealGo Support';

  @override
  String get helpBannerBody => 'Help with every trip and every order.';

  @override
  String get foodGroupNear => 'Near me';

  @override
  String get foodGroupVietnamese => 'Vietnamese';

  @override
  String get foodGroupTea => 'Milk tea';

  @override
  String get foodGroupFastFood => 'Fast food';

  @override
  String get foodGroupCafe => 'Coffee';

  @override
  String get storeCategoryPho => 'Pho';

  @override
  String get storeCategoryNoodles => 'Noodles';

  @override
  String get storeCategoryRice => 'Rice';

  @override
  String get storeCategoryBanhMi => 'Banh mi';

  @override
  String get storeCategoryCafe => 'Coffee';

  @override
  String get storeCategoryTea => 'Milk tea';

  @override
  String get storeCategoryFastFood => 'Fast food';

  @override
  String get storeCategorySnack => 'Snacks';

  @override
  String get storeCategoryMart => 'Grocery';

  @override
  String get storeRatingNew => 'New';

  @override
  String storeRatingFew(int count) {
    return '$count ratings';
  }

  @override
  String storeRatingValue(String rating, int count) {
    return '$rating ($count)';
  }

  @override
  String storeDistance(String km) {
    return '$km km';
  }

  @override
  String get foodDiscoverySearchHint => 'Search restaurants, dishes, drinks...';

  @override
  String get foodDiscoveryStoresTitle => 'Tasty spots near you';

  @override
  String get foodDiscoverySortedByDistance => 'Sorted by real distance';

  @override
  String get foodDiscoveryLocationOff => 'Turn on location to sort by distance';

  @override
  String get foodDiscoveryTopRatedTitle => 'Popular this week';

  @override
  String get foodDiscoveryTopRatedSubtitle => 'Dishes people love';

  @override
  String get foodBannerKicker => 'TODAY\'S FOOD DEAL';

  @override
  String get foodBannerTitle => 'Good food every day,\ndelivered to you';

  @override
  String get foodBannerCta => 'Explore now →';

  @override
  String get foodStoreBestsellers => 'Best sellers';

  @override
  String foodStorePrepChip(int minutes) {
    return '~$minutes min';
  }

  @override
  String get foodSearchGroups => 'Categories';

  @override
  String get foodSeeAll => 'See all →';

  @override
  String get foodCategoryEmpty => 'No restaurants in this category yet.';

  @override
  String get foodStoreTitle => 'Store details';

  @override
  String get foodStoreOpen => 'Open';

  @override
  String get foodStorePaused => 'Paused';

  @override
  String get foodStoreTabMenu => 'Menu';

  @override
  String get foodStoreTabReviews => 'Reviews';

  @override
  String get foodStoreTabInfo => 'Info';

  @override
  String get foodStoreNoItems => 'This store has no items yet.';

  @override
  String get foodItemSoldOut => 'Sold out';

  @override
  String get foodAddToCart => 'Add to cart';

  @override
  String get foodDecreaseQuantity => 'Decrease quantity';

  @override
  String get foodViewCart => 'View cart';

  @override
  String get foodStoreReviewsUnavailable => 'Couldn\'t load reviews.';

  @override
  String get foodStoreReviewsNone => 'No reviews yet.';

  @override
  String get foodStoreInfoName => 'Name';

  @override
  String get foodStoreInfoCategory => 'Category';

  @override
  String get foodStoreInfoAddress => 'Address';

  @override
  String get foodStoreInfoAddressMissing => 'No address yet';

  @override
  String get foodStoreInfoPayment => 'Payment';

  @override
  String get foodStoreInfoPaymentCod => 'Cash on delivery';

  @override
  String foodStoreMenuCount(int count) {
    return 'Menu · $count items';
  }

  @override
  String foodCartSelected(int count) {
    return '$count items selected';
  }

  @override
  String foodStoreReviewsHidden(int count) {
    return '$count reviews — the score appears once there are more';
  }

  @override
  String foodStoreReviewsSummary(String average, int count) {
    return '$average ★ · $count reviews';
  }

  @override
  String get homeVoucherBadge => 'DealGo Voucher';

  @override
  String get homeVoucherTitle => 'Daily deals that save on every trip!';

  @override
  String get homeVoucherBody =>
      'Browse running codes and add one at checkout — DealGo checks it before you order.';

  @override
  String get homeVoucherAction => 'Hunt deals';

  @override
  String get homeRecentEmpty => 'No rides or orders yet.';

  @override
  String get homeShopTitle => 'Featured shopping';

  @override
  String get homeRecentTitle => 'Recent orders & rides';

  @override
  String get homeCatFood => 'Food';

  @override
  String get homeCatMart => 'Supermarket';

  @override
  String get homeCatConvenience => 'Convenience';

  @override
  String get homeCatPharmacy => 'Pharmacy';

  @override
  String get homeCatFlowers => 'Flowers & gifts';

  @override
  String get homeCatElectronics => 'Electronics';

  @override
  String get homeCatFashion => 'Fashion';

  @override
  String get actionSave => 'Save';

  @override
  String get rideSafetyContactName => 'Name';

  @override
  String get rideSafetyContactPhone => 'Phone number';

  @override
  String get rideSafetyRemoveContact => 'Remove contact';

  @override
  String get rideSafetyContactsEmpty =>
      'No emergency contacts yet. Add up to 3 people.';

  @override
  String get driverNotificationsTitle => 'Driver notifications';

  @override
  String get driverOpenHistory => 'View trip history';

  @override
  String get driverCompletedNotFound => 'This job isn\'t in your history yet';

  @override
  String get driverCompletedNotFoundHint =>
      'History updates after a job ends. Try again in a few minutes.';

  @override
  String get driverCompletedFeeLabel => 'Platform fee';

  @override
  String get driverCompletedNetLabel => 'You earn';

  @override
  String get merchantOrderTitle => 'Order details';

  @override
  String get merchantOrderNotFound => 'Order not found';

  @override
  String get merchantOrderTitleNew => 'New order';

  @override
  String get merchantOrderTitlePreparing => 'Preparing';

  @override
  String get merchantOrderTitleReady => 'Hand over to driver';

  @override
  String get merchantMarkReady => 'Ready';

  @override
  String get merchantMarkHandedOver => 'Handed over';

  @override
  String get merchantOrderHeadNew => 'Waiting for confirmation';

  @override
  String get merchantOrderHeadPreparing => 'Order accepted';

  @override
  String get merchantOrderHeadReady => 'Order ready';

  @override
  String get merchantOrderCustomer => 'DealGo customer';

  @override
  String get merchantOrderNewChip => 'New · Awaiting store';

  @override
  String get merchantItemsToPrepare => 'Items to prepare';

  @override
  String get merchantReadyHint =>
      'Tap “Ready” only when every item is done and ready to hand over.';

  @override
  String get merchantDriverTitle => 'Pickup driver';

  @override
  String get merchantDriverWaiting =>
      'Waiting for a DealGo driver to claim the order.';

  @override
  String get merchantHandoffTitle => 'Handover check';

  @override
  String get merchantOrderRefLabel => 'Order code';

  @override
  String get merchantLineCountLabel => 'Item types';

  @override
  String get merchantHandoffCodLabel => 'Food value (COD)';

  @override
  String get merchantHandoffNote =>
      'Match the order code with the driver. The order moves to “Picked up” when the driver confirms in their app.';

  @override
  String get merchantHandoffDoneNote =>
      'Noted on this device. The status changes when the driver confirms pickup.';

  @override
  String get merchantFoodValueLabel => 'Food';

  @override
  String get merchantDeliveryFeeLabel => 'Delivery fee';

  @override
  String get merchantTotalLabel => 'Total';

  @override
  String get merchantConflictTitle => 'Confirm order';

  @override
  String get merchantBackToOrders => 'Back to orders';

  @override
  String get merchantConflictRefresh => 'See latest status';

  @override
  String get merchantConflictHeadline => 'Order already handled';

  @override
  String get merchantConflictBody =>
      'The order changed status (customer cancelled, another staff member or the system handled it).';

  @override
  String get merchantConflictOrder => 'Order';

  @override
  String get merchantConflictNote =>
      'The old action is not resent; the latest status comes from the server.';

  @override
  String orderRef(String ref) {
    return 'Order $ref';
  }

  @override
  String rideRef(String ref) {
    return 'Trip $ref';
  }

  @override
  String driverCompletedFeePercentLabel(String percent) {
    return 'Platform fee ($percent%)';
  }

  @override
  String merchantOrderPlacedAt(String time) {
    return 'Placed $time';
  }

  @override
  String merchantLineQty(int qty, String price) {
    return 'x$qty · $price each';
  }

  @override
  String get partnerModeChip => 'Partner mode';

  @override
  String get partnerContinue => 'Continue';

  @override
  String partnerStepOf(int current, int total) {
    return 'Step $current/$total';
  }

  @override
  String get partnerDocTake => 'Take photo';

  @override
  String get partnerDocPick => 'Choose from library';

  @override
  String get partnerDocRetake => 'Retake';

  @override
  String get partnerDocRemove => 'Remove';

  @override
  String get partnerDocStored => 'Saved on your application';

  @override
  String get partnerDocPicked => 'New photo — sent when you submit';

  @override
  String get partnerDocMissing => 'No photo yet';

  @override
  String get partnerDocFlagged => 'Retake requested';

  @override
  String get partnerDocOptional => 'Optional';

  @override
  String get partnerDocHint =>
      'Sharp, all four corners visible, no glare. JPG/PNG up to 4 MB.';

  @override
  String get partnerDocPickFailed =>
      'Could not open the camera or photo library.';

  @override
  String get partnerKindIdFront => 'ID card — front';

  @override
  String get partnerKindIdBack => 'ID card — back';

  @override
  String get partnerKindSelfie => 'Selfie';

  @override
  String get partnerKindLicense => 'Driving licence';

  @override
  String get partnerKindVehicleReg => 'Vehicle registration';

  @override
  String get partnerKindBusinessLicense => 'Business licence';

  @override
  String get partnerKindRepIdFront => 'Representative ID — front';

  @override
  String get partnerKindRepIdBack => 'Representative ID — back';

  @override
  String get partnerKindStorefront => 'Storefront photo';

  @override
  String get partnerSectionPersonal => 'Personal details';

  @override
  String get partnerSectionIdCard => 'ID card photos';

  @override
  String get partnerSectionSelfie => 'Selfie';

  @override
  String get partnerSectionLicense => 'Driving licence';

  @override
  String get partnerSectionVehicle => 'Vehicle / registration';

  @override
  String get partnerSectionBank => 'Payout account';

  @override
  String get partnerSectionShopInfo => 'Shop details';

  @override
  String get partnerSectionRepresentative => 'Representative';

  @override
  String get partnerSectionBusinessDocs => 'Business documents';

  @override
  String get partnerSectionStorefront => 'Storefront photo';

  @override
  String get partnerSectionOther => 'Other';

  @override
  String get partnerFix => 'Fix this';

  @override
  String get partnerStartFix => 'Start editing';

  @override
  String get partnerReasonLabel => 'Reason from DealGo';

  @override
  String get partnerIssuesTitle => 'Items to fix';

  @override
  String get partnerNoIssues =>
      'DealGo did not list specific items. Please review the whole application.';

  @override
  String get partnerResubmitNote =>
      'Only retake the requested documents; the others stay on your application.';

  @override
  String get partnerTimelineSubmitted => 'Application sent';

  @override
  String get partnerTimelineReview => 'Document review';

  @override
  String get partnerTimelineReviewing => 'Under review';

  @override
  String get partnerTimelineReviewed => 'Reviewed';

  @override
  String get partnerTimelineDone => 'Done';

  @override
  String get partnerTimelineInProgress => 'In progress';

  @override
  String get partnerTimelineWaiting => 'Waiting';

  @override
  String partnerSubmittedAt(String time) {
    return 'Sent $time';
  }

  @override
  String get partnerLoading => 'Loading application…';

  @override
  String get partnerErrorSession =>
      'Your session expired. Please sign in again.';

  @override
  String get partnerErrorNetwork =>
      'Could not reach the server. Try again later.';

  @override
  String get partnerErrorMissingDocs => 'Required documents are missing.';

  @override
  String get partnerErrorTooLarge =>
      'Photo too large. Retake at a lower resolution.';

  @override
  String get partnerErrorType => 'Photo format not supported.';

  @override
  String get partnerErrorStorage =>
      'The server cannot accept files right now. Try again later.';

  @override
  String get partnerErrorGeneric =>
      'Could not send the application. Try again later.';

  @override
  String get partnerBankName => 'Bank';

  @override
  String get partnerBankNameHint => 'e.g. Vietcombank';

  @override
  String get partnerBankAccount => 'Account number';

  @override
  String get partnerBankHolder => 'Account holder';

  @override
  String get partnerBankHolderHint => 'Uppercase, as printed on the card';

  @override
  String get partnerBankNote =>
      'The account holder must match your ID. DealGo does not charge when linking.';

  @override
  String get partnerReviewTitleDocs => 'Documents';

  @override
  String get partnerReviewEntered => 'Entered';

  @override
  String get partnerReviewMissing => 'Missing';

  @override
  String get partnerBackHome => 'Back to home';

  @override
  String get partnerViewApplication => 'Review application';

  @override
  String get kycRoleBadge => 'Driver';

  @override
  String get kycFlowLabel => 'DRIVER PARTNER SIGN-UP';

  @override
  String get kycIntroTitle => 'Driver partner sign-up';

  @override
  String get kycIntroSubtitle => 'Driver partner';

  @override
  String get kycIntroHero => 'Ride anywhere\nEarn more';

  @override
  String get kycIntroHeadline => 'Become a DealGo driver partner';

  @override
  String get kycIntroBody =>
      'Go online for rides or food delivery once each service is approved.';

  @override
  String get kycIntroRideTitle => 'Rides';

  @override
  String get kycIntroRideBody => 'Take trips and make offers';

  @override
  String get kycIntroFoodTitle => 'Food delivery';

  @override
  String get kycIntroFoodBody => 'Pick up from shops and deliver';

  @override
  String get kycIntroEarnTitle => 'Track earnings';

  @override
  String get kycIntroEarnBody => 'Clear per-trip earnings and payouts';

  @override
  String get kycIntroRequirements =>
      'Before you start: ID card, selfie, driving licence, vehicle registration and a payout account.';

  @override
  String get kycStartCta => 'Start sign-up';

  @override
  String get kycExistingCta => 'I already applied';

  @override
  String get kycStepServices => 'Choose services';

  @override
  String get kycStepPersonal => 'Personal details';

  @override
  String get kycStepIdentity => 'ID card photos';

  @override
  String get kycStepConfirm => 'Check your details';

  @override
  String get kycStepSelfie => 'Selfie';

  @override
  String get kycStepLicense => 'Driving licence';

  @override
  String get kycStepVehicle => 'Vehicle';

  @override
  String get kycStepBank => 'Payout bank';

  @override
  String get kycStepReview => 'Review driver application';

  @override
  String get kycSubServices =>
      'You can apply for several services depending on your documents and vehicle.';

  @override
  String get kycSubPersonal =>
      'Enter details exactly as on your ID to avoid mismatches.';

  @override
  String get kycSubIdentity =>
      'Photograph both sides of your chip ID card. Photos are only visible to the review team.';

  @override
  String get kycSubConfirm => 'Check what you entered against your ID card.';

  @override
  String get kycSubSelfie =>
      'Take a clear selfie without sunglasses or a mask.';

  @override
  String get kycSubLicense => 'Add a valid licence for the services you chose.';

  @override
  String get kycSubVehicle => 'Vehicle details used to check job eligibility.';

  @override
  String get kycSubBank => 'Account for earnings and payouts.';

  @override
  String get kycSubReview => 'Check before sending for review';

  @override
  String get kycServiceRideBody => 'Take trips, agree fares and pick up riders';

  @override
  String get kycServiceFoodBody => 'Collect orders from shops and deliver them';

  @override
  String get kycServicesNote =>
      'You can switch each service on or off after approval.';

  @override
  String get kycFullName => 'Full name';

  @override
  String get kycFullNameHint => 'As on your ID';

  @override
  String get kycBirthDate => 'Date of birth';

  @override
  String get kycNationality => 'Nationality';

  @override
  String get kycNationalityVn => 'Vietnam';

  @override
  String get kycAddress => 'Contact address';

  @override
  String get kycPrivacyNote =>
      'Legal details are only used for partner review and protected under DealGo\'s data policy.';

  @override
  String get kycIdNumber => 'ID number';

  @override
  String get kycIdNumberHint => '12 digits';

  @override
  String get kycConfirmNote =>
      'Details that don\'t match your ID will be sent back for changes.';

  @override
  String get kycLicenseClass => 'Licence class';

  @override
  String get kycLicenseNumber => 'Licence number';

  @override
  String get kycVehicleType => 'Vehicle type';

  @override
  String get kycVehiclePlate => 'Plate number';

  @override
  String get kycVehicleBrand => 'Brand';

  @override
  String get kycVehicleModel => 'Model';

  @override
  String get kycVehicleNote => 'DealGo currently accepts motorbikes only.';

  @override
  String get kycReviewProfile => 'Profile';

  @override
  String get kycReviewDriver => 'Driver details';

  @override
  String get kycReviewServices => 'Services';

  @override
  String get kycReviewBank => 'Payout bank';

  @override
  String get kycReviewNote =>
      'Sending creates a review; going online stays locked until DealGo approves.';

  @override
  String get kycSubmitCta => 'Send application';

  @override
  String get kycResubmitCta => 'Send changes';

  @override
  String get kycStatusTitle => 'KYC review result';

  @override
  String get kycTrackCta => 'Back to Driver home';

  @override
  String get kycPendingTitle => 'Under review';

  @override
  String kycPendingBody(String name) {
    return 'Driver application of $name';
  }

  @override
  String get kycActiveTitle => 'Driver application approved';

  @override
  String get kycActiveBody => 'You can go online for the approved services.';

  @override
  String get kycStatusPendingNote =>
      'The app updates once DealGo finishes the review. You can\'t go online until approved.';

  @override
  String get kycStatusActiveNote =>
      'Jobs are open for your approved application.';

  @override
  String get kycTimelineActivate => 'Start taking jobs';

  @override
  String get kycTimelineActivateBody => 'Only once each service is approved';

  @override
  String get kycRejectedTitle => 'Update driver application';

  @override
  String get kycRejectedBanner =>
      'Your application needs changes. Each item has a reason; unchanged documents don\'t need to be resent.';

  @override
  String get kybRoleBadge => 'Shop';

  @override
  String get kybFlowLabel => 'DEALGO PARTNER SIGN-UP';

  @override
  String get kybStepFlowLabel => 'SHOP DETAILS';

  @override
  String get kybIntroTitle => 'Become a Shop partner';

  @override
  String get kybIntroSubtitle => 'Shop partner';

  @override
  String get kybIntroHeadline => 'Start selling with DealGo';

  @override
  String get kybIntroBody => 'Sell food, groceries and goods in one app.';

  @override
  String get kybIntroHero => 'From small stalls to growing stores';

  @override
  String get kybIntroBenefits => 'DealGo grows with you';

  @override
  String get kybBenefitReachTitle => 'Reach customers';

  @override
  String get kybBenefitReachBody => 'Show your shop and menu nearby';

  @override
  String get kybBenefitOrdersTitle => 'Handle orders';

  @override
  String get kybBenefitOrdersBody => 'Track new and in-progress orders';

  @override
  String get kybBenefitRevenueTitle => 'Manage revenue';

  @override
  String get kybBenefitRevenueBody => 'Sales stats and payouts';

  @override
  String get kybBenefitTrustTitle => 'Transparent sign-up';

  @override
  String get kybBenefitTrustBody => 'Applications are reviewed before selling';

  @override
  String get kybIntroRequirements =>
      'You\'ll need shop details, a representative, a payout account and business documents.';

  @override
  String get kybStartCta => 'Start Shop sign-up';

  @override
  String get kybStepBusinessType => 'Business type';

  @override
  String get kybStepBusinessTypeHeadline => 'What do you sell?';

  @override
  String get kybStepShopInfo => 'Shop details';

  @override
  String get kybStepRepresentative => 'Representative & payout';

  @override
  String get kybStepDocuments => 'Business documents';

  @override
  String get kybStepReview => 'Review Shop application';

  @override
  String get kybSubBusinessType =>
      'Pick the closest type so DealGo can suggest categories and checks.';

  @override
  String get kybSubShopInfo =>
      'Name and address are used for review and shown to customers.';

  @override
  String get kybSubRepresentative => 'Legal representative and payout account.';

  @override
  String get kybSubDocuments =>
      'Photograph the business licence and the representative\'s ID. Only reviewers can see them.';

  @override
  String get kybSubReview => 'Check before sending';

  @override
  String get kybTypeRestaurant => 'Restaurant / eatery';

  @override
  String get kybTypeRestaurantBody => 'Cooked food delivered to the door.';

  @override
  String get kybTypeCafe => 'Café / milk tea';

  @override
  String get kybTypeCafeBody => 'Drinks, cakes and snacks.';

  @override
  String get kybTypeGrocery => 'Supermarket / grocery';

  @override
  String get kybTypeGroceryBody => 'Produce, meat, fish and household goods.';

  @override
  String get kybTypeConvenience => 'Convenience store';

  @override
  String get kybTypeConvenienceBody => 'Everyday essentials.';

  @override
  String get kybTypeOther => 'Other';

  @override
  String get kybTypeOtherBody => 'Pick categories when adding products.';

  @override
  String get kybSubjectLabel => 'Registered as';

  @override
  String get kybSubjectHousehold => 'Household business';

  @override
  String get kybSubjectCompany => 'Company';

  @override
  String get kybSubjectOther => 'Other';

  @override
  String get kybTypeNote =>
      'Categories and requirements can vary by type and area.';

  @override
  String get kybShopName => 'Shop name';

  @override
  String get kybShopAddress => 'Address';

  @override
  String get kybShopType => 'Type';

  @override
  String get kybRepName => 'Representative\'s full name';

  @override
  String get kybRepNote =>
      'The representative is responsible for the details given to DealGo.';

  @override
  String get kybReviewStatus => 'Application status';

  @override
  String get kybReviewShop => 'Shop details';

  @override
  String get kybReviewRep => 'Representative';

  @override
  String get kybReviewBank => 'Payout bank';

  @override
  String get kybReviewNote =>
      'Sending creates a review. Changing documents later needs a new update.';

  @override
  String get kybSubmitCta => 'Send for review';

  @override
  String get kybResubmitCta => 'Resend application';

  @override
  String get kybStatusTitle => 'Shop review status';

  @override
  String get kybTrackCta => 'Back to Shop home';

  @override
  String get kybPendingTitle => 'Application under review';

  @override
  String get kybActiveTitle => 'Shop application approved';

  @override
  String get kybActiveBody => 'You can open your shop and take orders.';

  @override
  String get kybStatusPendingNote =>
      'There\'s no guaranteed review time. The app updates once DealGo decides.';

  @override
  String get kybStatusActiveNote =>
      'Selling is open for your approved application.';

  @override
  String get kybTimelineActivate => 'Start selling';

  @override
  String get kybTimelineActivateBody => 'Only after approval';

  @override
  String get kybRejectedTitle => 'Update Shop application';

  @override
  String get kybRejectedBanner =>
      'Your application needs changes before review continues. The previous version is kept.';

  @override
  String get merchantStatsTitle => 'Statistics';

  @override
  String get merchantStatsToday => 'Today';

  @override
  String get merchantStatsSales => 'Food sales';

  @override
  String get merchantStatsDelivered => 'Completed orders';

  @override
  String get merchantStatsOpen => 'Open orders';

  @override
  String get merchantStatsRating => 'Rating';

  @override
  String get merchantStatsRatingNew => 'New shop';

  @override
  String merchantStatsRatingCount(int count) {
    return '$count ratings';
  }

  @override
  String merchantStatsLastDays(int days) {
    return 'Last $days days';
  }

  @override
  String get merchantStatsRange7 => '7 days';

  @override
  String get merchantStatsRange30 => '30 days';

  @override
  String get merchantStatsOrdersByDay => 'Completed orders per day';

  @override
  String merchantStatsTotals(int count, String sales, int cancelled) {
    return '$count orders · $sales · $cancelled cancelled';
  }

  @override
  String get merchantStatsTopItems => 'Best sellers';

  @override
  String get merchantStatsTopEmpty => 'No items delivered in this period yet.';

  @override
  String merchantStatsPortions(int count) {
    return '$count portions';
  }

  @override
  String get merchantStatsNote =>
      'Sales are the food subtotal of delivered orders, in Vietnam time; delivery fees excluded.';

  @override
  String get merchantStatsFailed => 'Could not load statistics. Pull to retry.';

  @override
  String get merchantStatsRetry => 'Retry';

  @override
  String merchantOrderCustomerName(String name) {
    return 'Customer: $name';
  }

  @override
  String merchantOrderDriverName(String name) {
    return 'Driver: $name';
  }

  @override
  String get merchantQueueTitle => 'Shop order queue';

  @override
  String merchantQueueViewOrder(String ref) {
    return 'View order $ref';
  }

  @override
  String get merchantQueueYourShop => 'Your shop';

  @override
  String get merchantQueueNewToConfirm => 'New orders to confirm';

  @override
  String get merchantQueueToHandle => 'Orders to handle';

  @override
  String get merchantQueueOthers => 'Other orders';

  @override
  String get merchantQueueNewChip => 'NEW · Awaiting shop';

  @override
  String get merchantQueueDeliverTo => 'Deliver to';

  @override
  String get merchantQueueItemsFood => 'Items · Food';

  @override
  String get merchantQueueDeliveryFee => 'Delivery fee';

  @override
  String get merchantQueueTotal => 'Total';

  @override
  String get merchantHomeTitle => 'Shop overview';

  @override
  String get merchantHomeOpenChip => 'Open';

  @override
  String get merchantHomeToConfirm => 'To confirm';

  @override
  String get merchantHomePreparing => 'Preparing';

  @override
  String get merchantHomeNoOrders => 'No open orders in the queue.';

  @override
  String merchantHomeOrderLine(int count, String food) {
    return '$count items · $food food';
  }

  @override
  String get merchantHomeView => 'View →';

  @override
  String get merchantHomeShopFallback => 'Your shop';

  @override
  String get merchantStatusPlaced => 'Awaiting shop';

  @override
  String get merchantStatusPreparing => 'Preparing';

  @override
  String get merchantStatusReady => 'Ready';

  @override
  String get merchantStatusAssigned => 'Driver assigned';

  @override
  String get merchantNotSynced => 'Not synced';

  @override
  String get merchantHomeCancelledToday => 'Cancelled today';

  @override
  String get merchantHomeSalesToday => 'Food sales today';

  @override
  String get merchantHomeOpenOrders => 'Open orders';

  @override
  String get merchantStatsIneligible =>
      'Your shop is not approved to sell yet. Statistics appear after approval.';

  @override
  String get supportAttachTitle => 'Photos (optional)';

  @override
  String get supportAttachCamera => 'Camera';

  @override
  String get supportAttachGallery => 'Gallery';

  @override
  String get supportAttachRemove => 'Remove photo';

  @override
  String supportAttachCount(int count, int max) {
    return '$count/$max photos';
  }

  @override
  String supportAttachPhoto(int n) {
    return 'Photo $n';
  }

  @override
  String supportAttachFile(int n) {
    return 'File $n';
  }

  @override
  String get supportAttachPdfNote =>
      'The PDF is stored with the request; DealGo staff can open it in the admin console.';

  @override
  String get supportAttachOpenFailed =>
      'Could not open the file. Please try again.';

  @override
  String get supportAttachTooLarge =>
      'The photo is too large. Choose a smaller one.';

  @override
  String get supportAttachBadType => 'This file type is not supported.';

  @override
  String get supportAttachUnavailable =>
      'Attachments can\'t be sent right now. Send without photos or try later.';

  @override
  String get helpFaqLoadFailed => 'Could not load the FAQ.';

  @override
  String get helpFaqRetry => 'Retry';

  @override
  String get helpFaqEmpty =>
      'No FAQ yet. Send a support request and DealGo will reply in the app.';

  @override
  String get rideShareCopiedChip => 'Copied';

  @override
  String get rideShareNotActive =>
      'You can share once a driver has accepted the trip.';

  @override
  String get rideShareLimit =>
      'You already created 5 links for this trip. Reuse one you sent.';

  @override
  String get rideShareFailed => 'Could not create the link. Please try again.';

  @override
  String get foodRejectOutOfStock => 'Item out of stock';

  @override
  String get foodRejectStoreBusy => 'Store is too busy';

  @override
  String get foodRejectStoreClosing => 'Store is closing';

  @override
  String get foodRejectPriceChanged => 'Item price changed';

  @override
  String get foodRejectOther => 'Other reason';

  @override
  String foodRejectReasonLine(String reason) {
    return 'Reason: $reason';
  }

  @override
  String foodRejectReasonLineWithNote(String reason, String note) {
    return 'Reason: $reason — $note';
  }

  @override
  String get foodRejectedTitle => 'The store declined your order';

  @override
  String get merchantRejectReasonTitle => 'Reason (shown to the customer)';

  @override
  String get merchantRejectNoteRequired => 'Note for the customer (required)';

  @override
  String get merchantRejectNoteOptional => 'Note for the customer (optional)';

  @override
  String get merchantRejectNoteMissing =>
      'Add a note when choosing \"Other reason\".';

  @override
  String get vouchersUse => 'Use for food order';

  @override
  String vouchersUseDone(String code) {
    return 'Code $code added to your cart (and copied). It is checked again at checkout.';
  }

  @override
  String get vouchersFootnote =>
      'Offers are managed by DealGo. The actual discount is calculated at checkout.';

  @override
  String voucherPercent(int percent) {
    return '$percent% off';
  }

  @override
  String voucherPercentMax(int percent, String max) {
    return '$percent% off, up to $max';
  }

  @override
  String voucherFixed(String amount) {
    return '$amount off';
  }

  @override
  String voucherDelivery(String amount) {
    return '$amount off delivery';
  }

  @override
  String voucherMinOrder(String amount) {
    return 'Orders from $amount';
  }

  @override
  String voucherEnds(String date) {
    return 'Until $date';
  }

  @override
  String voucherUsesLeft(int count) {
    return '$count uses left';
  }

  @override
  String get homeVoucherSeeAll => 'Hunt deals';

  @override
  String get rideQuoteExpiredNote =>
      'Get a new quote before confirming; an old quote can\'t be reused.';

  @override
  String get rideQuoteExpiredBadge => 'Expired';

  @override
  String get driverCounterNote =>
      'Keep the customer\'s fare to accept, or enter another amount to counter. The fare is only final once the customer confirms.';

  @override
  String get foodTrackingReconnectNote =>
      'When you\'re back online, the app loads the latest order status.';

  @override
  String get foodCancelledBrowse => 'Choose another store';

  @override
  String get rideMatchingReceiving => 'Receiving offers';

  @override
  String get rideMatchingSearching => 'Finding drivers';

  @override
  String get rideMatchingLoadFailed =>
      'Could not load the request. The trip status has not changed.';

  @override
  String get rideMatchingSent => 'Offer sent';

  @override
  String get rideMatchingWaiting => 'Waiting for drivers to make offers...';

  @override
  String get rideMatchingWaitingHint =>
      'Matching offers will appear here so you can compare and pick your driver.';

  @override
  String get rideStatusLabel => 'Status';

  @override
  String get rideNoOffersTitle => 'No driver offers yet';

  @override
  String get rideNoOffersMessage =>
      'There are no valid offers for this request in your area yet.';

  @override
  String get rideProgress => 'Progress';

  @override
  String get rideProgressSent => 'Request sent';

  @override
  String get rideProgressReceiving => 'Receiving offers from drivers';

  @override
  String get rideProgressChoose => 'Waiting for you to choose and confirm';

  @override
  String get rideMatchingRefreshFailed =>
      'Could not refresh the request. The trip status has not changed.';

  @override
  String get rideViewOffers => 'View offers';

  @override
  String get rideCancelSearch => 'Cancel search';

  @override
  String get rideTimeoutTitle => 'No driver found';

  @override
  String get rideTimeoutMessage =>
      'Matching time is over. No driver accepted the request.';

  @override
  String get rideCurrentRoute => 'Selected route';

  @override
  String get rideCurrentOfferedFare => 'Current offered fare';

  @override
  String get rideOfferedFare => 'Offered fare';

  @override
  String get rideTimeoutNote =>
      'The previous request has expired. Tap \"Find a driver again\" to send a new request.';

  @override
  String get rideEditRoute => 'Edit route';

  @override
  String get rideFindAgain => 'Find a driver again';

  @override
  String get rideAssignedNote =>
      'A driver accepted the trip. Open tracking to see the agreed fare.';

  @override
  String get rideTrack => 'Track trip';

  @override
  String get rideCancelledNote =>
      'The request was cancelled. Your offer is no longer valid.';

  @override
  String get rideConfirmTitle => 'Confirm ride';

  @override
  String get rideConfirmNoAgreed =>
      'The agreed fare for this trip has not arrived yet. Please try again.';

  @override
  String get rideConfirmNewPrice => 'Confirm new fare';

  @override
  String get rideFareChangedTitle => 'The fare just changed';

  @override
  String get rideFareChangedMessage =>
      'Trip conditions changed, so the old offer is no longer valid. Review the agreed fare before you accept.';

  @override
  String get rideCompareFares => 'Compare fares';

  @override
  String get rideFareYouPicked => 'Fare you picked';

  @override
  String get rideFareDifference => 'Difference';

  @override
  String get rideFareChangedNote =>
      'DealGo never changes what you pay on its own. The fare that applies is the agreed fare above.';

  @override
  String get rideChosenRoute => 'Chosen route';

  @override
  String get rideOfferAgreed => 'Agreed offer';

  @override
  String get rideStillValid => 'Still valid';

  @override
  String get rideFare => 'Fare';

  @override
  String get rideCustomerPays => 'You pay';

  @override
  String get ridePaymentMethod => 'Payment method';

  @override
  String get rideCashNote => 'Paid only when the trip is completed';

  @override
  String get rideConfirmPriceNote =>
      'If the fare changes, DealGo asks you to review and confirm again before it applies.';

  @override
  String get rideFarePendingExists =>
      'You already have a pending offer. Open it or cancel it before sending a new fare.';

  @override
  String get rideFareSendFailed => 'Could not send your offer.';

  @override
  String get rideFareTitle => 'Propose your fare';

  @override
  String get rideBookingInfo => 'Booking details';

  @override
  String get rideFareAsk => 'The fare you want to offer';

  @override
  String get rideYourOffer => 'Your offer';

  @override
  String get rideEnterAmount => 'Enter amount';

  @override
  String get rideFairNegotiation => 'Transparent negotiation';

  @override
  String get rideFairNegotiationNote =>
      'Drivers may offer a different fare. You only pay the amount of the offer you chose and confirmed.';

  @override
  String get rideFareOffline =>
      'Your offer was not sent. The trip has not been created.';

  @override
  String get rideSeeDriverOffers => 'See driver offers';

  @override
  String get rideNoAgreedYet => 'The fare has not been agreed yet.';

  @override
  String get rideSelectFailed => 'Could not select the offer.';

  @override
  String get rideCancelFailed => 'Could not cancel the request.';

  @override
  String get rideDriverOffers => 'Driver offers';

  @override
  String get rideRequestCancelled => 'Request cancelled';

  @override
  String get rideOfferInvalid => 'The offer is no longer valid.';

  @override
  String get rideAgreedTitle => 'Trip confirmed';

  @override
  String get rideAgreedMissing => 'The agreed fare has not arrived yet.';

  @override
  String get rideOffersLoadFailed =>
      'Could not load offers. The trip is not confirmed.';

  @override
  String get rideCurrentQuoteFare => 'Current offered fare';

  @override
  String get rideTripCode => 'Trip code';

  @override
  String get rideNoOffersHint =>
      'You can change your offered fare or try again later.';

  @override
  String get rideListRefreshFailed => 'Could not refresh the list.';

  @override
  String get rideChangeOffer => 'Change offer';

  @override
  String get rideQuoteExpiredTitle => 'Offer expired';

  @override
  String get rideQuoteExpiredMessage =>
      'The old offer can no longer be chosen because it expired.';

  @override
  String get rideOldFare => 'Old fare (for reference)';

  @override
  String get rideFindNewOffers => 'Find new offers';

  @override
  String get rideOfferTakenTitle => 'The driver took another job';

  @override
  String get rideOfferTakenMessage =>
      'The offer you picked was no longer available when you confirmed.';

  @override
  String get ridePreviousOffer => 'Previous offer';

  @override
  String get rideOfferTakenNote =>
      'The list may be out of date. Refresh and pick another offer.';

  @override
  String get rideRefreshList => 'Refresh list';

  @override
  String get rideSeeOtherDrivers => 'See other drivers';

  @override
  String get rideOfferList => 'Offers';

  @override
  String get rideRouteAndFare => 'Route & offered fare';

  @override
  String get rideLowestFirst => 'Lowest price';

  @override
  String get rideOffersNote =>
      'Only the offer you confirm becomes a trip. Offers you have not picked may expire.';

  @override
  String get rideSelectOffline =>
      'Your choice was not sent. The fare is not agreed yet.';

  @override
  String rideAcceptAmount(String amount) {
    return 'Accept $amount';
  }

  @override
  String rideRecordedAmount(String amount) {
    return 'Recorded $amount';
  }

  @override
  String rideCustomerPaysAmount(String amount) {
    return 'You pay $amount.';
  }

  @override
  String rideOffersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matching offers',
      one: '1 matching offer',
    );
    return '$_temp0';
  }

  @override
  String rideSendOffer(String amount) {
    return 'Send offer $amount';
  }

  @override
  String get rideVehicleMotorbike => 'Motorbike';

  @override
  String get rideOfferKindAccept => 'Matches your offer';

  @override
  String get rideOfferKindCounter => 'Counter-offer';

  @override
  String get rideOfferUnavailable => 'No longer available';

  @override
  String get rideOfferJustInvalid => 'Offer just became invalid';

  @override
  String get rideOfferExpiredShort => 'Offer expired';

  @override
  String get rideYouAreOffline => 'You are offline';

  @override
  String get driverServicesOfflineTitle => 'Offline';

  @override
  String get driverServicesOfflineBody => 'Switch on to start taking jobs';

  @override
  String get driverServicesNotRegistered => 'Not in your application';

  @override
  String get driverServicesNoneOn =>
      'Both services are off, so you will not get new jobs.';

  @override
  String driverVehiclePlate(String plate) {
    return 'Plate $plate';
  }

  @override
  String get driverVehicleUnknown =>
      'No plate number in your driver application';

  @override
  String get driverServicesSaved =>
      'Saved. The job list only shows the services you have switched on.';

  @override
  String get driverServicesSaveFailed =>
      'Your choice was not saved. Check your connection and try again.';

  @override
  String get driverHomeTitle => 'Driver overview';

  @override
  String get driverSeeHistory => 'View history';

  @override
  String get driverGoOnline => 'Go online';

  @override
  String get driverOfflineHeroMessage =>
      'Go online to see ride requests and food deliveries near you.';

  @override
  String get driverDutyStatus => 'Duty status';

  @override
  String get driverOfflineChip => 'Offline · Not taking jobs';

  @override
  String get driverServiceTypes => 'Services';

  @override
  String get driverNoServiceOn => 'No service switched on';

  @override
  String get driverContactSupport => 'Contact support';

  @override
  String get driverOpenApplication => 'Open driver application';

  @override
  String get driverIneligibleTitle => 'You cannot take jobs yet';

  @override
  String get driverIneligibleMessage =>
      'Your driver account is not approved yet or is suspended, so you cannot take rides or deliveries.';

  @override
  String get driverRightsByService => 'Access by service';

  @override
  String get driverServicePassenger => 'Rides';

  @override
  String get driverServiceBlocked => 'Not available';

  @override
  String get driverIneligibleNote =>
      'Open your driver application to see its review status and anything you need to add. If your account is suspended, contact support.';

  @override
  String get driverAllowedServices => 'Services you take';

  @override
  String get driverConfigure => 'Settings';

  @override
  String get driverOnlinePolicyNote =>
      'Fares and job access are checked by DealGo. Each driver handles one job at a time.';

  @override
  String get driverOnlineBadge => 'Online';

  @override
  String get driverOnDutyMapLabel => 'Taking jobs';

  @override
  String get driverRideLoadFailed =>
      'Could not load the ride. Check your connection and try again.';

  @override
  String get driverRideDetailTitle => 'Ride request details';

  @override
  String get driverMakeOffer => 'Make an offer';

  @override
  String get driverRideChip => 'Ride · Motorbike';

  @override
  String get driverCustomerFare => 'Customer\'s fare';

  @override
  String get driverReferenceFare => 'Reference fare';

  @override
  String get driverOfferCount => 'Offers so far';

  @override
  String get driverOfferSendFailed =>
      'Could not send your offer. Please try again.';

  @override
  String get driverOfferTitle => 'Negotiate the fare';

  @override
  String get driverSendOffer => 'Send offer';

  @override
  String get driverCustomerRequest => 'Customer request';

  @override
  String get driverVehicle => 'Vehicle';

  @override
  String get driverOfferSent => 'Offer sent';

  @override
  String get driverOfferWaitingAccept =>
      'Customer\'s fare · Waiting for the customer';

  @override
  String get driverOfferWaitingCounter =>
      'Your fare · Waiting for the customer';

  @override
  String get driverOfferChosen => 'The customer chose you';

  @override
  String get driverOfferLost => 'Not chosen';

  @override
  String get driverWaitingForCustomer => 'Waiting for the customer';

  @override
  String get driverWaitingForCustomerBody =>
      'This screen updates when the customer picks your offer.';

  @override
  String get driverReadyToNavigate => 'Ready to pick up';

  @override
  String get driverReadyToNavigateBody =>
      'Open pickup navigation to start the trip.';

  @override
  String get driverOfferLostBody =>
      'The customer chose another driver or the ride was cancelled.';

  @override
  String get driverOpenPickupNavigation => 'Open pickup navigation';

  @override
  String get driverYourOffer => 'Your offer';

  @override
  String get currencySuffixVnd => '₫';

  @override
  String get driverOfferAmount => 'Offer amount';

  @override
  String get driverOfferKind => 'Type';

  @override
  String get driverOfferKindAccept => 'Accept customer\'s fare';

  @override
  String get driverOfferKindCounter => 'Propose another fare';

  @override
  String get driverOfferKindNote =>
      'Sending the customer\'s fare accepts it; any other amount is a new proposal for the customer to consider.';

  @override
  String get driverOfferHintSame => 'You are accepting the customer\'s fare.';

  @override
  String get driverOfferHintCounter =>
      'Different from the customer\'s fare. They will see it as your proposal.';

  @override
  String get driverOpenJobDetails => 'View job details';

  @override
  String get driverLoadingRequests => 'Loading requests';

  @override
  String get driverNoOpenRequests => 'No open requests right now';

  @override
  String get driverRidesAvailable => 'Rides you can take';

  @override
  String get driverFoodAvailable => 'Deliveries you can take';

  @override
  String get driverOneJobNote => 'Each driver handles one job at a time.';

  @override
  String driverFoodJobSummary(int count, String dropoff) {
    return '$count items · $dropoff';
  }

  @override
  String get driverDeliveryFare => 'Delivery fee';

  @override
  String get driverDeliveryFareNote =>
      'Earnings are settled after delivery. You can take the job only after the store confirms the order.';

  @override
  String get driverLoadRequestsFailed =>
      'Could not load requests. Please try again.';

  @override
  String get driverRequestTitle => 'Request';

  @override
  String get driverRequestNotFound =>
      'Request not found. It may have been taken or expired.';

  @override
  String get apiErrGeneric => 'Something went wrong. Please try again.';

  @override
  String get apiErrNetwork =>
      'Can\'t reach DealGo. Check your connection and try again.';

  @override
  String get apiErrInvalidResponse =>
      'We couldn\'t read the response. Please try again.';

  @override
  String get apiErrForbidden => 'You don\'t have permission to do this.';

  @override
  String get apiErrNotFound =>
      'Not found. It may have been removed or changed.';

  @override
  String get apiErrConflict => 'This just changed. Reload and try again.';

  @override
  String get apiErrGone => 'This has expired.';

  @override
  String get apiErrTooLarge => 'The file is too large.';

  @override
  String get apiErrBadType => 'This file type isn\'t supported.';

  @override
  String get apiErrTooMany => 'Too many attempts. Wait a moment and try again.';

  @override
  String get apiErrServer =>
      'DealGo is having trouble. Please try again later.';

  @override
  String get apiErrRoleNotActive =>
      'This role isn\'t approved yet or is suspended.';

  @override
  String get apiErrRoleSuspended =>
      'This role is suspended. Contact support for details.';

  @override
  String get apiErrValidation =>
      'Some details aren\'t valid. Please check and try again.';

  @override
  String get apiErrRideNotFound => 'Ride not found.';

  @override
  String get apiErrRideChanged => 'The ride just changed. Please reload.';

  @override
  String get apiErrRideNotCancellable =>
      'The ride can\'t be cancelled at this stage.';

  @override
  String get apiErrFareOutOfRange => 'The fare is outside the allowed range.';

  @override
  String get apiErrRideAlreadyOpen => 'You already have a ride in progress.';

  @override
  String get apiErrNegotiationLimit =>
      'No more fare negotiation rounds for this ride.';

  @override
  String get apiErrSelfAction => 'You can\'t take your own request.';

  @override
  String get apiErrNotYourJob => 'This job is no longer assigned to you.';

  @override
  String get apiErrOrderNotFound => 'Order not found.';

  @override
  String get apiErrOrderChanged => 'The order just changed. Please reload.';

  @override
  String get apiErrJobTaken => 'Another driver already took this job.';

  @override
  String get apiErrOrderNotCancellable =>
      'The order can\'t be cancelled at this stage.';

  @override
  String get apiErrNotStoreOwner => 'Your account doesn\'t manage this store.';

  @override
  String get apiErrItemNotFound => 'Item not found.';

  @override
  String get apiErrVoucherNotFound => 'This promo code doesn\'t exist.';

  @override
  String get apiErrVoucherEnded => 'This promo code has ended or is paused.';

  @override
  String get apiErrVoucherNotStarted => 'This promo code hasn\'t started yet.';

  @override
  String get apiErrVoucherMinOrder =>
      'The minimum amount for this code isn\'t met.';

  @override
  String get apiErrVoucherUsedUp => 'This promo code has been fully used.';

  @override
  String get apiErrVoucherUserLimit =>
      'You\'ve used this code the maximum number of times.';

  @override
  String get apiErrVoucherWrongService =>
      'This promo code doesn\'t apply to this service.';

  @override
  String get merchantLoadingOrders => 'Loading orders';

  @override
  String get merchantIneligibleTitle => 'Your store can\'t take orders yet';

  @override
  String get merchantIneligibleMessage =>
      'Your store account isn\'t approved yet or is suspended, so it can\'t receive orders.';

  @override
  String get merchantIneligibleNote =>
      'Check your store application under Account. If it\'s suspended, contact support.';

  @override
  String get merchantReloadOrders => 'Reload orders';

  @override
  String get merchantNoNewOrders => 'No new orders';

  @override
  String get merchantNoNewOrdersBody =>
      'New orders show up here as soon as customers place them.';

  @override
  String get merchantNoNewOrdersNote =>
      'Turn on notifications so you don\'t miss new orders.';

  @override
  String get merchantViewSavedOrders => 'View saved orders';

  @override
  String get merchantOrdersLoadFailed => 'Couldn\'t load orders';

  @override
  String get merchantOrdersLoadFailedBody =>
      'The connection is unstable, so the order list may be out of date.';

  @override
  String get merchantConnection => 'Connection';

  @override
  String get merchantLoadFailedChip => 'Load failed';

  @override
  String get merchantLastSynced => 'Last synced';

  @override
  String get merchantLoadFailedNote =>
      'A connection error doesn\'t mean there are no orders. Retry to see new ones.';

  @override
  String get merchantNoSavedOrders => 'No orders saved on this device.';

  @override
  String get merchantSavedOrders => 'Saved orders';

  @override
  String get merchantItemInvalid => 'Item name and price aren\'t valid.';

  @override
  String get merchantItemUpdateFailed => 'Couldn\'t update the item.';

  @override
  String get merchantItemCreateFailed => 'Couldn\'t add the item.';

  @override
  String get foodStagePreparing => 'Preparing your food';

  @override
  String get foodStageOnTheWay => 'On the way';

  @override
  String get foodStageCancelled => 'Order cancelled';

  @override
  String get foodStageUnknown => 'Order status unknown';

  @override
  String merchantMenuSummary(int available, int total) {
    return '$available on sale · $total items in total';
  }

  @override
  String get merchantAddItem => 'Add item';

  @override
  String get merchantItemName => 'Item name';

  @override
  String get merchantItemPrice => 'Price (VND)';

  @override
  String get merchantPriceInvalid => 'Invalid price';

  @override
  String get merchantItemOnSale => 'On sale';

  @override
  String get merchantItemSoldOut => 'Sold out';

  @override
  String get foodOrderSentTitle => 'Order sent';

  @override
  String get foodOrderPlaced => 'Order placed';

  @override
  String get foodOrderPlacedSub => 'The store will confirm your order shortly';

  @override
  String get foodPayOnDelivery => 'Pay on delivery';

  @override
  String get foodCashNotPaid => 'Cash · Not paid yet';

  @override
  String get foodStepSent => 'Order sent';

  @override
  String get foodStepAwaitStore => 'Waiting for the store';

  @override
  String get foodStepNotPreparing => 'Not being prepared yet';

  @override
  String get foodOrderPlacedNote =>
      'Your order is in. You pay in cash on delivery; track it to see when the store confirms.';

  @override
  String get foodTrackOrder => 'Track order';

  @override
  String get foodReconnecting => 'Reconnecting...';

  @override
  String get foodReconnectingBody =>
      'Live updates are paused. Your order is still being handled.';

  @override
  String get foodOrderInProgress => 'Order in progress';

  @override
  String get foodCustomerPays => 'You pay';

  @override
  String get foodLastKnownStatus => 'Last known status';

  @override
  String get actionClose => 'Close';

  @override
  String foodLineQtyPrice(int quantity, String price) {
    return 'x$quantity · $price each';
  }

  @override
  String get homeSearchHint => 'Search places, stores, dishes...';

  @override
  String get homeHeroTitle => 'One app,\nendless options';

  @override
  String get homeHeroSubtitle =>
      'Ride • Shop • Delivery\nEveryday convenience in Da Nang';

  @override
  String get homeHeroCity => '~ Da Nang, always close by';

  @override
  String get homeServiceFoodSub => 'Thousands of stores,\ndelivered';

  @override
  String get voiceOpenFailed => 'Couldn\'t start the call. Please try again.';

  @override
  String get mapIllustrative => 'Illustrative map';

  @override
  String get rideVoucherTitle => 'Voucher';

  @override
  String get rideVoucherNote =>
      'The code is reserved when you pick a driver and returned if the trip is cancelled.';

  @override
  String rideVoucherLine(String code) {
    return 'Voucher $code';
  }

  @override
  String get rideCashDueLabel => 'Cash to the driver';

  @override
  String rideVoucherDropped(String reason) {
    return '$reason You can select again without the code.';
  }

  @override
  String driverCashToCollect(String amount) {
    return 'Collect $amount in cash';
  }

  @override
  String driverVoucherFunded(String amount) {
    return 'Customer voucher $amount; DealGo pays you this part.';
  }

  @override
  String get merchantBusyEyebrow => 'SERVICE CAPACITY';

  @override
  String get merchantBusyHeading => 'Store status';

  @override
  String get merchantBusyIntro =>
      'Adjust order intake when the kitchen is overloaded or needs a break.';

  @override
  String get merchantBusyAccepting => 'Taking orders';

  @override
  String get merchantBusyNotAccepting => 'Not taking orders';

  @override
  String merchantBusyAcceptingBody(String store) {
    return 'Customers can order from $store.';
  }

  @override
  String get merchantBusyNotAcceptingBody =>
      'Customers can\'t place new orders until you reopen.';

  @override
  String merchantBusyResumesAt(String time) {
    return 'Reopens automatically at $time';
  }

  @override
  String get merchantBusyResumeLabel => 'Auto-reopen';

  @override
  String merchantBusyResumeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String merchantBusyResumeHours(int hours) {
    return '$hours h';
  }

  @override
  String get merchantBusyResumeManual => 'Manual';

  @override
  String get merchantBusyPolicyNote =>
      'Confirmed orders still need to be served or handled per policy; pausing does not cancel them.';

  @override
  String get merchantBusySave => 'Save store status';

  @override
  String get merchantBusySaved => 'Store status saved.';

  @override
  String get checkoutErrStorePaused =>
      'This store isn\'t taking orders right now. Please try again later.';

  @override
  String get foodStorePausedBanner => 'This store has paused new orders.';

  @override
  String get foodStoreBusyBanner =>
      'The kitchen is busy — prep may take longer.';

  @override
  String get merchantHomeBusyChip => 'Busy';

  @override
  String get merchantHomePausedChip => 'Paused';

  @override
  String get merchantHoursEyebrow => 'BUSINESS HOURS';

  @override
  String get merchantHoursHeading => 'Opening schedule';

  @override
  String get merchantHoursIntro =>
      'Set opening hours, days off and the last-order cut-off.';

  @override
  String get merchantHoursUnset =>
      'No hours saved yet, so the store takes orders all day. Save the schedule below to apply it.';

  @override
  String get merchantHoursWeekly => 'Weekly schedule';

  @override
  String get merchantHoursClosedShort => 'Closed';

  @override
  String get merchantHoursClosures => 'Special days off';

  @override
  String get merchantHoursAddClosure => '+ Add day off';

  @override
  String get merchantHoursNoClosures => 'No special days off.';

  @override
  String get merchantHoursRemoveClosure => 'Remove';

  @override
  String get merchantHoursCutoffTitle => 'Stop orders before closing';

  @override
  String get merchantHoursCutoffHint =>
      'Don\'t accept orders too close to closing.';

  @override
  String get merchantHoursCutoffNone => 'None';

  @override
  String get merchantHoursEnforcedNote =>
      'Hours appear on your store page and are enforced when customers order. A closing time earlier than opening means the shift runs overnight into the next morning.';

  @override
  String get merchantHoursSave => 'Save schedule';

  @override
  String get merchantHoursSaved => 'Schedule saved.';

  @override
  String merchantHoursInvalidRange(String day) {
    return '$day: closing time can\'t equal opening time.';
  }

  @override
  String get dayShortMon => 'Mon';

  @override
  String get dayShortTue => 'Tue';

  @override
  String get dayShortWed => 'Wed';

  @override
  String get dayShortThu => 'Thu';

  @override
  String get dayShortFri => 'Fri';

  @override
  String get dayShortSat => 'Sat';

  @override
  String get dayShortSun => 'Sun';

  @override
  String get checkoutErrStoreClosed =>
      'This store is closed right now. Please come back later.';

  @override
  String get merchantHoursErrInvalid =>
      'The schedule is invalid. Check opening times and days off.';

  @override
  String get foodStoreClosedLabel => 'Closed';

  @override
  String get foodStorePausedLabel => 'Paused';

  @override
  String get foodStoreClosedBanner =>
      'This store is outside its ordering hours.';

  @override
  String foodStoreHoursToday(String range) {
    return 'Today: $range';
  }

  @override
  String get foodStoreHoursTodayOff => 'Closed today.';

  @override
  String get merchantAcceptEyebrow => 'OPERATIONS SETUP';

  @override
  String get merchantAcceptHeading => 'Order intake setup';

  @override
  String get merchantAcceptIntro =>
      'Control how the store takes in new orders.';

  @override
  String merchantAcceptStoreState(String state) {
    return 'Status: $state';
  }

  @override
  String get merchantAcceptStateOpen => 'taking orders';

  @override
  String get merchantAcceptStateBusy => 'kitchen busy';

  @override
  String get merchantAcceptStatePaused => 'paused';

  @override
  String get merchantAcceptStateClosed => 'outside opening hours';

  @override
  String get merchantAcceptLimits => 'Operating limits';

  @override
  String get merchantAcceptMaxActive => 'Max orders in progress';

  @override
  String get merchantAcceptMaxActiveHint =>
      'Avoid taking more than the kitchen can handle';

  @override
  String merchantAcceptOrdersCount(int count) {
    return '$count orders';
  }

  @override
  String get merchantAcceptNoLimit => 'No limit';

  @override
  String get merchantAcceptPrep => 'Default prep time';

  @override
  String get merchantAcceptPrepHint => 'Used to estimate when orders are ready';

  @override
  String get merchantAcceptCutoff => 'Orders near closing';

  @override
  String get merchantAcceptCutoffHint => 'Stop taking orders before closing';

  @override
  String get merchantAcceptPolicyNote =>
      'Orders in progress are not cancelled when you change modes. Finish pending orders before you stop taking orders.';

  @override
  String get merchantAcceptSave => 'Save settings';

  @override
  String get merchantAcceptSaved => 'Order acceptance settings saved.';

  @override
  String get merchantAcceptPickTitle => 'Choose a value';

  @override
  String get merchantBusyExtraLabel => 'Extra prep time while busy';

  @override
  String merchantBusyExtraHint(int minutes) {
    return 'Customers will see a prep time of about $minutes min.';
  }

  @override
  String foodStorePrepEstimate(int minutes) {
    return 'Prep about $minutes min';
  }

  @override
  String foodTrackingReadyBy(String time) {
    return 'Food expected ready at $time';
  }

  @override
  String get checkoutErrStoreAtCapacity =>
      'The store has too many orders right now. Please try again in a few minutes.';

  @override
  String get merchantHoursNextDay => 'next day';

  @override
  String foodStoreHoursOvernight(String range) {
    return '$range (until next morning)';
  }

  @override
  String get homeSearchChooseTitle => 'What are you looking for?';

  @override
  String homeSearchAsFood(String query) {
    return 'Stores and dishes: “$query”';
  }

  @override
  String homeSearchAsPlace(String query) {
    return 'Ride destination: “$query”';
  }

  @override
  String trackingDriverLiveAt(String time) {
    return 'Driver location at $time';
  }

  @override
  String get foodStageFailed => 'Delivery failed';

  @override
  String foodItemOptionsUpTo(int count) {
    return 'Up to $count';
  }

  @override
  String get foodItemOptionsSoldOut => 'Sold out';

  @override
  String get apiErrFoodOptionInvalid =>
      'This dish\'s options changed or are incomplete. Please choose again.';

  @override
  String merchantOptionsBasePrice(String price) {
    return 'Base price $price';
  }

  @override
  String get merchantOptionsAddChoice => '+ Add choice';

  @override
  String get merchantOptionsAddGroup => '+ Add option group';

  @override
  String get merchantOptionsEmpty =>
      'No options yet. Add a group such as Size or Topping for customers to choose.';

  @override
  String get merchantOptionsRuleRequiredOne => 'Required · pick 1';

  @override
  String get merchantOptionsRuleOptionalOne => 'Optional · pick 1';

  @override
  String merchantOptionsRuleUpTo(int max) {
    return 'Optional · up to $max';
  }

  @override
  String merchantOptionsRuleRange(int min, int max) {
    return 'Required · pick $min–$max';
  }

  @override
  String get merchantOptionsSoldOut => 'Sold out';

  @override
  String get merchantOptionsGroupDialogTitle => 'Option group';

  @override
  String get merchantOptionsGroupName => 'Group name (e.g. Size, Topping)';

  @override
  String get merchantOptionsMin => 'Customer must pick at least';

  @override
  String get merchantOptionsMax => 'Customer may pick up to';

  @override
  String get merchantOptionsChoiceDialogTitle => 'Choice';

  @override
  String get merchantOptionsChoiceName => 'Choice name';

  @override
  String get merchantOptionsChoicePrice => 'Extra price (VND)';

  @override
  String get merchantOptionsChoiceAvailable => 'Available';

  @override
  String get merchantOptionsDelete => 'Delete';

  @override
  String get merchantOptionsApply => 'Done';

  @override
  String get merchantOptionsSaved => 'Dish options saved';

  @override
  String get merchantOptionsInvalidGroup =>
      'Each group needs a unique name, at least one distinct choice, and min ≤ max ≤ number of choices.';

  @override
  String get merchantOptionsServerHint =>
      'Customers see the extra price; the server re-prices at checkout. Placed orders keep their original choices.';

  @override
  String get merchantOptionsItemMissing => 'Dish not found in the menu.';

  @override
  String get merchantOptionsUnsaved => 'Unsaved changes';

  @override
  String get driverFoodNoStorePoint =>
      'The store has no map point yet — follow its address.';

  @override
  String get driverNavGoogleMaps => 'Google Maps';

  @override
  String get driverNavWaze => 'Waze';

  @override
  String get driverNavOpenFailed =>
      'Couldn\'t open a navigation app. Follow the in-app map.';

  @override
  String get driverFoodDeliveryCodeTitle => 'Delivery code';

  @override
  String get driverFoodDeliveryCodeBody =>
      'Ask the customer for the 4-digit code in their DealGo app to complete the delivery.';

  @override
  String get driverFoodHandoverCodeTitle => 'Handover code';

  @override
  String get driverFoodHandoverCodeBody =>
      'Enter the 4-digit code the store shows on its handover screen.';

  @override
  String get driverFoodCodeWrong => 'That code doesn\'t match. Check again.';

  @override
  String get driverFoodCodeLocked =>
      'Too many wrong codes. Contact support about this order.';

  @override
  String get driverFoodCodeSubmit => 'Confirm';

  @override
  String get foodDeliveryCodeTitle => 'Delivery code';

  @override
  String get foodDeliveryCodeHint =>
      'Give this code to the courier when you receive your order. Don\'t share it before then.';

  @override
  String get merchantHandoverCodeLabel => 'Handover code';

  @override
  String get merchantHandoverCodeHint =>
      'The driver enters this code when collecting the order. Only give it to the assigned driver.';

  @override
  String get accountDeleteRow => 'Delete account';

  @override
  String get accountDeleteRowBody =>
      'Request permanent deletion of your DealGo account';

  @override
  String get deleteAccountHeader => 'Delete account';

  @override
  String get deleteAccountTitle => 'Request account deletion';

  @override
  String get deleteAccountSubtitle =>
      'This may cost you access to DealGo services.';

  @override
  String get deleteAccountWarnTitle =>
      'Please read carefully before continuing';

  @override
  String get deleteAccountWarnBody =>
      'A deleted account may not be recoverable once deletion completes.';

  @override
  String get deleteAccountWhatHappens => 'What will happen?';

  @override
  String get deleteAccountNoLoginTitle => 'You can\'t sign in';

  @override
  String get deleteAccountNoLoginBody =>
      'You will no longer be able to use this account';

  @override
  String get deleteAccountDataTitle => 'Account data';

  @override
  String get deleteAccountHistoryTitle => 'Transaction history';

  @override
  String get deleteAccountHistoryBody =>
      'Some records may have to be kept by law';

  @override
  String get deleteAccountBefore => 'Before you submit';

  @override
  String get deleteAccountCheckNoJobs => 'No ride or order in progress';

  @override
  String get deleteAccountCheckBackup => 'I have saved the information I need';

  @override
  String get deleteAccountTypeLabel => 'Type XÓA to confirm';

  @override
  String get deleteAccountTypeHint => 'XÓA';

  @override
  String get deleteAccountTypeHelper =>
      'You will verify your identity before the request is sent.';

  @override
  String get deleteAccountContinue => 'Continue deletion request';

  @override
  String get deleteAccountKeep => 'Keep my account';

  @override
  String get deleteAccountVerifyTitle => 'Verify it\'s you';

  @override
  String get deleteAccountPasswordBody =>
      'Enter your account password to confirm deletion.';

  @override
  String get deleteAccountPasswordLabel => 'Password';

  @override
  String get deleteAccountCodeLabel => 'Verification code';

  @override
  String get deleteAccountConfirm => 'Confirm account deletion';

  @override
  String get deleteAccountRestart => 'Start again';

  @override
  String get deleteAccountDoneTitle => 'Deletion request received';

  @override
  String get deleteAccountDoneAction => 'Back to sign in';

  @override
  String get deleteAccountLoadError =>
      'Couldn\'t load account deletion details.';

  @override
  String get deleteAccountReauthUnavailable =>
      'This account has no verified phone or password to verify with. Please contact support.';

  @override
  String get deleteAccountWrongPassword => 'Wrong password.';

  @override
  String get deleteAccountWrongCode => 'Wrong verification code.';

  @override
  String get deleteAccountLocked =>
      'Too many wrong attempts. Start again to get a new code.';

  @override
  String get deleteAccountExpired => 'The request expired. Start again.';

  @override
  String get deleteBlockerOps =>
      'Operations staff accounts can\'t be deleted in the app. Contact your administrator.';

  @override
  String get apiErrAccountDeleted =>
      'This account has been deleted. To restore it, contact DealGo support during the waiting period.';

  @override
  String deleteAccountDataBody(int days) {
    return 'Personal data is permanently erased after $days days';
  }

  @override
  String deleteAccountCodeBody(String phone) {
    return 'Enter the 6-digit code sent to $phone.';
  }

  @override
  String deleteAccountDoneBody(String date) {
    return 'Your account is locked and signed out on every device. Personal data will be permanently erased on $date. If you change your mind, contact support before then.';
  }

  @override
  String deleteBlockerRide(int count) {
    return 'You have $count ride(s) in progress.';
  }

  @override
  String deleteBlockerFood(int count) {
    return 'You have $count food order(s) in progress.';
  }

  @override
  String deleteBlockerDriver(int count) {
    return 'You have $count driver job(s) in progress.';
  }

  @override
  String deleteBlockerStore(int count) {
    return 'Your store has $count open order(s).';
  }

  @override
  String deleteBlockerCod(String amount) {
    return '$amount of cash-job platform fees are not yet settled with DealGo.';
  }

  @override
  String get accountEditProfile => 'Edit profile';

  @override
  String get accountEditProfileBody => 'Update name, email and photo';

  @override
  String get accountNotifPrefs => 'Notification settings';

  @override
  String get accountNotifPrefsBody => 'Choose which updates you want';

  @override
  String get accountSecurity => 'Security & privacy';

  @override
  String get accountSecurityBody => 'Sign-in, devices and account deletion';

  @override
  String get editProfileHeader => 'Edit profile';

  @override
  String get editProfileChangePhoto => 'Change profile photo';

  @override
  String get editProfileName => 'Full name';

  @override
  String get editProfilePhone => 'Phone number';

  @override
  String get editProfilePhoneLocked => 'Phone is protected. Verify to change.';

  @override
  String get editProfileEmail => 'Email';

  @override
  String get editProfileDob => 'Date of birth (optional)';

  @override
  String get editProfileGender => 'Gender (optional)';

  @override
  String get editProfileGenderMale => 'Male';

  @override
  String get editProfileGenderFemale => 'Female';

  @override
  String get editProfileGenderOther => 'Other';

  @override
  String get editProfilePrivacy =>
      'Personal info is only used to improve your experience.';

  @override
  String get editProfileSave => 'Save changes';

  @override
  String get editProfileSaved => 'Profile saved';

  @override
  String get editProfileHint => 'You can update this anytime';

  @override
  String get notifPrefsHeader => 'Notification settings';

  @override
  String get notifPrefsTitle => 'Your notifications';

  @override
  String get notifPrefsSubtitle =>
      'Choose which updates you want. You can change this anytime.';

  @override
  String get notifPrefsPushOn => 'Push notifications are on';

  @override
  String get notifPrefsPushHint => 'Adjust in the app or device settings';

  @override
  String get notifPrefsImportant => 'Important';

  @override
  String get notifPrefsRide => 'Rides';

  @override
  String get notifPrefsRideBody => 'Driver accepts, arrives and completes';

  @override
  String get notifPrefsFood => 'Food and orders';

  @override
  String get notifPrefsFoodBody => 'Confirm, prepare and deliver';

  @override
  String get notifPrefsChat => 'Messages and calls';

  @override
  String get notifPrefsChatBody => 'Messages from people on your trips/orders';

  @override
  String get notifPrefsOther => 'Other';

  @override
  String get notifPrefsPromo => 'Offers and promotions';

  @override
  String get notifPrefsPromoBody => 'Discount codes and new campaigns';

  @override
  String get notifPrefsNews => 'DealGo news';

  @override
  String get notifPrefsNewsBody => 'Service and feature updates';

  @override
  String get notifPrefsMandatory =>
      'Some required transaction or security updates are still sent to protect your account.';

  @override
  String get notifPrefsSave => 'Save settings';

  @override
  String get notifPrefsSaved => 'Notification settings saved';

  @override
  String get securityHeader => 'Security & privacy';

  @override
  String get securityTitle => 'Account safety';

  @override
  String get securitySubtitle =>
      'Manage how you sign in and control personal data.';

  @override
  String get securityProtected => 'Account is protected';

  @override
  String get securityProtectedBody => 'Phone verified · enhance with Passkey';

  @override
  String get securityLoginSection => 'Sign-in and verification';

  @override
  String get securityPhone => 'Phone number';

  @override
  String get securityVerified => 'Verified';

  @override
  String get securityPasskey => 'Passkey';

  @override
  String get securityPasskeyBody => 'Sign in with biometrics or a device key';

  @override
  String get securitySessions => 'Devices and sessions';

  @override
  String get securitySessionsBody => 'View and sign out other devices';

  @override
  String get securityChangePassword => 'Change password';

  @override
  String get securityChangePasswordBody => 'Update your email login password';

  @override
  String get securityPrivacySection => 'Privacy';

  @override
  String get securityPermissions => 'App permissions';

  @override
  String get securityPermissionsBody =>
      'Location, notifications, mic when needed';

  @override
  String get securityTerms => 'Terms & personal data';

  @override
  String get securityTermsBody => 'View policies and your rights';

  @override
  String get securityAccountSection => 'Account management';

  @override
  String get securityDelete => 'Request account deletion';

  @override
  String get securityDeleteBody => 'See consequences and steps';

  @override
  String get changePasswordHeader => 'Change password';

  @override
  String get changePasswordCurrent => 'Current password';

  @override
  String get changePasswordNew => 'New password';

  @override
  String get changePasswordConfirm => 'Confirm new password';

  @override
  String get changePasswordSave => 'Update password';

  @override
  String get changePasswordMismatch => 'New passwords do not match.';

  @override
  String get changePasswordDone => 'Password updated';

  @override
  String get sessionsHeader => 'Signed-in devices';

  @override
  String get sessionsTitle => 'Active sessions';

  @override
  String get sessionsSubtitle =>
      'See where you are signed in and revoke sessions.';

  @override
  String get sessionsWarn =>
      'If you see an unknown device, sign it out and check your verification methods.';

  @override
  String get sessionsCurrent => 'This device';

  @override
  String get sessionsThisDevice => 'This device';

  @override
  String get sessionsOthers => 'Other sessions';

  @override
  String get sessionsLogout => 'Sign out';

  @override
  String get sessionsLogoutOthers => 'Sign out all other devices';

  @override
  String get sessionsEmptyOthers => 'No other devices are signed in.';

  @override
  String get sessionsRevoked => 'Device signed out';

  @override
  String get merchantHistoryTitle => 'Order history';

  @override
  String get merchantHistoryHeadline => 'Order history';

  @override
  String get merchantHistorySubtitle =>
      'Look up sold, cancelled and settled orders';

  @override
  String get merchantHistorySearch => 'Search by order id or customer...';

  @override
  String get merchantHistoryAll => 'All';

  @override
  String get merchantHistoryDone => 'Completed';

  @override
  String get merchantHistoryCancelled => 'Cancelled';

  @override
  String get merchantHistoryTabReconcile => 'Settlement';

  @override
  String get merchantHistoryToday => 'Today';

  @override
  String merchantHistoryRevenue(String amount) {
    return 'Completed revenue: $amount';
  }

  @override
  String get merchantHistoryList => 'Orders';

  @override
  String get merchantHistoryDetail => 'Details';

  @override
  String get merchantHistoryEmpty => 'No finished orders yet';

  @override
  String get merchantCategoriesTitle => 'Menu categories';

  @override
  String get merchantCategoriesHeadline => 'Manage categories';

  @override
  String get merchantCategoriesSubtitle =>
      'Arrange dishes so customers find them faster.';

  @override
  String get merchantCategoriesSearch => 'Search categories...';

  @override
  String merchantCategoriesCount(String count) {
    return '$count categories';
  }

  @override
  String merchantCategoriesItemsOnSale(String count) {
    return '$count items on sale';
  }

  @override
  String get merchantCategoriesShowing => 'Visible categories';

  @override
  String get merchantCategoriesAdd => 'Add category +';

  @override
  String get merchantCategoriesHint =>
      'Category order affects the store page. Out-of-stock items stay in the category.';

  @override
  String get merchantCategoriesEmpty => 'No categories yet';

  @override
  String get merchantCategoryName => 'Category name';

  @override
  String get merchantCategoryDesc => 'Description (optional)';

  @override
  String get merchantItemEditTitle => 'Add / edit item';

  @override
  String get merchantItemStep => 'Step 1 / 2';

  @override
  String get merchantItemInfo => 'PRODUCT INFO';

  @override
  String get merchantItemCategory => 'Category';

  @override
  String get merchantItemDescription => 'Description';

  @override
  String get merchantItemPrep => 'Prep time (minutes)';

  @override
  String get merchantItemVisible => 'Visible to customers';

  @override
  String get merchantItemVisibleBody => 'Allow customers to order now';

  @override
  String get merchantItemSaveDraft => 'Save draft';

  @override
  String get merchantItemContinue => 'Continue: Size & topping';

  @override
  String get merchantItemSaved => 'Item saved';

  @override
  String get merchantProductsEdit => 'Edit';

  @override
  String get merchantProductsCategories => 'Categories';

  @override
  String get merchantProductsHistory => 'Order history';

  @override
  String get merchantItemPhoto => 'Item photo';

  @override
  String get merchantItemPhotoHint =>
      'JPEG, PNG or WebP — size/type limits from system settings';

  @override
  String get merchantItemPhotoPick => 'Choose photo';

  @override
  String get merchantItemPhotoUploading => 'Uploading photo…';

  @override
  String get merchantItemPhotoClear => 'Remove photo';

  @override
  String get merchantItemPhotoError => 'Could not upload the photo. Try again.';

  @override
  String get merchantCategoriesReorderHint =>
      'Hold and drag to change the order on the store page.';

  @override
  String get merchantCategoriesReordered => 'Category order saved';

  @override
  String merchantProductsSoldCount(String count) {
    return 'Sold $count';
  }

  @override
  String get merchantProductsSearch => 'Search items...';

  @override
  String get merchantProductsFilterAll => 'All';

  @override
  String get merchantProductsFilterOnSale => 'On sale';

  @override
  String get merchantProductsFilterHidden => 'Hidden / draft';

  @override
  String get merchantProductsEmptyFilter => 'No items match this filter';

  @override
  String get merchantOptionsChoiceMaxQty => 'Max quantity per line';

  @override
  String merchantOptionsMaxQty(String count) {
    return 'Max ×$count';
  }

  @override
  String get merchantCategoriesSearchHint => 'Search categories...';

  @override
  String get merchantEditGalleryHint => 'Photo gallery (max from settings)';

  @override
  String get merchantEditStatusHidden =>
      'Hidden / draft — not visible to customers';

  @override
  String get merchantEditStatusOnSale => 'On sale';

  @override
  String get merchantLocationTitle => 'Store location';

  @override
  String get merchantLocationIntro =>
      'Drivers use this point to pick up orders; the delivery fee is measured from here.';

  @override
  String get merchantLocationUnset =>
      'Your store has no location yet. Drivers get no exact pickup point and the delivery fee uses the default.';

  @override
  String get merchantLocationUnsetValue => 'Not set';

  @override
  String get merchantLocationPickHint =>
      'Tap to search an address or use the map';

  @override
  String get merchantLocationPendingHint => 'Not saved — tap Save location';

  @override
  String get merchantLocationSave => 'Save location';

  @override
  String get merchantLocationSaved => 'Store location saved.';

  @override
  String get placePickerStoreTitle => 'Store location';

  @override
  String get accountStoreLocationBody => 'Pickup point for drivers';

  @override
  String get forgotPasswordLink => 'Forgot password?';

  @override
  String get forgotPasswordTitle => 'Reset password';

  @override
  String get forgotPasswordIntro =>
      'Enter the email you sign in with. If it has a password account, DealGo emails a 6-digit code to reset it.';

  @override
  String get forgotPasswordSendCode => 'Send code';

  @override
  String forgotPasswordCodeSent(String email) {
    return 'If $email has a password account, a 6-digit code was sent to it. The code is valid for a few minutes.';
  }

  @override
  String get forgotPasswordCodeLabel => '6-digit code from the email';

  @override
  String get forgotPasswordNewLabel => 'New password (at least 8 characters)';

  @override
  String get forgotPasswordConfirmLabel => 'Repeat the new password';

  @override
  String get forgotPasswordSubmit => 'Reset password';

  @override
  String get forgotPasswordResend => 'Resend code';

  @override
  String get forgotPasswordResent =>
      'A new code was sent. The old code no longer works.';

  @override
  String get forgotPasswordDone =>
      'Your password was reset and older sessions were signed out. Sign in with the new password.';

  @override
  String get forgotPasswordErrCode => 'Enter all 6 digits of the code.';

  @override
  String get forgotPasswordErrCooldown =>
      'Please wait a moment before requesting another code.';

  @override
  String get forgotPasswordErrResendLimit =>
      'Too many codes were sent. Please start again.';

  @override
  String get forgotPasswordStartOver => 'Start again';

  @override
  String get securityPasskeyAdded => 'Passkey added to your account.';

  @override
  String get securityPasskeyUnsupported =>
      'This device or app version does not support passkeys yet. You can keep signing in with your phone number.';

  @override
  String get securityPasskeyExists =>
      'This device already has a passkey for your account.';

  @override
  String get securityPasskeyFailed =>
      'Could not add the passkey. Please try again.';

  @override
  String get securityPasskeyDisabled =>
      'Passkey sign-in is turned off for now.';

  @override
  String get securityPasskeyNeedsPhone =>
      'Verify your phone number before adding a passkey.';

  @override
  String get merchantProfileTitle => 'Store profile';

  @override
  String get merchantProfileIntro =>
      'Name and logo customers see in the store list and on your store page.';

  @override
  String get merchantProfileName => 'Store name';

  @override
  String get merchantProfileNameInvalid =>
      'Store name must be 2 to 120 characters.';

  @override
  String get merchantProfileSave => 'Save store name';

  @override
  String get merchantProfileSaved => 'Store name saved.';

  @override
  String get merchantProfileLogo => 'Store logo';

  @override
  String get merchantProfileLogoHint =>
      'JPEG, PNG or WebP; a square image works best.';

  @override
  String get merchantProfileLogoAdd => 'Add logo';

  @override
  String get merchantProfileLogoChange => 'Change logo';

  @override
  String get merchantProfileLogoRemove => 'Remove logo';

  @override
  String get merchantProfileLogoSaved => 'Logo updated.';

  @override
  String get merchantProfileLogoRemoved => 'Logo removed.';

  @override
  String get accountStoreProfileBody => 'Store name and logo';
}

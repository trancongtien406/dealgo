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
  String get otpHeading => 'Verify phone';

  @override
  String get otpSending => 'Sending';

  @override
  String get otpInvalidTitle => 'Wrong code';

  @override
  String get otpExpiredTitle => 'Code expired';

  @override
  String get otpLockedBody => 'Too many attempts. Try later.';

  @override
  String get otpInvalidBody => 'Code is wrong or used.';

  @override
  String get otpInvalidShort => 'Invalid OTP.';

  @override
  String get otpCannotResendTitle => 'Cannot send a new code yet';

  @override
  String get otpCannotResendBody => 'Wait to resend.';

  @override
  String get otpResendLabel => 'Send new code';

  @override
  String get otpResendCooldown => 'Resend after';

  @override
  String get otpServerGateHint => 'Wait to get a new code.';

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
  String get chatEmpty => 'No messages yet';

  @override
  String get chatInputHint => 'Type a message';

  @override
  String get chatContact => 'Message';

  @override
  String get chatContactShop => 'Message the shop';

  @override
  String get chatContactCustomer => 'Customer chat';

  @override
  String get voiceCall => 'Voice call';

  @override
  String get voiceCalling => 'Calling…';

  @override
  String get voiceConnecting => 'Connecting…';

  @override
  String get voiceIncoming => 'Incoming call';

  @override
  String get voiceReconnecting => 'Weak signal, reconnecting…';

  @override
  String get voicePeerCustomer => 'Customer';

  @override
  String get voicePeerDriver => 'Driver';

  @override
  String get voiceAccept => 'Answer';

  @override
  String get voiceDecline => 'Decline';

  @override
  String get voiceHangUp => 'End';

  @override
  String get voiceMute => 'Mute';

  @override
  String get voiceUnmute => 'Unmute';

  @override
  String get voiceSpeaker => 'Speaker';

  @override
  String get voiceEndedHungUp => 'Call ended';

  @override
  String get voiceEndedDeclined => 'Call declined';

  @override
  String get voiceEndedNoAnswer => 'No answer';

  @override
  String get voiceEndedMissed => 'Missed call';

  @override
  String get voiceEndedTripClosed => 'The trip has ended, so the call stopped';

  @override
  String get voiceEndedConnectionLost => 'Call connection lost';

  @override
  String get voiceMicDenied =>
      'Microphone access is needed for calls. Turn it on in Settings.';

  @override
  String get apiErrVoiceDisabled => 'In-app calling is turned off right now.';

  @override
  String get apiErrVoiceUnavailable =>
      'Calling isn\'t available right now. Please use chat.';

  @override
  String get apiErrVoiceBusy => 'There is already a call for this trip.';

  @override
  String get apiErrVoiceNoCounterpart => 'No driver has taken this trip yet.';

  @override
  String get apiErrVoiceWindowClosed =>
      'Calls are only available while the trip is in progress.';

  @override
  String get apiErrChatWindowClosed =>
      'The contact window has closed for this trip or order.';

  @override
  String get apiErrChatNoCounterpart =>
      'No driver has been assigned to this order yet.';

  @override
  String get apiErrChatForbidden =>
      'You do not have access to this conversation.';

  @override
  String get apiErrChatUnavailable =>
      'Chat is temporarily unavailable. Please try again later.';

  @override
  String get apiErrChatBodyInvalid => 'Message content is invalid.';

  @override
  String get bannerOfflineTitle => 'You’re offline';

  @override
  String get commonSelected => 'Selected';

  @override
  String get actionSeeDetail => 'View details →';

  @override
  String get rideOfferDetailTitle => 'Offer details';

  @override
  String get rideOfferAmountLabel => 'Driver offer';

  @override
  String get rideYourBidLabel => 'Your bid';

  @override
  String get rideTripInfoTitle => 'Trip';

  @override
  String get rideSelectOfferCta => 'Choose offer';

  @override
  String get ridePickupCodeTitle => 'Pickup verification code';

  @override
  String get ridePickupCodeChip => 'Show to driver';

  @override
  String get ridePickupCodeHeadline => 'Your pickup code';

  @override
  String get ridePickupCodeBody => 'Share only if car and plate match.';

  @override
  String get ridePickupCodeSafetyTitle => 'Keep the code private';

  @override
  String get ridePickupCodeSafetyBody => 'Don\'t send the code in chat.';

  @override
  String get rideSafetyTitle => 'Safety center';

  @override
  String get rideSafetyBannerTitle => 'Stay safe on this trip';

  @override
  String get rideSafetyBannerBody => 'Share your trip; call 113/115 if needed.';

  @override
  String get rideSafetyShareTitle => 'Share trip';

  @override
  String get rideSafetyShareBody => 'Send a trip link to someone.';

  @override
  String get rideSafetyShareCta => 'Share trip link';

  @override
  String get rideSafetyShareCopied => 'Trip link copied';

  @override
  String get rideSafetyContactsTitle => 'Emergency contacts';

  @override
  String get rideSafetyContactsBody => 'Saved on this device.';

  @override
  String get rideSafetyAddContact => 'Add contact';

  @override
  String get rideSafetyEmergencyTitle => 'Emergency help';

  @override
  String get rideSafetyEmergencyBody => 'Call emergency from your phone.';

  @override
  String get rideCancelTitle => 'Cancel trip';

  @override
  String get rideCancelPickReason => 'Why are you cancelling?';

  @override
  String get rideCancelReasonWait => 'Waiting too long';

  @override
  String get rideCancelReasonPlans => 'Plans changed';

  @override
  String get rideCancelReasonAddress => 'Wrong pickup / drop-off';

  @override
  String get rideCancelBookAgain => 'Book another ride';

  @override
  String get rideCancelReasonOptional => 'Reason (optional)';

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
  String get foodCancelPolicyHint => 'Cancel only before the store accepts.';

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
  String get driverJobFailedBody => 'Pick a reason.';

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
  String get driverJobsHistorySection => 'Job outcomes';

  @override
  String get driverServicesTitle => 'Choose services';

  @override
  String get driverServicesHeadline => 'Services';

  @override
  String get driverServicesOnlineTitle => 'Online';

  @override
  String get driverServicesApprovedSection => 'Approved services';

  @override
  String get driverServicesRideTitle => 'Rides';

  @override
  String get driverServicesFoodTitle => 'Food delivery';

  @override
  String get driverServicesApprovedChip => 'Approved';

  @override
  String get driverServicesVehicleSection => 'Active vehicle';

  @override
  String get driverServicesAreaSection => 'Request area';

  @override
  String get driverServicesAreaFromGps => 'From the driver’s current location';

  @override
  String get driverServicesSave => 'Save configuration';

  @override
  String driverServicesCount(int count) {
    return '$count services';
  }

  @override
  String get driverOtpTitle => 'Passenger pickup OTP';

  @override
  String get driverOtpHeadline => 'Verify passenger boarding';

  @override
  String get driverOtpBody => 'Enter the rider\'s 4-digit code.';

  @override
  String get driverOtpVerifyTitle => 'Passenger verification';

  @override
  String driverOtpValidFor(String rideId) {
    return 'OTP is valid only for trip $rideId';
  }

  @override
  String get driverOtpWaitingHint => 'Ask the customer for their pickup code';

  @override
  String get driverOtpWrong =>
      'OTP does not match. Check again with the passenger.';

  @override
  String get driverOtpConfirm => 'Confirm and start trip';

  @override
  String get driverOtpWaitingChip => 'WAITING';

  @override
  String get driverActiveNavTitle => 'Heading to pickup';

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
  String get driverActiveWaitingBody => 'Wait, then enter OTP to start.';

  @override
  String get driverActiveOnTripBody => 'Drive safely.';

  @override
  String get driverActiveCompleteCta => 'Complete / collect payment';

  @override
  String get driverActiveCompleteBody => 'Collect the agreed fare.';

  @override
  String get driverActiveReportIssue => 'Report issue';

  @override
  String get driverFoodPhaseNavTitle => 'Heading to store';

  @override
  String get driverFoodPhaseWaitTitle => 'Waiting at store';

  @override
  String get driverFoodPhasePickupTitle => 'Confirm pickup';

  @override
  String get driverFoodPhaseDeliverTitle => 'Deliver to customer';

  @override
  String get driverFoodPhaseCompleteTitle => 'Delivered';

  @override
  String get driverFoodConfirmPickup => 'Picked up order';

  @override
  String get driverFoodArrivedCustomer => 'Arrived at dropoff';

  @override
  String get driverFoodCompleteDelivery => 'Complete delivery';

  @override
  String get driverFoodWaitBody => 'Wait for the order.';

  @override
  String get driverFoodPickupBody => 'Check bags and handover code.';

  @override
  String get driverFoodDeliverBody => 'Deliver and collect COD.';

  @override
  String get driverFoodCompleteBody => 'COD will be settled.';

  @override
  String get driverFoodIncomePending => 'Updated after settlement';

  @override
  String get driverFoodNoClientFee => 'Your net income shows after settlement.';

  @override
  String get driverFoodCodCollect => 'Collect (COD)';

  @override
  String get merchantRejectOrder => 'Reject';

  @override
  String get merchantAcceptOrder => 'Confirm order';

  @override
  String get merchantRejectConfirmTitle => 'Reject this order?';

  @override
  String get merchantRejectConfirmBody => 'Reject this order?';

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
  String get merchantSettingsShellTitle => 'Shop settings';

  @override
  String get merchantAcceptTitle => 'Order acceptance';

  @override
  String get merchantAcceptModeLabel => 'Order confirmation mode';

  @override
  String get merchantAcceptManual => 'Manual';

  @override
  String get merchantAcceptAuto => 'Automatic when eligible';

  @override
  String get merchantAcceptManualHint => 'Accept each order.';

  @override
  String get merchantAcceptAutoHint => 'Auto-accept while open.';

  @override
  String get merchantHoursTitle => 'Opening hours';

  @override
  String get merchantHoursOpen => 'Open';

  @override
  String get merchantHoursClosed => 'Off';

  @override
  String get merchantBusyTitle => 'Busy / Paused';

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
  String get merchantBusyBusyHint => 'Still open, slower prep.';

  @override
  String get merchantBusyPausedHint => 'No new orders.';

  @override
  String get merchantVariantsTitle => 'Options';

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
  String get rideRouteSwapTooltip => 'Swap pickup and dropoff';

  @override
  String get rideRouteDistance => 'Distance';

  @override
  String get rideRouteRefPrice => 'Ref. price';

  @override
  String get rideRouteContinueBooking => 'Choose vehicle & offer';

  @override
  String get rideFareBreakdownTitle => 'Fare details';

  @override
  String get rideFareEstimatedFee => 'Estimated fee';

  @override
  String get rideFareComponentsTitle => 'Fare components';

  @override
  String get rideFareTripInfoTitle => 'Trip information';

  @override
  String get rideFareProposeCta => 'Propose trip fare';

  @override
  String get rideShareTrip => 'Share trip';

  @override
  String get foodSearchTitle => 'Find dishes & stores';

  @override
  String get foodSearchHint => 'bun bo';

  @override
  String get foodSearchFilterNear => 'Near me';

  @override
  String get foodSearchSortNewest => 'Newest';

  @override
  String get foodSearchSuggestions => 'Search suggestions';

  @override
  String foodSearchResults(int count) {
    return '$count results';
  }

  @override
  String get foodSearchEmpty => 'No matching stores yet';

  @override
  String get foodSearchDishes => 'Dishes';

  @override
  String get foodSearchStores => 'Stores';

  @override
  String get foodDeliverTo => 'Deliver to';

  @override
  String get foodFilterButton => 'Filters';

  @override
  String get foodFilterTitle => 'Filter & sort';

  @override
  String get foodFilterSort => 'Sort by';

  @override
  String get foodFilterNear => 'Nearest';

  @override
  String get foodFilterRating => 'Top rated';

  @override
  String get foodFilterDistance => 'Distance';

  @override
  String get foodFilterAnyDistance => 'Any distance';

  @override
  String foodFilterKm(int km) {
    return 'Within $km km';
  }

  @override
  String get foodFilterOpenNow => 'Open now';

  @override
  String get foodFilterOffers => 'Has offers';

  @override
  String get foodFilterApply => 'Apply';

  @override
  String get foodFilterReset => 'Reset';

  @override
  String get foodFilterClear => 'Clear filters';

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
  String get foodItemDetailTitle => 'Item details';

  @override
  String foodDishPhotoCount(int index, int total) {
    return 'Photo $index/$total';
  }

  @override
  String get foodItemOptionsChoose => 'Choose options';

  @override
  String get foodItemOptionsChooseRequired => 'Choose options';

  @override
  String foodItemOptionsMissingRequired(String groups) {
    return 'Choose $groups';
  }

  @override
  String get foodItemOptionsFree => 'Free';

  @override
  String get foodItemQuantity => 'Quantity';

  @override
  String foodItemSelectedOptions(String options) {
    return 'Selected: $options';
  }

  @override
  String get foodItemInfoTitle => 'Item details';

  @override
  String foodItemInStore(String store) {
    return 'At $store';
  }

  @override
  String get foodStoreDirections => 'Directions';

  @override
  String get foodStoreOpenInMaps => 'Open in Google Maps';

  @override
  String get foodStoreMapOpenFailed => 'Couldn\'t open the map.';

  @override
  String get foodStoreMenuSections => 'Menu categories';

  @override
  String foodItemOptionsMaxReached(int count) {
    return 'Maximum $count selected';
  }

  @override
  String get foodInvoiceTitle => 'Order receipt';

  @override
  String get foodInvoiceDelivered => 'Delivered successfully';

  @override
  String get foodInvoiceOrderId => 'Order';

  @override
  String get foodInvoiceSyncChip => 'v1 · Synced';

  @override
  String get foodInvoiceDeliveredChip => 'Delivered';

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
    return 'Paid $amount in cash.';
  }

  @override
  String get foodInvoiceRateCta => 'Rate order';

  @override
  String get foodInvoiceTrackCta => 'Track order';

  @override
  String get foodInvoiceItemsTitleOpen => 'Items';

  @override
  String get foodInvoiceCodDue => 'Total due';

  @override
  String get checkoutEmptyBody => 'No items yet.';

  @override
  String get checkoutBackToMenu => 'Back to menu';

  @override
  String get foodTrackingMapChip => 'Order is being delivered';

  @override
  String get foodTrackingMapWaitingDriver => 'Waiting for driver location';

  @override
  String get foodTrackingMapEmptyHint => 'Store not on the map yet.';

  @override
  String get foodTrackingCodDue => 'Due on delivery';

  @override
  String get foodTrackingCodHint => 'Pay on delivery.';

  @override
  String get paymentHistoryTitle => 'Payment history';

  @override
  String get paymentHistoryFilterAll => 'All';

  @override
  String get paymentHistoryRecent => 'Recent transactions';

  @override
  String get stateErrorTitle => 'Something went wrong';

  @override
  String get stateErrorBody => 'Couldn\'t load. Try again.';

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
  String get authLegalTerms => 'Terms of Service';

  @override
  String get authLegalConsentPrefix => 'I have read and agree to the ';

  @override
  String get authLegalConsentRequired =>
      'Please read and agree to the Terms of Service and Privacy Policy to continue.';

  @override
  String get authWelcomeTo => 'Welcome to';

  @override
  String get authMethodPasskey => 'Passkey';

  @override
  String get authMethodsEmptyTitle => 'No sign-in methods';

  @override
  String get authMethodsEmptyBody => 'Try again later.';

  @override
  String get authPhoneTitle => 'Sign in';

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
  String get passwordErrTooShort => 'Password must be at least 6 characters';

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
  String get otpShieldNote => 'OTP protects your account.';

  @override
  String get otpConfirm => 'Confirm';

  @override
  String get passkeyTitle => 'Sign in with Passkey';

  @override
  String get passkeyOr => 'or';

  @override
  String get passkeyContinue => 'Continue with passkey';

  @override
  String get passkeySignIn => 'Sign in';

  @override
  String get passkeySignUp => 'Create account';

  @override
  String get splashTagline => 'Go anywhere · Eat everything';

  @override
  String get splashPreparing => 'Getting things ready for you...';

  @override
  String get serviceRideTitle => 'Ride';

  @override
  String get serviceRideBlurb => 'Bike, car';

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
  String get onbSlide2Body => 'Local drivers, clear fares, your price.';

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
  String get onbSlide3Body => 'Da Nang favourites, delivered.';

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
  String get profileDone => 'Done';

  @override
  String get rolePickerPrefix => 'How do you want to use ';

  @override
  String get rolePickerSuffix => '?';

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
  String get roleMerchantBody => 'Menu, orders, revenue';

  @override
  String get roleDriver => 'Driver';

  @override
  String get roleDriverBody => 'Rides and deliveries';

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
    return 'COD $amount is collected for the store.';
  }

  @override
  String get actionSkip => 'Skip';

  @override
  String get driverClaimJob => 'Accept job';

  @override
  String get driverClaimFailed => 'Couldn\'t accept the job. Please try again.';

  @override
  String get driverFoodRequestTitle => 'Delivery';

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
  String get driverFoodNavigateBody => 'Go to the store, then confirm.';

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
  String get driverJobTakenBody => 'Another driver took this.';

  @override
  String get driverOfferNotChosenTitle => 'Your offer was not chosen';

  @override
  String get driverOfferNotChosenBody =>
      'The customer picked another driver for this order.';

  @override
  String get driverJobUnavailable => 'Request no longer available';

  @override
  String get driverRequestId => 'Request ID';

  @override
  String get driverService => 'Service';

  @override
  String get driverServiceFood => 'Food delivery';

  @override
  String get driverOtpMatched => 'Code matches — starting the trip.';

  @override
  String get driverHeadToPickup => 'Pickup point';

  @override
  String get driverFollowRoute => 'Drop-off point';

  @override
  String get driverPassenger => 'Customer';

  @override
  String get driverPickupLabel => 'Pickup';

  @override
  String get driverDropoffLabel => 'Destination';

  @override
  String get driverRideNavigateNote => 'Head to pickup.';

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
  String get driverOfflineNote => 'You\'re offline.';

  @override
  String get vouchersEmptyTitle => 'No vouchers yet';

  @override
  String get vouchersEmptyBody => 'No vouchers yet.';

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
  String get accountSectionDisplay => 'Display';

  @override
  String get accountLanguage => 'Language';

  @override
  String get accountTheme => 'Appearance';

  @override
  String get accountThemeSystem => 'Match system';

  @override
  String get accountThemeLight => 'Light';

  @override
  String get accountThemeDark => 'Dark';

  @override
  String get accountSupport => 'Help center';

  @override
  String get accountSupportBody => 'FAQs and Messenger chat on the web';

  @override
  String get accountSupportTicketsBody => 'Track the support requests you sent';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountPartnerHubTitle => 'Earn with DealGo';

  @override
  String get accountPartnerHubSubtitle =>
      'Become a Driver partner or register a Shop with DealGo';

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
  String get activityEmptyBody => 'No activity yet.';

  @override
  String get activityRecent => 'Recent';

  @override
  String get activityOfflineBody => 'May be out of date.';

  @override
  String get statusExpired => 'Expired';

  @override
  String get statusFailed => 'Failed';

  @override
  String get statusRejected => 'Rejected';

  @override
  String get statusInProgress => 'In progress';

  @override
  String get emptyStoresNearbyBody => 'Check back later.';

  @override
  String get notificationsEmptyTitle => 'No notifications yet';

  @override
  String get notificationsEmptyBody => 'No notifications yet.';

  @override
  String get helpNoResults => 'No articles match this keyword.';

  @override
  String get driverOpenRequests => 'Open requests';

  @override
  String get driverOfflineTitle => 'You are offline';

  @override
  String get driverJobsOfflineBody => 'Go online to see requests.';

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
  String get checkoutPlacedNote => 'Pay cash on delivery.';

  @override
  String get checkoutPayLaterNote => 'Pay cash on delivery.';

  @override
  String get checkoutProcessingTitle => 'Processing your order';

  @override
  String get checkoutProcessingBody => 'Confirming — don\'t reorder.';

  @override
  String get checkoutPendingRequest => 'Pending request';

  @override
  String get checkoutCartRef => 'Cart';

  @override
  String get checkoutExpectedAmount => 'Expected amount';

  @override
  String get checkoutOfflineTitle => 'You\'re offline';

  @override
  String get checkoutOfflineBody => 'Couldn\'t send. Cart is kept.';

  @override
  String get checkoutUnsentCart => 'Unsent cart';

  @override
  String get checkoutExpectedTotal => 'Expected total';

  @override
  String get checkoutCodShort => 'Cash · Unpaid';

  @override
  String get checkoutRepricedTitle => 'Price changed';

  @override
  String get checkoutRepricedBody => 'Please confirm the new total.';

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
      'Order is placed only after you accept.';

  @override
  String get checkoutRepricedPlacedNote =>
      'Placed at new price. Pay cash on delivery.';

  @override
  String checkoutAcceptTotal(String amount) {
    return 'Accept $amount';
  }

  @override
  String checkoutPlaceTotal(String amount) {
    return 'Place order · $amount';
  }

  @override
  String get inboxRideAssignedTitle => 'Driver found';

  @override
  String get inboxRideAssignedBody =>
      'Your driver is getting ready to come to the pickup point.';

  @override
  String get inboxRideDriverEnRouteTitle => 'Your driver is on the way';

  @override
  String get inboxRideDriverEnRouteBody =>
      'Your driver is heading to the pickup point.';

  @override
  String get inboxRideDriverArrivedTitle => 'Driver arrived';

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
  String get inboxRideExpiredTitle => 'Request expired';

  @override
  String get inboxRideExpiredBody => 'No driver accepted.';

  @override
  String get inboxFoodPreparingTitle => 'Preparing';

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
  String get inboxFoodDeliveredTitle => 'Delivered';

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
  String inboxUnreadCount(int count) {
    return '$count unread notifications';
  }

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
  String get addrBookEmptyBody => 'Save places to book faster.';

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
  String get addrBookLabelRequired => 'Enter a name';

  @override
  String get addrBookLine => 'Address';

  @override
  String get addrBookLineHint => 'Street number, street, ward/district';

  @override
  String get addrBookLineRequired => 'Enter an address (at least 3 characters)';

  @override
  String get addrBookNote => 'Note for driver';

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
    return 'Delete \"$label\"?';
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
  String get rateCommentLabel => 'Comment';

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
  String get drvHistEmptyBody => 'No jobs yet.';

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
    return 'Gross fares $gross · DealGo commission −$fee';
  }

  @override
  String drvHistItemFee(String percent, String fee) {
    return 'Commission $percent% −$fee';
  }

  @override
  String drvHistItemFeeFood(String percent, String fee) {
    return 'Commission $percent% of delivery fee −$fee';
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
  String get placeResultsTitle => 'Search results';

  @override
  String get placeSearchEmptyTitle => 'No results';

  @override
  String get placeSearchEmptyBody => 'Try another search.';

  @override
  String get placeSearchUnavailable =>
      'Place search is unavailable right now. Use your current location or a saved address.';

  @override
  String get placeSearchError => 'Couldn\'t load search results.';

  @override
  String get placeNothingYet =>
      'Search for a place or use your current location to start.';

  @override
  String get placeHistoryTitle => 'Recent';

  @override
  String get placeHistoryClear => 'Clear';

  @override
  String get placeHistoryDelete => 'Remove from history';

  @override
  String get placeHistoryClearTitle => 'Clear search history?';

  @override
  String get placeHistoryClearBody => 'Clear place history?';

  @override
  String get placeHistoryClearConfirm => 'Clear history';

  @override
  String get placeApproximate => 'Approximate house number · check the pin';

  @override
  String placeDistanceKm(String km) {
    return '$km km';
  }

  @override
  String get rideBookTitle => 'Book a ride';

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
  String get rideSamePlaces => 'Pickup and destination are the same.';

  @override
  String rideEtaMinutes(int minutes) {
    return '$minutes min';
  }

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
  String get rideFareAllowedRange => 'Allowed range';

  @override
  String get rideVehicleBikeTitle => 'Motorbike';

  @override
  String get rideVehicleCar4Title => '4-seat car';

  @override
  String get rideVehicleCar7Title => '7-seat car';

  @override
  String rideVehicleSeats(int count) {
    return '$count seats';
  }

  @override
  String get rideFareOpening => 'Opening fare';

  @override
  String get rideFarePerKm => 'Per kilometre';

  @override
  String rideFareTime(int minutes) {
    return 'Time ($minutes min)';
  }

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
  String get rideVehicleContinueToOffer => 'Propose your fare';

  @override
  String get rideVehicleClassesUnavailable =>
      'No vehicle classes are available right now. Pull to refresh or try again shortly.';

  @override
  String get homeQuickBookTitle => 'Quick ride';

  @override
  String get homeQuickBookPickup => '123 Nguyen Van Linh, Hai Chau, Da Nang';

  @override
  String get homeQuickBookVehicle => 'Bike & Car';

  @override
  String get homeQuickBookEstimate => 'Estimate';

  @override
  String get homeQuickBookEtaPrice => 'After places';

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
  String get foodOrderNoteLabel => 'Note for the store / driver';

  @override
  String get foodOrderNoteHint =>
      'E.g. less spicy, no onion, leave at the door…';

  @override
  String get foodLineNoteLabel => 'Note for this dish';

  @override
  String get foodLineNoteHint => 'E.g. less ice, no sugar…';

  @override
  String get foodUtensilsLabel => 'Cutlery';

  @override
  String get foodUtensilsYes => 'Yes';

  @override
  String get foodUtensilsNo => 'No';

  @override
  String get foodCartUpsellTitle => 'Add more to your meal';

  @override
  String get foodNoteSaved => 'Note saved';

  @override
  String get foodNoteCleared => 'Note cleared';

  @override
  String get foodCheckoutExtrasTitle => 'Notes & cutlery';

  @override
  String get foodCheckoutNoteEmpty => 'No note for the store or driver yet';

  @override
  String get foodCheckoutNoteAdd => 'Add';

  @override
  String get foodCheckoutNoteEdit => 'Edit';

  @override
  String get foodFareFixedLabel => 'Fixed delivery fee';

  @override
  String get foodFareFixedHint =>
      'DealGo sets this fee for the distance; it is not negotiable.';

  @override
  String get foodFareNegotiationHint =>
      'The driver can accept this amount or counter with a higher fee.';

  @override
  String get foodLineNoteClear => 'Clear note';

  @override
  String get foodCartLineRemove => 'Remove item';

  @override
  String get driverOtpLocked =>
      'Too many wrong codes. Contact support to continue this ride.';

  @override
  String get ridePickupCodeUnavailable =>
      'Your pickup code appears once a driver accepts the ride.';

  @override
  String driverCardRating(String rating, int count) {
    return '$rating · $count ratings';
  }

  @override
  String get driverCardNew => 'New';

  @override
  String get driverDetailTitle => 'Driver';

  @override
  String get driverDetailOpen => 'View driver details';

  @override
  String get driverDetailVehicle => 'Vehicle';

  @override
  String get driverDetailPlate => 'Licence plate';

  @override
  String get driverDetailClass => 'Vehicle type';

  @override
  String get driverAvatarOpen => 'View profile photo';

  @override
  String get driverAvatarClose => 'Close';

  @override
  String driverCardTrips(String count) {
    return '$count trips';
  }

  @override
  String get actionReload => 'Reload';

  @override
  String get rideAgreedFare => 'Agreed fare';

  @override
  String get rideVehicleLabel => 'Vehicle';

  @override
  String get rideViewReceipt => 'View receipt';

  @override
  String get rideOfflineTitle => 'Connection lost';

  @override
  String get rideOfflineBody => 'Showing last known data.';

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
  String get helpSearchHint => 'Search answers or guides...';

  @override
  String get helpTopicsTitle => 'Popular topics';

  @override
  String get helpTopicRide => 'Rides';

  @override
  String get helpTopicFood => 'Food';

  @override
  String get helpTopicPayment => 'Payments';

  @override
  String get helpTopicAccount => 'Account';

  @override
  String get helpTopicSelected => 'Topic for your request';

  @override
  String get helpFaqTitle => 'Frequently asked questions';

  @override
  String get helpSeeAll => 'See all';

  @override
  String get helpStillNeedTitle => 'Still need help?';

  @override
  String get helpStillNeedBody => 'See your requests.';

  @override
  String get helpMyTickets => 'Your requests';

  @override
  String get helpCreateTicket => 'Send a support request';

  @override
  String get supportListTitle => 'Support requests';

  @override
  String get supportListHeading => 'Your requests';

  @override
  String get supportListEmptyTitle => 'No requests yet';

  @override
  String get supportListEmptyBody => 'No requests yet.';

  @override
  String get supportListLoadFailed =>
      'Couldn\'t load your requests. Check your connection and try again.';

  @override
  String get supportNewTicket => 'New request';

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
  String get supportFieldCategory => 'Issue type';

  @override
  String get supportFieldRelated => 'Related ride / order';

  @override
  String get supportRelatedNone => 'Not about a specific ride or order';

  @override
  String get supportRelatedPickTitle => 'Pick ride / order';

  @override
  String get supportRelatedEmpty => 'No finished rides or orders yet.';

  @override
  String get supportFieldSubject => 'Subject';

  @override
  String get supportFieldDescription => 'Details';

  @override
  String get supportPrivacyNote => 'Never send passwords, OTPs or cards.';

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
  String get supportProgressInProgressBody => 'In progress.';

  @override
  String get supportProgressResolved => 'Resolved';

  @override
  String get supportProgressClosed => 'Closed';

  @override
  String get supportThreadTitle => 'Conversation';

  @override
  String get supportStaffName => 'DealGo Support';

  @override
  String get supportReplyHint => 'Type your reply...';

  @override
  String get supportReplySend => 'Send reply';

  @override
  String get supportClosedNote => 'Request closed.';

  @override
  String get supportResolvedNote => 'Resolved. Reply to reopen.';

  @override
  String get supportDetailLoadFailed => 'Couldn\'t load this request.';

  @override
  String get supportRelatedRide => 'Ride';

  @override
  String get supportRelatedFood => 'Order';

  @override
  String get inboxSupportReplyTitle => 'Support replied';

  @override
  String get inboxSupportResolvedTitle => 'Request resolved';

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
  String get foodGroupNear => 'Near me';

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
  String get foodDiscoverySearchHint => 'Search restaurants, dishes, drinks';

  @override
  String get foodFeedEndOfList => 'You have seen every store nearby';

  @override
  String get foodStoreBestsellers => 'Best sellers';

  @override
  String foodStorePrepChip(int minutes) {
    return '≈$minutes min';
  }

  @override
  String get foodSearchGroups => 'Categories';

  @override
  String get foodSeeAll => 'See all →';

  @override
  String get foodEmptyNoStoresInCategory => 'No stores in this category yet';

  @override
  String get foodEmptyOutOfArea => 'DealGo does not deliver here yet';

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
  String foodStoreSectionCount(int count) {
    return '$count items';
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
  String get homeVoucherTitle => 'Today\'s deals';

  @override
  String get homeRecentEmpty => 'No rides or orders yet.';

  @override
  String get homeShopTitle => 'Featured shopping';

  @override
  String get homeRecentTitle => 'Recent';

  @override
  String get homeCatFood => 'Food';

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
  String get driverCompletedNotFoundHint => 'Try again shortly.';

  @override
  String get driverCompletedFeeLabel => 'DealGo commission';

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
  String get merchantHandoffAwaitDriver =>
      'The driver has not confirmed pickup yet. Give them the handover code to finish.';

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
  String get merchantReadyHint => 'Tap when the order is complete.';

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
  String get merchantLineCountLabel => 'Items';

  @override
  String get merchantHandoffCodLabel => 'Food value (COD)';

  @override
  String get merchantHandoffNote => 'Match the order code with the driver.';

  @override
  String get merchantHandoffDoneNote => 'Waiting for driver.';

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
  String get merchantConflictBody => 'Order status changed.';

  @override
  String get merchantConflictOrder => 'Order';

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
    return 'DealGo commission ($percent%)';
  }

  @override
  String driverCompletedFoodFeePercentLabel(String percent) {
    return 'Delivery fee commission ($percent%)';
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
  String get partnerDocPick => 'Photo library';

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
  String get partnerDocHint => 'Sharp, all 4 corners. JPG/PNG ≤ 4 MB.';

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
  String get partnerKindVehicleInsurance => 'Vehicle insurance (photo)';

  @override
  String get partnerKindBusinessLicense => 'Business licence';

  @override
  String get partnerKindFoodSafetyCert => 'Food safety certificate';

  @override
  String kycLicenseClassMismatch(String licenseClass) {
    return 'Licence class $licenseClass does not cover this vehicle. Go back and pick the class printed on your licence.';
  }

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
  String get partnerTimelineSubmitted => 'Application sent';

  @override
  String get partnerTimelineReview => 'Document review';

  @override
  String get partnerTimelineReviewQuick => 'Admin approval';

  @override
  String get kycStatusTitleQuick => 'Driver registration status';

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
  String get partnerBankAccount => 'Account number';

  @override
  String get partnerBankHolder => 'Account holder';

  @override
  String get partnerBankHolderHint => 'UPPERCASE, NO ACCENTS';

  @override
  String get partnerBankNote => 'Holder name must match your ID.';

  @override
  String get partnerReviewTitleDocs => 'Documents';

  @override
  String get partnerReviewEntered => 'Entered';

  @override
  String get partnerReviewMissing => 'Missing';

  @override
  String get kycRoleBadge => 'Driver';

  @override
  String get kycFlowLabel => 'DRIVER SIGN-UP';

  @override
  String get kycIntroTitle => 'Driver sign-up';

  @override
  String get kycIntroSubtitle => 'Driver partner';

  @override
  String get kycIntroHero => 'Ride anywhere\nEarn more';

  @override
  String get kycIntroHeadline => 'Drive with DealGo';

  @override
  String get kycIntroRideTitle => 'Rides';

  @override
  String get kycIntroRideBody => 'Rides, your price';

  @override
  String get kycIntroFoodTitle => 'Food delivery';

  @override
  String get kycIntroFoodBody => 'Pick up, deliver';

  @override
  String get kycIntroEarnTitle => 'Track earnings';

  @override
  String get kycIntroEarnBody => 'Clear earnings';

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
  String get kycServiceRideBody => 'Carry riders, agree a fare';

  @override
  String get kycServiceFoodBody => 'Pick up and deliver food';

  @override
  String get kycFullName => 'Full name';

  @override
  String get kycBirthDate => 'Date of birth';

  @override
  String get kycNationality => 'Nationality';

  @override
  String get kycNationalityVn => 'Vietnam';

  @override
  String get kycAddress => 'Contact address';

  @override
  String get kycPrivacyNote => 'Used only for review; kept private.';

  @override
  String get kycIdNumber => 'ID number';

  @override
  String get kycIdNumberHint => '12 digits';

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
  String get kycVehicleInsuranceNote => 'Cars need an insurance photo.';

  @override
  String get kycReviewProfile => 'Profile';

  @override
  String get kycReviewDriver => 'Driver details';

  @override
  String get kycReviewServices => 'Services';

  @override
  String get kycReviewBank => 'Payout bank';

  @override
  String get kycReviewNote => 'You can work once approved.';

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
  String get kycActiveTitle => 'Activated';

  @override
  String get kycActiveBody => 'You can go online.';

  @override
  String get kycStatusPendingNote => 'Awaiting review.';

  @override
  String get kycStatusActiveNote => 'Approved.';

  @override
  String get kycTimelineActivate => 'Start taking jobs';

  @override
  String get kycRejectedTitle => 'Update driver application';

  @override
  String get kycRejectedBanner => 'Fix the items below.';

  @override
  String get kybRoleBadge => 'Shop';

  @override
  String get kybFlowLabel => 'STORE SIGN-UP';

  @override
  String get kybStepFlowLabel => 'SHOP DETAILS';

  @override
  String get kybIntroTitle => 'Store sign-up';

  @override
  String get kybIntroSubtitle => 'Shop partner';

  @override
  String get kybIntroHeadline => 'Sell with DealGo';

  @override
  String get kybIntroHero => 'From small stalls to growing stores';

  @override
  String get kybIntroBenefits => 'DealGo grows with you';

  @override
  String get kybBenefitReachTitle => 'Reach customers';

  @override
  String get kybBenefitReachBody => 'Shown by area';

  @override
  String get kybBenefitOrdersTitle => 'Handle orders';

  @override
  String get kybBenefitOrdersBody => 'Track orders';

  @override
  String get kybBenefitRevenueTitle => 'Manage revenue';

  @override
  String get kybBenefitRevenueBody => 'Stats & settlement';

  @override
  String get kybBenefitTrustTitle => 'Transparent sign-up';

  @override
  String get kybBenefitTrustBody => 'Verified stores';

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
  String get kybTypeRestaurantBody => 'Cooked food';

  @override
  String get kybTypeCafe => 'Café / milk tea';

  @override
  String get kybTypeCafeBody => 'Drinks, bakery';

  @override
  String get kybTypeGrocery => 'Supermarket / grocery';

  @override
  String get kybTypeGroceryBody => 'Groceries';

  @override
  String get kybTypeConvenience => 'Convenience store';

  @override
  String get kybTypeConvenienceBody => 'Essentials';

  @override
  String get kybTypeOther => 'Other';

  @override
  String get kybTypeOtherBody => 'Other';

  @override
  String get kybSubjectLabel => 'Registered as';

  @override
  String get kybSubjectHousehold => 'Household business';

  @override
  String get kybSubjectCompany => 'Company';

  @override
  String get kybSubjectOther => 'Other';

  @override
  String get kybShopName => 'Shop name';

  @override
  String get kybShopAddress => 'Address';

  @override
  String get kybShopPin => 'Pin your store on the map';

  @override
  String get kybShopPinRequired =>
      'Required: drivers use this point to pick up orders.';

  @override
  String get kybShopPinChange => 'Pinned. Tap to change.';

  @override
  String get kybShopType => 'Type';

  @override
  String get kybShopCategory => 'Store category (you can pick later)';

  @override
  String get kybRepName => 'Representative\'s full name';

  @override
  String get kybReviewStatus => 'Application status';

  @override
  String get kybReviewShop => 'Shop details';

  @override
  String get kybReviewRep => 'Representative';

  @override
  String get kybReviewBank => 'Payout bank';

  @override
  String get kybReviewNote => 'You can sell once approved.';

  @override
  String get kybSubmitCta => 'Send for review';

  @override
  String get kybResubmitCta => 'Resend application';

  @override
  String get kybStatusTitle => 'Review status';

  @override
  String get kybTrackCta => 'Back to Shop home';

  @override
  String get kybPendingTitle => 'Application under review';

  @override
  String get kybActiveTitle => 'Activated';

  @override
  String get kybActiveBody => 'You can start selling.';

  @override
  String get kybStatusPendingNote => 'Awaiting review.';

  @override
  String get kybStatusActiveNote => 'Approved.';

  @override
  String get kybTimelineActivate => 'Start selling';

  @override
  String get kybRejectedTitle => 'Update Shop application';

  @override
  String get kybRejectedBanner => 'More info needed.';

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
  String get merchantStatementTitle => 'DealGo commission';

  @override
  String merchantStatementCash(int count) {
    return 'Cash from drivers ($count orders)';
  }

  @override
  String merchantStatementCommission(String percent) {
    return 'Commission ($percent%)';
  }

  @override
  String get merchantStatementNet => 'Store keeps';

  @override
  String merchantStatementCycle(int days) {
    return 'Settled every $days days';
  }

  @override
  String get merchantStatementUnsettled => 'Commission not yet paid';

  @override
  String get merchantStatementAllPaid =>
      'Commission for this period is fully paid.';

  @override
  String merchantStatementLastPaid(String period, String amount) {
    return 'Last payment: $period · $amount';
  }

  @override
  String get merchantStatementNote => 'Store pays commission to DealGo.';

  @override
  String get merchantStatsFailed => 'Could not load statistics. Pull to retry.';

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
  String get merchantQueueToHandle => 'Orders to handle';

  @override
  String get merchantQueueOthers => 'Other orders';

  @override
  String get merchantQueueNewChip => 'New order';

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
  String get merchantStatusPickedUp => 'On the way';

  @override
  String get merchantStatusDelivered => 'Delivered';

  @override
  String get merchantStatusUnknown => 'Updating';

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
  String get supportAttachTitle => 'Attachments';

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
  String get supportAttachPdfNote => 'PDF attached.';

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
  String get helpSubtitle => 'Need help?';

  @override
  String get helpFaqEmpty => 'No FAQ yet.';

  @override
  String rideShareMessage(String url) {
    return 'Follow my DealGo trip live: $url';
  }

  @override
  String get rideShareSubject => 'My DealGo trip';

  @override
  String get rideShareSentChip => 'Shared';

  @override
  String get rideSafetyCopyLink => 'Copy link';

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
  String get merchantRejectReasonTitle => 'Reject reason';

  @override
  String get merchantRejectNoteRequired => 'Note for the customer (required)';

  @override
  String get merchantRejectNoteOptional => 'Note for the customer (optional)';

  @override
  String get vouchersUse => 'Use for food order';

  @override
  String vouchersUseDone(String code) {
    return 'Code $code added to your cart (and copied). It is checked again at checkout.';
  }

  @override
  String get vouchersFootnote => 'Discount applied at checkout.';

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
  String get rideQuoteExpiredBadge => 'Expired';

  @override
  String get foodCancelledBrowse => 'Choose another store';

  @override
  String get rideMatchingReceiving => 'Receiving offers';

  @override
  String get rideMatchingSearching => 'Waiting for offers';

  @override
  String get rideMatchingLoadFailed =>
      'Could not load the request. The trip status has not changed.';

  @override
  String get rideMatchingSent => 'Offer sent';

  @override
  String get rideMatchingWaiting => 'Waiting for drivers to make offers...';

  @override
  String rideViewersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drivers are viewing your request',
      one: '1 driver is viewing your request',
    );
    return '$_temp0';
  }

  @override
  String get rideViewersNone => 'No driver has opened your request yet';

  @override
  String get rideViewersNotifying => 'Notifying drivers nearby';

  @override
  String rideAutoAcceptLabel(String price) {
    return 'Auto-accept when a driver agrees to $price';
  }

  @override
  String get rideAutoAcceptHint =>
      'Only your exact price is accepted. A different price still needs you to choose.';

  @override
  String get rideStatusLabel => 'Status';

  @override
  String get rideStatusNegotiating => 'Negotiating';

  @override
  String get rideStatusAssigned => 'Driver assigned';

  @override
  String get rideStatusDriverEnRoute => 'Driver on the way';

  @override
  String get rideStatusDriverArrived => 'Driver arrived';

  @override
  String get rideStatusInTrip => 'Trip in progress';

  @override
  String get rideStatusCompleted => 'Completed';

  @override
  String get rideStatusCancelled => 'Cancelled';

  @override
  String get rideStatusExpired => 'Expired';

  @override
  String get rideNoOffersTitle => 'No offers yet';

  @override
  String get rideNoOffersMessage => 'No driver offers yet.';

  @override
  String get rideProgress => 'Progress';

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
  String get rideTimeoutMessage => 'Timed out, no driver.';

  @override
  String get rideCurrentRoute => 'Selected route';

  @override
  String get rideCurrentOfferedFare => 'Current offered fare';

  @override
  String get rideOfferedFare => 'Offered fare';

  @override
  String get rideEditRoute => 'Edit route';

  @override
  String get rideFindAgain => 'Find a driver again';

  @override
  String get rideAssignedNote => 'Driver accepted.';

  @override
  String get rideTrack => 'Track trip';

  @override
  String get rideConfirmTitle => 'Confirm ride';

  @override
  String get rideConfirmNoAgreed =>
      'The agreed fare for this trip has not arrived yet. Please try again.';

  @override
  String get rideConfirmNewPrice => 'Confirm new fare';

  @override
  String get rideFareChangedTitle => 'Fare changed';

  @override
  String get rideFareChangedMessage => 'Old quote is invalid. Review the fare.';

  @override
  String get rideCompareFares => 'Compare fares';

  @override
  String get rideFareYouPicked => 'Fare you picked';

  @override
  String get rideFareDifference => 'Difference';

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
  String get rideCashNote => 'Pay at the end';

  @override
  String get rideFarePendingExists =>
      'You already have a pending offer. Open it or cancel it before sending a new fare.';

  @override
  String get rideFareSendFailed => 'Could not send your offer.';

  @override
  String get rideYourOffer => 'Your offer';

  @override
  String get rideSuggestedFareShort => 'Suggested';

  @override
  String get ridePickVehicleClassFirst =>
      'Choose a vehicle class (bike or car) before sending your offer.';

  @override
  String get rideEnterAmount => 'Enter amount';

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
  String get rideListRefreshFailed => 'Could not refresh the list.';

  @override
  String get rideChangeOffer => 'Change offer';

  @override
  String get rideQuoteExpiredTitle => 'Offer expired';

  @override
  String get rideQuoteExpiredMessage => 'Quote expired.';

  @override
  String get rideOldFare => 'Old fare (for reference)';

  @override
  String get rideFindNewOffers => 'Find new offers';

  @override
  String get rideOfferTakenTitle => 'Driver unavailable';

  @override
  String get rideOfferTakenMessage => 'Offer no longer available.';

  @override
  String get ridePreviousOffer => 'Previous offer';

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
  String rideFindDriverCta(String amount) {
    return 'Find a driver · $amount';
  }

  @override
  String get rideFindDriverPlain => 'Find a driver';

  @override
  String rideRecommendedFareLabel(String amount) {
    return 'Recommended fare $amount';
  }

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
  String get driverServicesNotRegistered => 'Not registered';

  @override
  String get driverServicesNoneOn =>
      'Every service is off, so you will not get new jobs.';

  @override
  String driverVehiclePlate(String plate) {
    return 'Plate $plate';
  }

  @override
  String get driverVehicleUnknown =>
      'No plate number in your driver application';

  @override
  String get driverVehicleNotOnFile => 'No vehicle on file yet';

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
  String get driverOfflineHeroMessage => 'Go online for rides and deliveries.';

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
  String get driverIneligibleMessage => 'Account not approved or locked.';

  @override
  String get driverRightsByService => 'Access by service';

  @override
  String get driverServicePassenger => 'Rides';

  @override
  String get driverServiceBlocked => 'Not available';

  @override
  String get driverAllowedServices => 'Services you take';

  @override
  String get driverConfigure => 'Settings';

  @override
  String get driverOnlineBadge => 'Online';

  @override
  String get driverOnDutyMapLabel => 'Taking jobs';

  @override
  String get driverRideLoadFailed =>
      'Could not load the ride. Check your connection and try again.';

  @override
  String get driverRideDetailTitle => 'Ride request';

  @override
  String get driverCounterOffer => 'Counter offer';

  @override
  String driverAcceptAtPrice(String price) {
    return 'Accept $price';
  }

  @override
  String get driverRideChip => 'Ride · Bike & Car';

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
  String get driverOfferTitle => 'Make an offer';

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
  String get driverWaitingForCustomerBody => 'Waiting for rider.';

  @override
  String get driverReadyToNavigate => 'Ready to pick up';

  @override
  String get driverReadyToNavigateBody => 'Open pickup route.';

  @override
  String get driverOfferLostBody => 'Rider chose another driver.';

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
  String get driverOfferHintSame => 'You are accepting the customer\'s fare.';

  @override
  String get driverOfferHintCounter =>
      'Different from the customer\'s fare. They will see it as your proposal.';

  @override
  String get driverOpenJobDetails => 'View job details';

  @override
  String get driverNoOpenRequests => 'No open requests right now';

  @override
  String get driverRidesAvailable => 'Rides you can take';

  @override
  String get driverFoodAvailable => 'Deliveries you can take';

  @override
  String driverFoodJobSummary(int count, String dropoff) {
    return '$count items · $dropoff';
  }

  @override
  String get driverDeliveryFare => 'Delivery fee';

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
  String get apiErrPasskeyUnavailable =>
      'This device or app version does not support passkeys yet.';

  @override
  String get apiErrPasskeyInvalid =>
      'Passkey verification failed. Please try again or use another sign-in method.';

  @override
  String get apiErrNetwork =>
      'Can\'t reach DealGo. Check your connection and try again.';

  @override
  String get apiErrInvalidResponse =>
      'We couldn\'t read the response. Please try again.';

  @override
  String get apiErrCarDocsTitle => 'Car documents needed';

  @override
  String get apiErrCarDocsBody =>
      'Car drivers need a vehicle insurance photo before taking trips. Add it so DealGo can review again.';

  @override
  String get actionCompleteDocuments => 'Complete documents';

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
  String get merchantIneligibleTitle => 'Can\'t take orders';

  @override
  String get merchantIneligibleMessage => 'Store not approved or locked.';

  @override
  String get merchantReloadOrders => 'Reload orders';

  @override
  String get merchantNoNewOrders => 'No new orders';

  @override
  String get merchantNoNewOrdersBody => 'New orders appear here.';

  @override
  String get merchantViewSavedOrders => 'View saved orders';

  @override
  String get merchantOrdersLoadFailed => 'Couldn\'t load orders';

  @override
  String get merchantOrdersLoadFailedBody => 'List may be outdated.';

  @override
  String get merchantConnection => 'Connection';

  @override
  String get merchantLoadFailedChip => 'Load failed';

  @override
  String get merchantLastSynced => 'Last synced';

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
  String get foodStageAwaitingStore => 'Waiting for the store to confirm';

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
  String get merchantItemPendingReview => 'Pending review';

  @override
  String get merchantItemRejected => 'Rejected';

  @override
  String get foodOrderSentTitle => 'Order sent';

  @override
  String get foodOrderPlaced => 'Order placed';

  @override
  String get foodOrderPlacedSub => 'Waiting for store';

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
  String get foodTrackOrder => 'Track order';

  @override
  String get foodReconnecting => 'Reconnecting...';

  @override
  String get foodReconnectingBody => 'Reconnecting…';

  @override
  String get foodOrderInProgress => 'Order in progress';

  @override
  String get foodCustomerPays => 'You pay';

  @override
  String get foodLastKnownStatus => 'Last known status';

  @override
  String foodLineQtyPrice(int quantity, String price) {
    return 'x$quantity · $price each';
  }

  @override
  String get homeSearchHint => 'Search places, stores, dishes...';

  @override
  String get homeServiceRideSub => 'Ride now';

  @override
  String get homeServiceFoodSub => 'Delivered to you';

  @override
  String get voiceOpenFailed => 'Couldn\'t start the call. Please try again.';

  @override
  String get mapIllustrative => 'Illustrative map';

  @override
  String get mapRouteRoadFollowed => 'Road route';

  @override
  String get mapRouteStraightFallback => 'Straight-line preview';

  @override
  String get rideVoucherTitle => 'Voucher';

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
  String get merchantBusyAccepting => 'Taking orders';

  @override
  String get merchantBusyNotAccepting => 'Not taking orders';

  @override
  String merchantBusyAcceptingBody(String store) {
    return 'Customers can order from $store.';
  }

  @override
  String get merchantBusyNotAcceptingBody => 'Customers can\'t order.';

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
  String get merchantBusySave => 'Save store status';

  @override
  String get merchantBusySaved => 'Store status saved.';

  @override
  String get checkoutErrStorePaused =>
      'This store isn\'t taking orders right now. Please try again later.';

  @override
  String get foodStorePausedBanner => 'This store has paused new orders.';

  @override
  String get foodStoreBusyBanner => 'Busy — slower prep.';

  @override
  String get merchantHomeBusyChip => 'Busy';

  @override
  String get merchantHomePausedChip => 'Paused';

  @override
  String get merchantHoursEyebrow => 'BUSINESS HOURS';

  @override
  String get merchantHoursHeading => 'Opening schedule';

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
  String get merchantHoursCutoffTitle => 'Last order before close';

  @override
  String get merchantHoursCutoffNone => 'None';

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
  String get foodStoreClosedBanner => 'Store is closed.';

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
  String merchantAcceptOrdersCount(int count) {
    return '$count orders';
  }

  @override
  String get merchantAcceptNoLimit => 'No limit';

  @override
  String get merchantAcceptPrep => 'Default prep time';

  @override
  String get merchantAcceptCutoff => 'Orders near closing';

  @override
  String get merchantAcceptSave => 'Save settings';

  @override
  String get merchantAcceptSaved => 'Order acceptance settings saved.';

  @override
  String get merchantAcceptPickTitle => 'Choose a value';

  @override
  String get merchantBusyExtraLabel => 'Extra prep time';

  @override
  String merchantBusyExtraHint(int minutes) {
    return 'Prep ≈$minutes min.';
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
  String get driverNavAppleMaps => 'Apple Maps';

  @override
  String get chatRoleDriver => 'Driver';

  @override
  String get chatRoleCustomer => 'Customer';

  @override
  String get chatRoleShop => 'Shop';

  @override
  String get chatCallAction => 'Call';

  @override
  String get chatCloseAction => 'Close';

  @override
  String get chatSendAction => 'Send';

  @override
  String get chatStatusSending => 'Sending';

  @override
  String get chatStatusSent => 'Sent';

  @override
  String get chatStatusFailed => 'Not sent · Tap to retry';

  @override
  String get chatToday => 'Today';

  @override
  String get chatYesterday => 'Yesterday';

  @override
  String get chatEmptyBody => 'Send a message to coordinate quickly';

  @override
  String chatUnreadCount(int count) {
    return '$count new messages';
  }

  @override
  String get chatQuickDriverComing => 'I\'m on my way';

  @override
  String get chatQuickDriverDelivering => 'I\'m on my way with your order';

  @override
  String get chatQuickDriverArrived => 'I\'ve arrived';

  @override
  String get chatQuickDriverWait => 'Give me 2 minutes';

  @override
  String get chatQuickCustomerGate => 'I\'m at the gate';

  @override
  String get chatQuickCustomerComing => 'Coming out now';

  @override
  String get chatQuickCustomerWhere => 'Where are you?';

  @override
  String get chatQuickCustomerLeaveAtGate => 'Please leave it at the gate';

  @override
  String get driverNavOpenFailed =>
      'Couldn\'t open a navigation app. Check Google Maps or Waze on this phone.';

  @override
  String get driverNavOpen => 'Navigate';

  @override
  String get driverNavSheetTitle => 'Navigate with';

  @override
  String get driverNavWeb => 'Google Maps (browser)';

  @override
  String get driverNavLastUsed => 'Last used';

  @override
  String get driverNavToPickup => 'To the pickup point';

  @override
  String get driverNavToDropoff => 'To the drop-off point';

  @override
  String get driverNavToStore => 'To the store';

  @override
  String get driverNavToCustomer => 'To the customer';

  @override
  String get driverRideUnassignedTitle => 'Ride reassigned';

  @override
  String get driverRideUnassignedStartTimeout =>
      'You didn\'t start heading to the pickup in time.';

  @override
  String get driverRideUnassignedArriveTimeout =>
      'You didn\'t reach the pickup in time.';

  @override
  String get driverRideUnassignedOps => 'DealGo support reassigned the ride.';

  @override
  String get driverRideUnassignedGeneric =>
      'The ride was reopened for new offers.';

  @override
  String get driverFoodDeliveryCodeTitle => 'Delivery code';

  @override
  String get driverFoodDeliveryCodeBody =>
      'Enter the customer\'s 4-digit code.';

  @override
  String get driverFoodHandoverCodeTitle => 'Handover code';

  @override
  String get driverFoodHandoverCodeBody => 'Enter the store\'s 4-digit code.';

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
  String get foodDeliveryCodeHint => 'Tell the driver this code on delivery.';

  @override
  String get merchantHandoverCodeLabel => 'Handover code';

  @override
  String get merchantHandoverCodeHint => 'Tell the driver this code at pickup.';

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
  String get deleteAccountWarnTitle => 'Please note';

  @override
  String get deleteAccountWarnBody => 'This can\'t be undone.';

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
  String get deleteAccountContinue => 'Continue';

  @override
  String get deleteAccountKeep => 'Keep account';

  @override
  String get deleteAccountVerifyTitle => 'Verify it\'s you';

  @override
  String get deleteAccountPasswordBody => 'Enter your password to confirm.';

  @override
  String get deleteAccountPasswordLabel => 'Password';

  @override
  String get deleteAccountCodeLabel => 'Verification code';

  @override
  String get deleteAccountConfirm => 'Confirm deletion';

  @override
  String get deleteAccountRestart => 'Start again';

  @override
  String get deleteAccountDoneTitle => 'Deletion requested';

  @override
  String get deleteAccountDoneAction => 'Back to sign in';

  @override
  String get deleteAccountLoadError =>
      'Couldn\'t load account deletion details.';

  @override
  String get deleteAccountReauthUnavailable =>
      'This account can\'t be re-verified in the app yet. Please contact support.';

  @override
  String get deleteAccountWrongPassword => 'Wrong password.';

  @override
  String get deleteAccountWrongCode => 'Wrong verification code.';

  @override
  String get deleteAccountLocked => 'Too many failed attempts. Start again.';

  @override
  String get deleteAccountPasskeyVerify => 'Verify passkey';

  @override
  String get deleteAccountWrongPasskey => 'Passkey verification failed.';

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
  String get editProfilePhoneLocked =>
      'Verified phone; it can\'t be changed here.';

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
  String get editProfileSave => 'Save changes';

  @override
  String get editProfileSaved => 'Profile saved';

  @override
  String get notifPrefsHeader => 'Notification settings';

  @override
  String get notifPrefsTitle => 'Your notifications';

  @override
  String get notifPrefsPushOn => 'Push notifications are on';

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
  String get notifPrefsNewJobSound => 'New job sound';

  @override
  String get notifPrefsNewJobSoundBody =>
      'Say \"DealGo, new job\" on new jobs.';

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
  String get securityProtected => 'Account is protected';

  @override
  String get securityLoginSection => 'Sign-in and verification';

  @override
  String get securityPhone => 'Phone number';

  @override
  String get securityVerified => 'Verified';

  @override
  String get securityEmail => 'Email';

  @override
  String get securityPasskey => 'Passkey';

  @override
  String get securitySessions => 'Devices and sessions';

  @override
  String get securityChangePassword => 'Change password';

  @override
  String get securityPrivacySection => 'Privacy';

  @override
  String get securityPermissions => 'App permissions';

  @override
  String get securityTerms => 'Terms & personal data';

  @override
  String get securityAccountSection => 'Account management';

  @override
  String get securityDelete => 'Request account deletion';

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
  String get merchantHistorySearch => 'Search by order id or customer';

  @override
  String get merchantHistoryAll => 'All';

  @override
  String get merchantHistoryDone => 'Completed';

  @override
  String get merchantHistoryCancelled => 'Cancelled';

  @override
  String merchantHistoryRevenue(String amount) {
    return 'Completed revenue: $amount';
  }

  @override
  String get merchantHistoryList => 'Orders';

  @override
  String get merchantHistoryEmpty => 'No finished orders yet';

  @override
  String get merchantCategoriesTitle => 'Categories';

  @override
  String get merchantCategoriesHeadline => 'Manage categories';

  @override
  String get merchantCategoriesSearch => 'Search categories';

  @override
  String merchantCategoriesCount(String count) {
    return '$count categories';
  }

  @override
  String merchantCategoriesItemsOnSale(String count) {
    return '$count items on sale';
  }

  @override
  String get merchantCategoriesAdd => 'Add category +';

  @override
  String get merchantCategoriesEmpty => 'No categories yet';

  @override
  String get merchantCategoryName => 'Category name';

  @override
  String get merchantCategoryDesc => 'Description (optional)';

  @override
  String get merchantItemEditTitle => 'Add / edit item';

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
  String get merchantItemPhotoPick => 'Choose photo';

  @override
  String get merchantItemPhotoUploading => 'Uploading photo…';

  @override
  String get merchantItemPhotoClear => 'Remove photo';

  @override
  String get merchantItemPhotoError => 'Could not upload the photo. Try again.';

  @override
  String get merchantCategoriesReordered => 'Category order saved';

  @override
  String merchantProductsSoldCount(String count) {
    return 'Sold $count';
  }

  @override
  String get merchantProductsSearch => 'Search items';

  @override
  String get merchantProductsFilterAll => 'All';

  @override
  String get merchantProductsFilterOnSale => 'On sale';

  @override
  String get merchantProductsFilterHidden => 'Hidden / draft';

  @override
  String get merchantProductsEmptyFilter => 'No items match this filter';

  @override
  String get merchantProductsEmptyMenu =>
      'No items yet. Tap “Add item” to start selling.';

  @override
  String get merchantOptionsChoiceMaxQty => 'Max quantity per line';

  @override
  String merchantOptionsMaxQty(String count) {
    return 'Max ×$count';
  }

  @override
  String get merchantCategoriesSearchHint => 'Search categories';

  @override
  String get merchantEditStatusHidden =>
      'Hidden / draft — not visible to customers';

  @override
  String get merchantEditStatusOnSale => 'On sale';

  @override
  String get merchantLocationTitle => 'Store location';

  @override
  String get merchantLocationUnset => 'No pin set — store is hidden.';

  @override
  String get merchantLocationPinNow => 'Pin now';

  @override
  String get merchantLocationUnsetValue => 'Not set';

  @override
  String get merchantLocationPickHint => 'Pick on map';

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
  String get forgotPasswordIntro => 'Enter your email to get a 6-digit code.';

  @override
  String get forgotPasswordSendCode => 'Send code';

  @override
  String forgotPasswordCodeSent(String email) {
    return 'If $email has a password account, a 6-digit code was sent to it. The code is valid for a few minutes.';
  }

  @override
  String get forgotPasswordCodeLabel => '6-digit code from the email';

  @override
  String get forgotPasswordNewLabel => 'New password (6+ chars)';

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
      'This device or app version does not support passkeys yet.';

  @override
  String get securityPasskeyExists =>
      'This device already has a passkey for your account.';

  @override
  String get securityPasskeyFailed =>
      'Could not add the passkey. Please try again.';

  @override
  String get securityPasskeyNeedsVerifiedLogin =>
      'Verify your account before adding a passkey.';

  @override
  String get merchantProfileTitle => 'Store profile';

  @override
  String get merchantProfileName => 'Store name';

  @override
  String get merchantProfileNameInvalid =>
      'Store name must be 2 to 120 characters.';

  @override
  String get merchantProfileCategory => 'Store category';

  @override
  String get merchantProfileSave => 'Save changes';

  @override
  String get merchantProfileSaved => 'Store profile saved.';

  @override
  String get merchantProfileLogo => 'Store logo';

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
  String get accountStoreProfileBody => 'Store name, category and logo';

  @override
  String get foodReorderConfirmTitle => 'Reorder this order?';

  @override
  String get foodReorderConfirmBody => 'Add items at current prices?';

  @override
  String get actionReorder => 'Reorder';

  @override
  String get foodReorderNone =>
      'None of the old order\'s dishes are available now';

  @override
  String foodReorderPartial(int count) {
    return '$count unavailable item(s) were left out';
  }

  @override
  String get kycQuickModeBanner => 'Quick sign-up, no documents.';

  @override
  String get kybQuickModeBanner => 'Quick sign-up, no documents.';

  @override
  String get handoverRefLabel => 'Handover code';

  @override
  String handoverRefSemantics(String ref) {
    return 'Handover code $ref';
  }

  @override
  String get rideRebookAction => 'Rebook ride';

  @override
  String trackEtaMinutes(int minutes) {
    return '≈$minutes min';
  }

  @override
  String get trackStepFinding => 'Finding';

  @override
  String get trackStepComing => 'Coming';

  @override
  String get trackStepArrived => 'Arrived';

  @override
  String get trackStepOnTrip => 'On trip';

  @override
  String get trackStepDone => 'Done';

  @override
  String get trackStepPlaced => 'Placed';

  @override
  String get trackStepPreparing => 'Cooking';

  @override
  String get trackStepReady => 'Ready';

  @override
  String get trackStepDriverToStore => 'Driver to store';

  @override
  String get trackStepDelivering => 'On the way';

  @override
  String get trackStepDelivered => 'Delivered';

  @override
  String trackItemsMore(int count) {
    return '+$count more';
  }

  @override
  String get foodStageFindingDriver => 'Finding a driver';

  @override
  String get foodStageDriverToStore => 'Driver heading to the store';

  @override
  String get foodStageDeliveringToYou => 'Driver is on the way to you';

  @override
  String get accountSignOutConfirmTitle => 'Sign out?';

  @override
  String get accountSignOutConfirmBody => 'You\'ll need to sign in again.';

  @override
  String get accountSignOutCancel => 'Cancel';

  @override
  String get rideOfferConfirmTitle => 'Choose this driver?';

  @override
  String rideOfferConfirmBody(String amount) {
    return 'Fare $amount.';
  }

  @override
  String get rideOfferConfirmAction => 'Choose driver';

  @override
  String get rideOfferConfirmCancel => 'Review';

  @override
  String get rideRaiseFare => 'Raise fare';

  @override
  String get rideRaiseFareTitle => 'Raise your offer';

  @override
  String rideRaiseFareBody(String amount) {
    return 'Current fare: $amount';
  }

  @override
  String rideRaiseFareStep(String amount) {
    return '+$amount';
  }

  @override
  String rideRaiseFareDone(String amount) {
    return 'Fare raised to $amount';
  }

  @override
  String get rideDeclineOffer => 'Decline this price';

  @override
  String get rideDeclineOfferDone =>
      'Offer declined. The driver can send a new price.';

  @override
  String get driverWithdrawOffer => 'Withdraw offer';

  @override
  String get driverWithdrawOfferDone => 'Offer withdrawn';

  @override
  String get driverCustomerRating => 'Customer rating';

  @override
  String driverCustomerRatingValue(String average, int count) {
    return '$average★ ($count ratings)';
  }

  @override
  String get driverCustomerRatingNone => 'No ratings yet';

  @override
  String get driverCancelRide => 'Cancel ride';

  @override
  String get driverCancelReasonTitle => 'Why are you cancelling?';

  @override
  String get driverCancelHint => 'Counts toward your cancel rate.';

  @override
  String get driverCancelReasonCustomerUnreachable =>
      'Can\'t reach the customer';

  @override
  String get driverCancelReasonPickupTooFar => 'Pickup is too far';

  @override
  String get driverCancelReasonVehicleProblem => 'Vehicle problem';

  @override
  String get driverCancelReasonSafetyConcern => 'Safety concern';

  @override
  String get driverCancelReasonCustomerAsked => 'Customer asked to cancel';

  @override
  String get driverCancelReasonOther => 'Other reason';

  @override
  String get driverCancelDone => 'Ride cancelled';

  @override
  String get driverNoShow => 'Customer didn\'t show';

  @override
  String get driverNoShowBody => 'Use only after waiting at pickup.';

  @override
  String get driverNoShowDone => 'No-show recorded. The ride is closed.';

  @override
  String get driverRateCustomerTitle => 'Rate the customer';

  @override
  String get driverRateCustomerSubmit => 'Send rating';

  @override
  String get driverRateCustomerDone => 'Rating sent – thank you!';

  @override
  String driverRateCustomerYours(int stars) {
    return 'Your rating: $stars★';
  }

  @override
  String get driverRateTagOnTime => 'On time';

  @override
  String get driverRateTagPolite => 'Polite';

  @override
  String get driverRateTagClearPickup => 'Clear pickup';

  @override
  String get driverRateTagLate => 'Kept me waiting';

  @override
  String get driverRateTagRude => 'Rude';

  @override
  String get driverRateTagWrongPickup => 'Wrong pickup point';

  @override
  String get driverFoodRelease => 'Return order';

  @override
  String get driverFoodReleaseTitle => 'Why return this order?';

  @override
  String get driverFoodReleaseHint => 'Releasing counts as a cancel.';

  @override
  String get driverFoodReleaseStoreTooSlow => 'Store is too slow';

  @override
  String get driverFoodReleaseStoreClosed => 'Store is closed';

  @override
  String get driverFoodReleaseVehicleProblem => 'Vehicle problem';

  @override
  String get driverFoodReleaseSafetyConcern => 'Safety concern';

  @override
  String get driverFoodReleaseOther => 'Other reason';

  @override
  String get driverFoodReleaseDone => 'Order returned';

  @override
  String get driverFailNoteLabel => 'Details (required)';

  @override
  String get driverFailNoteRequired => 'Please describe what happened.';

  @override
  String get driverFailAbsentHint => 'Call and text first, wait a few minutes.';

  @override
  String get driverFoodFailedDone => 'Delivery reported as failed';

  @override
  String get apiErrLiveOffersFull =>
      'This ride already has the maximum number of offers. Try again shortly.';

  @override
  String get apiErrFareRaiseLimit =>
      'You can\'t raise the fare any more for this ride.';

  @override
  String get apiErrCancelCooldown =>
      'You\'ve cancelled several rides recently. Please wait a little before booking again.';

  @override
  String get apiErrRepostInvalid => 'This ride can\'t be reposted.';

  @override
  String get apiErrFailTooEarly =>
      'Wait at the drop-off a few more minutes before reporting the customer unreachable.';

  @override
  String get apiErrFailNoteRequired =>
      'Please add a note describing the problem.';

  @override
  String get apiErrStoreLocationRequired =>
      'This store hasn\'t set its location yet.';

  @override
  String get apiErrDriverLocationStale =>
      'We don\'t have your current location yet. Turn on location and pull to refresh.';

  @override
  String get apiErrOutsideServiceZone =>
      'This address is outside our service area.';

  @override
  String get apiErrTooFar => 'The delivery address is too far from this store.';

  @override
  String get apiErrSettlementOverlap =>
      'This period overlaps an existing statement.';

  @override
  String get apiErrSettlementPeriodOpen => 'This period hasn\'t ended yet.';

  @override
  String get apiErrShopLocationRequired =>
      'Pin your shop location on the map to continue.';

  @override
  String get apiErrChangePending =>
      'There\'s already an order change waiting for the customer.';

  @override
  String get apiErrChangeInvalid =>
      'This change isn\'t allowed. You can only lower quantities or remove items.';

  @override
  String get apiErrChangeNotFound =>
      'This change is no longer waiting for an answer.';

  @override
  String get foodCancelChangeRejected => 'You declined the store\'s change';

  @override
  String get foodCancelChangeExpired =>
      'The store\'s change wasn\'t answered in time';

  @override
  String get foodChangeTitle => 'Store changed order';

  @override
  String get foodChangeReasonOutOfStock => 'Some items are sold out';

  @override
  String get foodChangeReasonNotEnough => 'Not enough portions left';

  @override
  String get foodChangeReasonOther => 'Other reason';

  @override
  String get foodChangeLineRemoved => 'Removed';

  @override
  String get foodChangeNewTotal => 'New total';

  @override
  String foodChangeAnswerBy(String time) {
    return 'Answer by $time, otherwise the order is cancelled for free.';
  }

  @override
  String get foodChangeAccept => 'Accept';

  @override
  String get foodChangeReject => 'Cancel order';

  @override
  String get foodChangeRejectConfirmTitle => 'Cancel this order?';

  @override
  String get foodChangeRejectConfirmBody =>
      'Order will be cancelled at no cost.';

  @override
  String get merchantEditOrder => 'Report sold-out items';

  @override
  String get merchantEditOrderHint => 'Customer must approve changes.';

  @override
  String get merchantEditOrderNote => 'Note for the customer';

  @override
  String get merchantEditOrderAllRemoved =>
      'To remove every item, reject the order instead.';

  @override
  String merchantEditOrderNewSubtotal(String amount) {
    return 'New food value: $amount';
  }

  @override
  String get merchantEditOrderSend => 'Send to customer';

  @override
  String merchantChangePending(String total, String time) {
    return 'Waiting for the customer to accept the change (new total $total) until $time.';
  }

  @override
  String get pushForegroundOpen => 'View';

  @override
  String get mapPinPickup => 'Pickup';

  @override
  String get mapPinDropoff => 'Drop-off';

  @override
  String get mapPinStore => 'Store';

  @override
  String get mapPinHome => 'Deliver';

  @override
  String get mapPickerTitle => 'Pick on map';

  @override
  String get mapPickerConfirm => 'Use this location';

  @override
  String get mapPickerPinned => 'Pinned location';

  @override
  String get mapPickerSearch => 'Search places';

  @override
  String get mapStyleTitle => 'Map style';

  @override
  String get mapStyleStandard => 'Standard';

  @override
  String get mapStyleSatellite => 'Satellite';

  @override
  String get mapStyleDark => 'Dark';

  @override
  String get mapOpenSettings => 'Settings';

  @override
  String homeBannerSlideLabel(int index, int count) {
    return 'Banner $index of $count';
  }

  @override
  String foodStoreFeeFrom(String fee) {
    return 'Delivery from $fee';
  }

  @override
  String foodStoreOpenUntil(String time) {
    return 'Open until $time';
  }

  @override
  String get foodOffersNearTitle => 'Deals near you';

  @override
  String get foodStoreOffersTitle => 'Store deals';

  @override
  String get foodStoreOfferUse => 'Use';

  @override
  String foodStoreOfferApplied(String code) {
    return 'Code $code added to this order';
  }

  @override
  String get foodStoreSearchMenu => 'Search this menu';

  @override
  String get foodStoreSearchNone => 'No matching dishes';

  @override
  String get foodStoreSectionOther => 'More dishes';

  @override
  String get foodStoreReviewsAll => 'All';

  @override
  String get foodStoreReviewsMore => 'Show more';

  @override
  String get foodStoreMerchantReply => 'Store reply';

  @override
  String get foodStoreReviewsFilterNone => 'No matching reviews';

  @override
  String foodItemSold(int count) {
    return '$count sold';
  }

  @override
  String get merchantOffersTitle => 'Store deals';

  @override
  String get merchantOffersEmpty => 'No deals yet';

  @override
  String get merchantOffersCreate => 'New deal';

  @override
  String get merchantOfferNewTitle => 'New deal';

  @override
  String get merchantOfferStatusActive => 'Live';

  @override
  String get merchantOfferStatusPaused => 'Paused';

  @override
  String get merchantOfferStatusEnded => 'Ended';

  @override
  String get merchantOfferStatusUpcoming => 'Upcoming';

  @override
  String get merchantOfferPause => 'Pause';

  @override
  String get merchantOfferResume => 'Resume';

  @override
  String get merchantOfferEnd => 'End';

  @override
  String merchantOfferEndConfirm(String name) {
    return 'End $name?';
  }

  @override
  String merchantOfferUsage(int used, int limit) {
    return 'Used $used/$limit';
  }

  @override
  String merchantOfferLimitReached(int count) {
    return '$count deals already live';
  }

  @override
  String get merchantOfferFormName => 'Deal name';

  @override
  String get merchantOfferFormCode => 'Code';

  @override
  String get merchantOfferKindPercent => 'Percent off';

  @override
  String get merchantOfferKindFixed => 'Amount off';

  @override
  String get merchantOfferFormPercent => 'Percent';

  @override
  String get merchantOfferFormAmount => 'Amount';

  @override
  String get merchantOfferFormMax => 'Max discount';

  @override
  String get merchantOfferFormMinOrder => 'Minimum order';

  @override
  String get merchantOfferFormUsage => 'Total uses';

  @override
  String get merchantOfferFormPerUser => 'Uses per customer';

  @override
  String get merchantOfferFormStart => 'Starts';

  @override
  String get merchantOfferFormEnd => 'Ends';

  @override
  String get merchantOfferFieldRequired => 'Required';

  @override
  String get merchantOfferFieldInvalid => 'Invalid';

  @override
  String get merchantOfferMinBelowValue => 'Must be at least the discount';

  @override
  String get merchantOfferSave => 'Create deal';

  @override
  String get merchantReviewsTitle => 'Customer reviews';

  @override
  String get merchantReviewsEmpty => 'No reviews yet';

  @override
  String get merchantReviewHidden => 'Hidden';

  @override
  String get merchantReviewReply => 'Reply';

  @override
  String get merchantReviewEditReply => 'Edit reply';

  @override
  String get merchantReviewReplySend => 'Send';

  @override
  String get merchantReviewReplyRemove => 'Remove reply';

  @override
  String get foodBadgeBestSeller => 'Best seller';

  @override
  String get foodBadgeNew => 'New';

  @override
  String foodStoreMinOrder(String amount) {
    return 'Min. order $amount';
  }

  @override
  String get foodCollectionNear => 'Near you';

  @override
  String get foodCollectionTopRated => 'Top rated';

  @override
  String get foodCollectionDeals => 'On sale';

  @override
  String get foodCollectionNewDishes => 'New dishes';

  @override
  String foodEtaArriveAt(String time) {
    return 'Arrives around $time';
  }

  @override
  String foodCartBarShortfall(String amount) {
    return '$amount to go';
  }

  @override
  String foodCartMinOrderMissing(String amount) {
    return 'Add $amount more to reach the minimum order';
  }

  @override
  String get foodStoreInfoHours => 'Hours';

  @override
  String get foodStoreInfoMinOrder => 'Minimum order';

  @override
  String get foodStoreInfoNoMinOrder => 'None';

  @override
  String get foodStoreInfoPrep => 'Prep time';

  @override
  String get foodStoreTagsTitle => 'Customers say';

  @override
  String foodStoreSoldTotal(int count) {
    return '$count+ sold';
  }

  @override
  String voucherSaveAmount(String amount) {
    return 'Save $amount';
  }

  @override
  String get voucherBestPick => 'Best';

  @override
  String voucherNeedMore(String amount) {
    return 'Add $amount more';
  }

  @override
  String get voucherPickerApply => 'Use';

  @override
  String get checkoutErrMinOrder => 'The order is below the store minimum';

  @override
  String get merchantItemOriginalPrice => 'Original price';

  @override
  String get merchantItemOriginalPriceInvalid =>
      'Original price must be above the price';

  @override
  String get merchantStoreMinOrder => 'Minimum order';

  @override
  String get merchantStoreMinOrderInvalid => 'Enter 0 to 10,000,000';

  @override
  String get foodStoreFeeFree => 'Free delivery';

  @override
  String get merchantProfileCover => 'Cover photo';

  @override
  String get merchantProfileCoverAdd => 'Add cover photo';

  @override
  String get merchantProfileCoverChange => 'Change cover photo';

  @override
  String get merchantProfileCoverRemove => 'Remove cover photo';

  @override
  String get merchantProfileCoverSaved => 'Cover photo updated.';

  @override
  String get merchantProfileCoverRemoved => 'Cover photo removed.';

  @override
  String get merchantProfileDescription => 'About the store';

  @override
  String get foodStoreAbout => 'About';

  @override
  String voucherCap(String amount) {
    return 'Up to $amount';
  }

  @override
  String get voucherUsed => 'Used';

  @override
  String otpPasteChip(String code) {
    return 'Paste code $code';
  }

  @override
  String get otpNoCodeYet => 'Didn\'t get the code?';

  @override
  String get otpEmailSpamHint =>
      'Can\'t find the email? Check your Spam or Promotions folder.';

  @override
  String get emailVerifyLocked =>
      'Too many wrong codes. Resend to get a new code.';

  @override
  String get emailVerifySuccess => 'Email verified';

  @override
  String get emailVerifyPendingNotice =>
      'Your new email is saved only after you enter the verification code.';

  @override
  String get profileEmailUnverified => 'Email not verified';

  @override
  String get profileEmailVerifyAction => 'Verify';

  @override
  String get draftResumeTitle => 'Continue where you left off?';

  @override
  String get draftResumeBody =>
      'We saved your progress on this device. Continue, or start over?';

  @override
  String get draftResumeContinue => 'Continue';

  @override
  String get draftResumeDiscard => 'Start over';

  @override
  String get draftRestoredNote => 'Restored your unsent draft.';

  @override
  String rideStopNumbered(int n) {
    return 'Stop $n';
  }

  @override
  String get rideAddStop => 'Add stop';

  @override
  String get rideRemoveStop => 'Remove stop';

  @override
  String get rideMoveStopUp => 'Move stop up';

  @override
  String rideStopsMax(int n) {
    return 'Up to $n stops';
  }

  @override
  String rideStopFeeNote(String fee) {
    return 'Each stop adds $fee';
  }

  @override
  String get rideStopFeeLine => 'Stop fee';

  @override
  String get rideWaitFeeLine => 'Waiting at stops';

  @override
  String get rideStopPending => 'Not yet';

  @override
  String get rideStopArrived => 'Driver waiting';

  @override
  String get rideStopDeparted => 'Done';

  @override
  String rideStopsCount(int n) {
    return '+$n stops';
  }

  @override
  String get rideRouteChanged =>
      'The customer changed the route. Review it and offer again.';

  @override
  String get rideStopsLocked =>
      'Stops can only be changed before a driver is chosen.';

  @override
  String get rideStopsUnavailable =>
      'Stops are not available for this service right now.';

  @override
  String driverStopArrive(int n) {
    return 'Arrived at stop $n';
  }

  @override
  String driverStopDepart(int n) {
    return 'Leave stop $n';
  }

  @override
  String get driverStopsTitle => 'Stops';

  @override
  String driverStopFreeWait(int m, String fee) {
    return 'Free wait $m min, then $fee/min';
  }

  @override
  String driverNavigateToStop(int n) {
    return 'Navigate to stop $n';
  }

  @override
  String get driverStopsPendingError =>
      'Finish every stop before completing the trip.';

  @override
  String get rideEditStops => 'Edit stops';

  @override
  String get rideEditStopsSave => 'Update route';

  @override
  String get rideEditStopsConfirmTitle => 'Change stops?';

  @override
  String get rideEditStopsConfirmBody =>
      'Changing the route clears current driver offers and restarts the search.';

  @override
  String get rideEditStopsConfirmAction => 'Change route';

  @override
  String get rideEditStopsDone => 'Route updated. Waiting for new offers.';

  @override
  String get rideStopsNone => 'No stops yet';

  @override
  String mapPinStop(int n) {
    return 'Stop $n';
  }

  @override
  String get paymentGroupWallet => 'E-wallets';

  @override
  String get paymentGroupCard => 'Credit/debit cards';

  @override
  String get paymentGroupRecommended => 'Recommended';

  @override
  String get paymentGroupAddMore => 'More methods';

  @override
  String get paymentCashLabel => 'Cash';

  @override
  String get paymentCashSubtitle => 'Pay the driver directly';

  @override
  String get paymentStatusCash => 'Cash payment';

  @override
  String get paymentStatusNotStarted => 'Not paid yet';

  @override
  String get paymentStatusPending => 'Waiting for payment confirmation';

  @override
  String get paymentStatusPaid => 'Payment successful';

  @override
  String get paymentStatusFailed => 'Payment failed';

  @override
  String get paymentStatusExpired => 'Payment session expired';

  @override
  String get paymentStatusRefundPending => 'Refund in progress';

  @override
  String get paymentStatusRefunded => 'Refunded';

  @override
  String get paymentSheetTitle => 'Payment method';

  @override
  String get paymentClose => 'Close';

  @override
  String get paymentUnavailable => 'Unavailable';

  @override
  String get paymentChange => 'Change';

  @override
  String get paymentSessionExpired => 'Your session has expired.';

  @override
  String get paymentStartFailed =>
      'Couldn\'t start the payment. Try again or pay in cash.';

  @override
  String get paymentStatusLoadFailed => 'Couldn\'t load the payment status.';

  @override
  String get paymentHeader => 'Payment';

  @override
  String get paymentPreparing => 'Preparing payment…';

  @override
  String get paymentPendingHint =>
      'Finish paying in your wallet/bank app, then come back to DealGo. The status updates automatically.';

  @override
  String get paymentReopen => 'Reopen payment page';

  @override
  String get paymentRetry => 'Try again';

  @override
  String get paymentSwitchToCash => 'Switch to cash';

  @override
  String get paymentContinue => 'Continue';

  @override
  String get driverPaymentMethod => 'Payment method';

  @override
  String get driverPaidOnline => 'Paid online';

  @override
  String driverPaidOnlineAmount(String amount) {
    return 'Paid online $amount';
  }

  @override
  String get driverOnlinePaymentPending =>
      'Customer\'s online payment not confirmed yet';

  @override
  String get profilePhone => 'Phone number';

  @override
  String get profilePhoneHint =>
      'So the driver and the shop can reach you about orders. No verification code needed.';

  @override
  String get profilePhoneInvalid =>
      'Enter a valid Vietnamese mobile number (e.g. 0901 234 567).';

  @override
  String get driverJobPushGone =>
      'This request was cancelled or taken by another driver.';

  @override
  String get incomingJobTitle => 'New ride request';

  @override
  String get incomingJobSkip => 'Skip';

  @override
  String get incomingJobOpen => 'View & quote';

  @override
  String get driverStartTrip => 'Start trip';

  @override
  String get rideOfferAcceptShort => 'Accept';

  @override
  String get rideOfferDeclineShort => 'Decline';

  @override
  String driverSendQuoteAmount(String amount) {
    return 'Offer $amount';
  }

  @override
  String get driverWithdrawOfferShort => 'Withdraw';

  @override
  String get incomingJobDetails => 'Details';

  @override
  String get kycCaptureFrontTitle => 'Capture ID front';

  @override
  String get kycCaptureBackTitle => 'Capture ID back';

  @override
  String get kycCaptureAlignHint =>
      'Fit the card in the frame, well lit, no glare';

  @override
  String get kycCaptureChecking => 'Checking photo…';

  @override
  String get kycCaptureBlurry => 'Photo is blurry';

  @override
  String get kycCaptureGlare => 'Photo has glare';

  @override
  String get kycCaptureDark => 'Photo is too dark';

  @override
  String get kycCaptureRetake => 'Retake';

  @override
  String get kycCaptureCameraError => 'Could not open the camera.';

  @override
  String get kycLivenessTitle => 'Face check';

  @override
  String get kycLivenessCenter => 'Look straight at the frame';

  @override
  String get kycLivenessTurnLeft => 'Turn your face left';

  @override
  String get kycLivenessTurnRight => 'Turn your face right';

  @override
  String get kycLivenessBlink => 'Blink your eyes';

  @override
  String get kycLivenessNoFace => 'No face in the frame';

  @override
  String get kycLivenessManyFaces => 'Only one person in the frame';

  @override
  String get kycLivenessDone => 'Done';

  @override
  String get kycLivenessTimeout => 'Time is up, try again';

  @override
  String get kycHintFindCard => 'Fit the card in the frame';

  @override
  String get kycHintCloser => 'Closer';

  @override
  String get kycHintMoreLight => 'More light';

  @override
  String get kycHintNoGlare => 'Avoid glare';

  @override
  String get kycHintHoldStill => 'Hold still';

  @override
  String get kycHintCaptured => 'Captured';

  @override
  String get kycHintFaceInOval => 'Face in the oval';

  @override
  String get kycLivenessRecording => 'Recording';

  @override
  String get partnerDocSelfieVideo => 'Face video';

  @override
  String get livenessClipRetry =>
      'The face video didn\'t save (missing or too large). Let\'s try again.';

  @override
  String get parcelWhereTo => 'Where is the package going?';

  @override
  String get driverServiceParcel => 'Goods delivery';

  @override
  String get driverServiceParcelHint => 'Receive parcel delivery requests';

  @override
  String get homeServiceParcel => 'Delivery';

  @override
  String get homeServiceParcelSub => 'Send a package across town, fast';

  @override
  String get parcelDetailsTitle => 'Package details';

  @override
  String get parcelSizeTitle => 'Package size';

  @override
  String parcelSizeHint(String dims) {
    return 'Max size $dims';
  }

  @override
  String get parcelSizeS => 'Small';

  @override
  String get parcelSizeM => 'Medium';

  @override
  String get parcelSizeL => 'Large';

  @override
  String get parcelSizeXL => 'Extra large';

  @override
  String get parcelWeightLabel => 'Weight (optional)';

  @override
  String get parcelWeightInvalid => 'Enter a valid weight';

  @override
  String parcelWeightOver(String limit) {
    return 'Over $limit kg for this size';
  }

  @override
  String get parcelNoteLabel => 'Note for the driver (optional)';

  @override
  String get parcelSenderTitle => 'Sender';

  @override
  String get parcelRecipientTitle => 'Recipient';

  @override
  String get parcelNameLabel => 'Full name';

  @override
  String get parcelPhoneLabel => 'Phone number';

  @override
  String get parcelFieldRequired => 'Required';

  @override
  String get parcelPhoneInvalid => 'Enter a valid phone number';

  @override
  String get parcelPayerSender => 'Sender pays';

  @override
  String get parcelPayerRecipient => 'Recipient pays';

  @override
  String get parcelItemPhotoAdd => 'Add package photo';

  @override
  String get parcelItemPhotoAdded => 'Package photo added';

  @override
  String get parcelVehicleTitle => 'Vehicle';

  @override
  String parcelOptionHint(String min, String max) {
    return 'Offer $min – $max';
  }

  @override
  String get parcelQuoteCta => 'See price';

  @override
  String get parcelSubmitCta => 'Book delivery';

  @override
  String get parcelDriverBadge => 'Package';

  @override
  String get parcelOutcomeDelivered => 'Delivered';

  @override
  String get parcelOutcomeReturning => 'Returning to sender';

  @override
  String get parcelOutcomeReturned => 'Returned to sender';

  @override
  String get parcelOutcomeInTransit => 'On the way';

  @override
  String get parcelOutcomeWaitingPickup => 'Waiting for pickup';

  @override
  String get parcelFailUnreachable => 'Recipient unreachable';

  @override
  String get parcelFailRefused => 'Recipient refused';

  @override
  String get parcelFailAddress => 'Wrong address';

  @override
  String get parcelFailDamaged => 'Package damaged';

  @override
  String get parcelFailOther => 'Other reason';

  @override
  String get parcelFailTitle => 'Why can\'t it be delivered?';

  @override
  String get parcelErrorNoVehicle => 'No vehicle can carry this package size';

  @override
  String get parcelErrorTooHeavy => 'Package is too heavy for this size';

  @override
  String get parcelErrorRecipientCode => 'Recipient code is wrong';

  @override
  String get parcelErrorCodeLocked => 'Too many wrong codes. Try again later';

  @override
  String get parcelErrorSizeUnavailable =>
      'This size isn\'t available right now';

  @override
  String get parcelErrorPayerMethod => 'Recipient-pays only works with cash';

  @override
  String get parcelErrorPhoto => 'A photo is required';

  @override
  String get parcelErrorState => 'The delivery has changed. Refresh';

  @override
  String get parcelErrorNetwork => 'Connection problem. Try again';

  @override
  String get parcelErrorGeneric => 'Something went wrong';

  @override
  String get parcelRetry => 'Retry';

  @override
  String parcelSenderLine(String name, String phone) {
    return 'Sender: $name · $phone';
  }

  @override
  String parcelRecipientLine(String name, String phone) {
    return 'Recipient: $name · $phone';
  }

  @override
  String parcelRecipientCode(String code) {
    return 'Recipient code: $code';
  }

  @override
  String get parcelRecipientCodeHint =>
      'Share this code with the recipient. The driver needs it to complete the delivery.';

  @override
  String get parcelPickupCta => 'Picked up (take photo)';

  @override
  String get parcelReturningHint => 'Bring the package back to the sender';

  @override
  String get parcelReturnedCta => 'Returned to sender (photo)';

  @override
  String get parcelRecipientCodeInput => 'Recipient code';

  @override
  String get parcelDeliverCta => 'Delivered (photo)';

  @override
  String get parcelFailCta => 'Can\'t deliver';

  @override
  String parcelServiceFeeLine(String amount) {
    return 'Service fee $amount (included in fare)';
  }

  @override
  String parcelReturnFeeLine(String amount) {
    return 'Return fee if delivery fails: $amount';
  }

  @override
  String parcelReturnFeeCharged(String amount) {
    return 'Return fee $amount';
  }

  @override
  String get parcelReceiptServiceFee => 'Parcel service fee (included)';

  @override
  String get parcelReceiptReturnFee => 'Return fee';

  @override
  String get driverServicesFoodMotorbikeOnly =>
      'Food orders are for motorbike drivers only.';

  @override
  String get partnerKindFoodSafetyCommitment => 'Food safety commitment';

  @override
  String get partnerFoodSafetyUseCommitment => 'Use the food safety commitment';

  @override
  String get partnerFoodSafetyUseCommitmentHint =>
      'Small household shops may sign the food safety commitment instead of the certificate.';

  @override
  String get kycOcrPrefilledNote =>
      'Some fields were filled from your document photos. Please check and correct them.';

  @override
  String get kycOcrReading => 'Reading your document…';

  @override
  String get parcelPickContact => 'Pick from contacts';

  @override
  String get parcelEditRoute => 'Edit route';

  @override
  String get parcelEdit => 'Edit';

  @override
  String get parcelMoreDetails => 'Weight, note, photo (optional)';

  @override
  String get parcelPricing => 'Getting price…';

  @override
  String get parcelSectionPackage => 'Package';

  @override
  String get parcelSectionPayment => 'Payment';

  @override
  String get parcelFareLabel => 'Fare';

  @override
  String get parcelPhoneHint => '0901 234 567';

  @override
  String get parcelSenderYou => 'You';

  @override
  String get parcelPayerRecipientNote =>
      'The recipient pays the driver in cash on delivery.';

  @override
  String parcelSubmitWithPrice(String price) {
    return 'Book · $price';
  }

  @override
  String get apiErrCrossRegion =>
      'DealGo does not support trips between service regions yet. Please choose a destination in the same city as your pickup.';

  @override
  String get apiErrDriverAtCapacity =>
      'You are on an active trip. Finish it before taking a new request.';

  @override
  String get apiErrDriverTooFar =>
      'You are too far from the pickup. Move closer and try again.';

  @override
  String get apiErrOfferDriverUnavailable =>
      'This driver just took another trip. Please choose another driver.';

  @override
  String get apiErrItemNotApproved =>
      'This item is still awaiting approval and cannot be put on sale yet.';

  @override
  String get rideIntercity => 'Intercity';

  @override
  String rideIntercityQuote(String km, String minutes) {
    return 'Intercity trip · $km km · ≈$minutes min';
  }

  @override
  String get rideIntercityNote =>
      'The destination is in another province/region. Drivers bid as usual.';

  @override
  String driverPickupAwayKm(String km) {
    return '$km km away';
  }

  @override
  String get driverServiceSettings => 'Service settings';

  @override
  String get rideGoHome => 'Back to home';

  @override
  String get apiErrIntercityStops =>
      'Intercity trips go straight to one destination without extra stops.';

  @override
  String get apiErrIntercityTooFar =>
      'This intercity trip is longer than DealGo currently supports.';

  @override
  String get apiErrIntercityVehicle =>
      'This vehicle class does not run intercity. Please choose another vehicle.';

  @override
  String get apiErrIntercityNoVehicle =>
      'No vehicle class runs intercity trips yet.';

  @override
  String driverJobTripKm(String km) {
    return 'Trip $km km';
  }

  @override
  String driverJobPickupKm(String km) {
    return '$km km to pickup';
  }

  @override
  String get appUpdateRequiredTitle => 'Update required';

  @override
  String get appUpdateRequiredBody =>
      'This version of the app is no longer supported. Please update to keep using DealGo.';

  @override
  String get appUpdateNow => 'Update now';

  @override
  String appUpdateLatest(String version) {
    return 'New version: $version';
  }

  @override
  String get appUpdateOptionalTitle => 'A new version is available';

  @override
  String get appUpdateOptionalBody =>
      'Update to get the latest features and fixes.';

  @override
  String get appUpdateLater => 'Later';

  @override
  String get appUpdateRetry => 'Check again';

  @override
  String get legalConsentTitle => 'Our terms have been updated';

  @override
  String get legalConsentBody =>
      'Please review and accept the new terms to keep using DealGo.';

  @override
  String get legalConsentRead => 'Read the full text';

  @override
  String legalConsentEffective(String date) {
    return 'Effective $date';
  }

  @override
  String legalConsentVersion(String version) {
    return 'version $version';
  }

  @override
  String get legalConsentAgree => 'I agree';

  @override
  String get legalConsentFailed => 'Couldn\'t send. Please try again.';

  @override
  String contactPhoneDial(String phone) {
    return 'Call $phone';
  }

  @override
  String get contactPhoneDialFailed => 'Couldn\'t open the phone app.';

  @override
  String get kycReviewAvatar => 'Profile photo';

  @override
  String get kycAvatarMissing =>
      'Required before you submit. Customers see this photo when you take their job.';

  @override
  String get kycAvatarReady =>
      'Customers see this photo when you take their job.';

  @override
  String get kycAvatarAdd => 'Add photo';

  @override
  String get partnerErrorAvatar =>
      'Add a profile photo to your profile before submitting your driver application.';

  @override
  String offlineJobUpdatedAt(String time) {
    return 'Last updated $time · no connection';
  }

  @override
  String get offlineJobCallHint =>
      'Regular phone calls work without mobile data.';

  @override
  String get legalRegulationsTitle => 'Terms of use for partners';

  @override
  String get legalRegulationsBody => 'For partner drivers and shops';

  @override
  String get legalTermsTitle => 'Terms of Service';

  @override
  String get legalTermsBody => 'Your rights and obligations when using DealGo';

  @override
  String get legalPrivacyTitle => 'Privacy policy';

  @override
  String get legalPrivacyBody => 'How DealGo collects and protects your data';

  @override
  String get legalLoadError =>
      'Could not load this document. Please try again.';

  @override
  String get partnerConsentTitle => 'Partner registration terms';

  @override
  String get partnerConsentRegulations =>
      'I have read and agree to the Terms of use';

  @override
  String get partnerConsentPrivacy =>
      'I have read and agree to the Privacy policy';

  @override
  String get partnerConsentView => 'View';

  @override
  String get partnerConsentHint =>
      'You must accept both to submit your application.';

  @override
  String get partnerConsentLoadError =>
      'Could not load the terms — tap to retry';

  @override
  String get partnerErrorLegalConsent =>
      'The Terms of use or Privacy policy was just updated. Please review and accept again.';

  @override
  String get foodFareSuggested => 'Suggested delivery fee';

  @override
  String get foodFareYourOffer => 'Your offer';

  @override
  String get foodFareFixedWaiting =>
      'Drivers can only accept the fee you offered. If it\'s taking a while, raise the fee to make the order more attractive.';

  @override
  String get driverFareFixed =>
      'This order uses a fixed fee: you can only accept the customer\'s price.';

  @override
  String get foodFareDecrease => 'Lower the fee';

  @override
  String get foodFareIncrease => 'Raise the fee';

  @override
  String get foodFareReset => 'Use the suggestion';

  @override
  String get foodFareNegotiationTitle => 'Delivery fee';

  @override
  String foodFareWaiting(String amount) {
    return 'Waiting for a driver to accept $amount';
  }

  @override
  String foodFareAgreed(String amount) {
    return 'Agreed delivery fee: $amount';
  }

  @override
  String get foodFareOffersEmpty => 'No driver has proposed another fee yet.';

  @override
  String get foodFareDriverOffer => 'Driver offer';

  @override
  String get foodFareSelect => 'Choose';

  @override
  String foodFareRaise(String amount) {
    return 'Raise to $amount';
  }

  @override
  String foodFareRaisesLeft(int count) {
    return '$count raises left';
  }

  @override
  String get foodFareOfferExpired => 'Expired';

  @override
  String get foodFareSelectFailed =>
      'Could not choose this offer. It may have expired or the driver took another job.';

  @override
  String get foodFareRaiseFailed => 'Could not raise the fee. Try again later.';

  @override
  String get foodFareCodExtra =>
      'If the agreed fee is higher than what you paid online, the difference is collected in cash on delivery.';

  @override
  String get driverFareCounter => 'Propose fee';

  @override
  String get driverFareCounterTitle => 'Propose a delivery fee';

  @override
  String driverFareCustomerOffer(String amount) {
    return 'Customer offers $amount';
  }

  @override
  String driverFareCounterSend(String amount) {
    return 'Send $amount';
  }

  @override
  String get driverFareCounterSent => 'Offer sent. Waiting for the customer.';

  @override
  String get driverFareCounterFailed => 'Could not send the offer.';

  @override
  String get merchantFareAgreed => 'Delivery fee (agreed)';

  @override
  String get driverCreditTitle => 'Prepaid balance';

  @override
  String get driverCreditSubtitle =>
      'Covers platform fees only. It cannot be withdrawn or transferred.';

  @override
  String get driverCreditBalance => 'Prepaid credit';

  @override
  String get driverCreditOwes => 'Fee debt';

  @override
  String get driverCreditBlocked =>
      'Fee debt is over the limit. You will not receive new jobs until you top up.';

  @override
  String get driverCreditNearLimit =>
      'Fee debt is close to the limit. Top up to keep receiving jobs.';

  @override
  String get driverCreditDisabled =>
      'Top-up is not open yet. Please try again later.';

  @override
  String get driverCreditAmount => 'Top-up amount';

  @override
  String driverCreditAmountRange(String min, String max) {
    return 'From $min to $max';
  }

  @override
  String get driverCreditTopUp => 'Top up';

  @override
  String get driverCreditPending => 'Waiting for payment';

  @override
  String driverCreditRemaining(String amount) {
    return '$amount left';
  }

  @override
  String get driverCreditOpenCheckout => 'Open the payment page';

  @override
  String get driverCreditCancelTopUp => 'Cancel this top-up';

  @override
  String get driverCreditChecking => 'Checking payment…';

  @override
  String get driverCreditPaidHint =>
      'Paid. The amount is now in your prepaid balance.';

  @override
  String get driverCreditRecent => 'Recent top-ups';

  @override
  String get driverCreditEmpty => 'No top-ups yet.';

  @override
  String get driverCreditLoading => 'Loading balance…';

  @override
  String get driverCreditCardTitle => 'Top up fees';

  @override
  String get driverCreditCardBody =>
      'Keep your fee debt at zero so you keep receiving jobs.';

  @override
  String get driverCreditStatusPending => 'Pending';

  @override
  String get driverCreditStatusPaid => 'Credited';

  @override
  String get driverCreditStatusExpired => 'Expired';

  @override
  String get driverCreditStatusCancelled => 'Cancelled';

  @override
  String get driverCreditStatusRefundPending => 'Refund pending';

  @override
  String get driverCreditStatusRefunded => 'Refunded';

  @override
  String get driverCreditStatusFailed => 'Failed';

  @override
  String get driverCreditErrorGeneric => 'Could not top up. Please try again.';

  @override
  String get driverCreditErrorPending =>
      'You already have a top-up waiting for payment.';

  @override
  String get driverCreditErrorDailyLimit =>
      'Today\'s top-up limit has been reached.';

  @override
  String get driverCreditErrorCreditLimit =>
      'Prepaid balance limit has been reached.';

  @override
  String get driverCreditErrorAmount =>
      'The amount is outside the allowed range.';

  @override
  String get driverCreditErrorKyc =>
      'An approved KYC is required before topping up.';

  @override
  String get driverCreditErrorDisabled => 'Top-up is not open yet.';

  @override
  String get driverCreditErrorProvider =>
      'The payment provider is not available right now.';

  @override
  String get driverCreditScanHint =>
      'Open your banking app and scan this QR code. The amount is filled in for you.';

  @override
  String get driverCreditOrderCode => 'Order code';

  @override
  String driverCreditExpiresIn(String time) {
    return 'Expires in $time';
  }

  @override
  String get driverCreditDetailTitle => 'Top-up detail';

  @override
  String get driverCreditCopyCode => 'Copy order code';

  @override
  String get driverCreditCopied => 'Order code copied.';

  @override
  String get driverCreditPaymentReceived => 'Payment received';

  @override
  String driverCreditPaymentReceivedBody(String amount) {
    return '$amount has been added to your prepaid balance.';
  }

  @override
  String get driverCreditLinkExpired => 'This payment link is no longer valid.';

  @override
  String get driverCreditCreateNew => 'Create a new top-up';

  @override
  String get driverCreditAppliedFees => 'Applied to fees';

  @override
  String get driverCreditRefundedAmount => 'Refunded';

  @override
  String get driverCreditMethod => 'Payment method';

  @override
  String get driverCreditCreatedAt => 'Created';

  @override
  String get driverCreditPaidAt => 'Paid at';

  @override
  String get driverCreditClose => 'Close';

  @override
  String get driverCreditWaitingBank =>
      'The balance updates automatically once your bank confirms.';

  @override
  String get foodVoucherWallTitle => 'Today\'s offers';

  @override
  String get foodVoucherWallSeeAll => 'See all';

  @override
  String get foodReorderTitle => 'Order again';

  @override
  String foodReorderStripItems(int count, String total) {
    return '$count items · $total';
  }
}

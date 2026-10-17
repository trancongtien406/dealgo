import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('vi'),
    Locale('en'),
  ];

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @actionSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get actionSeeAll;

  /// No description provided for @actionExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore now'**
  String get actionExplore;

  /// No description provided for @actionBookRideNow.
  ///
  /// In en, this message translates to:
  /// **'Book a ride'**
  String get actionBookRideNow;

  /// No description provided for @actionVerifyContinue.
  ///
  /// In en, this message translates to:
  /// **'Verify and continue'**
  String get actionVerifyContinue;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get actionSend;

  /// No description provided for @actionChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get actionChange;

  /// No description provided for @actionResend.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get actionResend;

  /// No description provided for @actionResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get actionResendCode;

  /// No description provided for @actionChangePhone.
  ///
  /// In en, this message translates to:
  /// **'Change phone number'**
  String get actionChangePhone;

  /// No description provided for @actionKeepEnteringCode.
  ///
  /// In en, this message translates to:
  /// **'Keep entering code'**
  String get actionKeepEnteringCode;

  /// No description provided for @actionHuntDeals.
  ///
  /// In en, this message translates to:
  /// **'Hunt deals'**
  String get actionHuntDeals;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Unable to reach the server'**
  String get errorNetwork;

  /// No description provided for @errorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session is no longer valid'**
  String get errorSessionExpired;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorGeneric;

  /// No description provided for @errorLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load data'**
  String get errorLoadFailed;

  /// No description provided for @errorOffline.
  ///
  /// In en, this message translates to:
  /// **'You appear to be offline. Check the connection and try again.'**
  String get errorOffline;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again'**
  String get errorUnauthorized;

  /// No description provided for @emptyGeneric.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyGeneric;

  /// No description provided for @emptyStoresNearby.
  ///
  /// In en, this message translates to:
  /// **'No stores nearby yet'**
  String get emptyStoresNearby;

  /// No description provided for @emptyActivity.
  ///
  /// In en, this message translates to:
  /// **'No activity in this filter yet'**
  String get emptyActivity;

  /// No description provided for @emptyNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications in this group'**
  String get emptyNotifications;

  /// No description provided for @emptyOffers.
  ///
  /// In en, this message translates to:
  /// **'No driver offers yet'**
  String get emptyOffers;

  /// No description provided for @emptyOrders.
  ///
  /// In en, this message translates to:
  /// **'No orders in the queue'**
  String get emptyOrders;

  /// No description provided for @statusOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get statusOnline;

  /// No description provided for @statusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get statusOffline;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get statusProcessing;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusSearching.
  ///
  /// In en, this message translates to:
  /// **'Finding a driver'**
  String get statusSearching;

  /// No description provided for @statusAssigned.
  ///
  /// In en, this message translates to:
  /// **'Driver assigned'**
  String get statusAssigned;

  /// No description provided for @statusOnTrip.
  ///
  /// In en, this message translates to:
  /// **'On trip'**
  String get statusOnTrip;

  /// No description provided for @statusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get statusPreparing;

  /// No description provided for @statusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready for pickup'**
  String get statusReady;

  /// No description provided for @statusDelivering.
  ///
  /// In en, this message translates to:
  /// **'Out for delivery'**
  String get statusDelivering;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabTrips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get tabTrips;

  /// No description provided for @tabBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get tabBook;

  /// No description provided for @tabShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get tabShop;

  /// No description provided for @tabAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get tabAccount;

  /// No description provided for @tabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get tabOverview;

  /// No description provided for @tabOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get tabOrders;

  /// No description provided for @tabProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get tabProducts;

  /// No description provided for @tabStats.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get tabStats;

  /// No description provided for @tabJobs.
  ///
  /// In en, this message translates to:
  /// **'Jobs'**
  String get tabJobs;

  /// No description provided for @tabEarnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get tabEarnings;

  /// No description provided for @tabNotifications.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get tabNotifications;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterRides.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get filterRides;

  /// No description provided for @filterFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get filterFood;

  /// No description provided for @filterShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get filterShopping;

  /// No description provided for @filterOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get filterOrders;

  /// No description provided for @filterSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get filterSystem;

  /// No description provided for @filterNearby.
  ///
  /// In en, this message translates to:
  /// **'Near me'**
  String get filterNearby;

  /// No description provided for @filterSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get filterSaved;

  /// No description provided for @filterJobs.
  ///
  /// In en, this message translates to:
  /// **'Jobs'**
  String get filterJobs;

  /// No description provided for @filterEarnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get filterEarnings;

  /// No description provided for @authWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to DealGo!'**
  String get authWelcomeTitle;

  /// No description provided for @authWelcomePrefix.
  ///
  /// In en, this message translates to:
  /// **'Welcome to\n'**
  String get authWelcomePrefix;

  /// No description provided for @authWelcomeBrand.
  ///
  /// In en, this message translates to:
  /// **'DealGo'**
  String get authWelcomeBrand;

  /// No description provided for @authWelcomeSuffix.
  ///
  /// In en, this message translates to:
  /// **'!'**
  String get authWelcomeSuffix;

  /// No description provided for @authWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number to sign in or create an account. One account works across roles.'**
  String get authWelcomeBody;

  /// No description provided for @authPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get authPhoneLabel;

  /// No description provided for @authPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Enter phone number'**
  String get authPhoneHint;

  /// No description provided for @authOtpInfo.
  ///
  /// In en, this message translates to:
  /// **'An OTP will be sent to verify and protect your account.'**
  String get authOtpInfo;

  /// No description provided for @authTermsPrefix.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to DealGo’s '**
  String get authTermsPrefix;

  /// No description provided for @authTermsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get authTermsOfUse;

  /// No description provided for @authTermsAnd.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get authTermsAnd;

  /// No description provided for @authPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get authPrivacyPolicy;

  /// No description provided for @authTermsSuffix.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get authTermsSuffix;

  /// No description provided for @authMockDemo.
  ///
  /// In en, this message translates to:
  /// **'Enter demo (mock)'**
  String get authMockDemo;

  /// No description provided for @otpTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify OTP'**
  String get otpTitle;

  /// No description provided for @otpHeading.
  ///
  /// In en, this message translates to:
  /// **'Verify phone number'**
  String get otpHeading;

  /// No description provided for @otpBodyPrefix.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit OTP sent to\n'**
  String get otpBodyPrefix;

  /// No description provided for @otpNotReceived.
  ///
  /// In en, this message translates to:
  /// **'Didn’t get a code?'**
  String get otpNotReceived;

  /// No description provided for @otpSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get otpSending;

  /// No description provided for @otpResendAfter.
  ///
  /// In en, this message translates to:
  /// **'Resend in {time}'**
  String otpResendAfter(String time);

  /// No description provided for @otpProtectTitle.
  ///
  /// In en, this message translates to:
  /// **'Protect your account'**
  String get otpProtectTitle;

  /// No description provided for @otpProtectBody.
  ///
  /// In en, this message translates to:
  /// **'OTP codes expire. Never share this code with anyone.'**
  String get otpProtectBody;

  /// No description provided for @otpInvalidTitle.
  ///
  /// In en, this message translates to:
  /// **'Incorrect verification code'**
  String get otpInvalidTitle;

  /// No description provided for @otpExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification code expired'**
  String get otpExpiredTitle;

  /// No description provided for @otpLockedBody.
  ///
  /// In en, this message translates to:
  /// **'Too many incorrect attempts. Request a new code later.'**
  String get otpLockedBody;

  /// No description provided for @otpInvalidBody.
  ///
  /// In en, this message translates to:
  /// **'The 6-digit code does not match or was already used. Check and try again.'**
  String get otpInvalidBody;

  /// No description provided for @otpInvalidShort.
  ///
  /// In en, this message translates to:
  /// **'Invalid OTP.'**
  String get otpInvalidShort;

  /// No description provided for @otpCannotResendTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot send a new code yet'**
  String get otpCannotResendTitle;

  /// No description provided for @otpCannotResendBody.
  ///
  /// In en, this message translates to:
  /// **'Wait until the cooldown ends before requesting another OTP.'**
  String get otpCannotResendBody;

  /// No description provided for @otpResendLabel.
  ///
  /// In en, this message translates to:
  /// **'Send new code'**
  String get otpResendLabel;

  /// No description provided for @otpResendCooldown.
  ///
  /// In en, this message translates to:
  /// **'Resend after'**
  String get otpResendCooldown;

  /// No description provided for @otpServerGateHint.
  ///
  /// In en, this message translates to:
  /// **'“Send new code” stays disabled until the server allows another send.'**
  String get otpServerGateHint;

  /// No description provided for @otpPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'We do not reveal whether an account exists. Attempt limits are enforced by the server.'**
  String get otpPrivacyNote;

  /// No description provided for @otpFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get otpFieldLabel;

  /// No description provided for @roleHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Role hub'**
  String get roleHubTitle;

  /// No description provided for @roleHubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One account · Three operating modes'**
  String get roleHubSubtitle;

  /// No description provided for @roleContinueCustomer.
  ///
  /// In en, this message translates to:
  /// **'Continue as Customer'**
  String get roleContinueCustomer;

  /// No description provided for @roleContinueMerchant.
  ///
  /// In en, this message translates to:
  /// **'Continue as Shop'**
  String get roleContinueMerchant;

  /// No description provided for @roleContinueDriver.
  ///
  /// In en, this message translates to:
  /// **'Continue as Driver'**
  String get roleContinueDriver;

  /// No description provided for @roleCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer mode'**
  String get roleCustomerTitle;

  /// No description provided for @roleCustomerHeadline.
  ///
  /// In en, this message translates to:
  /// **'Book rides, food, and shopping'**
  String get roleCustomerHeadline;

  /// No description provided for @roleCustomerDetail.
  ///
  /// In en, this message translates to:
  /// **'Use DealGo services'**
  String get roleCustomerDetail;

  /// No description provided for @roleMerchantTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop mode'**
  String get roleMerchantTitle;

  /// No description provided for @roleMerchantHeadline.
  ///
  /// In en, this message translates to:
  /// **'Manage your store'**
  String get roleMerchantHeadline;

  /// No description provided for @roleMerchantDetail.
  ///
  /// In en, this message translates to:
  /// **'New orders · Menu · Revenue'**
  String get roleMerchantDetail;

  /// No description provided for @roleDriverTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver mode'**
  String get roleDriverTitle;

  /// No description provided for @roleDriverHeadline.
  ///
  /// In en, this message translates to:
  /// **'Accept jobs and earn'**
  String get roleDriverHeadline;

  /// No description provided for @roleDriverDetail.
  ///
  /// In en, this message translates to:
  /// **'Rides · Food delivery · Earnings'**
  String get roleDriverDetail;

  /// No description provided for @roleOnboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish partner onboarding'**
  String get roleOnboardingTitle;

  /// No description provided for @rideTrackContact.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get rideTrackContact;

  /// No description provided for @rideTrackRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get rideTrackRetry;

  /// No description provided for @ridePickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get ridePickup;

  /// No description provided for @rideDropoff.
  ///
  /// In en, this message translates to:
  /// **'Drop-off'**
  String get rideDropoff;

  /// No description provided for @foodCheckoutContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue to payment'**
  String get foodCheckoutContinue;

  /// No description provided for @homeTagline.
  ///
  /// In en, this message translates to:
  /// **'Go anywhere · Buy everything'**
  String get homeTagline;

  /// No description provided for @homeCitySample.
  ///
  /// In en, this message translates to:
  /// **'Da Nang'**
  String get homeCitySample;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get chatTitle;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get chatEmpty;

  /// No description provided for @chatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message'**
  String get chatInputHint;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatContact.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get chatContact;

  /// No description provided for @voiceCall.
  ///
  /// In en, this message translates to:
  /// **'Voice call'**
  String get voiceCall;

  /// No description provided for @voiceTitle.
  ///
  /// In en, this message translates to:
  /// **'In-trip voice call'**
  String get voiceTitle;

  /// No description provided for @voiceRoomLabel.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get voiceRoomLabel;

  /// No description provided for @voiceStubHint.
  ///
  /// In en, this message translates to:
  /// **'LiveKit joins when the server issues a token. Showing the room name for now.'**
  String get voiceStubHint;

  /// No description provided for @bannerOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'You’re offline'**
  String get bannerOfflineTitle;

  /// No description provided for @bannerEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here'**
  String get bannerEmptyTitle;

  /// No description provided for @commonSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get commonSelected;

  /// No description provided for @commonNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get commonNew;

  /// No description provided for @commonCodUnpaid.
  ///
  /// In en, this message translates to:
  /// **'COD · Not collected'**
  String get commonCodUnpaid;

  /// No description provided for @actionSeeDetail.
  ///
  /// In en, this message translates to:
  /// **'View details →'**
  String get actionSeeDetail;

  /// No description provided for @rideOfferDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Offer & driver details'**
  String get rideOfferDetailTitle;

  /// No description provided for @rideDriverLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get rideDriverLabel;

  /// No description provided for @rideOfferAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver offer'**
  String get rideOfferAmountLabel;

  /// No description provided for @rideYourBidLabel.
  ///
  /// In en, this message translates to:
  /// **'Your bid'**
  String get rideYourBidLabel;

  /// No description provided for @rideTripInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get rideTripInfoTitle;

  /// No description provided for @rideOfferDetailHint.
  ///
  /// In en, this message translates to:
  /// **'Confirming this offer creates the trip. Unselected offers may expire.'**
  String get rideOfferDetailHint;

  /// No description provided for @rideSelectOfferCta.
  ///
  /// In en, this message translates to:
  /// **'Continue with this offer'**
  String get rideSelectOfferCta;

  /// No description provided for @ridePickupCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Pickup verification code'**
  String get ridePickupCodeTitle;

  /// No description provided for @ridePickupCodeChip.
  ///
  /// In en, this message translates to:
  /// **'Show to driver'**
  String get ridePickupCodeChip;

  /// No description provided for @ridePickupCodeHeadline.
  ///
  /// In en, this message translates to:
  /// **'Your pickup code'**
  String get ridePickupCodeHeadline;

  /// No description provided for @ridePickupCodeBody.
  ///
  /// In en, this message translates to:
  /// **'Share this code only when the vehicle and plate match.'**
  String get ridePickupCodeBody;

  /// No description provided for @ridePickupCodeSafetyTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep the code private'**
  String get ridePickupCodeSafetyTitle;

  /// No description provided for @ridePickupCodeSafetyBody.
  ///
  /// In en, this message translates to:
  /// **'Do not send the code in chat before the driver arrives.'**
  String get ridePickupCodeSafetyBody;

  /// No description provided for @rideSafetyTitle.
  ///
  /// In en, this message translates to:
  /// **'Safety center'**
  String get rideSafetyTitle;

  /// No description provided for @rideSafetyBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Stay safe on this trip'**
  String get rideSafetyBannerTitle;

  /// No description provided for @rideSafetyBannerBody.
  ///
  /// In en, this message translates to:
  /// **'Share your trip and keep emergency contacts handy. Emergency calling uses your phone — DealGo does not fake an SOS backend.'**
  String get rideSafetyBannerBody;

  /// No description provided for @rideSafetyShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share trip'**
  String get rideSafetyShareTitle;

  /// No description provided for @rideSafetyShareBody.
  ///
  /// In en, this message translates to:
  /// **'Copy a trip link to send to someone you trust.'**
  String get rideSafetyShareBody;

  /// No description provided for @rideSafetyShareCta.
  ///
  /// In en, this message translates to:
  /// **'Copy trip link'**
  String get rideSafetyShareCta;

  /// No description provided for @rideSafetyShareCopied.
  ///
  /// In en, this message translates to:
  /// **'Trip link copied'**
  String get rideSafetyShareCopied;

  /// No description provided for @rideSafetyContactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency contacts'**
  String get rideSafetyContactsTitle;

  /// No description provided for @rideSafetyContactsBody.
  ///
  /// In en, this message translates to:
  /// **'Contacts below are stored on this device for demo only.'**
  String get rideSafetyContactsBody;

  /// No description provided for @rideSafetyContactLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get rideSafetyContactLocal;

  /// No description provided for @rideSafetyAddContact.
  ///
  /// In en, this message translates to:
  /// **'Add contact (mock)'**
  String get rideSafetyAddContact;

  /// No description provided for @rideSafetyContactsMockHint.
  ///
  /// In en, this message translates to:
  /// **'Contact editing is local mock — not synced to the server.'**
  String get rideSafetyContactsMockHint;

  /// No description provided for @rideSafetyEmergencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency help'**
  String get rideSafetyEmergencyTitle;

  /// No description provided for @rideSafetyEmergencyBody.
  ///
  /// In en, this message translates to:
  /// **'Use your phone dialer for local emergency numbers. No in-app SOS is claimed here.'**
  String get rideSafetyEmergencyBody;

  /// No description provided for @rideCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel trip'**
  String get rideCancelTitle;

  /// No description provided for @rideCancelPickReason.
  ///
  /// In en, this message translates to:
  /// **'Why are you cancelling?'**
  String get rideCancelPickReason;

  /// No description provided for @rideCancelPolicyHint.
  ///
  /// In en, this message translates to:
  /// **'Cancellation fees or penalties are set by the server when available — this screen does not invent them.'**
  String get rideCancelPolicyHint;

  /// No description provided for @rideCancelReasonWait.
  ///
  /// In en, this message translates to:
  /// **'Waiting too long'**
  String get rideCancelReasonWait;

  /// No description provided for @rideCancelReasonPlans.
  ///
  /// In en, this message translates to:
  /// **'Plans changed'**
  String get rideCancelReasonPlans;

  /// No description provided for @rideCancelReasonAddress.
  ///
  /// In en, this message translates to:
  /// **'Wrong pickup / drop-off'**
  String get rideCancelReasonAddress;

  /// No description provided for @rideCancelReasonDriver.
  ///
  /// In en, this message translates to:
  /// **'Issue with the driver'**
  String get rideCancelReasonDriver;

  /// No description provided for @rideCancelReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get rideCancelReasonOther;

  /// No description provided for @rideCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm cancel'**
  String get rideCancelConfirm;

  /// No description provided for @rideCancelKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep this trip'**
  String get rideCancelKeep;

  /// No description provided for @rideCancelSuccess.
  ///
  /// In en, this message translates to:
  /// **'Trip cancelled'**
  String get rideCancelSuccess;

  /// No description provided for @rideCancelSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Cancel requested'**
  String get rideCancelSubmitted;

  /// No description provided for @rideCancelSoftFail.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Your reason was kept locally — try again when online.'**
  String get rideCancelSoftFail;

  /// No description provided for @foodCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get foodCancelTitle;

  /// No description provided for @foodCancelPickReason.
  ///
  /// In en, this message translates to:
  /// **'Why are you cancelling?'**
  String get foodCancelPickReason;

  /// No description provided for @foodCancelPolicyHint.
  ///
  /// In en, this message translates to:
  /// **'Refund or fee outcomes come from the server. This picker does not invent policies.'**
  String get foodCancelPolicyHint;

  /// No description provided for @foodCancelReasonWrong.
  ///
  /// In en, this message translates to:
  /// **'Ordered the wrong items'**
  String get foodCancelReasonWrong;

  /// No description provided for @foodCancelReasonWait.
  ///
  /// In en, this message translates to:
  /// **'Waiting too long'**
  String get foodCancelReasonWait;

  /// No description provided for @foodCancelReasonAddress.
  ///
  /// In en, this message translates to:
  /// **'Need a different delivery address'**
  String get foodCancelReasonAddress;

  /// No description provided for @foodCancelReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get foodCancelReasonOther;

  /// No description provided for @foodCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm cancel'**
  String get foodCancelConfirm;

  /// No description provided for @foodCancelKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep this order'**
  String get foodCancelKeep;

  /// No description provided for @foodCancelSoftFail.
  ///
  /// In en, this message translates to:
  /// **'Cancel is shown locally for now — server cancel will soft-fail until the API is available.'**
  String get foodCancelSoftFail;

  /// No description provided for @driverJobFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery failed'**
  String get driverJobFailedTitle;

  /// No description provided for @driverJobFailedChip.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get driverJobFailedChip;

  /// No description provided for @driverJobFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Record why the delivery could not be completed. Settlement follows server rules — no client-side fees invented.'**
  String get driverJobFailedBody;

  /// No description provided for @driverJobFailedPick.
  ///
  /// In en, this message translates to:
  /// **'Outcome'**
  String get driverJobFailedPick;

  /// No description provided for @driverFailAbsent.
  ///
  /// In en, this message translates to:
  /// **'Customer absent'**
  String get driverFailAbsent;

  /// No description provided for @driverFailAddress.
  ///
  /// In en, this message translates to:
  /// **'Wrong address'**
  String get driverFailAddress;

  /// No description provided for @driverFailRefused.
  ///
  /// In en, this message translates to:
  /// **'Refused'**
  String get driverFailRefused;

  /// No description provided for @driverFailOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get driverFailOther;

  /// No description provided for @driverJobFailedSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit outcome'**
  String get driverJobFailedSubmit;

  /// No description provided for @driverJobFailedPolicyHint.
  ///
  /// In en, this message translates to:
  /// **'This is a UI shell. Nest soft-fails when no failure API is present.'**
  String get driverJobFailedPolicyHint;

  /// No description provided for @driverJobFailedSoftFail.
  ///
  /// In en, this message translates to:
  /// **'Outcome saved on device for demo. Server sync will soft-fail without an API.'**
  String get driverJobFailedSoftFail;

  /// No description provided for @driverOpenCompletedSample.
  ///
  /// In en, this message translates to:
  /// **'Open completed job sample'**
  String get driverOpenCompletedSample;

  /// No description provided for @driverJobIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Job'**
  String get driverJobIdLabel;

  /// No description provided for @driverJobCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Completed job'**
  String get driverJobCompletedTitle;

  /// No description provided for @driverBackToJobs.
  ///
  /// In en, this message translates to:
  /// **'Back to jobs'**
  String get driverBackToJobs;

  /// No description provided for @driverCompletedRouteSample.
  ///
  /// In en, this message translates to:
  /// **'Hai Chau → Airport (sample)'**
  String get driverCompletedRouteSample;

  /// No description provided for @driverCompletedTimeSample.
  ///
  /// In en, this message translates to:
  /// **'Completed · today (fixture)'**
  String get driverCompletedTimeSample;

  /// No description provided for @driverCompletedEarningsTitle.
  ///
  /// In en, this message translates to:
  /// **'Earnings snapshot'**
  String get driverCompletedEarningsTitle;

  /// No description provided for @driverCompletedFareLabel.
  ///
  /// In en, this message translates to:
  /// **'Accepted fare'**
  String get driverCompletedFareLabel;

  /// No description provided for @driverCompletedBonusLabel.
  ///
  /// In en, this message translates to:
  /// **'Bonus'**
  String get driverCompletedBonusLabel;

  /// No description provided for @driverCompletedEarningsHint.
  ///
  /// In en, this message translates to:
  /// **'Amounts are layout fixtures — not live ledger balances.'**
  String get driverCompletedEarningsHint;

  /// No description provided for @driverCompletedFixtureHint.
  ///
  /// In en, this message translates to:
  /// **'Completed detail uses mock data until history APIs are wired.'**
  String get driverCompletedFixtureHint;

  /// No description provided for @driverJobsHistorySection.
  ///
  /// In en, this message translates to:
  /// **'Job outcomes (demo)'**
  String get driverJobsHistorySection;

  /// No description provided for @driverServicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose services'**
  String get driverServicesTitle;

  /// No description provided for @driverServicesHeadline.
  ///
  /// In en, this message translates to:
  /// **'Choose services to receive work'**
  String get driverServicesHeadline;

  /// No description provided for @driverServicesBody.
  ///
  /// In en, this message translates to:
  /// **'You can enable each approved work type separately.'**
  String get driverServicesBody;

  /// No description provided for @driverServicesOnlineTitle.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get driverServicesOnlineTitle;

  /// No description provided for @driverServicesOnlineBody.
  ///
  /// In en, this message translates to:
  /// **'Ready to receive new requests'**
  String get driverServicesOnlineBody;

  /// No description provided for @driverServicesApprovedSection.
  ///
  /// In en, this message translates to:
  /// **'Approved services'**
  String get driverServicesApprovedSection;

  /// No description provided for @driverServicesRideTitle.
  ///
  /// In en, this message translates to:
  /// **'Passenger rides (motorbike)'**
  String get driverServicesRideTitle;

  /// No description provided for @driverServicesRideBody.
  ///
  /// In en, this message translates to:
  /// **'Nearby trips · Flexible pricing'**
  String get driverServicesRideBody;

  /// No description provided for @driverServicesFoodTitle.
  ///
  /// In en, this message translates to:
  /// **'Food delivery'**
  String get driverServicesFoodTitle;

  /// No description provided for @driverServicesFoodBody.
  ///
  /// In en, this message translates to:
  /// **'Pick up from Shop and deliver to customer'**
  String get driverServicesFoodBody;

  /// No description provided for @driverServicesApprovedChip.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get driverServicesApprovedChip;

  /// No description provided for @driverServicesVehicleSection.
  ///
  /// In en, this message translates to:
  /// **'Active vehicle'**
  String get driverServicesVehicleSection;

  /// No description provided for @driverServicesVehicleInUse.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get driverServicesVehicleInUse;

  /// No description provided for @driverServicesAreaSection.
  ///
  /// In en, this message translates to:
  /// **'Request area'**
  String get driverServicesAreaSection;

  /// No description provided for @driverServicesAreaEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get driverServicesAreaEdit;

  /// No description provided for @driverServicesAreaFromGps.
  ///
  /// In en, this message translates to:
  /// **'From the driver’s current location'**
  String get driverServicesAreaFromGps;

  /// No description provided for @driverServicesSave.
  ///
  /// In en, this message translates to:
  /// **'Save configuration'**
  String get driverServicesSave;

  /// No description provided for @driverServicesPolicyHint.
  ///
  /// In en, this message translates to:
  /// **'The system only sends jobs that match valid documents, driver status, and vehicle.'**
  String get driverServicesPolicyHint;

  /// No description provided for @driverServicesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} services'**
  String driverServicesCount(int count);

  /// No description provided for @driverOtpTitle.
  ///
  /// In en, this message translates to:
  /// **'Passenger pickup OTP'**
  String get driverOtpTitle;

  /// No description provided for @driverOtpHeadline.
  ///
  /// In en, this message translates to:
  /// **'Verify passenger boarding'**
  String get driverOtpHeadline;

  /// No description provided for @driverOtpBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the 4-digit code from the passenger to start the trip.'**
  String get driverOtpBody;

  /// No description provided for @driverOtpVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Passenger verification'**
  String get driverOtpVerifyTitle;

  /// No description provided for @driverOtpValidFor.
  ///
  /// In en, this message translates to:
  /// **'OTP is valid only for trip #{rideId}'**
  String driverOtpValidFor(String rideId);

  /// No description provided for @driverOtpWaitingHint.
  ///
  /// In en, this message translates to:
  /// **'Waiting to match code · Illustrative display'**
  String get driverOtpWaitingHint;

  /// No description provided for @driverOtpWrong.
  ///
  /// In en, this message translates to:
  /// **'OTP does not match. Check again with the passenger.'**
  String get driverOtpWrong;

  /// No description provided for @driverOtpGuide.
  ///
  /// In en, this message translates to:
  /// **'Only start the trip after verifying the passenger and confirmation code.'**
  String get driverOtpGuide;

  /// No description provided for @driverOtpPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Do not share the pickup OTP in chat or with unrelated people.'**
  String get driverOtpPrivacy;

  /// No description provided for @driverOtpConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm and start trip'**
  String get driverOtpConfirm;

  /// No description provided for @driverOtpWaitingChip.
  ///
  /// In en, this message translates to:
  /// **'WAITING'**
  String get driverOtpWaitingChip;

  /// No description provided for @driverActiveNavTitle.
  ///
  /// In en, this message translates to:
  /// **'Navigate to pickup'**
  String get driverActiveNavTitle;

  /// No description provided for @driverActiveArrivedTitle.
  ///
  /// In en, this message translates to:
  /// **'Arrived at pickup'**
  String get driverActiveArrivedTitle;

  /// No description provided for @driverActiveOnTripTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip in progress'**
  String get driverActiveOnTripTitle;

  /// No description provided for @driverActiveCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'End trip'**
  String get driverActiveCompleteTitle;

  /// No description provided for @driverActiveArrivedCta.
  ///
  /// In en, this message translates to:
  /// **'Arrived at pickup'**
  String get driverActiveArrivedCta;

  /// No description provided for @driverActiveOpenOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter passenger OTP'**
  String get driverActiveOpenOtp;

  /// No description provided for @driverActiveWaitingBody.
  ///
  /// In en, this message translates to:
  /// **'Wait for the passenger. Verify OTP before starting the trip.'**
  String get driverActiveWaitingBody;

  /// No description provided for @driverActiveOnTripBody.
  ///
  /// In en, this message translates to:
  /// **'In-trip map (mock). Follow the route to the dropoff.'**
  String get driverActiveOnTripBody;

  /// No description provided for @driverActiveCompleteCta.
  ///
  /// In en, this message translates to:
  /// **'Complete / collect payment'**
  String get driverActiveCompleteCta;

  /// No description provided for @driverActiveCompleteBody.
  ///
  /// In en, this message translates to:
  /// **'Collect the server-locked fare. Do not invent surcharges on device.'**
  String get driverActiveCompleteBody;

  /// No description provided for @driverActiveReportIssue.
  ///
  /// In en, this message translates to:
  /// **'Report issue'**
  String get driverActiveReportIssue;

  /// No description provided for @driverFoodPhaseNavTitle.
  ///
  /// In en, this message translates to:
  /// **'Navigate to store'**
  String get driverFoodPhaseNavTitle;

  /// No description provided for @driverFoodPhaseWaitTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting at store'**
  String get driverFoodPhaseWaitTitle;

  /// No description provided for @driverFoodPhasePickupTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm pickup'**
  String get driverFoodPhasePickupTitle;

  /// No description provided for @driverFoodPhaseDeliverTitle.
  ///
  /// In en, this message translates to:
  /// **'Deliver to customer'**
  String get driverFoodPhaseDeliverTitle;

  /// No description provided for @driverFoodPhaseCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery confirmed'**
  String get driverFoodPhaseCompleteTitle;

  /// No description provided for @driverFoodArrivedStore.
  ///
  /// In en, this message translates to:
  /// **'Arrived at store'**
  String get driverFoodArrivedStore;

  /// No description provided for @driverFoodConfirmPickup.
  ///
  /// In en, this message translates to:
  /// **'Picked up order'**
  String get driverFoodConfirmPickup;

  /// No description provided for @driverFoodArrivedCustomer.
  ///
  /// In en, this message translates to:
  /// **'Arrived at dropoff'**
  String get driverFoodArrivedCustomer;

  /// No description provided for @driverFoodCompleteDelivery.
  ///
  /// In en, this message translates to:
  /// **'Complete delivery'**
  String get driverFoodCompleteDelivery;

  /// No description provided for @driverFoodWaitBody.
  ///
  /// In en, this message translates to:
  /// **'Wait until the Shop finishes. Do not mark pickup before bags are ready.'**
  String get driverFoodWaitBody;

  /// No description provided for @driverFoodPickupBody.
  ///
  /// In en, this message translates to:
  /// **'Match bag count and handoff code with the Shop before leaving.'**
  String get driverFoodPickupBody;

  /// No description provided for @driverFoodDeliverBody.
  ///
  /// In en, this message translates to:
  /// **'Delivery map (mock). Collect COD using the server order total.'**
  String get driverFoodDeliverBody;

  /// No description provided for @driverFoodCompleteBody.
  ///
  /// In en, this message translates to:
  /// **'Collecting COD is not driver income. Settlement follows the server.'**
  String get driverFoodCompleteBody;

  /// No description provided for @driverFoodIncomePending.
  ///
  /// In en, this message translates to:
  /// **'Per server settlement'**
  String get driverFoodIncomePending;

  /// No description provided for @driverFoodNoClientFee.
  ///
  /// In en, this message translates to:
  /// **'Do not compute income/commission on the client — show server amounts only when present.'**
  String get driverFoodNoClientFee;

  /// No description provided for @driverFoodCodCollect.
  ///
  /// In en, this message translates to:
  /// **'COD to collect on delivery'**
  String get driverFoodCodCollect;

  /// No description provided for @merchantRejectOrder.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get merchantRejectOrder;

  /// No description provided for @merchantAcceptOrder.
  ///
  /// In en, this message translates to:
  /// **'Confirm order'**
  String get merchantAcceptOrder;

  /// No description provided for @merchantRejectConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject this order?'**
  String get merchantRejectConfirmTitle;

  /// No description provided for @merchantRejectConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Device-only reject (mock). Nest reject API is not wired — no server mutation.'**
  String get merchantRejectConfirmBody;

  /// No description provided for @merchantRejectConfirmCta.
  ///
  /// In en, this message translates to:
  /// **'Confirm reject'**
  String get merchantRejectConfirmCta;

  /// No description provided for @merchantRejectKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep order'**
  String get merchantRejectKeep;

  /// No description provided for @merchantRejectDone.
  ///
  /// In en, this message translates to:
  /// **'Reject recorded on device (demo).'**
  String get merchantRejectDone;

  /// No description provided for @merchantHomeFinanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Today’s finances'**
  String get merchantHomeFinanceTitle;

  /// No description provided for @merchantHomeGrossFood.
  ///
  /// In en, this message translates to:
  /// **'Food revenue (gross)'**
  String get merchantHomeGrossFood;

  /// No description provided for @merchantHomePendingSettle.
  ///
  /// In en, this message translates to:
  /// **'Pending settlement'**
  String get merchantHomePendingSettle;

  /// No description provided for @merchantHomeAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available balance'**
  String get merchantHomeAvailable;

  /// No description provided for @merchantHomeFinanceHint.
  ///
  /// In en, this message translates to:
  /// **'Revenue is not withdrawable balance; COD and refunds settle separately. Figures are queue layout — not a withdraw ledger.'**
  String get merchantHomeFinanceHint;

  /// No description provided for @merchantHomeCompletedToday.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get merchantHomeCompletedToday;

  /// No description provided for @merchantHomeFoodToday.
  ///
  /// In en, this message translates to:
  /// **'Food total on queue'**
  String get merchantHomeFoodToday;

  /// No description provided for @merchantOrderItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get merchantOrderItemsTitle;

  /// No description provided for @merchantOrderValueTitle.
  ///
  /// In en, this message translates to:
  /// **'Order value'**
  String get merchantOrderValueTitle;

  /// No description provided for @merchantOrderCodTotal.
  ///
  /// In en, this message translates to:
  /// **'COD total'**
  String get merchantOrderCodTotal;

  /// No description provided for @merchantOrderFoodRevenue.
  ///
  /// In en, this message translates to:
  /// **'Food revenue'**
  String get merchantOrderFoodRevenue;

  /// No description provided for @merchantOrderDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get merchantOrderDiscount;

  /// No description provided for @merchantOrderCodNote.
  ///
  /// In en, this message translates to:
  /// **'Shop does not keep the full COD: delivery fee belongs to driver/platform; COD is not collected at accept.'**
  String get merchantOrderCodNote;

  /// No description provided for @merchantSettingsShellTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop settings'**
  String get merchantSettingsShellTitle;

  /// No description provided for @kybIntroBrand.
  ///
  /// In en, this message translates to:
  /// **'DealGo'**
  String get kybIntroBrand;

  /// No description provided for @kybIntroPartnerMode.
  ///
  /// In en, this message translates to:
  /// **'Partner mode'**
  String get kybIntroPartnerMode;

  /// No description provided for @kycIntroBrand.
  ///
  /// In en, this message translates to:
  /// **'DealGo'**
  String get kycIntroBrand;

  /// No description provided for @kycIntroPartnerMode.
  ///
  /// In en, this message translates to:
  /// **'Partner mode'**
  String get kycIntroPartnerMode;

  /// No description provided for @merchantSettingsSection.
  ///
  /// In en, this message translates to:
  /// **'Shop settings'**
  String get merchantSettingsSection;

  /// No description provided for @merchantSettingsMockHint.
  ///
  /// In en, this message translates to:
  /// **'Settings on this screen are local mock toggles until Nest shop-config APIs exist.'**
  String get merchantSettingsMockHint;

  /// No description provided for @merchantAcceptTitle.
  ///
  /// In en, this message translates to:
  /// **'Order accept mode'**
  String get merchantAcceptTitle;

  /// No description provided for @merchantAcceptModeLabel.
  ///
  /// In en, this message translates to:
  /// **'How new orders are accepted'**
  String get merchantAcceptModeLabel;

  /// No description provided for @merchantAcceptManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get merchantAcceptManual;

  /// No description provided for @merchantAcceptAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get merchantAcceptAuto;

  /// No description provided for @merchantAcceptManualHint.
  ///
  /// In en, this message translates to:
  /// **'You confirm each new order in the queue.'**
  String get merchantAcceptManualHint;

  /// No description provided for @merchantAcceptAutoHint.
  ///
  /// In en, this message translates to:
  /// **'Eligible new orders can be accepted automatically on this device mock.'**
  String get merchantAcceptAutoHint;

  /// No description provided for @merchantHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'Hours & closed days'**
  String get merchantHoursTitle;

  /// No description provided for @merchantHoursOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get merchantHoursOpen;

  /// No description provided for @merchantHoursClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get merchantHoursClosed;

  /// No description provided for @merchantBusyTitle.
  ///
  /// In en, this message translates to:
  /// **'Busy / pause'**
  String get merchantBusyTitle;

  /// No description provided for @merchantBusyModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Store availability'**
  String get merchantBusyModeLabel;

  /// No description provided for @merchantBusyOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get merchantBusyOpen;

  /// No description provided for @merchantBusyBusy.
  ///
  /// In en, this message translates to:
  /// **'Busy'**
  String get merchantBusyBusy;

  /// No description provided for @merchantBusyPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get merchantBusyPaused;

  /// No description provided for @merchantBusyOpenHint.
  ///
  /// In en, this message translates to:
  /// **'Customers can place orders normally (mock).'**
  String get merchantBusyOpenHint;

  /// No description provided for @merchantBusyBusyHint.
  ///
  /// In en, this message translates to:
  /// **'Show busy — new orders may be limited on this device mock.'**
  String get merchantBusyBusyHint;

  /// No description provided for @merchantBusyPausedHint.
  ///
  /// In en, this message translates to:
  /// **'Temporarily stop accepting orders on this device mock.'**
  String get merchantBusyPausedHint;

  /// No description provided for @merchantVariantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sizes & toppings'**
  String get merchantVariantsTitle;

  /// No description provided for @merchantVariantsCta.
  ///
  /// In en, this message translates to:
  /// **'Edit variants'**
  String get merchantVariantsCta;

  /// No description provided for @merchantVariantsItem.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get merchantVariantsItem;

  /// No description provided for @merchantVariantsShellChip.
  ///
  /// In en, this message translates to:
  /// **'Editor shell'**
  String get merchantVariantsShellChip;

  /// No description provided for @merchantVariantsSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get merchantVariantsSizeLabel;

  /// No description provided for @merchantVariantsToppingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Toppings'**
  String get merchantVariantsToppingsLabel;

  /// No description provided for @merchantVariantsSave.
  ///
  /// In en, this message translates to:
  /// **'Save locally'**
  String get merchantVariantsSave;

  /// No description provided for @merchantVariantsSavedLocal.
  ///
  /// In en, this message translates to:
  /// **'Variants saved on device (mock)'**
  String get merchantVariantsSavedLocal;

  /// No description provided for @merchantVariantsPriceHint.
  ///
  /// In en, this message translates to:
  /// **'Do not invent topping fees here — prices come from catalog/server when available.'**
  String get merchantVariantsPriceHint;

  /// No description provided for @merchantSizeS.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get merchantSizeS;

  /// No description provided for @merchantSizeM.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get merchantSizeM;

  /// No description provided for @merchantSizeL.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get merchantSizeL;

  /// No description provided for @merchantToppingEgg.
  ///
  /// In en, this message translates to:
  /// **'Egg'**
  String get merchantToppingEgg;

  /// No description provided for @merchantToppingCheese.
  ///
  /// In en, this message translates to:
  /// **'Cheese'**
  String get merchantToppingCheese;

  /// No description provided for @merchantToppingSpice.
  ///
  /// In en, this message translates to:
  /// **'Extra spice'**
  String get merchantToppingSpice;

  /// No description provided for @dayMon.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get dayMon;

  /// No description provided for @dayTue.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get dayTue;

  /// No description provided for @dayWed.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get dayWed;

  /// No description provided for @dayThu.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get dayThu;

  /// No description provided for @dayFri.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get dayFri;

  /// No description provided for @daySat.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get daySat;

  /// No description provided for @daySun.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get daySun;

  /// No description provided for @rideRouteOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your route'**
  String get rideRouteOverviewTitle;

  /// No description provided for @rideRouteOverviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Estimated path before booking'**
  String get rideRouteOverviewSubtitle;

  /// No description provided for @rideRouteOverviewMapBadge.
  ///
  /// In en, this message translates to:
  /// **'4.8 km · ~12 min'**
  String get rideRouteOverviewMapBadge;

  /// No description provided for @rideRouteSwapTooltip.
  ///
  /// In en, this message translates to:
  /// **'Swap pickup and dropoff'**
  String get rideRouteSwapTooltip;

  /// No description provided for @rideRouteInService.
  ///
  /// In en, this message translates to:
  /// **'In service area'**
  String get rideRouteInService;

  /// No description provided for @rideRouteDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get rideRouteDistance;

  /// No description provided for @rideRouteDistanceSample.
  ///
  /// In en, this message translates to:
  /// **'4.8 km'**
  String get rideRouteDistanceSample;

  /// No description provided for @rideRouteDuration.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get rideRouteDuration;

  /// No description provided for @rideRouteDurationSample.
  ///
  /// In en, this message translates to:
  /// **'~12 min'**
  String get rideRouteDurationSample;

  /// No description provided for @rideRouteRefPrice.
  ///
  /// In en, this message translates to:
  /// **'Ref. price'**
  String get rideRouteRefPrice;

  /// No description provided for @rideRoutePriceHint.
  ///
  /// In en, this message translates to:
  /// **'Official price appears when you choose a vehicle.'**
  String get rideRoutePriceHint;

  /// No description provided for @rideRouteContinueVehicle.
  ///
  /// In en, this message translates to:
  /// **'Continue to vehicles'**
  String get rideRouteContinueVehicle;

  /// No description provided for @rideFareBreakdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Fare details'**
  String get rideFareBreakdownTitle;

  /// No description provided for @rideFareEstimatedFee.
  ///
  /// In en, this message translates to:
  /// **'Estimated fee'**
  String get rideFareEstimatedFee;

  /// No description provided for @rideFareVersionChip.
  ///
  /// In en, this message translates to:
  /// **'Quote v1'**
  String get rideFareVersionChip;

  /// No description provided for @rideFareComponentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Fare components'**
  String get rideFareComponentsTitle;

  /// No description provided for @rideFareBase.
  ///
  /// In en, this message translates to:
  /// **'Base fare'**
  String get rideFareBase;

  /// No description provided for @rideFareDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance fare'**
  String get rideFareDistance;

  /// No description provided for @rideFareSurcharge.
  ///
  /// In en, this message translates to:
  /// **'Included surcharges'**
  String get rideFareSurcharge;

  /// No description provided for @rideFareDiscount.
  ///
  /// In en, this message translates to:
  /// **'Promotion'**
  String get rideFareDiscount;

  /// No description provided for @rideFareProposedTotal.
  ///
  /// In en, this message translates to:
  /// **'Proposed total'**
  String get rideFareProposedTotal;

  /// No description provided for @rideFareTripInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip information'**
  String get rideFareTripInfoTitle;

  /// No description provided for @rideFareBreakdownNote.
  ///
  /// In en, this message translates to:
  /// **'The fare is locked to the quote you confirm. Later surcharges need notice and your consent.'**
  String get rideFareBreakdownNote;

  /// No description provided for @rideFareProposeCta.
  ///
  /// In en, this message translates to:
  /// **'Propose trip fare'**
  String get rideFareProposeCta;

  /// No description provided for @rideTrackingEtaChip.
  ///
  /// In en, this message translates to:
  /// **'Driver about 4 min away'**
  String get rideTrackingEtaChip;

  /// No description provided for @rideTrackingMovingChip.
  ///
  /// In en, this message translates to:
  /// **'Heading to pickup'**
  String get rideTrackingMovingChip;

  /// No description provided for @rideTrackingInProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip in progress'**
  String get rideTrackingInProgressTitle;

  /// No description provided for @rideTrackingProgressSample.
  ///
  /// In en, this message translates to:
  /// **'Traveled 3.1 / 5.2 km (fixture)'**
  String get rideTrackingProgressSample;

  /// No description provided for @rideTrackingRunningChip.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get rideTrackingRunningChip;

  /// No description provided for @rideShareTrip.
  ///
  /// In en, this message translates to:
  /// **'Share trip'**
  String get rideShareTrip;

  /// No description provided for @foodSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Find dishes & stores'**
  String get foodSearchTitle;

  /// No description provided for @foodSearchHint.
  ///
  /// In en, this message translates to:
  /// **'bun bo'**
  String get foodSearchHint;

  /// No description provided for @foodSearchFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get foodSearchFilterAll;

  /// No description provided for @foodSearchFilterStores.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get foodSearchFilterStores;

  /// No description provided for @foodSearchFilterDishes.
  ///
  /// In en, this message translates to:
  /// **'Dishes'**
  String get foodSearchFilterDishes;

  /// No description provided for @foodSearchFilterNear.
  ///
  /// In en, this message translates to:
  /// **'Near me'**
  String get foodSearchFilterNear;

  /// No description provided for @foodSearchSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Search suggestions'**
  String get foodSearchSuggestions;

  /// No description provided for @foodSearchSuggestionsHint.
  ///
  /// In en, this message translates to:
  /// **'Results matching your keyword'**
  String get foodSearchSuggestionsHint;

  /// No description provided for @foodSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No matching stores yet'**
  String get foodSearchEmpty;

  /// No description provided for @foodSearchHistory.
  ///
  /// In en, this message translates to:
  /// **'Search history'**
  String get foodSearchHistory;

  /// No description provided for @foodSearchClearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get foodSearchClearHistory;

  /// No description provided for @foodSearchPopular.
  ///
  /// In en, this message translates to:
  /// **'Popular keywords'**
  String get foodSearchPopular;

  /// No description provided for @foodCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Restaurants & categories'**
  String get foodCategoryTitle;

  /// No description provided for @foodCategorySearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Food in Da Nang'**
  String get foodCategorySearchPlaceholder;

  /// No description provided for @foodCategorySortNear.
  ///
  /// In en, this message translates to:
  /// **'Nearest'**
  String get foodCategorySortNear;

  /// No description provided for @foodCategorySortRating.
  ///
  /// In en, this message translates to:
  /// **'Top rated'**
  String get foodCategorySortRating;

  /// No description provided for @foodCategorySortFreeship.
  ///
  /// In en, this message translates to:
  /// **'Free shipping'**
  String get foodCategorySortFreeship;

  /// No description provided for @foodCategoryFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get foodCategoryFilter;

  /// No description provided for @foodCategoryAroundYou.
  ///
  /// In en, this message translates to:
  /// **'Restaurants around you'**
  String get foodCategoryAroundYou;

  /// No description provided for @foodCategoryAroundHint.
  ///
  /// In en, this message translates to:
  /// **'{count} stores · Deliver to Hai Chau'**
  String foodCategoryAroundHint(int count);

  /// No description provided for @foodCategoryVietnamese.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get foodCategoryVietnamese;

  /// No description provided for @foodFreeshipChip.
  ///
  /// In en, this message translates to:
  /// **'Freeship 0đ'**
  String get foodFreeshipChip;

  /// No description provided for @foodItemOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Item options'**
  String get foodItemOptionsTitle;

  /// No description provided for @foodItemOptionsRating.
  ///
  /// In en, this message translates to:
  /// **'★ 4.8 (320 reviews) · Sold 2.4k'**
  String get foodItemOptionsRating;

  /// No description provided for @foodItemOptionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Hue-style beef noodle with soft beef, crab cake, herbs, and hot broth.'**
  String get foodItemOptionsDescription;

  /// No description provided for @foodItemOptionsNoGroups.
  ///
  /// In en, this message translates to:
  /// **'No options for this item.'**
  String get foodItemOptionsNoGroups;

  /// No description provided for @foodItemOptionsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get foodItemOptionsTotal;

  /// No description provided for @foodItemOptionsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to cart'**
  String get foodItemOptionsAdd;

  /// No description provided for @foodItemOptionsRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get foodItemOptionsRequired;

  /// No description provided for @foodItemOptionsOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get foodItemOptionsOptional;

  /// No description provided for @foodInvoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Order receipt'**
  String get foodInvoiceTitle;

  /// No description provided for @foodInvoiceDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered successfully'**
  String get foodInvoiceDelivered;

  /// No description provided for @foodInvoiceOrderId.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get foodInvoiceOrderId;

  /// No description provided for @foodInvoiceSyncChip.
  ///
  /// In en, this message translates to:
  /// **'v1 · Synced'**
  String get foodInvoiceSyncChip;

  /// No description provided for @foodInvoiceDeliveredChip.
  ///
  /// In en, this message translates to:
  /// **'DELIVERED'**
  String get foodInvoiceDeliveredChip;

  /// No description provided for @foodInvoiceStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get foodInvoiceStore;

  /// No description provided for @foodInvoiceRecipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get foodInvoiceRecipient;

  /// No description provided for @foodInvoiceRecipientSample.
  ///
  /// In en, this message translates to:
  /// **'Tran Thi Mai'**
  String get foodInvoiceRecipientSample;

  /// No description provided for @foodInvoiceItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Items received'**
  String get foodInvoiceItemsTitle;

  /// No description provided for @foodInvoiceItemsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No line items on this order yet.'**
  String get foodInvoiceItemsEmpty;

  /// No description provided for @foodInvoiceReceiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get foodInvoiceReceiptTitle;

  /// No description provided for @foodInvoiceSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get foodInvoiceSubtotal;

  /// No description provided for @foodInvoiceDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get foodInvoiceDelivery;

  /// No description provided for @foodInvoiceDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get foodInvoiceDiscount;

  /// No description provided for @foodInvoiceCodTotal.
  ///
  /// In en, this message translates to:
  /// **'COD total'**
  String get foodInvoiceCodTotal;

  /// No description provided for @foodInvoiceMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get foodInvoiceMethod;

  /// No description provided for @foodInvoiceMethodCollected.
  ///
  /// In en, this message translates to:
  /// **'COD · Collected'**
  String get foodInvoiceMethodCollected;

  /// No description provided for @foodInvoiceCodNote.
  ///
  /// In en, this message translates to:
  /// **'COD {amount} is collected by the driver and recorded once on successful delivery.'**
  String foodInvoiceCodNote(String amount);

  /// No description provided for @foodInvoiceRateCta.
  ///
  /// In en, this message translates to:
  /// **'Rate order'**
  String get foodInvoiceRateCta;

  /// No description provided for @foodTrackingStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Live status'**
  String get foodTrackingStatusTitle;

  /// No description provided for @foodTrackingSyncChip.
  ///
  /// In en, this message translates to:
  /// **'v1 · Synced'**
  String get foodTrackingSyncChip;

  /// No description provided for @foodTrackingMapChip.
  ///
  /// In en, this message translates to:
  /// **'Order is being delivered'**
  String get foodTrackingMapChip;

  /// No description provided for @foodTrackingMapCity.
  ///
  /// In en, this message translates to:
  /// **'Da Nang · Simulation'**
  String get foodTrackingMapCity;

  /// No description provided for @foodTrackingDriverTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver delivering'**
  String get foodTrackingDriverTitle;

  /// No description provided for @foodTrackingDriverSample.
  ///
  /// In en, this message translates to:
  /// **'Tran Minh Anh'**
  String get foodTrackingDriverSample;

  /// No description provided for @foodTrackingDriverMeta.
  ///
  /// In en, this message translates to:
  /// **'Honda Vision · bike · 43H1-123.45'**
  String get foodTrackingDriverMeta;

  /// No description provided for @foodTrackingVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get foodTrackingVerified;

  /// No description provided for @foodTrackingEtaLabel.
  ///
  /// In en, this message translates to:
  /// **'ETA (fixture)'**
  String get foodTrackingEtaLabel;

  /// No description provided for @foodTrackingEtaSample.
  ///
  /// In en, this message translates to:
  /// **'~8 min'**
  String get foodTrackingEtaSample;

  /// No description provided for @foodTrackingPayOnDelivery.
  ///
  /// In en, this message translates to:
  /// **'Pay on delivery'**
  String get foodTrackingPayOnDelivery;

  /// No description provided for @foodTrackingCodDue.
  ///
  /// In en, this message translates to:
  /// **'COD due'**
  String get foodTrackingCodDue;

  /// No description provided for @foodTrackingCodHint.
  ///
  /// In en, this message translates to:
  /// **'Not collected until delivery succeeds.'**
  String get foodTrackingCodHint;

  /// No description provided for @paymentHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment history'**
  String get paymentHistoryTitle;

  /// No description provided for @paymentHistoryMonthTotal.
  ///
  /// In en, this message translates to:
  /// **'Total paid this month'**
  String get paymentHistoryMonthTotal;

  /// No description provided for @paymentHistoryMonthMeta.
  ///
  /// In en, this message translates to:
  /// **'October 2026 · 12 transactions'**
  String get paymentHistoryMonthMeta;

  /// No description provided for @paymentHistoryTestOnly.
  ///
  /// In en, this message translates to:
  /// **'TEST_ONLY fixture'**
  String get paymentHistoryTestOnly;

  /// No description provided for @paymentHistoryFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get paymentHistoryFilterAll;

  /// No description provided for @paymentHistoryFilterPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paymentHistoryFilterPaid;

  /// No description provided for @paymentHistoryFilterRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get paymentHistoryFilterRefund;

  /// No description provided for @paymentHistoryRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get paymentHistoryRecent;

  /// No description provided for @paymentHistoryMonthPicker.
  ///
  /// In en, this message translates to:
  /// **'October ▼'**
  String get paymentHistoryMonthPicker;

  /// No description provided for @paymentHistoryTodayGroup.
  ///
  /// In en, this message translates to:
  /// **'TODAY, 11/10'**
  String get paymentHistoryTodayGroup;

  /// No description provided for @paymentHistoryFoodSample.
  ///
  /// In en, this message translates to:
  /// **'Order Bun Bo Hue O Co'**
  String get paymentHistoryFoodSample;

  /// No description provided for @paymentHistoryFoodMeta.
  ///
  /// In en, this message translates to:
  /// **'10:32 · DealGo Wallet · #DG123456'**
  String get paymentHistoryFoodMeta;

  /// No description provided for @paymentHistoryRideSample.
  ///
  /// In en, this message translates to:
  /// **'Airport ride'**
  String get paymentHistoryRideSample;

  /// No description provided for @paymentHistoryRideMeta.
  ///
  /// In en, this message translates to:
  /// **'09:15 · COD · #Q-CAR-0007'**
  String get paymentHistoryRideMeta;

  /// No description provided for @paymentHistoryRefundSample.
  ///
  /// In en, this message translates to:
  /// **'Refund · cancelled order'**
  String get paymentHistoryRefundSample;

  /// No description provided for @paymentHistoryRefundMeta.
  ///
  /// In en, this message translates to:
  /// **'08:40 · Wallet · #RF-001'**
  String get paymentHistoryRefundMeta;

  /// No description provided for @paymentHistoryNote.
  ///
  /// In en, this message translates to:
  /// **'Each transaction has a reconciliation code and receipt so you can review payments or refunds.'**
  String get paymentHistoryNote;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

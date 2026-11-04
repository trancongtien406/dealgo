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

  /// No description provided for @actionBookRideNow.
  ///
  /// In en, this message translates to:
  /// **'Book a ride'**
  String get actionBookRideNow;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

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

  /// No description provided for @emptyStoresNearby.
  ///
  /// In en, this message translates to:
  /// **'No stores nearby yet'**
  String get emptyStoresNearby;

  /// No description provided for @emptyOffers.
  ///
  /// In en, this message translates to:
  /// **'No driver offers yet'**
  String get emptyOffers;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

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
  /// **'Me'**
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
  /// **'Menu'**
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

  /// No description provided for @authPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get authPhoneLabel;

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

  /// No description provided for @otpHeading.
  ///
  /// In en, this message translates to:
  /// **'Verify phone'**
  String get otpHeading;

  /// No description provided for @otpSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get otpSending;

  /// No description provided for @otpInvalidTitle.
  ///
  /// In en, this message translates to:
  /// **'Wrong code'**
  String get otpInvalidTitle;

  /// No description provided for @otpExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Code expired'**
  String get otpExpiredTitle;

  /// No description provided for @otpLockedBody.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try later.'**
  String get otpLockedBody;

  /// No description provided for @otpInvalidBody.
  ///
  /// In en, this message translates to:
  /// **'Code is wrong or used.'**
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
  /// **'Wait to resend.'**
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
  /// **'Wait to get a new code.'**
  String get otpServerGateHint;

  /// No description provided for @otpPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'For your security, wrong attempts are limited.'**
  String get otpPrivacyNote;

  /// No description provided for @otpFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get otpFieldLabel;

  /// No description provided for @actionChangeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get actionChangeEmail;

  /// No description provided for @authEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// No description provided for @otpEmailHeadingPrefix.
  ///
  /// In en, this message translates to:
  /// **'Verify '**
  String get otpEmailHeadingPrefix;

  /// No description provided for @otpEmailHeadingAccent.
  ///
  /// In en, this message translates to:
  /// **'email'**
  String get otpEmailHeadingAccent;

  /// No description provided for @otpEmailBodyPrefix.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to '**
  String get otpEmailBodyPrefix;

  /// No description provided for @emailErrorNotVerified.
  ///
  /// In en, this message translates to:
  /// **'This email is not verified yet. Sign in again to get a verification code, or reset your password by email.'**
  String get emailErrorNotVerified;

  /// No description provided for @emailErrorTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get emailErrorTooManyAttempts;

  /// No description provided for @emailErrorDeliveryFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not send the verification email. Please try again later.'**
  String get emailErrorDeliveryFailed;

  /// No description provided for @otpEmailLockedBody.
  ///
  /// In en, this message translates to:
  /// **'Too many incorrect codes. Go back and start again to get a new code.'**
  String get otpEmailLockedBody;

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

  /// No description provided for @chatContact.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get chatContact;

  /// No description provided for @chatContactShop.
  ///
  /// In en, this message translates to:
  /// **'Message the shop'**
  String get chatContactShop;

  /// No description provided for @chatContactCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer chat'**
  String get chatContactCustomer;

  /// No description provided for @voiceCall.
  ///
  /// In en, this message translates to:
  /// **'Voice call'**
  String get voiceCall;

  /// No description provided for @voiceCalling.
  ///
  /// In en, this message translates to:
  /// **'Calling…'**
  String get voiceCalling;

  /// No description provided for @voiceConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get voiceConnecting;

  /// No description provided for @voiceIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming call'**
  String get voiceIncoming;

  /// No description provided for @voiceReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Weak signal, reconnecting…'**
  String get voiceReconnecting;

  /// No description provided for @voicePeerCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get voicePeerCustomer;

  /// No description provided for @voicePeerDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get voicePeerDriver;

  /// No description provided for @voiceAccept.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get voiceAccept;

  /// No description provided for @voiceDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get voiceDecline;

  /// No description provided for @voiceHangUp.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get voiceHangUp;

  /// No description provided for @voiceMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get voiceMute;

  /// No description provided for @voiceUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get voiceUnmute;

  /// No description provided for @voiceSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get voiceSpeaker;

  /// No description provided for @voiceEndedHungUp.
  ///
  /// In en, this message translates to:
  /// **'Call ended'**
  String get voiceEndedHungUp;

  /// No description provided for @voiceEndedDeclined.
  ///
  /// In en, this message translates to:
  /// **'Call declined'**
  String get voiceEndedDeclined;

  /// No description provided for @voiceEndedNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'No answer'**
  String get voiceEndedNoAnswer;

  /// No description provided for @voiceEndedMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed call'**
  String get voiceEndedMissed;

  /// No description provided for @voiceEndedTripClosed.
  ///
  /// In en, this message translates to:
  /// **'The trip has ended, so the call stopped'**
  String get voiceEndedTripClosed;

  /// No description provided for @voiceEndedConnectionLost.
  ///
  /// In en, this message translates to:
  /// **'Call connection lost'**
  String get voiceEndedConnectionLost;

  /// No description provided for @voiceMicDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is needed for calls. Turn it on in Settings.'**
  String get voiceMicDenied;

  /// No description provided for @apiErrVoiceDisabled.
  ///
  /// In en, this message translates to:
  /// **'In-app calling is turned off right now.'**
  String get apiErrVoiceDisabled;

  /// No description provided for @apiErrVoiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Calling isn\'t available right now. Please use chat.'**
  String get apiErrVoiceUnavailable;

  /// No description provided for @apiErrVoiceBusy.
  ///
  /// In en, this message translates to:
  /// **'There is already a call for this trip.'**
  String get apiErrVoiceBusy;

  /// No description provided for @apiErrVoiceNoCounterpart.
  ///
  /// In en, this message translates to:
  /// **'No driver has taken this trip yet.'**
  String get apiErrVoiceNoCounterpart;

  /// No description provided for @apiErrVoiceWindowClosed.
  ///
  /// In en, this message translates to:
  /// **'Calls are only available while the trip is in progress.'**
  String get apiErrVoiceWindowClosed;

  /// No description provided for @apiErrChatWindowClosed.
  ///
  /// In en, this message translates to:
  /// **'The contact window has closed for this trip or order.'**
  String get apiErrChatWindowClosed;

  /// No description provided for @apiErrChatNoCounterpart.
  ///
  /// In en, this message translates to:
  /// **'No driver has been assigned to this order yet.'**
  String get apiErrChatNoCounterpart;

  /// No description provided for @apiErrChatForbidden.
  ///
  /// In en, this message translates to:
  /// **'You do not have access to this conversation.'**
  String get apiErrChatForbidden;

  /// No description provided for @apiErrChatUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Chat is temporarily unavailable. Please try again later.'**
  String get apiErrChatUnavailable;

  /// No description provided for @apiErrChatBodyInvalid.
  ///
  /// In en, this message translates to:
  /// **'Message content is invalid.'**
  String get apiErrChatBodyInvalid;

  /// No description provided for @bannerOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'You’re offline'**
  String get bannerOfflineTitle;

  /// No description provided for @commonSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get commonSelected;

  /// No description provided for @actionSeeDetail.
  ///
  /// In en, this message translates to:
  /// **'View details →'**
  String get actionSeeDetail;

  /// No description provided for @rideOfferDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Offer details'**
  String get rideOfferDetailTitle;

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

  /// No description provided for @rideSelectOfferCta.
  ///
  /// In en, this message translates to:
  /// **'Choose offer'**
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
  /// **'Share only if car and plate match.'**
  String get ridePickupCodeBody;

  /// No description provided for @ridePickupCodeSafetyTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep the code private'**
  String get ridePickupCodeSafetyTitle;

  /// No description provided for @ridePickupCodeSafetyBody.
  ///
  /// In en, this message translates to:
  /// **'Don\'t send the code in chat.'**
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
  /// **'Share your trip; call 113/115 if needed.'**
  String get rideSafetyBannerBody;

  /// No description provided for @rideSafetyShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share trip'**
  String get rideSafetyShareTitle;

  /// No description provided for @rideSafetyShareBody.
  ///
  /// In en, this message translates to:
  /// **'Send a trip link to someone.'**
  String get rideSafetyShareBody;

  /// No description provided for @rideSafetyShareCta.
  ///
  /// In en, this message translates to:
  /// **'Share trip link'**
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
  /// **'Saved on this device.'**
  String get rideSafetyContactsBody;

  /// No description provided for @rideSafetyAddContact.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get rideSafetyAddContact;

  /// No description provided for @rideSafetyEmergencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency help'**
  String get rideSafetyEmergencyTitle;

  /// No description provided for @rideSafetyEmergencyBody.
  ///
  /// In en, this message translates to:
  /// **'Call emergency from your phone.'**
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

  /// No description provided for @rideCancelBookAgain.
  ///
  /// In en, this message translates to:
  /// **'Book another ride'**
  String get rideCancelBookAgain;

  /// No description provided for @rideCancelReasonOptional.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get rideCancelReasonOptional;

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
  /// **'Couldn\'t connect. Please try again when you\'re online.'**
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
  /// **'Cancel only before the store accepts.'**
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
  /// **'Pick a reason.'**
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

  /// No description provided for @driverJobFailedSoftFail.
  ///
  /// In en, this message translates to:
  /// **'Reason saved on this device.'**
  String get driverJobFailedSoftFail;

  /// No description provided for @driverOpenCompletedSample.
  ///
  /// In en, this message translates to:
  /// **'View trip details'**
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

  /// No description provided for @driverCompletedEarningsTitle.
  ///
  /// In en, this message translates to:
  /// **'Earnings for this job'**
  String get driverCompletedEarningsTitle;

  /// No description provided for @driverCompletedFareLabel.
  ///
  /// In en, this message translates to:
  /// **'Accepted fare'**
  String get driverCompletedFareLabel;

  /// No description provided for @driverJobsHistorySection.
  ///
  /// In en, this message translates to:
  /// **'Job outcomes'**
  String get driverJobsHistorySection;

  /// No description provided for @driverServicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose services'**
  String get driverServicesTitle;

  /// No description provided for @driverServicesHeadline.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get driverServicesHeadline;

  /// No description provided for @driverServicesOnlineTitle.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get driverServicesOnlineTitle;

  /// No description provided for @driverServicesApprovedSection.
  ///
  /// In en, this message translates to:
  /// **'Approved services'**
  String get driverServicesApprovedSection;

  /// No description provided for @driverServicesRideTitle.
  ///
  /// In en, this message translates to:
  /// **'Rides'**
  String get driverServicesRideTitle;

  /// No description provided for @driverServicesFoodTitle.
  ///
  /// In en, this message translates to:
  /// **'Food delivery'**
  String get driverServicesFoodTitle;

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

  /// No description provided for @driverServicesAreaSection.
  ///
  /// In en, this message translates to:
  /// **'Request area'**
  String get driverServicesAreaSection;

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
  /// **'Enter the rider\'s 4-digit code.'**
  String get driverOtpBody;

  /// No description provided for @driverOtpVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Passenger verification'**
  String get driverOtpVerifyTitle;

  /// No description provided for @driverOtpValidFor.
  ///
  /// In en, this message translates to:
  /// **'OTP is valid only for trip {rideId}'**
  String driverOtpValidFor(String rideId);

  /// No description provided for @driverOtpWaitingHint.
  ///
  /// In en, this message translates to:
  /// **'Ask the customer for their pickup code'**
  String get driverOtpWaitingHint;

  /// No description provided for @driverOtpWrong.
  ///
  /// In en, this message translates to:
  /// **'OTP does not match. Check again with the passenger.'**
  String get driverOtpWrong;

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
  /// **'Heading to pickup'**
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
  /// **'Wait, then enter OTP to start.'**
  String get driverActiveWaitingBody;

  /// No description provided for @driverActiveOnTripBody.
  ///
  /// In en, this message translates to:
  /// **'Drive safely.'**
  String get driverActiveOnTripBody;

  /// No description provided for @driverActiveCompleteCta.
  ///
  /// In en, this message translates to:
  /// **'Complete / collect payment'**
  String get driverActiveCompleteCta;

  /// No description provided for @driverActiveCompleteBody.
  ///
  /// In en, this message translates to:
  /// **'Collect the agreed fare.'**
  String get driverActiveCompleteBody;

  /// No description provided for @driverActiveReportIssue.
  ///
  /// In en, this message translates to:
  /// **'Report issue'**
  String get driverActiveReportIssue;

  /// No description provided for @driverFoodPhaseNavTitle.
  ///
  /// In en, this message translates to:
  /// **'Heading to store'**
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
  /// **'Delivered'**
  String get driverFoodPhaseCompleteTitle;

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
  /// **'Wait for the order.'**
  String get driverFoodWaitBody;

  /// No description provided for @driverFoodPickupBody.
  ///
  /// In en, this message translates to:
  /// **'Check bags and handover code.'**
  String get driverFoodPickupBody;

  /// No description provided for @driverFoodDeliverBody.
  ///
  /// In en, this message translates to:
  /// **'Deliver and collect COD.'**
  String get driverFoodDeliverBody;

  /// No description provided for @driverFoodCompleteBody.
  ///
  /// In en, this message translates to:
  /// **'COD will be settled.'**
  String get driverFoodCompleteBody;

  /// No description provided for @driverFoodIncomePending.
  ///
  /// In en, this message translates to:
  /// **'Updated after settlement'**
  String get driverFoodIncomePending;

  /// No description provided for @driverFoodNoClientFee.
  ///
  /// In en, this message translates to:
  /// **'Your net income shows after settlement.'**
  String get driverFoodNoClientFee;

  /// No description provided for @driverFoodCodCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect (COD)'**
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
  /// **'Reject this order?'**
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
  /// **'Order declined. The customer is notified it was cancelled.'**
  String get merchantRejectDone;

  /// No description provided for @merchantHomeFinanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Today’s finances'**
  String get merchantHomeFinanceTitle;

  /// No description provided for @merchantHomeCompletedToday.
  ///
  /// In en, this message translates to:
  /// **'Completed today'**
  String get merchantHomeCompletedToday;

  /// No description provided for @merchantHomeFoodToday.
  ///
  /// In en, this message translates to:
  /// **'Food sales today'**
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

  /// No description provided for @merchantSettingsShellTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop settings'**
  String get merchantSettingsShellTitle;

  /// No description provided for @merchantAcceptTitle.
  ///
  /// In en, this message translates to:
  /// **'Order acceptance'**
  String get merchantAcceptTitle;

  /// No description provided for @merchantAcceptModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Order confirmation mode'**
  String get merchantAcceptModeLabel;

  /// No description provided for @merchantAcceptManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get merchantAcceptManual;

  /// No description provided for @merchantAcceptAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic when eligible'**
  String get merchantAcceptAuto;

  /// No description provided for @merchantAcceptManualHint.
  ///
  /// In en, this message translates to:
  /// **'Accept each order.'**
  String get merchantAcceptManualHint;

  /// No description provided for @merchantAcceptAutoHint.
  ///
  /// In en, this message translates to:
  /// **'Auto-accept while open.'**
  String get merchantAcceptAutoHint;

  /// No description provided for @merchantHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get merchantHoursTitle;

  /// No description provided for @merchantHoursOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get merchantHoursOpen;

  /// No description provided for @merchantHoursClosed.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get merchantHoursClosed;

  /// No description provided for @merchantBusyTitle.
  ///
  /// In en, this message translates to:
  /// **'Busy / Paused'**
  String get merchantBusyTitle;

  /// No description provided for @merchantBusyModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Service mode'**
  String get merchantBusyModeLabel;

  /// No description provided for @merchantBusyOpen.
  ///
  /// In en, this message translates to:
  /// **'Operating normally'**
  String get merchantBusyOpen;

  /// No description provided for @merchantBusyBusy.
  ///
  /// In en, this message translates to:
  /// **'Kitchen busy'**
  String get merchantBusyBusy;

  /// No description provided for @merchantBusyPaused.
  ///
  /// In en, this message translates to:
  /// **'Pause new orders'**
  String get merchantBusyPaused;

  /// No description provided for @merchantBusyOpenHint.
  ///
  /// In en, this message translates to:
  /// **'Take orders during opening hours.'**
  String get merchantBusyOpenHint;

  /// No description provided for @merchantBusyBusyHint.
  ///
  /// In en, this message translates to:
  /// **'Still open, slower prep.'**
  String get merchantBusyBusyHint;

  /// No description provided for @merchantBusyPausedHint.
  ///
  /// In en, this message translates to:
  /// **'No new orders.'**
  String get merchantBusyPausedHint;

  /// No description provided for @merchantVariantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get merchantVariantsTitle;

  /// No description provided for @merchantVariantsCta.
  ///
  /// In en, this message translates to:
  /// **'Edit variants'**
  String get merchantVariantsCta;

  /// No description provided for @merchantVariantsSave.
  ///
  /// In en, this message translates to:
  /// **'Save options'**
  String get merchantVariantsSave;

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

  /// No description provided for @rideRouteSwapTooltip.
  ///
  /// In en, this message translates to:
  /// **'Swap pickup and dropoff'**
  String get rideRouteSwapTooltip;

  /// No description provided for @rideRouteDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get rideRouteDistance;

  /// No description provided for @rideRouteRefPrice.
  ///
  /// In en, this message translates to:
  /// **'Ref. price'**
  String get rideRouteRefPrice;

  /// No description provided for @rideRouteContinueBooking.
  ///
  /// In en, this message translates to:
  /// **'Choose vehicle & offer'**
  String get rideRouteContinueBooking;

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

  /// No description provided for @rideFareComponentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Fare components'**
  String get rideFareComponentsTitle;

  /// No description provided for @rideFareTripInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip information'**
  String get rideFareTripInfoTitle;

  /// No description provided for @rideFareProposeCta.
  ///
  /// In en, this message translates to:
  /// **'Propose trip fare'**
  String get rideFareProposeCta;

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

  /// No description provided for @foodSearchFilterNear.
  ///
  /// In en, this message translates to:
  /// **'Near me'**
  String get foodSearchFilterNear;

  /// No description provided for @foodSearchSortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get foodSearchSortNewest;

  /// No description provided for @foodSearchSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Search suggestions'**
  String get foodSearchSuggestions;

  /// No description provided for @foodSearchResults.
  ///
  /// In en, this message translates to:
  /// **'{count} results'**
  String foodSearchResults(int count);

  /// No description provided for @foodSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No matching stores yet'**
  String get foodSearchEmpty;

  /// No description provided for @foodSearchDishes.
  ///
  /// In en, this message translates to:
  /// **'Dishes'**
  String get foodSearchDishes;

  /// No description provided for @foodSearchStores.
  ///
  /// In en, this message translates to:
  /// **'Stores'**
  String get foodSearchStores;

  /// No description provided for @foodSearchDishUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This dish is no longer sold'**
  String get foodSearchDishUnavailable;

  /// No description provided for @foodDeliverTo.
  ///
  /// In en, this message translates to:
  /// **'Deliver to'**
  String get foodDeliverTo;

  /// No description provided for @foodFilterButton.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get foodFilterButton;

  /// No description provided for @foodFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter & sort'**
  String get foodFilterTitle;

  /// No description provided for @foodFilterSort.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get foodFilterSort;

  /// No description provided for @foodFilterNear.
  ///
  /// In en, this message translates to:
  /// **'Nearest'**
  String get foodFilterNear;

  /// No description provided for @foodFilterRating.
  ///
  /// In en, this message translates to:
  /// **'Top rated'**
  String get foodFilterRating;

  /// No description provided for @foodFilterDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get foodFilterDistance;

  /// No description provided for @foodFilterAnyDistance.
  ///
  /// In en, this message translates to:
  /// **'Any distance'**
  String get foodFilterAnyDistance;

  /// No description provided for @foodFilterKm.
  ///
  /// In en, this message translates to:
  /// **'Within {km} km'**
  String foodFilterKm(int km);

  /// No description provided for @foodFilterOpenNow.
  ///
  /// In en, this message translates to:
  /// **'Open now'**
  String get foodFilterOpenNow;

  /// No description provided for @foodFilterOffers.
  ///
  /// In en, this message translates to:
  /// **'Has offers'**
  String get foodFilterOffers;

  /// No description provided for @foodFilterApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get foodFilterApply;

  /// No description provided for @foodFilterReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get foodFilterReset;

  /// No description provided for @foodFilterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get foodFilterClear;

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

  /// No description provided for @foodCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Restaurants & categories'**
  String get foodCategoryTitle;

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

  /// No description provided for @foodCategoryAroundYou.
  ///
  /// In en, this message translates to:
  /// **'Restaurants around you'**
  String get foodCategoryAroundYou;

  /// No description provided for @foodCategoryAroundHint.
  ///
  /// In en, this message translates to:
  /// **'{count} stores'**
  String foodCategoryAroundHint(int count);

  /// No description provided for @foodItemOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Item options'**
  String get foodItemOptionsTitle;

  /// No description provided for @foodItemAddonsTitle.
  ///
  /// In en, this message translates to:
  /// **'Add-ons'**
  String get foodItemAddonsTitle;

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

  /// No description provided for @foodItemDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Item details'**
  String get foodItemDetailTitle;

  /// No description provided for @foodDishPhotoCount.
  ///
  /// In en, this message translates to:
  /// **'Photo {index}/{total}'**
  String foodDishPhotoCount(int index, int total);

  /// No description provided for @foodItemOptionsChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose options'**
  String get foodItemOptionsChoose;

  /// No description provided for @foodItemOptionsChooseRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose options'**
  String get foodItemOptionsChooseRequired;

  /// No description provided for @foodItemOptionsMissingRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose {groups}'**
  String foodItemOptionsMissingRequired(String groups);

  /// No description provided for @foodItemOptionsFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get foodItemOptionsFree;

  /// No description provided for @foodItemQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get foodItemQuantity;

  /// No description provided for @foodItemSelectedOptions.
  ///
  /// In en, this message translates to:
  /// **'Selected: {options}'**
  String foodItemSelectedOptions(String options);

  /// No description provided for @foodItemInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Item details'**
  String get foodItemInfoTitle;

  /// No description provided for @foodItemInStore.
  ///
  /// In en, this message translates to:
  /// **'At {store}'**
  String foodItemInStore(String store);

  /// No description provided for @foodStoreDirections.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get foodStoreDirections;

  /// No description provided for @foodStoreOpenInMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Google Maps'**
  String get foodStoreOpenInMaps;

  /// No description provided for @foodStoreMapOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the map.'**
  String get foodStoreMapOpenFailed;

  /// No description provided for @foodStoreMenuSections.
  ///
  /// In en, this message translates to:
  /// **'Menu categories'**
  String get foodStoreMenuSections;

  /// No description provided for @foodItemOptionsMaxReached.
  ///
  /// In en, this message translates to:
  /// **'Maximum {count} selected'**
  String foodItemOptionsMaxReached(int count);

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
  /// **'Delivered'**
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
  /// **'Total paid'**
  String get foodInvoiceCodTotal;

  /// No description provided for @foodInvoiceMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get foodInvoiceMethod;

  /// No description provided for @foodInvoiceMethodCollected.
  ///
  /// In en, this message translates to:
  /// **'Cash · Paid'**
  String get foodInvoiceMethodCollected;

  /// No description provided for @foodInvoiceCodNote.
  ///
  /// In en, this message translates to:
  /// **'Paid {amount} in cash.'**
  String foodInvoiceCodNote(String amount);

  /// No description provided for @foodInvoiceRateCta.
  ///
  /// In en, this message translates to:
  /// **'Rate order'**
  String get foodInvoiceRateCta;

  /// No description provided for @foodInvoiceTrackCta.
  ///
  /// In en, this message translates to:
  /// **'Track order'**
  String get foodInvoiceTrackCta;

  /// No description provided for @foodInvoiceItemsTitleOpen.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get foodInvoiceItemsTitleOpen;

  /// No description provided for @foodInvoiceCodDue.
  ///
  /// In en, this message translates to:
  /// **'Total due'**
  String get foodInvoiceCodDue;

  /// No description provided for @checkoutEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No items yet.'**
  String get checkoutEmptyBody;

  /// No description provided for @checkoutBackToMenu.
  ///
  /// In en, this message translates to:
  /// **'Back to menu'**
  String get checkoutBackToMenu;

  /// No description provided for @foodTrackingMapChip.
  ///
  /// In en, this message translates to:
  /// **'Order is being delivered'**
  String get foodTrackingMapChip;

  /// No description provided for @foodTrackingMapWaitingDriver.
  ///
  /// In en, this message translates to:
  /// **'Waiting for driver location'**
  String get foodTrackingMapWaitingDriver;

  /// No description provided for @foodTrackingMapEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Store not on the map yet.'**
  String get foodTrackingMapEmptyHint;

  /// No description provided for @foodTrackingCodDue.
  ///
  /// In en, this message translates to:
  /// **'Due on delivery'**
  String get foodTrackingCodDue;

  /// No description provided for @foodTrackingCodHint.
  ///
  /// In en, this message translates to:
  /// **'Pay on delivery.'**
  String get foodTrackingCodHint;

  /// No description provided for @paymentHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment history'**
  String get paymentHistoryTitle;

  /// No description provided for @paymentHistoryFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get paymentHistoryFilterAll;

  /// No description provided for @paymentHistoryRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get paymentHistoryRecent;

  /// No description provided for @stateErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get stateErrorTitle;

  /// No description provided for @stateErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load. Try again.'**
  String get stateErrorBody;

  /// No description provided for @fieldShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get fieldShowPassword;

  /// No description provided for @fieldHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get fieldHidePassword;

  /// No description provided for @authHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get authHelp;

  /// No description provided for @authHelpHotline.
  ///
  /// In en, this message translates to:
  /// **'DealGo help center: 1900 6868'**
  String get authHelpHotline;

  /// No description provided for @authLegalPrefix.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to the '**
  String get authLegalPrefix;

  /// No description provided for @authLegalTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get authLegalTerms;

  /// No description provided for @authLegalConsentPrefix.
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to the '**
  String get authLegalConsentPrefix;

  /// No description provided for @authLegalConsentRequired.
  ///
  /// In en, this message translates to:
  /// **'Please read and agree to the Terms of Service and Privacy Policy to continue.'**
  String get authLegalConsentRequired;

  /// No description provided for @authWelcomeTo.
  ///
  /// In en, this message translates to:
  /// **'Welcome to'**
  String get authWelcomeTo;

  /// No description provided for @authMethodPasskey.
  ///
  /// In en, this message translates to:
  /// **'Passkey'**
  String get authMethodPasskey;

  /// No description provided for @authMethodsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No sign-in methods'**
  String get authMethodsEmptyTitle;

  /// No description provided for @authMethodsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Try again later.'**
  String get authMethodsEmptyBody;

  /// No description provided for @authPhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authPhoneTitle;

  /// No description provided for @authPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number'**
  String get authPhoneRequired;

  /// No description provided for @authPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone number (9 to 11 digits)'**
  String get authPhoneInvalid;

  /// No description provided for @authOtherMethods.
  ///
  /// In en, this message translates to:
  /// **'Use another sign-in method'**
  String get authOtherMethods;

  /// No description provided for @emailErrRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address'**
  String get emailErrRequired;

  /// No description provided for @emailErrInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get emailErrInvalid;

  /// No description provided for @passwordErrRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get passwordErrRequired;

  /// No description provided for @passwordErrTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordErrTooShort;

  /// No description provided for @passwordErrConfirm.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get passwordErrConfirm;

  /// No description provided for @passwordErrMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordErrMismatch;

  /// No description provided for @emailErrWrongCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password'**
  String get emailErrWrongCredentials;

  /// No description provided for @emailErrInUse.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered'**
  String get emailErrInUse;

  /// No description provided for @emailLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Email'**
  String get emailLoginTitle;

  /// No description provided for @emailRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign up with Email'**
  String get emailRegisterTitle;

  /// No description provided for @emailLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use the email and password you registered with.'**
  String get emailLoginSubtitle;

  /// No description provided for @emailRegisterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a DealGo account with email and password.'**
  String get emailRegisterSubtitle;

  /// No description provided for @emailFieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get emailFieldPassword;

  /// No description provided for @emailFieldConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get emailFieldConfirmPassword;

  /// No description provided for @emailFieldDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name (optional)'**
  String get emailFieldDisplayName;

  /// No description provided for @emailTabLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get emailTabLogin;

  /// No description provided for @emailTabRegister.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get emailTabRegister;

  /// No description provided for @otpSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count}s'**
  String otpSeconds(int count);

  /// No description provided for @otpChangePhone.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get otpChangePhone;

  /// No description provided for @otpPhoneHeadingPrefix.
  ///
  /// In en, this message translates to:
  /// **'Verify '**
  String get otpPhoneHeadingPrefix;

  /// No description provided for @otpPhoneHeadingAccent.
  ///
  /// In en, this message translates to:
  /// **'phone number'**
  String get otpPhoneHeadingAccent;

  /// No description provided for @otpResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in'**
  String get otpResendIn;

  /// No description provided for @otpShieldNote.
  ///
  /// In en, this message translates to:
  /// **'OTP protects your account.'**
  String get otpShieldNote;

  /// No description provided for @otpConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get otpConfirm;

  /// No description provided for @passkeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Passkey'**
  String get passkeyTitle;

  /// No description provided for @passkeyOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get passkeyOr;

  /// No description provided for @passkeyContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue with passkey'**
  String get passkeyContinue;

  /// No description provided for @passkeySignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get passkeySignIn;

  /// No description provided for @passkeySignUp.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get passkeySignUp;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Go anywhere · Eat everything'**
  String get splashTagline;

  /// No description provided for @splashPreparing.
  ///
  /// In en, this message translates to:
  /// **'Getting things ready for you...'**
  String get splashPreparing;

  /// No description provided for @serviceRideTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride'**
  String get serviceRideTitle;

  /// No description provided for @serviceRideBlurb.
  ///
  /// In en, this message translates to:
  /// **'Bike, car'**
  String get serviceRideBlurb;

  /// No description provided for @serviceFoodTitle.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get serviceFoodTitle;

  /// No description provided for @serviceFoodBlurb.
  ///
  /// In en, this message translates to:
  /// **'Thousands of dishes\nevery day'**
  String get serviceFoodBlurb;

  /// No description provided for @onbSlide1Title.
  ///
  /// In en, this message translates to:
  /// **'One app,\n'**
  String get onbSlide1Title;

  /// No description provided for @onbSlide1Accent.
  ///
  /// In en, this message translates to:
  /// **'endless experiences'**
  String get onbSlide1Accent;

  /// No description provided for @onbSlide1Body.
  ///
  /// In en, this message translates to:
  /// **'Rides, great food and daily shopping — all in DealGo.'**
  String get onbSlide1Body;

  /// No description provided for @onbSlide2Title.
  ///
  /// In en, this message translates to:
  /// **'Move fast,\n'**
  String get onbSlide2Title;

  /// No description provided for @onbSlide2Accent.
  ///
  /// In en, this message translates to:
  /// **'safe & affordable'**
  String get onbSlide2Accent;

  /// No description provided for @onbSlide2Body.
  ///
  /// In en, this message translates to:
  /// **'Local drivers, clear fares, your price.'**
  String get onbSlide2Body;

  /// No description provided for @onbSlide2Pill1Title.
  ///
  /// In en, this message translates to:
  /// **'Bikes & cars'**
  String get onbSlide2Pill1Title;

  /// No description provided for @onbSlide2Pill1Body.
  ///
  /// In en, this message translates to:
  /// **'Pickup in\nas little as 3 min'**
  String get onbSlide2Pill1Body;

  /// No description provided for @onbSlide2Pill2Title.
  ///
  /// In en, this message translates to:
  /// **'Negotiated fares'**
  String get onbSlide2Pill2Title;

  /// No description provided for @onbSlide2Pill2Body.
  ///
  /// In en, this message translates to:
  /// **'Lock in a price\nyou like'**
  String get onbSlide2Pill2Body;

  /// No description provided for @onbSlide3Title.
  ///
  /// In en, this message translates to:
  /// **'Hot, tasty food,\n'**
  String get onbSlide3Title;

  /// No description provided for @onbSlide3Accent.
  ///
  /// In en, this message translates to:
  /// **'delivered fast'**
  String get onbSlide3Accent;

  /// No description provided for @onbSlide3Body.
  ///
  /// In en, this message translates to:
  /// **'Da Nang favourites, delivered.'**
  String get onbSlide3Body;

  /// No description provided for @onbSlide3Pill1Title.
  ///
  /// In en, this message translates to:
  /// **'Local specialties'**
  String get onbSlide3Pill1Title;

  /// No description provided for @onbSlide3Pill1Body.
  ///
  /// In en, this message translates to:
  /// **'Mi Quang, fish cake noodles,\ncrispy banh mi'**
  String get onbSlide3Pill1Body;

  /// No description provided for @onbSlide3Pill2Title.
  ///
  /// In en, this message translates to:
  /// **'20\' express delivery'**
  String get onbSlide3Pill2Title;

  /// No description provided for @onbSlide3Pill2Body.
  ///
  /// In en, this message translates to:
  /// **'Always arrives\npiping hot'**
  String get onbSlide3Pill2Body;

  /// No description provided for @onbSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onbSkip;

  /// No description provided for @onbStart.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onbStart;

  /// No description provided for @profileSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get profileSetupTitle;

  /// No description provided for @profileAvatarOptional.
  ///
  /// In en, this message translates to:
  /// **'Profile photo (optional)'**
  String get profileAvatarOptional;

  /// No description provided for @profileFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get profileFullName;

  /// No description provided for @profileBirthdayOptional.
  ///
  /// In en, this message translates to:
  /// **'Date of birth (optional)'**
  String get profileBirthdayOptional;

  /// No description provided for @profileGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get profileGender;

  /// No description provided for @profileGenderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get profileGenderMale;

  /// No description provided for @profileGenderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get profileGenderFemale;

  /// No description provided for @profileGenderOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get profileGenderOther;

  /// No description provided for @profileDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get profileDone;

  /// No description provided for @rolePickerPrefix.
  ///
  /// In en, this message translates to:
  /// **'How do you want to use '**
  String get rolePickerPrefix;

  /// No description provided for @rolePickerSuffix.
  ///
  /// In en, this message translates to:
  /// **'?'**
  String get rolePickerSuffix;

  /// No description provided for @rolePickerPartnerSection.
  ///
  /// In en, this message translates to:
  /// **'Complete partner profile'**
  String get rolePickerPartnerSection;

  /// No description provided for @rolePickerLearnMore.
  ///
  /// In en, this message translates to:
  /// **'Learn more'**
  String get rolePickerLearnMore;

  /// No description provided for @actionGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get actionGotIt;

  /// No description provided for @rolePickerInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Three roles, one app'**
  String get rolePickerInfoTitle;

  /// No description provided for @roleCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get roleCustomer;

  /// No description provided for @roleCustomerBody.
  ///
  /// In en, this message translates to:
  /// **'Rides, food and daily shopping'**
  String get roleCustomerBody;

  /// No description provided for @roleMerchant.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get roleMerchant;

  /// No description provided for @roleMerchantBody.
  ///
  /// In en, this message translates to:
  /// **'Menu, orders, revenue'**
  String get roleMerchantBody;

  /// No description provided for @roleDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get roleDriver;

  /// No description provided for @roleDriverBody.
  ///
  /// In en, this message translates to:
  /// **'Rides and deliveries'**
  String get roleDriverBody;

  /// No description provided for @rolePartnerDriver.
  ///
  /// In en, this message translates to:
  /// **'Become a driver partner'**
  String get rolePartnerDriver;

  /// No description provided for @rolePartnerShop.
  ///
  /// In en, this message translates to:
  /// **'Become a shop partner'**
  String get rolePartnerShop;

  /// No description provided for @rolePartnerPending.
  ///
  /// In en, this message translates to:
  /// **'Application under review'**
  String get rolePartnerPending;

  /// No description provided for @rolePartnerRejected.
  ///
  /// In en, this message translates to:
  /// **'Application needs more information'**
  String get rolePartnerRejected;

  /// No description provided for @rolePartnerStart.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile to activate this role'**
  String get rolePartnerStart;

  /// No description provided for @onbStep.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String onbStep(int step, int total);

  /// No description provided for @driverActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the status. Please try again.'**
  String get driverActionFailed;

  /// No description provided for @driverActionConflict.
  ///
  /// In en, this message translates to:
  /// **'The status changed on the server. Go back to your jobs to refresh.'**
  String get driverActionConflict;

  /// No description provided for @driverAgreedFare.
  ///
  /// In en, this message translates to:
  /// **'Agreed fare'**
  String get driverAgreedFare;

  /// No description provided for @driverCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect'**
  String get driverCollect;

  /// No description provided for @driverPhasePickup.
  ///
  /// In en, this message translates to:
  /// **'Picking up'**
  String get driverPhasePickup;

  /// No description provided for @driverPhaseWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get driverPhaseWaiting;

  /// No description provided for @driverPhaseOnTrip.
  ///
  /// In en, this message translates to:
  /// **'On trip'**
  String get driverPhaseOnTrip;

  /// No description provided for @driverPhaseDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get driverPhaseDone;

  /// No description provided for @driverItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String driverItemsCount(int count);

  /// No description provided for @driverCodNote.
  ///
  /// In en, this message translates to:
  /// **'COD {amount} is collected for the store.'**
  String driverCodNote(String amount);

  /// No description provided for @actionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get actionSkip;

  /// No description provided for @driverClaimJob.
  ///
  /// In en, this message translates to:
  /// **'Accept job'**
  String get driverClaimJob;

  /// No description provided for @driverClaimFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t accept the job. Please try again.'**
  String get driverClaimFailed;

  /// No description provided for @driverFoodRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get driverFoodRequestTitle;

  /// No description provided for @driverJobInfo.
  ///
  /// In en, this message translates to:
  /// **'Job details'**
  String get driverJobInfo;

  /// No description provided for @driverPickupStore.
  ///
  /// In en, this message translates to:
  /// **'DealGo partner store'**
  String get driverPickupStore;

  /// No description provided for @driverDeliveryStops.
  ///
  /// In en, this message translates to:
  /// **'Pickup and drop-off'**
  String get driverDeliveryStops;

  /// No description provided for @driverPickupPoint.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get driverPickupPoint;

  /// No description provided for @driverDropoffPoint.
  ///
  /// In en, this message translates to:
  /// **'Deliver to customer'**
  String get driverDropoffPoint;

  /// No description provided for @driverFinance.
  ///
  /// In en, this message translates to:
  /// **'Payment details'**
  String get driverFinance;

  /// No description provided for @driverFoodSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Food subtotal'**
  String get driverFoodSubtotal;

  /// No description provided for @driverFoodDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get driverFoodDeliveryFee;

  /// No description provided for @driverFoodFeeCustomerPays.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee paid by customer'**
  String get driverFoodFeeCustomerPays;

  /// No description provided for @driverFoodExpectedIncome.
  ///
  /// In en, this message translates to:
  /// **'Expected driver income'**
  String get driverFoodExpectedIncome;

  /// No description provided for @driverDeliveredTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get driverDeliveredTitle;

  /// No description provided for @driverHeadToStore.
  ///
  /// In en, this message translates to:
  /// **'Head to the store'**
  String get driverHeadToStore;

  /// No description provided for @driverHeadToCustomer.
  ///
  /// In en, this message translates to:
  /// **'Head to drop-off'**
  String get driverHeadToCustomer;

  /// No description provided for @driverFoodNavigateBody.
  ///
  /// In en, this message translates to:
  /// **'Go to the store, then confirm.'**
  String get driverFoodNavigateBody;

  /// No description provided for @driverFoodPhaseWait.
  ///
  /// In en, this message translates to:
  /// **'Waiting for food'**
  String get driverFoodPhaseWait;

  /// No description provided for @driverFoodPhasePicked.
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get driverFoodPhasePicked;

  /// No description provided for @driverFoodPhaseDelivering.
  ///
  /// In en, this message translates to:
  /// **'Delivering'**
  String get driverFoodPhaseDelivering;

  /// No description provided for @driverNearbyRequests.
  ///
  /// In en, this message translates to:
  /// **'Nearby requests'**
  String get driverNearbyRequests;

  /// No description provided for @actionRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get actionRefresh;

  /// No description provided for @driverFindOtherJobs.
  ///
  /// In en, this message translates to:
  /// **'Find other jobs'**
  String get driverFindOtherJobs;

  /// No description provided for @driverJobTakenTitle.
  ///
  /// In en, this message translates to:
  /// **'Request already taken'**
  String get driverJobTakenTitle;

  /// No description provided for @driverJobTakenBody.
  ///
  /// In en, this message translates to:
  /// **'Another driver took this.'**
  String get driverJobTakenBody;

  /// No description provided for @driverOfferNotChosenTitle.
  ///
  /// In en, this message translates to:
  /// **'Your offer was not chosen'**
  String get driverOfferNotChosenTitle;

  /// No description provided for @driverOfferNotChosenBody.
  ///
  /// In en, this message translates to:
  /// **'The customer picked another driver for this order.'**
  String get driverOfferNotChosenBody;

  /// No description provided for @driverJobUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Request no longer available'**
  String get driverJobUnavailable;

  /// No description provided for @driverRequestId.
  ///
  /// In en, this message translates to:
  /// **'Request ID'**
  String get driverRequestId;

  /// No description provided for @driverService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get driverService;

  /// No description provided for @driverServiceFood.
  ///
  /// In en, this message translates to:
  /// **'Food delivery'**
  String get driverServiceFood;

  /// No description provided for @driverOtpMatched.
  ///
  /// In en, this message translates to:
  /// **'Code matches — starting the trip.'**
  String get driverOtpMatched;

  /// No description provided for @driverHeadToPickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup point'**
  String get driverHeadToPickup;

  /// No description provided for @driverFollowRoute.
  ///
  /// In en, this message translates to:
  /// **'Drop-off point'**
  String get driverFollowRoute;

  /// No description provided for @driverPassenger.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get driverPassenger;

  /// No description provided for @driverPickupLabel.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get driverPickupLabel;

  /// No description provided for @driverDropoffLabel.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get driverDropoffLabel;

  /// No description provided for @driverRideNavigateNote.
  ///
  /// In en, this message translates to:
  /// **'Head to pickup.'**
  String get driverRideNavigateNote;

  /// No description provided for @driverCallCustomer.
  ///
  /// In en, this message translates to:
  /// **'Call customer'**
  String get driverCallCustomer;

  /// No description provided for @driverChatCustomer.
  ///
  /// In en, this message translates to:
  /// **'Message customer'**
  String get driverChatCustomer;

  /// No description provided for @rideTrackTitle.
  ///
  /// In en, this message translates to:
  /// **'Track your driver'**
  String get rideTrackTitle;

  /// No description provided for @rideTrackAssigned.
  ///
  /// In en, this message translates to:
  /// **'Driver is on the way'**
  String get rideTrackAssigned;

  /// No description provided for @rideTrackArrived.
  ///
  /// In en, this message translates to:
  /// **'Driver has arrived'**
  String get rideTrackArrived;

  /// No description provided for @rideTrackInTrip.
  ///
  /// In en, this message translates to:
  /// **'On your trip'**
  String get rideTrackInTrip;

  /// No description provided for @rideTrackCompleted.
  ///
  /// In en, this message translates to:
  /// **'Trip completed'**
  String get rideTrackCompleted;

  /// No description provided for @rideTrackNegotiating.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a driver'**
  String get rideTrackNegotiating;

  /// No description provided for @rideTrackExpired.
  ///
  /// In en, this message translates to:
  /// **'Ride expired'**
  String get rideTrackExpired;

  /// No description provided for @rideTrackCancelled.
  ///
  /// In en, this message translates to:
  /// **'Ride cancelled'**
  String get rideTrackCancelled;

  /// No description provided for @rideTrackDriverFallback.
  ///
  /// In en, this message translates to:
  /// **'DealGo driver'**
  String get rideTrackDriverFallback;

  /// No description provided for @foodCancelNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'The shop has already accepted this order, so it can\'t be cancelled. Please contact the shop.'**
  String get foodCancelNotAllowed;

  /// No description provided for @foodCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t cancel the order. Please try again.'**
  String get foodCancelFailed;

  /// No description provided for @foodCancelDone.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled.'**
  String get foodCancelDone;

  /// No description provided for @voucherValid.
  ///
  /// In en, this message translates to:
  /// **'{code} is valid · {amount} off'**
  String voucherValid(String code, String amount);

  /// No description provided for @voucherLabel.
  ///
  /// In en, this message translates to:
  /// **'Promo code'**
  String get voucherLabel;

  /// No description provided for @voucherHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a promo code'**
  String get voucherHint;

  /// No description provided for @voucherApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get voucherApply;

  /// No description provided for @voucherRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove code'**
  String get voucherRemove;

  /// No description provided for @voucherErrEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a promo code'**
  String get voucherErrEmpty;

  /// No description provided for @voucherErrInvalid.
  ///
  /// In en, this message translates to:
  /// **'This promo code isn\'t valid'**
  String get voucherErrInvalid;

  /// No description provided for @voucherErrFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check the code. Please try again.'**
  String get voucherErrFailed;

  /// No description provided for @driverOfflineNote.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline.'**
  String get driverOfflineNote;

  /// No description provided for @vouchersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No vouchers yet'**
  String get vouchersEmptyTitle;

  /// No description provided for @vouchersEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No vouchers yet.'**
  String get vouchersEmptyBody;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get accountNotifications;

  /// No description provided for @accountVouchers.
  ///
  /// In en, this message translates to:
  /// **'My vouchers'**
  String get accountVouchers;

  /// No description provided for @accountVouchersBody.
  ///
  /// In en, this message translates to:
  /// **'Your available promo codes'**
  String get accountVouchersBody;

  /// No description provided for @accountSectionServices.
  ///
  /// In en, this message translates to:
  /// **'Account & services'**
  String get accountSectionServices;

  /// No description provided for @accountActivity.
  ///
  /// In en, this message translates to:
  /// **'My activity'**
  String get accountActivity;

  /// No description provided for @accountActivityBody.
  ///
  /// In en, this message translates to:
  /// **'Trips and orders'**
  String get accountActivityBody;

  /// No description provided for @accountAddresses.
  ///
  /// In en, this message translates to:
  /// **'Saved addresses'**
  String get accountAddresses;

  /// No description provided for @accountAddressesBody.
  ///
  /// In en, this message translates to:
  /// **'Home, work and other places'**
  String get accountAddressesBody;

  /// No description provided for @accountPayments.
  ///
  /// In en, this message translates to:
  /// **'Payment history'**
  String get accountPayments;

  /// No description provided for @accountPaymentsBody.
  ///
  /// In en, this message translates to:
  /// **'Receipts and refunds'**
  String get accountPaymentsBody;

  /// No description provided for @accountRoles.
  ///
  /// In en, this message translates to:
  /// **'Role center'**
  String get accountRoles;

  /// No description provided for @accountSwitchRole.
  ///
  /// In en, this message translates to:
  /// **'Switch role'**
  String get accountSwitchRole;

  /// No description provided for @accountAcceptMode.
  ///
  /// In en, this message translates to:
  /// **'Auto / manual accept'**
  String get accountAcceptMode;

  /// No description provided for @accountAcceptModeBody.
  ///
  /// In en, this message translates to:
  /// **'Choose how new orders are accepted'**
  String get accountAcceptModeBody;

  /// No description provided for @accountHours.
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get accountHours;

  /// No description provided for @accountHoursBody.
  ///
  /// In en, this message translates to:
  /// **'Open and closed schedule'**
  String get accountHoursBody;

  /// No description provided for @accountBusy.
  ///
  /// In en, this message translates to:
  /// **'Busy mode'**
  String get accountBusy;

  /// No description provided for @accountBusyBody.
  ///
  /// In en, this message translates to:
  /// **'Pause new orders'**
  String get accountBusyBody;

  /// No description provided for @accountSectionHelp.
  ///
  /// In en, this message translates to:
  /// **'Help & settings'**
  String get accountSectionHelp;

  /// No description provided for @accountSectionDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get accountSectionDisplay;

  /// No description provided for @accountLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get accountLanguage;

  /// No description provided for @accountTheme.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get accountTheme;

  /// No description provided for @accountThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'Match system'**
  String get accountThemeSystem;

  /// No description provided for @accountThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get accountThemeLight;

  /// No description provided for @accountThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get accountThemeDark;

  /// No description provided for @accountSupport.
  ///
  /// In en, this message translates to:
  /// **'Help center'**
  String get accountSupport;

  /// No description provided for @accountSupportBody.
  ///
  /// In en, this message translates to:
  /// **'FAQs and Messenger chat on the web'**
  String get accountSupportBody;

  /// No description provided for @accountSupportTicketsBody.
  ///
  /// In en, this message translates to:
  /// **'Track the support requests you sent'**
  String get accountSupportTicketsBody;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// No description provided for @accountPartnerHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Earn with DealGo'**
  String get accountPartnerHubTitle;

  /// No description provided for @accountPartnerHubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Become a Driver partner or register a Shop with DealGo'**
  String get accountPartnerHubSubtitle;

  /// No description provided for @accountDriverPartner.
  ///
  /// In en, this message translates to:
  /// **'Driver partner profile'**
  String get accountDriverPartner;

  /// No description provided for @accountShopPartner.
  ///
  /// In en, this message translates to:
  /// **'Shop partner profile'**
  String get accountShopPartner;

  /// No description provided for @partnerStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'Not submitted'**
  String get partnerStatusDraft;

  /// No description provided for @partnerStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get partnerStatusPending;

  /// No description provided for @partnerStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Needs more information'**
  String get partnerStatusRejected;

  /// No description provided for @partnerStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get partnerStatusActive;

  /// No description provided for @partnerActionRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get partnerActionRegister;

  /// No description provided for @partnerActionTrack.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get partnerActionTrack;

  /// No description provided for @partnerActionUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get partnerActionUpdate;

  /// No description provided for @partnerActionView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get partnerActionView;

  /// No description provided for @accountRoleShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get accountRoleShop;

  /// No description provided for @activityEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get activityEmptyTitle;

  /// No description provided for @activityEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No activity yet.'**
  String get activityEmptyBody;

  /// No description provided for @activityRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get activityRecent;

  /// No description provided for @activityOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'May be out of date.'**
  String get activityOfflineBody;

  /// No description provided for @statusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get statusExpired;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get statusRejected;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get statusInProgress;

  /// No description provided for @emptyStoresNearbyBody.
  ///
  /// In en, this message translates to:
  /// **'Check back later.'**
  String get emptyStoresNearbyBody;

  /// No description provided for @notificationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsEmptyTitle;

  /// No description provided for @notificationsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get notificationsEmptyBody;

  /// No description provided for @helpNoResults.
  ///
  /// In en, this message translates to:
  /// **'No articles match this keyword.'**
  String get helpNoResults;

  /// No description provided for @driverOpenRequests.
  ///
  /// In en, this message translates to:
  /// **'Open requests'**
  String get driverOpenRequests;

  /// No description provided for @driverOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get driverOfflineTitle;

  /// No description provided for @driverJobsOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Go online to see requests.'**
  String get driverJobsOfflineBody;

  /// No description provided for @checkoutVoucherRejected.
  ///
  /// In en, this message translates to:
  /// **'This voucher can no longer be used for this order. Remove it or try another code.'**
  String get checkoutVoucherRejected;

  /// No description provided for @checkoutErrOrderOpen.
  ///
  /// In en, this message translates to:
  /// **'You already have a food order in progress.'**
  String get checkoutErrOrderOpen;

  /// No description provided for @checkoutErrItemUnavailable.
  ///
  /// In en, this message translates to:
  /// **'An item just sold out. Please review the menu.'**
  String get checkoutErrItemUnavailable;

  /// No description provided for @checkoutErrFareRange.
  ///
  /// In en, this message translates to:
  /// **'The delivery fee is outside the allowed range.'**
  String get checkoutErrFareRange;

  /// No description provided for @checkoutErrStoreNotFound.
  ///
  /// In en, this message translates to:
  /// **'Store not found.'**
  String get checkoutErrStoreNotFound;

  /// No description provided for @checkoutErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the order. Your cart is still on this device.'**
  String get checkoutErrGeneric;

  /// No description provided for @checkoutMenuChangedEmpty.
  ///
  /// In en, this message translates to:
  /// **'The menu changed and none of your items are left.'**
  String get checkoutMenuChangedEmpty;

  /// No description provided for @checkoutTitleSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Confirming order'**
  String get checkoutTitleSubmitting;

  /// No description provided for @checkoutTitleOffline.
  ///
  /// In en, this message translates to:
  /// **'Order payment'**
  String get checkoutTitleOffline;

  /// No description provided for @checkoutTitleRepriced.
  ///
  /// In en, this message translates to:
  /// **'Review your cart again'**
  String get checkoutTitleRepriced;

  /// No description provided for @checkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Food checkout'**
  String get checkoutTitle;

  /// No description provided for @checkoutBackToCart.
  ///
  /// In en, this message translates to:
  /// **'Back to cart'**
  String get checkoutBackToCart;

  /// No description provided for @checkoutRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get checkoutRetry;

  /// No description provided for @checkoutBackToCartShort.
  ///
  /// In en, this message translates to:
  /// **'Back to cart'**
  String get checkoutBackToCartShort;

  /// No description provided for @checkoutRecipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get checkoutRecipient;

  /// No description provided for @checkoutRecipientAddress.
  ///
  /// In en, this message translates to:
  /// **'Recipient and address'**
  String get checkoutRecipientAddress;

  /// No description provided for @checkoutYourOrder.
  ///
  /// In en, this message translates to:
  /// **'Your order'**
  String get checkoutYourOrder;

  /// No description provided for @checkoutEtaChip.
  ///
  /// In en, this message translates to:
  /// **'~{minutes} min delivery'**
  String checkoutEtaChip(int minutes);

  /// No description provided for @checkoutItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String checkoutItemCount(int count);

  /// No description provided for @checkoutYouSave.
  ///
  /// In en, this message translates to:
  /// **'Save {amount}'**
  String checkoutYouSave(String amount);

  /// No description provided for @checkoutItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get checkoutItems;

  /// No description provided for @checkoutTotalSection.
  ///
  /// In en, this message translates to:
  /// **'Payment summary'**
  String get checkoutTotalSection;

  /// No description provided for @checkoutSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get checkoutSubtotal;

  /// No description provided for @checkoutDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get checkoutDeliveryFee;

  /// No description provided for @checkoutDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get checkoutDiscount;

  /// No description provided for @checkoutCodTotal.
  ///
  /// In en, this message translates to:
  /// **'Total due'**
  String get checkoutCodTotal;

  /// No description provided for @checkoutPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get checkoutPayment;

  /// No description provided for @checkoutCodUncollected.
  ///
  /// In en, this message translates to:
  /// **'Cash · Not paid yet'**
  String get checkoutCodUncollected;

  /// No description provided for @checkoutPlacedNote.
  ///
  /// In en, this message translates to:
  /// **'Pay cash on delivery.'**
  String get checkoutPlacedNote;

  /// No description provided for @checkoutPayLaterNote.
  ///
  /// In en, this message translates to:
  /// **'Pay cash on delivery.'**
  String get checkoutPayLaterNote;

  /// No description provided for @checkoutProcessingTitle.
  ///
  /// In en, this message translates to:
  /// **'Processing your order'**
  String get checkoutProcessingTitle;

  /// No description provided for @checkoutProcessingBody.
  ///
  /// In en, this message translates to:
  /// **'Confirming — don\'t reorder.'**
  String get checkoutProcessingBody;

  /// No description provided for @checkoutPendingRequest.
  ///
  /// In en, this message translates to:
  /// **'Pending request'**
  String get checkoutPendingRequest;

  /// No description provided for @checkoutCartRef.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get checkoutCartRef;

  /// No description provided for @checkoutExpectedAmount.
  ///
  /// In en, this message translates to:
  /// **'Expected amount'**
  String get checkoutExpectedAmount;

  /// No description provided for @checkoutOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get checkoutOfflineTitle;

  /// No description provided for @checkoutOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send. Cart is kept.'**
  String get checkoutOfflineBody;

  /// No description provided for @checkoutUnsentCart.
  ///
  /// In en, this message translates to:
  /// **'Unsent cart'**
  String get checkoutUnsentCart;

  /// No description provided for @checkoutExpectedTotal.
  ///
  /// In en, this message translates to:
  /// **'Expected total'**
  String get checkoutExpectedTotal;

  /// No description provided for @checkoutCodShort.
  ///
  /// In en, this message translates to:
  /// **'Cash · Unpaid'**
  String get checkoutCodShort;

  /// No description provided for @checkoutRepricedTitle.
  ///
  /// In en, this message translates to:
  /// **'Price changed'**
  String get checkoutRepricedTitle;

  /// No description provided for @checkoutRepricedBody.
  ///
  /// In en, this message translates to:
  /// **'Please confirm the new total.'**
  String get checkoutRepricedBody;

  /// No description provided for @checkoutCompare.
  ///
  /// In en, this message translates to:
  /// **'What changed'**
  String get checkoutCompare;

  /// No description provided for @checkoutPreviousTotal.
  ///
  /// In en, this message translates to:
  /// **'Previous total'**
  String get checkoutPreviousTotal;

  /// No description provided for @checkoutDeliveryIncrease.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee increase'**
  String get checkoutDeliveryIncrease;

  /// No description provided for @checkoutNewTotal.
  ///
  /// In en, this message translates to:
  /// **'New total'**
  String get checkoutNewTotal;

  /// No description provided for @checkoutRepricedDraftNote.
  ///
  /// In en, this message translates to:
  /// **'Order is placed only after you accept.'**
  String get checkoutRepricedDraftNote;

  /// No description provided for @checkoutRepricedPlacedNote.
  ///
  /// In en, this message translates to:
  /// **'Placed at new price. Pay cash on delivery.'**
  String get checkoutRepricedPlacedNote;

  /// No description provided for @checkoutAcceptTotal.
  ///
  /// In en, this message translates to:
  /// **'Accept {amount}'**
  String checkoutAcceptTotal(String amount);

  /// No description provided for @checkoutPlaceTotal.
  ///
  /// In en, this message translates to:
  /// **'Place order · {amount}'**
  String checkoutPlaceTotal(String amount);

  /// No description provided for @inboxRideAssignedTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver found'**
  String get inboxRideAssignedTitle;

  /// No description provided for @inboxRideAssignedBody.
  ///
  /// In en, this message translates to:
  /// **'Your driver is getting ready to come to the pickup point.'**
  String get inboxRideAssignedBody;

  /// No description provided for @inboxRideDriverEnRouteTitle.
  ///
  /// In en, this message translates to:
  /// **'Your driver is on the way'**
  String get inboxRideDriverEnRouteTitle;

  /// No description provided for @inboxRideDriverEnRouteBody.
  ///
  /// In en, this message translates to:
  /// **'Your driver is heading to the pickup point.'**
  String get inboxRideDriverEnRouteBody;

  /// No description provided for @inboxRideDriverArrivedTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver arrived'**
  String get inboxRideDriverArrivedTitle;

  /// No description provided for @inboxRideDriverArrivedBody.
  ///
  /// In en, this message translates to:
  /// **'Go to the pickup point and tell the driver your code.'**
  String get inboxRideDriverArrivedBody;

  /// No description provided for @inboxRideInTripTitle.
  ///
  /// In en, this message translates to:
  /// **'Your trip has started'**
  String get inboxRideInTripTitle;

  /// No description provided for @inboxRideInTripBody.
  ///
  /// In en, this message translates to:
  /// **'Have a safe trip.'**
  String get inboxRideInTripBody;

  /// No description provided for @inboxRideCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip completed'**
  String get inboxRideCompletedTitle;

  /// No description provided for @inboxRideCompletedBody.
  ///
  /// In en, this message translates to:
  /// **'Thanks for riding with DealGo.'**
  String get inboxRideCompletedBody;

  /// No description provided for @inboxRideCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride cancelled'**
  String get inboxRideCancelledTitle;

  /// No description provided for @inboxRideCancelledBody.
  ///
  /// In en, this message translates to:
  /// **'The ride was cancelled.'**
  String get inboxRideCancelledBody;

  /// No description provided for @inboxRideExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Request expired'**
  String get inboxRideExpiredTitle;

  /// No description provided for @inboxRideExpiredBody.
  ///
  /// In en, this message translates to:
  /// **'No driver accepted.'**
  String get inboxRideExpiredBody;

  /// No description provided for @inboxFoodPreparingTitle.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get inboxFoodPreparingTitle;

  /// No description provided for @inboxFoodPreparingBody.
  ///
  /// In en, this message translates to:
  /// **'The store confirmed your order.'**
  String get inboxFoodPreparingBody;

  /// No description provided for @inboxFoodReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your food is ready'**
  String get inboxFoodReadyTitle;

  /// No description provided for @inboxFoodReadyBody.
  ///
  /// In en, this message translates to:
  /// **'Finding a driver to deliver it.'**
  String get inboxFoodReadyBody;

  /// No description provided for @inboxFoodAssignedTitle.
  ///
  /// In en, this message translates to:
  /// **'A driver took your order'**
  String get inboxFoodAssignedTitle;

  /// No description provided for @inboxFoodAssignedBody.
  ///
  /// In en, this message translates to:
  /// **'The driver is heading to the store.'**
  String get inboxFoodAssignedBody;

  /// No description provided for @inboxFoodPickedUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Your food was picked up'**
  String get inboxFoodPickedUpTitle;

  /// No description provided for @inboxFoodPickedUpBody.
  ///
  /// In en, this message translates to:
  /// **'Your order is on its way.'**
  String get inboxFoodPickedUpBody;

  /// No description provided for @inboxFoodDeliveredTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get inboxFoodDeliveredTitle;

  /// No description provided for @inboxFoodDeliveredBody.
  ///
  /// In en, this message translates to:
  /// **'Enjoy your meal.'**
  String get inboxFoodDeliveredBody;

  /// No description provided for @inboxFoodFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery failed'**
  String get inboxFoodFailedTitle;

  /// No description provided for @inboxFoodFailedBody.
  ///
  /// In en, this message translates to:
  /// **'The order could not be delivered. Contact support if needed.'**
  String get inboxFoodFailedBody;

  /// No description provided for @inboxFoodCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled'**
  String get inboxFoodCancelledTitle;

  /// No description provided for @inboxFoodCancelledBody.
  ///
  /// In en, this message translates to:
  /// **'The food order was cancelled.'**
  String get inboxFoodCancelledBody;

  /// No description provided for @inboxMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get inboxMarkAllRead;

  /// No description provided for @inboxSectionToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get inboxSectionToday;

  /// No description provided for @inboxSectionYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get inboxSectionYesterday;

  /// No description provided for @inboxSectionEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get inboxSectionEarlier;

  /// No description provided for @inboxFilterPromos.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get inboxFilterPromos;

  /// No description provided for @inboxUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get inboxUnread;

  /// No description provided for @inboxUnreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count} unread notifications'**
  String inboxUnreadCount(int count);

  /// No description provided for @inboxLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading notifications'**
  String get inboxLoading;

  /// No description provided for @inboxJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get inboxJustNow;

  /// No description provided for @inboxMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String inboxMinutesAgo(int count);

  /// No description provided for @inboxHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String inboxHoursAgo(int count);

  /// No description provided for @addrBookTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved addresses'**
  String get addrBookTitle;

  /// No description provided for @addrBookAdd.
  ///
  /// In en, this message translates to:
  /// **'Add address'**
  String get addrBookAdd;

  /// No description provided for @addrBookAddTitle.
  ///
  /// In en, this message translates to:
  /// **'New address'**
  String get addrBookAddTitle;

  /// No description provided for @addrBookEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit address'**
  String get addrBookEditTitle;

  /// No description provided for @addrBookFull.
  ///
  /// In en, this message translates to:
  /// **'You have saved the maximum of 20 addresses. Delete one to add another.'**
  String get addrBookFull;

  /// No description provided for @addrBookLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading addresses'**
  String get addrBookLoading;

  /// No description provided for @addrBookEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No saved addresses yet'**
  String get addrBookEmptyTitle;

  /// No description provided for @addrBookEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Save places to book faster.'**
  String get addrBookEmptyBody;

  /// No description provided for @addrBookDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get addrBookDefault;

  /// No description provided for @addrBookNoPin.
  ///
  /// In en, this message translates to:
  /// **'No map pin yet'**
  String get addrBookNoPin;

  /// No description provided for @addrBookPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned to your current location'**
  String get addrBookPinned;

  /// No description provided for @addrBookPinHere.
  ///
  /// In en, this message translates to:
  /// **'Pin current location'**
  String get addrBookPinHere;

  /// No description provided for @addrBookLocating.
  ///
  /// In en, this message translates to:
  /// **'Locating…'**
  String get addrBookLocating;

  /// No description provided for @addrBookPinFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not get your location. Allow location access and try again.'**
  String get addrBookPinFailed;

  /// No description provided for @addrBookMore.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get addrBookMore;

  /// No description provided for @addrBookEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get addrBookEdit;

  /// No description provided for @addrBookMakeDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get addrBookMakeDefault;

  /// No description provided for @addrBookDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get addrBookDelete;

  /// No description provided for @addrBookCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get addrBookCancel;

  /// No description provided for @addrBookDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete address?'**
  String get addrBookDeleteTitle;

  /// No description provided for @addrBookDeleted.
  ///
  /// In en, this message translates to:
  /// **'Address deleted'**
  String get addrBookDeleted;

  /// No description provided for @addrBookSaved.
  ///
  /// In en, this message translates to:
  /// **'Address saved'**
  String get addrBookSaved;

  /// No description provided for @addrBookKindHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get addrBookKindHome;

  /// No description provided for @addrBookKindWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get addrBookKindWork;

  /// No description provided for @addrBookKindOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get addrBookKindOther;

  /// No description provided for @addrBookLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get addrBookLabel;

  /// No description provided for @addrBookLabelRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get addrBookLabelRequired;

  /// No description provided for @addrBookLine.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addrBookLine;

  /// No description provided for @addrBookLineHint.
  ///
  /// In en, this message translates to:
  /// **'Street number, street, ward/district'**
  String get addrBookLineHint;

  /// No description provided for @addrBookLineRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an address (at least 3 characters)'**
  String get addrBookLineRequired;

  /// No description provided for @addrBookNote.
  ///
  /// In en, this message translates to:
  /// **'Note for driver'**
  String get addrBookNote;

  /// No description provided for @addrBookSave.
  ///
  /// In en, this message translates to:
  /// **'Save address'**
  String get addrBookSave;

  /// No description provided for @addrBookErrKindTaken.
  ///
  /// In en, this message translates to:
  /// **'You already saved this type. Choose \"Other\" or edit the existing one.'**
  String get addrBookErrKindTaken;

  /// No description provided for @addrBookErrNotFound.
  ///
  /// In en, this message translates to:
  /// **'This address no longer exists. The list was refreshed.'**
  String get addrBookErrNotFound;

  /// No description provided for @addrBookErrOffline.
  ///
  /// In en, this message translates to:
  /// **'No connection. Try again later.'**
  String get addrBookErrOffline;

  /// No description provided for @addrBookErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Try again later.'**
  String get addrBookErrGeneric;

  /// No description provided for @addrBookDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{label}\"?'**
  String addrBookDeleteBody(String label);

  /// No description provided for @rateRidePrompt.
  ///
  /// In en, this message translates to:
  /// **'How was your trip?'**
  String get rateRidePrompt;

  /// No description provided for @rateOrderPrompt.
  ///
  /// In en, this message translates to:
  /// **'How was your order?'**
  String get rateOrderPrompt;

  /// No description provided for @rateWhy.
  ///
  /// In en, this message translates to:
  /// **'Ratings help DealGo keep drivers and stores at their best.'**
  String get rateWhy;

  /// No description provided for @rateRideAction.
  ///
  /// In en, this message translates to:
  /// **'Rate this trip'**
  String get rateRideAction;

  /// No description provided for @rateOrderAction.
  ///
  /// In en, this message translates to:
  /// **'Rate this order'**
  String get rateOrderAction;

  /// No description provided for @rateRideTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate your trip'**
  String get rateRideTitle;

  /// No description provided for @rateOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate your order'**
  String get rateOrderTitle;

  /// No description provided for @rateDriverLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get rateDriverLabel;

  /// No description provided for @rateStoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get rateStoreLabel;

  /// No description provided for @rateTagsLabel.
  ///
  /// In en, this message translates to:
  /// **'What stood out'**
  String get rateTagsLabel;

  /// No description provided for @rateCommentLabel.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get rateCommentLabel;

  /// No description provided for @rateCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your experience'**
  String get rateCommentHint;

  /// No description provided for @rateSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit rating'**
  String get rateSubmit;

  /// No description provided for @rateThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks for your rating!'**
  String get rateThanks;

  /// No description provided for @rateErrAlready.
  ///
  /// In en, this message translates to:
  /// **'You have already rated this.'**
  String get rateErrAlready;

  /// No description provided for @rateErrNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'You can rate only after the trip or order is finished.'**
  String get rateErrNotAllowed;

  /// No description provided for @rateErrOffline.
  ///
  /// In en, this message translates to:
  /// **'No connection. Try again later.'**
  String get rateErrOffline;

  /// No description provided for @rateErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not send your rating. Try again later.'**
  String get rateErrGeneric;

  /// No description provided for @rateTagOnTime.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get rateTagOnTime;

  /// No description provided for @rateTagFriendly.
  ///
  /// In en, this message translates to:
  /// **'Friendly'**
  String get rateTagFriendly;

  /// No description provided for @rateTagSafeDriving.
  ///
  /// In en, this message translates to:
  /// **'Safe driving'**
  String get rateTagSafeDriving;

  /// No description provided for @rateTagCleanVehicle.
  ///
  /// In en, this message translates to:
  /// **'Clean vehicle'**
  String get rateTagCleanVehicle;

  /// No description provided for @rateTagTastyFood.
  ///
  /// In en, this message translates to:
  /// **'Tasty food'**
  String get rateTagTastyFood;

  /// No description provided for @rateTagWellPacked.
  ///
  /// In en, this message translates to:
  /// **'Well packed'**
  String get rateTagWellPacked;

  /// No description provided for @rateTagLate.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get rateTagLate;

  /// No description provided for @rateTagRude.
  ///
  /// In en, this message translates to:
  /// **'Impolite'**
  String get rateTagRude;

  /// No description provided for @rateTagUnsafeDriving.
  ///
  /// In en, this message translates to:
  /// **'Unsafe driving'**
  String get rateTagUnsafeDriving;

  /// No description provided for @rateTagWrongItems.
  ///
  /// In en, this message translates to:
  /// **'Wrong items'**
  String get rateTagWrongItems;

  /// No description provided for @rateTagColdFood.
  ///
  /// In en, this message translates to:
  /// **'Food was cold'**
  String get rateTagColdFood;

  /// No description provided for @rateDone.
  ///
  /// In en, this message translates to:
  /// **'You rated {stars} stars. Thank you!'**
  String rateDone(int stars);

  /// No description provided for @rateStarTooltip.
  ///
  /// In en, this message translates to:
  /// **'{star} stars'**
  String rateStarTooltip(int star);

  /// No description provided for @drvHistTitle.
  ///
  /// In en, this message translates to:
  /// **'Earnings & history'**
  String get drvHistTitle;

  /// No description provided for @drvHistToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get drvHistToday;

  /// No description provided for @drvHistWeek.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get drvHistWeek;

  /// No description provided for @drvHistEarnedToday.
  ///
  /// In en, this message translates to:
  /// **'Earned today'**
  String get drvHistEarnedToday;

  /// No description provided for @drvHistEarnedWeek.
  ///
  /// In en, this message translates to:
  /// **'Earned in 7 days'**
  String get drvHistEarnedWeek;

  /// No description provided for @drvHistRides.
  ///
  /// In en, this message translates to:
  /// **'Rides'**
  String get drvHistRides;

  /// No description provided for @drvHistFood.
  ///
  /// In en, this message translates to:
  /// **'Food delivery'**
  String get drvHistFood;

  /// No description provided for @drvHistRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get drvHistRating;

  /// No description provided for @drvHistNoRating.
  ///
  /// In en, this message translates to:
  /// **'No ratings yet'**
  String get drvHistNoRating;

  /// No description provided for @drvHistRecent.
  ///
  /// In en, this message translates to:
  /// **'Job history'**
  String get drvHistRecent;

  /// No description provided for @drvHistFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get drvHistFilterAll;

  /// No description provided for @drvHistEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No jobs yet'**
  String get drvHistEmptyTitle;

  /// No description provided for @drvHistEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No jobs yet.'**
  String get drvHistEmptyBody;

  /// No description provided for @drvHistLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get drvHistLoadMore;

  /// No description provided for @drvHistLoadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more. Retry'**
  String get drvHistLoadMoreFailed;

  /// No description provided for @drvHistOutcomeCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get drvHistOutcomeCancelled;

  /// No description provided for @drvHistOutcomeFailed.
  ///
  /// In en, this message translates to:
  /// **'Delivery failed'**
  String get drvHistOutcomeFailed;

  /// No description provided for @drvHistLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading history'**
  String get drvHistLoading;

  /// No description provided for @drvHistJobs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 job} other{{count} jobs}}'**
  String drvHistJobs(int count);

  /// No description provided for @drvHistCancelled.
  ///
  /// In en, this message translates to:
  /// **'{count} cancelled'**
  String drvHistCancelled(int count);

  /// No description provided for @drvHistStars.
  ///
  /// In en, this message translates to:
  /// **'{stars}/5 stars'**
  String drvHistStars(int stars);

  /// No description provided for @drvHistRatingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 rating} other{{count} ratings}}'**
  String drvHistRatingCount(int count);

  /// No description provided for @drvHistGrossLine.
  ///
  /// In en, this message translates to:
  /// **'Gross fares {gross} · DealGo commission −{fee}'**
  String drvHistGrossLine(String gross, String fee);

  /// No description provided for @drvHistItemFee.
  ///
  /// In en, this message translates to:
  /// **'Commission {percent}% −{fee}'**
  String drvHistItemFee(String percent, String fee);

  /// No description provided for @drvHistItemFeeFood.
  ///
  /// In en, this message translates to:
  /// **'Commission {percent}% of delivery fee −{fee}'**
  String drvHistItemFeeFood(String percent, String fee);

  /// No description provided for @rateDeadline.
  ///
  /// In en, this message translates to:
  /// **'You can rate until {date}.'**
  String rateDeadline(String date);

  /// No description provided for @rateErrExpired.
  ///
  /// In en, this message translates to:
  /// **'The rating window for this trip/order has closed.'**
  String get rateErrExpired;

  /// No description provided for @placePickerPickupTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose pickup'**
  String get placePickerPickupTitle;

  /// No description provided for @placePickerDropoffTitle.
  ///
  /// In en, this message translates to:
  /// **'Where to?'**
  String get placePickerDropoffTitle;

  /// No description provided for @placePickerDeliveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery address'**
  String get placePickerDeliveryTitle;

  /// No description provided for @placePickerHint.
  ///
  /// In en, this message translates to:
  /// **'Search places or addresses'**
  String get placePickerHint;

  /// No description provided for @placeCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Your current location'**
  String get placeCurrentLocation;

  /// No description provided for @placeCurrentLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Use your phone\'s GPS'**
  String get placeCurrentLocationHint;

  /// No description provided for @placeLocating.
  ///
  /// In en, this message translates to:
  /// **'Getting your location…'**
  String get placeLocating;

  /// No description provided for @placeLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location access is off. Turn it on in Settings or pick another address.'**
  String get placeLocationDenied;

  /// No description provided for @placeLocationFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get your location. Please try again.'**
  String get placeLocationFailed;

  /// No description provided for @placeCurrentNamed.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get placeCurrentNamed;

  /// No description provided for @placeSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved addresses'**
  String get placeSavedTitle;

  /// No description provided for @placeSavedManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get placeSavedManage;

  /// No description provided for @placeResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Search results'**
  String get placeResultsTitle;

  /// No description provided for @placeSearchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get placeSearchEmptyTitle;

  /// No description provided for @placeSearchEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Try another search.'**
  String get placeSearchEmptyBody;

  /// No description provided for @placeSearchUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Place search is unavailable right now. Use your current location or a saved address.'**
  String get placeSearchUnavailable;

  /// No description provided for @placeSearchError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load search results.'**
  String get placeSearchError;

  /// No description provided for @placeNothingYet.
  ///
  /// In en, this message translates to:
  /// **'Search for a place or use your current location to start.'**
  String get placeNothingYet;

  /// No description provided for @placeHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get placeHistoryTitle;

  /// No description provided for @placeHistoryClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get placeHistoryClear;

  /// No description provided for @placeHistoryDelete.
  ///
  /// In en, this message translates to:
  /// **'Remove from history'**
  String get placeHistoryDelete;

  /// No description provided for @placeHistoryClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear search history?'**
  String get placeHistoryClearTitle;

  /// No description provided for @placeHistoryClearBody.
  ///
  /// In en, this message translates to:
  /// **'Clear place history?'**
  String get placeHistoryClearBody;

  /// No description provided for @placeHistoryClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get placeHistoryClearConfirm;

  /// No description provided for @placeApproximate.
  ///
  /// In en, this message translates to:
  /// **'Approximate house number · check the pin'**
  String get placeApproximate;

  /// No description provided for @placeDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String placeDistanceKm(String km);

  /// No description provided for @rideBookTitle.
  ///
  /// In en, this message translates to:
  /// **'Book a ride'**
  String get rideBookTitle;

  /// No description provided for @mapRecenter.
  ///
  /// In en, this message translates to:
  /// **'Recenter on me'**
  String get mapRecenter;

  /// No description provided for @rideWhereTo.
  ///
  /// In en, this message translates to:
  /// **'Where to?'**
  String get rideWhereTo;

  /// No description provided for @ridePickupPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Choose pickup'**
  String get ridePickupPlaceholder;

  /// No description provided for @rideDropoffPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Choose destination'**
  String get rideDropoffPlaceholder;

  /// No description provided for @rideSuggestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggested for you'**
  String get rideSuggestionsTitle;

  /// No description provided for @rideOpenPendingOffers.
  ///
  /// In en, this message translates to:
  /// **'View pending offers'**
  String get rideOpenPendingOffers;

  /// No description provided for @rideSamePlaces.
  ///
  /// In en, this message translates to:
  /// **'Pickup and destination are the same.'**
  String get rideSamePlaces;

  /// No description provided for @rideEtaMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String rideEtaMinutes(int minutes);

  /// No description provided for @rideDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String rideDistanceKm(String km);

  /// No description provided for @rideQuoteLoading.
  ///
  /// In en, this message translates to:
  /// **'Calculating the reference fare…'**
  String get rideQuoteLoading;

  /// No description provided for @rideQuoteError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get a fare. Check your connection and try again.'**
  String get rideQuoteError;

  /// No description provided for @rideFareRange.
  ///
  /// In en, this message translates to:
  /// **'Allowed from {min} to {max}'**
  String rideFareRange(String min, String max);

  /// No description provided for @rideFareInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount.'**
  String get rideFareInvalid;

  /// No description provided for @rideFareAllowedRange.
  ///
  /// In en, this message translates to:
  /// **'Allowed range'**
  String get rideFareAllowedRange;

  /// No description provided for @rideVehicleBikeTitle.
  ///
  /// In en, this message translates to:
  /// **'Motorbike'**
  String get rideVehicleBikeTitle;

  /// No description provided for @rideVehicleCar4Title.
  ///
  /// In en, this message translates to:
  /// **'4-seat car'**
  String get rideVehicleCar4Title;

  /// No description provided for @rideVehicleCar7Title.
  ///
  /// In en, this message translates to:
  /// **'7-seat car'**
  String get rideVehicleCar7Title;

  /// No description provided for @rideVehicleSeats.
  ///
  /// In en, this message translates to:
  /// **'{count} seats'**
  String rideVehicleSeats(int count);

  /// No description provided for @rideFareOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening fare'**
  String get rideFareOpening;

  /// No description provided for @rideFarePerKm.
  ///
  /// In en, this message translates to:
  /// **'Per kilometre'**
  String get rideFarePerKm;

  /// No description provided for @rideFareTime.
  ///
  /// In en, this message translates to:
  /// **'Time ({minutes} min)'**
  String rideFareTime(int minutes);

  /// No description provided for @rideVehicleBikeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quick · 1 passenger'**
  String get rideVehicleBikeSubtitle;

  /// No description provided for @rideVehicleFrom.
  ///
  /// In en, this message translates to:
  /// **'From {amount}'**
  String rideVehicleFrom(String amount);

  /// No description provided for @rideVehicleTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a vehicle'**
  String get rideVehicleTitle;

  /// No description provided for @rideVehicleRouteTitle.
  ///
  /// In en, this message translates to:
  /// **'Your route'**
  String get rideVehicleRouteTitle;

  /// No description provided for @rideVehicleContinueToOffer.
  ///
  /// In en, this message translates to:
  /// **'Propose your fare'**
  String get rideVehicleContinueToOffer;

  /// No description provided for @rideVehicleClassesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No vehicle classes are available right now. Pull to refresh or try again shortly.'**
  String get rideVehicleClassesUnavailable;

  /// No description provided for @homeQuickBookTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick ride'**
  String get homeQuickBookTitle;

  /// No description provided for @homeQuickBookPickup.
  ///
  /// In en, this message translates to:
  /// **'123 Nguyen Van Linh, Hai Chau, Da Nang'**
  String get homeQuickBookPickup;

  /// No description provided for @homeQuickBookVehicle.
  ///
  /// In en, this message translates to:
  /// **'Bike & Car'**
  String get homeQuickBookVehicle;

  /// No description provided for @homeQuickBookEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimate'**
  String get homeQuickBookEstimate;

  /// No description provided for @homeQuickBookEtaPrice.
  ///
  /// In en, this message translates to:
  /// **'After places'**
  String get homeQuickBookEtaPrice;

  /// No description provided for @homeQuickBookEtaTime.
  ///
  /// In en, this message translates to:
  /// **'Time ~ 12 min'**
  String get homeQuickBookEtaTime;

  /// No description provided for @foodCartTitle.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get foodCartTitle;

  /// No description provided for @foodCartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get foodCartEmpty;

  /// No description provided for @foodCartEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimated payment'**
  String get foodCartEstimate;

  /// No description provided for @foodCartContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue to checkout'**
  String get foodCartContinue;

  /// No description provided for @foodDropoffTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery address'**
  String get foodDropoffTitle;

  /// No description provided for @foodDropoffChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a delivery address'**
  String get foodDropoffChoose;

  /// No description provided for @foodDropoffChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get foodDropoffChange;

  /// No description provided for @foodFareNeedAddress.
  ///
  /// In en, this message translates to:
  /// **'Pick an address first'**
  String get foodFareNeedAddress;

  /// No description provided for @foodFareQuoting.
  ///
  /// In en, this message translates to:
  /// **'Calculating…'**
  String get foodFareQuoting;

  /// No description provided for @foodFareQuoteError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get the delivery fee. Check your connection and try again.'**
  String get foodFareQuoteError;

  /// No description provided for @foodOrderNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note for the store / driver'**
  String get foodOrderNoteLabel;

  /// No description provided for @foodOrderNoteHint.
  ///
  /// In en, this message translates to:
  /// **'E.g. less spicy, no onion, leave at the door…'**
  String get foodOrderNoteHint;

  /// No description provided for @foodLineNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note for this dish'**
  String get foodLineNoteLabel;

  /// No description provided for @foodLineNoteHint.
  ///
  /// In en, this message translates to:
  /// **'E.g. less ice, no sugar…'**
  String get foodLineNoteHint;

  /// No description provided for @foodUtensilsLabel.
  ///
  /// In en, this message translates to:
  /// **'Cutlery'**
  String get foodUtensilsLabel;

  /// No description provided for @foodUtensilsYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get foodUtensilsYes;

  /// No description provided for @foodUtensilsNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get foodUtensilsNo;

  /// No description provided for @foodCartUpsellTitle.
  ///
  /// In en, this message translates to:
  /// **'Add more to your meal'**
  String get foodCartUpsellTitle;

  /// No description provided for @foodNoteSaved.
  ///
  /// In en, this message translates to:
  /// **'Note saved'**
  String get foodNoteSaved;

  /// No description provided for @foodNoteCleared.
  ///
  /// In en, this message translates to:
  /// **'Note cleared'**
  String get foodNoteCleared;

  /// No description provided for @foodCheckoutExtrasTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes & cutlery'**
  String get foodCheckoutExtrasTitle;

  /// No description provided for @foodCheckoutNoteEmpty.
  ///
  /// In en, this message translates to:
  /// **'No note for the store or driver yet'**
  String get foodCheckoutNoteEmpty;

  /// No description provided for @foodCheckoutNoteAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get foodCheckoutNoteAdd;

  /// No description provided for @foodCheckoutNoteEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get foodCheckoutNoteEdit;

  /// No description provided for @foodFareFixedLabel.
  ///
  /// In en, this message translates to:
  /// **'Fixed delivery fee'**
  String get foodFareFixedLabel;

  /// No description provided for @foodFareFixedHint.
  ///
  /// In en, this message translates to:
  /// **'DealGo sets this fee for the distance; it is not negotiable.'**
  String get foodFareFixedHint;

  /// No description provided for @foodFareNegotiationHint.
  ///
  /// In en, this message translates to:
  /// **'The driver can accept this amount or counter with a higher fee.'**
  String get foodFareNegotiationHint;

  /// No description provided for @foodLineNoteClear.
  ///
  /// In en, this message translates to:
  /// **'Clear note'**
  String get foodLineNoteClear;

  /// No description provided for @foodCartLineRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove item'**
  String get foodCartLineRemove;

  /// No description provided for @driverOtpLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong codes. Contact support to continue this ride.'**
  String get driverOtpLocked;

  /// No description provided for @ridePickupCodeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your pickup code appears once a driver accepts the ride.'**
  String get ridePickupCodeUnavailable;

  /// No description provided for @driverCardRating.
  ///
  /// In en, this message translates to:
  /// **'{rating} · {count} ratings'**
  String driverCardRating(String rating, int count);

  /// No description provided for @driverCardNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get driverCardNew;

  /// No description provided for @driverDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get driverDetailTitle;

  /// No description provided for @driverDetailOpen.
  ///
  /// In en, this message translates to:
  /// **'View driver details'**
  String get driverDetailOpen;

  /// No description provided for @driverDetailVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get driverDetailVehicle;

  /// No description provided for @driverDetailPlate.
  ///
  /// In en, this message translates to:
  /// **'Licence plate'**
  String get driverDetailPlate;

  /// No description provided for @driverDetailClass.
  ///
  /// In en, this message translates to:
  /// **'Vehicle type'**
  String get driverDetailClass;

  /// No description provided for @driverAvatarOpen.
  ///
  /// In en, this message translates to:
  /// **'View profile photo'**
  String get driverAvatarOpen;

  /// No description provided for @driverAvatarClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get driverAvatarClose;

  /// No description provided for @driverCardTrips.
  ///
  /// In en, this message translates to:
  /// **'{count} trips'**
  String driverCardTrips(String count);

  /// No description provided for @actionReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get actionReload;

  /// No description provided for @rideAgreedFare.
  ///
  /// In en, this message translates to:
  /// **'Agreed fare'**
  String get rideAgreedFare;

  /// No description provided for @rideVehicleLabel.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get rideVehicleLabel;

  /// No description provided for @rideViewReceipt.
  ///
  /// In en, this message translates to:
  /// **'View receipt'**
  String get rideViewReceipt;

  /// No description provided for @rideOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get rideOfflineTitle;

  /// No description provided for @rideOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Showing last known data.'**
  String get rideOfflineBody;

  /// No description provided for @rideTripSummary.
  ///
  /// In en, this message translates to:
  /// **'Trip summary'**
  String get rideTripSummary;

  /// No description provided for @rideSelectOfferAmount.
  ///
  /// In en, this message translates to:
  /// **'Choose {amount}'**
  String rideSelectOfferAmount(String amount);

  /// No description provided for @rideSelectOfferPrompt.
  ///
  /// In en, this message translates to:
  /// **'Choose an offer'**
  String get rideSelectOfferPrompt;

  /// No description provided for @rideReceiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip receipt'**
  String get rideReceiptTitle;

  /// No description provided for @rideReceiptHelp.
  ///
  /// In en, this message translates to:
  /// **'Get help'**
  String get rideReceiptHelp;

  /// No description provided for @rideReceiptDone.
  ///
  /// In en, this message translates to:
  /// **'Trip completed!'**
  String get rideReceiptDone;

  /// No description provided for @rideReceiptThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks for riding with DealGo'**
  String get rideReceiptThanks;

  /// No description provided for @rideReceiptNoFare.
  ///
  /// In en, this message translates to:
  /// **'The server has not returned the agreed fare yet.'**
  String get rideReceiptNoFare;

  /// No description provided for @rideReceiptCash.
  ///
  /// In en, this message translates to:
  /// **'Paid in cash to the driver'**
  String get rideReceiptCash;

  /// No description provided for @rideReceiptFinishedAt.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get rideReceiptFinishedAt;

  /// No description provided for @rideReceiptPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment details'**
  String get rideReceiptPayment;

  /// No description provided for @rideReceiptOffline.
  ///
  /// In en, this message translates to:
  /// **'Could not load the receipt. The agreed fare is not shown.'**
  String get rideReceiptOffline;

  /// No description provided for @rideReceiptRef.
  ///
  /// In en, this message translates to:
  /// **'Receipt {ref}'**
  String rideReceiptRef(String ref);

  /// No description provided for @foodTrackingTitle.
  ///
  /// In en, this message translates to:
  /// **'Track food order'**
  String get foodTrackingTitle;

  /// No description provided for @paymentHistoryTotal.
  ///
  /// In en, this message translates to:
  /// **'Total paid'**
  String get paymentHistoryTotal;

  /// No description provided for @paymentHistoryFilterRides.
  ///
  /// In en, this message translates to:
  /// **'Rides'**
  String get paymentHistoryFilterRides;

  /// No description provided for @paymentHistoryFilterFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get paymentHistoryFilterFood;

  /// No description provided for @paymentHistoryCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentHistoryCash;

  /// No description provided for @paymentHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No payments yet. Completed rides and delivered orders appear here.'**
  String get paymentHistoryEmpty;

  /// No description provided for @paymentHistoryCount.
  ///
  /// In en, this message translates to:
  /// **'{count} payments'**
  String paymentHistoryCount(int count);

  /// No description provided for @driverStatTodayJobs.
  ///
  /// In en, this message translates to:
  /// **'Jobs today'**
  String get driverStatTodayJobs;

  /// No description provided for @driverStatTodayEarnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings today'**
  String get driverStatTodayEarnings;

  /// No description provided for @driverStatRating.
  ///
  /// In en, this message translates to:
  /// **'Average rating'**
  String get driverStatRating;

  /// No description provided for @driverStatWeekJobs.
  ///
  /// In en, this message translates to:
  /// **'Jobs, last 7 days'**
  String get driverStatWeekJobs;

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'Help center'**
  String get helpTitle;

  /// No description provided for @helpSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search answers or guides...'**
  String get helpSearchHint;

  /// No description provided for @helpTopicsTitle.
  ///
  /// In en, this message translates to:
  /// **'Popular topics'**
  String get helpTopicsTitle;

  /// No description provided for @helpTopicRide.
  ///
  /// In en, this message translates to:
  /// **'Rides'**
  String get helpTopicRide;

  /// No description provided for @helpTopicFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get helpTopicFood;

  /// No description provided for @helpTopicPayment.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get helpTopicPayment;

  /// No description provided for @helpTopicAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get helpTopicAccount;

  /// No description provided for @helpTopicSelected.
  ///
  /// In en, this message translates to:
  /// **'Topic for your request'**
  String get helpTopicSelected;

  /// No description provided for @helpFaqTitle.
  ///
  /// In en, this message translates to:
  /// **'Frequently asked questions'**
  String get helpFaqTitle;

  /// No description provided for @helpSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get helpSeeAll;

  /// No description provided for @helpStillNeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Still need help?'**
  String get helpStillNeedTitle;

  /// No description provided for @helpStillNeedBody.
  ///
  /// In en, this message translates to:
  /// **'See your requests.'**
  String get helpStillNeedBody;

  /// No description provided for @helpMyTickets.
  ///
  /// In en, this message translates to:
  /// **'Your requests'**
  String get helpMyTickets;

  /// No description provided for @helpCreateTicket.
  ///
  /// In en, this message translates to:
  /// **'Send a support request'**
  String get helpCreateTicket;

  /// No description provided for @supportListTitle.
  ///
  /// In en, this message translates to:
  /// **'Support requests'**
  String get supportListTitle;

  /// No description provided for @supportListHeading.
  ///
  /// In en, this message translates to:
  /// **'Your requests'**
  String get supportListHeading;

  /// No description provided for @supportListEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No requests yet'**
  String get supportListEmptyTitle;

  /// No description provided for @supportListEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No requests yet.'**
  String get supportListEmptyBody;

  /// No description provided for @supportListLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your requests. Check your connection and try again.'**
  String get supportListLoadFailed;

  /// No description provided for @supportNewTicket.
  ///
  /// In en, this message translates to:
  /// **'New request'**
  String get supportNewTicket;

  /// No description provided for @supportStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get supportStatusOpen;

  /// No description provided for @supportStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get supportStatusInProgress;

  /// No description provided for @supportStatusReplied.
  ///
  /// In en, this message translates to:
  /// **'Replied'**
  String get supportStatusReplied;

  /// No description provided for @supportStatusResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get supportStatusResolved;

  /// No description provided for @supportStatusClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get supportStatusClosed;

  /// No description provided for @supportCategoryRide.
  ///
  /// In en, this message translates to:
  /// **'Ride'**
  String get supportCategoryRide;

  /// No description provided for @supportCategoryFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get supportCategoryFood;

  /// No description provided for @supportCategoryPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get supportCategoryPayment;

  /// No description provided for @supportCategoryAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get supportCategoryAccount;

  /// No description provided for @supportCategorySafety.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get supportCategorySafety;

  /// No description provided for @supportCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get supportCategoryOther;

  /// No description provided for @supportPriorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get supportPriorityLow;

  /// No description provided for @supportPriorityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get supportPriorityNormal;

  /// No description provided for @supportPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get supportPriorityHigh;

  /// No description provided for @supportPriorityUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get supportPriorityUrgent;

  /// No description provided for @supportCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New support request'**
  String get supportCreateTitle;

  /// No description provided for @supportCreateHeading.
  ///
  /// In en, this message translates to:
  /// **'Need help?'**
  String get supportCreateHeading;

  /// No description provided for @supportFieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Issue type'**
  String get supportFieldCategory;

  /// No description provided for @supportFieldRelated.
  ///
  /// In en, this message translates to:
  /// **'Related ride / order'**
  String get supportFieldRelated;

  /// No description provided for @supportRelatedNone.
  ///
  /// In en, this message translates to:
  /// **'Not about a specific ride or order'**
  String get supportRelatedNone;

  /// No description provided for @supportRelatedPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick ride / order'**
  String get supportRelatedPickTitle;

  /// No description provided for @supportRelatedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No finished rides or orders yet.'**
  String get supportRelatedEmpty;

  /// No description provided for @supportFieldSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get supportFieldSubject;

  /// No description provided for @supportFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get supportFieldDescription;

  /// No description provided for @supportPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Never send passwords, OTPs or cards.'**
  String get supportPrivacyNote;

  /// No description provided for @supportSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send support request'**
  String get supportSubmit;

  /// No description provided for @supportSubjectTooShort.
  ///
  /// In en, this message translates to:
  /// **'The subject needs at least 3 characters.'**
  String get supportSubjectTooShort;

  /// No description provided for @supportDescriptionTooShort.
  ///
  /// In en, this message translates to:
  /// **'The details need at least 10 characters.'**
  String get supportDescriptionTooShort;

  /// No description provided for @supportLimitReached.
  ///
  /// In en, this message translates to:
  /// **'You have several open requests. Add to an existing one or wait for a reply.'**
  String get supportLimitReached;

  /// No description provided for @supportTextTooLong.
  ///
  /// In en, this message translates to:
  /// **'The text is too long. Please shorten it.'**
  String get supportTextTooLong;

  /// No description provided for @supportSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send. Check your connection and try again.'**
  String get supportSendFailed;

  /// No description provided for @supportCreated.
  ///
  /// In en, this message translates to:
  /// **'Support request sent.'**
  String get supportCreated;

  /// No description provided for @supportDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Request details'**
  String get supportDetailTitle;

  /// No description provided for @supportInfoCategory.
  ///
  /// In en, this message translates to:
  /// **'Issue type'**
  String get supportInfoCategory;

  /// No description provided for @supportInfoRelated.
  ///
  /// In en, this message translates to:
  /// **'Related to'**
  String get supportInfoRelated;

  /// No description provided for @supportInfoPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get supportInfoPriority;

  /// No description provided for @supportProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get supportProgressTitle;

  /// No description provided for @supportProgressReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get supportProgressReceived;

  /// No description provided for @supportProgressInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get supportProgressInProgress;

  /// No description provided for @supportProgressInProgressBody.
  ///
  /// In en, this message translates to:
  /// **'In progress.'**
  String get supportProgressInProgressBody;

  /// No description provided for @supportProgressResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get supportProgressResolved;

  /// No description provided for @supportProgressClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get supportProgressClosed;

  /// No description provided for @supportThreadTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get supportThreadTitle;

  /// No description provided for @supportStaffName.
  ///
  /// In en, this message translates to:
  /// **'DealGo Support'**
  String get supportStaffName;

  /// No description provided for @supportReplyHint.
  ///
  /// In en, this message translates to:
  /// **'Type your reply...'**
  String get supportReplyHint;

  /// No description provided for @supportReplySend.
  ///
  /// In en, this message translates to:
  /// **'Send reply'**
  String get supportReplySend;

  /// No description provided for @supportClosedNote.
  ///
  /// In en, this message translates to:
  /// **'Request closed.'**
  String get supportClosedNote;

  /// No description provided for @supportResolvedNote.
  ///
  /// In en, this message translates to:
  /// **'Resolved. Reply to reopen.'**
  String get supportResolvedNote;

  /// No description provided for @supportDetailLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this request.'**
  String get supportDetailLoadFailed;

  /// No description provided for @supportRelatedRide.
  ///
  /// In en, this message translates to:
  /// **'Ride'**
  String get supportRelatedRide;

  /// No description provided for @supportRelatedFood.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get supportRelatedFood;

  /// No description provided for @inboxSupportReplyTitle.
  ///
  /// In en, this message translates to:
  /// **'Support replied'**
  String get inboxSupportReplyTitle;

  /// No description provided for @inboxSupportResolvedTitle.
  ///
  /// In en, this message translates to:
  /// **'Request resolved'**
  String get inboxSupportResolvedTitle;

  /// No description provided for @supportFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All · {count}'**
  String supportFilterAll(int count);

  /// No description provided for @supportFilterActive.
  ///
  /// In en, this message translates to:
  /// **'In progress · {count}'**
  String supportFilterActive(int count);

  /// No description provided for @supportFilterDone.
  ///
  /// In en, this message translates to:
  /// **'Done · {count}'**
  String supportFilterDone(int count);

  /// No description provided for @supportCodeCreated.
  ///
  /// In en, this message translates to:
  /// **'Request {code} · Created {time}'**
  String supportCodeCreated(String code, String time);

  /// No description provided for @supportProgressReceivedAt.
  ///
  /// In en, this message translates to:
  /// **'Request received at {time}'**
  String supportProgressReceivedAt(String time);

  /// No description provided for @supportProgressAt.
  ///
  /// In en, this message translates to:
  /// **'At {time}'**
  String supportProgressAt(String time);

  /// No description provided for @helpBannerBadge.
  ///
  /// In en, this message translates to:
  /// **'DealGo Support'**
  String get helpBannerBadge;

  /// No description provided for @foodGroupNear.
  ///
  /// In en, this message translates to:
  /// **'Near me'**
  String get foodGroupNear;

  /// No description provided for @storeRatingNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get storeRatingNew;

  /// No description provided for @storeRatingFew.
  ///
  /// In en, this message translates to:
  /// **'{count} ratings'**
  String storeRatingFew(int count);

  /// No description provided for @storeRatingValue.
  ///
  /// In en, this message translates to:
  /// **'{rating} ({count})'**
  String storeRatingValue(String rating, int count);

  /// No description provided for @storeDistance.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String storeDistance(String km);

  /// No description provided for @foodDiscoverySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search restaurants, dishes, drinks'**
  String get foodDiscoverySearchHint;

  /// No description provided for @foodFeedEndOfList.
  ///
  /// In en, this message translates to:
  /// **'You have seen every store nearby'**
  String get foodFeedEndOfList;

  /// No description provided for @foodStoreBestsellers.
  ///
  /// In en, this message translates to:
  /// **'Best sellers'**
  String get foodStoreBestsellers;

  /// No description provided for @foodStorePrepChip.
  ///
  /// In en, this message translates to:
  /// **'≈{minutes} min'**
  String foodStorePrepChip(int minutes);

  /// No description provided for @foodStorePrepShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String foodStorePrepShort(int minutes);

  /// No description provided for @foodSearchGroups.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get foodSearchGroups;

  /// No description provided for @foodSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all →'**
  String get foodSeeAll;

  /// No description provided for @foodEmptyNoStoresInCategory.
  ///
  /// In en, this message translates to:
  /// **'No stores in this category yet'**
  String get foodEmptyNoStoresInCategory;

  /// No description provided for @foodEmptyOutOfArea.
  ///
  /// In en, this message translates to:
  /// **'DealGo does not deliver here yet'**
  String get foodEmptyOutOfArea;

  /// No description provided for @foodStoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Store details'**
  String get foodStoreTitle;

  /// No description provided for @foodStoreOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get foodStoreOpen;

  /// No description provided for @foodStorePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get foodStorePaused;

  /// No description provided for @foodStoreTabMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get foodStoreTabMenu;

  /// No description provided for @foodStoreTabReviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get foodStoreTabReviews;

  /// No description provided for @foodStoreTabInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get foodStoreTabInfo;

  /// No description provided for @foodStoreNoItems.
  ///
  /// In en, this message translates to:
  /// **'This store has no items yet.'**
  String get foodStoreNoItems;

  /// No description provided for @foodItemSoldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get foodItemSoldOut;

  /// No description provided for @foodAddToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to cart'**
  String get foodAddToCart;

  /// No description provided for @foodDecreaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Decrease quantity'**
  String get foodDecreaseQuantity;

  /// No description provided for @foodViewCart.
  ///
  /// In en, this message translates to:
  /// **'View cart'**
  String get foodViewCart;

  /// No description provided for @foodStoreReviewsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load reviews.'**
  String get foodStoreReviewsUnavailable;

  /// No description provided for @foodStoreReviewsNone.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet.'**
  String get foodStoreReviewsNone;

  /// No description provided for @foodStoreInfoName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get foodStoreInfoName;

  /// No description provided for @foodStoreInfoCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get foodStoreInfoCategory;

  /// No description provided for @foodStoreInfoAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get foodStoreInfoAddress;

  /// No description provided for @foodStoreInfoAddressMissing.
  ///
  /// In en, this message translates to:
  /// **'No address yet'**
  String get foodStoreInfoAddressMissing;

  /// No description provided for @foodStoreInfoPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get foodStoreInfoPayment;

  /// No description provided for @foodStoreInfoPaymentCod.
  ///
  /// In en, this message translates to:
  /// **'Cash on delivery'**
  String get foodStoreInfoPaymentCod;

  /// No description provided for @foodStoreMenuCount.
  ///
  /// In en, this message translates to:
  /// **'Menu · {count} items'**
  String foodStoreMenuCount(int count);

  /// No description provided for @foodStoreSectionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String foodStoreSectionCount(int count);

  /// No description provided for @foodStoreReviewsHidden.
  ///
  /// In en, this message translates to:
  /// **'{count} reviews — the score appears once there are more'**
  String foodStoreReviewsHidden(int count);

  /// No description provided for @foodStoreReviewsSummary.
  ///
  /// In en, this message translates to:
  /// **'{average} ★ · {count} reviews'**
  String foodStoreReviewsSummary(String average, int count);

  /// No description provided for @homeVoucherBadge.
  ///
  /// In en, this message translates to:
  /// **'DealGo Voucher'**
  String get homeVoucherBadge;

  /// No description provided for @homeVoucherTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s deals'**
  String get homeVoucherTitle;

  /// No description provided for @homeRecentEmpty.
  ///
  /// In en, this message translates to:
  /// **'No rides or orders yet.'**
  String get homeRecentEmpty;

  /// No description provided for @homeShopTitle.
  ///
  /// In en, this message translates to:
  /// **'Featured shopping'**
  String get homeShopTitle;

  /// No description provided for @homeRecentTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get homeRecentTitle;

  /// No description provided for @homeCatFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get homeCatFood;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @rideSafetyContactName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get rideSafetyContactName;

  /// No description provided for @rideSafetyContactPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get rideSafetyContactPhone;

  /// No description provided for @rideSafetyRemoveContact.
  ///
  /// In en, this message translates to:
  /// **'Remove contact'**
  String get rideSafetyRemoveContact;

  /// No description provided for @rideSafetyContactsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No emergency contacts yet. Add up to 3 people.'**
  String get rideSafetyContactsEmpty;

  /// No description provided for @driverNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver notifications'**
  String get driverNotificationsTitle;

  /// No description provided for @driverOpenHistory.
  ///
  /// In en, this message translates to:
  /// **'View trip history'**
  String get driverOpenHistory;

  /// No description provided for @driverCompletedNotFound.
  ///
  /// In en, this message translates to:
  /// **'This job isn\'t in your history yet'**
  String get driverCompletedNotFound;

  /// No description provided for @driverCompletedNotFoundHint.
  ///
  /// In en, this message translates to:
  /// **'Try again shortly.'**
  String get driverCompletedNotFoundHint;

  /// No description provided for @driverCompletedFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'DealGo commission'**
  String get driverCompletedFeeLabel;

  /// No description provided for @driverCompletedNetLabel.
  ///
  /// In en, this message translates to:
  /// **'You earn'**
  String get driverCompletedNetLabel;

  /// No description provided for @merchantOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Order details'**
  String get merchantOrderTitle;

  /// No description provided for @merchantOrderNotFound.
  ///
  /// In en, this message translates to:
  /// **'Order not found'**
  String get merchantOrderNotFound;

  /// No description provided for @merchantOrderTitleNew.
  ///
  /// In en, this message translates to:
  /// **'New order'**
  String get merchantOrderTitleNew;

  /// No description provided for @merchantOrderTitlePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get merchantOrderTitlePreparing;

  /// No description provided for @merchantOrderTitleReady.
  ///
  /// In en, this message translates to:
  /// **'Hand over to driver'**
  String get merchantOrderTitleReady;

  /// No description provided for @merchantMarkReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get merchantMarkReady;

  /// No description provided for @merchantHandoffAwaitDriver.
  ///
  /// In en, this message translates to:
  /// **'The driver has not confirmed pickup yet. Give them the handover code to finish.'**
  String get merchantHandoffAwaitDriver;

  /// No description provided for @merchantMarkHandedOver.
  ///
  /// In en, this message translates to:
  /// **'Handed over'**
  String get merchantMarkHandedOver;

  /// No description provided for @merchantOrderHeadNew.
  ///
  /// In en, this message translates to:
  /// **'Waiting for confirmation'**
  String get merchantOrderHeadNew;

  /// No description provided for @merchantOrderHeadPreparing.
  ///
  /// In en, this message translates to:
  /// **'Order accepted'**
  String get merchantOrderHeadPreparing;

  /// No description provided for @merchantOrderHeadReady.
  ///
  /// In en, this message translates to:
  /// **'Order ready'**
  String get merchantOrderHeadReady;

  /// No description provided for @merchantOrderCustomer.
  ///
  /// In en, this message translates to:
  /// **'DealGo customer'**
  String get merchantOrderCustomer;

  /// No description provided for @merchantOrderNewChip.
  ///
  /// In en, this message translates to:
  /// **'New · Awaiting store'**
  String get merchantOrderNewChip;

  /// No description provided for @merchantItemsToPrepare.
  ///
  /// In en, this message translates to:
  /// **'Items to prepare'**
  String get merchantItemsToPrepare;

  /// No description provided for @merchantReadyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap when the order is complete.'**
  String get merchantReadyHint;

  /// No description provided for @merchantDriverTitle.
  ///
  /// In en, this message translates to:
  /// **'Pickup driver'**
  String get merchantDriverTitle;

  /// No description provided for @merchantDriverWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a DealGo driver to claim the order.'**
  String get merchantDriverWaiting;

  /// No description provided for @merchantHandoffTitle.
  ///
  /// In en, this message translates to:
  /// **'Handover check'**
  String get merchantHandoffTitle;

  /// No description provided for @merchantOrderRefLabel.
  ///
  /// In en, this message translates to:
  /// **'Order code'**
  String get merchantOrderRefLabel;

  /// No description provided for @merchantLineCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get merchantLineCountLabel;

  /// No description provided for @merchantHandoffCodLabel.
  ///
  /// In en, this message translates to:
  /// **'Food value (COD)'**
  String get merchantHandoffCodLabel;

  /// No description provided for @merchantHandoffNote.
  ///
  /// In en, this message translates to:
  /// **'Match the order code with the driver.'**
  String get merchantHandoffNote;

  /// No description provided for @merchantHandoffDoneNote.
  ///
  /// In en, this message translates to:
  /// **'Waiting for driver.'**
  String get merchantHandoffDoneNote;

  /// No description provided for @merchantFoodValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get merchantFoodValueLabel;

  /// No description provided for @merchantDeliveryFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get merchantDeliveryFeeLabel;

  /// No description provided for @merchantTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get merchantTotalLabel;

  /// No description provided for @merchantConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm order'**
  String get merchantConflictTitle;

  /// No description provided for @merchantBackToOrders.
  ///
  /// In en, this message translates to:
  /// **'Back to orders'**
  String get merchantBackToOrders;

  /// No description provided for @merchantConflictRefresh.
  ///
  /// In en, this message translates to:
  /// **'See latest status'**
  String get merchantConflictRefresh;

  /// No description provided for @merchantConflictHeadline.
  ///
  /// In en, this message translates to:
  /// **'Order already handled'**
  String get merchantConflictHeadline;

  /// No description provided for @merchantConflictBody.
  ///
  /// In en, this message translates to:
  /// **'Order status changed.'**
  String get merchantConflictBody;

  /// No description provided for @merchantConflictOrder.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get merchantConflictOrder;

  /// No description provided for @orderRef.
  ///
  /// In en, this message translates to:
  /// **'Order {ref}'**
  String orderRef(String ref);

  /// No description provided for @rideRef.
  ///
  /// In en, this message translates to:
  /// **'Trip {ref}'**
  String rideRef(String ref);

  /// No description provided for @driverCompletedFeePercentLabel.
  ///
  /// In en, this message translates to:
  /// **'DealGo commission ({percent}%)'**
  String driverCompletedFeePercentLabel(String percent);

  /// No description provided for @driverCompletedFoodFeePercentLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee commission ({percent}%)'**
  String driverCompletedFoodFeePercentLabel(String percent);

  /// No description provided for @merchantOrderPlacedAt.
  ///
  /// In en, this message translates to:
  /// **'Placed {time}'**
  String merchantOrderPlacedAt(String time);

  /// No description provided for @merchantLineQty.
  ///
  /// In en, this message translates to:
  /// **'x{qty} · {price} each'**
  String merchantLineQty(int qty, String price);

  /// No description provided for @partnerModeChip.
  ///
  /// In en, this message translates to:
  /// **'Partner mode'**
  String get partnerModeChip;

  /// No description provided for @partnerContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get partnerContinue;

  /// No description provided for @partnerStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {current}/{total}'**
  String partnerStepOf(int current, int total);

  /// No description provided for @partnerDocTake.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get partnerDocTake;

  /// No description provided for @partnerDocPick.
  ///
  /// In en, this message translates to:
  /// **'Photo library'**
  String get partnerDocPick;

  /// No description provided for @partnerDocRetake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get partnerDocRetake;

  /// No description provided for @partnerDocRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get partnerDocRemove;

  /// No description provided for @partnerDocStored.
  ///
  /// In en, this message translates to:
  /// **'Saved on your application'**
  String get partnerDocStored;

  /// No description provided for @partnerDocPicked.
  ///
  /// In en, this message translates to:
  /// **'New photo — sent when you submit'**
  String get partnerDocPicked;

  /// No description provided for @partnerDocMissing.
  ///
  /// In en, this message translates to:
  /// **'No photo yet'**
  String get partnerDocMissing;

  /// No description provided for @partnerDocFlagged.
  ///
  /// In en, this message translates to:
  /// **'Retake requested'**
  String get partnerDocFlagged;

  /// No description provided for @partnerDocOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get partnerDocOptional;

  /// No description provided for @partnerDocHint.
  ///
  /// In en, this message translates to:
  /// **'Sharp, all 4 corners. JPG/PNG ≤ 4 MB.'**
  String get partnerDocHint;

  /// No description provided for @partnerDocPickFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the camera or photo library.'**
  String get partnerDocPickFailed;

  /// No description provided for @partnerKindIdFront.
  ///
  /// In en, this message translates to:
  /// **'ID card — front'**
  String get partnerKindIdFront;

  /// No description provided for @partnerKindIdBack.
  ///
  /// In en, this message translates to:
  /// **'ID card — back'**
  String get partnerKindIdBack;

  /// No description provided for @partnerKindSelfie.
  ///
  /// In en, this message translates to:
  /// **'Selfie'**
  String get partnerKindSelfie;

  /// No description provided for @partnerKindLicense.
  ///
  /// In en, this message translates to:
  /// **'Driving licence'**
  String get partnerKindLicense;

  /// No description provided for @partnerKindVehicleReg.
  ///
  /// In en, this message translates to:
  /// **'Vehicle registration'**
  String get partnerKindVehicleReg;

  /// No description provided for @partnerKindVehicleInsurance.
  ///
  /// In en, this message translates to:
  /// **'Vehicle insurance (photo)'**
  String get partnerKindVehicleInsurance;

  /// No description provided for @partnerKindBusinessLicense.
  ///
  /// In en, this message translates to:
  /// **'Business licence'**
  String get partnerKindBusinessLicense;

  /// No description provided for @partnerKindFoodSafetyCert.
  ///
  /// In en, this message translates to:
  /// **'Food safety certificate'**
  String get partnerKindFoodSafetyCert;

  /// No description provided for @kycLicenseClassMismatch.
  ///
  /// In en, this message translates to:
  /// **'Licence class {licenseClass} does not cover this vehicle. Go back and pick the class printed on your licence.'**
  String kycLicenseClassMismatch(String licenseClass);

  /// No description provided for @partnerKindRepIdFront.
  ///
  /// In en, this message translates to:
  /// **'Representative ID — front'**
  String get partnerKindRepIdFront;

  /// No description provided for @partnerKindRepIdBack.
  ///
  /// In en, this message translates to:
  /// **'Representative ID — back'**
  String get partnerKindRepIdBack;

  /// No description provided for @partnerKindStorefront.
  ///
  /// In en, this message translates to:
  /// **'Storefront photo'**
  String get partnerKindStorefront;

  /// No description provided for @partnerSectionPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal details'**
  String get partnerSectionPersonal;

  /// No description provided for @partnerSectionIdCard.
  ///
  /// In en, this message translates to:
  /// **'ID card photos'**
  String get partnerSectionIdCard;

  /// No description provided for @partnerSectionSelfie.
  ///
  /// In en, this message translates to:
  /// **'Selfie'**
  String get partnerSectionSelfie;

  /// No description provided for @partnerSectionLicense.
  ///
  /// In en, this message translates to:
  /// **'Driving licence'**
  String get partnerSectionLicense;

  /// No description provided for @partnerSectionVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle / registration'**
  String get partnerSectionVehicle;

  /// No description provided for @partnerSectionBank.
  ///
  /// In en, this message translates to:
  /// **'Payout account'**
  String get partnerSectionBank;

  /// No description provided for @partnerSectionShopInfo.
  ///
  /// In en, this message translates to:
  /// **'Shop details'**
  String get partnerSectionShopInfo;

  /// No description provided for @partnerSectionRepresentative.
  ///
  /// In en, this message translates to:
  /// **'Representative'**
  String get partnerSectionRepresentative;

  /// No description provided for @partnerSectionBusinessDocs.
  ///
  /// In en, this message translates to:
  /// **'Business documents'**
  String get partnerSectionBusinessDocs;

  /// No description provided for @partnerSectionStorefront.
  ///
  /// In en, this message translates to:
  /// **'Storefront photo'**
  String get partnerSectionStorefront;

  /// No description provided for @partnerSectionOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get partnerSectionOther;

  /// No description provided for @partnerFix.
  ///
  /// In en, this message translates to:
  /// **'Fix this'**
  String get partnerFix;

  /// No description provided for @partnerStartFix.
  ///
  /// In en, this message translates to:
  /// **'Start editing'**
  String get partnerStartFix;

  /// No description provided for @partnerReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason from DealGo'**
  String get partnerReasonLabel;

  /// No description provided for @partnerIssuesTitle.
  ///
  /// In en, this message translates to:
  /// **'Items to fix'**
  String get partnerIssuesTitle;

  /// No description provided for @partnerNoIssues.
  ///
  /// In en, this message translates to:
  /// **'DealGo did not list specific items. Please review the whole application.'**
  String get partnerNoIssues;

  /// No description provided for @partnerTimelineSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Application sent'**
  String get partnerTimelineSubmitted;

  /// No description provided for @partnerTimelineReview.
  ///
  /// In en, this message translates to:
  /// **'Document review'**
  String get partnerTimelineReview;

  /// No description provided for @partnerTimelineReviewQuick.
  ///
  /// In en, this message translates to:
  /// **'Admin approval'**
  String get partnerTimelineReviewQuick;

  /// No description provided for @kycStatusTitleQuick.
  ///
  /// In en, this message translates to:
  /// **'Driver registration status'**
  String get kycStatusTitleQuick;

  /// No description provided for @partnerTimelineReviewing.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get partnerTimelineReviewing;

  /// No description provided for @partnerTimelineReviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get partnerTimelineReviewed;

  /// No description provided for @partnerTimelineDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get partnerTimelineDone;

  /// No description provided for @partnerTimelineInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get partnerTimelineInProgress;

  /// No description provided for @partnerTimelineWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get partnerTimelineWaiting;

  /// No description provided for @partnerErrorSession.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please sign in again.'**
  String get partnerErrorSession;

  /// No description provided for @partnerErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Try again later.'**
  String get partnerErrorNetwork;

  /// No description provided for @partnerErrorMissingDocs.
  ///
  /// In en, this message translates to:
  /// **'Required documents are missing.'**
  String get partnerErrorMissingDocs;

  /// No description provided for @partnerErrorTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Photo too large. Retake at a lower resolution.'**
  String get partnerErrorTooLarge;

  /// No description provided for @partnerErrorType.
  ///
  /// In en, this message translates to:
  /// **'Photo format not supported.'**
  String get partnerErrorType;

  /// No description provided for @partnerErrorStorage.
  ///
  /// In en, this message translates to:
  /// **'The server cannot accept files right now. Try again later.'**
  String get partnerErrorStorage;

  /// No description provided for @partnerErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not send the application. Try again later.'**
  String get partnerErrorGeneric;

  /// No description provided for @partnerBankName.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get partnerBankName;

  /// No description provided for @partnerBankAccount.
  ///
  /// In en, this message translates to:
  /// **'Account number'**
  String get partnerBankAccount;

  /// No description provided for @partnerBankHolder.
  ///
  /// In en, this message translates to:
  /// **'Account holder'**
  String get partnerBankHolder;

  /// No description provided for @partnerBankHolderHint.
  ///
  /// In en, this message translates to:
  /// **'UPPERCASE, NO ACCENTS'**
  String get partnerBankHolderHint;

  /// No description provided for @partnerBankNote.
  ///
  /// In en, this message translates to:
  /// **'Holder name must match your ID.'**
  String get partnerBankNote;

  /// No description provided for @partnerReviewTitleDocs.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get partnerReviewTitleDocs;

  /// No description provided for @partnerReviewEntered.
  ///
  /// In en, this message translates to:
  /// **'Entered'**
  String get partnerReviewEntered;

  /// No description provided for @partnerReviewMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get partnerReviewMissing;

  /// No description provided for @kycRoleBadge.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get kycRoleBadge;

  /// No description provided for @kycFlowLabel.
  ///
  /// In en, this message translates to:
  /// **'DRIVER SIGN-UP'**
  String get kycFlowLabel;

  /// No description provided for @kycIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver sign-up'**
  String get kycIntroTitle;

  /// No description provided for @kycIntroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Driver partner'**
  String get kycIntroSubtitle;

  /// No description provided for @kycIntroHero.
  ///
  /// In en, this message translates to:
  /// **'Ride anywhere\nEarn more'**
  String get kycIntroHero;

  /// No description provided for @kycIntroHeadline.
  ///
  /// In en, this message translates to:
  /// **'Drive with DealGo'**
  String get kycIntroHeadline;

  /// No description provided for @kycIntroRideTitle.
  ///
  /// In en, this message translates to:
  /// **'Rides'**
  String get kycIntroRideTitle;

  /// No description provided for @kycIntroRideBody.
  ///
  /// In en, this message translates to:
  /// **'Rides, your price'**
  String get kycIntroRideBody;

  /// No description provided for @kycIntroFoodTitle.
  ///
  /// In en, this message translates to:
  /// **'Food delivery'**
  String get kycIntroFoodTitle;

  /// No description provided for @kycIntroFoodBody.
  ///
  /// In en, this message translates to:
  /// **'Pick up, deliver'**
  String get kycIntroFoodBody;

  /// No description provided for @kycIntroEarnTitle.
  ///
  /// In en, this message translates to:
  /// **'Track earnings'**
  String get kycIntroEarnTitle;

  /// No description provided for @kycIntroEarnBody.
  ///
  /// In en, this message translates to:
  /// **'Clear earnings'**
  String get kycIntroEarnBody;

  /// No description provided for @kycIntroRequirements.
  ///
  /// In en, this message translates to:
  /// **'Before you start: ID card, selfie, driving licence, vehicle registration and a payout account.'**
  String get kycIntroRequirements;

  /// No description provided for @kycStartCta.
  ///
  /// In en, this message translates to:
  /// **'Start sign-up'**
  String get kycStartCta;

  /// No description provided for @kycExistingCta.
  ///
  /// In en, this message translates to:
  /// **'I already applied'**
  String get kycExistingCta;

  /// No description provided for @kycStepServices.
  ///
  /// In en, this message translates to:
  /// **'Choose services'**
  String get kycStepServices;

  /// No description provided for @kycStepPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal details'**
  String get kycStepPersonal;

  /// No description provided for @kycStepIdentity.
  ///
  /// In en, this message translates to:
  /// **'ID card photos'**
  String get kycStepIdentity;

  /// No description provided for @kycStepConfirm.
  ///
  /// In en, this message translates to:
  /// **'Check your details'**
  String get kycStepConfirm;

  /// No description provided for @kycStepSelfie.
  ///
  /// In en, this message translates to:
  /// **'Selfie'**
  String get kycStepSelfie;

  /// No description provided for @kycStepLicense.
  ///
  /// In en, this message translates to:
  /// **'Driving licence'**
  String get kycStepLicense;

  /// No description provided for @kycStepVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get kycStepVehicle;

  /// No description provided for @kycStepBank.
  ///
  /// In en, this message translates to:
  /// **'Payout bank'**
  String get kycStepBank;

  /// No description provided for @kycStepReview.
  ///
  /// In en, this message translates to:
  /// **'Review driver application'**
  String get kycStepReview;

  /// No description provided for @kycSubServices.
  ///
  /// In en, this message translates to:
  /// **'You can apply for several services depending on your documents and vehicle.'**
  String get kycSubServices;

  /// No description provided for @kycSubPersonal.
  ///
  /// In en, this message translates to:
  /// **'Enter details exactly as on your ID to avoid mismatches.'**
  String get kycSubPersonal;

  /// No description provided for @kycSubIdentity.
  ///
  /// In en, this message translates to:
  /// **'Photograph both sides of your chip ID card. Photos are only visible to the review team.'**
  String get kycSubIdentity;

  /// No description provided for @kycSubConfirm.
  ///
  /// In en, this message translates to:
  /// **'Check what you entered against your ID card.'**
  String get kycSubConfirm;

  /// No description provided for @kycSubSelfie.
  ///
  /// In en, this message translates to:
  /// **'Take a clear selfie without sunglasses or a mask.'**
  String get kycSubSelfie;

  /// No description provided for @kycSubLicense.
  ///
  /// In en, this message translates to:
  /// **'Add a valid licence for the services you chose.'**
  String get kycSubLicense;

  /// No description provided for @kycSubVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle details used to check job eligibility.'**
  String get kycSubVehicle;

  /// No description provided for @kycSubBank.
  ///
  /// In en, this message translates to:
  /// **'Account for earnings and payouts.'**
  String get kycSubBank;

  /// No description provided for @kycSubReview.
  ///
  /// In en, this message translates to:
  /// **'Check before sending for review'**
  String get kycSubReview;

  /// No description provided for @kycServiceRideBody.
  ///
  /// In en, this message translates to:
  /// **'Carry riders, agree a fare'**
  String get kycServiceRideBody;

  /// No description provided for @kycServiceFoodBody.
  ///
  /// In en, this message translates to:
  /// **'Pick up and deliver food'**
  String get kycServiceFoodBody;

  /// No description provided for @kycFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get kycFullName;

  /// No description provided for @kycBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get kycBirthDate;

  /// No description provided for @kycNationality.
  ///
  /// In en, this message translates to:
  /// **'Nationality'**
  String get kycNationality;

  /// No description provided for @kycNationalityVn.
  ///
  /// In en, this message translates to:
  /// **'Vietnam'**
  String get kycNationalityVn;

  /// No description provided for @kycAddress.
  ///
  /// In en, this message translates to:
  /// **'Contact address'**
  String get kycAddress;

  /// No description provided for @kycPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Used only for review; kept private.'**
  String get kycPrivacyNote;

  /// No description provided for @kycIdNumber.
  ///
  /// In en, this message translates to:
  /// **'ID number'**
  String get kycIdNumber;

  /// No description provided for @kycIdNumberHint.
  ///
  /// In en, this message translates to:
  /// **'12 digits'**
  String get kycIdNumberHint;

  /// No description provided for @kycLicenseClass.
  ///
  /// In en, this message translates to:
  /// **'Licence class'**
  String get kycLicenseClass;

  /// No description provided for @kycLicenseNumber.
  ///
  /// In en, this message translates to:
  /// **'Licence number'**
  String get kycLicenseNumber;

  /// No description provided for @kycVehicleType.
  ///
  /// In en, this message translates to:
  /// **'Vehicle type'**
  String get kycVehicleType;

  /// No description provided for @kycVehiclePlate.
  ///
  /// In en, this message translates to:
  /// **'Plate number'**
  String get kycVehiclePlate;

  /// No description provided for @kycVehicleBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get kycVehicleBrand;

  /// No description provided for @kycVehicleModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get kycVehicleModel;

  /// No description provided for @kycVehicleInsuranceNote.
  ///
  /// In en, this message translates to:
  /// **'Cars need an insurance photo.'**
  String get kycVehicleInsuranceNote;

  /// No description provided for @kycReviewProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get kycReviewProfile;

  /// No description provided for @kycReviewDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver details'**
  String get kycReviewDriver;

  /// No description provided for @kycReviewServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get kycReviewServices;

  /// No description provided for @kycReviewBank.
  ///
  /// In en, this message translates to:
  /// **'Payout bank'**
  String get kycReviewBank;

  /// No description provided for @kycReviewNote.
  ///
  /// In en, this message translates to:
  /// **'You can work once approved.'**
  String get kycReviewNote;

  /// No description provided for @kycSubmitCta.
  ///
  /// In en, this message translates to:
  /// **'Send application'**
  String get kycSubmitCta;

  /// No description provided for @kycResubmitCta.
  ///
  /// In en, this message translates to:
  /// **'Send changes'**
  String get kycResubmitCta;

  /// No description provided for @kycStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'KYC review result'**
  String get kycStatusTitle;

  /// No description provided for @kycTrackCta.
  ///
  /// In en, this message translates to:
  /// **'Back to Driver home'**
  String get kycTrackCta;

  /// No description provided for @kycPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get kycPendingTitle;

  /// No description provided for @kycPendingBody.
  ///
  /// In en, this message translates to:
  /// **'Driver application of {name}'**
  String kycPendingBody(String name);

  /// No description provided for @kycActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Activated'**
  String get kycActiveTitle;

  /// No description provided for @kycActiveBody.
  ///
  /// In en, this message translates to:
  /// **'You can go online.'**
  String get kycActiveBody;

  /// No description provided for @kycStatusPendingNote.
  ///
  /// In en, this message translates to:
  /// **'Awaiting review.'**
  String get kycStatusPendingNote;

  /// No description provided for @kycStatusActiveNote.
  ///
  /// In en, this message translates to:
  /// **'Approved.'**
  String get kycStatusActiveNote;

  /// No description provided for @kycTimelineActivate.
  ///
  /// In en, this message translates to:
  /// **'Start taking jobs'**
  String get kycTimelineActivate;

  /// No description provided for @kycRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Update driver application'**
  String get kycRejectedTitle;

  /// No description provided for @kycRejectedBanner.
  ///
  /// In en, this message translates to:
  /// **'Fix the items below.'**
  String get kycRejectedBanner;

  /// No description provided for @kybRoleBadge.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get kybRoleBadge;

  /// No description provided for @kybFlowLabel.
  ///
  /// In en, this message translates to:
  /// **'STORE SIGN-UP'**
  String get kybFlowLabel;

  /// No description provided for @kybStepFlowLabel.
  ///
  /// In en, this message translates to:
  /// **'SHOP DETAILS'**
  String get kybStepFlowLabel;

  /// No description provided for @kybIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Store sign-up'**
  String get kybIntroTitle;

  /// No description provided for @kybIntroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shop partner'**
  String get kybIntroSubtitle;

  /// No description provided for @kybIntroHeadline.
  ///
  /// In en, this message translates to:
  /// **'Sell with DealGo'**
  String get kybIntroHeadline;

  /// No description provided for @kybIntroHero.
  ///
  /// In en, this message translates to:
  /// **'From small stalls to growing stores'**
  String get kybIntroHero;

  /// No description provided for @kybIntroBenefits.
  ///
  /// In en, this message translates to:
  /// **'DealGo grows with you'**
  String get kybIntroBenefits;

  /// No description provided for @kybBenefitReachTitle.
  ///
  /// In en, this message translates to:
  /// **'Reach customers'**
  String get kybBenefitReachTitle;

  /// No description provided for @kybBenefitReachBody.
  ///
  /// In en, this message translates to:
  /// **'Shown by area'**
  String get kybBenefitReachBody;

  /// No description provided for @kybBenefitOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'Handle orders'**
  String get kybBenefitOrdersTitle;

  /// No description provided for @kybBenefitOrdersBody.
  ///
  /// In en, this message translates to:
  /// **'Track orders'**
  String get kybBenefitOrdersBody;

  /// No description provided for @kybBenefitRevenueTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage revenue'**
  String get kybBenefitRevenueTitle;

  /// No description provided for @kybBenefitRevenueBody.
  ///
  /// In en, this message translates to:
  /// **'Stats & settlement'**
  String get kybBenefitRevenueBody;

  /// No description provided for @kybBenefitTrustTitle.
  ///
  /// In en, this message translates to:
  /// **'Transparent sign-up'**
  String get kybBenefitTrustTitle;

  /// No description provided for @kybBenefitTrustBody.
  ///
  /// In en, this message translates to:
  /// **'Verified stores'**
  String get kybBenefitTrustBody;

  /// No description provided for @kybIntroRequirements.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need shop details, a representative, a payout account and business documents.'**
  String get kybIntroRequirements;

  /// No description provided for @kybStartCta.
  ///
  /// In en, this message translates to:
  /// **'Start Shop sign-up'**
  String get kybStartCta;

  /// No description provided for @kybStepBusinessType.
  ///
  /// In en, this message translates to:
  /// **'Business type'**
  String get kybStepBusinessType;

  /// No description provided for @kybStepBusinessTypeHeadline.
  ///
  /// In en, this message translates to:
  /// **'What do you sell?'**
  String get kybStepBusinessTypeHeadline;

  /// No description provided for @kybStepShopInfo.
  ///
  /// In en, this message translates to:
  /// **'Shop details'**
  String get kybStepShopInfo;

  /// No description provided for @kybStepRepresentative.
  ///
  /// In en, this message translates to:
  /// **'Representative & payout'**
  String get kybStepRepresentative;

  /// No description provided for @kybStepDocuments.
  ///
  /// In en, this message translates to:
  /// **'Business documents'**
  String get kybStepDocuments;

  /// No description provided for @kybStepReview.
  ///
  /// In en, this message translates to:
  /// **'Review Shop application'**
  String get kybStepReview;

  /// No description provided for @kybSubBusinessType.
  ///
  /// In en, this message translates to:
  /// **'Pick the closest type so DealGo can suggest categories and checks.'**
  String get kybSubBusinessType;

  /// No description provided for @kybSubShopInfo.
  ///
  /// In en, this message translates to:
  /// **'Name and address are used for review and shown to customers.'**
  String get kybSubShopInfo;

  /// No description provided for @kybSubRepresentative.
  ///
  /// In en, this message translates to:
  /// **'Legal representative and payout account.'**
  String get kybSubRepresentative;

  /// No description provided for @kybSubDocuments.
  ///
  /// In en, this message translates to:
  /// **'Photograph the business licence and the representative\'s ID. Only reviewers can see them.'**
  String get kybSubDocuments;

  /// No description provided for @kybSubReview.
  ///
  /// In en, this message translates to:
  /// **'Check before sending'**
  String get kybSubReview;

  /// No description provided for @kybTypeRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurant / eatery'**
  String get kybTypeRestaurant;

  /// No description provided for @kybTypeRestaurantBody.
  ///
  /// In en, this message translates to:
  /// **'Cooked food'**
  String get kybTypeRestaurantBody;

  /// No description provided for @kybTypeCafe.
  ///
  /// In en, this message translates to:
  /// **'Café / milk tea'**
  String get kybTypeCafe;

  /// No description provided for @kybTypeCafeBody.
  ///
  /// In en, this message translates to:
  /// **'Drinks, bakery'**
  String get kybTypeCafeBody;

  /// No description provided for @kybTypeGrocery.
  ///
  /// In en, this message translates to:
  /// **'Supermarket / grocery'**
  String get kybTypeGrocery;

  /// No description provided for @kybTypeGroceryBody.
  ///
  /// In en, this message translates to:
  /// **'Groceries'**
  String get kybTypeGroceryBody;

  /// No description provided for @kybTypeConvenience.
  ///
  /// In en, this message translates to:
  /// **'Convenience store'**
  String get kybTypeConvenience;

  /// No description provided for @kybTypeConvenienceBody.
  ///
  /// In en, this message translates to:
  /// **'Essentials'**
  String get kybTypeConvenienceBody;

  /// No description provided for @kybTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get kybTypeOther;

  /// No description provided for @kybTypeOtherBody.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get kybTypeOtherBody;

  /// No description provided for @kybSubjectLabel.
  ///
  /// In en, this message translates to:
  /// **'Registered as'**
  String get kybSubjectLabel;

  /// No description provided for @kybSubjectHousehold.
  ///
  /// In en, this message translates to:
  /// **'Household business'**
  String get kybSubjectHousehold;

  /// No description provided for @kybSubjectCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get kybSubjectCompany;

  /// No description provided for @kybSubjectOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get kybSubjectOther;

  /// No description provided for @kybShopName.
  ///
  /// In en, this message translates to:
  /// **'Shop name'**
  String get kybShopName;

  /// No description provided for @kybShopAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get kybShopAddress;

  /// No description provided for @kybShopPin.
  ///
  /// In en, this message translates to:
  /// **'Pin your store on the map'**
  String get kybShopPin;

  /// No description provided for @kybShopPinRequired.
  ///
  /// In en, this message translates to:
  /// **'Required: drivers use this point to pick up orders.'**
  String get kybShopPinRequired;

  /// No description provided for @kybShopPinChange.
  ///
  /// In en, this message translates to:
  /// **'Pinned. Tap to change.'**
  String get kybShopPinChange;

  /// No description provided for @kybShopType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get kybShopType;

  /// No description provided for @kybShopCategory.
  ///
  /// In en, this message translates to:
  /// **'Store category (you can pick later)'**
  String get kybShopCategory;

  /// No description provided for @kybRepName.
  ///
  /// In en, this message translates to:
  /// **'Representative\'s full name'**
  String get kybRepName;

  /// No description provided for @kybReviewStatus.
  ///
  /// In en, this message translates to:
  /// **'Application status'**
  String get kybReviewStatus;

  /// No description provided for @kybReviewShop.
  ///
  /// In en, this message translates to:
  /// **'Shop details'**
  String get kybReviewShop;

  /// No description provided for @kybReviewRep.
  ///
  /// In en, this message translates to:
  /// **'Representative'**
  String get kybReviewRep;

  /// No description provided for @kybReviewBank.
  ///
  /// In en, this message translates to:
  /// **'Payout bank'**
  String get kybReviewBank;

  /// No description provided for @kybReviewNote.
  ///
  /// In en, this message translates to:
  /// **'You can sell once approved.'**
  String get kybReviewNote;

  /// No description provided for @kybSubmitCta.
  ///
  /// In en, this message translates to:
  /// **'Send for review'**
  String get kybSubmitCta;

  /// No description provided for @kybResubmitCta.
  ///
  /// In en, this message translates to:
  /// **'Resend application'**
  String get kybResubmitCta;

  /// No description provided for @kybStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Review status'**
  String get kybStatusTitle;

  /// No description provided for @kybTrackCta.
  ///
  /// In en, this message translates to:
  /// **'Back to Shop home'**
  String get kybTrackCta;

  /// No description provided for @kybPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Application under review'**
  String get kybPendingTitle;

  /// No description provided for @kybActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Activated'**
  String get kybActiveTitle;

  /// No description provided for @kybActiveBody.
  ///
  /// In en, this message translates to:
  /// **'You can start selling.'**
  String get kybActiveBody;

  /// No description provided for @kybStatusPendingNote.
  ///
  /// In en, this message translates to:
  /// **'Awaiting review.'**
  String get kybStatusPendingNote;

  /// No description provided for @kybStatusActiveNote.
  ///
  /// In en, this message translates to:
  /// **'Approved.'**
  String get kybStatusActiveNote;

  /// No description provided for @kybTimelineActivate.
  ///
  /// In en, this message translates to:
  /// **'Start selling'**
  String get kybTimelineActivate;

  /// No description provided for @kybRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Shop application'**
  String get kybRejectedTitle;

  /// No description provided for @kybRejectedBanner.
  ///
  /// In en, this message translates to:
  /// **'More info needed.'**
  String get kybRejectedBanner;

  /// No description provided for @merchantStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get merchantStatsTitle;

  /// No description provided for @merchantStatsToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get merchantStatsToday;

  /// No description provided for @merchantStatsSales.
  ///
  /// In en, this message translates to:
  /// **'Food sales'**
  String get merchantStatsSales;

  /// No description provided for @merchantStatsDelivered.
  ///
  /// In en, this message translates to:
  /// **'Completed orders'**
  String get merchantStatsDelivered;

  /// No description provided for @merchantStatsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open orders'**
  String get merchantStatsOpen;

  /// No description provided for @merchantStatsRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get merchantStatsRating;

  /// No description provided for @merchantStatsRatingNew.
  ///
  /// In en, this message translates to:
  /// **'New shop'**
  String get merchantStatsRatingNew;

  /// No description provided for @merchantStatsRatingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} ratings'**
  String merchantStatsRatingCount(int count);

  /// No description provided for @merchantStatsLastDays.
  ///
  /// In en, this message translates to:
  /// **'Last {days} days'**
  String merchantStatsLastDays(int days);

  /// No description provided for @merchantStatsRange7.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get merchantStatsRange7;

  /// No description provided for @merchantStatsRange30.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get merchantStatsRange30;

  /// No description provided for @merchantStatsOrdersByDay.
  ///
  /// In en, this message translates to:
  /// **'Completed orders per day'**
  String get merchantStatsOrdersByDay;

  /// No description provided for @merchantStatsTotals.
  ///
  /// In en, this message translates to:
  /// **'{count} orders · {sales} · {cancelled} cancelled'**
  String merchantStatsTotals(int count, String sales, int cancelled);

  /// No description provided for @merchantStatsTopItems.
  ///
  /// In en, this message translates to:
  /// **'Best sellers'**
  String get merchantStatsTopItems;

  /// No description provided for @merchantStatsTopEmpty.
  ///
  /// In en, this message translates to:
  /// **'No items delivered in this period yet.'**
  String get merchantStatsTopEmpty;

  /// No description provided for @merchantStatsPortions.
  ///
  /// In en, this message translates to:
  /// **'{count} portions'**
  String merchantStatsPortions(int count);

  /// No description provided for @merchantStatementTitle.
  ///
  /// In en, this message translates to:
  /// **'DealGo commission'**
  String get merchantStatementTitle;

  /// No description provided for @merchantStatementCash.
  ///
  /// In en, this message translates to:
  /// **'Cash from drivers ({count} orders)'**
  String merchantStatementCash(int count);

  /// No description provided for @merchantStatementCommission.
  ///
  /// In en, this message translates to:
  /// **'Commission ({percent}%)'**
  String merchantStatementCommission(String percent);

  /// No description provided for @merchantStatementNet.
  ///
  /// In en, this message translates to:
  /// **'Store keeps'**
  String get merchantStatementNet;

  /// No description provided for @merchantStatementCycle.
  ///
  /// In en, this message translates to:
  /// **'Settled every {days} days'**
  String merchantStatementCycle(int days);

  /// No description provided for @merchantStatementUnsettled.
  ///
  /// In en, this message translates to:
  /// **'Commission not yet paid'**
  String get merchantStatementUnsettled;

  /// No description provided for @merchantStatementAllPaid.
  ///
  /// In en, this message translates to:
  /// **'Commission for this period is fully paid.'**
  String get merchantStatementAllPaid;

  /// No description provided for @merchantStatementLastPaid.
  ///
  /// In en, this message translates to:
  /// **'Last payment: {period} · {amount}'**
  String merchantStatementLastPaid(String period, String amount);

  /// No description provided for @merchantStatementNote.
  ///
  /// In en, this message translates to:
  /// **'Store pays commission to DealGo.'**
  String get merchantStatementNote;

  /// No description provided for @merchantStatsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load statistics. Pull to retry.'**
  String get merchantStatsFailed;

  /// No description provided for @merchantOrderCustomerName.
  ///
  /// In en, this message translates to:
  /// **'Customer: {name}'**
  String merchantOrderCustomerName(String name);

  /// No description provided for @merchantOrderDriverName.
  ///
  /// In en, this message translates to:
  /// **'Driver: {name}'**
  String merchantOrderDriverName(String name);

  /// No description provided for @merchantQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop order queue'**
  String get merchantQueueTitle;

  /// No description provided for @merchantQueueViewOrder.
  ///
  /// In en, this message translates to:
  /// **'View order {ref}'**
  String merchantQueueViewOrder(String ref);

  /// No description provided for @merchantQueueYourShop.
  ///
  /// In en, this message translates to:
  /// **'Your shop'**
  String get merchantQueueYourShop;

  /// No description provided for @merchantQueueToHandle.
  ///
  /// In en, this message translates to:
  /// **'Orders to handle'**
  String get merchantQueueToHandle;

  /// No description provided for @merchantQueueOthers.
  ///
  /// In en, this message translates to:
  /// **'Other orders'**
  String get merchantQueueOthers;

  /// No description provided for @merchantQueueNewChip.
  ///
  /// In en, this message translates to:
  /// **'New order'**
  String get merchantQueueNewChip;

  /// No description provided for @merchantQueueDeliverTo.
  ///
  /// In en, this message translates to:
  /// **'Deliver to'**
  String get merchantQueueDeliverTo;

  /// No description provided for @merchantQueueItemsFood.
  ///
  /// In en, this message translates to:
  /// **'Items · Food'**
  String get merchantQueueItemsFood;

  /// No description provided for @merchantQueueDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get merchantQueueDeliveryFee;

  /// No description provided for @merchantQueueTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get merchantQueueTotal;

  /// No description provided for @merchantHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop overview'**
  String get merchantHomeTitle;

  /// No description provided for @merchantHomeOpenChip.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get merchantHomeOpenChip;

  /// No description provided for @merchantHomeToConfirm.
  ///
  /// In en, this message translates to:
  /// **'To confirm'**
  String get merchantHomeToConfirm;

  /// No description provided for @merchantHomePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get merchantHomePreparing;

  /// No description provided for @merchantHomeNoOrders.
  ///
  /// In en, this message translates to:
  /// **'No open orders in the queue.'**
  String get merchantHomeNoOrders;

  /// No description provided for @merchantHomeOrderLine.
  ///
  /// In en, this message translates to:
  /// **'{count} items · {food} food'**
  String merchantHomeOrderLine(int count, String food);

  /// No description provided for @merchantHomeView.
  ///
  /// In en, this message translates to:
  /// **'View →'**
  String get merchantHomeView;

  /// No description provided for @merchantHomeShopFallback.
  ///
  /// In en, this message translates to:
  /// **'Your shop'**
  String get merchantHomeShopFallback;

  /// No description provided for @merchantStatusPlaced.
  ///
  /// In en, this message translates to:
  /// **'Awaiting shop'**
  String get merchantStatusPlaced;

  /// No description provided for @merchantStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get merchantStatusPreparing;

  /// No description provided for @merchantStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get merchantStatusReady;

  /// No description provided for @merchantStatusAssigned.
  ///
  /// In en, this message translates to:
  /// **'Driver assigned'**
  String get merchantStatusAssigned;

  /// No description provided for @merchantStatusPickedUp.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get merchantStatusPickedUp;

  /// No description provided for @merchantStatusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get merchantStatusDelivered;

  /// No description provided for @merchantStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Updating'**
  String get merchantStatusUnknown;

  /// No description provided for @merchantNotSynced.
  ///
  /// In en, this message translates to:
  /// **'Not synced'**
  String get merchantNotSynced;

  /// No description provided for @merchantHomeCancelledToday.
  ///
  /// In en, this message translates to:
  /// **'Cancelled today'**
  String get merchantHomeCancelledToday;

  /// No description provided for @merchantHomeSalesToday.
  ///
  /// In en, this message translates to:
  /// **'Food sales today'**
  String get merchantHomeSalesToday;

  /// No description provided for @merchantHomeOpenOrders.
  ///
  /// In en, this message translates to:
  /// **'Open orders'**
  String get merchantHomeOpenOrders;

  /// No description provided for @merchantStatsIneligible.
  ///
  /// In en, this message translates to:
  /// **'Your shop is not approved to sell yet. Statistics appear after approval.'**
  String get merchantStatsIneligible;

  /// No description provided for @supportAttachTitle.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get supportAttachTitle;

  /// No description provided for @supportAttachCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get supportAttachCamera;

  /// No description provided for @supportAttachGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get supportAttachGallery;

  /// No description provided for @supportAttachRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get supportAttachRemove;

  /// No description provided for @supportAttachCount.
  ///
  /// In en, this message translates to:
  /// **'{count}/{max} photos'**
  String supportAttachCount(int count, int max);

  /// No description provided for @supportAttachPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo {n}'**
  String supportAttachPhoto(int n);

  /// No description provided for @supportAttachFile.
  ///
  /// In en, this message translates to:
  /// **'File {n}'**
  String supportAttachFile(int n);

  /// No description provided for @supportAttachPdfNote.
  ///
  /// In en, this message translates to:
  /// **'PDF attached.'**
  String get supportAttachPdfNote;

  /// No description provided for @supportAttachOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the file. Please try again.'**
  String get supportAttachOpenFailed;

  /// No description provided for @supportAttachTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The photo is too large. Choose a smaller one.'**
  String get supportAttachTooLarge;

  /// No description provided for @supportAttachBadType.
  ///
  /// In en, this message translates to:
  /// **'This file type is not supported.'**
  String get supportAttachBadType;

  /// No description provided for @supportAttachUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Attachments can\'t be sent right now. Send without photos or try later.'**
  String get supportAttachUnavailable;

  /// No description provided for @helpFaqLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the FAQ.'**
  String get helpFaqLoadFailed;

  /// No description provided for @helpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Need help?'**
  String get helpSubtitle;

  /// No description provided for @helpFaqEmpty.
  ///
  /// In en, this message translates to:
  /// **'No FAQ yet.'**
  String get helpFaqEmpty;

  /// No description provided for @rideShareMessage.
  ///
  /// In en, this message translates to:
  /// **'Follow my DealGo trip live: {url}'**
  String rideShareMessage(String url);

  /// No description provided for @rideShareSubject.
  ///
  /// In en, this message translates to:
  /// **'My DealGo trip'**
  String get rideShareSubject;

  /// No description provided for @rideShareSentChip.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get rideShareSentChip;

  /// No description provided for @rideSafetyCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get rideSafetyCopyLink;

  /// No description provided for @rideShareCopiedChip.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get rideShareCopiedChip;

  /// No description provided for @rideShareNotActive.
  ///
  /// In en, this message translates to:
  /// **'You can share once a driver has accepted the trip.'**
  String get rideShareNotActive;

  /// No description provided for @rideShareLimit.
  ///
  /// In en, this message translates to:
  /// **'You already created 5 links for this trip. Reuse one you sent.'**
  String get rideShareLimit;

  /// No description provided for @rideShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the link. Please try again.'**
  String get rideShareFailed;

  /// No description provided for @foodRejectOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Item out of stock'**
  String get foodRejectOutOfStock;

  /// No description provided for @foodRejectStoreBusy.
  ///
  /// In en, this message translates to:
  /// **'Store is too busy'**
  String get foodRejectStoreBusy;

  /// No description provided for @foodRejectStoreClosing.
  ///
  /// In en, this message translates to:
  /// **'Store is closing'**
  String get foodRejectStoreClosing;

  /// No description provided for @foodRejectPriceChanged.
  ///
  /// In en, this message translates to:
  /// **'Item price changed'**
  String get foodRejectPriceChanged;

  /// No description provided for @foodRejectOther.
  ///
  /// In en, this message translates to:
  /// **'Other reason'**
  String get foodRejectOther;

  /// No description provided for @foodRejectReasonLine.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String foodRejectReasonLine(String reason);

  /// No description provided for @foodRejectReasonLineWithNote.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason} — {note}'**
  String foodRejectReasonLineWithNote(String reason, String note);

  /// No description provided for @foodRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'The store declined your order'**
  String get foodRejectedTitle;

  /// No description provided for @merchantRejectReasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject reason'**
  String get merchantRejectReasonTitle;

  /// No description provided for @merchantRejectNoteRequired.
  ///
  /// In en, this message translates to:
  /// **'Note for the customer (required)'**
  String get merchantRejectNoteRequired;

  /// No description provided for @merchantRejectNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note for the customer (optional)'**
  String get merchantRejectNoteOptional;

  /// No description provided for @vouchersUse.
  ///
  /// In en, this message translates to:
  /// **'Use for food order'**
  String get vouchersUse;

  /// No description provided for @vouchersUseDone.
  ///
  /// In en, this message translates to:
  /// **'Code {code} added to your cart (and copied). It is checked again at checkout.'**
  String vouchersUseDone(String code);

  /// No description provided for @vouchersFootnote.
  ///
  /// In en, this message translates to:
  /// **'Discount applied at checkout.'**
  String get vouchersFootnote;

  /// No description provided for @voucherPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% off'**
  String voucherPercent(int percent);

  /// No description provided for @voucherPercentMax.
  ///
  /// In en, this message translates to:
  /// **'{percent}% off, up to {max}'**
  String voucherPercentMax(int percent, String max);

  /// No description provided for @voucherFixed.
  ///
  /// In en, this message translates to:
  /// **'{amount} off'**
  String voucherFixed(String amount);

  /// No description provided for @voucherDelivery.
  ///
  /// In en, this message translates to:
  /// **'{amount} off delivery'**
  String voucherDelivery(String amount);

  /// No description provided for @voucherMinOrder.
  ///
  /// In en, this message translates to:
  /// **'Orders from {amount}'**
  String voucherMinOrder(String amount);

  /// No description provided for @voucherEnds.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String voucherEnds(String date);

  /// No description provided for @voucherUsesLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} uses left'**
  String voucherUsesLeft(int count);

  /// No description provided for @homeVoucherSeeAll.
  ///
  /// In en, this message translates to:
  /// **'Hunt deals'**
  String get homeVoucherSeeAll;

  /// No description provided for @rideQuoteExpiredBadge.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get rideQuoteExpiredBadge;

  /// No description provided for @foodCancelledBrowse.
  ///
  /// In en, this message translates to:
  /// **'Choose another store'**
  String get foodCancelledBrowse;

  /// No description provided for @rideMatchingReceiving.
  ///
  /// In en, this message translates to:
  /// **'Receiving offers'**
  String get rideMatchingReceiving;

  /// No description provided for @rideMatchingSearching.
  ///
  /// In en, this message translates to:
  /// **'Waiting for offers'**
  String get rideMatchingSearching;

  /// No description provided for @rideMatchingLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the request. The trip status has not changed.'**
  String get rideMatchingLoadFailed;

  /// No description provided for @rideMatchingSent.
  ///
  /// In en, this message translates to:
  /// **'Offer sent'**
  String get rideMatchingSent;

  /// No description provided for @rideMatchingWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for drivers to make offers...'**
  String get rideMatchingWaiting;

  /// No description provided for @rideViewersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 driver is viewing your request} other{{count} drivers are viewing your request}}'**
  String rideViewersCount(int count);

  /// No description provided for @rideViewersNone.
  ///
  /// In en, this message translates to:
  /// **'No driver has opened your request yet'**
  String get rideViewersNone;

  /// No description provided for @rideViewersNotifying.
  ///
  /// In en, this message translates to:
  /// **'Notifying drivers nearby'**
  String get rideViewersNotifying;

  /// No description provided for @rideAutoAcceptLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto-accept when a driver agrees to {price}'**
  String rideAutoAcceptLabel(String price);

  /// No description provided for @rideAutoAcceptHint.
  ///
  /// In en, this message translates to:
  /// **'Only your exact price is accepted. A different price still needs you to choose.'**
  String get rideAutoAcceptHint;

  /// No description provided for @rideStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get rideStatusLabel;

  /// No description provided for @rideStatusNegotiating.
  ///
  /// In en, this message translates to:
  /// **'Negotiating'**
  String get rideStatusNegotiating;

  /// No description provided for @rideStatusAssigned.
  ///
  /// In en, this message translates to:
  /// **'Driver assigned'**
  String get rideStatusAssigned;

  /// No description provided for @rideStatusDriverEnRoute.
  ///
  /// In en, this message translates to:
  /// **'Driver on the way'**
  String get rideStatusDriverEnRoute;

  /// No description provided for @rideStatusDriverArrived.
  ///
  /// In en, this message translates to:
  /// **'Driver arrived'**
  String get rideStatusDriverArrived;

  /// No description provided for @rideStatusInTrip.
  ///
  /// In en, this message translates to:
  /// **'Trip in progress'**
  String get rideStatusInTrip;

  /// No description provided for @rideStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get rideStatusCompleted;

  /// No description provided for @rideStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get rideStatusCancelled;

  /// No description provided for @rideStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get rideStatusExpired;

  /// No description provided for @rideNoOffersTitle.
  ///
  /// In en, this message translates to:
  /// **'No offers yet'**
  String get rideNoOffersTitle;

  /// No description provided for @rideNoOffersMessage.
  ///
  /// In en, this message translates to:
  /// **'No driver offers yet.'**
  String get rideNoOffersMessage;

  /// No description provided for @rideProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get rideProgress;

  /// No description provided for @rideMatchingRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh the request. The trip status has not changed.'**
  String get rideMatchingRefreshFailed;

  /// No description provided for @rideViewOffers.
  ///
  /// In en, this message translates to:
  /// **'View offers'**
  String get rideViewOffers;

  /// No description provided for @rideCancelSearch.
  ///
  /// In en, this message translates to:
  /// **'Cancel search'**
  String get rideCancelSearch;

  /// No description provided for @rideTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'No driver found'**
  String get rideTimeoutTitle;

  /// No description provided for @rideTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'Timed out, no driver.'**
  String get rideTimeoutMessage;

  /// No description provided for @rideCurrentRoute.
  ///
  /// In en, this message translates to:
  /// **'Selected route'**
  String get rideCurrentRoute;

  /// No description provided for @rideCurrentOfferedFare.
  ///
  /// In en, this message translates to:
  /// **'Current offered fare'**
  String get rideCurrentOfferedFare;

  /// No description provided for @rideOfferedFare.
  ///
  /// In en, this message translates to:
  /// **'Offered fare'**
  String get rideOfferedFare;

  /// No description provided for @rideEditRoute.
  ///
  /// In en, this message translates to:
  /// **'Edit route'**
  String get rideEditRoute;

  /// No description provided for @rideFindAgain.
  ///
  /// In en, this message translates to:
  /// **'Find a driver again'**
  String get rideFindAgain;

  /// No description provided for @rideAssignedNote.
  ///
  /// In en, this message translates to:
  /// **'Driver accepted.'**
  String get rideAssignedNote;

  /// No description provided for @rideTrack.
  ///
  /// In en, this message translates to:
  /// **'Track trip'**
  String get rideTrack;

  /// No description provided for @rideConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm ride'**
  String get rideConfirmTitle;

  /// No description provided for @rideConfirmNoAgreed.
  ///
  /// In en, this message translates to:
  /// **'The agreed fare for this trip has not arrived yet. Please try again.'**
  String get rideConfirmNoAgreed;

  /// No description provided for @rideConfirmNewPrice.
  ///
  /// In en, this message translates to:
  /// **'Confirm new fare'**
  String get rideConfirmNewPrice;

  /// No description provided for @rideFareChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Fare changed'**
  String get rideFareChangedTitle;

  /// No description provided for @rideFareChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Old quote is invalid. Review the fare.'**
  String get rideFareChangedMessage;

  /// No description provided for @rideCompareFares.
  ///
  /// In en, this message translates to:
  /// **'Compare fares'**
  String get rideCompareFares;

  /// No description provided for @rideFareYouPicked.
  ///
  /// In en, this message translates to:
  /// **'Fare you picked'**
  String get rideFareYouPicked;

  /// No description provided for @rideFareDifference.
  ///
  /// In en, this message translates to:
  /// **'Difference'**
  String get rideFareDifference;

  /// No description provided for @rideChosenRoute.
  ///
  /// In en, this message translates to:
  /// **'Chosen route'**
  String get rideChosenRoute;

  /// No description provided for @rideOfferAgreed.
  ///
  /// In en, this message translates to:
  /// **'Agreed offer'**
  String get rideOfferAgreed;

  /// No description provided for @rideStillValid.
  ///
  /// In en, this message translates to:
  /// **'Still valid'**
  String get rideStillValid;

  /// No description provided for @rideFare.
  ///
  /// In en, this message translates to:
  /// **'Fare'**
  String get rideFare;

  /// No description provided for @rideCustomerPays.
  ///
  /// In en, this message translates to:
  /// **'You pay'**
  String get rideCustomerPays;

  /// No description provided for @ridePaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get ridePaymentMethod;

  /// No description provided for @rideCashNote.
  ///
  /// In en, this message translates to:
  /// **'Pay at the end'**
  String get rideCashNote;

  /// No description provided for @rideFarePendingExists.
  ///
  /// In en, this message translates to:
  /// **'You already have a pending offer. Open it or cancel it before sending a new fare.'**
  String get rideFarePendingExists;

  /// No description provided for @rideFareSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send your offer.'**
  String get rideFareSendFailed;

  /// No description provided for @rideYourOffer.
  ///
  /// In en, this message translates to:
  /// **'Your offer'**
  String get rideYourOffer;

  /// No description provided for @rideSuggestedFareShort.
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get rideSuggestedFareShort;

  /// No description provided for @ridePickVehicleClassFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose a vehicle class (bike or car) before sending your offer.'**
  String get ridePickVehicleClassFirst;

  /// No description provided for @rideEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get rideEnterAmount;

  /// No description provided for @rideFareOffline.
  ///
  /// In en, this message translates to:
  /// **'Your offer was not sent. The trip has not been created.'**
  String get rideFareOffline;

  /// No description provided for @rideSeeDriverOffers.
  ///
  /// In en, this message translates to:
  /// **'See driver offers'**
  String get rideSeeDriverOffers;

  /// No description provided for @rideNoAgreedYet.
  ///
  /// In en, this message translates to:
  /// **'The fare has not been agreed yet.'**
  String get rideNoAgreedYet;

  /// No description provided for @rideSelectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not select the offer.'**
  String get rideSelectFailed;

  /// No description provided for @rideCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel the request.'**
  String get rideCancelFailed;

  /// No description provided for @rideDriverOffers.
  ///
  /// In en, this message translates to:
  /// **'Driver offers'**
  String get rideDriverOffers;

  /// No description provided for @rideRequestCancelled.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled'**
  String get rideRequestCancelled;

  /// No description provided for @rideOfferInvalid.
  ///
  /// In en, this message translates to:
  /// **'The offer is no longer valid.'**
  String get rideOfferInvalid;

  /// No description provided for @rideAgreedTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip confirmed'**
  String get rideAgreedTitle;

  /// No description provided for @rideAgreedMissing.
  ///
  /// In en, this message translates to:
  /// **'The agreed fare has not arrived yet.'**
  String get rideAgreedMissing;

  /// No description provided for @rideOffersLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load offers. The trip is not confirmed.'**
  String get rideOffersLoadFailed;

  /// No description provided for @rideCurrentQuoteFare.
  ///
  /// In en, this message translates to:
  /// **'Current offered fare'**
  String get rideCurrentQuoteFare;

  /// No description provided for @rideTripCode.
  ///
  /// In en, this message translates to:
  /// **'Trip code'**
  String get rideTripCode;

  /// No description provided for @rideListRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh the list.'**
  String get rideListRefreshFailed;

  /// No description provided for @rideChangeOffer.
  ///
  /// In en, this message translates to:
  /// **'Change offer'**
  String get rideChangeOffer;

  /// No description provided for @rideQuoteExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Offer expired'**
  String get rideQuoteExpiredTitle;

  /// No description provided for @rideQuoteExpiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Quote expired.'**
  String get rideQuoteExpiredMessage;

  /// No description provided for @rideOldFare.
  ///
  /// In en, this message translates to:
  /// **'Old fare (for reference)'**
  String get rideOldFare;

  /// No description provided for @rideFindNewOffers.
  ///
  /// In en, this message translates to:
  /// **'Find new offers'**
  String get rideFindNewOffers;

  /// No description provided for @rideOfferTakenTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver unavailable'**
  String get rideOfferTakenTitle;

  /// No description provided for @rideOfferTakenMessage.
  ///
  /// In en, this message translates to:
  /// **'Offer no longer available.'**
  String get rideOfferTakenMessage;

  /// No description provided for @ridePreviousOffer.
  ///
  /// In en, this message translates to:
  /// **'Previous offer'**
  String get ridePreviousOffer;

  /// No description provided for @rideRefreshList.
  ///
  /// In en, this message translates to:
  /// **'Refresh list'**
  String get rideRefreshList;

  /// No description provided for @rideSeeOtherDrivers.
  ///
  /// In en, this message translates to:
  /// **'See other drivers'**
  String get rideSeeOtherDrivers;

  /// No description provided for @rideOfferList.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get rideOfferList;

  /// No description provided for @rideRouteAndFare.
  ///
  /// In en, this message translates to:
  /// **'Route & offered fare'**
  String get rideRouteAndFare;

  /// No description provided for @rideLowestFirst.
  ///
  /// In en, this message translates to:
  /// **'Lowest price'**
  String get rideLowestFirst;

  /// No description provided for @rideSelectOffline.
  ///
  /// In en, this message translates to:
  /// **'Your choice was not sent. The fare is not agreed yet.'**
  String get rideSelectOffline;

  /// No description provided for @rideAcceptAmount.
  ///
  /// In en, this message translates to:
  /// **'Accept {amount}'**
  String rideAcceptAmount(String amount);

  /// No description provided for @rideRecordedAmount.
  ///
  /// In en, this message translates to:
  /// **'Recorded {amount}'**
  String rideRecordedAmount(String amount);

  /// No description provided for @rideCustomerPaysAmount.
  ///
  /// In en, this message translates to:
  /// **'You pay {amount}.'**
  String rideCustomerPaysAmount(String amount);

  /// No description provided for @rideOffersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 matching offer} other{{count} matching offers}}'**
  String rideOffersCount(int count);

  /// No description provided for @rideFindDriverCta.
  ///
  /// In en, this message translates to:
  /// **'Find a driver · {amount}'**
  String rideFindDriverCta(String amount);

  /// No description provided for @rideFindDriverPlain.
  ///
  /// In en, this message translates to:
  /// **'Find a driver'**
  String get rideFindDriverPlain;

  /// No description provided for @rideRecommendedFareLabel.
  ///
  /// In en, this message translates to:
  /// **'Recommended fare {amount}'**
  String rideRecommendedFareLabel(String amount);

  /// No description provided for @rideOfferKindAccept.
  ///
  /// In en, this message translates to:
  /// **'Matches your offer'**
  String get rideOfferKindAccept;

  /// No description provided for @rideOfferKindCounter.
  ///
  /// In en, this message translates to:
  /// **'Counter-offer'**
  String get rideOfferKindCounter;

  /// No description provided for @rideOfferUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No longer available'**
  String get rideOfferUnavailable;

  /// No description provided for @rideOfferJustInvalid.
  ///
  /// In en, this message translates to:
  /// **'Offer just became invalid'**
  String get rideOfferJustInvalid;

  /// No description provided for @rideOfferExpiredShort.
  ///
  /// In en, this message translates to:
  /// **'Offer expired'**
  String get rideOfferExpiredShort;

  /// No description provided for @rideYouAreOffline.
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get rideYouAreOffline;

  /// No description provided for @driverServicesOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get driverServicesOfflineTitle;

  /// No description provided for @driverServicesNotRegistered.
  ///
  /// In en, this message translates to:
  /// **'Not registered'**
  String get driverServicesNotRegistered;

  /// No description provided for @driverServicesNoneOn.
  ///
  /// In en, this message translates to:
  /// **'Every service is off, so you will not get new jobs.'**
  String get driverServicesNoneOn;

  /// No description provided for @driverVehiclePlate.
  ///
  /// In en, this message translates to:
  /// **'Plate {plate}'**
  String driverVehiclePlate(String plate);

  /// No description provided for @driverVehicleUnknown.
  ///
  /// In en, this message translates to:
  /// **'No plate number in your driver application'**
  String get driverVehicleUnknown;

  /// No description provided for @driverVehicleNotOnFile.
  ///
  /// In en, this message translates to:
  /// **'No vehicle on file yet'**
  String get driverVehicleNotOnFile;

  /// No description provided for @driverServicesSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved. The job list only shows the services you have switched on.'**
  String get driverServicesSaved;

  /// No description provided for @driverServicesSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Your choice was not saved. Check your connection and try again.'**
  String get driverServicesSaveFailed;

  /// No description provided for @driverHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver overview'**
  String get driverHomeTitle;

  /// No description provided for @driverSeeHistory.
  ///
  /// In en, this message translates to:
  /// **'View history'**
  String get driverSeeHistory;

  /// No description provided for @driverGoOnline.
  ///
  /// In en, this message translates to:
  /// **'Go online'**
  String get driverGoOnline;

  /// No description provided for @driverOfflineHeroMessage.
  ///
  /// In en, this message translates to:
  /// **'Go online for rides and deliveries.'**
  String get driverOfflineHeroMessage;

  /// No description provided for @driverDutyStatus.
  ///
  /// In en, this message translates to:
  /// **'Duty status'**
  String get driverDutyStatus;

  /// No description provided for @driverOfflineChip.
  ///
  /// In en, this message translates to:
  /// **'Offline · Not taking jobs'**
  String get driverOfflineChip;

  /// No description provided for @driverServiceTypes.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get driverServiceTypes;

  /// No description provided for @driverNoServiceOn.
  ///
  /// In en, this message translates to:
  /// **'No service switched on'**
  String get driverNoServiceOn;

  /// No description provided for @driverContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get driverContactSupport;

  /// No description provided for @driverOpenApplication.
  ///
  /// In en, this message translates to:
  /// **'Open driver application'**
  String get driverOpenApplication;

  /// No description provided for @driverIneligibleTitle.
  ///
  /// In en, this message translates to:
  /// **'You cannot take jobs yet'**
  String get driverIneligibleTitle;

  /// No description provided for @driverIneligibleMessage.
  ///
  /// In en, this message translates to:
  /// **'Account not approved or locked.'**
  String get driverIneligibleMessage;

  /// No description provided for @driverRightsByService.
  ///
  /// In en, this message translates to:
  /// **'Access by service'**
  String get driverRightsByService;

  /// No description provided for @driverServicePassenger.
  ///
  /// In en, this message translates to:
  /// **'Rides'**
  String get driverServicePassenger;

  /// No description provided for @driverServiceBlocked.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get driverServiceBlocked;

  /// No description provided for @driverAllowedServices.
  ///
  /// In en, this message translates to:
  /// **'Services you take'**
  String get driverAllowedServices;

  /// No description provided for @driverConfigure.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get driverConfigure;

  /// No description provided for @driverOnlineBadge.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get driverOnlineBadge;

  /// No description provided for @driverOnDutyMapLabel.
  ///
  /// In en, this message translates to:
  /// **'Taking jobs'**
  String get driverOnDutyMapLabel;

  /// No description provided for @driverRideLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the ride. Check your connection and try again.'**
  String get driverRideLoadFailed;

  /// No description provided for @driverRideDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride request'**
  String get driverRideDetailTitle;

  /// No description provided for @driverCounterOffer.
  ///
  /// In en, this message translates to:
  /// **'Counter offer'**
  String get driverCounterOffer;

  /// No description provided for @driverAcceptAtPrice.
  ///
  /// In en, this message translates to:
  /// **'Accept {price}'**
  String driverAcceptAtPrice(String price);

  /// No description provided for @driverRideChip.
  ///
  /// In en, this message translates to:
  /// **'Ride · Bike & Car'**
  String get driverRideChip;

  /// No description provided for @driverCustomerFare.
  ///
  /// In en, this message translates to:
  /// **'Customer\'s fare'**
  String get driverCustomerFare;

  /// No description provided for @driverReferenceFare.
  ///
  /// In en, this message translates to:
  /// **'Reference fare'**
  String get driverReferenceFare;

  /// No description provided for @driverOfferCount.
  ///
  /// In en, this message translates to:
  /// **'Offers so far'**
  String get driverOfferCount;

  /// No description provided for @driverOfferSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send your offer. Please try again.'**
  String get driverOfferSendFailed;

  /// No description provided for @driverOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'Make an offer'**
  String get driverOfferTitle;

  /// No description provided for @driverSendOffer.
  ///
  /// In en, this message translates to:
  /// **'Send offer'**
  String get driverSendOffer;

  /// No description provided for @driverCustomerRequest.
  ///
  /// In en, this message translates to:
  /// **'Customer request'**
  String get driverCustomerRequest;

  /// No description provided for @driverVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get driverVehicle;

  /// No description provided for @driverOfferSent.
  ///
  /// In en, this message translates to:
  /// **'Offer sent'**
  String get driverOfferSent;

  /// No description provided for @driverOfferWaitingAccept.
  ///
  /// In en, this message translates to:
  /// **'Customer\'s fare · Waiting for the customer'**
  String get driverOfferWaitingAccept;

  /// No description provided for @driverOfferWaitingCounter.
  ///
  /// In en, this message translates to:
  /// **'Your fare · Waiting for the customer'**
  String get driverOfferWaitingCounter;

  /// No description provided for @driverOfferChosen.
  ///
  /// In en, this message translates to:
  /// **'The customer chose you'**
  String get driverOfferChosen;

  /// No description provided for @driverOfferLost.
  ///
  /// In en, this message translates to:
  /// **'Not chosen'**
  String get driverOfferLost;

  /// No description provided for @driverWaitingForCustomer.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the customer'**
  String get driverWaitingForCustomer;

  /// No description provided for @driverWaitingForCustomerBody.
  ///
  /// In en, this message translates to:
  /// **'Waiting for rider.'**
  String get driverWaitingForCustomerBody;

  /// No description provided for @driverReadyToNavigate.
  ///
  /// In en, this message translates to:
  /// **'Ready to pick up'**
  String get driverReadyToNavigate;

  /// No description provided for @driverReadyToNavigateBody.
  ///
  /// In en, this message translates to:
  /// **'Open pickup route.'**
  String get driverReadyToNavigateBody;

  /// No description provided for @driverOfferLostBody.
  ///
  /// In en, this message translates to:
  /// **'Rider chose another driver.'**
  String get driverOfferLostBody;

  /// No description provided for @driverOpenPickupNavigation.
  ///
  /// In en, this message translates to:
  /// **'Open pickup navigation'**
  String get driverOpenPickupNavigation;

  /// No description provided for @driverYourOffer.
  ///
  /// In en, this message translates to:
  /// **'Your offer'**
  String get driverYourOffer;

  /// No description provided for @currencySuffixVnd.
  ///
  /// In en, this message translates to:
  /// **'₫'**
  String get currencySuffixVnd;

  /// No description provided for @driverOfferAmount.
  ///
  /// In en, this message translates to:
  /// **'Offer amount'**
  String get driverOfferAmount;

  /// No description provided for @driverOfferKind.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get driverOfferKind;

  /// No description provided for @driverOfferKindAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept customer\'s fare'**
  String get driverOfferKindAccept;

  /// No description provided for @driverOfferKindCounter.
  ///
  /// In en, this message translates to:
  /// **'Propose another fare'**
  String get driverOfferKindCounter;

  /// No description provided for @driverOfferHintSame.
  ///
  /// In en, this message translates to:
  /// **'You are accepting the customer\'s fare.'**
  String get driverOfferHintSame;

  /// No description provided for @driverOfferHintCounter.
  ///
  /// In en, this message translates to:
  /// **'Different from the customer\'s fare. They will see it as your proposal.'**
  String get driverOfferHintCounter;

  /// No description provided for @driverOpenJobDetails.
  ///
  /// In en, this message translates to:
  /// **'View job details'**
  String get driverOpenJobDetails;

  /// No description provided for @driverNoOpenRequests.
  ///
  /// In en, this message translates to:
  /// **'No open requests right now'**
  String get driverNoOpenRequests;

  /// No description provided for @driverRidesAvailable.
  ///
  /// In en, this message translates to:
  /// **'Rides you can take'**
  String get driverRidesAvailable;

  /// No description provided for @driverFoodAvailable.
  ///
  /// In en, this message translates to:
  /// **'Deliveries you can take'**
  String get driverFoodAvailable;

  /// No description provided for @driverFoodJobSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} items · {dropoff}'**
  String driverFoodJobSummary(int count, String dropoff);

  /// No description provided for @driverDeliveryFare.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get driverDeliveryFare;

  /// No description provided for @driverLoadRequestsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load requests. Please try again.'**
  String get driverLoadRequestsFailed;

  /// No description provided for @driverRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get driverRequestTitle;

  /// No description provided for @driverRequestNotFound.
  ///
  /// In en, this message translates to:
  /// **'Request not found. It may have been taken or expired.'**
  String get driverRequestNotFound;

  /// No description provided for @apiErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get apiErrGeneric;

  /// No description provided for @apiErrPasskeyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This device or app version does not support passkeys yet.'**
  String get apiErrPasskeyUnavailable;

  /// No description provided for @apiErrPasskeyInvalid.
  ///
  /// In en, this message translates to:
  /// **'Passkey verification failed. Please try again or use another sign-in method.'**
  String get apiErrPasskeyInvalid;

  /// No description provided for @apiErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach DealGo. Check your connection and try again.'**
  String get apiErrNetwork;

  /// No description provided for @apiErrInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t read the response. Please try again.'**
  String get apiErrInvalidResponse;

  /// No description provided for @apiErrCarDocsTitle.
  ///
  /// In en, this message translates to:
  /// **'Car documents needed'**
  String get apiErrCarDocsTitle;

  /// No description provided for @apiErrCarDocsBody.
  ///
  /// In en, this message translates to:
  /// **'Car drivers need a vehicle insurance photo before taking trips. Add it so DealGo can review again.'**
  String get apiErrCarDocsBody;

  /// No description provided for @actionCompleteDocuments.
  ///
  /// In en, this message translates to:
  /// **'Complete documents'**
  String get actionCompleteDocuments;

  /// No description provided for @apiErrForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do this.'**
  String get apiErrForbidden;

  /// No description provided for @apiErrNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found. It may have been removed or changed.'**
  String get apiErrNotFound;

  /// No description provided for @apiErrConflict.
  ///
  /// In en, this message translates to:
  /// **'This just changed. Reload and try again.'**
  String get apiErrConflict;

  /// No description provided for @apiErrGone.
  ///
  /// In en, this message translates to:
  /// **'This has expired.'**
  String get apiErrGone;

  /// No description provided for @apiErrTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The file is too large.'**
  String get apiErrTooLarge;

  /// No description provided for @apiErrBadType.
  ///
  /// In en, this message translates to:
  /// **'This file type isn\'t supported.'**
  String get apiErrBadType;

  /// No description provided for @apiErrTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a moment and try again.'**
  String get apiErrTooMany;

  /// No description provided for @apiErrServer.
  ///
  /// In en, this message translates to:
  /// **'DealGo is having trouble. Please try again later.'**
  String get apiErrServer;

  /// No description provided for @apiErrRoleNotActive.
  ///
  /// In en, this message translates to:
  /// **'This role isn\'t approved yet or is suspended.'**
  String get apiErrRoleNotActive;

  /// No description provided for @apiErrRoleSuspended.
  ///
  /// In en, this message translates to:
  /// **'This role is suspended. Contact support for details.'**
  String get apiErrRoleSuspended;

  /// No description provided for @apiErrValidation.
  ///
  /// In en, this message translates to:
  /// **'Some details aren\'t valid. Please check and try again.'**
  String get apiErrValidation;

  /// No description provided for @apiErrRideNotFound.
  ///
  /// In en, this message translates to:
  /// **'Ride not found.'**
  String get apiErrRideNotFound;

  /// No description provided for @apiErrRideChanged.
  ///
  /// In en, this message translates to:
  /// **'The ride just changed. Please reload.'**
  String get apiErrRideChanged;

  /// No description provided for @apiErrRideNotCancellable.
  ///
  /// In en, this message translates to:
  /// **'The ride can\'t be cancelled at this stage.'**
  String get apiErrRideNotCancellable;

  /// No description provided for @apiErrFareOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'The fare is outside the allowed range.'**
  String get apiErrFareOutOfRange;

  /// No description provided for @apiErrRideAlreadyOpen.
  ///
  /// In en, this message translates to:
  /// **'You already have a ride in progress.'**
  String get apiErrRideAlreadyOpen;

  /// No description provided for @apiErrNegotiationLimit.
  ///
  /// In en, this message translates to:
  /// **'No more fare negotiation rounds for this ride.'**
  String get apiErrNegotiationLimit;

  /// No description provided for @apiErrSelfAction.
  ///
  /// In en, this message translates to:
  /// **'You can\'t take your own request.'**
  String get apiErrSelfAction;

  /// No description provided for @apiErrNotYourJob.
  ///
  /// In en, this message translates to:
  /// **'This job is no longer assigned to you.'**
  String get apiErrNotYourJob;

  /// No description provided for @apiErrOrderNotFound.
  ///
  /// In en, this message translates to:
  /// **'Order not found.'**
  String get apiErrOrderNotFound;

  /// No description provided for @apiErrOrderChanged.
  ///
  /// In en, this message translates to:
  /// **'The order just changed. Please reload.'**
  String get apiErrOrderChanged;

  /// No description provided for @apiErrJobTaken.
  ///
  /// In en, this message translates to:
  /// **'Another driver already took this job.'**
  String get apiErrJobTaken;

  /// No description provided for @apiErrOrderNotCancellable.
  ///
  /// In en, this message translates to:
  /// **'The order can\'t be cancelled at this stage.'**
  String get apiErrOrderNotCancellable;

  /// No description provided for @apiErrNotStoreOwner.
  ///
  /// In en, this message translates to:
  /// **'Your account doesn\'t manage this store.'**
  String get apiErrNotStoreOwner;

  /// No description provided for @apiErrItemNotFound.
  ///
  /// In en, this message translates to:
  /// **'Item not found.'**
  String get apiErrItemNotFound;

  /// No description provided for @apiErrVoucherNotFound.
  ///
  /// In en, this message translates to:
  /// **'This promo code doesn\'t exist.'**
  String get apiErrVoucherNotFound;

  /// No description provided for @apiErrVoucherEnded.
  ///
  /// In en, this message translates to:
  /// **'This promo code has ended or is paused.'**
  String get apiErrVoucherEnded;

  /// No description provided for @apiErrVoucherNotStarted.
  ///
  /// In en, this message translates to:
  /// **'This promo code hasn\'t started yet.'**
  String get apiErrVoucherNotStarted;

  /// No description provided for @apiErrVoucherMinOrder.
  ///
  /// In en, this message translates to:
  /// **'The minimum amount for this code isn\'t met.'**
  String get apiErrVoucherMinOrder;

  /// No description provided for @apiErrVoucherUsedUp.
  ///
  /// In en, this message translates to:
  /// **'This promo code has been fully used.'**
  String get apiErrVoucherUsedUp;

  /// No description provided for @apiErrVoucherUserLimit.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used this code the maximum number of times.'**
  String get apiErrVoucherUserLimit;

  /// No description provided for @apiErrVoucherWrongService.
  ///
  /// In en, this message translates to:
  /// **'This promo code doesn\'t apply to this service.'**
  String get apiErrVoucherWrongService;

  /// No description provided for @merchantIneligibleTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t take orders'**
  String get merchantIneligibleTitle;

  /// No description provided for @merchantIneligibleMessage.
  ///
  /// In en, this message translates to:
  /// **'Store not approved or locked.'**
  String get merchantIneligibleMessage;

  /// No description provided for @merchantReloadOrders.
  ///
  /// In en, this message translates to:
  /// **'Reload orders'**
  String get merchantReloadOrders;

  /// No description provided for @merchantNoNewOrders.
  ///
  /// In en, this message translates to:
  /// **'No new orders'**
  String get merchantNoNewOrders;

  /// No description provided for @merchantNoNewOrdersBody.
  ///
  /// In en, this message translates to:
  /// **'New orders appear here.'**
  String get merchantNoNewOrdersBody;

  /// No description provided for @merchantViewSavedOrders.
  ///
  /// In en, this message translates to:
  /// **'View saved orders'**
  String get merchantViewSavedOrders;

  /// No description provided for @merchantOrdersLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load orders'**
  String get merchantOrdersLoadFailed;

  /// No description provided for @merchantOrdersLoadFailedBody.
  ///
  /// In en, this message translates to:
  /// **'List may be outdated.'**
  String get merchantOrdersLoadFailedBody;

  /// No description provided for @merchantConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get merchantConnection;

  /// No description provided for @merchantLoadFailedChip.
  ///
  /// In en, this message translates to:
  /// **'Load failed'**
  String get merchantLoadFailedChip;

  /// No description provided for @merchantLastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced'**
  String get merchantLastSynced;

  /// No description provided for @merchantNoSavedOrders.
  ///
  /// In en, this message translates to:
  /// **'No orders saved on this device.'**
  String get merchantNoSavedOrders;

  /// No description provided for @merchantSavedOrders.
  ///
  /// In en, this message translates to:
  /// **'Saved orders'**
  String get merchantSavedOrders;

  /// No description provided for @merchantItemInvalid.
  ///
  /// In en, this message translates to:
  /// **'Item name and price aren\'t valid.'**
  String get merchantItemInvalid;

  /// No description provided for @merchantItemUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the item.'**
  String get merchantItemUpdateFailed;

  /// No description provided for @merchantItemCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add the item.'**
  String get merchantItemCreateFailed;

  /// No description provided for @foodStageAwaitingStore.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the store to confirm'**
  String get foodStageAwaitingStore;

  /// No description provided for @foodStagePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing your food'**
  String get foodStagePreparing;

  /// No description provided for @foodStageOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get foodStageOnTheWay;

  /// No description provided for @foodStageCancelled.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled'**
  String get foodStageCancelled;

  /// No description provided for @foodStageUnknown.
  ///
  /// In en, this message translates to:
  /// **'Order status unknown'**
  String get foodStageUnknown;

  /// No description provided for @merchantMenuSummary.
  ///
  /// In en, this message translates to:
  /// **'{available} on sale · {total} items in total'**
  String merchantMenuSummary(int available, int total);

  /// No description provided for @merchantAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get merchantAddItem;

  /// No description provided for @merchantItemName.
  ///
  /// In en, this message translates to:
  /// **'Item name'**
  String get merchantItemName;

  /// No description provided for @merchantItemPrice.
  ///
  /// In en, this message translates to:
  /// **'Price (VND)'**
  String get merchantItemPrice;

  /// No description provided for @merchantPriceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid price'**
  String get merchantPriceInvalid;

  /// No description provided for @merchantItemOnSale.
  ///
  /// In en, this message translates to:
  /// **'On sale'**
  String get merchantItemOnSale;

  /// No description provided for @merchantItemSoldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get merchantItemSoldOut;

  /// No description provided for @merchantItemPendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get merchantItemPendingReview;

  /// No description provided for @merchantItemRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get merchantItemRejected;

  /// No description provided for @foodOrderSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Order sent'**
  String get foodOrderSentTitle;

  /// No description provided for @foodOrderPlaced.
  ///
  /// In en, this message translates to:
  /// **'Order placed'**
  String get foodOrderPlaced;

  /// No description provided for @foodOrderPlacedSub.
  ///
  /// In en, this message translates to:
  /// **'Waiting for store'**
  String get foodOrderPlacedSub;

  /// No description provided for @foodPayOnDelivery.
  ///
  /// In en, this message translates to:
  /// **'Pay on delivery'**
  String get foodPayOnDelivery;

  /// No description provided for @foodCashNotPaid.
  ///
  /// In en, this message translates to:
  /// **'Cash · Not paid yet'**
  String get foodCashNotPaid;

  /// No description provided for @foodStepSent.
  ///
  /// In en, this message translates to:
  /// **'Order sent'**
  String get foodStepSent;

  /// No description provided for @foodStepAwaitStore.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the store'**
  String get foodStepAwaitStore;

  /// No description provided for @foodStepNotPreparing.
  ///
  /// In en, this message translates to:
  /// **'Not being prepared yet'**
  String get foodStepNotPreparing;

  /// No description provided for @foodTrackOrder.
  ///
  /// In en, this message translates to:
  /// **'Track order'**
  String get foodTrackOrder;

  /// No description provided for @foodReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting...'**
  String get foodReconnecting;

  /// No description provided for @foodReconnectingBody.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get foodReconnectingBody;

  /// No description provided for @foodOrderInProgress.
  ///
  /// In en, this message translates to:
  /// **'Order in progress'**
  String get foodOrderInProgress;

  /// No description provided for @foodCustomerPays.
  ///
  /// In en, this message translates to:
  /// **'You pay'**
  String get foodCustomerPays;

  /// No description provided for @foodLastKnownStatus.
  ///
  /// In en, this message translates to:
  /// **'Last known status'**
  String get foodLastKnownStatus;

  /// No description provided for @foodLineQtyPrice.
  ///
  /// In en, this message translates to:
  /// **'x{quantity} · {price} each'**
  String foodLineQtyPrice(int quantity, String price);

  /// No description provided for @homeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search places, stores, dishes...'**
  String get homeSearchHint;

  /// No description provided for @homeServiceRideSub.
  ///
  /// In en, this message translates to:
  /// **'Ride now'**
  String get homeServiceRideSub;

  /// No description provided for @homeServiceFoodSub.
  ///
  /// In en, this message translates to:
  /// **'Delivered to you'**
  String get homeServiceFoodSub;

  /// No description provided for @voiceOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the call. Please try again.'**
  String get voiceOpenFailed;

  /// No description provided for @mapIllustrative.
  ///
  /// In en, this message translates to:
  /// **'Illustrative map'**
  String get mapIllustrative;

  /// No description provided for @mapRouteRoadFollowed.
  ///
  /// In en, this message translates to:
  /// **'Road route'**
  String get mapRouteRoadFollowed;

  /// No description provided for @mapRouteStraightFallback.
  ///
  /// In en, this message translates to:
  /// **'Straight-line preview'**
  String get mapRouteStraightFallback;

  /// No description provided for @rideVoucherTitle.
  ///
  /// In en, this message translates to:
  /// **'Voucher'**
  String get rideVoucherTitle;

  /// No description provided for @rideVoucherLine.
  ///
  /// In en, this message translates to:
  /// **'Voucher {code}'**
  String rideVoucherLine(String code);

  /// No description provided for @rideCashDueLabel.
  ///
  /// In en, this message translates to:
  /// **'Cash to the driver'**
  String get rideCashDueLabel;

  /// No description provided for @rideVoucherDropped.
  ///
  /// In en, this message translates to:
  /// **'{reason} You can select again without the code.'**
  String rideVoucherDropped(String reason);

  /// No description provided for @driverCashToCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect {amount} in cash'**
  String driverCashToCollect(String amount);

  /// No description provided for @driverVoucherFunded.
  ///
  /// In en, this message translates to:
  /// **'Customer voucher {amount}; DealGo pays you this part.'**
  String driverVoucherFunded(String amount);

  /// No description provided for @merchantBusyEyebrow.
  ///
  /// In en, this message translates to:
  /// **'SERVICE CAPACITY'**
  String get merchantBusyEyebrow;

  /// No description provided for @merchantBusyHeading.
  ///
  /// In en, this message translates to:
  /// **'Store status'**
  String get merchantBusyHeading;

  /// No description provided for @merchantBusyAccepting.
  ///
  /// In en, this message translates to:
  /// **'Taking orders'**
  String get merchantBusyAccepting;

  /// No description provided for @merchantBusyNotAccepting.
  ///
  /// In en, this message translates to:
  /// **'Not taking orders'**
  String get merchantBusyNotAccepting;

  /// No description provided for @merchantBusyAcceptingBody.
  ///
  /// In en, this message translates to:
  /// **'Customers can order from {store}.'**
  String merchantBusyAcceptingBody(String store);

  /// No description provided for @merchantBusyNotAcceptingBody.
  ///
  /// In en, this message translates to:
  /// **'Customers can\'t order.'**
  String get merchantBusyNotAcceptingBody;

  /// No description provided for @merchantBusyResumesAt.
  ///
  /// In en, this message translates to:
  /// **'Reopens automatically at {time}'**
  String merchantBusyResumesAt(String time);

  /// No description provided for @merchantBusyResumeLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto-reopen'**
  String get merchantBusyResumeLabel;

  /// No description provided for @merchantBusyResumeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String merchantBusyResumeMinutes(int minutes);

  /// No description provided for @merchantBusyResumeHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String merchantBusyResumeHours(int hours);

  /// No description provided for @merchantBusyResumeManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get merchantBusyResumeManual;

  /// No description provided for @merchantBusySave.
  ///
  /// In en, this message translates to:
  /// **'Save store status'**
  String get merchantBusySave;

  /// No description provided for @merchantBusySaved.
  ///
  /// In en, this message translates to:
  /// **'Store status saved.'**
  String get merchantBusySaved;

  /// No description provided for @checkoutErrStorePaused.
  ///
  /// In en, this message translates to:
  /// **'This store isn\'t taking orders right now. Please try again later.'**
  String get checkoutErrStorePaused;

  /// No description provided for @foodStorePausedBanner.
  ///
  /// In en, this message translates to:
  /// **'This store has paused new orders.'**
  String get foodStorePausedBanner;

  /// No description provided for @foodStoreBusyBanner.
  ///
  /// In en, this message translates to:
  /// **'Busy — slower prep.'**
  String get foodStoreBusyBanner;

  /// No description provided for @merchantHomeBusyChip.
  ///
  /// In en, this message translates to:
  /// **'Busy'**
  String get merchantHomeBusyChip;

  /// No description provided for @merchantHomePausedChip.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get merchantHomePausedChip;

  /// No description provided for @merchantHoursEyebrow.
  ///
  /// In en, this message translates to:
  /// **'BUSINESS HOURS'**
  String get merchantHoursEyebrow;

  /// No description provided for @merchantHoursHeading.
  ///
  /// In en, this message translates to:
  /// **'Opening schedule'**
  String get merchantHoursHeading;

  /// No description provided for @merchantHoursUnset.
  ///
  /// In en, this message translates to:
  /// **'No hours saved yet, so the store takes orders all day. Save the schedule below to apply it.'**
  String get merchantHoursUnset;

  /// No description provided for @merchantHoursWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly schedule'**
  String get merchantHoursWeekly;

  /// No description provided for @merchantHoursClosedShort.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get merchantHoursClosedShort;

  /// No description provided for @merchantHoursClosures.
  ///
  /// In en, this message translates to:
  /// **'Special days off'**
  String get merchantHoursClosures;

  /// No description provided for @merchantHoursAddClosure.
  ///
  /// In en, this message translates to:
  /// **'+ Add day off'**
  String get merchantHoursAddClosure;

  /// No description provided for @merchantHoursNoClosures.
  ///
  /// In en, this message translates to:
  /// **'No special days off.'**
  String get merchantHoursNoClosures;

  /// No description provided for @merchantHoursRemoveClosure.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get merchantHoursRemoveClosure;

  /// No description provided for @merchantHoursCutoffTitle.
  ///
  /// In en, this message translates to:
  /// **'Last order before close'**
  String get merchantHoursCutoffTitle;

  /// No description provided for @merchantHoursCutoffNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get merchantHoursCutoffNone;

  /// No description provided for @merchantHoursSave.
  ///
  /// In en, this message translates to:
  /// **'Save schedule'**
  String get merchantHoursSave;

  /// No description provided for @merchantHoursSaved.
  ///
  /// In en, this message translates to:
  /// **'Schedule saved.'**
  String get merchantHoursSaved;

  /// No description provided for @merchantHoursInvalidRange.
  ///
  /// In en, this message translates to:
  /// **'{day}: closing time can\'t equal opening time.'**
  String merchantHoursInvalidRange(String day);

  /// No description provided for @dayShortMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get dayShortMon;

  /// No description provided for @dayShortTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get dayShortTue;

  /// No description provided for @dayShortWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get dayShortWed;

  /// No description provided for @dayShortThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get dayShortThu;

  /// No description provided for @dayShortFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get dayShortFri;

  /// No description provided for @dayShortSat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get dayShortSat;

  /// No description provided for @dayShortSun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get dayShortSun;

  /// No description provided for @checkoutErrStoreClosed.
  ///
  /// In en, this message translates to:
  /// **'This store is closed right now. Please come back later.'**
  String get checkoutErrStoreClosed;

  /// No description provided for @merchantHoursErrInvalid.
  ///
  /// In en, this message translates to:
  /// **'The schedule is invalid. Check opening times and days off.'**
  String get merchantHoursErrInvalid;

  /// No description provided for @foodStoreClosedLabel.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get foodStoreClosedLabel;

  /// No description provided for @foodStorePausedLabel.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get foodStorePausedLabel;

  /// No description provided for @foodStoreClosedBanner.
  ///
  /// In en, this message translates to:
  /// **'Store is closed.'**
  String get foodStoreClosedBanner;

  /// No description provided for @foodStoreHoursToday.
  ///
  /// In en, this message translates to:
  /// **'Today: {range}'**
  String foodStoreHoursToday(String range);

  /// No description provided for @foodStoreHoursTodayOff.
  ///
  /// In en, this message translates to:
  /// **'Closed today.'**
  String get foodStoreHoursTodayOff;

  /// No description provided for @merchantAcceptEyebrow.
  ///
  /// In en, this message translates to:
  /// **'OPERATIONS SETUP'**
  String get merchantAcceptEyebrow;

  /// No description provided for @merchantAcceptHeading.
  ///
  /// In en, this message translates to:
  /// **'Order intake setup'**
  String get merchantAcceptHeading;

  /// No description provided for @merchantAcceptStoreState.
  ///
  /// In en, this message translates to:
  /// **'Status: {state}'**
  String merchantAcceptStoreState(String state);

  /// No description provided for @merchantAcceptStateOpen.
  ///
  /// In en, this message translates to:
  /// **'taking orders'**
  String get merchantAcceptStateOpen;

  /// No description provided for @merchantAcceptStateBusy.
  ///
  /// In en, this message translates to:
  /// **'kitchen busy'**
  String get merchantAcceptStateBusy;

  /// No description provided for @merchantAcceptStatePaused.
  ///
  /// In en, this message translates to:
  /// **'paused'**
  String get merchantAcceptStatePaused;

  /// No description provided for @merchantAcceptStateClosed.
  ///
  /// In en, this message translates to:
  /// **'outside opening hours'**
  String get merchantAcceptStateClosed;

  /// No description provided for @merchantAcceptLimits.
  ///
  /// In en, this message translates to:
  /// **'Operating limits'**
  String get merchantAcceptLimits;

  /// No description provided for @merchantAcceptMaxActive.
  ///
  /// In en, this message translates to:
  /// **'Max orders in progress'**
  String get merchantAcceptMaxActive;

  /// No description provided for @merchantAcceptOrdersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} orders'**
  String merchantAcceptOrdersCount(int count);

  /// No description provided for @merchantAcceptNoLimit.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get merchantAcceptNoLimit;

  /// No description provided for @merchantAcceptPrep.
  ///
  /// In en, this message translates to:
  /// **'Default prep time'**
  String get merchantAcceptPrep;

  /// No description provided for @merchantAcceptCutoff.
  ///
  /// In en, this message translates to:
  /// **'Orders near closing'**
  String get merchantAcceptCutoff;

  /// No description provided for @merchantAcceptSave.
  ///
  /// In en, this message translates to:
  /// **'Save settings'**
  String get merchantAcceptSave;

  /// No description provided for @merchantAcceptSaved.
  ///
  /// In en, this message translates to:
  /// **'Order acceptance settings saved.'**
  String get merchantAcceptSaved;

  /// No description provided for @merchantAcceptPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a value'**
  String get merchantAcceptPickTitle;

  /// No description provided for @merchantBusyExtraLabel.
  ///
  /// In en, this message translates to:
  /// **'Extra prep time'**
  String get merchantBusyExtraLabel;

  /// No description provided for @merchantBusyExtraHint.
  ///
  /// In en, this message translates to:
  /// **'Prep ≈{minutes} min.'**
  String merchantBusyExtraHint(int minutes);

  /// No description provided for @foodTrackingReadyBy.
  ///
  /// In en, this message translates to:
  /// **'Food expected ready at {time}'**
  String foodTrackingReadyBy(String time);

  /// No description provided for @checkoutErrStoreAtCapacity.
  ///
  /// In en, this message translates to:
  /// **'The store has too many orders right now. Please try again in a few minutes.'**
  String get checkoutErrStoreAtCapacity;

  /// No description provided for @merchantHoursNextDay.
  ///
  /// In en, this message translates to:
  /// **'next day'**
  String get merchantHoursNextDay;

  /// No description provided for @foodStoreHoursOvernight.
  ///
  /// In en, this message translates to:
  /// **'{range} (until next morning)'**
  String foodStoreHoursOvernight(String range);

  /// No description provided for @homeSearchChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'What are you looking for?'**
  String get homeSearchChooseTitle;

  /// No description provided for @homeSearchAsFood.
  ///
  /// In en, this message translates to:
  /// **'Stores and dishes: “{query}”'**
  String homeSearchAsFood(String query);

  /// No description provided for @homeSearchAsPlace.
  ///
  /// In en, this message translates to:
  /// **'Ride destination: “{query}”'**
  String homeSearchAsPlace(String query);

  /// No description provided for @trackingDriverLiveAt.
  ///
  /// In en, this message translates to:
  /// **'Driver location at {time}'**
  String trackingDriverLiveAt(String time);

  /// No description provided for @foodStageFailed.
  ///
  /// In en, this message translates to:
  /// **'Delivery failed'**
  String get foodStageFailed;

  /// No description provided for @foodItemOptionsUpTo.
  ///
  /// In en, this message translates to:
  /// **'Up to {count}'**
  String foodItemOptionsUpTo(int count);

  /// No description provided for @foodItemOptionsSoldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get foodItemOptionsSoldOut;

  /// No description provided for @apiErrFoodOptionInvalid.
  ///
  /// In en, this message translates to:
  /// **'This dish\'s options changed or are incomplete. Please choose again.'**
  String get apiErrFoodOptionInvalid;

  /// No description provided for @merchantOptionsBasePrice.
  ///
  /// In en, this message translates to:
  /// **'Base price {price}'**
  String merchantOptionsBasePrice(String price);

  /// No description provided for @merchantOptionsAddChoice.
  ///
  /// In en, this message translates to:
  /// **'+ Add choice'**
  String get merchantOptionsAddChoice;

  /// No description provided for @merchantOptionsAddGroup.
  ///
  /// In en, this message translates to:
  /// **'+ Add option group'**
  String get merchantOptionsAddGroup;

  /// No description provided for @merchantOptionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No options yet. Add a group such as Size or Topping for customers to choose.'**
  String get merchantOptionsEmpty;

  /// No description provided for @merchantOptionsRuleRequiredOne.
  ///
  /// In en, this message translates to:
  /// **'Required · pick 1'**
  String get merchantOptionsRuleRequiredOne;

  /// No description provided for @merchantOptionsRuleOptionalOne.
  ///
  /// In en, this message translates to:
  /// **'Optional · pick 1'**
  String get merchantOptionsRuleOptionalOne;

  /// No description provided for @merchantOptionsRuleUpTo.
  ///
  /// In en, this message translates to:
  /// **'Optional · up to {max}'**
  String merchantOptionsRuleUpTo(int max);

  /// No description provided for @merchantOptionsRuleRange.
  ///
  /// In en, this message translates to:
  /// **'Required · pick {min}–{max}'**
  String merchantOptionsRuleRange(int min, int max);

  /// No description provided for @merchantOptionsSoldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get merchantOptionsSoldOut;

  /// No description provided for @merchantOptionsGroupDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Option group'**
  String get merchantOptionsGroupDialogTitle;

  /// No description provided for @merchantOptionsGroupName.
  ///
  /// In en, this message translates to:
  /// **'Group name (e.g. Size, Topping)'**
  String get merchantOptionsGroupName;

  /// No description provided for @merchantOptionsMin.
  ///
  /// In en, this message translates to:
  /// **'Customer must pick at least'**
  String get merchantOptionsMin;

  /// No description provided for @merchantOptionsMax.
  ///
  /// In en, this message translates to:
  /// **'Customer may pick up to'**
  String get merchantOptionsMax;

  /// No description provided for @merchantOptionsChoiceDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Choice'**
  String get merchantOptionsChoiceDialogTitle;

  /// No description provided for @merchantOptionsChoiceName.
  ///
  /// In en, this message translates to:
  /// **'Choice name'**
  String get merchantOptionsChoiceName;

  /// No description provided for @merchantOptionsChoicePrice.
  ///
  /// In en, this message translates to:
  /// **'Extra price (VND)'**
  String get merchantOptionsChoicePrice;

  /// No description provided for @merchantOptionsChoiceAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get merchantOptionsChoiceAvailable;

  /// No description provided for @merchantOptionsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get merchantOptionsDelete;

  /// No description provided for @merchantOptionsApply.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get merchantOptionsApply;

  /// No description provided for @merchantOptionsSaved.
  ///
  /// In en, this message translates to:
  /// **'Dish options saved'**
  String get merchantOptionsSaved;

  /// No description provided for @merchantOptionsInvalidGroup.
  ///
  /// In en, this message translates to:
  /// **'Each group needs a unique name, at least one distinct choice, and min ≤ max ≤ number of choices.'**
  String get merchantOptionsInvalidGroup;

  /// No description provided for @merchantOptionsItemMissing.
  ///
  /// In en, this message translates to:
  /// **'Dish not found in the menu.'**
  String get merchantOptionsItemMissing;

  /// No description provided for @merchantOptionsUnsaved.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get merchantOptionsUnsaved;

  /// No description provided for @driverFoodNoStorePoint.
  ///
  /// In en, this message translates to:
  /// **'The store has no map point yet — follow its address.'**
  String get driverFoodNoStorePoint;

  /// No description provided for @driverNavGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Google Maps'**
  String get driverNavGoogleMaps;

  /// No description provided for @driverNavWaze.
  ///
  /// In en, this message translates to:
  /// **'Waze'**
  String get driverNavWaze;

  /// No description provided for @driverNavAppleMaps.
  ///
  /// In en, this message translates to:
  /// **'Apple Maps'**
  String get driverNavAppleMaps;

  /// No description provided for @chatRoleDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get chatRoleDriver;

  /// No description provided for @chatRoleCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get chatRoleCustomer;

  /// No description provided for @chatRoleShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get chatRoleShop;

  /// No description provided for @chatCallAction.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get chatCallAction;

  /// No description provided for @chatCloseAction.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get chatCloseAction;

  /// No description provided for @chatSendAction.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSendAction;

  /// No description provided for @chatStatusSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get chatStatusSending;

  /// No description provided for @chatStatusSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get chatStatusSent;

  /// No description provided for @chatStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Not sent · Tap to retry'**
  String get chatStatusFailed;

  /// No description provided for @chatToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get chatToday;

  /// No description provided for @chatYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get chatYesterday;

  /// No description provided for @chatEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Send a message to coordinate quickly'**
  String get chatEmptyBody;

  /// No description provided for @chatUnreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count} new messages'**
  String chatUnreadCount(int count);

  /// No description provided for @chatQuickDriverComing.
  ///
  /// In en, this message translates to:
  /// **'I\'m on my way'**
  String get chatQuickDriverComing;

  /// No description provided for @chatQuickDriverDelivering.
  ///
  /// In en, this message translates to:
  /// **'I\'m on my way with your order'**
  String get chatQuickDriverDelivering;

  /// No description provided for @chatQuickDriverArrived.
  ///
  /// In en, this message translates to:
  /// **'I\'ve arrived'**
  String get chatQuickDriverArrived;

  /// No description provided for @chatQuickDriverWait.
  ///
  /// In en, this message translates to:
  /// **'Give me 2 minutes'**
  String get chatQuickDriverWait;

  /// No description provided for @chatQuickCustomerGate.
  ///
  /// In en, this message translates to:
  /// **'I\'m at the gate'**
  String get chatQuickCustomerGate;

  /// No description provided for @chatQuickCustomerComing.
  ///
  /// In en, this message translates to:
  /// **'Coming out now'**
  String get chatQuickCustomerComing;

  /// No description provided for @chatQuickCustomerWhere.
  ///
  /// In en, this message translates to:
  /// **'Where are you?'**
  String get chatQuickCustomerWhere;

  /// No description provided for @chatQuickCustomerLeaveAtGate.
  ///
  /// In en, this message translates to:
  /// **'Please leave it at the gate'**
  String get chatQuickCustomerLeaveAtGate;

  /// No description provided for @driverNavOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open a navigation app. Check Google Maps or Waze on this phone.'**
  String get driverNavOpenFailed;

  /// No description provided for @driverNavOpen.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get driverNavOpen;

  /// No description provided for @driverNavSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Navigate with'**
  String get driverNavSheetTitle;

  /// No description provided for @driverNavWeb.
  ///
  /// In en, this message translates to:
  /// **'Google Maps (browser)'**
  String get driverNavWeb;

  /// No description provided for @driverNavLastUsed.
  ///
  /// In en, this message translates to:
  /// **'Last used'**
  String get driverNavLastUsed;

  /// No description provided for @driverNavToPickup.
  ///
  /// In en, this message translates to:
  /// **'To the pickup point'**
  String get driverNavToPickup;

  /// No description provided for @driverNavToDropoff.
  ///
  /// In en, this message translates to:
  /// **'To the drop-off point'**
  String get driverNavToDropoff;

  /// No description provided for @driverNavToStore.
  ///
  /// In en, this message translates to:
  /// **'To the store'**
  String get driverNavToStore;

  /// No description provided for @driverNavToCustomer.
  ///
  /// In en, this message translates to:
  /// **'To the customer'**
  String get driverNavToCustomer;

  /// No description provided for @driverRideUnassignedTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride reassigned'**
  String get driverRideUnassignedTitle;

  /// No description provided for @driverRideUnassignedStartTimeout.
  ///
  /// In en, this message translates to:
  /// **'You didn\'t start heading to the pickup in time.'**
  String get driverRideUnassignedStartTimeout;

  /// No description provided for @driverRideUnassignedArriveTimeout.
  ///
  /// In en, this message translates to:
  /// **'You didn\'t reach the pickup in time.'**
  String get driverRideUnassignedArriveTimeout;

  /// No description provided for @driverRideUnassignedOps.
  ///
  /// In en, this message translates to:
  /// **'DealGo support reassigned the ride.'**
  String get driverRideUnassignedOps;

  /// No description provided for @driverRideUnassignedGeneric.
  ///
  /// In en, this message translates to:
  /// **'The ride was reopened for new offers.'**
  String get driverRideUnassignedGeneric;

  /// No description provided for @driverFoodDeliveryCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery code'**
  String get driverFoodDeliveryCodeTitle;

  /// No description provided for @driverFoodDeliveryCodeBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the customer\'s 4-digit code.'**
  String get driverFoodDeliveryCodeBody;

  /// No description provided for @driverFoodHandoverCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Handover code'**
  String get driverFoodHandoverCodeTitle;

  /// No description provided for @driverFoodHandoverCodeBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the store\'s 4-digit code.'**
  String get driverFoodHandoverCodeBody;

  /// No description provided for @driverFoodCodeWrong.
  ///
  /// In en, this message translates to:
  /// **'That code doesn\'t match. Check again.'**
  String get driverFoodCodeWrong;

  /// No description provided for @driverFoodCodeLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong codes. Contact support about this order.'**
  String get driverFoodCodeLocked;

  /// No description provided for @driverFoodCodeSubmit.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get driverFoodCodeSubmit;

  /// No description provided for @foodDeliveryCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery code'**
  String get foodDeliveryCodeTitle;

  /// No description provided for @foodDeliveryCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Tell the driver this code on delivery.'**
  String get foodDeliveryCodeHint;

  /// No description provided for @merchantHandoverCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Handover code'**
  String get merchantHandoverCodeLabel;

  /// No description provided for @merchantHandoverCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Tell the driver this code at pickup.'**
  String get merchantHandoverCodeHint;

  /// No description provided for @accountDeleteRow.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDeleteRow;

  /// No description provided for @accountDeleteRowBody.
  ///
  /// In en, this message translates to:
  /// **'Request permanent deletion of your DealGo account'**
  String get accountDeleteRowBody;

  /// No description provided for @deleteAccountHeader.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountHeader;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Request account deletion'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountWarnTitle.
  ///
  /// In en, this message translates to:
  /// **'Please note'**
  String get deleteAccountWarnTitle;

  /// No description provided for @deleteAccountWarnBody.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get deleteAccountWarnBody;

  /// No description provided for @deleteAccountWhatHappens.
  ///
  /// In en, this message translates to:
  /// **'What will happen?'**
  String get deleteAccountWhatHappens;

  /// No description provided for @deleteAccountNoLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'You can\'t sign in'**
  String get deleteAccountNoLoginTitle;

  /// No description provided for @deleteAccountNoLoginBody.
  ///
  /// In en, this message translates to:
  /// **'You will no longer be able to use this account'**
  String get deleteAccountNoLoginBody;

  /// No description provided for @deleteAccountDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Account data'**
  String get deleteAccountDataTitle;

  /// No description provided for @deleteAccountHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction history'**
  String get deleteAccountHistoryTitle;

  /// No description provided for @deleteAccountHistoryBody.
  ///
  /// In en, this message translates to:
  /// **'Some records may have to be kept by law'**
  String get deleteAccountHistoryBody;

  /// No description provided for @deleteAccountBefore.
  ///
  /// In en, this message translates to:
  /// **'Before you submit'**
  String get deleteAccountBefore;

  /// No description provided for @deleteAccountCheckNoJobs.
  ///
  /// In en, this message translates to:
  /// **'No ride or order in progress'**
  String get deleteAccountCheckNoJobs;

  /// No description provided for @deleteAccountCheckBackup.
  ///
  /// In en, this message translates to:
  /// **'I have saved the information I need'**
  String get deleteAccountCheckBackup;

  /// No description provided for @deleteAccountTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type XÓA to confirm'**
  String get deleteAccountTypeLabel;

  /// No description provided for @deleteAccountTypeHint.
  ///
  /// In en, this message translates to:
  /// **'XÓA'**
  String get deleteAccountTypeHint;

  /// No description provided for @deleteAccountContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get deleteAccountContinue;

  /// No description provided for @deleteAccountKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep account'**
  String get deleteAccountKeep;

  /// No description provided for @deleteAccountVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify it\'s you'**
  String get deleteAccountVerifyTitle;

  /// No description provided for @deleteAccountPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to confirm.'**
  String get deleteAccountPasswordBody;

  /// No description provided for @deleteAccountPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get deleteAccountPasswordLabel;

  /// No description provided for @deleteAccountCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get deleteAccountCodeLabel;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm deletion'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteAccountRestart.
  ///
  /// In en, this message translates to:
  /// **'Start again'**
  String get deleteAccountRestart;

  /// No description provided for @deleteAccountDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Deletion requested'**
  String get deleteAccountDoneTitle;

  /// No description provided for @deleteAccountDoneAction.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get deleteAccountDoneAction;

  /// No description provided for @deleteAccountLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load account deletion details.'**
  String get deleteAccountLoadError;

  /// No description provided for @deleteAccountReauthUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This account can\'t be re-verified in the app yet. Please contact support.'**
  String get deleteAccountReauthUnavailable;

  /// No description provided for @deleteAccountWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password.'**
  String get deleteAccountWrongPassword;

  /// No description provided for @deleteAccountWrongCode.
  ///
  /// In en, this message translates to:
  /// **'Wrong verification code.'**
  String get deleteAccountWrongCode;

  /// No description provided for @deleteAccountLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts. Start again.'**
  String get deleteAccountLocked;

  /// Delete account: button that opens the native passkey prompt again
  ///
  /// In en, this message translates to:
  /// **'Verify passkey'**
  String get deleteAccountPasskeyVerify;

  /// No description provided for @deleteAccountWrongPasskey.
  ///
  /// In en, this message translates to:
  /// **'Passkey verification failed.'**
  String get deleteAccountWrongPasskey;

  /// No description provided for @deleteAccountExpired.
  ///
  /// In en, this message translates to:
  /// **'The request expired. Start again.'**
  String get deleteAccountExpired;

  /// No description provided for @deleteBlockerOps.
  ///
  /// In en, this message translates to:
  /// **'Operations staff accounts can\'t be deleted in the app. Contact your administrator.'**
  String get deleteBlockerOps;

  /// No description provided for @apiErrAccountDeleted.
  ///
  /// In en, this message translates to:
  /// **'This account has been deleted. To restore it, contact DealGo support during the waiting period.'**
  String get apiErrAccountDeleted;

  /// No description provided for @deleteAccountDataBody.
  ///
  /// In en, this message translates to:
  /// **'Personal data is permanently erased after {days} days'**
  String deleteAccountDataBody(int days);

  /// No description provided for @deleteAccountCodeBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to {phone}.'**
  String deleteAccountCodeBody(String phone);

  /// No description provided for @deleteAccountDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Your account is locked and signed out on every device. Personal data will be permanently erased on {date}. If you change your mind, contact support before then.'**
  String deleteAccountDoneBody(String date);

  /// No description provided for @deleteBlockerRide.
  ///
  /// In en, this message translates to:
  /// **'You have {count} ride(s) in progress.'**
  String deleteBlockerRide(int count);

  /// No description provided for @deleteBlockerFood.
  ///
  /// In en, this message translates to:
  /// **'You have {count} food order(s) in progress.'**
  String deleteBlockerFood(int count);

  /// No description provided for @deleteBlockerDriver.
  ///
  /// In en, this message translates to:
  /// **'You have {count} driver job(s) in progress.'**
  String deleteBlockerDriver(int count);

  /// No description provided for @deleteBlockerStore.
  ///
  /// In en, this message translates to:
  /// **'Your store has {count} open order(s).'**
  String deleteBlockerStore(int count);

  /// No description provided for @deleteBlockerCod.
  ///
  /// In en, this message translates to:
  /// **'{amount} of cash-job platform fees are not yet settled with DealGo.'**
  String deleteBlockerCod(String amount);

  /// No description provided for @accountNotifPrefs.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get accountNotifPrefs;

  /// No description provided for @accountNotifPrefsBody.
  ///
  /// In en, this message translates to:
  /// **'Choose which updates you want'**
  String get accountNotifPrefsBody;

  /// No description provided for @accountSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security & privacy'**
  String get accountSecurity;

  /// No description provided for @accountSecurityBody.
  ///
  /// In en, this message translates to:
  /// **'Sign-in, devices and account deletion'**
  String get accountSecurityBody;

  /// No description provided for @editProfileHeader.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfileHeader;

  /// No description provided for @editProfileChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change profile photo'**
  String get editProfileChangePhoto;

  /// No description provided for @editProfileName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get editProfileName;

  /// No description provided for @editProfilePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get editProfilePhone;

  /// No description provided for @editProfilePhoneLocked.
  ///
  /// In en, this message translates to:
  /// **'Verified phone; it can\'t be changed here.'**
  String get editProfilePhoneLocked;

  /// No description provided for @editProfileEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get editProfileEmail;

  /// No description provided for @editProfileDob.
  ///
  /// In en, this message translates to:
  /// **'Date of birth (optional)'**
  String get editProfileDob;

  /// No description provided for @editProfileGender.
  ///
  /// In en, this message translates to:
  /// **'Gender (optional)'**
  String get editProfileGender;

  /// No description provided for @editProfileGenderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get editProfileGenderMale;

  /// No description provided for @editProfileGenderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get editProfileGenderFemale;

  /// No description provided for @editProfileGenderOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get editProfileGenderOther;

  /// No description provided for @editProfileSave.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get editProfileSave;

  /// No description provided for @editProfileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get editProfileSaved;

  /// No description provided for @notifPrefsHeader.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notifPrefsHeader;

  /// No description provided for @notifPrefsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your notifications'**
  String get notifPrefsTitle;

  /// No description provided for @notifPrefsPushOn.
  ///
  /// In en, this message translates to:
  /// **'Push notifications are on'**
  String get notifPrefsPushOn;

  /// No description provided for @notifPrefsImportant.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get notifPrefsImportant;

  /// No description provided for @notifPrefsRide.
  ///
  /// In en, this message translates to:
  /// **'Rides'**
  String get notifPrefsRide;

  /// No description provided for @notifPrefsRideBody.
  ///
  /// In en, this message translates to:
  /// **'Driver accepts, arrives and completes'**
  String get notifPrefsRideBody;

  /// No description provided for @notifPrefsFood.
  ///
  /// In en, this message translates to:
  /// **'Food and orders'**
  String get notifPrefsFood;

  /// No description provided for @notifPrefsFoodBody.
  ///
  /// In en, this message translates to:
  /// **'Confirm, prepare and deliver'**
  String get notifPrefsFoodBody;

  /// No description provided for @notifPrefsChat.
  ///
  /// In en, this message translates to:
  /// **'Messages and calls'**
  String get notifPrefsChat;

  /// No description provided for @notifPrefsChatBody.
  ///
  /// In en, this message translates to:
  /// **'Messages from people on your trips/orders'**
  String get notifPrefsChatBody;

  /// No description provided for @notifPrefsNewJobSound.
  ///
  /// In en, this message translates to:
  /// **'New job sound'**
  String get notifPrefsNewJobSound;

  /// No description provided for @notifPrefsNewJobSoundBody.
  ///
  /// In en, this message translates to:
  /// **'Say \"DealGo, new job\" on new jobs.'**
  String get notifPrefsNewJobSoundBody;

  /// No description provided for @notifPrefsOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get notifPrefsOther;

  /// No description provided for @notifPrefsPromo.
  ///
  /// In en, this message translates to:
  /// **'Offers and promotions'**
  String get notifPrefsPromo;

  /// No description provided for @notifPrefsPromoBody.
  ///
  /// In en, this message translates to:
  /// **'Discount codes and new campaigns'**
  String get notifPrefsPromoBody;

  /// No description provided for @notifPrefsNews.
  ///
  /// In en, this message translates to:
  /// **'DealGo news'**
  String get notifPrefsNews;

  /// No description provided for @notifPrefsNewsBody.
  ///
  /// In en, this message translates to:
  /// **'Service and feature updates'**
  String get notifPrefsNewsBody;

  /// No description provided for @notifPrefsMandatory.
  ///
  /// In en, this message translates to:
  /// **'Some required transaction or security updates are still sent to protect your account.'**
  String get notifPrefsMandatory;

  /// No description provided for @notifPrefsSave.
  ///
  /// In en, this message translates to:
  /// **'Save settings'**
  String get notifPrefsSave;

  /// No description provided for @notifPrefsSaved.
  ///
  /// In en, this message translates to:
  /// **'Notification settings saved'**
  String get notifPrefsSaved;

  /// No description provided for @securityHeader.
  ///
  /// In en, this message translates to:
  /// **'Security & privacy'**
  String get securityHeader;

  /// No description provided for @securityTitle.
  ///
  /// In en, this message translates to:
  /// **'Account safety'**
  String get securityTitle;

  /// No description provided for @securityProtected.
  ///
  /// In en, this message translates to:
  /// **'Account is protected'**
  String get securityProtected;

  /// No description provided for @securityLoginSection.
  ///
  /// In en, this message translates to:
  /// **'Sign-in and verification'**
  String get securityLoginSection;

  /// No description provided for @securityPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get securityPhone;

  /// No description provided for @securityVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get securityVerified;

  /// No description provided for @securityEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get securityEmail;

  /// No description provided for @securityPasskey.
  ///
  /// In en, this message translates to:
  /// **'Passkey'**
  String get securityPasskey;

  /// No description provided for @securitySessions.
  ///
  /// In en, this message translates to:
  /// **'Devices and sessions'**
  String get securitySessions;

  /// No description provided for @securityChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get securityChangePassword;

  /// No description provided for @securityPrivacySection.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get securityPrivacySection;

  /// No description provided for @securityPermissions.
  ///
  /// In en, this message translates to:
  /// **'App permissions'**
  String get securityPermissions;

  /// No description provided for @securityTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms & personal data'**
  String get securityTerms;

  /// No description provided for @securityAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account management'**
  String get securityAccountSection;

  /// No description provided for @securityDelete.
  ///
  /// In en, this message translates to:
  /// **'Request account deletion'**
  String get securityDelete;

  /// No description provided for @changePasswordHeader.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordHeader;

  /// No description provided for @changePasswordCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get changePasswordCurrent;

  /// No description provided for @changePasswordNew.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get changePasswordNew;

  /// No description provided for @changePasswordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get changePasswordConfirm;

  /// No description provided for @changePasswordSave.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get changePasswordSave;

  /// No description provided for @changePasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'New passwords do not match.'**
  String get changePasswordMismatch;

  /// No description provided for @changePasswordDone.
  ///
  /// In en, this message translates to:
  /// **'Password updated'**
  String get changePasswordDone;

  /// No description provided for @sessionsHeader.
  ///
  /// In en, this message translates to:
  /// **'Signed-in devices'**
  String get sessionsHeader;

  /// No description provided for @sessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Active sessions'**
  String get sessionsTitle;

  /// No description provided for @sessionsWarn.
  ///
  /// In en, this message translates to:
  /// **'If you see an unknown device, sign it out and check your verification methods.'**
  String get sessionsWarn;

  /// No description provided for @sessionsCurrent.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get sessionsCurrent;

  /// No description provided for @sessionsThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get sessionsThisDevice;

  /// No description provided for @sessionsOthers.
  ///
  /// In en, this message translates to:
  /// **'Other sessions'**
  String get sessionsOthers;

  /// No description provided for @sessionsLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get sessionsLogout;

  /// No description provided for @sessionsLogoutOthers.
  ///
  /// In en, this message translates to:
  /// **'Sign out all other devices'**
  String get sessionsLogoutOthers;

  /// No description provided for @sessionsEmptyOthers.
  ///
  /// In en, this message translates to:
  /// **'No other devices are signed in.'**
  String get sessionsEmptyOthers;

  /// No description provided for @sessionsRevoked.
  ///
  /// In en, this message translates to:
  /// **'Device signed out'**
  String get sessionsRevoked;

  /// No description provided for @merchantHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Order history'**
  String get merchantHistoryTitle;

  /// No description provided for @merchantHistoryHeadline.
  ///
  /// In en, this message translates to:
  /// **'Order history'**
  String get merchantHistoryHeadline;

  /// No description provided for @merchantHistorySearch.
  ///
  /// In en, this message translates to:
  /// **'Search by order id or customer'**
  String get merchantHistorySearch;

  /// No description provided for @merchantHistoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get merchantHistoryAll;

  /// No description provided for @merchantHistoryDone.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get merchantHistoryDone;

  /// No description provided for @merchantHistoryCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get merchantHistoryCancelled;

  /// No description provided for @merchantHistoryRevenue.
  ///
  /// In en, this message translates to:
  /// **'Completed revenue: {amount}'**
  String merchantHistoryRevenue(String amount);

  /// No description provided for @merchantHistoryList.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get merchantHistoryList;

  /// No description provided for @merchantHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No finished orders yet'**
  String get merchantHistoryEmpty;

  /// No description provided for @merchantCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get merchantCategoriesTitle;

  /// No description provided for @merchantCategoriesHeadline.
  ///
  /// In en, this message translates to:
  /// **'Manage categories'**
  String get merchantCategoriesHeadline;

  /// No description provided for @merchantCategoriesSearch.
  ///
  /// In en, this message translates to:
  /// **'Search categories'**
  String get merchantCategoriesSearch;

  /// No description provided for @merchantCategoriesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} categories'**
  String merchantCategoriesCount(String count);

  /// No description provided for @merchantCategoriesItemsOnSale.
  ///
  /// In en, this message translates to:
  /// **'{count} items on sale'**
  String merchantCategoriesItemsOnSale(String count);

  /// No description provided for @merchantCategoriesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add category +'**
  String get merchantCategoriesAdd;

  /// No description provided for @merchantCategoriesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get merchantCategoriesEmpty;

  /// No description provided for @merchantCategoryName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get merchantCategoryName;

  /// No description provided for @merchantCategoryDesc.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get merchantCategoryDesc;

  /// No description provided for @merchantItemEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Add / edit item'**
  String get merchantItemEditTitle;

  /// No description provided for @merchantItemInfo.
  ///
  /// In en, this message translates to:
  /// **'PRODUCT INFO'**
  String get merchantItemInfo;

  /// No description provided for @merchantItemCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get merchantItemCategory;

  /// No description provided for @merchantItemDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get merchantItemDescription;

  /// No description provided for @merchantItemPrep.
  ///
  /// In en, this message translates to:
  /// **'Prep time (minutes)'**
  String get merchantItemPrep;

  /// No description provided for @merchantItemVisible.
  ///
  /// In en, this message translates to:
  /// **'Visible to customers'**
  String get merchantItemVisible;

  /// No description provided for @merchantItemVisibleBody.
  ///
  /// In en, this message translates to:
  /// **'Allow customers to order now'**
  String get merchantItemVisibleBody;

  /// No description provided for @merchantItemContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue: Size & topping'**
  String get merchantItemContinue;

  /// No description provided for @merchantItemSaved.
  ///
  /// In en, this message translates to:
  /// **'Item saved'**
  String get merchantItemSaved;

  /// No description provided for @merchantProductsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get merchantProductsEdit;

  /// No description provided for @merchantProductsCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get merchantProductsCategories;

  /// No description provided for @merchantProductsHistory.
  ///
  /// In en, this message translates to:
  /// **'Order history'**
  String get merchantProductsHistory;

  /// No description provided for @merchantItemPhoto.
  ///
  /// In en, this message translates to:
  /// **'Item photo'**
  String get merchantItemPhoto;

  /// No description provided for @merchantItemPhotoPick.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get merchantItemPhotoPick;

  /// No description provided for @merchantItemPhotoUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading photo…'**
  String get merchantItemPhotoUploading;

  /// No description provided for @merchantItemPhotoClear.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get merchantItemPhotoClear;

  /// No description provided for @merchantItemPhotoError.
  ///
  /// In en, this message translates to:
  /// **'Could not upload the photo. Try again.'**
  String get merchantItemPhotoError;

  /// No description provided for @merchantCategoriesReordered.
  ///
  /// In en, this message translates to:
  /// **'Category order saved'**
  String get merchantCategoriesReordered;

  /// No description provided for @merchantProductsSoldCount.
  ///
  /// In en, this message translates to:
  /// **'Sold {count}'**
  String merchantProductsSoldCount(String count);

  /// No description provided for @merchantProductsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search items'**
  String get merchantProductsSearch;

  /// No description provided for @merchantProductsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get merchantProductsFilterAll;

  /// No description provided for @merchantProductsFilterOnSale.
  ///
  /// In en, this message translates to:
  /// **'On sale'**
  String get merchantProductsFilterOnSale;

  /// No description provided for @merchantProductsFilterHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden / draft'**
  String get merchantProductsFilterHidden;

  /// No description provided for @merchantProductsEmptyFilter.
  ///
  /// In en, this message translates to:
  /// **'No items match this filter'**
  String get merchantProductsEmptyFilter;

  /// No description provided for @merchantProductsEmptyMenu.
  ///
  /// In en, this message translates to:
  /// **'No items yet. Tap “Add item” to start selling.'**
  String get merchantProductsEmptyMenu;

  /// No description provided for @merchantOptionsChoiceMaxQty.
  ///
  /// In en, this message translates to:
  /// **'Max quantity per line'**
  String get merchantOptionsChoiceMaxQty;

  /// No description provided for @merchantOptionsMaxQty.
  ///
  /// In en, this message translates to:
  /// **'Max ×{count}'**
  String merchantOptionsMaxQty(String count);

  /// No description provided for @merchantCategoriesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search categories'**
  String get merchantCategoriesSearchHint;

  /// No description provided for @merchantEditStatusHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden / draft — not visible to customers'**
  String get merchantEditStatusHidden;

  /// No description provided for @merchantEditStatusOnSale.
  ///
  /// In en, this message translates to:
  /// **'On sale'**
  String get merchantEditStatusOnSale;

  /// No description provided for @merchantLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Store location'**
  String get merchantLocationTitle;

  /// No description provided for @merchantLocationUnset.
  ///
  /// In en, this message translates to:
  /// **'No pin set — store is hidden.'**
  String get merchantLocationUnset;

  /// No description provided for @merchantLocationPinNow.
  ///
  /// In en, this message translates to:
  /// **'Pin now'**
  String get merchantLocationPinNow;

  /// No description provided for @merchantLocationUnsetValue.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get merchantLocationUnsetValue;

  /// No description provided for @merchantLocationPickHint.
  ///
  /// In en, this message translates to:
  /// **'Pick on map'**
  String get merchantLocationPickHint;

  /// No description provided for @merchantLocationPendingHint.
  ///
  /// In en, this message translates to:
  /// **'Not saved — tap Save location'**
  String get merchantLocationPendingHint;

  /// No description provided for @merchantLocationSave.
  ///
  /// In en, this message translates to:
  /// **'Save location'**
  String get merchantLocationSave;

  /// No description provided for @merchantLocationSaved.
  ///
  /// In en, this message translates to:
  /// **'Store location saved.'**
  String get merchantLocationSaved;

  /// No description provided for @placePickerStoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Store location'**
  String get placePickerStoreTitle;

  /// No description provided for @accountStoreLocationBody.
  ///
  /// In en, this message translates to:
  /// **'Pickup point for drivers'**
  String get accountStoreLocationBody;

  /// No description provided for @forgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordLink;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to get a 6-digit code.'**
  String get forgotPasswordIntro;

  /// No description provided for @forgotPasswordSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get forgotPasswordSendCode;

  /// No description provided for @forgotPasswordCodeSent.
  ///
  /// In en, this message translates to:
  /// **'If {email} has a password account, a 6-digit code was sent to it. The code is valid for a few minutes.'**
  String forgotPasswordCodeSent(String email);

  /// No description provided for @forgotPasswordCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code from the email'**
  String get forgotPasswordCodeLabel;

  /// No description provided for @forgotPasswordNewLabel.
  ///
  /// In en, this message translates to:
  /// **'New password (6+ chars)'**
  String get forgotPasswordNewLabel;

  /// No description provided for @forgotPasswordConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat the new password'**
  String get forgotPasswordConfirmLabel;

  /// No description provided for @forgotPasswordSubmit.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get forgotPasswordSubmit;

  /// No description provided for @forgotPasswordResend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get forgotPasswordResend;

  /// No description provided for @forgotPasswordResent.
  ///
  /// In en, this message translates to:
  /// **'A new code was sent. The old code no longer works.'**
  String get forgotPasswordResent;

  /// No description provided for @forgotPasswordDone.
  ///
  /// In en, this message translates to:
  /// **'Your password was reset and older sessions were signed out. Sign in with the new password.'**
  String get forgotPasswordDone;

  /// No description provided for @forgotPasswordErrCode.
  ///
  /// In en, this message translates to:
  /// **'Enter all 6 digits of the code.'**
  String get forgotPasswordErrCode;

  /// No description provided for @forgotPasswordErrCooldown.
  ///
  /// In en, this message translates to:
  /// **'Please wait a moment before requesting another code.'**
  String get forgotPasswordErrCooldown;

  /// No description provided for @forgotPasswordErrResendLimit.
  ///
  /// In en, this message translates to:
  /// **'Too many codes were sent. Please start again.'**
  String get forgotPasswordErrResendLimit;

  /// No description provided for @forgotPasswordStartOver.
  ///
  /// In en, this message translates to:
  /// **'Start again'**
  String get forgotPasswordStartOver;

  /// No description provided for @securityPasskeyAdded.
  ///
  /// In en, this message translates to:
  /// **'Passkey added to your account.'**
  String get securityPasskeyAdded;

  /// No description provided for @securityPasskeyUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This device or app version does not support passkeys yet.'**
  String get securityPasskeyUnsupported;

  /// No description provided for @securityPasskeyExists.
  ///
  /// In en, this message translates to:
  /// **'This device already has a passkey for your account.'**
  String get securityPasskeyExists;

  /// No description provided for @securityPasskeyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add the passkey. Please try again.'**
  String get securityPasskeyFailed;

  /// No description provided for @securityPasskeyNeedsVerifiedLogin.
  ///
  /// In en, this message translates to:
  /// **'Verify your account before adding a passkey.'**
  String get securityPasskeyNeedsVerifiedLogin;

  /// No description provided for @merchantProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Store profile'**
  String get merchantProfileTitle;

  /// No description provided for @merchantProfileName.
  ///
  /// In en, this message translates to:
  /// **'Store name'**
  String get merchantProfileName;

  /// No description provided for @merchantProfileNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Store name must be 2 to 120 characters.'**
  String get merchantProfileNameInvalid;

  /// No description provided for @merchantProfileCategory.
  ///
  /// In en, this message translates to:
  /// **'Store category'**
  String get merchantProfileCategory;

  /// No description provided for @merchantProfileSave.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get merchantProfileSave;

  /// No description provided for @merchantProfileSaved.
  ///
  /// In en, this message translates to:
  /// **'Store profile saved.'**
  String get merchantProfileSaved;

  /// No description provided for @merchantProfileLogo.
  ///
  /// In en, this message translates to:
  /// **'Store logo'**
  String get merchantProfileLogo;

  /// No description provided for @merchantProfileLogoAdd.
  ///
  /// In en, this message translates to:
  /// **'Add logo'**
  String get merchantProfileLogoAdd;

  /// No description provided for @merchantProfileLogoChange.
  ///
  /// In en, this message translates to:
  /// **'Change logo'**
  String get merchantProfileLogoChange;

  /// No description provided for @merchantProfileLogoRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove logo'**
  String get merchantProfileLogoRemove;

  /// No description provided for @merchantProfileLogoSaved.
  ///
  /// In en, this message translates to:
  /// **'Logo updated.'**
  String get merchantProfileLogoSaved;

  /// No description provided for @merchantProfileLogoRemoved.
  ///
  /// In en, this message translates to:
  /// **'Logo removed.'**
  String get merchantProfileLogoRemoved;

  /// No description provided for @accountStoreProfileBody.
  ///
  /// In en, this message translates to:
  /// **'Store name, category and logo'**
  String get accountStoreProfileBody;

  /// No description provided for @foodReorderConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reorder this order?'**
  String get foodReorderConfirmTitle;

  /// No description provided for @foodReorderConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Add items at current prices?'**
  String get foodReorderConfirmBody;

  /// No description provided for @actionReorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get actionReorder;

  /// No description provided for @foodReorderNone.
  ///
  /// In en, this message translates to:
  /// **'None of the old order\'s dishes are available now'**
  String get foodReorderNone;

  /// No description provided for @foodReorderPartial.
  ///
  /// In en, this message translates to:
  /// **'{count} unavailable item(s) were left out'**
  String foodReorderPartial(int count);

  /// No description provided for @kycQuickModeBanner.
  ///
  /// In en, this message translates to:
  /// **'Quick sign-up, no documents.'**
  String get kycQuickModeBanner;

  /// No description provided for @kybQuickModeBanner.
  ///
  /// In en, this message translates to:
  /// **'Quick sign-up, no documents.'**
  String get kybQuickModeBanner;

  /// No description provided for @handoverRefLabel.
  ///
  /// In en, this message translates to:
  /// **'Handover code'**
  String get handoverRefLabel;

  /// No description provided for @handoverRefSemantics.
  ///
  /// In en, this message translates to:
  /// **'Handover code {ref}'**
  String handoverRefSemantics(String ref);

  /// No description provided for @rideRebookAction.
  ///
  /// In en, this message translates to:
  /// **'Rebook ride'**
  String get rideRebookAction;

  /// No description provided for @trackEtaMinutes.
  ///
  /// In en, this message translates to:
  /// **'≈{minutes} min'**
  String trackEtaMinutes(int minutes);

  /// No description provided for @trackStepFinding.
  ///
  /// In en, this message translates to:
  /// **'Finding'**
  String get trackStepFinding;

  /// No description provided for @trackStepComing.
  ///
  /// In en, this message translates to:
  /// **'Coming'**
  String get trackStepComing;

  /// No description provided for @trackStepArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get trackStepArrived;

  /// No description provided for @trackStepOnTrip.
  ///
  /// In en, this message translates to:
  /// **'On trip'**
  String get trackStepOnTrip;

  /// No description provided for @trackStepDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get trackStepDone;

  /// No description provided for @trackStepPlaced.
  ///
  /// In en, this message translates to:
  /// **'Placed'**
  String get trackStepPlaced;

  /// No description provided for @trackStepPreparing.
  ///
  /// In en, this message translates to:
  /// **'Cooking'**
  String get trackStepPreparing;

  /// No description provided for @trackStepReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get trackStepReady;

  /// No description provided for @trackStepDriverToStore.
  ///
  /// In en, this message translates to:
  /// **'Driver to store'**
  String get trackStepDriverToStore;

  /// No description provided for @trackStepDelivering.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get trackStepDelivering;

  /// No description provided for @trackStepDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get trackStepDelivered;

  /// No description provided for @trackItemsMore.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String trackItemsMore(int count);

  /// No description provided for @foodStageFindingDriver.
  ///
  /// In en, this message translates to:
  /// **'Finding a driver'**
  String get foodStageFindingDriver;

  /// No description provided for @foodStageDriverToStore.
  ///
  /// In en, this message translates to:
  /// **'Driver heading to the store'**
  String get foodStageDriverToStore;

  /// No description provided for @foodStageDeliveringToYou.
  ///
  /// In en, this message translates to:
  /// **'Driver is on the way to you'**
  String get foodStageDeliveringToYou;

  /// No description provided for @accountSignOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get accountSignOutConfirmTitle;

  /// No description provided for @accountSignOutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need to sign in again.'**
  String get accountSignOutConfirmBody;

  /// No description provided for @accountSignOutCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get accountSignOutCancel;

  /// No description provided for @rideOfferConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose this driver?'**
  String get rideOfferConfirmTitle;

  /// No description provided for @rideOfferConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Fare {amount}.'**
  String rideOfferConfirmBody(String amount);

  /// No description provided for @rideOfferConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Choose driver'**
  String get rideOfferConfirmAction;

  /// No description provided for @rideOfferConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get rideOfferConfirmCancel;

  /// No description provided for @rideRaiseFare.
  ///
  /// In en, this message translates to:
  /// **'Raise fare'**
  String get rideRaiseFare;

  /// No description provided for @rideRaiseFareTitle.
  ///
  /// In en, this message translates to:
  /// **'Raise your offer'**
  String get rideRaiseFareTitle;

  /// No description provided for @rideRaiseFareBody.
  ///
  /// In en, this message translates to:
  /// **'Current fare: {amount}'**
  String rideRaiseFareBody(String amount);

  /// No description provided for @rideRaiseFareStep.
  ///
  /// In en, this message translates to:
  /// **'+{amount}'**
  String rideRaiseFareStep(String amount);

  /// No description provided for @rideRaiseFareDone.
  ///
  /// In en, this message translates to:
  /// **'Fare raised to {amount}'**
  String rideRaiseFareDone(String amount);

  /// No description provided for @rideDeclineOffer.
  ///
  /// In en, this message translates to:
  /// **'Decline this price'**
  String get rideDeclineOffer;

  /// No description provided for @rideDeclineOfferDone.
  ///
  /// In en, this message translates to:
  /// **'Offer declined. The driver can send a new price.'**
  String get rideDeclineOfferDone;

  /// No description provided for @driverWithdrawOffer.
  ///
  /// In en, this message translates to:
  /// **'Withdraw offer'**
  String get driverWithdrawOffer;

  /// No description provided for @driverWithdrawOfferDone.
  ///
  /// In en, this message translates to:
  /// **'Offer withdrawn'**
  String get driverWithdrawOfferDone;

  /// No description provided for @driverCustomerRating.
  ///
  /// In en, this message translates to:
  /// **'Customer rating'**
  String get driverCustomerRating;

  /// No description provided for @driverCustomerRatingValue.
  ///
  /// In en, this message translates to:
  /// **'{average}★ ({count} ratings)'**
  String driverCustomerRatingValue(String average, int count);

  /// No description provided for @driverCustomerRatingNone.
  ///
  /// In en, this message translates to:
  /// **'No ratings yet'**
  String get driverCustomerRatingNone;

  /// No description provided for @driverCancelRide.
  ///
  /// In en, this message translates to:
  /// **'Cancel ride'**
  String get driverCancelRide;

  /// No description provided for @driverCancelReasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Why are you cancelling?'**
  String get driverCancelReasonTitle;

  /// No description provided for @driverCancelHint.
  ///
  /// In en, this message translates to:
  /// **'Counts toward your cancel rate.'**
  String get driverCancelHint;

  /// No description provided for @driverCancelReasonCustomerUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the customer'**
  String get driverCancelReasonCustomerUnreachable;

  /// No description provided for @driverCancelReasonPickupTooFar.
  ///
  /// In en, this message translates to:
  /// **'Pickup is too far'**
  String get driverCancelReasonPickupTooFar;

  /// No description provided for @driverCancelReasonVehicleProblem.
  ///
  /// In en, this message translates to:
  /// **'Vehicle problem'**
  String get driverCancelReasonVehicleProblem;

  /// No description provided for @driverCancelReasonSafetyConcern.
  ///
  /// In en, this message translates to:
  /// **'Safety concern'**
  String get driverCancelReasonSafetyConcern;

  /// No description provided for @driverCancelReasonCustomerAsked.
  ///
  /// In en, this message translates to:
  /// **'Customer asked to cancel'**
  String get driverCancelReasonCustomerAsked;

  /// No description provided for @driverCancelReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other reason'**
  String get driverCancelReasonOther;

  /// No description provided for @driverCancelDone.
  ///
  /// In en, this message translates to:
  /// **'Ride cancelled'**
  String get driverCancelDone;

  /// No description provided for @driverNoShow.
  ///
  /// In en, this message translates to:
  /// **'Customer didn\'t show'**
  String get driverNoShow;

  /// No description provided for @driverNoShowBody.
  ///
  /// In en, this message translates to:
  /// **'Use only after waiting at pickup.'**
  String get driverNoShowBody;

  /// No description provided for @driverNoShowDone.
  ///
  /// In en, this message translates to:
  /// **'No-show recorded. The ride is closed.'**
  String get driverNoShowDone;

  /// No description provided for @driverRateCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate the customer'**
  String get driverRateCustomerTitle;

  /// No description provided for @driverRateCustomerSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send rating'**
  String get driverRateCustomerSubmit;

  /// No description provided for @driverRateCustomerDone.
  ///
  /// In en, this message translates to:
  /// **'Rating sent – thank you!'**
  String get driverRateCustomerDone;

  /// No description provided for @driverRateCustomerYours.
  ///
  /// In en, this message translates to:
  /// **'Your rating: {stars}★'**
  String driverRateCustomerYours(int stars);

  /// No description provided for @driverRateTagOnTime.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get driverRateTagOnTime;

  /// No description provided for @driverRateTagPolite.
  ///
  /// In en, this message translates to:
  /// **'Polite'**
  String get driverRateTagPolite;

  /// No description provided for @driverRateTagClearPickup.
  ///
  /// In en, this message translates to:
  /// **'Clear pickup'**
  String get driverRateTagClearPickup;

  /// No description provided for @driverRateTagLate.
  ///
  /// In en, this message translates to:
  /// **'Kept me waiting'**
  String get driverRateTagLate;

  /// No description provided for @driverRateTagRude.
  ///
  /// In en, this message translates to:
  /// **'Rude'**
  String get driverRateTagRude;

  /// No description provided for @driverRateTagWrongPickup.
  ///
  /// In en, this message translates to:
  /// **'Wrong pickup point'**
  String get driverRateTagWrongPickup;

  /// No description provided for @driverFoodRelease.
  ///
  /// In en, this message translates to:
  /// **'Return order'**
  String get driverFoodRelease;

  /// No description provided for @driverFoodReleaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Why return this order?'**
  String get driverFoodReleaseTitle;

  /// No description provided for @driverFoodReleaseHint.
  ///
  /// In en, this message translates to:
  /// **'Releasing counts as a cancel.'**
  String get driverFoodReleaseHint;

  /// No description provided for @driverFoodReleaseStoreTooSlow.
  ///
  /// In en, this message translates to:
  /// **'Store is too slow'**
  String get driverFoodReleaseStoreTooSlow;

  /// No description provided for @driverFoodReleaseStoreClosed.
  ///
  /// In en, this message translates to:
  /// **'Store is closed'**
  String get driverFoodReleaseStoreClosed;

  /// No description provided for @driverFoodReleaseVehicleProblem.
  ///
  /// In en, this message translates to:
  /// **'Vehicle problem'**
  String get driverFoodReleaseVehicleProblem;

  /// No description provided for @driverFoodReleaseSafetyConcern.
  ///
  /// In en, this message translates to:
  /// **'Safety concern'**
  String get driverFoodReleaseSafetyConcern;

  /// No description provided for @driverFoodReleaseOther.
  ///
  /// In en, this message translates to:
  /// **'Other reason'**
  String get driverFoodReleaseOther;

  /// No description provided for @driverFoodReleaseDone.
  ///
  /// In en, this message translates to:
  /// **'Order returned'**
  String get driverFoodReleaseDone;

  /// No description provided for @driverFailNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Details (required)'**
  String get driverFailNoteLabel;

  /// No description provided for @driverFailNoteRequired.
  ///
  /// In en, this message translates to:
  /// **'Please describe what happened.'**
  String get driverFailNoteRequired;

  /// No description provided for @driverFailAbsentHint.
  ///
  /// In en, this message translates to:
  /// **'Call and text first, wait a few minutes.'**
  String get driverFailAbsentHint;

  /// No description provided for @driverFoodFailedDone.
  ///
  /// In en, this message translates to:
  /// **'Delivery reported as failed'**
  String get driverFoodFailedDone;

  /// No description provided for @apiErrLiveOffersFull.
  ///
  /// In en, this message translates to:
  /// **'This ride already has the maximum number of offers. Try again shortly.'**
  String get apiErrLiveOffersFull;

  /// No description provided for @apiErrFareRaiseLimit.
  ///
  /// In en, this message translates to:
  /// **'You can\'t raise the fare any more for this ride.'**
  String get apiErrFareRaiseLimit;

  /// No description provided for @apiErrCancelCooldown.
  ///
  /// In en, this message translates to:
  /// **'You\'ve cancelled several rides recently. Please wait a little before booking again.'**
  String get apiErrCancelCooldown;

  /// No description provided for @apiErrRepostInvalid.
  ///
  /// In en, this message translates to:
  /// **'This ride can\'t be reposted.'**
  String get apiErrRepostInvalid;

  /// No description provided for @apiErrFailTooEarly.
  ///
  /// In en, this message translates to:
  /// **'Wait at the drop-off a few more minutes before reporting the customer unreachable.'**
  String get apiErrFailTooEarly;

  /// No description provided for @apiErrFailNoteRequired.
  ///
  /// In en, this message translates to:
  /// **'Please add a note describing the problem.'**
  String get apiErrFailNoteRequired;

  /// No description provided for @apiErrStoreLocationRequired.
  ///
  /// In en, this message translates to:
  /// **'This store hasn\'t set its location yet.'**
  String get apiErrStoreLocationRequired;

  /// No description provided for @apiErrDriverLocationStale.
  ///
  /// In en, this message translates to:
  /// **'We don\'t have your current location yet. Turn on location and pull to refresh.'**
  String get apiErrDriverLocationStale;

  /// No description provided for @apiErrOutsideServiceZone.
  ///
  /// In en, this message translates to:
  /// **'This address is outside our service area.'**
  String get apiErrOutsideServiceZone;

  /// No description provided for @apiErrTooFar.
  ///
  /// In en, this message translates to:
  /// **'The delivery address is too far from this store.'**
  String get apiErrTooFar;

  /// No description provided for @apiErrSettlementOverlap.
  ///
  /// In en, this message translates to:
  /// **'This period overlaps an existing statement.'**
  String get apiErrSettlementOverlap;

  /// No description provided for @apiErrSettlementPeriodOpen.
  ///
  /// In en, this message translates to:
  /// **'This period hasn\'t ended yet.'**
  String get apiErrSettlementPeriodOpen;

  /// No description provided for @apiErrShopLocationRequired.
  ///
  /// In en, this message translates to:
  /// **'Pin your shop location on the map to continue.'**
  String get apiErrShopLocationRequired;

  /// No description provided for @apiErrChangePending.
  ///
  /// In en, this message translates to:
  /// **'There\'s already an order change waiting for the customer.'**
  String get apiErrChangePending;

  /// No description provided for @apiErrChangeInvalid.
  ///
  /// In en, this message translates to:
  /// **'This change isn\'t allowed. You can only lower quantities or remove items.'**
  String get apiErrChangeInvalid;

  /// No description provided for @apiErrChangeNotFound.
  ///
  /// In en, this message translates to:
  /// **'This change is no longer waiting for an answer.'**
  String get apiErrChangeNotFound;

  /// No description provided for @foodCancelChangeRejected.
  ///
  /// In en, this message translates to:
  /// **'You declined the store\'s change'**
  String get foodCancelChangeRejected;

  /// No description provided for @foodCancelChangeExpired.
  ///
  /// In en, this message translates to:
  /// **'The store\'s change wasn\'t answered in time'**
  String get foodCancelChangeExpired;

  /// No description provided for @foodChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Store changed order'**
  String get foodChangeTitle;

  /// No description provided for @foodChangeReasonOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Some items are sold out'**
  String get foodChangeReasonOutOfStock;

  /// No description provided for @foodChangeReasonNotEnough.
  ///
  /// In en, this message translates to:
  /// **'Not enough portions left'**
  String get foodChangeReasonNotEnough;

  /// No description provided for @foodChangeReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other reason'**
  String get foodChangeReasonOther;

  /// No description provided for @foodChangeLineRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get foodChangeLineRemoved;

  /// No description provided for @foodChangeNewTotal.
  ///
  /// In en, this message translates to:
  /// **'New total'**
  String get foodChangeNewTotal;

  /// No description provided for @foodChangeAnswerBy.
  ///
  /// In en, this message translates to:
  /// **'Answer by {time}, otherwise the order is cancelled for free.'**
  String foodChangeAnswerBy(String time);

  /// No description provided for @foodChangeAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get foodChangeAccept;

  /// No description provided for @foodChangeReject.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get foodChangeReject;

  /// No description provided for @foodChangeRejectConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this order?'**
  String get foodChangeRejectConfirmTitle;

  /// No description provided for @foodChangeRejectConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Order will be cancelled at no cost.'**
  String get foodChangeRejectConfirmBody;

  /// No description provided for @merchantEditOrder.
  ///
  /// In en, this message translates to:
  /// **'Report sold-out items'**
  String get merchantEditOrder;

  /// No description provided for @merchantEditOrderHint.
  ///
  /// In en, this message translates to:
  /// **'Customer must approve changes.'**
  String get merchantEditOrderHint;

  /// No description provided for @merchantEditOrderNote.
  ///
  /// In en, this message translates to:
  /// **'Note for the customer'**
  String get merchantEditOrderNote;

  /// No description provided for @merchantEditOrderAllRemoved.
  ///
  /// In en, this message translates to:
  /// **'To remove every item, reject the order instead.'**
  String get merchantEditOrderAllRemoved;

  /// No description provided for @merchantEditOrderNewSubtotal.
  ///
  /// In en, this message translates to:
  /// **'New food value: {amount}'**
  String merchantEditOrderNewSubtotal(String amount);

  /// No description provided for @merchantEditOrderSend.
  ///
  /// In en, this message translates to:
  /// **'Send to customer'**
  String get merchantEditOrderSend;

  /// No description provided for @merchantChangePending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the customer to accept the change (new total {total}) until {time}.'**
  String merchantChangePending(String total, String time);

  /// No description provided for @pushForegroundOpen.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get pushForegroundOpen;

  /// Short chip above the pickup pin on maps.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get mapPinPickup;

  /// No description provided for @mapPinDropoff.
  ///
  /// In en, this message translates to:
  /// **'Drop-off'**
  String get mapPinDropoff;

  /// No description provided for @mapPinStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get mapPinStore;

  /// No description provided for @mapPinHome.
  ///
  /// In en, this message translates to:
  /// **'Deliver'**
  String get mapPinHome;

  /// No description provided for @mapPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick on map'**
  String get mapPickerTitle;

  /// No description provided for @mapPickerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Use this location'**
  String get mapPickerConfirm;

  /// No description provided for @mapPickerPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned location'**
  String get mapPickerPinned;

  /// No description provided for @mapPickerSearch.
  ///
  /// In en, this message translates to:
  /// **'Search places'**
  String get mapPickerSearch;

  /// No description provided for @mapStyleTitle.
  ///
  /// In en, this message translates to:
  /// **'Map style'**
  String get mapStyleTitle;

  /// No description provided for @mapStyleStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get mapStyleStandard;

  /// No description provided for @mapStyleSatellite.
  ///
  /// In en, this message translates to:
  /// **'Satellite'**
  String get mapStyleSatellite;

  /// No description provided for @mapStyleDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get mapStyleDark;

  /// No description provided for @mapOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get mapOpenSettings;

  /// Screen-reader label of one home banner slide.
  ///
  /// In en, this message translates to:
  /// **'Banner {index} of {count}'**
  String homeBannerSlideLabel(int index, int count);

  /// No description provided for @foodStoreFeeFrom.
  ///
  /// In en, this message translates to:
  /// **'Delivery from {fee}'**
  String foodStoreFeeFrom(String fee);

  /// No description provided for @foodStoreOpenUntil.
  ///
  /// In en, this message translates to:
  /// **'Open until {time}'**
  String foodStoreOpenUntil(String time);

  /// No description provided for @foodOffersNearTitle.
  ///
  /// In en, this message translates to:
  /// **'Deals near you'**
  String get foodOffersNearTitle;

  /// No description provided for @foodStoreOffersTitle.
  ///
  /// In en, this message translates to:
  /// **'Store deals'**
  String get foodStoreOffersTitle;

  /// No description provided for @foodStoreOfferUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get foodStoreOfferUse;

  /// No description provided for @foodStoreOfferApplied.
  ///
  /// In en, this message translates to:
  /// **'Code {code} added to this order'**
  String foodStoreOfferApplied(String code);

  /// No description provided for @foodStoreSearchMenu.
  ///
  /// In en, this message translates to:
  /// **'Search this menu'**
  String get foodStoreSearchMenu;

  /// No description provided for @foodStoreSearchNone.
  ///
  /// In en, this message translates to:
  /// **'No matching dishes'**
  String get foodStoreSearchNone;

  /// No description provided for @foodStoreSectionOther.
  ///
  /// In en, this message translates to:
  /// **'More dishes'**
  String get foodStoreSectionOther;

  /// No description provided for @foodStoreReviewsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get foodStoreReviewsAll;

  /// No description provided for @foodStoreReviewsMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get foodStoreReviewsMore;

  /// No description provided for @foodStoreMerchantReply.
  ///
  /// In en, this message translates to:
  /// **'Store reply'**
  String get foodStoreMerchantReply;

  /// No description provided for @foodStoreReviewsFilterNone.
  ///
  /// In en, this message translates to:
  /// **'No matching reviews'**
  String get foodStoreReviewsFilterNone;

  /// No description provided for @foodItemSold.
  ///
  /// In en, this message translates to:
  /// **'{count} sold'**
  String foodItemSold(int count);

  /// No description provided for @foodItemOptionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} choices'**
  String foodItemOptionsCount(int count);

  /// No description provided for @merchantOffersTitle.
  ///
  /// In en, this message translates to:
  /// **'Store deals'**
  String get merchantOffersTitle;

  /// No description provided for @merchantOffersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No deals yet'**
  String get merchantOffersEmpty;

  /// No description provided for @merchantOffersCreate.
  ///
  /// In en, this message translates to:
  /// **'New deal'**
  String get merchantOffersCreate;

  /// No description provided for @merchantOfferNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New deal'**
  String get merchantOfferNewTitle;

  /// No description provided for @merchantOfferStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get merchantOfferStatusActive;

  /// No description provided for @merchantOfferStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get merchantOfferStatusPaused;

  /// No description provided for @merchantOfferStatusEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get merchantOfferStatusEnded;

  /// No description provided for @merchantOfferStatusUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get merchantOfferStatusUpcoming;

  /// No description provided for @merchantOfferPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get merchantOfferPause;

  /// No description provided for @merchantOfferResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get merchantOfferResume;

  /// No description provided for @merchantOfferEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get merchantOfferEnd;

  /// No description provided for @merchantOfferEndConfirm.
  ///
  /// In en, this message translates to:
  /// **'End {name}?'**
  String merchantOfferEndConfirm(String name);

  /// No description provided for @merchantOfferUsage.
  ///
  /// In en, this message translates to:
  /// **'Used {used}/{limit}'**
  String merchantOfferUsage(int used, int limit);

  /// No description provided for @merchantOfferLimitReached.
  ///
  /// In en, this message translates to:
  /// **'{count} deals already live'**
  String merchantOfferLimitReached(int count);

  /// No description provided for @merchantOfferFormName.
  ///
  /// In en, this message translates to:
  /// **'Deal name'**
  String get merchantOfferFormName;

  /// No description provided for @merchantOfferFormCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get merchantOfferFormCode;

  /// No description provided for @merchantOfferKindPercent.
  ///
  /// In en, this message translates to:
  /// **'Percent off'**
  String get merchantOfferKindPercent;

  /// No description provided for @merchantOfferKindFixed.
  ///
  /// In en, this message translates to:
  /// **'Amount off'**
  String get merchantOfferKindFixed;

  /// No description provided for @merchantOfferFormPercent.
  ///
  /// In en, this message translates to:
  /// **'Percent'**
  String get merchantOfferFormPercent;

  /// No description provided for @merchantOfferFormAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get merchantOfferFormAmount;

  /// No description provided for @merchantOfferFormMax.
  ///
  /// In en, this message translates to:
  /// **'Max discount'**
  String get merchantOfferFormMax;

  /// No description provided for @merchantOfferFormMinOrder.
  ///
  /// In en, this message translates to:
  /// **'Minimum order'**
  String get merchantOfferFormMinOrder;

  /// No description provided for @merchantOfferFormUsage.
  ///
  /// In en, this message translates to:
  /// **'Total uses'**
  String get merchantOfferFormUsage;

  /// No description provided for @merchantOfferFormPerUser.
  ///
  /// In en, this message translates to:
  /// **'Uses per customer'**
  String get merchantOfferFormPerUser;

  /// No description provided for @merchantOfferFormStart.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get merchantOfferFormStart;

  /// No description provided for @merchantOfferFormEnd.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get merchantOfferFormEnd;

  /// No description provided for @merchantOfferFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get merchantOfferFieldRequired;

  /// No description provided for @merchantOfferFieldInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid'**
  String get merchantOfferFieldInvalid;

  /// No description provided for @merchantOfferMinBelowValue.
  ///
  /// In en, this message translates to:
  /// **'Must be at least the discount'**
  String get merchantOfferMinBelowValue;

  /// No description provided for @merchantOfferSave.
  ///
  /// In en, this message translates to:
  /// **'Create deal'**
  String get merchantOfferSave;

  /// No description provided for @merchantReviewsTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer reviews'**
  String get merchantReviewsTitle;

  /// No description provided for @merchantReviewsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get merchantReviewsEmpty;

  /// No description provided for @merchantReviewHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get merchantReviewHidden;

  /// No description provided for @merchantReviewReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get merchantReviewReply;

  /// No description provided for @merchantReviewEditReply.
  ///
  /// In en, this message translates to:
  /// **'Edit reply'**
  String get merchantReviewEditReply;

  /// No description provided for @merchantReviewReplySend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get merchantReviewReplySend;

  /// No description provided for @merchantReviewReplyRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove reply'**
  String get merchantReviewReplyRemove;

  /// No description provided for @foodBadgeBestSeller.
  ///
  /// In en, this message translates to:
  /// **'Best seller'**
  String get foodBadgeBestSeller;

  /// No description provided for @foodBadgeNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get foodBadgeNew;

  /// No description provided for @foodStoreMinOrder.
  ///
  /// In en, this message translates to:
  /// **'Min. order {amount}'**
  String foodStoreMinOrder(String amount);

  /// No description provided for @foodCollectionNear.
  ///
  /// In en, this message translates to:
  /// **'Near you'**
  String get foodCollectionNear;

  /// No description provided for @foodCollectionTopRated.
  ///
  /// In en, this message translates to:
  /// **'Top rated'**
  String get foodCollectionTopRated;

  /// No description provided for @foodCollectionDeals.
  ///
  /// In en, this message translates to:
  /// **'On sale'**
  String get foodCollectionDeals;

  /// No description provided for @foodCollectionNewDishes.
  ///
  /// In en, this message translates to:
  /// **'New dishes'**
  String get foodCollectionNewDishes;

  /// No description provided for @foodEtaArriveAt.
  ///
  /// In en, this message translates to:
  /// **'Arrives around {time}'**
  String foodEtaArriveAt(String time);

  /// No description provided for @foodCartBarShortfall.
  ///
  /// In en, this message translates to:
  /// **'{amount} to go'**
  String foodCartBarShortfall(String amount);

  /// No description provided for @foodCartMinOrderMissing.
  ///
  /// In en, this message translates to:
  /// **'Add {amount} more to reach the minimum order'**
  String foodCartMinOrderMissing(String amount);

  /// No description provided for @foodStoreInfoHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get foodStoreInfoHours;

  /// No description provided for @foodStoreInfoMinOrder.
  ///
  /// In en, this message translates to:
  /// **'Minimum order'**
  String get foodStoreInfoMinOrder;

  /// No description provided for @foodStoreInfoNoMinOrder.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get foodStoreInfoNoMinOrder;

  /// No description provided for @foodStoreInfoPrep.
  ///
  /// In en, this message translates to:
  /// **'Prep time'**
  String get foodStoreInfoPrep;

  /// No description provided for @foodStoreTagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Customers say'**
  String get foodStoreTagsTitle;

  /// No description provided for @foodStoreSoldTotal.
  ///
  /// In en, this message translates to:
  /// **'{count}+ sold'**
  String foodStoreSoldTotal(int count);

  /// No description provided for @voucherSaveAmount.
  ///
  /// In en, this message translates to:
  /// **'Save {amount}'**
  String voucherSaveAmount(String amount);

  /// No description provided for @voucherBestPick.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get voucherBestPick;

  /// No description provided for @voucherNeedMore.
  ///
  /// In en, this message translates to:
  /// **'Add {amount} more'**
  String voucherNeedMore(String amount);

  /// No description provided for @voucherPickerApply.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get voucherPickerApply;

  /// No description provided for @checkoutErrMinOrder.
  ///
  /// In en, this message translates to:
  /// **'The order is below the store minimum'**
  String get checkoutErrMinOrder;

  /// No description provided for @merchantItemOriginalPrice.
  ///
  /// In en, this message translates to:
  /// **'Original price'**
  String get merchantItemOriginalPrice;

  /// No description provided for @merchantItemOriginalPriceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Original price must be above the price'**
  String get merchantItemOriginalPriceInvalid;

  /// No description provided for @merchantStoreMinOrder.
  ///
  /// In en, this message translates to:
  /// **'Minimum order'**
  String get merchantStoreMinOrder;

  /// No description provided for @merchantStoreMinOrderInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter 0 to 10,000,000'**
  String get merchantStoreMinOrderInvalid;

  /// Store card: delivery fee is 0
  ///
  /// In en, this message translates to:
  /// **'Free delivery'**
  String get foodStoreFeeFree;

  /// No description provided for @merchantProfileCover.
  ///
  /// In en, this message translates to:
  /// **'Cover photo'**
  String get merchantProfileCover;

  /// No description provided for @merchantProfileCoverAdd.
  ///
  /// In en, this message translates to:
  /// **'Add cover photo'**
  String get merchantProfileCoverAdd;

  /// No description provided for @merchantProfileCoverChange.
  ///
  /// In en, this message translates to:
  /// **'Change cover photo'**
  String get merchantProfileCoverChange;

  /// No description provided for @merchantProfileCoverRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove cover photo'**
  String get merchantProfileCoverRemove;

  /// No description provided for @merchantProfileCoverSaved.
  ///
  /// In en, this message translates to:
  /// **'Cover photo updated.'**
  String get merchantProfileCoverSaved;

  /// No description provided for @merchantProfileCoverRemoved.
  ///
  /// In en, this message translates to:
  /// **'Cover photo removed.'**
  String get merchantProfileCoverRemoved;

  /// No description provided for @merchantProfileDescription.
  ///
  /// In en, this message translates to:
  /// **'About the store'**
  String get merchantProfileDescription;

  /// No description provided for @foodStoreAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get foodStoreAbout;

  /// No description provided for @voucherCap.
  ///
  /// In en, this message translates to:
  /// **'Up to {amount}'**
  String voucherCap(String amount);

  /// No description provided for @voucherUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get voucherUsed;

  /// No description provided for @otpPasteChip.
  ///
  /// In en, this message translates to:
  /// **'Paste code {code}'**
  String otpPasteChip(String code);

  /// No description provided for @otpNoCodeYet.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t get the code?'**
  String get otpNoCodeYet;

  /// No description provided for @otpEmailSpamHint.
  ///
  /// In en, this message translates to:
  /// **'Can\'t find the email? Check your Spam or Promotions folder.'**
  String get otpEmailSpamHint;

  /// No description provided for @emailVerifyLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong codes. Resend to get a new code.'**
  String get emailVerifyLocked;

  /// No description provided for @emailVerifySuccess.
  ///
  /// In en, this message translates to:
  /// **'Email verified'**
  String get emailVerifySuccess;

  /// No description provided for @emailVerifyPendingNotice.
  ///
  /// In en, this message translates to:
  /// **'Your new email is saved only after you enter the verification code.'**
  String get emailVerifyPendingNotice;

  /// No description provided for @profileEmailUnverified.
  ///
  /// In en, this message translates to:
  /// **'Email not verified'**
  String get profileEmailUnverified;

  /// No description provided for @profileEmailVerifyAction.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get profileEmailVerifyAction;

  /// No description provided for @draftResumeTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue where you left off?'**
  String get draftResumeTitle;

  /// No description provided for @draftResumeBody.
  ///
  /// In en, this message translates to:
  /// **'We saved your progress on this device. Continue, or start over?'**
  String get draftResumeBody;

  /// No description provided for @draftResumeContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get draftResumeContinue;

  /// No description provided for @draftResumeDiscard.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get draftResumeDiscard;

  /// No description provided for @draftRestoredNote.
  ///
  /// In en, this message translates to:
  /// **'Restored your unsent draft.'**
  String get draftRestoredNote;

  /// No description provided for @rideStopNumbered.
  ///
  /// In en, this message translates to:
  /// **'Stop {n}'**
  String rideStopNumbered(int n);

  /// No description provided for @rideAddStop.
  ///
  /// In en, this message translates to:
  /// **'Add stop'**
  String get rideAddStop;

  /// No description provided for @rideRemoveStop.
  ///
  /// In en, this message translates to:
  /// **'Remove stop'**
  String get rideRemoveStop;

  /// No description provided for @rideMoveStopUp.
  ///
  /// In en, this message translates to:
  /// **'Move stop up'**
  String get rideMoveStopUp;

  /// No description provided for @rideStopsMax.
  ///
  /// In en, this message translates to:
  /// **'Up to {n} stops'**
  String rideStopsMax(int n);

  /// No description provided for @rideStopFeeNote.
  ///
  /// In en, this message translates to:
  /// **'Each stop adds {fee}'**
  String rideStopFeeNote(String fee);

  /// No description provided for @rideStopFeeLine.
  ///
  /// In en, this message translates to:
  /// **'Stop fee'**
  String get rideStopFeeLine;

  /// No description provided for @rideWaitFeeLine.
  ///
  /// In en, this message translates to:
  /// **'Waiting at stops'**
  String get rideWaitFeeLine;

  /// No description provided for @rideStopPending.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get rideStopPending;

  /// No description provided for @rideStopArrived.
  ///
  /// In en, this message translates to:
  /// **'Driver waiting'**
  String get rideStopArrived;

  /// No description provided for @rideStopDeparted.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get rideStopDeparted;

  /// No description provided for @rideStopsCount.
  ///
  /// In en, this message translates to:
  /// **'+{n} stops'**
  String rideStopsCount(int n);

  /// No description provided for @rideRouteChanged.
  ///
  /// In en, this message translates to:
  /// **'The customer changed the route. Review it and offer again.'**
  String get rideRouteChanged;

  /// No description provided for @rideStopsLocked.
  ///
  /// In en, this message translates to:
  /// **'Stops can only be changed before a driver is chosen.'**
  String get rideStopsLocked;

  /// No description provided for @rideStopsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Stops are not available for this service right now.'**
  String get rideStopsUnavailable;

  /// No description provided for @driverStopArrive.
  ///
  /// In en, this message translates to:
  /// **'Arrived at stop {n}'**
  String driverStopArrive(int n);

  /// No description provided for @driverStopDepart.
  ///
  /// In en, this message translates to:
  /// **'Leave stop {n}'**
  String driverStopDepart(int n);

  /// No description provided for @driverStopsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stops'**
  String get driverStopsTitle;

  /// No description provided for @driverStopFreeWait.
  ///
  /// In en, this message translates to:
  /// **'Free wait {m} min, then {fee}/min'**
  String driverStopFreeWait(int m, String fee);

  /// No description provided for @driverNavigateToStop.
  ///
  /// In en, this message translates to:
  /// **'Navigate to stop {n}'**
  String driverNavigateToStop(int n);

  /// No description provided for @driverStopsPendingError.
  ///
  /// In en, this message translates to:
  /// **'Finish every stop before completing the trip.'**
  String get driverStopsPendingError;

  /// No description provided for @rideEditStops.
  ///
  /// In en, this message translates to:
  /// **'Edit stops'**
  String get rideEditStops;

  /// No description provided for @rideEditStopsSave.
  ///
  /// In en, this message translates to:
  /// **'Update route'**
  String get rideEditStopsSave;

  /// No description provided for @rideEditStopsConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Change stops?'**
  String get rideEditStopsConfirmTitle;

  /// No description provided for @rideEditStopsConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Changing the route clears current driver offers and restarts the search.'**
  String get rideEditStopsConfirmBody;

  /// No description provided for @rideEditStopsConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Change route'**
  String get rideEditStopsConfirmAction;

  /// No description provided for @rideEditStopsDone.
  ///
  /// In en, this message translates to:
  /// **'Route updated. Waiting for new offers.'**
  String get rideEditStopsDone;

  /// No description provided for @rideStopsNone.
  ///
  /// In en, this message translates to:
  /// **'No stops yet'**
  String get rideStopsNone;

  /// No description provided for @mapPinStop.
  ///
  /// In en, this message translates to:
  /// **'Stop {n}'**
  String mapPinStop(int n);

  /// No description provided for @paymentGroupWallet.
  ///
  /// In en, this message translates to:
  /// **'E-wallets'**
  String get paymentGroupWallet;

  /// No description provided for @paymentGroupCard.
  ///
  /// In en, this message translates to:
  /// **'Credit/debit cards'**
  String get paymentGroupCard;

  /// No description provided for @paymentGroupRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get paymentGroupRecommended;

  /// No description provided for @paymentGroupAddMore.
  ///
  /// In en, this message translates to:
  /// **'More methods'**
  String get paymentGroupAddMore;

  /// No description provided for @paymentCashLabel.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentCashLabel;

  /// No description provided for @paymentCashSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pay the driver directly'**
  String get paymentCashSubtitle;

  /// No description provided for @paymentStatusCash.
  ///
  /// In en, this message translates to:
  /// **'Cash payment'**
  String get paymentStatusCash;

  /// No description provided for @paymentStatusNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not paid yet'**
  String get paymentStatusNotStarted;

  /// No description provided for @paymentStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for payment confirmation'**
  String get paymentStatusPending;

  /// No description provided for @paymentStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Payment successful'**
  String get paymentStatusPaid;

  /// No description provided for @paymentStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get paymentStatusFailed;

  /// No description provided for @paymentStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Payment session expired'**
  String get paymentStatusExpired;

  /// No description provided for @paymentStatusRefundPending.
  ///
  /// In en, this message translates to:
  /// **'Refund in progress'**
  String get paymentStatusRefundPending;

  /// No description provided for @paymentStatusRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get paymentStatusRefunded;

  /// No description provided for @paymentSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentSheetTitle;

  /// No description provided for @paymentClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get paymentClose;

  /// No description provided for @paymentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get paymentUnavailable;

  /// No description provided for @paymentChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get paymentChange;

  /// No description provided for @paymentSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired.'**
  String get paymentSessionExpired;

  /// No description provided for @paymentStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the payment. Try again or pay in cash.'**
  String get paymentStartFailed;

  /// No description provided for @paymentStatusLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the payment status.'**
  String get paymentStatusLoadFailed;

  /// No description provided for @paymentHeader.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentHeader;

  /// No description provided for @paymentPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing payment…'**
  String get paymentPreparing;

  /// No description provided for @paymentPendingHint.
  ///
  /// In en, this message translates to:
  /// **'Finish paying in your wallet/bank app, then come back to DealGo. The status updates automatically.'**
  String get paymentPendingHint;

  /// No description provided for @paymentReopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen payment page'**
  String get paymentReopen;

  /// No description provided for @paymentRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get paymentRetry;

  /// No description provided for @paymentSwitchToCash.
  ///
  /// In en, this message translates to:
  /// **'Switch to cash'**
  String get paymentSwitchToCash;

  /// No description provided for @paymentContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get paymentContinue;

  /// No description provided for @driverPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get driverPaymentMethod;

  /// No description provided for @driverPaidOnline.
  ///
  /// In en, this message translates to:
  /// **'Paid online'**
  String get driverPaidOnline;

  /// No description provided for @driverPaidOnlineAmount.
  ///
  /// In en, this message translates to:
  /// **'Paid online {amount}'**
  String driverPaidOnlineAmount(String amount);

  /// No description provided for @driverOnlinePaymentPending.
  ///
  /// In en, this message translates to:
  /// **'Customer\'s online payment not confirmed yet'**
  String get driverOnlinePaymentPending;

  /// No description provided for @profilePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get profilePhone;

  /// No description provided for @profilePhoneHint.
  ///
  /// In en, this message translates to:
  /// **'So the driver and the shop can reach you about orders. No verification code needed.'**
  String get profilePhoneHint;

  /// No description provided for @profilePhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Vietnamese mobile number (e.g. 0901 234 567).'**
  String get profilePhoneInvalid;

  /// No description provided for @driverJobPushGone.
  ///
  /// In en, this message translates to:
  /// **'This request was cancelled or taken by another driver.'**
  String get driverJobPushGone;

  /// No description provided for @incomingJobTitle.
  ///
  /// In en, this message translates to:
  /// **'New ride request'**
  String get incomingJobTitle;

  /// No description provided for @incomingJobSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get incomingJobSkip;

  /// No description provided for @incomingJobOpen.
  ///
  /// In en, this message translates to:
  /// **'View & quote'**
  String get incomingJobOpen;

  /// No description provided for @driverStartTrip.
  ///
  /// In en, this message translates to:
  /// **'Start trip'**
  String get driverStartTrip;

  /// No description provided for @rideOfferAcceptShort.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get rideOfferAcceptShort;

  /// No description provided for @rideOfferDeclineShort.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get rideOfferDeclineShort;

  /// No description provided for @driverSendQuoteAmount.
  ///
  /// In en, this message translates to:
  /// **'Offer {amount}'**
  String driverSendQuoteAmount(String amount);

  /// No description provided for @driverWithdrawOfferShort.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get driverWithdrawOfferShort;

  /// No description provided for @incomingJobDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get incomingJobDetails;

  /// No description provided for @kycCaptureFrontTitle.
  ///
  /// In en, this message translates to:
  /// **'Capture ID front'**
  String get kycCaptureFrontTitle;

  /// No description provided for @kycCaptureBackTitle.
  ///
  /// In en, this message translates to:
  /// **'Capture ID back'**
  String get kycCaptureBackTitle;

  /// No description provided for @kycCaptureAlignHint.
  ///
  /// In en, this message translates to:
  /// **'Fit the card in the frame, well lit, no glare'**
  String get kycCaptureAlignHint;

  /// No description provided for @kycCaptureChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking photo…'**
  String get kycCaptureChecking;

  /// No description provided for @kycCaptureBlurry.
  ///
  /// In en, this message translates to:
  /// **'Photo is blurry'**
  String get kycCaptureBlurry;

  /// No description provided for @kycCaptureGlare.
  ///
  /// In en, this message translates to:
  /// **'Photo has glare'**
  String get kycCaptureGlare;

  /// No description provided for @kycCaptureDark.
  ///
  /// In en, this message translates to:
  /// **'Photo is too dark'**
  String get kycCaptureDark;

  /// No description provided for @kycCaptureRetake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get kycCaptureRetake;

  /// No description provided for @kycCaptureCameraError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the camera.'**
  String get kycCaptureCameraError;

  /// No description provided for @kycLivenessTitle.
  ///
  /// In en, this message translates to:
  /// **'Face check'**
  String get kycLivenessTitle;

  /// No description provided for @kycLivenessCenter.
  ///
  /// In en, this message translates to:
  /// **'Look straight at the frame'**
  String get kycLivenessCenter;

  /// No description provided for @kycLivenessTurnLeft.
  ///
  /// In en, this message translates to:
  /// **'Turn your face left'**
  String get kycLivenessTurnLeft;

  /// No description provided for @kycLivenessTurnRight.
  ///
  /// In en, this message translates to:
  /// **'Turn your face right'**
  String get kycLivenessTurnRight;

  /// No description provided for @kycLivenessBlink.
  ///
  /// In en, this message translates to:
  /// **'Blink your eyes'**
  String get kycLivenessBlink;

  /// No description provided for @kycLivenessNoFace.
  ///
  /// In en, this message translates to:
  /// **'No face in the frame'**
  String get kycLivenessNoFace;

  /// No description provided for @kycLivenessManyFaces.
  ///
  /// In en, this message translates to:
  /// **'Only one person in the frame'**
  String get kycLivenessManyFaces;

  /// No description provided for @kycLivenessDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get kycLivenessDone;

  /// No description provided for @kycLivenessTimeout.
  ///
  /// In en, this message translates to:
  /// **'Time is up, try again'**
  String get kycLivenessTimeout;

  /// No description provided for @kycHintFindCard.
  ///
  /// In en, this message translates to:
  /// **'Fit the card in the frame'**
  String get kycHintFindCard;

  /// No description provided for @kycHintCloser.
  ///
  /// In en, this message translates to:
  /// **'Closer'**
  String get kycHintCloser;

  /// No description provided for @kycHintMoreLight.
  ///
  /// In en, this message translates to:
  /// **'More light'**
  String get kycHintMoreLight;

  /// No description provided for @kycHintNoGlare.
  ///
  /// In en, this message translates to:
  /// **'Avoid glare'**
  String get kycHintNoGlare;

  /// No description provided for @kycHintHoldStill.
  ///
  /// In en, this message translates to:
  /// **'Hold still'**
  String get kycHintHoldStill;

  /// No description provided for @kycHintCaptured.
  ///
  /// In en, this message translates to:
  /// **'Captured'**
  String get kycHintCaptured;

  /// No description provided for @kycHintFaceInOval.
  ///
  /// In en, this message translates to:
  /// **'Face in the oval'**
  String get kycHintFaceInOval;

  /// No description provided for @kycLivenessRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get kycLivenessRecording;

  /// No description provided for @partnerDocSelfieVideo.
  ///
  /// In en, this message translates to:
  /// **'Face video'**
  String get partnerDocSelfieVideo;

  /// No description provided for @livenessClipRetry.
  ///
  /// In en, this message translates to:
  /// **'The face video didn\'t save (missing or too large). Let\'s try again.'**
  String get livenessClipRetry;

  /// No description provided for @parcelWhereTo.
  ///
  /// In en, this message translates to:
  /// **'Where is the package going?'**
  String get parcelWhereTo;

  /// No description provided for @driverServiceParcel.
  ///
  /// In en, this message translates to:
  /// **'Goods delivery'**
  String get driverServiceParcel;

  /// No description provided for @driverServiceParcelHint.
  ///
  /// In en, this message translates to:
  /// **'Receive parcel delivery requests'**
  String get driverServiceParcelHint;

  /// No description provided for @homeServiceParcel.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get homeServiceParcel;

  /// No description provided for @homeServiceParcelSub.
  ///
  /// In en, this message translates to:
  /// **'Send a package across town, fast'**
  String get homeServiceParcelSub;

  /// No description provided for @parcelDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Package details'**
  String get parcelDetailsTitle;

  /// No description provided for @parcelSizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Package size'**
  String get parcelSizeTitle;

  /// No description provided for @parcelSizeHint.
  ///
  /// In en, this message translates to:
  /// **'Max size {dims}'**
  String parcelSizeHint(String dims);

  /// No description provided for @parcelSizeS.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get parcelSizeS;

  /// No description provided for @parcelSizeM.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get parcelSizeM;

  /// No description provided for @parcelSizeL.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get parcelSizeL;

  /// No description provided for @parcelSizeXL.
  ///
  /// In en, this message translates to:
  /// **'Extra large'**
  String get parcelSizeXL;

  /// No description provided for @parcelWeightLabel.
  ///
  /// In en, this message translates to:
  /// **'Weight (optional)'**
  String get parcelWeightLabel;

  /// No description provided for @parcelWeightInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid weight'**
  String get parcelWeightInvalid;

  /// No description provided for @parcelWeightOver.
  ///
  /// In en, this message translates to:
  /// **'Over {limit} kg for this size'**
  String parcelWeightOver(String limit);

  /// No description provided for @parcelNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note for the driver (optional)'**
  String get parcelNoteLabel;

  /// No description provided for @parcelSenderTitle.
  ///
  /// In en, this message translates to:
  /// **'Sender'**
  String get parcelSenderTitle;

  /// No description provided for @parcelRecipientTitle.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get parcelRecipientTitle;

  /// No description provided for @parcelNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get parcelNameLabel;

  /// No description provided for @parcelPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get parcelPhoneLabel;

  /// No description provided for @parcelFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get parcelFieldRequired;

  /// No description provided for @parcelPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get parcelPhoneInvalid;

  /// No description provided for @parcelPayerSender.
  ///
  /// In en, this message translates to:
  /// **'Sender pays'**
  String get parcelPayerSender;

  /// No description provided for @parcelPayerRecipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient pays'**
  String get parcelPayerRecipient;

  /// No description provided for @parcelItemPhotoAdd.
  ///
  /// In en, this message translates to:
  /// **'Add package photo'**
  String get parcelItemPhotoAdd;

  /// No description provided for @parcelItemPhotoAdded.
  ///
  /// In en, this message translates to:
  /// **'Package photo added'**
  String get parcelItemPhotoAdded;

  /// No description provided for @parcelVehicleTitle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get parcelVehicleTitle;

  /// No description provided for @parcelOptionHint.
  ///
  /// In en, this message translates to:
  /// **'Offer {min} – {max}'**
  String parcelOptionHint(String min, String max);

  /// No description provided for @parcelQuoteCta.
  ///
  /// In en, this message translates to:
  /// **'See price'**
  String get parcelQuoteCta;

  /// No description provided for @parcelSubmitCta.
  ///
  /// In en, this message translates to:
  /// **'Book delivery'**
  String get parcelSubmitCta;

  /// No description provided for @parcelDriverBadge.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get parcelDriverBadge;

  /// No description provided for @parcelOutcomeDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get parcelOutcomeDelivered;

  /// No description provided for @parcelOutcomeReturning.
  ///
  /// In en, this message translates to:
  /// **'Returning to sender'**
  String get parcelOutcomeReturning;

  /// No description provided for @parcelOutcomeReturned.
  ///
  /// In en, this message translates to:
  /// **'Returned to sender'**
  String get parcelOutcomeReturned;

  /// No description provided for @parcelOutcomeInTransit.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get parcelOutcomeInTransit;

  /// No description provided for @parcelOutcomeWaitingPickup.
  ///
  /// In en, this message translates to:
  /// **'Waiting for pickup'**
  String get parcelOutcomeWaitingPickup;

  /// No description provided for @parcelFailUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Recipient unreachable'**
  String get parcelFailUnreachable;

  /// No description provided for @parcelFailRefused.
  ///
  /// In en, this message translates to:
  /// **'Recipient refused'**
  String get parcelFailRefused;

  /// No description provided for @parcelFailAddress.
  ///
  /// In en, this message translates to:
  /// **'Wrong address'**
  String get parcelFailAddress;

  /// No description provided for @parcelFailDamaged.
  ///
  /// In en, this message translates to:
  /// **'Package damaged'**
  String get parcelFailDamaged;

  /// No description provided for @parcelFailOther.
  ///
  /// In en, this message translates to:
  /// **'Other reason'**
  String get parcelFailOther;

  /// No description provided for @parcelFailTitle.
  ///
  /// In en, this message translates to:
  /// **'Why can\'t it be delivered?'**
  String get parcelFailTitle;

  /// No description provided for @parcelErrorNoVehicle.
  ///
  /// In en, this message translates to:
  /// **'No vehicle can carry this package size'**
  String get parcelErrorNoVehicle;

  /// No description provided for @parcelErrorTooHeavy.
  ///
  /// In en, this message translates to:
  /// **'Package is too heavy for this size'**
  String get parcelErrorTooHeavy;

  /// No description provided for @parcelErrorRecipientCode.
  ///
  /// In en, this message translates to:
  /// **'Recipient code is wrong'**
  String get parcelErrorRecipientCode;

  /// No description provided for @parcelErrorCodeLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong codes. Try again later'**
  String get parcelErrorCodeLocked;

  /// No description provided for @parcelErrorSizeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This size isn\'t available right now'**
  String get parcelErrorSizeUnavailable;

  /// No description provided for @parcelErrorPayerMethod.
  ///
  /// In en, this message translates to:
  /// **'Recipient-pays only works with cash'**
  String get parcelErrorPayerMethod;

  /// No description provided for @parcelErrorPhoto.
  ///
  /// In en, this message translates to:
  /// **'A photo is required'**
  String get parcelErrorPhoto;

  /// No description provided for @parcelErrorState.
  ///
  /// In en, this message translates to:
  /// **'The delivery has changed. Refresh'**
  String get parcelErrorState;

  /// No description provided for @parcelErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Connection problem. Try again'**
  String get parcelErrorNetwork;

  /// No description provided for @parcelErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get parcelErrorGeneric;

  /// No description provided for @parcelRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get parcelRetry;

  /// No description provided for @parcelSenderLine.
  ///
  /// In en, this message translates to:
  /// **'Sender: {name} · {phone}'**
  String parcelSenderLine(String name, String phone);

  /// No description provided for @parcelRecipientLine.
  ///
  /// In en, this message translates to:
  /// **'Recipient: {name} · {phone}'**
  String parcelRecipientLine(String name, String phone);

  /// No description provided for @parcelRecipientCode.
  ///
  /// In en, this message translates to:
  /// **'Recipient code: {code}'**
  String parcelRecipientCode(String code);

  /// No description provided for @parcelRecipientCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Share this code with the recipient. The driver needs it to complete the delivery.'**
  String get parcelRecipientCodeHint;

  /// No description provided for @parcelPickupCta.
  ///
  /// In en, this message translates to:
  /// **'Picked up (take photo)'**
  String get parcelPickupCta;

  /// No description provided for @parcelReturningHint.
  ///
  /// In en, this message translates to:
  /// **'Bring the package back to the sender'**
  String get parcelReturningHint;

  /// No description provided for @parcelReturnedCta.
  ///
  /// In en, this message translates to:
  /// **'Returned to sender (photo)'**
  String get parcelReturnedCta;

  /// No description provided for @parcelRecipientCodeInput.
  ///
  /// In en, this message translates to:
  /// **'Recipient code'**
  String get parcelRecipientCodeInput;

  /// No description provided for @parcelDeliverCta.
  ///
  /// In en, this message translates to:
  /// **'Delivered (photo)'**
  String get parcelDeliverCta;

  /// No description provided for @parcelFailCta.
  ///
  /// In en, this message translates to:
  /// **'Can\'t deliver'**
  String get parcelFailCta;

  /// No description provided for @parcelServiceFeeLine.
  ///
  /// In en, this message translates to:
  /// **'Service fee {amount} (included in fare)'**
  String parcelServiceFeeLine(String amount);

  /// No description provided for @parcelReturnFeeLine.
  ///
  /// In en, this message translates to:
  /// **'Return fee if delivery fails: {amount}'**
  String parcelReturnFeeLine(String amount);

  /// No description provided for @parcelReturnFeeCharged.
  ///
  /// In en, this message translates to:
  /// **'Return fee {amount}'**
  String parcelReturnFeeCharged(String amount);

  /// No description provided for @parcelReceiptServiceFee.
  ///
  /// In en, this message translates to:
  /// **'Parcel service fee (included)'**
  String get parcelReceiptServiceFee;

  /// No description provided for @parcelReceiptReturnFee.
  ///
  /// In en, this message translates to:
  /// **'Return fee'**
  String get parcelReceiptReturnFee;

  /// No description provided for @driverServicesFoodMotorbikeOnly.
  ///
  /// In en, this message translates to:
  /// **'Food orders are for motorbike drivers only.'**
  String get driverServicesFoodMotorbikeOnly;

  /// No description provided for @partnerKindFoodSafetyCommitment.
  ///
  /// In en, this message translates to:
  /// **'Food safety commitment'**
  String get partnerKindFoodSafetyCommitment;

  /// No description provided for @partnerFoodSafetyUseCommitment.
  ///
  /// In en, this message translates to:
  /// **'Use the food safety commitment'**
  String get partnerFoodSafetyUseCommitment;

  /// No description provided for @partnerFoodSafetyUseCommitmentHint.
  ///
  /// In en, this message translates to:
  /// **'Small household shops may sign the food safety commitment instead of the certificate.'**
  String get partnerFoodSafetyUseCommitmentHint;

  /// No description provided for @kycOcrPrefilledNote.
  ///
  /// In en, this message translates to:
  /// **'Some fields were filled from your document photos. Please check and correct them.'**
  String get kycOcrPrefilledNote;

  /// No description provided for @kycOcrReading.
  ///
  /// In en, this message translates to:
  /// **'Reading your document…'**
  String get kycOcrReading;

  /// No description provided for @parcelPickContact.
  ///
  /// In en, this message translates to:
  /// **'Pick from contacts'**
  String get parcelPickContact;

  /// No description provided for @parcelEditRoute.
  ///
  /// In en, this message translates to:
  /// **'Edit route'**
  String get parcelEditRoute;

  /// No description provided for @parcelEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get parcelEdit;

  /// No description provided for @parcelMoreDetails.
  ///
  /// In en, this message translates to:
  /// **'Weight, note, photo (optional)'**
  String get parcelMoreDetails;

  /// No description provided for @parcelPricing.
  ///
  /// In en, this message translates to:
  /// **'Getting price…'**
  String get parcelPricing;

  /// No description provided for @parcelSectionPackage.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get parcelSectionPackage;

  /// No description provided for @parcelSectionPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get parcelSectionPayment;

  /// No description provided for @parcelFareLabel.
  ///
  /// In en, this message translates to:
  /// **'Fare'**
  String get parcelFareLabel;

  /// No description provided for @parcelPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'0901 234 567'**
  String get parcelPhoneHint;

  /// No description provided for @parcelSenderYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get parcelSenderYou;

  /// No description provided for @parcelPayerRecipientNote.
  ///
  /// In en, this message translates to:
  /// **'The recipient pays the driver in cash on delivery.'**
  String get parcelPayerRecipientNote;

  /// No description provided for @parcelSubmitWithPrice.
  ///
  /// In en, this message translates to:
  /// **'Book · {price}'**
  String parcelSubmitWithPrice(String price);

  /// No description provided for @apiErrCrossRegion.
  ///
  /// In en, this message translates to:
  /// **'DealGo does not support trips between service regions yet. Please choose a destination in the same city as your pickup.'**
  String get apiErrCrossRegion;

  /// No description provided for @apiErrDriverAtCapacity.
  ///
  /// In en, this message translates to:
  /// **'You are on an active trip. Finish it before taking a new request.'**
  String get apiErrDriverAtCapacity;

  /// No description provided for @apiErrDriverTooFar.
  ///
  /// In en, this message translates to:
  /// **'You are too far from the pickup. Move closer and try again.'**
  String get apiErrDriverTooFar;

  /// No description provided for @apiErrOfferDriverUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This driver just took another trip. Please choose another driver.'**
  String get apiErrOfferDriverUnavailable;

  /// No description provided for @apiErrItemNotApproved.
  ///
  /// In en, this message translates to:
  /// **'This item is still awaiting approval and cannot be put on sale yet.'**
  String get apiErrItemNotApproved;

  /// No description provided for @rideIntercity.
  ///
  /// In en, this message translates to:
  /// **'Intercity'**
  String get rideIntercity;

  /// No description provided for @rideIntercityQuote.
  ///
  /// In en, this message translates to:
  /// **'Intercity trip · {km} km · ≈{minutes} min'**
  String rideIntercityQuote(String km, String minutes);

  /// No description provided for @rideIntercityNote.
  ///
  /// In en, this message translates to:
  /// **'The destination is in another province/region. Drivers bid as usual.'**
  String get rideIntercityNote;

  /// No description provided for @driverPickupAwayKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km away'**
  String driverPickupAwayKm(String km);

  /// No description provided for @driverServiceSettings.
  ///
  /// In en, this message translates to:
  /// **'Service settings'**
  String get driverServiceSettings;

  /// No description provided for @rideGoHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get rideGoHome;

  /// No description provided for @apiErrIntercityStops.
  ///
  /// In en, this message translates to:
  /// **'Intercity trips go straight to one destination without extra stops.'**
  String get apiErrIntercityStops;

  /// No description provided for @apiErrIntercityTooFar.
  ///
  /// In en, this message translates to:
  /// **'This intercity trip is longer than DealGo currently supports.'**
  String get apiErrIntercityTooFar;

  /// No description provided for @apiErrIntercityVehicle.
  ///
  /// In en, this message translates to:
  /// **'This vehicle class does not run intercity. Please choose another vehicle.'**
  String get apiErrIntercityVehicle;

  /// No description provided for @apiErrIntercityNoVehicle.
  ///
  /// In en, this message translates to:
  /// **'No vehicle class runs intercity trips yet.'**
  String get apiErrIntercityNoVehicle;

  /// No description provided for @driverJobTripKm.
  ///
  /// In en, this message translates to:
  /// **'Trip {km} km'**
  String driverJobTripKm(String km);

  /// No description provided for @driverJobPickupKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km to pickup'**
  String driverJobPickupKm(String km);

  /// No description provided for @appUpdateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get appUpdateRequiredTitle;

  /// No description provided for @appUpdateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'This version of the app is no longer supported. Please update to keep using DealGo.'**
  String get appUpdateRequiredBody;

  /// No description provided for @appUpdateNow.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get appUpdateNow;

  /// No description provided for @appUpdateLatest.
  ///
  /// In en, this message translates to:
  /// **'New version: {version}'**
  String appUpdateLatest(String version);

  /// No description provided for @appUpdateOptionalTitle.
  ///
  /// In en, this message translates to:
  /// **'A new version is available'**
  String get appUpdateOptionalTitle;

  /// No description provided for @appUpdateOptionalBody.
  ///
  /// In en, this message translates to:
  /// **'Update to get the latest features and fixes.'**
  String get appUpdateOptionalBody;

  /// No description provided for @appUpdateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get appUpdateLater;

  /// No description provided for @appUpdateRetry.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get appUpdateRetry;

  /// No description provided for @legalConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Our terms have been updated'**
  String get legalConsentTitle;

  /// No description provided for @legalConsentBody.
  ///
  /// In en, this message translates to:
  /// **'Please review and accept the new terms to keep using DealGo.'**
  String get legalConsentBody;

  /// No description provided for @legalConsentRead.
  ///
  /// In en, this message translates to:
  /// **'Read the full text'**
  String get legalConsentRead;

  /// No description provided for @legalConsentEffective.
  ///
  /// In en, this message translates to:
  /// **'Effective {date}'**
  String legalConsentEffective(String date);

  /// No description provided for @legalConsentVersion.
  ///
  /// In en, this message translates to:
  /// **'version {version}'**
  String legalConsentVersion(String version);

  /// No description provided for @legalConsentAgree.
  ///
  /// In en, this message translates to:
  /// **'I agree'**
  String get legalConsentAgree;

  /// No description provided for @legalConsentFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send. Please try again.'**
  String get legalConsentFailed;

  /// No description provided for @contactPhoneDial.
  ///
  /// In en, this message translates to:
  /// **'Call {phone}'**
  String contactPhoneDial(String phone);

  /// No description provided for @contactPhoneDialFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the phone app.'**
  String get contactPhoneDialFailed;

  /// No description provided for @kycReviewAvatar.
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get kycReviewAvatar;

  /// No description provided for @kycAvatarMissing.
  ///
  /// In en, this message translates to:
  /// **'Required before you submit. Customers see this photo when you take their job.'**
  String get kycAvatarMissing;

  /// No description provided for @kycAvatarReady.
  ///
  /// In en, this message translates to:
  /// **'Customers see this photo when you take their job.'**
  String get kycAvatarReady;

  /// No description provided for @kycAvatarAdd.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get kycAvatarAdd;

  /// No description provided for @partnerErrorAvatar.
  ///
  /// In en, this message translates to:
  /// **'Add a profile photo to your profile before submitting your driver application.'**
  String get partnerErrorAvatar;

  /// No description provided for @offlineJobUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Last updated {time} · no connection'**
  String offlineJobUpdatedAt(String time);

  /// No description provided for @offlineJobCallHint.
  ///
  /// In en, this message translates to:
  /// **'Regular phone calls work without mobile data.'**
  String get offlineJobCallHint;

  /// No description provided for @legalRegulationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of use for partners'**
  String get legalRegulationsTitle;

  /// No description provided for @legalRegulationsBody.
  ///
  /// In en, this message translates to:
  /// **'For partner drivers and shops'**
  String get legalRegulationsBody;

  /// No description provided for @legalTermsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get legalTermsTitle;

  /// No description provided for @legalTermsBody.
  ///
  /// In en, this message translates to:
  /// **'Your rights and obligations when using DealGo'**
  String get legalTermsBody;

  /// No description provided for @legalPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get legalPrivacyTitle;

  /// No description provided for @legalPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'How DealGo collects and protects your data'**
  String get legalPrivacyBody;

  /// No description provided for @legalLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load this document. Please try again.'**
  String get legalLoadError;

  /// No description provided for @partnerConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Partner registration terms'**
  String get partnerConsentTitle;

  /// No description provided for @partnerConsentRegulations.
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to the Terms of use'**
  String get partnerConsentRegulations;

  /// No description provided for @partnerConsentPrivacy.
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to the Privacy policy'**
  String get partnerConsentPrivacy;

  /// No description provided for @partnerConsentView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get partnerConsentView;

  /// No description provided for @partnerConsentHint.
  ///
  /// In en, this message translates to:
  /// **'You must accept both to submit your application.'**
  String get partnerConsentHint;

  /// No description provided for @partnerConsentLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the terms — tap to retry'**
  String get partnerConsentLoadError;

  /// No description provided for @partnerErrorLegalConsent.
  ///
  /// In en, this message translates to:
  /// **'The Terms of use or Privacy policy was just updated. Please review and accept again.'**
  String get partnerErrorLegalConsent;

  /// No description provided for @foodFareSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested delivery fee'**
  String get foodFareSuggested;

  /// No description provided for @foodFareYourOffer.
  ///
  /// In en, this message translates to:
  /// **'Your offer'**
  String get foodFareYourOffer;

  /// No description provided for @foodFareFixedWaiting.
  ///
  /// In en, this message translates to:
  /// **'Drivers can only accept the fee you offered. If it\'s taking a while, raise the fee to make the order more attractive.'**
  String get foodFareFixedWaiting;

  /// No description provided for @driverFareFixed.
  ///
  /// In en, this message translates to:
  /// **'This order uses a fixed fee: you can only accept the customer\'s price.'**
  String get driverFareFixed;

  /// No description provided for @foodFareDecrease.
  ///
  /// In en, this message translates to:
  /// **'Lower the fee'**
  String get foodFareDecrease;

  /// No description provided for @foodFareIncrease.
  ///
  /// In en, this message translates to:
  /// **'Raise the fee'**
  String get foodFareIncrease;

  /// No description provided for @foodFareReset.
  ///
  /// In en, this message translates to:
  /// **'Use the suggestion'**
  String get foodFareReset;

  /// No description provided for @foodFareNegotiationTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get foodFareNegotiationTitle;

  /// No description provided for @foodFareWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a driver to accept {amount}'**
  String foodFareWaiting(String amount);

  /// No description provided for @foodFareAgreed.
  ///
  /// In en, this message translates to:
  /// **'Agreed delivery fee: {amount}'**
  String foodFareAgreed(String amount);

  /// No description provided for @foodFareOffersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No driver has proposed another fee yet.'**
  String get foodFareOffersEmpty;

  /// No description provided for @foodFareDriverOffer.
  ///
  /// In en, this message translates to:
  /// **'Driver offer'**
  String get foodFareDriverOffer;

  /// No description provided for @foodFareSelect.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get foodFareSelect;

  /// No description provided for @foodFareRaise.
  ///
  /// In en, this message translates to:
  /// **'Raise to {amount}'**
  String foodFareRaise(String amount);

  /// No description provided for @foodFareRaisesLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} raises left'**
  String foodFareRaisesLeft(int count);

  /// No description provided for @foodFareOfferExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get foodFareOfferExpired;

  /// No description provided for @foodFareSelectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not choose this offer. It may have expired or the driver took another job.'**
  String get foodFareSelectFailed;

  /// No description provided for @foodFareRaiseFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not raise the fee. Try again later.'**
  String get foodFareRaiseFailed;

  /// No description provided for @foodFareCodExtra.
  ///
  /// In en, this message translates to:
  /// **'If the agreed fee is higher than what you paid online, the difference is collected in cash on delivery.'**
  String get foodFareCodExtra;

  /// No description provided for @driverFareCounter.
  ///
  /// In en, this message translates to:
  /// **'Propose fee'**
  String get driverFareCounter;

  /// No description provided for @driverFareCounterTitle.
  ///
  /// In en, this message translates to:
  /// **'Propose a delivery fee'**
  String get driverFareCounterTitle;

  /// No description provided for @driverFareCustomerOffer.
  ///
  /// In en, this message translates to:
  /// **'Customer offers {amount}'**
  String driverFareCustomerOffer(String amount);

  /// No description provided for @driverFareCounterSend.
  ///
  /// In en, this message translates to:
  /// **'Send {amount}'**
  String driverFareCounterSend(String amount);

  /// No description provided for @driverFareCounterSent.
  ///
  /// In en, this message translates to:
  /// **'Offer sent. Waiting for the customer.'**
  String get driverFareCounterSent;

  /// No description provided for @driverFareCounterFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the offer.'**
  String get driverFareCounterFailed;

  /// No description provided for @merchantFareAgreed.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee (agreed)'**
  String get merchantFareAgreed;

  /// No description provided for @driverCreditTitle.
  ///
  /// In en, this message translates to:
  /// **'Prepaid balance'**
  String get driverCreditTitle;

  /// No description provided for @driverCreditSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Covers platform fees only. It cannot be withdrawn or transferred.'**
  String get driverCreditSubtitle;

  /// No description provided for @driverCreditBalance.
  ///
  /// In en, this message translates to:
  /// **'Prepaid credit'**
  String get driverCreditBalance;

  /// No description provided for @driverCreditOwes.
  ///
  /// In en, this message translates to:
  /// **'Fee debt'**
  String get driverCreditOwes;

  /// No description provided for @driverCreditBlocked.
  ///
  /// In en, this message translates to:
  /// **'Fee debt is over the limit. You will not receive new jobs until you top up.'**
  String get driverCreditBlocked;

  /// No description provided for @driverCreditNearLimit.
  ///
  /// In en, this message translates to:
  /// **'Fee debt is close to the limit. Top up to keep receiving jobs.'**
  String get driverCreditNearLimit;

  /// No description provided for @driverCreditDisabled.
  ///
  /// In en, this message translates to:
  /// **'Top-up is not open yet. Please try again later.'**
  String get driverCreditDisabled;

  /// No description provided for @driverCreditAmount.
  ///
  /// In en, this message translates to:
  /// **'Top-up amount'**
  String get driverCreditAmount;

  /// No description provided for @driverCreditAmountRange.
  ///
  /// In en, this message translates to:
  /// **'From {min} to {max}'**
  String driverCreditAmountRange(String min, String max);

  /// No description provided for @driverCreditTopUp.
  ///
  /// In en, this message translates to:
  /// **'Top up'**
  String get driverCreditTopUp;

  /// No description provided for @driverCreditPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for payment'**
  String get driverCreditPending;

  /// No description provided for @driverCreditRemaining.
  ///
  /// In en, this message translates to:
  /// **'{amount} left'**
  String driverCreditRemaining(String amount);

  /// No description provided for @driverCreditOpenCheckout.
  ///
  /// In en, this message translates to:
  /// **'Open the payment page'**
  String get driverCreditOpenCheckout;

  /// No description provided for @driverCreditCancelTopUp.
  ///
  /// In en, this message translates to:
  /// **'Cancel this top-up'**
  String get driverCreditCancelTopUp;

  /// No description provided for @driverCreditChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking payment…'**
  String get driverCreditChecking;

  /// No description provided for @driverCreditPaidHint.
  ///
  /// In en, this message translates to:
  /// **'Paid. The amount is now in your prepaid balance.'**
  String get driverCreditPaidHint;

  /// No description provided for @driverCreditRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent top-ups'**
  String get driverCreditRecent;

  /// No description provided for @driverCreditEmpty.
  ///
  /// In en, this message translates to:
  /// **'No top-ups yet.'**
  String get driverCreditEmpty;

  /// No description provided for @driverCreditLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading balance…'**
  String get driverCreditLoading;

  /// No description provided for @driverCreditCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Top up fees'**
  String get driverCreditCardTitle;

  /// No description provided for @driverCreditCardBody.
  ///
  /// In en, this message translates to:
  /// **'Keep your fee debt at zero so you keep receiving jobs.'**
  String get driverCreditCardBody;

  /// No description provided for @driverCreditStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get driverCreditStatusPending;

  /// No description provided for @driverCreditStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Credited'**
  String get driverCreditStatusPaid;

  /// No description provided for @driverCreditStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get driverCreditStatusExpired;

  /// No description provided for @driverCreditStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get driverCreditStatusCancelled;

  /// No description provided for @driverCreditStatusRefundPending.
  ///
  /// In en, this message translates to:
  /// **'Refund pending'**
  String get driverCreditStatusRefundPending;

  /// No description provided for @driverCreditStatusRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get driverCreditStatusRefunded;

  /// No description provided for @driverCreditStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get driverCreditStatusFailed;

  /// No description provided for @driverCreditErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not top up. Please try again.'**
  String get driverCreditErrorGeneric;

  /// No description provided for @driverCreditErrorPending.
  ///
  /// In en, this message translates to:
  /// **'You already have a top-up waiting for payment.'**
  String get driverCreditErrorPending;

  /// No description provided for @driverCreditErrorDailyLimit.
  ///
  /// In en, this message translates to:
  /// **'Today\'s top-up limit has been reached.'**
  String get driverCreditErrorDailyLimit;

  /// No description provided for @driverCreditErrorCreditLimit.
  ///
  /// In en, this message translates to:
  /// **'Prepaid balance limit has been reached.'**
  String get driverCreditErrorCreditLimit;

  /// No description provided for @driverCreditErrorAmount.
  ///
  /// In en, this message translates to:
  /// **'The amount is outside the allowed range.'**
  String get driverCreditErrorAmount;

  /// No description provided for @driverCreditErrorKyc.
  ///
  /// In en, this message translates to:
  /// **'An approved KYC is required before topping up.'**
  String get driverCreditErrorKyc;

  /// No description provided for @driverCreditErrorDisabled.
  ///
  /// In en, this message translates to:
  /// **'Top-up is not open yet.'**
  String get driverCreditErrorDisabled;

  /// No description provided for @driverCreditErrorProvider.
  ///
  /// In en, this message translates to:
  /// **'The payment provider is not available right now.'**
  String get driverCreditErrorProvider;

  /// No description provided for @driverCreditScanHint.
  ///
  /// In en, this message translates to:
  /// **'Open your banking app and scan this QR code. The amount is filled in for you.'**
  String get driverCreditScanHint;

  /// No description provided for @driverCreditOrderCode.
  ///
  /// In en, this message translates to:
  /// **'Order code'**
  String get driverCreditOrderCode;

  /// No description provided for @driverCreditExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'Expires in {time}'**
  String driverCreditExpiresIn(String time);

  /// No description provided for @driverCreditDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Top-up detail'**
  String get driverCreditDetailTitle;

  /// No description provided for @driverCreditCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy order code'**
  String get driverCreditCopyCode;

  /// No description provided for @driverCreditCopied.
  ///
  /// In en, this message translates to:
  /// **'Order code copied.'**
  String get driverCreditCopied;

  /// No description provided for @driverCreditPaymentReceived.
  ///
  /// In en, this message translates to:
  /// **'Payment received'**
  String get driverCreditPaymentReceived;

  /// No description provided for @driverCreditPaymentReceivedBody.
  ///
  /// In en, this message translates to:
  /// **'{amount} has been added to your prepaid balance.'**
  String driverCreditPaymentReceivedBody(String amount);

  /// No description provided for @driverCreditLinkExpired.
  ///
  /// In en, this message translates to:
  /// **'This payment link is no longer valid.'**
  String get driverCreditLinkExpired;

  /// No description provided for @driverCreditCreateNew.
  ///
  /// In en, this message translates to:
  /// **'Create a new top-up'**
  String get driverCreditCreateNew;

  /// No description provided for @driverCreditAppliedFees.
  ///
  /// In en, this message translates to:
  /// **'Applied to fees'**
  String get driverCreditAppliedFees;

  /// No description provided for @driverCreditRefundedAmount.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get driverCreditRefundedAmount;

  /// No description provided for @driverCreditMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get driverCreditMethod;

  /// No description provided for @driverCreditCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get driverCreditCreatedAt;

  /// No description provided for @driverCreditPaidAt.
  ///
  /// In en, this message translates to:
  /// **'Paid at'**
  String get driverCreditPaidAt;

  /// No description provided for @driverCreditClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get driverCreditClose;

  /// No description provided for @driverCreditWaitingBank.
  ///
  /// In en, this message translates to:
  /// **'The balance updates automatically once your bank confirms.'**
  String get driverCreditWaitingBank;

  /// No description provided for @foodVoucherWallTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s offers'**
  String get foodVoucherWallTitle;

  /// No description provided for @foodVoucherWallSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get foodVoucherWallSeeAll;

  /// No description provided for @foodReorderTitle.
  ///
  /// In en, this message translates to:
  /// **'Order again'**
  String get foodReorderTitle;

  /// No description provided for @foodReorderStripItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}} · {total}'**
  String foodReorderStripItems(int count, String total);
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

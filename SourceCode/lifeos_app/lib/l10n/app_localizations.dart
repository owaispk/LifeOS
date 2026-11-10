import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';

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
    Locale('en'),
    Locale('ur'),
  ];

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @appLock.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get appLock;

  /// No description provided for @appLockSub.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint, face or PIN to open LifeOS'**
  String get appLockSub;

  /// No description provided for @atcAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get atcAdd;

  /// No description provided for @atcAmountOptional.
  ///
  /// In en, this message translates to:
  /// **'Amount (optional)'**
  String get atcAmountOptional;

  /// No description provided for @atcCadenceDay.
  ///
  /// In en, this message translates to:
  /// **'{cycle} · {day}'**
  String atcCadenceDay(String cycle, String day);

  /// No description provided for @atcCadenceWindow.
  ///
  /// In en, this message translates to:
  /// **'~{from}–{to} monthly'**
  String atcCadenceWindow(String from, String to);

  /// No description provided for @atcCreateAuto.
  ///
  /// In en, this message translates to:
  /// **'Create tasks automatically'**
  String get atcCreateAuto;

  /// No description provided for @atcCreatedThisMonth.
  ///
  /// In en, this message translates to:
  /// **'⚡ ATC created {n, plural, =1{1 task} other{{n} tasks}} for you this month'**
  String atcCreatedThisMonth(int n);

  /// No description provided for @atcDays.
  ///
  /// In en, this message translates to:
  /// **'{n} days'**
  String atcDays(String n);

  /// No description provided for @atcDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get atcDelete;

  /// No description provided for @atcDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'No new tasks will be created. Tasks it already made stay in your list.'**
  String get atcDeleteBody;

  /// No description provided for @atcDeleteRule.
  ///
  /// In en, this message translates to:
  /// **'Delete rule'**
  String get atcDeleteRule;

  /// No description provided for @atcDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String atcDeleteTitle(String name);

  /// No description provided for @atcDueDates.
  ///
  /// In en, this message translates to:
  /// **'Due dates (optional — otherwise every 6 months)'**
  String get atcDueDates;

  /// No description provided for @atcDueDay.
  ///
  /// In en, this message translates to:
  /// **'Due day'**
  String get atcDueDay;

  /// No description provided for @atcEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'➕ Add a payment'**
  String get atcEmptyAction;

  /// No description provided for @atcEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tell it once what you pay regularly — rent, fees, bills — and it creates the reminders every month.'**
  String get atcEmptyBody;

  /// No description provided for @atcEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Let LifeOS remember your payments'**
  String get atcEmptyTitle;

  /// No description provided for @atcEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get atcEnded;

  /// No description provided for @atcEvery6Months.
  ///
  /// In en, this message translates to:
  /// **'Every 6 months'**
  String get atcEvery6Months;

  /// No description provided for @atcFeeChanged.
  ///
  /// In en, this message translates to:
  /// **'Fee changed'**
  String get atcFeeChanged;

  /// No description provided for @atcFeeDecreasedMsg.
  ///
  /// In en, this message translates to:
  /// **'Fee decreased from {oldAmount} → {newAmount}. Update future tasks?'**
  String atcFeeDecreasedMsg(String oldAmount, String newAmount);

  /// No description provided for @atcFeeIncreased.
  ///
  /// In en, this message translates to:
  /// **'Fee increased'**
  String get atcFeeIncreased;

  /// No description provided for @atcFeeIncreasedMsg.
  ///
  /// In en, this message translates to:
  /// **'Fee increased from {oldAmount} → {newAmount}. Update future tasks?'**
  String atcFeeIncreasedMsg(String oldAmount, String newAmount);

  /// No description provided for @atcFewerDays.
  ///
  /// In en, this message translates to:
  /// **'Fewer days'**
  String get atcFewerDays;

  /// No description provided for @atcFor.
  ///
  /// In en, this message translates to:
  /// **'For'**
  String get atcFor;

  /// No description provided for @atcFreeLimit.
  ///
  /// In en, this message translates to:
  /// **'Free plan includes {n} auto-rules — Premium removes the limit'**
  String atcFreeLimit(String n);

  /// No description provided for @atcGroupAppointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get atcGroupAppointments;

  /// No description provided for @atcGroupBills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get atcGroupBills;

  /// No description provided for @atcGroupFees.
  ///
  /// In en, this message translates to:
  /// **'Fees'**
  String get atcGroupFees;

  /// No description provided for @atcGroupFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get atcGroupFixed;

  /// No description provided for @atcHistory.
  ///
  /// In en, this message translates to:
  /// **'Created {n, plural, =1{1 task} other{{n} tasks}} · {paid} paid on time'**
  String atcHistory(int n, String paid);

  /// No description provided for @atcHousehold.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get atcHousehold;

  /// No description provided for @atcHowOften.
  ///
  /// In en, this message translates to:
  /// **'How often'**
  String get atcHowOften;

  /// No description provided for @atcIllScan.
  ///
  /// In en, this message translates to:
  /// **'I\'ll scan it'**
  String get atcIllScan;

  /// No description provided for @atcInstallments.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} paid'**
  String atcInstallments(String done, String total);

  /// No description provided for @atcInstallmentsTotal.
  ///
  /// In en, this message translates to:
  /// **'How many installments in total'**
  String get atcInstallmentsTotal;

  /// No description provided for @atcKeepAsIs.
  ///
  /// In en, this message translates to:
  /// **'Keep as is'**
  String get atcKeepAsIs;

  /// No description provided for @atcMissedBill.
  ///
  /// In en, this message translates to:
  /// **'No {label} bill this month — did you miss it, or should I pause this reminder?'**
  String atcMissedBill(String label);

  /// No description provided for @atcMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get atcMonthly;

  /// No description provided for @atcMoreDays.
  ///
  /// In en, this message translates to:
  /// **'More days'**
  String get atcMoreDays;

  /// No description provided for @atcNewPattern.
  ///
  /// In en, this message translates to:
  /// **'New pattern detected'**
  String get atcNewPattern;

  /// No description provided for @atcNext.
  ///
  /// In en, this message translates to:
  /// **'Next {day}'**
  String atcNext(String day);

  /// No description provided for @atcNoThanks.
  ///
  /// In en, this message translates to:
  /// **'No thanks'**
  String get atcNoThanks;

  /// No description provided for @atcNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get atcNotNow;

  /// No description provided for @atcOnSetDates.
  ///
  /// In en, this message translates to:
  /// **'On set dates · {dates}'**
  String atcOnSetDates(String dates);

  /// No description provided for @atcOnce.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get atcOnce;

  /// No description provided for @atcPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get atcPause;

  /// No description provided for @atcPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get atcPaused;

  /// No description provided for @atcPickDates.
  ///
  /// In en, this message translates to:
  /// **'Pick dates'**
  String get atcPickDates;

  /// No description provided for @atcPresetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get atcPresetCustom;

  /// No description provided for @atcPresetFees.
  ///
  /// In en, this message translates to:
  /// **'School fee'**
  String get atcPresetFees;

  /// No description provided for @atcPresetInstallment.
  ///
  /// In en, this message translates to:
  /// **'Installment / Committee'**
  String get atcPresetInstallment;

  /// No description provided for @atcPresetInternet.
  ///
  /// In en, this message translates to:
  /// **'Internet'**
  String get atcPresetInternet;

  /// No description provided for @atcPresetMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get atcPresetMobile;

  /// No description provided for @atcPresetRent.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get atcPresetRent;

  /// No description provided for @atcPresetSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get atcPresetSubscription;

  /// No description provided for @atcPresetUtility.
  ///
  /// In en, this message translates to:
  /// **'Utility bill'**
  String get atcPresetUtility;

  /// No description provided for @atcProposalBill.
  ///
  /// In en, this message translates to:
  /// **'Your {label} bill{when}. Create a monthly reminder?'**
  String atcProposalBill(String label, String when);

  /// No description provided for @atcProposalDue.
  ///
  /// In en, this message translates to:
  /// **', due {day}'**
  String atcProposalDue(String day);

  /// No description provided for @atcProposalFee.
  ///
  /// In en, this message translates to:
  /// **'Create a fee reminder{who}{amount}{day}?'**
  String atcProposalFee(String who, String amount, String day);

  /// No description provided for @atcProposalFor.
  ///
  /// In en, this message translates to:
  /// **' for {name}'**
  String atcProposalFor(String name);

  /// No description provided for @atcProposalWindow.
  ///
  /// In en, this message translates to:
  /// **' usually arrives the {from}–{to}'**
  String atcProposalWindow(String from, String to);

  /// No description provided for @atcProposed.
  ///
  /// In en, this message translates to:
  /// **'Proposed'**
  String get atcProposed;

  /// No description provided for @atcQuarterly.
  ///
  /// In en, this message translates to:
  /// **'Quarterly'**
  String get atcQuarterly;

  /// No description provided for @atcRemindBefore.
  ///
  /// In en, this message translates to:
  /// **'Remind me before'**
  String get atcRemindBefore;

  /// No description provided for @atcReminderOn.
  ///
  /// In en, this message translates to:
  /// **'⚡ Auto-reminder is on'**
  String get atcReminderOn;

  /// No description provided for @atcRuleGone.
  ///
  /// In en, this message translates to:
  /// **'This rule is gone'**
  String get atcRuleGone;

  /// No description provided for @atcRuleGoneBody.
  ///
  /// In en, this message translates to:
  /// **'It was deleted. Tasks it created are still in Tasks.'**
  String get atcRuleGoneBody;

  /// No description provided for @atcSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get atcSaveChanges;

  /// No description provided for @atcSavedNewTasks.
  ///
  /// In en, this message translates to:
  /// **'Saved — applies to new tasks'**
  String get atcSavedNewTasks;

  /// No description provided for @atcSeePremium.
  ///
  /// In en, this message translates to:
  /// **'See Premium'**
  String get atcSeePremium;

  /// No description provided for @atcSkipMonths.
  ///
  /// In en, this message translates to:
  /// **'Skip these months'**
  String get atcSkipMonths;

  /// No description provided for @atcStatusOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get atcStatusOn;

  /// No description provided for @atcStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused — no new tasks'**
  String get atcStatusPaused;

  /// No description provided for @atcTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto Tasks'**
  String get atcTitle;

  /// No description provided for @atcTurnOn.
  ///
  /// In en, this message translates to:
  /// **'⚡ Turn on auto-reminder'**
  String get atcTurnOn;

  /// No description provided for @atcUpdateFuture.
  ///
  /// In en, this message translates to:
  /// **'Update future tasks'**
  String get atcUpdateFuture;

  /// No description provided for @atcUpgradeBody.
  ///
  /// In en, this message translates to:
  /// **'Free plan includes {n} auto-rules — Premium removes the limit.'**
  String atcUpgradeBody(String n);

  /// No description provided for @atcUpgradeTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium'**
  String get atcUpgradeTitle;

  /// No description provided for @atcUtility.
  ///
  /// In en, this message translates to:
  /// **'utility'**
  String get atcUtility;

  /// No description provided for @atcWaitingOk.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your OK'**
  String get atcWaitingOk;

  /// No description provided for @atcWhatPay.
  ///
  /// In en, this message translates to:
  /// **'What do you pay regularly?'**
  String get atcWhatPay;

  /// No description provided for @atcYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get atcYearly;

  /// No description provided for @atcYesRemind.
  ///
  /// In en, this message translates to:
  /// **'Yes, remind me'**
  String get atcYesRemind;

  /// No description provided for @autoLock.
  ///
  /// In en, this message translates to:
  /// **'Lock after time in the background'**
  String get autoLock;

  /// No description provided for @autoLockMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String autoLockMinutes(String n);

  /// No description provided for @autoReminderOn.
  ///
  /// In en, this message translates to:
  /// **'⚡ Auto-reminder on'**
  String get autoReminderOn;

  /// No description provided for @calAllDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get calAllDay;

  /// No description provided for @calCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 event} other{{n} events}}'**
  String calCount(int n);

  /// No description provided for @calDenied.
  ///
  /// In en, this message translates to:
  /// **'LifeOS needs calendar access to show your events.'**
  String get calDenied;

  /// No description provided for @calEventsHeader.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get calEventsHeader;

  /// No description provided for @calFromCalendar.
  ///
  /// In en, this message translates to:
  /// **'In {name}'**
  String calFromCalendar(String name);

  /// No description provided for @calLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get calLocation;

  /// No description provided for @calNoCalendars.
  ///
  /// In en, this message translates to:
  /// **'No calendars found on this phone.'**
  String get calNoCalendars;

  /// No description provided for @calOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get calOpenSettings;

  /// No description provided for @calReadOnly.
  ///
  /// In en, this message translates to:
  /// **'From your phone\'s calendar. Change it there.'**
  String get calReadOnly;

  /// No description provided for @calSection.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calSection;

  /// No description provided for @calShowEvents.
  ///
  /// In en, this message translates to:
  /// **'Show calendar events'**
  String get calShowEvents;

  /// No description provided for @calShowEventsHint.
  ///
  /// In en, this message translates to:
  /// **'Your phone\'s events appear in Today and Upcoming. LifeOS only reads them — it never adds, changes or deletes anything.'**
  String get calShowEventsHint;

  /// No description provided for @calWhichCalendars.
  ///
  /// In en, this message translates to:
  /// **'Calendars to show'**
  String get calWhichCalendars;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @cpAllDocuments.
  ///
  /// In en, this message translates to:
  /// **'All documents'**
  String get cpAllDocuments;

  /// No description provided for @cpBatchHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a document to check or change it.'**
  String get cpBatchHint;

  /// No description provided for @cpBatchTitle.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{File 1 document} other{File {n} documents}}'**
  String cpBatchTitle(int n);

  /// No description provided for @cpBelongsTo.
  ///
  /// In en, this message translates to:
  /// **'Belongs to'**
  String get cpBelongsTo;

  /// No description provided for @cpBillTaskUpdated.
  ///
  /// In en, this message translates to:
  /// **'⚡ Bill task updated'**
  String get cpBillTaskUpdated;

  /// No description provided for @cpBlurryBody.
  ///
  /// In en, this message translates to:
  /// **'Image looks unclear — text may be hard to read later.'**
  String get cpBlurryBody;

  /// No description provided for @cpBlurryPageBody.
  ///
  /// In en, this message translates to:
  /// **'Page {pages} looks unclear — text may be hard to read later.'**
  String cpBlurryPageBody(String pages);

  /// No description provided for @cpDiscardNew.
  ///
  /// In en, this message translates to:
  /// **'Discard new'**
  String get cpDiscardNew;

  /// No description provided for @cpDiscardThis.
  ///
  /// In en, this message translates to:
  /// **'Discard this one'**
  String get cpDiscardThis;

  /// No description provided for @cpDiscarded.
  ///
  /// In en, this message translates to:
  /// **'Discarded'**
  String get cpDiscarded;

  /// No description provided for @cpDropPage.
  ///
  /// In en, this message translates to:
  /// **'Remove page {pages}'**
  String cpDropPage(String pages);

  /// No description provided for @cpDuplicateBody.
  ///
  /// In en, this message translates to:
  /// **'Looks like a duplicate of \'{title}\', saved {date}. Keep both?'**
  String cpDuplicateBody(String title, String date);

  /// No description provided for @cpDuplicateDiscarded.
  ///
  /// In en, this message translates to:
  /// **'Duplicate discarded'**
  String get cpDuplicateDiscarded;

  /// No description provided for @cpDuplicateTitle.
  ///
  /// In en, this message translates to:
  /// **'Possible duplicate'**
  String get cpDuplicateTitle;

  /// No description provided for @cpFieldBillingMonth.
  ///
  /// In en, this message translates to:
  /// **'Billing month'**
  String get cpFieldBillingMonth;

  /// No description provided for @cpFieldDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get cpFieldDoctor;

  /// No description provided for @cpFieldDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get cpFieldDueDate;

  /// No description provided for @cpFieldEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get cpFieldEndDate;

  /// No description provided for @cpFieldExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry date'**
  String get cpFieldExpiryDate;

  /// No description provided for @cpFieldInstitution.
  ///
  /// In en, this message translates to:
  /// **'Institution'**
  String get cpFieldInstitution;

  /// No description provided for @cpFieldIssueDate.
  ///
  /// In en, this message translates to:
  /// **'Issue date'**
  String get cpFieldIssueDate;

  /// No description provided for @cpFieldIssuer.
  ///
  /// In en, this message translates to:
  /// **'Issuer'**
  String get cpFieldIssuer;

  /// No description provided for @cpFieldNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get cpFieldNumber;

  /// No description provided for @cpFieldProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get cpFieldProduct;

  /// No description provided for @cpFieldRefNumber.
  ///
  /// In en, this message translates to:
  /// **'Reference no.'**
  String get cpFieldRefNumber;

  /// No description provided for @cpFieldStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get cpFieldStartDate;

  /// No description provided for @cpFieldStudent.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get cpFieldStudent;

  /// No description provided for @cpFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get cpFolder;

  /// No description provided for @cpHeldBack.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 needs a check} other{{n} need a check}}'**
  String cpHeldBack(int n);

  /// No description provided for @cpImportFile.
  ///
  /// In en, this message translates to:
  /// **'Import a file'**
  String get cpImportFile;

  /// No description provided for @cpJpeg.
  ///
  /// In en, this message translates to:
  /// **'JPEG'**
  String get cpJpeg;

  /// No description provided for @cpKeepAnyway.
  ///
  /// In en, this message translates to:
  /// **'Keep anyway'**
  String get cpKeepAnyway;

  /// No description provided for @cpKeepBoth.
  ///
  /// In en, this message translates to:
  /// **'Keep both'**
  String get cpKeepBoth;

  /// No description provided for @cpMaybeDuplicate.
  ///
  /// In en, this message translates to:
  /// **'May be a duplicate of \'{title}\''**
  String cpMaybeDuplicate(String title);

  /// No description provided for @cpNobody.
  ///
  /// In en, this message translates to:
  /// **'Nobody'**
  String get cpNobody;

  /// No description provided for @cpNotSure.
  ///
  /// In en, this message translates to:
  /// **'Not sure what this is — please pick a type.'**
  String get cpNotSure;

  /// No description provided for @cpNothingLeft.
  ///
  /// In en, this message translates to:
  /// **'Nothing left to file'**
  String get cpNothingLeft;

  /// No description provided for @cpPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {n} of {total}'**
  String cpPageOf(String n, String total);

  /// No description provided for @cpPages.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 page} other{{n} pages}}'**
  String cpPages(int n);

  /// No description provided for @cpPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get cpPdf;

  /// No description provided for @cpPdfTitle.
  ///
  /// In en, this message translates to:
  /// **'LifeOS scan'**
  String get cpPdfTitle;

  /// No description provided for @cpPickType.
  ///
  /// In en, this message translates to:
  /// **'Pick a type'**
  String get cpPickType;

  /// No description provided for @cpReading.
  ///
  /// In en, this message translates to:
  /// **'Reading document…'**
  String get cpReading;

  /// No description provided for @cpRetake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get cpRetake;

  /// No description provided for @cpRetakeTitle.
  ///
  /// In en, this message translates to:
  /// **'Retake?'**
  String get cpRetakeTitle;

  /// No description provided for @cpSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as'**
  String get cpSaveAs;

  /// No description provided for @cpSaveReady.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{Nothing ready yet} =1{Save 1 ready document} other{Save {n} ready documents}}'**
  String cpSaveReady(int n);

  /// No description provided for @cpSaveToVault.
  ///
  /// In en, this message translates to:
  /// **'Save to Vault'**
  String get cpSaveToVault;

  /// No description provided for @cpSaveToVaultOf.
  ///
  /// In en, this message translates to:
  /// **'Save to Vault · 1 of {total}'**
  String cpSaveToVaultOf(String total);

  /// No description provided for @cpSavedCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 document saved to Vault} other{{n} documents saved to Vault}}'**
  String cpSavedCount(int n);

  /// No description provided for @cpSavedToVault.
  ///
  /// In en, this message translates to:
  /// **'Saved to Vault'**
  String get cpSavedToVault;

  /// No description provided for @cpScanAnother.
  ///
  /// In en, this message translates to:
  /// **'Scan another'**
  String get cpScanAnother;

  /// No description provided for @cpScanAnyway.
  ///
  /// In en, this message translates to:
  /// **'Scan anyway'**
  String get cpScanAnyway;

  /// No description provided for @cpScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan · {date} {year}'**
  String cpScanTitle(String date, String year);

  /// No description provided for @cpStatusCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get cpStatusCheck;

  /// No description provided for @cpStatusNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get cpStatusNew;

  /// No description provided for @cpStatusReading.
  ///
  /// In en, this message translates to:
  /// **'Reading…'**
  String get cpStatusReading;

  /// No description provided for @cpStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get cpStatusReady;

  /// No description provided for @cpStorageFullBody.
  ///
  /// In en, this message translates to:
  /// **'Only {mb} MB free. Scans may not save — free up some space first, or scan anyway.'**
  String cpStorageFullBody(String mb);

  /// No description provided for @cpStorageFullTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage is almost full'**
  String get cpStorageFullTitle;

  /// No description provided for @cpTypeAgreement.
  ///
  /// In en, this message translates to:
  /// **'Agreement'**
  String get cpTypeAgreement;

  /// No description provided for @cpTypeBill.
  ///
  /// In en, this message translates to:
  /// **'Bill'**
  String get cpTypeBill;

  /// No description provided for @cpTypeCertificate.
  ///
  /// In en, this message translates to:
  /// **'Certificate'**
  String get cpTypeCertificate;

  /// No description provided for @cpTypeCnic.
  ///
  /// In en, this message translates to:
  /// **'CNIC'**
  String get cpTypeCnic;

  /// No description provided for @cpTypeConfidence.
  ///
  /// In en, this message translates to:
  /// **'{type} · {percent}%'**
  String cpTypeConfidence(String type, String percent);

  /// No description provided for @cpTypeDegree.
  ///
  /// In en, this message translates to:
  /// **'Degree'**
  String get cpTypeDegree;

  /// No description provided for @cpTypeFeeVoucher.
  ///
  /// In en, this message translates to:
  /// **'Fee voucher'**
  String get cpTypeFeeVoucher;

  /// No description provided for @cpTypeLicense.
  ///
  /// In en, this message translates to:
  /// **'Driving licence'**
  String get cpTypeLicense;

  /// No description provided for @cpTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get cpTypeOther;

  /// No description provided for @cpTypePassport.
  ///
  /// In en, this message translates to:
  /// **'Passport'**
  String get cpTypePassport;

  /// No description provided for @cpTypePolicy.
  ///
  /// In en, this message translates to:
  /// **'Insurance policy'**
  String get cpTypePolicy;

  /// No description provided for @cpTypePrescription.
  ///
  /// In en, this message translates to:
  /// **'Prescription'**
  String get cpTypePrescription;

  /// No description provided for @cpTypeReceipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get cpTypeReceipt;

  /// No description provided for @cpTypeReport.
  ///
  /// In en, this message translates to:
  /// **'Lab report'**
  String get cpTypeReport;

  /// No description provided for @cpTypeVisa.
  ///
  /// In en, this message translates to:
  /// **'Visa'**
  String get cpTypeVisa;

  /// No description provided for @cpTypeWarranty.
  ///
  /// In en, this message translates to:
  /// **'Warranty'**
  String get cpTypeWarranty;

  /// No description provided for @cpUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get cpUndo;

  /// No description provided for @cpUnfiled.
  ///
  /// In en, this message translates to:
  /// **'📥 Unfiled'**
  String get cpUnfiled;

  /// No description provided for @cpUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read any text — saved as Unclassified. Pick a type if you like.'**
  String get cpUnreadable;

  /// No description provided for @cpUnusualBill.
  ///
  /// In en, this message translates to:
  /// **'Unusually high bill ⚠'**
  String get cpUnusualBill;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @dayOfMonth.
  ///
  /// In en, this message translates to:
  /// **'Day of month'**
  String get dayOfMonth;

  /// No description provided for @deleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all local data'**
  String get deleteAll;

  /// No description provided for @deleteAllBody.
  ///
  /// In en, this message translates to:
  /// **'All documents, tasks, payments and keys on this phone will be deleted. This can\'t be undone.'**
  String get deleteAllBody;

  /// No description provided for @deleteAllConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteAllConfirmHint;

  /// No description provided for @deleteAllConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE to confirm'**
  String get deleteAllConfirmTitle;

  /// No description provided for @deleteAllSub.
  ///
  /// In en, this message translates to:
  /// **'Removes everything from this phone'**
  String get deleteAllSub;

  /// No description provided for @deleteAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete everything?'**
  String get deleteAllTitle;

  /// No description provided for @deleteForever.
  ///
  /// In en, this message translates to:
  /// **'Delete forever'**
  String get deleteForever;

  /// No description provided for @dgClear.
  ///
  /// In en, this message translates to:
  /// **'Clear logs'**
  String get dgClear;

  /// No description provided for @dgCleared.
  ///
  /// In en, this message translates to:
  /// **'Logs cleared'**
  String get dgCleared;

  /// No description provided for @dgCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 entry} other{{n} entries}}'**
  String dgCount(int n);

  /// No description provided for @dgEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet'**
  String get dgEmpty;

  /// No description provided for @dgEntry.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics & logs'**
  String get dgEntry;

  /// No description provided for @dgEntrySub.
  ///
  /// In en, this message translates to:
  /// **'For testing: see and share the app\'s log'**
  String get dgEntrySub;

  /// No description provided for @dgErrorsCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{no errors} =1{1 error} other{{n} errors}}'**
  String dgErrorsCount(int n);

  /// No description provided for @dgErrorsOnly.
  ///
  /// In en, this message translates to:
  /// **'Errors only'**
  String get dgErrorsOnly;

  /// No description provided for @dgPrivacy.
  ///
  /// In en, this message translates to:
  /// **'The log stays on this phone and has no personal data. It is only sent if you tap Share.'**
  String get dgPrivacy;

  /// No description provided for @dgShare.
  ///
  /// In en, this message translates to:
  /// **'Share logs'**
  String get dgShare;

  /// No description provided for @dgTestError.
  ///
  /// In en, this message translates to:
  /// **'Record a test error'**
  String get dgTestError;

  /// No description provided for @dgTestErrorText.
  ///
  /// In en, this message translates to:
  /// **'Test error recorded from Diagnostics'**
  String get dgTestErrorText;

  /// No description provided for @dgTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get dgTitle;

  /// No description provided for @digestBills.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{no bills due} =1{1 bill due} other{{n} bills due}}'**
  String digestBills(int n);

  /// No description provided for @digestBody.
  ///
  /// In en, this message translates to:
  /// **'Life Score {score} · {tasks} · {bills}'**
  String digestBody(String score, String tasks, String bills);

  /// No description provided for @digestTasks.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{no tasks} =1{1 task} other{{n} tasks}}'**
  String digestTasks(int n);

  /// No description provided for @digestTime.
  ///
  /// In en, this message translates to:
  /// **'Morning summary'**
  String get digestTime;

  /// No description provided for @domainHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get domainHealth;

  /// No description provided for @domainMind.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get domainMind;

  /// No description provided for @domainMoney.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get domainMoney;

  /// No description provided for @domainPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get domainPeople;

  /// No description provided for @domainSoul.
  ///
  /// In en, this message translates to:
  /// **'Soul'**
  String get domainSoul;

  /// No description provided for @domainVault.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get domainVault;

  /// No description provided for @domainWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get domainWork;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export everything'**
  String get exportData;

  /// No description provided for @exportDataSub.
  ///
  /// In en, this message translates to:
  /// **'A ZIP of your documents and data'**
  String get exportDataSub;

  /// No description provided for @exportDone.
  ///
  /// In en, this message translates to:
  /// **'Export ready: {docs} documents'**
  String exportDone(String docs);

  /// No description provided for @exporting.
  ///
  /// In en, this message translates to:
  /// **'Preparing your export…'**
  String get exporting;

  /// No description provided for @freeLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Free plan includes 3 auto-rules — Premium removes the limit'**
  String get freeLimitReached;

  /// No description provided for @hmAddTask.
  ///
  /// In en, this message translates to:
  /// **'➕ Add a task'**
  String get hmAddTask;

  /// No description provided for @hmAllClear.
  ///
  /// In en, this message translates to:
  /// **'All clear today ✓'**
  String get hmAllClear;

  /// No description provided for @hmAttentionSection.
  ///
  /// In en, this message translates to:
  /// **'⚠ Needs attention'**
  String get hmAttentionSection;

  /// No description provided for @hmClearDay.
  ///
  /// In en, this message translates to:
  /// **'A clear day.'**
  String get hmClearDay;

  /// No description provided for @hmDueIn.
  ///
  /// In en, this message translates to:
  /// **'due in {n} days'**
  String hmDueIn(String n);

  /// No description provided for @hmDueToday.
  ///
  /// In en, this message translates to:
  /// **'due today'**
  String get hmDueToday;

  /// No description provided for @hmDueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'due tomorrow'**
  String get hmDueTomorrow;

  /// No description provided for @hmExpiredAgo.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{expired 1 day ago} other{expired {n} days ago}}'**
  String hmExpiredAgo(int n);

  /// No description provided for @hmExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'expires in {n} days'**
  String hmExpiresIn(String n);

  /// No description provided for @hmExpiresToday.
  ///
  /// In en, this message translates to:
  /// **'expires today'**
  String get hmExpiresToday;

  /// No description provided for @hmExpiresTomorrow.
  ///
  /// In en, this message translates to:
  /// **'expires tomorrow'**
  String get hmExpiresTomorrow;

  /// No description provided for @hmGreetAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon 👋'**
  String get hmGreetAfternoon;

  /// No description provided for @hmGreetAfternoonName.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon, {name} 👋'**
  String hmGreetAfternoonName(String name);

  /// No description provided for @hmGreetCustom.
  ///
  /// In en, this message translates to:
  /// **'{greeting} 👋'**
  String hmGreetCustom(String greeting);

  /// No description provided for @hmGreetCustomName.
  ///
  /// In en, this message translates to:
  /// **'{greeting}, {name} 👋'**
  String hmGreetCustomName(String greeting, String name);

  /// No description provided for @hmGreetEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening 🌆'**
  String get hmGreetEvening;

  /// No description provided for @hmGreetEveningName.
  ///
  /// In en, this message translates to:
  /// **'Good evening, {name} 🌆'**
  String hmGreetEveningName(String name);

  /// No description provided for @hmGreetHello.
  ///
  /// In en, this message translates to:
  /// **'Hello 👋'**
  String get hmGreetHello;

  /// No description provided for @hmGreetHelloName.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name} 👋'**
  String hmGreetHelloName(String name);

  /// No description provided for @hmGreetMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning ☀️'**
  String get hmGreetMorning;

  /// No description provided for @hmGreetMorningName.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name} ☀️'**
  String hmGreetMorningName(String name);

  /// No description provided for @hmGreetNamaste.
  ///
  /// In en, this message translates to:
  /// **'Namaste 🙏'**
  String get hmGreetNamaste;

  /// No description provided for @hmGreetNamasteName.
  ///
  /// In en, this message translates to:
  /// **'Namaste, {name} 🙏'**
  String hmGreetNamasteName(String name);

  /// No description provided for @hmGreetNight.
  ///
  /// In en, this message translates to:
  /// **'Working late? 🌙'**
  String get hmGreetNight;

  /// No description provided for @hmGreetNightName.
  ///
  /// In en, this message translates to:
  /// **'Working late, {name}? 🌙'**
  String hmGreetNightName(String name);

  /// No description provided for @hmGreetSalam.
  ///
  /// In en, this message translates to:
  /// **'Salam 👋'**
  String get hmGreetSalam;

  /// No description provided for @hmGreetSalamName.
  ///
  /// In en, this message translates to:
  /// **'Salam, {name} 👋'**
  String hmGreetSalamName(String name);

  /// No description provided for @hmNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get hmNeedsAttention;

  /// No description provided for @hmNoPaymentsWeek.
  ///
  /// In en, this message translates to:
  /// **'No payments due this week'**
  String get hmNoPaymentsWeek;

  /// No description provided for @hmNothingUrgent.
  ///
  /// In en, this message translates to:
  /// **'Nothing urgent'**
  String get hmNothingUrgent;

  /// No description provided for @hmNothingUrgentBody.
  ///
  /// In en, this message translates to:
  /// **'Payments due soon and expiring documents show here.'**
  String get hmNothingUrgentBody;

  /// No description provided for @hmNothingUrgentNice.
  ///
  /// In en, this message translates to:
  /// **'Nothing urgent — nice ✓'**
  String get hmNothingUrgentNice;

  /// No description provided for @hmPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get hmPaid;

  /// No description provided for @hmPaymentsWeek.
  ///
  /// In en, this message translates to:
  /// **'{amount} in payments this week'**
  String hmPaymentsWeek(String amount);

  /// No description provided for @hmPromptAtcBody.
  ///
  /// In en, this message translates to:
  /// **'Rent, fees, bills: reminded every month, automatically.'**
  String get hmPromptAtcBody;

  /// No description provided for @hmPromptAtcTitle.
  ///
  /// In en, this message translates to:
  /// **'Add what you pay regularly ⚡'**
  String get hmPromptAtcTitle;

  /// No description provided for @hmPromptScanBody.
  ///
  /// In en, this message translates to:
  /// **'CNIC, passport, a bill — LifeOS files it and reminds you.'**
  String get hmPromptScanBody;

  /// No description provided for @hmPromptScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan your first document 📸'**
  String get hmPromptScanTitle;

  /// No description provided for @hmPromptTaskBody.
  ///
  /// In en, this message translates to:
  /// **'Anything on your mind, with a reminder.'**
  String get hmPromptTaskBody;

  /// No description provided for @hmPromptTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a task ➕'**
  String get hmPromptTaskTitle;

  /// No description provided for @hmSeeAllCount.
  ///
  /// In en, this message translates to:
  /// **'See all ({n})'**
  String hmSeeAllCount(String n);

  /// No description provided for @hmSeeAllN.
  ///
  /// In en, this message translates to:
  /// **'See all {n}'**
  String hmSeeAllN(String n);

  /// No description provided for @hmSoon.
  ///
  /// In en, this message translates to:
  /// **'Soon'**
  String get hmSoon;

  /// No description provided for @hmThingsNeedAttention.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 thing needs attention} other{{n} things need attention}}'**
  String hmThingsNeedAttention(int n);

  /// No description provided for @hmTodayTasks.
  ///
  /// In en, this message translates to:
  /// **'Today · {n, plural, =1{1 task} other{{n} tasks}}'**
  String hmTodayTasks(int n);

  /// No description provided for @hmTodayTasksEvents.
  ///
  /// In en, this message translates to:
  /// **'Today · {tasks} · {events}'**
  String hmTodayTasksEvents(String tasks, String events);

  /// No description provided for @hmUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get hmUrgent;

  /// No description provided for @hmWasDueAgo.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{was due 1 day ago} other{was due {n} days ago}}'**
  String hmWasDueAgo(int n);

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageUrdu.
  ///
  /// In en, this message translates to:
  /// **'اردو'**
  String get languageUrdu;

  /// No description provided for @lockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Set a screen lock on this phone to use this'**
  String get lockUnavailable;

  /// No description provided for @lockedTitle.
  ///
  /// In en, this message translates to:
  /// **'LifeOS is locked'**
  String get lockedTitle;

  /// No description provided for @lookTemplate.
  ///
  /// In en, this message translates to:
  /// **'Look'**
  String get lookTemplate;

  /// No description provided for @mnAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get mnAdd;

  /// No description provided for @mnAddExpense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get mnAddExpense;

  /// No description provided for @mnAddExpenseAction.
  ///
  /// In en, this message translates to:
  /// **'💸 Add expense'**
  String get mnAddExpenseAction;

  /// No description provided for @mnAddSalary.
  ///
  /// In en, this message translates to:
  /// **'Add your salary to see the share'**
  String get mnAddSalary;

  /// No description provided for @mnAmountError.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount above 0'**
  String get mnAmountError;

  /// No description provided for @mnAmountPaid.
  ///
  /// In en, this message translates to:
  /// **'Amount paid'**
  String get mnAmountPaid;

  /// No description provided for @mnAmountPending.
  ///
  /// In en, this message translates to:
  /// **'amount pending'**
  String get mnAmountPending;

  /// No description provided for @mnAttachReceipt.
  ///
  /// In en, this message translates to:
  /// **'📎 Attach receipt?'**
  String get mnAttachReceipt;

  /// No description provided for @mnBreakdownItem.
  ///
  /// In en, this message translates to:
  /// **'{name} {amount}, {percent} percent'**
  String mnBreakdownItem(String name, String amount, String percent);

  /// No description provided for @mnBreakdownSemantics.
  ///
  /// In en, this message translates to:
  /// **'Spending by category: {items}'**
  String mnBreakdownSemantics(String items);

  /// No description provided for @mnCatFees.
  ///
  /// In en, this message translates to:
  /// **'Fees & Tuition'**
  String get mnCatFees;

  /// No description provided for @mnCatInstallment.
  ///
  /// In en, this message translates to:
  /// **'Installments'**
  String get mnCatInstallment;

  /// No description provided for @mnCatInternet.
  ///
  /// In en, this message translates to:
  /// **'Internet'**
  String get mnCatInternet;

  /// No description provided for @mnCatMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get mnCatMobile;

  /// No description provided for @mnCatOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get mnCatOther;

  /// No description provided for @mnCatRent.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get mnCatRent;

  /// No description provided for @mnCatSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get mnCatSubscription;

  /// No description provided for @mnCatUtilities.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get mnCatUtilities;

  /// No description provided for @mnCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get mnCategory;

  /// No description provided for @mnChangeSalary.
  ///
  /// In en, this message translates to:
  /// **'Change salary'**
  String get mnChangeSalary;

  /// No description provided for @mnDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get mnDate;

  /// No description provided for @mnDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get mnDelete;

  /// No description provided for @mnDeltaNew.
  ///
  /// In en, this message translates to:
  /// **'New · nothing in {month}'**
  String mnDeltaNew(String month);

  /// No description provided for @mnDeltaSame.
  ///
  /// In en, this message translates to:
  /// **'Same as {month}'**
  String mnDeltaSame(String month);

  /// No description provided for @mnDeltaVs.
  ///
  /// In en, this message translates to:
  /// **'{percent}% vs {month}'**
  String mnDeltaVs(String percent, String month);

  /// No description provided for @mnDigest.
  ///
  /// In en, this message translates to:
  /// **'{month} fixed payments: {total} across {n, plural, =1{1 item} other{{n} items}}'**
  String mnDigest(String month, String total, int n);

  /// No description provided for @mnEditExpense.
  ///
  /// In en, this message translates to:
  /// **'Edit expense'**
  String get mnEditExpense;

  /// No description provided for @mnExpensesCount.
  ///
  /// In en, this message translates to:
  /// **'Expenses · {n}'**
  String mnExpensesCount(String n);

  /// No description provided for @mnFiledInVault.
  ///
  /// In en, this message translates to:
  /// **'Filed in Vault'**
  String get mnFiledInVault;

  /// No description provided for @mnForecast.
  ///
  /// In en, this message translates to:
  /// **'Forecast'**
  String get mnForecast;

  /// No description provided for @mnImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get mnImport;

  /// No description provided for @mnLinkedNote.
  ///
  /// In en, this message translates to:
  /// **'⚡ Logged from a payment'**
  String get mnLinkedNote;

  /// No description provided for @mnLoggedFromPayment.
  ///
  /// In en, this message translates to:
  /// **'Logged from a payment'**
  String get mnLoggedFromPayment;

  /// No description provided for @mnLoggedInMoney.
  ///
  /// In en, this message translates to:
  /// **'Logged in Money'**
  String get mnLoggedInMoney;

  /// No description provided for @mnMarkPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark paid'**
  String get mnMarkPaid;

  /// No description provided for @mnMonthlySalary.
  ///
  /// In en, this message translates to:
  /// **'Monthly salary'**
  String get mnMonthlySalary;

  /// No description provided for @mnNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get mnNextMonth;

  /// No description provided for @mnNoExpensesBody.
  ///
  /// In en, this message translates to:
  /// **'Paid bills and quick expenses will add up here.'**
  String get mnNoExpensesBody;

  /// No description provided for @mnNoExpensesIn.
  ///
  /// In en, this message translates to:
  /// **'No expenses in {month}'**
  String mnNoExpensesIn(String month);

  /// No description provided for @mnNoFixedBody.
  ///
  /// In en, this message translates to:
  /// **'Add what you pay regularly in More → Auto Tasks and the forecast fills itself.'**
  String get mnNoFixedBody;

  /// No description provided for @mnNoFixedTitle.
  ///
  /// In en, this message translates to:
  /// **'No fixed payments this month'**
  String get mnNoFixedTitle;

  /// No description provided for @mnNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get mnNoteHint;

  /// No description provided for @mnOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get mnOverview;

  /// No description provided for @mnPaidAmountLine.
  ///
  /// In en, this message translates to:
  /// **'✓ {title} — {amount} paid'**
  String mnPaidAmountLine(String title, String amount);

  /// No description provided for @mnPaidDone.
  ///
  /// In en, this message translates to:
  /// **'✓ Paid'**
  String get mnPaidDone;

  /// No description provided for @mnPaidHowMuch.
  ///
  /// In en, this message translates to:
  /// **'✓ {title} — how much did you pay?'**
  String mnPaidHowMuch(String title);

  /// No description provided for @mnPaidOnDay.
  ///
  /// In en, this message translates to:
  /// **'Paid on day'**
  String get mnPaidOnDay;

  /// No description provided for @mnPrevMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get mnPrevMonth;

  /// No description provided for @mnReceiptAttached.
  ///
  /// In en, this message translates to:
  /// **'Receipt attached'**
  String get mnReceiptAttached;

  /// No description provided for @mnReceiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt — {title}'**
  String mnReceiptTitle(String title);

  /// No description provided for @mnSalaryShare.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of income goes to fixed payments'**
  String mnSalaryShare(String percent);

  /// No description provided for @mnSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get mnSave;

  /// No description provided for @mnScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get mnScan;

  /// No description provided for @mnSpendingByCategory.
  ///
  /// In en, this message translates to:
  /// **'Spending by category'**
  String get mnSpendingByCategory;

  /// No description provided for @mnSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get mnSpent;

  /// No description provided for @mnStatusOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue 🔴'**
  String get mnStatusOverdue;

  /// No description provided for @mnStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid ✓'**
  String get mnStatusPaid;

  /// No description provided for @mnStatusUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get mnStatusUpcoming;

  /// No description provided for @mnStatusUpcomingPlanned.
  ///
  /// In en, this message translates to:
  /// **'Upcoming · planned'**
  String get mnStatusUpcomingPlanned;

  /// No description provided for @mnTitle.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get mnTitle;

  /// No description provided for @mnTotals.
  ///
  /// In en, this message translates to:
  /// **'{total} total · {paid} paid · {remaining} remaining'**
  String mnTotals(String total, String paid, String remaining);

  /// No description provided for @mnUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Local data could not be opened on this device.'**
  String get mnUnavailableBody;

  /// No description provided for @mnUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Money isn\'t available'**
  String get mnUnavailableTitle;

  /// No description provided for @mnUncategorised.
  ///
  /// In en, this message translates to:
  /// **'Uncategorised'**
  String get mnUncategorised;

  /// No description provided for @mnUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get mnUndo;

  /// No description provided for @mnYourSalary.
  ///
  /// In en, this message translates to:
  /// **'Your salary'**
  String get mnYourSalary;

  /// No description provided for @mon1.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get mon1;

  /// No description provided for @mon10.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get mon10;

  /// No description provided for @mon11.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get mon11;

  /// No description provided for @mon12.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get mon12;

  /// No description provided for @mon2.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get mon2;

  /// No description provided for @mon3.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get mon3;

  /// No description provided for @mon4.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get mon4;

  /// No description provided for @mon5.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get mon5;

  /// No description provided for @mon6.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get mon6;

  /// No description provided for @mon7.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get mon7;

  /// No description provided for @mon8.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get mon8;

  /// No description provided for @mon9.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get mon9;

  /// No description provided for @month1.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get month1;

  /// No description provided for @month10.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get month10;

  /// No description provided for @month11.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get month11;

  /// No description provided for @month12.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get month12;

  /// No description provided for @month2.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get month2;

  /// No description provided for @month3.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get month3;

  /// No description provided for @month4.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get month4;

  /// No description provided for @month5.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get month5;

  /// No description provided for @month6.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get month6;

  /// No description provided for @month7.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get month7;

  /// No description provided for @month8.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get month8;

  /// No description provided for @month9.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get month9;

  /// No description provided for @moreSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get moreSettings;

  /// No description provided for @moreSettingsSub.
  ///
  /// In en, this message translates to:
  /// **'Security, notifications, language, data'**
  String get moreSettingsSub;

  /// No description provided for @mrAutoTasks.
  ///
  /// In en, this message translates to:
  /// **'Auto Tasks'**
  String get mrAutoTasks;

  /// No description provided for @mrAutoTasksSub.
  ///
  /// In en, this message translates to:
  /// **'Rules that create payment tasks for you'**
  String get mrAutoTasksSub;

  /// No description provided for @mrProfile.
  ///
  /// In en, this message translates to:
  /// **'My profile'**
  String get mrProfile;

  /// No description provided for @mrProfileSub.
  ///
  /// In en, this message translates to:
  /// **'Your name, greeting and language'**
  String get mrProfileSub;

  /// No description provided for @mrTitle.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get mrTitle;

  /// No description provided for @mrTrashSub.
  ///
  /// In en, this message translates to:
  /// **'Deleted documents, kept for 30 days'**
  String get mrTrashSub;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @notifyAbout.
  ///
  /// In en, this message translates to:
  /// **'Notify me about'**
  String get notifyAbout;

  /// No description provided for @obDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re set'**
  String get obDoneTitle;

  /// No description provided for @obForecast.
  ///
  /// In en, this message translates to:
  /// **'{month} fixed payments: {total}'**
  String obForecast(String month, String total);

  /// No description provided for @obForecastNone.
  ///
  /// In en, this message translates to:
  /// **'Add payments any time from More → Auto Tasks.'**
  String get obForecastNone;

  /// No description provided for @obNotifAsk.
  ///
  /// In en, this message translates to:
  /// **'We\'ll remind you before things are due.'**
  String get obNotifAsk;

  /// No description provided for @obPayBody.
  ///
  /// In en, this message translates to:
  /// **'Tap one, add the amount and day. LifeOS reminds you every month.'**
  String get obPayBody;

  /// No description provided for @obPayTitle.
  ///
  /// In en, this message translates to:
  /// **'What do you pay every month?'**
  String get obPayTitle;

  /// No description provided for @obRoleQ.
  ///
  /// In en, this message translates to:
  /// **'Who are you organising for?'**
  String get obRoleQ;

  /// No description provided for @obScanBody.
  ///
  /// In en, this message translates to:
  /// **'A CNIC, passport or bill. LifeOS reads it and files it for you.'**
  String get obScanBody;

  /// No description provided for @obScanNow.
  ///
  /// In en, this message translates to:
  /// **'📸 Scan now'**
  String get obScanNow;

  /// No description provided for @obScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan your first document'**
  String get obScanTitle;

  /// No description provided for @obSeeDashboard.
  ///
  /// In en, this message translates to:
  /// **'See my dashboard'**
  String get obSeeDashboard;

  /// No description provided for @obWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to LifeOS'**
  String get obWelcome;

  /// No description provided for @parseHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get parseHigh;

  /// No description provided for @payCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get payCustom;

  /// No description provided for @payElectricity.
  ///
  /// In en, this message translates to:
  /// **'Electricity'**
  String get payElectricity;

  /// No description provided for @payGas.
  ///
  /// In en, this message translates to:
  /// **'Gas'**
  String get payGas;

  /// No description provided for @payInstallment.
  ///
  /// In en, this message translates to:
  /// **'Installment'**
  String get payInstallment;

  /// No description provided for @payInternet.
  ///
  /// In en, this message translates to:
  /// **'Internet'**
  String get payInternet;

  /// No description provided for @payMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get payMobile;

  /// No description provided for @payRent.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get payRent;

  /// No description provided for @paySchoolFee.
  ///
  /// In en, this message translates to:
  /// **'School fee'**
  String get paySchoolFee;

  /// No description provided for @profileAboutYou.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get profileAboutYou;

  /// No description provided for @profileAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get profileAuto;

  /// No description provided for @profileAutoValue.
  ///
  /// In en, this message translates to:
  /// **'Auto ({value})'**
  String profileAutoValue(String value);

  /// No description provided for @profileCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency symbol'**
  String get profileCurrency;

  /// No description provided for @profileCurrencyOther.
  ///
  /// In en, this message translates to:
  /// **'Another symbol'**
  String get profileCurrencyOther;

  /// No description provided for @profileDateOrder.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get profileDateOrder;

  /// No description provided for @profileNameLabel.
  ///
  /// In en, this message translates to:
  /// **'What should we call you?'**
  String get profileNameLabel;

  /// No description provided for @profileRegion.
  ///
  /// In en, this message translates to:
  /// **'Region & formats'**
  String get profileRegion;

  /// No description provided for @profileWeekStart.
  ///
  /// In en, this message translates to:
  /// **'Week starts on'**
  String get profileWeekStart;

  /// No description provided for @quietHours.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get quietHours;

  /// No description provided for @quietHoursValue.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String quietHoursValue(String from, String to);

  /// No description provided for @removeChip.
  ///
  /// In en, this message translates to:
  /// **'Remove {what}'**
  String removeChip(String what);

  /// No description provided for @roleBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business owner'**
  String get roleBusiness;

  /// No description provided for @roleJustMe.
  ///
  /// In en, this message translates to:
  /// **'Just me'**
  String get roleJustMe;

  /// No description provided for @roleParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get roleParent;

  /// No description provided for @roleProfessional.
  ///
  /// In en, this message translates to:
  /// **'Professional'**
  String get roleProfessional;

  /// No description provided for @roleStudent.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get roleStudent;

  /// No description provided for @scCompBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get scCompBalance;

  /// No description provided for @scCompDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get scCompDocuments;

  /// No description provided for @scCompHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get scCompHealth;

  /// No description provided for @scCompPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get scCompPayments;

  /// No description provided for @scCompPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get scCompPeople;

  /// No description provided for @scCompTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get scCompTasks;

  /// No description provided for @scComponentSemantics.
  ///
  /// In en, this message translates to:
  /// **'{name}: {pct} percent, {weight} percent of the score'**
  String scComponentSemantics(String name, String pct, String weight);

  /// No description provided for @scComponentValue.
  ///
  /// In en, this message translates to:
  /// **'{pct}% · {weight} pts'**
  String scComponentValue(String pct, String weight);

  /// No description provided for @scDay1.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get scDay1;

  /// No description provided for @scDay2.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get scDay2;

  /// No description provided for @scDay3.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get scDay3;

  /// No description provided for @scDay4.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get scDay4;

  /// No description provided for @scDay5.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get scDay5;

  /// No description provided for @scDay6.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get scDay6;

  /// No description provided for @scDay7.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get scDay7;

  /// No description provided for @scDoingWell.
  ///
  /// In en, this message translates to:
  /// **'Doing well'**
  String get scDoingWell;

  /// No description provided for @scDownSince.
  ///
  /// In en, this message translates to:
  /// **'Down {n} since yesterday'**
  String scDownSince(String n);

  /// No description provided for @scExpiredAgo.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Expired 1 day ago} other{Expired {n} days ago}}'**
  String scExpiredAgo(int n);

  /// No description provided for @scExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Expires in 1 day} other{Expires in {n} days}}'**
  String scExpiresIn(int n);

  /// No description provided for @scExpiresToday.
  ///
  /// In en, this message translates to:
  /// **'Expires today'**
  String get scExpiresToday;

  /// No description provided for @scFewThings.
  ///
  /// In en, this message translates to:
  /// **'A few things need you'**
  String get scFewThings;

  /// No description provided for @scHeavyWeek.
  ///
  /// In en, this message translates to:
  /// **'Heavy week'**
  String get scHeavyWeek;

  /// No description provided for @scLast7.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get scLast7;

  /// No description provided for @scLifeScore.
  ///
  /// In en, this message translates to:
  /// **'Life Score'**
  String get scLifeScore;

  /// No description provided for @scMoveToday.
  ///
  /// In en, this message translates to:
  /// **'Move to today'**
  String get scMoveToday;

  /// No description provided for @scMovedToday.
  ///
  /// In en, this message translates to:
  /// **'Moved to today'**
  String get scMovedToday;

  /// No description provided for @scNothingPulling.
  ///
  /// In en, this message translates to:
  /// **'Nothing is pulling your score down today ✓'**
  String get scNothingPulling;

  /// No description provided for @scOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get scOpen;

  /// No description provided for @scRingSemantics.
  ///
  /// In en, this message translates to:
  /// **'Life Score {score}, {label}'**
  String scRingSemantics(String score, String label);

  /// No description provided for @scSameYesterday.
  ///
  /// In en, this message translates to:
  /// **'Same as yesterday'**
  String get scSameYesterday;

  /// No description provided for @scShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all {n}'**
  String scShowAll(String n);

  /// No description provided for @scSparkSemantics.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days: {values}'**
  String scSparkSemantics(String values);

  /// No description provided for @scStillOpen.
  ///
  /// In en, this message translates to:
  /// **'Still open from yesterday'**
  String get scStillOpen;

  /// No description provided for @scTriageTitle.
  ///
  /// In en, this message translates to:
  /// **'Heavy week? Here are the 3 highest-impact items'**
  String get scTriageTitle;

  /// No description provided for @scUpSince.
  ///
  /// In en, this message translates to:
  /// **'Up {n} since yesterday'**
  String scUpSince(String n);

  /// No description provided for @scWasDue.
  ///
  /// In en, this message translates to:
  /// **'Was due {date}'**
  String scWasDue(String date);

  /// No description provided for @scWhatWouldLift.
  ///
  /// In en, this message translates to:
  /// **'What would lift it'**
  String get scWhatWouldLift;

  /// No description provided for @scWhatsInIt.
  ///
  /// In en, this message translates to:
  /// **'What\'s in it'**
  String get scWhatsInIt;

  /// No description provided for @scWhenSorted.
  ///
  /// In en, this message translates to:
  /// **'+{pts} when sorted'**
  String scWhenSorted(String pts);

  /// No description provided for @screenshotBlock.
  ///
  /// In en, this message translates to:
  /// **'Block screenshots in the Vault'**
  String get screenshotBlock;

  /// No description provided for @setGreeting.
  ///
  /// In en, this message translates to:
  /// **'Greeting'**
  String get setGreeting;

  /// No description provided for @setGreetingAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic — time of day'**
  String get setGreetingAuto;

  /// No description provided for @setGreetingCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get setGreetingCustom;

  /// No description provided for @setGreetingCustomHint.
  ///
  /// In en, this message translates to:
  /// **'Your greeting, e.g. Shalom'**
  String get setGreetingCustomHint;

  /// No description provided for @setGreetingHello.
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get setGreetingHello;

  /// No description provided for @setGreetingNamaste.
  ///
  /// In en, this message translates to:
  /// **'Namaste'**
  String get setGreetingNamaste;

  /// No description provided for @setGreetingSalam.
  ///
  /// In en, this message translates to:
  /// **'Salam'**
  String get setGreetingSalam;

  /// No description provided for @setWidgetDetails.
  ///
  /// In en, this message translates to:
  /// **'Show details on widget'**
  String get setWidgetDetails;

  /// No description provided for @setWidgetDetailsSub.
  ///
  /// In en, this message translates to:
  /// **'Task titles and amounts on the home-screen widget'**
  String get setWidgetDetailsSub;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsData;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get settingsPremium;

  /// No description provided for @settingsPremiumSub.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get settingsPremiumSub;

  /// No description provided for @settingsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecurity;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @speak.
  ///
  /// In en, this message translates to:
  /// **'Speak'**
  String get speak;

  /// No description provided for @templateClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic · large text'**
  String get templateClassic;

  /// No description provided for @templateFlagship.
  ///
  /// In en, this message translates to:
  /// **'Flagship'**
  String get templateFlagship;

  /// No description provided for @templateFunky.
  ///
  /// In en, this message translates to:
  /// **'Funky'**
  String get templateFunky;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeMode;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @tkActionDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get tkActionDismiss;

  /// No description provided for @tkActionDone.
  ///
  /// In en, this message translates to:
  /// **'Done ✓'**
  String get tkActionDone;

  /// No description provided for @tkActionPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid ✓'**
  String get tkActionPaid;

  /// No description provided for @tkActionRenew.
  ///
  /// In en, this message translates to:
  /// **'Set renewal task'**
  String get tkActionRenew;

  /// No description provided for @tkAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get tkAdd;

  /// No description provided for @tkAddAnyway.
  ///
  /// In en, this message translates to:
  /// **'Add anyway'**
  String get tkAddAnyway;

  /// No description provided for @tkAddNotes.
  ///
  /// In en, this message translates to:
  /// **'Add notes'**
  String get tkAddNotes;

  /// No description provided for @tkAddReminder.
  ///
  /// In en, this message translates to:
  /// **'Add reminder'**
  String get tkAddReminder;

  /// No description provided for @tkAddSubtask.
  ///
  /// In en, this message translates to:
  /// **'Add a sub-task'**
  String get tkAddSubtask;

  /// No description provided for @tkAddTaskAction.
  ///
  /// In en, this message translates to:
  /// **'➕ Add task'**
  String get tkAddTaskAction;

  /// No description provided for @tkAllDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get tkAllDay;

  /// No description provided for @tkAnytime.
  ///
  /// In en, this message translates to:
  /// **'Anytime'**
  String get tkAnytime;

  /// No description provided for @tkAutoCreated.
  ///
  /// In en, this message translates to:
  /// **'Auto-created'**
  String get tkAutoCreated;

  /// No description provided for @tkCantOpen.
  ///
  /// In en, this message translates to:
  /// **'Can\'t open this task'**
  String get tkCantOpen;

  /// No description provided for @tkChannelDesc.
  ///
  /// In en, this message translates to:
  /// **'Task, payment and document reminders'**
  String get tkChannelDesc;

  /// No description provided for @tkChannelName.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get tkChannelName;

  /// No description provided for @tkCloseQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Close quick actions'**
  String get tkCloseQuickActions;

  /// No description provided for @tkComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon ({pbi}).'**
  String tkComingSoon(String pbi);

  /// No description provided for @tkCreatedAuto.
  ///
  /// In en, this message translates to:
  /// **'Created automatically'**
  String get tkCreatedAuto;

  /// No description provided for @tkCreatedByRule.
  ///
  /// In en, this message translates to:
  /// **'Created by rule: {name}'**
  String tkCreatedByRule(String name);

  /// No description provided for @tkCreatedFrom.
  ///
  /// In en, this message translates to:
  /// **'Created from: {title}'**
  String tkCreatedFrom(String title);

  /// No description provided for @tkDayFull.
  ///
  /// In en, this message translates to:
  /// **'{day} is already full ({load} of {capacity})'**
  String tkDayFull(String day, String load, String capacity);

  /// No description provided for @tkDayLoad.
  ///
  /// In en, this message translates to:
  /// **'{day} {load}'**
  String tkDayLoad(String day, String load);

  /// No description provided for @tkDayLoadOver.
  ///
  /// In en, this message translates to:
  /// **'{day} {load}, over capacity'**
  String tkDayLoadOver(String day, String load);

  /// No description provided for @tkDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get tkDelete;

  /// No description provided for @tkDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" and its sub-tasks will be removed.'**
  String tkDeleteBody(String title);

  /// No description provided for @tkDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this task?'**
  String get tkDeleteTitle;

  /// No description provided for @tkDocDue.
  ///
  /// In en, this message translates to:
  /// **'Due: {date}'**
  String tkDocDue(String date);

  /// No description provided for @tkDocIssuer.
  ///
  /// In en, this message translates to:
  /// **'Issuer: {issuer}'**
  String tkDocIssuer(String issuer);

  /// No description provided for @tkDocType.
  ///
  /// In en, this message translates to:
  /// **'Type: {type}'**
  String tkDocType(String type);

  /// No description provided for @tkDomainMind.
  ///
  /// In en, this message translates to:
  /// **'Mind'**
  String get tkDomainMind;

  /// No description provided for @tkDomainVault.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get tkDomainVault;

  /// No description provided for @tkDomains.
  ///
  /// In en, this message translates to:
  /// **'Domains'**
  String get tkDomains;

  /// No description provided for @tkDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get tkDone;

  /// No description provided for @tkDoneNext.
  ///
  /// In en, this message translates to:
  /// **'Done — next one scheduled'**
  String get tkDoneNext;

  /// No description provided for @tkDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Done: {title}'**
  String tkDoneTitle(String title);

  /// No description provided for @tkDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get tkDue;

  /// No description provided for @tkEmptyDomainsBody.
  ///
  /// In en, this message translates to:
  /// **'Tasks are grouped by life area here.'**
  String get tkEmptyDomainsBody;

  /// No description provided for @tkEmptyDomainsTitle.
  ///
  /// In en, this message translates to:
  /// **'No open tasks'**
  String get tkEmptyDomainsTitle;

  /// No description provided for @tkEmptyTodayBody.
  ///
  /// In en, this message translates to:
  /// **'Add a task and it\'ll show up here for today.'**
  String get tkEmptyTodayBody;

  /// No description provided for @tkEmptyTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing on your plate'**
  String get tkEmptyTodayTitle;

  /// No description provided for @tkEmptyWeekBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing is due in the next 7 days.'**
  String get tkEmptyWeekBody;

  /// No description provided for @tkEmptyWeekTitle.
  ///
  /// In en, this message translates to:
  /// **'A clear week ahead'**
  String get tkEmptyWeekTitle;

  /// No description provided for @tkEveryDay.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Every day} other{Every {n} days}}'**
  String tkEveryDay(int n);

  /// No description provided for @tkEveryMonth.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Every month} other{Every {n} months}}'**
  String tkEveryMonth(int n);

  /// No description provided for @tkEveryWeek.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Every week} other{Every {n} weeks}}'**
  String tkEveryWeek(int n);

  /// No description provided for @tkFewerOptions.
  ///
  /// In en, this message translates to:
  /// **'Fewer options'**
  String get tkFewerOptions;

  /// No description provided for @tkFor.
  ///
  /// In en, this message translates to:
  /// **'For'**
  String get tkFor;

  /// No description provided for @tkFull.
  ///
  /// In en, this message translates to:
  /// **'⚠ Full'**
  String get tkFull;

  /// No description provided for @tkGoneBody.
  ///
  /// In en, this message translates to:
  /// **'It was deleted or completed.'**
  String get tkGoneBody;

  /// No description provided for @tkGoneTitle.
  ///
  /// In en, this message translates to:
  /// **'This task is gone'**
  String get tkGoneTitle;

  /// No description provided for @tkHasRoom.
  ///
  /// In en, this message translates to:
  /// **'{day} has room.'**
  String tkHasRoom(String day);

  /// No description provided for @tkHeatDay.
  ///
  /// In en, this message translates to:
  /// **'{day}: {percent} percent'**
  String tkHeatDay(String day, String percent);

  /// No description provided for @tkHeatDayFull.
  ///
  /// In en, this message translates to:
  /// **'{day}: {percent} percent, full'**
  String tkHeatDayFull(String day, String percent);

  /// No description provided for @tkHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get tkHigh;

  /// No description provided for @tkHighChip.
  ///
  /// In en, this message translates to:
  /// **'‼ High'**
  String get tkHighChip;

  /// No description provided for @tkHours.
  ///
  /// In en, this message translates to:
  /// **'{n} h'**
  String tkHours(String n);

  /// No description provided for @tkLifeArea.
  ///
  /// In en, this message translates to:
  /// **'Life area'**
  String get tkLifeArea;

  /// No description provided for @tkLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get tkLow;

  /// No description provided for @tkMarkDone.
  ///
  /// In en, this message translates to:
  /// **'Mark \"{title}\" done'**
  String tkMarkDone(String title);

  /// No description provided for @tkMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get tkMedium;

  /// No description provided for @tkMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String tkMinutes(String n);

  /// No description provided for @tkMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get tkMoreOptions;

  /// No description provided for @tkMoveTo.
  ///
  /// In en, this message translates to:
  /// **'Move to {day}'**
  String tkMoveTo(String day);

  /// No description provided for @tkMuteRule.
  ///
  /// In en, this message translates to:
  /// **'Mute this rule'**
  String get tkMuteRule;

  /// No description provided for @tkNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get tkNever;

  /// No description provided for @tkNewTask.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get tkNewTask;

  /// No description provided for @tkNoDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get tkNoDate;

  /// No description provided for @tkNoLighterDay.
  ///
  /// In en, this message translates to:
  /// **'No lighter day in the next two weeks — pick a day, or add it anyway.'**
  String get tkNoLighterDay;

  /// No description provided for @tkNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get tkNotes;

  /// No description provided for @tkNotifDue.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String tkNotifDue(String date);

  /// No description provided for @tkNotifDueLower.
  ///
  /// In en, this message translates to:
  /// **'due {date}'**
  String tkNotifDueLower(String date);

  /// No description provided for @tkNotifExpiryBody.
  ///
  /// In en, this message translates to:
  /// **'Tap to see which one and renew it'**
  String get tkNotifExpiryBody;

  /// No description provided for @tkNotifExpiryTitle.
  ///
  /// In en, this message translates to:
  /// **'A document expires soon'**
  String get tkNotifExpiryTitle;

  /// No description provided for @tkNotifHidden.
  ///
  /// In en, this message translates to:
  /// **'Open LifeOS to see details'**
  String get tkNotifHidden;

  /// No description provided for @tkNotifPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'A payment is due'**
  String get tkNotifPaymentTitle;

  /// No description provided for @tkNotifReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get tkNotifReminder;

  /// No description provided for @tkNotifTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'A task is due'**
  String get tkNotifTaskTitle;

  /// No description provided for @tkOffset10m.
  ///
  /// In en, this message translates to:
  /// **'10 minutes before'**
  String get tkOffset10m;

  /// No description provided for @tkOffset1d.
  ///
  /// In en, this message translates to:
  /// **'1 day before'**
  String get tkOffset1d;

  /// No description provided for @tkOffset1h.
  ///
  /// In en, this message translates to:
  /// **'1 hour before'**
  String get tkOffset1h;

  /// No description provided for @tkOffsetAtDue.
  ///
  /// In en, this message translates to:
  /// **'At due time'**
  String get tkOffsetAtDue;

  /// No description provided for @tkOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get tkOverdue;

  /// No description provided for @tkPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments ⚡'**
  String get tkPayments;

  /// No description provided for @tkPickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick date'**
  String get tkPickDate;

  /// No description provided for @tkPickDateTime.
  ///
  /// In en, this message translates to:
  /// **'Pick a date & time'**
  String get tkPickDateTime;

  /// No description provided for @tkPickDay.
  ///
  /// In en, this message translates to:
  /// **'Pick a day'**
  String get tkPickDay;

  /// No description provided for @tkPickTime.
  ///
  /// In en, this message translates to:
  /// **'Pick a time…'**
  String get tkPickTime;

  /// No description provided for @tkPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get tkPriority;

  /// No description provided for @tkQaExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get tkQaExpense;

  /// No description provided for @tkQaExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Log an expense'**
  String get tkQaExpenseTitle;

  /// No description provided for @tkQaScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get tkQaScan;

  /// No description provided for @tkQaScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan a document'**
  String get tkQaScanTitle;

  /// No description provided for @tkQaTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get tkQaTask;

  /// No description provided for @tkQaTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a task'**
  String get tkQaTaskTitle;

  /// No description provided for @tkQaVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get tkQaVoice;

  /// No description provided for @tkQaVoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Speak a task'**
  String get tkQaVoiceTitle;

  /// No description provided for @tkQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get tkQuickActions;

  /// No description provided for @tkRemoveDueDate.
  ///
  /// In en, this message translates to:
  /// **'Remove due date'**
  String get tkRemoveDueDate;

  /// No description provided for @tkRemoveReminder.
  ///
  /// In en, this message translates to:
  /// **'Remove reminder'**
  String get tkRemoveReminder;

  /// No description provided for @tkRemoveSubtask.
  ///
  /// In en, this message translates to:
  /// **'Remove sub-task'**
  String get tkRemoveSubtask;

  /// No description provided for @tkRenewDocument.
  ///
  /// In en, this message translates to:
  /// **'document'**
  String get tkRenewDocument;

  /// No description provided for @tkRenewTitle.
  ///
  /// In en, this message translates to:
  /// **'Renew {what}'**
  String tkRenewTitle(String what);

  /// No description provided for @tkRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get tkRepeat;

  /// No description provided for @tkRulePaused.
  ///
  /// In en, this message translates to:
  /// **'Rule paused — no new tasks from it'**
  String get tkRulePaused;

  /// No description provided for @tkSkipCycle.
  ///
  /// In en, this message translates to:
  /// **'Skip this cycle'**
  String get tkSkipCycle;

  /// No description provided for @tkSnooze.
  ///
  /// In en, this message translates to:
  /// **'Snooze'**
  String get tkSnooze;

  /// No description provided for @tkSubtasks.
  ///
  /// In en, this message translates to:
  /// **'Sub-tasks ({done}/{total})'**
  String tkSubtasks(String done, String total);

  /// No description provided for @tkTabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tkTabHome;

  /// No description provided for @tkTabMoney.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get tkTabMoney;

  /// No description provided for @tkTabMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get tkTabMore;

  /// No description provided for @tkTabVault.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get tkTabVault;

  /// No description provided for @tkTakesAbout.
  ///
  /// In en, this message translates to:
  /// **'Takes about'**
  String get tkTakesAbout;

  /// No description provided for @tkTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get tkTask;

  /// No description provided for @tkTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tkTasks;

  /// No description provided for @tkTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get tkTime;

  /// No description provided for @tkTimed.
  ///
  /// In en, this message translates to:
  /// **'Timed'**
  String get tkTimed;

  /// No description provided for @tkTomorrowMorning.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow morning'**
  String get tkTomorrowMorning;

  /// No description provided for @tkTomorrowOn.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow · {date}'**
  String tkTomorrowOn(String date);

  /// No description provided for @tkTonight.
  ///
  /// In en, this message translates to:
  /// **'Tonight'**
  String get tkTonight;

  /// No description provided for @tkUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Local data could not be opened on this device.'**
  String get tkUnavailableBody;

  /// No description provided for @tkUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks aren\'t available'**
  String get tkUnavailableTitle;

  /// No description provided for @tkUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get tkUndo;

  /// No description provided for @tkUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get tkUpcoming;

  /// No description provided for @tkWeekLoad.
  ///
  /// In en, this message translates to:
  /// **'Week load: {days}'**
  String tkWeekLoad(String days);

  /// No description provided for @tkWeekday1.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get tkWeekday1;

  /// No description provided for @tkWeekday2.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tkWeekday2;

  /// No description provided for @tkWeekday3.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get tkWeekday3;

  /// No description provided for @tkWeekday4.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get tkWeekday4;

  /// No description provided for @tkWeekday5.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get tkWeekday5;

  /// No description provided for @tkWeekday6.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get tkWeekday6;

  /// No description provided for @tkWeekday7.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get tkWeekday7;

  /// No description provided for @tkWhatNeedsDoing.
  ///
  /// In en, this message translates to:
  /// **'What needs doing?'**
  String get tkWhatNeedsDoing;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @trash.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get trash;

  /// No description provided for @turnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get turnOn;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @unlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock LifeOS'**
  String get unlockReason;

  /// No description provided for @unlockVaultReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock your Vault'**
  String get unlockVaultReason;

  /// No description provided for @vaultLock.
  ///
  /// In en, this message translates to:
  /// **'Vault lock'**
  String get vaultLock;

  /// No description provided for @vaultLockSub.
  ///
  /// In en, this message translates to:
  /// **'Ask again before opening the Vault'**
  String get vaultLockSub;

  /// No description provided for @vaultLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'The Vault is locked'**
  String get vaultLockedTitle;

  /// No description provided for @voiceHint.
  ///
  /// In en, this message translates to:
  /// **'Try: \"Pay electricity bill Friday 5pm\"'**
  String get voiceHint;

  /// No description provided for @voiceListening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get voiceListening;

  /// No description provided for @voiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Speak your task'**
  String get voiceTitle;

  /// No description provided for @voiceTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get voiceTryAgain;

  /// No description provided for @voiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice isn\'t available on this phone — type instead'**
  String get voiceUnavailable;

  /// No description provided for @vtAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get vtAdd;

  /// No description provided for @vtAddFavourite.
  ///
  /// In en, this message translates to:
  /// **'Add to favourites'**
  String get vtAddFavourite;

  /// No description provided for @vtAddPerson.
  ///
  /// In en, this message translates to:
  /// **'Add person'**
  String get vtAddPerson;

  /// No description provided for @vtAddTag.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get vtAddTag;

  /// No description provided for @vtAddTagHint.
  ///
  /// In en, this message translates to:
  /// **'Add a tag'**
  String get vtAddTagHint;

  /// No description provided for @vtAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get vtAdded;

  /// No description provided for @vtAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get vtAmount;

  /// No description provided for @vtAnyTime.
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get vtAnyTime;

  /// No description provided for @vtAnyType.
  ///
  /// In en, this message translates to:
  /// **'Any type'**
  String get vtAnyType;

  /// No description provided for @vtAnyone.
  ///
  /// In en, this message translates to:
  /// **'Anyone'**
  String get vtAnyone;

  /// No description provided for @vtArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get vtArchive;

  /// No description provided for @vtArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get vtArchived;

  /// No description provided for @vtBelongsTo.
  ///
  /// In en, this message translates to:
  /// **'Belongs to'**
  String get vtBelongsTo;

  /// No description provided for @vtClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get vtClear;

  /// No description provided for @vtClearField.
  ///
  /// In en, this message translates to:
  /// **'Clear {label}'**
  String vtClearField(String label);

  /// No description provided for @vtClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get vtClearSearch;

  /// No description provided for @vtDaysLeftShort.
  ///
  /// In en, this message translates to:
  /// **'{n}d left'**
  String vtDaysLeftShort(String n);

  /// No description provided for @vtDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get vtDelete;

  /// No description provided for @vtDeleteDocBody.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be removed.'**
  String vtDeleteDocBody(String title);

  /// No description provided for @vtDeleteDocTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this document?'**
  String get vtDeleteDocTitle;

  /// No description provided for @vtDeleteFolder.
  ///
  /// In en, this message translates to:
  /// **'Delete folder'**
  String get vtDeleteFolder;

  /// No description provided for @vtDeleteFolderBody.
  ///
  /// In en, this message translates to:
  /// **'Its documents move to Unfiled — nothing is lost.'**
  String get vtDeleteFolderBody;

  /// No description provided for @vtDeleteFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String vtDeleteFolderTitle(String name);

  /// No description provided for @vtDeleteForeverBody.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" and its files will be removed from this phone. This can\'t be undone.'**
  String vtDeleteForeverBody(String title);

  /// No description provided for @vtDeleteForeverTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete forever?'**
  String get vtDeleteForeverTitle;

  /// No description provided for @vtDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get vtDetails;

  /// No description provided for @vtDocCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 doc} other{{n} docs}}'**
  String vtDocCount(int n);

  /// No description provided for @vtDocGoneMessage.
  ///
  /// In en, this message translates to:
  /// **'It was deleted. Look in Vault → Trash to restore it.'**
  String get vtDocGoneMessage;

  /// No description provided for @vtDocGoneTitle.
  ///
  /// In en, this message translates to:
  /// **'This document is gone'**
  String get vtDocGoneTitle;

  /// No description provided for @vtDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get vtDueDate;

  /// No description provided for @vtEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get vtEdit;

  /// No description provided for @vtEditPerson.
  ///
  /// In en, this message translates to:
  /// **'Edit person'**
  String get vtEditPerson;

  /// No description provided for @vtEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Scan or import a document to file it here.'**
  String get vtEmptyMessage;

  /// No description provided for @vtEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get vtEmptyTitle;

  /// No description provided for @vtExpiredAgo.
  ///
  /// In en, this message translates to:
  /// **'Expired {n}d ago'**
  String vtExpiredAgo(String n);

  /// No description provided for @vtExpiresToday.
  ///
  /// In en, this message translates to:
  /// **'Expires today'**
  String get vtExpiresToday;

  /// No description provided for @vtExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get vtExpiringSoon;

  /// No description provided for @vtExpiringSoonCount.
  ///
  /// In en, this message translates to:
  /// **'⏰ Expiring soon ({n})'**
  String vtExpiringSoonCount(String n);

  /// No description provided for @vtExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry date'**
  String get vtExpiryDate;

  /// No description provided for @vtExpiryPrompt.
  ///
  /// In en, this message translates to:
  /// **'Does this document expire?'**
  String get vtExpiryPrompt;

  /// No description provided for @vtFavourite.
  ///
  /// In en, this message translates to:
  /// **'Favourite'**
  String get vtFavourite;

  /// No description provided for @vtFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get vtFolder;

  /// No description provided for @vtFolderBills.
  ///
  /// In en, this message translates to:
  /// **'Bills & Receipts'**
  String get vtFolderBills;

  /// No description provided for @vtFolderEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get vtFolderEducation;

  /// No description provided for @vtFolderIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get vtFolderIdentity;

  /// No description provided for @vtFolderInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get vtFolderInsurance;

  /// No description provided for @vtFolderMedical.
  ///
  /// In en, this message translates to:
  /// **'Medical'**
  String get vtFolderMedical;

  /// No description provided for @vtFolderName.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get vtFolderName;

  /// No description provided for @vtFolderOptions.
  ///
  /// In en, this message translates to:
  /// **'Folder options'**
  String get vtFolderOptions;

  /// No description provided for @vtFolderProperty.
  ///
  /// In en, this message translates to:
  /// **'Property'**
  String get vtFolderProperty;

  /// No description provided for @vtFolderVehicles.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get vtFolderVehicles;

  /// No description provided for @vtFolderWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get vtFolderWork;

  /// No description provided for @vtFolders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get vtFolders;

  /// No description provided for @vtImportFiles.
  ///
  /// In en, this message translates to:
  /// **'Import from files'**
  String get vtImportFiles;

  /// No description provided for @vtIssuer.
  ///
  /// In en, this message translates to:
  /// **'Issuer'**
  String get vtIssuer;

  /// No description provided for @vtLadderAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts: {list}\nNext: {next}'**
  String vtLadderAlerts(String list, String next);

  /// No description provided for @vtLadderDayAfter.
  ///
  /// In en, this message translates to:
  /// **'{n} day after'**
  String vtLadderDayAfter(String n);

  /// No description provided for @vtLadderDaysBefore.
  ///
  /// In en, this message translates to:
  /// **'{n} days before'**
  String vtLadderDaysBefore(String n);

  /// No description provided for @vtLadderExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired — a weekly reminder until renewed'**
  String get vtLadderExpired;

  /// No description provided for @vtLadderOnDay.
  ///
  /// In en, this message translates to:
  /// **'on the day'**
  String get vtLadderOnDay;

  /// No description provided for @vtLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get vtLast30Days;

  /// No description provided for @vtLinkedTasks.
  ///
  /// In en, this message translates to:
  /// **'Linked tasks'**
  String get vtLinkedTasks;

  /// No description provided for @vtMarkRenewed.
  ///
  /// In en, this message translates to:
  /// **'Mark renewed → scan the new one'**
  String get vtMarkRenewed;

  /// No description provided for @vtMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get vtMove;

  /// No description provided for @vtMovedToTrash.
  ///
  /// In en, this message translates to:
  /// **'Moved to Trash'**
  String get vtMovedToTrash;

  /// No description provided for @vtNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get vtNewFolder;

  /// No description provided for @vtNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get vtNo;

  /// No description provided for @vtNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get vtNoMatches;

  /// No description provided for @vtNoMatchesHint.
  ///
  /// In en, this message translates to:
  /// **'Try a title, an issuer like K-Electric, a word from the document, or a tag.'**
  String get vtNoMatchesHint;

  /// No description provided for @vtNoPages.
  ///
  /// In en, this message translates to:
  /// **'No pages stored for this document'**
  String get vtNoPages;

  /// No description provided for @vtNobody.
  ///
  /// In en, this message translates to:
  /// **'Nobody'**
  String get vtNobody;

  /// No description provided for @vtNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get vtNotSet;

  /// No description provided for @vtNothingExpiring.
  ///
  /// In en, this message translates to:
  /// **'Nothing expiring'**
  String get vtNothingExpiring;

  /// No description provided for @vtNothingExpiringMessage.
  ///
  /// In en, this message translates to:
  /// **'Documents due to expire in the next 90 days show here.'**
  String get vtNothingExpiringMessage;

  /// No description provided for @vtOwnProfileProtected.
  ///
  /// In en, this message translates to:
  /// **'Your own profile can\'t be deleted'**
  String get vtOwnProfileProtected;

  /// No description provided for @vtPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String vtPageOf(String page, String total);

  /// No description provided for @vtPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get vtPeople;

  /// No description provided for @vtPerson.
  ///
  /// In en, this message translates to:
  /// **'Person'**
  String get vtPerson;

  /// No description provided for @vtPersonOptions.
  ///
  /// In en, this message translates to:
  /// **'Person options'**
  String get vtPersonOptions;

  /// No description provided for @vtRefNumber.
  ///
  /// In en, this message translates to:
  /// **'Reference / number'**
  String get vtRefNumber;

  /// No description provided for @vtRelationChild.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get vtRelationChild;

  /// No description provided for @vtRelationOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get vtRelationOther;

  /// No description provided for @vtRelationParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get vtRelationParent;

  /// No description provided for @vtRelationSpouse.
  ///
  /// In en, this message translates to:
  /// **'Spouse'**
  String get vtRelationSpouse;

  /// No description provided for @vtRemoveFavourite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get vtRemoveFavourite;

  /// No description provided for @vtRemovePerson.
  ///
  /// In en, this message translates to:
  /// **'Remove person'**
  String get vtRemovePerson;

  /// No description provided for @vtRemovePersonBody.
  ///
  /// In en, this message translates to:
  /// **'Their documents stay in the Vault, unassigned.'**
  String get vtRemovePersonBody;

  /// No description provided for @vtRemovePersonTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String vtRemovePersonTitle(String name);

  /// No description provided for @vtRemoveTag.
  ///
  /// In en, this message translates to:
  /// **'Remove tag {tag}'**
  String vtRemoveTag(String tag);

  /// No description provided for @vtRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get vtRename;

  /// No description provided for @vtRenameFolder.
  ///
  /// In en, this message translates to:
  /// **'Rename folder'**
  String get vtRenameFolder;

  /// No description provided for @vtRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get vtRestore;

  /// No description provided for @vtSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get vtSave;

  /// No description provided for @vtScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get vtScan;

  /// No description provided for @vtScanAction.
  ///
  /// In en, this message translates to:
  /// **'📸 Scan'**
  String get vtScanAction;

  /// No description provided for @vtSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search documents…'**
  String get vtSearchHint;

  /// No description provided for @vtSearchUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Search isn\'t available'**
  String get vtSearchUnavailable;

  /// No description provided for @vtSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get vtSeeAll;

  /// No description provided for @vtSetDate.
  ///
  /// In en, this message translates to:
  /// **'Set date'**
  String get vtSetDate;

  /// No description provided for @vtShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get vtShare;

  /// No description provided for @vtSharedFrom.
  ///
  /// In en, this message translates to:
  /// **'Shared from LifeOS'**
  String get vtSharedFrom;

  /// No description provided for @vtSystemFolderNoDelete.
  ///
  /// In en, this message translates to:
  /// **'System folders can\'t be deleted'**
  String get vtSystemFolderNoDelete;

  /// No description provided for @vtSystemFolderNoRename.
  ///
  /// In en, this message translates to:
  /// **'System folders can\'t be renamed'**
  String get vtSystemFolderNoRename;

  /// No description provided for @vtTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get vtTags;

  /// No description provided for @vtThisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get vtThisYear;

  /// No description provided for @vtTrashDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{n} days left'**
  String vtTrashDaysLeft(String n);

  /// No description provided for @vtTrashEmpty.
  ///
  /// In en, this message translates to:
  /// **'Trash is empty'**
  String get vtTrashEmpty;

  /// No description provided for @vtTrashEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Deleted documents stay here for {days} days, then are removed for good.'**
  String vtTrashEmptyMessage(String days);

  /// No description provided for @vtTrashUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Trash isn\'t available'**
  String get vtTrashUnavailable;

  /// No description provided for @vtTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Please try again.'**
  String get vtTryAgain;

  /// No description provided for @vtType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get vtType;

  /// No description provided for @vtTypeAgreement.
  ///
  /// In en, this message translates to:
  /// **'Agreement'**
  String get vtTypeAgreement;

  /// No description provided for @vtTypeBill.
  ///
  /// In en, this message translates to:
  /// **'Bill'**
  String get vtTypeBill;

  /// No description provided for @vtTypeCertificate.
  ///
  /// In en, this message translates to:
  /// **'Certificate'**
  String get vtTypeCertificate;

  /// No description provided for @vtTypeCnic.
  ///
  /// In en, this message translates to:
  /// **'CNIC'**
  String get vtTypeCnic;

  /// No description provided for @vtTypeDegree.
  ///
  /// In en, this message translates to:
  /// **'Degree'**
  String get vtTypeDegree;

  /// No description provided for @vtTypeFeeVoucher.
  ///
  /// In en, this message translates to:
  /// **'Fee voucher'**
  String get vtTypeFeeVoucher;

  /// No description provided for @vtTypeLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get vtTypeLicense;

  /// No description provided for @vtTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get vtTypeOther;

  /// No description provided for @vtTypePassport.
  ///
  /// In en, this message translates to:
  /// **'Passport'**
  String get vtTypePassport;

  /// No description provided for @vtTypePolicy.
  ///
  /// In en, this message translates to:
  /// **'Policy'**
  String get vtTypePolicy;

  /// No description provided for @vtTypePrescription.
  ///
  /// In en, this message translates to:
  /// **'Prescription'**
  String get vtTypePrescription;

  /// No description provided for @vtTypeReceipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get vtTypeReceipt;

  /// No description provided for @vtTypeReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get vtTypeReport;

  /// No description provided for @vtTypeVisa.
  ///
  /// In en, this message translates to:
  /// **'Visa'**
  String get vtTypeVisa;

  /// No description provided for @vtTypeWarranty.
  ///
  /// In en, this message translates to:
  /// **'Warranty'**
  String get vtTypeWarranty;

  /// No description provided for @vtUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get vtUnarchive;

  /// No description provided for @vtUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Local data could not be opened on this device.'**
  String get vtUnavailableMessage;

  /// No description provided for @vtUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'The Vault isn\'t available'**
  String get vtUnavailableTitle;

  /// No description provided for @vtUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get vtUndo;

  /// No description provided for @vtUnfiled.
  ///
  /// In en, this message translates to:
  /// **'Unfiled'**
  String get vtUnfiled;

  /// No description provided for @vtUnfiledTitle.
  ///
  /// In en, this message translates to:
  /// **'📥 Unfiled'**
  String get vtUnfiledTitle;

  /// No description provided for @vtVaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get vtVaultTitle;

  /// No description provided for @wd1.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get wd1;

  /// No description provided for @wd2.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get wd2;

  /// No description provided for @wd3.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get wd3;

  /// No description provided for @wd4.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get wd4;

  /// No description provided for @wd5.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get wd5;

  /// No description provided for @wd6.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get wd6;

  /// No description provided for @wd7.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get wd7;

  /// No description provided for @wgAllClear.
  ///
  /// In en, this message translates to:
  /// **'All clear today ✨'**
  String get wgAllClear;

  /// No description provided for @wgDueShort.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 due} other{{n} due}}'**
  String wgDueShort(int n);

  /// No description provided for @wgLockPromptBody.
  ///
  /// In en, this message translates to:
  /// **'App Lock is on, but the home-screen widget can still show task titles and amounts. Show only the score and counts instead?'**
  String get wgLockPromptBody;

  /// No description provided for @wgLockPromptHide.
  ///
  /// In en, this message translates to:
  /// **'Hide details'**
  String get wgLockPromptHide;

  /// No description provided for @wgLockPromptKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep showing'**
  String get wgLockPromptKeep;

  /// No description provided for @wgLockPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide details on the widget?'**
  String get wgLockPromptTitle;

  /// No description provided for @wgMore.
  ///
  /// In en, this message translates to:
  /// **'+{n} more'**
  String wgMore(String n);

  /// No description provided for @wgPaymentLine.
  ///
  /// In en, this message translates to:
  /// **'⚡ {title} ~{amount} · {day}'**
  String wgPaymentLine(String title, String amount, String day);

  /// No description provided for @wgPaymentLineNoAmount.
  ///
  /// In en, this message translates to:
  /// **'⚡ {title} · {day}'**
  String wgPaymentLineNoAmount(String title, String day);

  /// No description provided for @wgTasksShort.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{No tasks} =1{1 task} other{{n} tasks}}'**
  String wgTasksShort(int n);

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;
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
      <String>['en', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

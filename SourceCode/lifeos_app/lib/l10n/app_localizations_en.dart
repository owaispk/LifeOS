// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get aiAdvanced => 'Advanced: use my own provider';

  @override
  String get aiAlways => 'Always';

  @override
  String get aiApiKey => 'API key';

  @override
  String get aiApiKeyStored => 'Saved on this phone only';

  @override
  String get aiBaseUrl => 'Base URL';

  @override
  String get aiConsentAsk => 'Ask each time';

  @override
  String get aiConsentBody =>
      'Couldn\'t read this fully on the phone. Send the text — not the image — to your AI provider?';

  @override
  String get aiConsentBodyManaged =>
      'Couldn\'t read this fully on the phone. Send the text - not the image - to LifeOS AI? Our servers forward it to the AI provider and store nothing.';

  @override
  String get aiConsentSetting => 'Send document text';

  @override
  String get aiConsentTitle => 'Send this document\'s text?';

  @override
  String get aiDismiss => 'Dismiss';

  @override
  String aiFailedPrefix(String message) {
    return 'Your AI provider said: $message';
  }

  @override
  String get aiJustOnce => 'Just this once';

  @override
  String get aiKeptLocal => 'Kept what the phone read.';

  @override
  String get aiKeyHint =>
      'A local provider on your own machine may need no key.';

  @override
  String get aiLockedPitch =>
      'Premium AI reads what the phone can\'t: damaged photos, Urdu documents, and billers it hasn\'t seen before.';

  @override
  String get aiModeManaged => 'LifeOS AI';

  @override
  String get aiModeManagedSub => 'No setup. Included with Premium.';

  @override
  String get aiModeOwn => 'Your own provider';

  @override
  String get aiModel => 'Model';

  @override
  String get aiNever => 'Never';

  @override
  String get aiNotConfigured =>
      'Not set up — LifeOS reads documents on the phone only.';

  @override
  String get aiPreset => 'Provider';

  @override
  String get aiPresetCustom => 'Custom or local';

  @override
  String get aiPrivacyNote =>
      'Your document text goes directly from this phone to your AI provider. LifeOS servers never see it, and the image is never sent.';

  @override
  String get aiPrivacyNoteManaged =>
      'Your document text goes to LifeOS, which forwards it to the AI provider and stores nothing. The image is never sent.';

  @override
  String get aiReadBadge => 'AI-read';

  @override
  String get aiReading => 'Asking your AI provider…';

  @override
  String get aiReauth => 'Confirm it\'s you to change AI settings';

  @override
  String get aiSave => 'Save';

  @override
  String get aiSection => 'AI';

  @override
  String get aiTeaser => 'Premium AI could read this document.';

  @override
  String get aiTest => 'Test connection';

  @override
  String get aiTestOk => 'Connected.';

  @override
  String get aiTitle => 'Use my own AI provider';

  @override
  String get aiUpgrade => 'Upgrade';

  @override
  String get aiUseManaged => 'Use LifeOS AI instead';

  @override
  String get amount => 'Amount';

  @override
  String get appLock => 'App lock';

  @override
  String get appLockSub => 'Fingerprint, face or PIN to open LifeOS';

  @override
  String get atcAdd => 'Add';

  @override
  String get atcAmountOptional => 'Amount (optional)';

  @override
  String atcCadenceDay(String cycle, String day) {
    return '$cycle · $day';
  }

  @override
  String atcCadenceWindow(String from, String to) {
    return '~$from–$to monthly';
  }

  @override
  String get atcCreateAuto => 'Create tasks automatically';

  @override
  String atcCreatedThisMonth(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n tasks',
      one: '1 task',
    );
    return '⚡ ATC created $_temp0 for you this month';
  }

  @override
  String atcDays(String n) {
    return '$n days';
  }

  @override
  String get atcDelete => 'Delete';

  @override
  String get atcDeleteBody =>
      'No new tasks will be created. Tasks it already made stay in your list.';

  @override
  String get atcDeleteRule => 'Delete rule';

  @override
  String atcDeleteTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get atcDueDates => 'Due dates (optional — otherwise every 6 months)';

  @override
  String get atcDueDay => 'Due day';

  @override
  String get atcEmptyAction => '➕ Add a payment';

  @override
  String get atcEmptyBody =>
      'Tell it once what you pay regularly — rent, fees, bills — and it creates the reminders every month.';

  @override
  String get atcEmptyTitle => 'Let LifeOS remember your payments';

  @override
  String get atcEnded => 'Ended';

  @override
  String get atcEvery6Months => 'Every 6 months';

  @override
  String get atcFeeChanged => 'Fee changed';

  @override
  String atcFeeDecreasedMsg(String oldAmount, String newAmount) {
    return 'Fee decreased from $oldAmount → $newAmount. Update future tasks?';
  }

  @override
  String get atcFeeIncreased => 'Fee increased';

  @override
  String atcFeeIncreasedMsg(String oldAmount, String newAmount) {
    return 'Fee increased from $oldAmount → $newAmount. Update future tasks?';
  }

  @override
  String get atcFewerDays => 'Fewer days';

  @override
  String get atcFor => 'For';

  @override
  String atcFreeLimit(String n) {
    return 'Free plan includes $n auto-rules — Premium removes the limit';
  }

  @override
  String get atcGroupAppointments => 'Appointments';

  @override
  String get atcGroupBills => 'Bills';

  @override
  String get atcGroupFees => 'Fees';

  @override
  String get atcGroupFixed => 'Fixed';

  @override
  String atcHistory(int n, String paid) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n tasks',
      one: '1 task',
    );
    return 'Created $_temp0 · $paid paid on time';
  }

  @override
  String get atcHousehold => 'Household';

  @override
  String get atcHowOften => 'How often';

  @override
  String get atcIllScan => 'I\'ll scan it';

  @override
  String atcInstallments(String done, String total) {
    return '$done of $total paid';
  }

  @override
  String get atcInstallmentsTotal => 'How many installments in total';

  @override
  String get atcKeepAsIs => 'Keep as is';

  @override
  String atcMissedBill(String label) {
    return 'No $label bill this month — did you miss it, or should I pause this reminder?';
  }

  @override
  String get atcMonthly => 'Monthly';

  @override
  String get atcMoreDays => 'More days';

  @override
  String get atcNewPattern => 'New pattern detected';

  @override
  String atcNext(String day) {
    return 'Next $day';
  }

  @override
  String get atcNoThanks => 'No thanks';

  @override
  String get atcNotNow => 'Not now';

  @override
  String atcOnSetDates(String dates) {
    return 'On set dates · $dates';
  }

  @override
  String get atcOnce => 'Once';

  @override
  String get atcPause => 'Pause';

  @override
  String get atcPaused => 'Paused';

  @override
  String get atcPickDates => 'Pick dates';

  @override
  String get atcPresetCustom => 'Custom';

  @override
  String get atcPresetFees => 'School fee';

  @override
  String get atcPresetInstallment => 'Installment / Committee';

  @override
  String get atcPresetInternet => 'Internet';

  @override
  String get atcPresetMobile => 'Mobile';

  @override
  String get atcPresetRent => 'Rent';

  @override
  String get atcPresetSubscription => 'Subscription';

  @override
  String get atcPresetUtility => 'Utility bill';

  @override
  String atcProposalBill(String label, String when) {
    return 'Your $label bill$when. Create a monthly reminder?';
  }

  @override
  String atcProposalDue(String day) {
    return ', due $day';
  }

  @override
  String atcProposalFee(String who, String amount, String day) {
    return 'Create a fee reminder$who$amount$day?';
  }

  @override
  String atcProposalFor(String name) {
    return ' for $name';
  }

  @override
  String atcProposalWindow(String from, String to) {
    return ' usually arrives the $from–$to';
  }

  @override
  String get atcProposed => 'Proposed';

  @override
  String get atcQuarterly => 'Quarterly';

  @override
  String get atcRemindBefore => 'Remind me before';

  @override
  String get atcReminderOn => '⚡ Auto-reminder is on';

  @override
  String get atcRuleGone => 'This rule is gone';

  @override
  String get atcRuleGoneBody =>
      'It was deleted. Tasks it created are still in Tasks.';

  @override
  String get atcSaveChanges => 'Save changes';

  @override
  String get atcSavedNewTasks => 'Saved — applies to new tasks';

  @override
  String get atcSeePremium => 'See Premium';

  @override
  String get atcSkipMonths => 'Skip these months';

  @override
  String get atcStatusOn => 'On';

  @override
  String get atcStatusPaused => 'Paused — no new tasks';

  @override
  String get atcTitle => 'Auto Tasks';

  @override
  String get atcTurnOn => '⚡ Turn on auto-reminder';

  @override
  String get atcUpdateFuture => 'Update future tasks';

  @override
  String atcUpgradeBody(String n) {
    return 'Free plan includes $n auto-rules — Premium removes the limit.';
  }

  @override
  String get atcUpgradeTitle => 'Upgrade to Premium';

  @override
  String get atcUtility => 'utility';

  @override
  String get atcWaitingOk => 'Waiting for your OK';

  @override
  String get atcWhatPay => 'What do you pay regularly?';

  @override
  String get atcYearly => 'Yearly';

  @override
  String get atcYesRemind => 'Yes, remind me';

  @override
  String get autoLock => 'Lock after time in the background';

  @override
  String autoLockMinutes(String n) {
    return '$n min';
  }

  @override
  String get autoReminderOn => '⚡ Auto-reminder on';

  @override
  String get calAllDay => 'All day';

  @override
  String calCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n events',
      one: '1 event',
    );
    return '$_temp0';
  }

  @override
  String get calDenied => 'LifeOS needs calendar access to show your events.';

  @override
  String get calEventsHeader => 'Events';

  @override
  String calFromCalendar(String name) {
    return 'In $name';
  }

  @override
  String get calLocation => 'Location';

  @override
  String get calNoCalendars => 'No calendars found on this phone.';

  @override
  String get calOpenSettings => 'Open settings';

  @override
  String get calReadOnly => 'From your phone\'s calendar. Change it there.';

  @override
  String get calSection => 'Calendar';

  @override
  String get calShowEvents => 'Show calendar events';

  @override
  String get calShowEventsHint =>
      'Your phone\'s events appear in Today and Upcoming. LifeOS only reads them — it never adds, changes or deletes anything.';

  @override
  String get calWhichCalendars => 'Calendars to show';

  @override
  String get cancel => 'Cancel';

  @override
  String get continueLabel => 'Continue';

  @override
  String get cpAllDocuments => 'All documents';

  @override
  String get cpBatchHint => 'Tap a document to check or change it.';

  @override
  String cpBatchTitle(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'File $n documents',
      one: 'File 1 document',
    );
    return '$_temp0';
  }

  @override
  String get cpBelongsTo => 'Belongs to';

  @override
  String get cpBillTaskUpdated => '⚡ Bill task updated';

  @override
  String get cpBlurryBody =>
      'Image looks unclear — text may be hard to read later.';

  @override
  String cpBlurryPageBody(String pages) {
    return 'Page $pages looks unclear — text may be hard to read later.';
  }

  @override
  String get cpDiscardNew => 'Discard new';

  @override
  String get cpDiscardThis => 'Discard this one';

  @override
  String get cpDiscarded => 'Discarded';

  @override
  String cpDropPage(String pages) {
    return 'Remove page $pages';
  }

  @override
  String cpDuplicateBody(String title, String date) {
    return 'Looks like a duplicate of \'$title\', saved $date. Keep both?';
  }

  @override
  String get cpDuplicateDiscarded => 'Duplicate discarded';

  @override
  String get cpDuplicateTitle => 'Possible duplicate';

  @override
  String get cpFieldBillingMonth => 'Billing month';

  @override
  String get cpFieldDoctor => 'Doctor';

  @override
  String get cpFieldDueDate => 'Due date';

  @override
  String get cpFieldEndDate => 'End date';

  @override
  String get cpFieldExpiryDate => 'Expiry date';

  @override
  String get cpFieldInstitution => 'Institution';

  @override
  String get cpFieldIssueDate => 'Issue date';

  @override
  String get cpFieldIssuer => 'Issuer';

  @override
  String get cpFieldNumber => 'Number';

  @override
  String get cpFieldProduct => 'Product';

  @override
  String get cpFieldRefNumber => 'Reference no.';

  @override
  String get cpFieldStartDate => 'Start date';

  @override
  String get cpFieldStudent => 'Student';

  @override
  String get cpFolder => 'Folder';

  @override
  String cpHeldBack(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n need a check',
      one: '1 needs a check',
    );
    return '$_temp0';
  }

  @override
  String get cpImportFile => 'Import a file';

  @override
  String get cpJpeg => 'JPEG';

  @override
  String get cpKeepAnyway => 'Keep anyway';

  @override
  String get cpKeepBoth => 'Keep both';

  @override
  String cpMaybeDuplicate(String title) {
    return 'May be a duplicate of \'$title\'';
  }

  @override
  String get cpNobody => 'Nobody';

  @override
  String get cpNotSure => 'Not sure what this is — please pick a type.';

  @override
  String get cpNothingLeft => 'Nothing left to file';

  @override
  String cpPageOf(String n, String total) {
    return 'Page $n of $total';
  }

  @override
  String cpPages(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String get cpPdf => 'PDF';

  @override
  String get cpPdfTitle => 'LifeOS scan';

  @override
  String get cpPickType => 'Pick a type';

  @override
  String get cpReading => 'Reading document…';

  @override
  String get cpRetake => 'Retake';

  @override
  String get cpRetakeTitle => 'Retake?';

  @override
  String get cpSaveAs => 'Save as';

  @override
  String cpSaveReady(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Save $n ready documents',
      one: 'Save 1 ready document',
      zero: 'Nothing ready yet',
    );
    return '$_temp0';
  }

  @override
  String get cpSaveToVault => 'Save to Vault';

  @override
  String cpSaveToVaultOf(String total) {
    return 'Save to Vault · 1 of $total';
  }

  @override
  String cpSavedCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n documents saved to Vault',
      one: '1 document saved to Vault',
    );
    return '$_temp0';
  }

  @override
  String get cpSavedToVault => 'Saved to Vault';

  @override
  String get cpScanAnother => 'Scan another';

  @override
  String get cpScanAnyway => 'Scan anyway';

  @override
  String cpScanTitle(String date, String year) {
    return 'Scan · $date $year';
  }

  @override
  String get cpStatusCheck => 'Check';

  @override
  String get cpStatusNew => 'New';

  @override
  String get cpStatusReading => 'Reading…';

  @override
  String get cpStatusReady => 'Ready';

  @override
  String cpStorageFullBody(String mb) {
    return 'Only $mb MB free. Scans may not save — free up some space first, or scan anyway.';
  }

  @override
  String get cpStorageFullTitle => 'Storage is almost full';

  @override
  String get cpTypeAgreement => 'Agreement';

  @override
  String get cpTypeBill => 'Bill';

  @override
  String get cpTypeCertificate => 'Certificate';

  @override
  String get cpTypeCnic => 'CNIC';

  @override
  String cpTypeConfidence(String type, String percent) {
    return '$type · $percent%';
  }

  @override
  String get cpTypeDegree => 'Degree';

  @override
  String get cpTypeFeeVoucher => 'Fee voucher';

  @override
  String get cpTypeLicense => 'Driving licence';

  @override
  String get cpTypeOther => 'Document';

  @override
  String get cpTypePassport => 'Passport';

  @override
  String get cpTypePolicy => 'Insurance policy';

  @override
  String get cpTypePrescription => 'Prescription';

  @override
  String get cpTypeReceipt => 'Receipt';

  @override
  String get cpTypeReport => 'Lab report';

  @override
  String get cpTypeVisa => 'Visa';

  @override
  String get cpTypeWarranty => 'Warranty';

  @override
  String get cpUndo => 'Undo';

  @override
  String get cpUnfiled => '📥 Unfiled';

  @override
  String get cpUnreadable =>
      'Couldn\'t read any text — saved as Unclassified. Pick a type if you like.';

  @override
  String get cpUnusualBill => 'Unusually high bill ⚠';

  @override
  String get create => 'Create';

  @override
  String get dayOfMonth => 'Day of month';

  @override
  String get deleteAll => 'Delete all local data';

  @override
  String get deleteAllBody =>
      'All documents, tasks, payments and keys on this phone will be deleted. This can\'t be undone.';

  @override
  String get deleteAllConfirmHint => 'DELETE';

  @override
  String get deleteAllConfirmTitle => 'Type DELETE to confirm';

  @override
  String get deleteAllSub => 'Removes everything from this phone';

  @override
  String get deleteAllTitle => 'Delete everything?';

  @override
  String get deleteForever => 'Delete forever';

  @override
  String get dgClear => 'Clear logs';

  @override
  String get dgCleared => 'Logs cleared';

  @override
  String dgCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n entries',
      one: '1 entry',
    );
    return '$_temp0';
  }

  @override
  String get dgEmpty => 'Nothing logged yet';

  @override
  String get dgEntry => 'Diagnostics & logs';

  @override
  String get dgEntrySub => 'For testing: see and share the app\'s log';

  @override
  String dgErrorsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n errors',
      one: '1 error',
      zero: 'no errors',
    );
    return '$_temp0';
  }

  @override
  String get dgErrorsOnly => 'Errors only';

  @override
  String get dgPrivacy =>
      'The log stays on this phone and has no personal data. It is only sent if you tap Share.';

  @override
  String get dgShare => 'Share logs';

  @override
  String get dgTestError => 'Record a test error';

  @override
  String get dgTestErrorText => 'Test error recorded from Diagnostics';

  @override
  String get dgTitle => 'Diagnostics';

  @override
  String digestBills(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n bills due',
      one: '1 bill due',
      zero: 'no bills due',
    );
    return '$_temp0';
  }

  @override
  String digestBody(String score, String tasks, String bills) {
    return 'Life Score $score · $tasks · $bills';
  }

  @override
  String digestTasks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n tasks',
      one: '1 task',
      zero: 'no tasks',
    );
    return '$_temp0';
  }

  @override
  String get digestTime => 'Morning summary';

  @override
  String get domainHealth => 'Health';

  @override
  String get domainMind => 'Tasks';

  @override
  String get domainMoney => 'Money';

  @override
  String get domainPeople => 'People';

  @override
  String get domainSoul => 'Soul';

  @override
  String get domainVault => 'Documents';

  @override
  String get domainWork => 'Work';

  @override
  String get exportData => 'Export everything';

  @override
  String get exportDataSub => 'A ZIP of your documents and data';

  @override
  String exportDone(String docs) {
    return 'Export ready: $docs documents';
  }

  @override
  String get exporting => 'Preparing your export…';

  @override
  String get freeLimitReached =>
      'Free plan includes 3 auto-rules — Premium removes the limit';

  @override
  String get hmAddTask => '➕ Add a task';

  @override
  String get hmAllClear => 'All clear today ✓';

  @override
  String get hmAttentionSection => '⚠ Needs attention';

  @override
  String get hmClearDay => 'A clear day.';

  @override
  String hmDueIn(String n) {
    return 'due in $n days';
  }

  @override
  String get hmDueToday => 'due today';

  @override
  String get hmDueTomorrow => 'due tomorrow';

  @override
  String hmExpiredAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'expired $n days ago',
      one: 'expired 1 day ago',
    );
    return '$_temp0';
  }

  @override
  String hmExpiresIn(String n) {
    return 'expires in $n days';
  }

  @override
  String get hmExpiresToday => 'expires today';

  @override
  String get hmExpiresTomorrow => 'expires tomorrow';

  @override
  String get hmGreetAfternoon => 'Good afternoon 👋';

  @override
  String hmGreetAfternoonName(String name) {
    return 'Good afternoon, $name 👋';
  }

  @override
  String hmGreetCustom(String greeting) {
    return '$greeting 👋';
  }

  @override
  String hmGreetCustomName(String greeting, String name) {
    return '$greeting, $name 👋';
  }

  @override
  String get hmGreetEvening => 'Good evening 🌆';

  @override
  String hmGreetEveningName(String name) {
    return 'Good evening, $name 🌆';
  }

  @override
  String get hmGreetHello => 'Hello 👋';

  @override
  String hmGreetHelloName(String name) {
    return 'Hello, $name 👋';
  }

  @override
  String get hmGreetMorning => 'Good morning ☀️';

  @override
  String hmGreetMorningName(String name) {
    return 'Good morning, $name ☀️';
  }

  @override
  String get hmGreetNamaste => 'Namaste 🙏';

  @override
  String hmGreetNamasteName(String name) {
    return 'Namaste, $name 🙏';
  }

  @override
  String get hmGreetNight => 'Working late? 🌙';

  @override
  String hmGreetNightName(String name) {
    return 'Working late, $name? 🌙';
  }

  @override
  String get hmGreetSalam => 'Salam 👋';

  @override
  String hmGreetSalamName(String name) {
    return 'Salam, $name 👋';
  }

  @override
  String get hmNeedsAttention => 'Needs attention';

  @override
  String get hmNoPaymentsWeek => 'No payments due this week';

  @override
  String get hmNothingUrgent => 'Nothing urgent';

  @override
  String get hmNothingUrgentBody =>
      'Payments due soon and expiring documents show here.';

  @override
  String get hmNothingUrgentNice => 'Nothing urgent — nice ✓';

  @override
  String get hmPaid => 'Paid';

  @override
  String hmPaymentsWeek(String amount) {
    return '$amount in payments this week';
  }

  @override
  String get hmPromptAtcBody =>
      'Rent, fees, bills: reminded every month, automatically.';

  @override
  String get hmPromptAtcTitle => 'Add what you pay regularly ⚡';

  @override
  String get hmPromptScanBody =>
      'CNIC, passport, a bill — LifeOS files it and reminds you.';

  @override
  String get hmPromptScanTitle => 'Scan your first document 📸';

  @override
  String get hmPromptTaskBody => 'Anything on your mind, with a reminder.';

  @override
  String get hmPromptTaskTitle => 'Add a task ➕';

  @override
  String hmSeeAllCount(String n) {
    return 'See all ($n)';
  }

  @override
  String hmSeeAllN(String n) {
    return 'See all $n';
  }

  @override
  String get hmSoon => 'Soon';

  @override
  String hmThingsNeedAttention(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n things need attention',
      one: '1 thing needs attention',
    );
    return '$_temp0';
  }

  @override
  String hmTodayTasks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n tasks',
      one: '1 task',
    );
    return 'Today · $_temp0';
  }

  @override
  String hmTodayTasksEvents(String tasks, String events) {
    return 'Today · $tasks · $events';
  }

  @override
  String get hmUrgent => 'Urgent';

  @override
  String hmWasDueAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'was due $n days ago',
      one: 'was due 1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUrdu => 'اردو';

  @override
  String get lockUnavailable => 'Set a screen lock on this phone to use this';

  @override
  String get lockedTitle => 'LifeOS is locked';

  @override
  String get lookTemplate => 'Look';

  @override
  String get mnAdd => 'Add';

  @override
  String get mnAddBill => 'Add a bill to pay';

  @override
  String get mnAddBillSub =>
      'Not paid yet. It shows in the forecast, with a reminder before it\'s due.';

  @override
  String get mnAddExpense => 'Add expense';

  @override
  String get mnAddExpenseAction => '💸 Add expense';

  @override
  String get mnAddSalary => 'Add your salary to see the share';

  @override
  String get mnAddSalaryLeft => 'Add your income to see what\'s left';

  @override
  String get mnAmountError => 'Enter an amount above 0';

  @override
  String get mnAmountPaid => 'Amount paid';

  @override
  String get mnAmountPending => 'amount pending';

  @override
  String get mnAttachReceipt => '📎 Attach receipt?';

  @override
  String mnBillAdded(String date) {
    return 'Bill added for $date';
  }

  @override
  String get mnBillNameHint => 'Plumber, car service, wedding gift';

  @override
  String mnBillsPaidValue(int paid, int total) {
    return '$paid of $total';
  }

  @override
  String mnBreakdownItem(String name, String amount, String percent) {
    return '$name $amount, $percent percent';
  }

  @override
  String mnBreakdownSemantics(String items) {
    return 'Spending by category: $items';
  }

  @override
  String get mnCatFees => 'Fees & Tuition';

  @override
  String get mnCatInstallment => 'Installments';

  @override
  String get mnCatInternet => 'Internet';

  @override
  String get mnCatMobile => 'Mobile';

  @override
  String get mnCatOther => 'Other';

  @override
  String get mnCatRent => 'Rent';

  @override
  String get mnCatSubscription => 'Subscriptions';

  @override
  String get mnCatUtilities => 'Utilities';

  @override
  String get mnCategory => 'Category';

  @override
  String get mnChangeSalary => 'Change salary';

  @override
  String get mnComingUp => 'Coming up';

  @override
  String get mnDate => 'Date';

  @override
  String get mnDelete => 'Delete';

  @override
  String mnDeltaNew(String month) {
    return 'New · nothing in $month';
  }

  @override
  String mnDeltaSame(String month) {
    return 'Same as $month';
  }

  @override
  String mnDeltaVs(String percent, String month) {
    return '$percent% vs $month';
  }

  @override
  String mnDigest(String month, String total, int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n items',
      one: '1 item',
    );
    return '$month fixed payments: $total across $_temp0';
  }

  @override
  String get mnDueDate => 'Due date';

  @override
  String get mnEditExpense => 'Edit expense';

  @override
  String mnExpensesCount(String n) {
    return 'Expenses · $n';
  }

  @override
  String get mnFiledInVault => 'Filed in Vault';

  @override
  String get mnForecast => 'Forecast';

  @override
  String get mnImport => 'Import';

  @override
  String get mnLinkedNote => '⚡ Logged from a payment';

  @override
  String get mnLoggedFromPayment => 'Logged from a payment';

  @override
  String get mnLoggedInMoney => 'Logged in Money';

  @override
  String get mnMarkPaid => 'Mark paid';

  @override
  String get mnMarkUnpaid => 'Mark as unpaid';

  @override
  String get mnMarkUnpaidBody =>
      'The expense logged for it is removed and its task opens again. A receipt you attached goes to Trash.';

  @override
  String mnMarkUnpaidTitle(String title) {
    return 'Mark $title as unpaid?';
  }

  @override
  String get mnMarkedUnpaid => 'Marked as unpaid';

  @override
  String get mnMonthlySalary => 'Monthly salary';

  @override
  String get mnNextMonth => 'Next month';

  @override
  String get mnNoExpensesBody =>
      'Paid bills and quick expenses will add up here.';

  @override
  String mnNoExpensesIn(String month) {
    return 'No expenses in $month';
  }

  @override
  String get mnNoFixedBody =>
      'Add what you pay regularly in More → Auto Tasks and the forecast fills itself.';

  @override
  String get mnNoFixedTitle => 'No fixed payments this month';

  @override
  String get mnNotPaidYet => 'Not paid yet? Add it as a bill to pay';

  @override
  String get mnNoteHint => 'Note (optional)';

  @override
  String get mnNothingDue => 'No bills left to pay this month.';

  @override
  String get mnOverview => 'Overview';

  @override
  String mnPaidAmountLine(String title, String amount) {
    return '✓ $title — $amount paid';
  }

  @override
  String get mnPaidDone => '✓ Paid';

  @override
  String mnPaidHowMuch(String title) {
    return '✓ $title — how much did you pay?';
  }

  @override
  String get mnPaidOnDay => 'Paid on day';

  @override
  String get mnPickDueDate => 'Pick a date';

  @override
  String get mnPrevMonth => 'Previous month';

  @override
  String get mnReceiptAttached => 'Receipt attached';

  @override
  String mnReceiptTitle(String title) {
    return 'Receipt — $title';
  }

  @override
  String mnRemindDaysBefore(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days before',
      one: '1 day before',
    );
    return '$_temp0';
  }

  @override
  String get mnRemindOnDay => 'On the day';

  @override
  String mnSalaryLeft(String left, String salary) {
    return '$left left of $salary';
  }

  @override
  String mnSalaryOver(String over, String salary) {
    return '$over over your $salary income';
  }

  @override
  String mnSalaryShare(String percent) {
    return '$percent% of income goes to fixed payments';
  }

  @override
  String get mnSave => 'Save';

  @override
  String get mnScan => 'Scan';

  @override
  String mnSeeAllExpenses(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'See all $n expenses',
      one: 'See 1 expense',
    );
    return '$_temp0';
  }

  @override
  String get mnSeeForecast => 'See forecast';

  @override
  String get mnSpendingByCategory => 'Spending by category';

  @override
  String get mnSpent => 'Spent';

  @override
  String mnSpentIn(String month) {
    return 'Spent in $month';
  }

  @override
  String get mnSpentThisMonth => 'Spent this month';

  @override
  String get mnStatBiggest => 'Biggest';

  @override
  String get mnStatBillsPaid => 'Bills paid';

  @override
  String get mnStatPerDay => 'Per day';

  @override
  String get mnStatusOverdue => 'Overdue 🔴';

  @override
  String get mnStatusPaid => 'Paid ✓';

  @override
  String get mnStatusUpcoming => 'Upcoming';

  @override
  String get mnStatusUpcomingPlanned => 'Upcoming · planned';

  @override
  String mnStillToPay(String amount) {
    return '$amount still to pay';
  }

  @override
  String get mnTitle => 'Money';

  @override
  String mnTotals(String total, String paid, String remaining) {
    return '$total total · $paid paid · $remaining remaining';
  }

  @override
  String get mnUnavailableBody =>
      'Local data could not be opened on this device.';

  @override
  String get mnUnavailableTitle => 'Money isn\'t available';

  @override
  String get mnUncategorised => 'Uncategorised';

  @override
  String get mnUndo => 'Undo';

  @override
  String get mnYourSalary => 'Your salary';

  @override
  String get mon1 => 'Jan';

  @override
  String get mon10 => 'Oct';

  @override
  String get mon11 => 'Nov';

  @override
  String get mon12 => 'Dec';

  @override
  String get mon2 => 'Feb';

  @override
  String get mon3 => 'Mar';

  @override
  String get mon4 => 'Apr';

  @override
  String get mon5 => 'May';

  @override
  String get mon6 => 'Jun';

  @override
  String get mon7 => 'Jul';

  @override
  String get mon8 => 'Aug';

  @override
  String get mon9 => 'Sep';

  @override
  String get month1 => 'January';

  @override
  String get month10 => 'October';

  @override
  String get month11 => 'November';

  @override
  String get month12 => 'December';

  @override
  String get month2 => 'February';

  @override
  String get month3 => 'March';

  @override
  String get month4 => 'April';

  @override
  String get month5 => 'May';

  @override
  String get month6 => 'June';

  @override
  String get month7 => 'July';

  @override
  String get month8 => 'August';

  @override
  String get month9 => 'September';

  @override
  String get moreSettings => 'Settings';

  @override
  String get moreSettingsSub => 'Security, notifications, language, data';

  @override
  String get mrAutoTasks => 'Auto Tasks';

  @override
  String get mrAutoTasksSub => 'Rules that create payment tasks for you';

  @override
  String get mrProfile => 'My profile';

  @override
  String get mrProfileSub => 'Your name, greeting and language';

  @override
  String get mrTitle => 'More';

  @override
  String get mrTrashSub => 'Deleted documents, kept for 30 days';

  @override
  String get name => 'Name';

  @override
  String get next => 'Next';

  @override
  String get notifyAbout => 'Notify me about';

  @override
  String get obDoneTitle => 'You\'re set';

  @override
  String obForecast(String month, String total) {
    return '$month fixed payments: $total';
  }

  @override
  String get obForecastNone => 'Add payments any time from More → Auto Tasks.';

  @override
  String get obNotifAsk => 'We\'ll remind you before things are due.';

  @override
  String get obPayBody =>
      'Tap one, add the amount and day. LifeOS reminds you every month.';

  @override
  String get obPayTitle => 'What do you pay every month?';

  @override
  String get obRoleQ => 'Who are you organising for?';

  @override
  String get obScanBody =>
      'A CNIC, passport or bill. LifeOS reads it and files it for you.';

  @override
  String get obScanNow => '📸 Scan now';

  @override
  String get obScanTitle => 'Scan your first document';

  @override
  String get obSeeDashboard => 'See my dashboard';

  @override
  String get obWelcome => 'Welcome to LifeOS';

  @override
  String get parseHigh => 'High';

  @override
  String get payCustom => 'Custom';

  @override
  String get payElectricity => 'Electricity';

  @override
  String get payGas => 'Gas';

  @override
  String get payInstallment => 'Installment';

  @override
  String get payInternet => 'Internet';

  @override
  String get payMobile => 'Mobile';

  @override
  String get payRent => 'Rent';

  @override
  String get paySchoolFee => 'School fee';

  @override
  String pmDocLimitBody(String n) {
    return 'The free plan holds $n documents. Premium removes the limit — your documents stay where they are either way.';
  }

  @override
  String pmDocsLeft(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n documents left on the free plan',
      one: '1 document left on the free plan',
      zero: 'No documents left on the free plan',
    );
    return '$_temp0';
  }

  @override
  String get pmHeadline => 'Premium removes the free plan\'s limits.';

  @override
  String get pmManageInStore =>
      'Change or cancel in the store you bought it from. Cancelling keeps Premium until the period you paid for ends.';

  @override
  String get pmNoAccountNote =>
      'LifeOS has no account to sign in to. Premium follows the store account that bought it, and your documents never leave this phone.';

  @override
  String get pmNothingToRestore =>
      'No subscription found on this store account.';

  @override
  String pmPerkDocuments(String n) {
    return 'Unlimited documents — the free plan holds $n.';
  }

  @override
  String pmPerkRules(String n) {
    return 'Unlimited auto-rules — the free plan allows $n.';
  }

  @override
  String pmPricePerMonth(String price) {
    return '$price a month';
  }

  @override
  String get pmPriceUnavailable =>
      'The store isn\'t reachable right now, so the price can\'t be shown.';

  @override
  String get pmPurchaseFailed =>
      'The purchase didn\'t go through. Nothing was charged.';

  @override
  String get pmRestore => 'Restore purchases';

  @override
  String get pmSeePremium => 'See Premium';

  @override
  String get pmSubscribe => 'Subscribe';

  @override
  String get pmYourePremium => 'You\'re on Premium.';

  @override
  String get profileAboutYou => 'About you';

  @override
  String get profileAuto => 'Auto';

  @override
  String profileAutoValue(String value) {
    return 'Auto ($value)';
  }

  @override
  String get profileCurrency => 'Currency symbol';

  @override
  String get profileCurrencyOther => 'Another symbol';

  @override
  String get profileDateOrder => 'Dates';

  @override
  String get profileNameLabel => 'What should we call you?';

  @override
  String get profileRegion => 'Region & formats';

  @override
  String get profileWeekStart => 'Week starts on';

  @override
  String get quietHours => 'Quiet hours';

  @override
  String quietHoursValue(String from, String to) {
    return '$from – $to';
  }

  @override
  String removeChip(String what) {
    return 'Remove $what';
  }

  @override
  String get roleBusiness => 'Business owner';

  @override
  String get roleJustMe => 'Just me';

  @override
  String get roleParent => 'Parent';

  @override
  String get roleProfessional => 'Professional';

  @override
  String get roleStudent => 'Student';

  @override
  String get scCompBalance => 'Balance';

  @override
  String get scCompDocuments => 'Documents';

  @override
  String get scCompHealth => 'Health';

  @override
  String get scCompPayments => 'Payments';

  @override
  String get scCompPeople => 'People';

  @override
  String get scCompTasks => 'Tasks';

  @override
  String scComponentSemantics(String name, String pct, String weight) {
    return '$name: $pct percent, $weight percent of the score';
  }

  @override
  String scComponentValue(String pct, String weight) {
    return '$pct% · $weight pts';
  }

  @override
  String get scDay1 => 'M';

  @override
  String get scDay2 => 'T';

  @override
  String get scDay3 => 'W';

  @override
  String get scDay4 => 'T';

  @override
  String get scDay5 => 'F';

  @override
  String get scDay6 => 'S';

  @override
  String get scDay7 => 'S';

  @override
  String get scDoingWell => 'Doing well';

  @override
  String scDownSince(String n) {
    return 'Down $n since yesterday';
  }

  @override
  String scExpiredAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Expired $n days ago',
      one: 'Expired 1 day ago',
    );
    return '$_temp0';
  }

  @override
  String scExpiresIn(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Expires in $n days',
      one: 'Expires in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get scExpiresToday => 'Expires today';

  @override
  String get scFewThings => 'A few things need you';

  @override
  String get scHeavyWeek => 'Heavy week';

  @override
  String get scLast7 => 'Last 7 days';

  @override
  String get scLifeScore => 'Life Score';

  @override
  String get scMoveToday => 'Move to today';

  @override
  String get scMovedToday => 'Moved to today';

  @override
  String get scNothingPulling => 'Nothing is pulling your score down today ✓';

  @override
  String get scOpen => 'Open';

  @override
  String scRingSemantics(String score, String label) {
    return 'Life Score $score, $label';
  }

  @override
  String get scSameYesterday => 'Same as yesterday';

  @override
  String scShowAll(String n) {
    return 'Show all $n';
  }

  @override
  String scSparkSemantics(String values) {
    return 'Last 7 days: $values';
  }

  @override
  String get scStillOpen => 'Still open from yesterday';

  @override
  String get scTriageTitle => 'Heavy week? Here are the 3 highest-impact items';

  @override
  String scUpSince(String n) {
    return 'Up $n since yesterday';
  }

  @override
  String scWasDue(String date) {
    return 'Was due $date';
  }

  @override
  String get scWhatWouldLift => 'What would lift it';

  @override
  String get scWhatsInIt => 'What\'s in it';

  @override
  String scWhenSorted(String pts) {
    return '+$pts when sorted';
  }

  @override
  String get screenshotBlock => 'Block screenshots in the Vault';

  @override
  String get setGreeting => 'Greeting';

  @override
  String get setGreetingAuto => 'Automatic — time of day';

  @override
  String get setGreetingCustom => 'Custom…';

  @override
  String get setGreetingCustomHint => 'Your greeting, e.g. Shalom';

  @override
  String get setGreetingHello => 'Hello';

  @override
  String get setGreetingNamaste => 'Namaste';

  @override
  String get setGreetingSalam => 'Salam';

  @override
  String get setWidgetDetails => 'Show details on widget';

  @override
  String get setWidgetDetailsSub =>
      'Task titles and amounts on the home-screen widget';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsPremium => 'Premium';

  @override
  String get settingsPremiumSub => 'Coming soon';

  @override
  String get settingsSecurity => 'Security';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get shAddDocuments => 'Add documents';

  @override
  String shBundleDefaultTitle(String date) {
    return 'Shared PDF · $date';
  }

  @override
  String get shClearSelection => 'Clear selection';

  @override
  String get shDeletePack => 'Delete share pack';

  @override
  String get shDeletedDoc => 'Deleted document';

  @override
  String get shDocuments => 'Documents';

  @override
  String get shDone => 'Done';

  @override
  String get shFailed => 'Couldn\'t prepare the share. Please try again.';

  @override
  String get shHistory => 'Share history';

  @override
  String get shHistoryEmptyMessage =>
      'Documents you share from the Vault appear here.';

  @override
  String get shHistoryEmptyTitle => 'Nothing shared yet';

  @override
  String get shHistorySub => 'What you\'ve shared, kept only on this phone';

  @override
  String get shJobPack => 'Job Application Pack';

  @override
  String get shJobPackSub => 'Degree, CNIC, CV and photo';

  @override
  String shMissingDocs(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n documents in this pack are no longer in the Vault',
      one: '1 document in this pack is no longer in the Vault',
    );
    return '$_temp0';
  }

  @override
  String get shNewPack => 'New share pack';

  @override
  String get shNoDocuments => 'Add at least one document';

  @override
  String shPackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n documents',
      one: '1 document',
    );
    return '$_temp0';
  }

  @override
  String get shPackSaved => 'Share pack saved';

  @override
  String get shPackTitle => 'Title';

  @override
  String get shPackTitleHint => 'e.g. Job Application Pack';

  @override
  String get shPacks => 'Share packs';

  @override
  String get shPacksSub => 'Documents you often send together';

  @override
  String get shPickDocuments => 'Choose documents';

  @override
  String shPreparing(String done, String total) {
    return 'Preparing… $done of $total pages';
  }

  @override
  String get shPromoLine =>
      'Shared with LifeOS. Scan to get the free app for Android and iPhone.';

  @override
  String get shPurpose => 'Purpose (optional)';

  @override
  String get shPurposeHint => 'e.g. account opening';

  @override
  String get shRecipientRequired => 'Enter who it\'s for';

  @override
  String get shRemove => 'Remove';

  @override
  String get shReorderHint => 'Drag to change the order';

  @override
  String get shSaveFolder => 'Folder';

  @override
  String get shSavePack => 'Save as share pack';

  @override
  String get shSaveToVault => 'Also save to the Vault';

  @override
  String get shSavedToVault => 'Also saved to the Vault';

  @override
  String shSelected(String n) {
    return '$n selected';
  }

  @override
  String get shShare => 'Share';

  @override
  String get shShareAsPdf => 'Share as one PDF';

  @override
  String get shShareFile => 'Share file';

  @override
  String get shShareFileSub => 'The document as it is';

  @override
  String get shShareFileSubFree =>
      'One PDF, with a small LifeOS line at the bottom';

  @override
  String get shShareWatermark => 'Share with watermark…';

  @override
  String get shShareWatermarkSub =>
      'Stamp who it\'s for, so the copy can\'t be reused';

  @override
  String shSharedTimes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Shared $n times',
      one: 'Shared once',
    );
    return '$_temp0';
  }

  @override
  String get shSharedWith => 'Shared with';

  @override
  String get shSharedWithHint => 'e.g. ABC Bank';

  @override
  String shTo(String recipient) {
    return 'To $recipient';
  }

  @override
  String get shWatermarkTitle => 'Add watermark';

  @override
  String get shWatermarked => 'Watermarked';

  @override
  String shWmFull(String name, String recipient, String purpose, String date) {
    return 'Shared by $name with $recipient for $purpose — $date';
  }

  @override
  String shWmNoName(String recipient, String purpose, String date) {
    return 'Shared with $recipient for $purpose — $date';
  }

  @override
  String shWmNoNameNoPurpose(String recipient, String date) {
    return 'Shared with $recipient — $date';
  }

  @override
  String shWmNoPurpose(String name, String recipient, String date) {
    return 'Shared by $name with $recipient — $date';
  }

  @override
  String get skip => 'Skip';

  @override
  String get speak => 'Speak';

  @override
  String get templateClassic => 'Classic · large text';

  @override
  String get templateFlagship => 'Flagship';

  @override
  String get templateFunky => 'Funky';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeMode => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get tkActionDismiss => 'Dismiss';

  @override
  String get tkActionDone => 'Done ✓';

  @override
  String get tkActionPaid => 'Paid ✓';

  @override
  String get tkActionRenew => 'Set renewal task';

  @override
  String get tkAdd => 'Add';

  @override
  String get tkAddAnyway => 'Add anyway';

  @override
  String get tkAddNotes => 'Add notes';

  @override
  String get tkAddReminder => 'Add reminder';

  @override
  String get tkAddSubtask => 'Add a sub-task';

  @override
  String get tkAddTaskAction => '➕ Add task';

  @override
  String get tkAllDay => 'All day';

  @override
  String get tkAnytime => 'Anytime';

  @override
  String get tkAutoCreated => 'Auto-created';

  @override
  String get tkCantOpen => 'Can\'t open this task';

  @override
  String get tkChannelDesc => 'Task, payment and document reminders';

  @override
  String get tkChannelName => 'Reminders';

  @override
  String get tkCloseQuickActions => 'Close quick actions';

  @override
  String tkComingSoon(String pbi) {
    return 'Coming soon ($pbi).';
  }

  @override
  String get tkCompletedEmptyBody =>
      'Tasks you tick off show here, newest first.';

  @override
  String get tkCompletedEmptyTitle => 'Nothing completed yet';

  @override
  String get tkCompletedTasks => 'Completed tasks';

  @override
  String get tkCompletedTitle => 'Completed';

  @override
  String get tkCreatedAuto => 'Created automatically';

  @override
  String tkCreatedByRule(String name) {
    return 'Created by rule: $name';
  }

  @override
  String tkCreatedFrom(String title) {
    return 'Created from: $title';
  }

  @override
  String tkDayFull(String day, String load, String capacity) {
    return '$day is already full ($load of $capacity)';
  }

  @override
  String tkDayLoad(String day, String load) {
    return '$day $load';
  }

  @override
  String tkDayLoadOver(String day, String load) {
    return '$day $load, over capacity';
  }

  @override
  String get tkDelete => 'Delete';

  @override
  String tkDeleteBody(String title) {
    return '\"$title\" and its sub-tasks will be removed.';
  }

  @override
  String get tkDeleteTitle => 'Delete this task?';

  @override
  String tkDocDue(String date) {
    return 'Due: $date';
  }

  @override
  String tkDocIssuer(String issuer) {
    return 'Issuer: $issuer';
  }

  @override
  String tkDocType(String type) {
    return 'Type: $type';
  }

  @override
  String get tkDomainMind => 'Mind';

  @override
  String get tkDomainVault => 'Vault';

  @override
  String get tkDomains => 'Domains';

  @override
  String get tkDone => 'Done';

  @override
  String tkDoneAt(String time) {
    return 'Done at $time';
  }

  @override
  String get tkDoneNext => 'Done — next one scheduled';

  @override
  String tkDoneTitle(String title) {
    return 'Done: $title';
  }

  @override
  String get tkDue => 'Due';

  @override
  String get tkEmptyDomainsBody => 'Tasks are grouped by life area here.';

  @override
  String get tkEmptyDomainsTitle => 'No open tasks';

  @override
  String get tkEmptyTodayBody =>
      'Add a task and it\'ll show up here for today.';

  @override
  String get tkEmptyTodayTitle => 'Nothing on your plate';

  @override
  String get tkEmptyWeekBody => 'Nothing is due in the next 7 days.';

  @override
  String get tkEmptyWeekTitle => 'A clear week ahead';

  @override
  String tkEveryDay(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Every $n days',
      one: 'Every day',
    );
    return '$_temp0';
  }

  @override
  String tkEveryMonth(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Every $n months',
      one: 'Every month',
    );
    return '$_temp0';
  }

  @override
  String tkEveryWeek(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Every $n weeks',
      one: 'Every week',
    );
    return '$_temp0';
  }

  @override
  String get tkFewerOptions => 'Fewer options';

  @override
  String get tkFor => 'For';

  @override
  String get tkFull => '⚠ Full';

  @override
  String get tkGoneBody => 'It was deleted or completed.';

  @override
  String get tkGoneTitle => 'This task is gone';

  @override
  String tkHasRoom(String day) {
    return '$day has room.';
  }

  @override
  String tkHeatDay(String day, String percent) {
    return '$day: $percent percent';
  }

  @override
  String tkHeatDayFull(String day, String percent) {
    return '$day: $percent percent, full';
  }

  @override
  String get tkHigh => 'High';

  @override
  String get tkHighChip => '‼ High';

  @override
  String tkHours(String n) {
    return '$n h';
  }

  @override
  String get tkLifeArea => 'Life area';

  @override
  String get tkLow => 'Low';

  @override
  String tkMarkDone(String title) {
    return 'Mark \"$title\" done';
  }

  @override
  String get tkMarkNotDone => 'Mark as not done';

  @override
  String get tkMedium => 'Medium';

  @override
  String tkMinutes(String n) {
    return '$n min';
  }

  @override
  String get tkMoreOptions => 'More options';

  @override
  String tkMoveTo(String day) {
    return 'Move to $day';
  }

  @override
  String get tkMuteRule => 'Mute this rule';

  @override
  String get tkNever => 'Never';

  @override
  String get tkNewTask => 'New task';

  @override
  String get tkNoDate => 'No date';

  @override
  String get tkNoLighterDay =>
      'No lighter day in the next two weeks — pick a day, or add it anyway.';

  @override
  String get tkNotes => 'Notes';

  @override
  String tkNotifDue(String date) {
    return 'Due $date';
  }

  @override
  String tkNotifDueLower(String date) {
    return 'due $date';
  }

  @override
  String get tkNotifExpiryBody => 'Tap to see which one and renew it';

  @override
  String get tkNotifExpiryTitle => 'A document expires soon';

  @override
  String get tkNotifHidden => 'Open LifeOS to see details';

  @override
  String get tkNotifPaymentTitle => 'A payment is due';

  @override
  String get tkNotifReminder => 'Reminder';

  @override
  String get tkNotifTaskTitle => 'A task is due';

  @override
  String get tkOffset10m => '10 minutes before';

  @override
  String get tkOffset1d => '1 day before';

  @override
  String get tkOffset1h => '1 hour before';

  @override
  String get tkOffsetAtDue => 'At due time';

  @override
  String get tkOverdue => 'Overdue';

  @override
  String get tkPayments => 'Payments ⚡';

  @override
  String get tkPickDate => 'Pick date';

  @override
  String get tkPickDateTime => 'Pick a date & time';

  @override
  String get tkPickDay => 'Pick a day';

  @override
  String get tkPickTime => 'Pick a time…';

  @override
  String get tkPriority => 'Priority';

  @override
  String get tkQaExpense => 'Expense';

  @override
  String get tkQaExpenseTitle => 'Log an expense';

  @override
  String get tkQaScan => 'Scan';

  @override
  String get tkQaScanTitle => 'Scan a document';

  @override
  String get tkQaTask => 'Task';

  @override
  String get tkQaTaskTitle => 'Add a task';

  @override
  String get tkQaVoice => 'Voice';

  @override
  String get tkQaVoiceTitle => 'Speak a task';

  @override
  String get tkQuickActions => 'Quick actions';

  @override
  String get tkRemoveDueDate => 'Remove due date';

  @override
  String get tkRemoveReminder => 'Remove reminder';

  @override
  String get tkRemoveSubtask => 'Remove sub-task';

  @override
  String get tkRenewDocument => 'document';

  @override
  String tkRenewTitle(String what) {
    return 'Renew $what';
  }

  @override
  String get tkReopened => 'Back in your tasks';

  @override
  String get tkRepeat => 'Repeat';

  @override
  String get tkRulePaused => 'Rule paused — no new tasks from it';

  @override
  String get tkSkipCycle => 'Skip this cycle';

  @override
  String get tkSnooze => 'Snooze';

  @override
  String tkSubtasks(String done, String total) {
    return 'Sub-tasks ($done/$total)';
  }

  @override
  String get tkTabHome => 'Home';

  @override
  String get tkTabMoney => 'Money';

  @override
  String get tkTabMore => 'More';

  @override
  String get tkTabVault => 'Vault';

  @override
  String get tkTakesAbout => 'Takes about';

  @override
  String get tkTask => 'Task';

  @override
  String get tkTasks => 'Tasks';

  @override
  String get tkTime => 'Time';

  @override
  String get tkTimed => 'Timed';

  @override
  String get tkTomorrowMorning => 'Tomorrow morning';

  @override
  String tkTomorrowOn(String date) {
    return 'Tomorrow · $date';
  }

  @override
  String get tkTonight => 'Tonight';

  @override
  String get tkUnavailableBody =>
      'Local data could not be opened on this device.';

  @override
  String get tkUnavailableTitle => 'Tasks aren\'t available';

  @override
  String get tkUndo => 'Undo';

  @override
  String get tkUpcoming => 'Upcoming';

  @override
  String tkWeekLoad(String days) {
    return 'Week load: $days';
  }

  @override
  String get tkWeekday1 => 'Monday';

  @override
  String get tkWeekday2 => 'Tuesday';

  @override
  String get tkWeekday3 => 'Wednesday';

  @override
  String get tkWeekday4 => 'Thursday';

  @override
  String get tkWeekday5 => 'Friday';

  @override
  String get tkWeekday6 => 'Saturday';

  @override
  String get tkWeekday7 => 'Sunday';

  @override
  String get tkWhatNeedsDoing => 'What needs doing?';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get trash => 'Trash';

  @override
  String get turnOn => 'Turn on';

  @override
  String get unlock => 'Unlock';

  @override
  String get unlockReason => 'Unlock LifeOS';

  @override
  String get unlockVaultReason => 'Unlock your Vault';

  @override
  String get vaultLock => 'Vault lock';

  @override
  String get vaultLockSub => 'Ask again before opening the Vault';

  @override
  String get vaultLockedTitle => 'The Vault is locked';

  @override
  String get voiceHint => 'Try: \"Pay electricity bill Friday 5pm\"';

  @override
  String get voiceListening => 'Listening…';

  @override
  String get voiceTitle => 'Speak your task';

  @override
  String get voiceTryAgain => 'Try again';

  @override
  String get voiceUnavailable =>
      'Voice isn\'t available on this phone — type instead';

  @override
  String get vtAdd => 'Add';

  @override
  String get vtAddFavourite => 'Add to favourites';

  @override
  String get vtAddPerson => 'Add person';

  @override
  String get vtAddTag => 'Add tag';

  @override
  String get vtAddTagHint => 'Add a tag';

  @override
  String get vtAdded => 'Added';

  @override
  String get vtAmount => 'Amount';

  @override
  String get vtAnyTime => 'Any time';

  @override
  String get vtAnyType => 'Any type';

  @override
  String get vtAnyone => 'Anyone';

  @override
  String get vtArchive => 'Archive';

  @override
  String get vtArchived => 'Archived';

  @override
  String get vtBelongsTo => 'Belongs to';

  @override
  String get vtClear => 'Clear';

  @override
  String vtClearField(String label) {
    return 'Clear $label';
  }

  @override
  String get vtClearSearch => 'Clear search';

  @override
  String vtDaysLeftShort(String n) {
    return '${n}d left';
  }

  @override
  String get vtDelete => 'Delete';

  @override
  String vtDeleteDocBody(String title) {
    return '\"$title\" will be removed.';
  }

  @override
  String get vtDeleteDocTitle => 'Delete this document?';

  @override
  String get vtDeleteFolder => 'Delete folder';

  @override
  String get vtDeleteFolderBody =>
      'Its documents move to Unfiled — nothing is lost.';

  @override
  String vtDeleteFolderTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String vtDeleteForeverBody(String title) {
    return '\"$title\" and its files will be removed from this phone. This can\'t be undone.';
  }

  @override
  String get vtDeleteForeverTitle => 'Delete forever?';

  @override
  String get vtDetails => 'Details';

  @override
  String vtDocCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n docs',
      one: '1 doc',
    );
    return '$_temp0';
  }

  @override
  String get vtDocGoneMessage =>
      'It was deleted. Look in Vault → Trash to restore it.';

  @override
  String get vtDocGoneTitle => 'This document is gone';

  @override
  String get vtDueDate => 'Due date';

  @override
  String get vtEdit => 'Edit';

  @override
  String get vtEditPerson => 'Edit person';

  @override
  String get vtEmptyMessage => 'Scan or import a document to file it here.';

  @override
  String get vtEmptyTitle => 'Nothing here yet';

  @override
  String vtExpiredAgo(String n) {
    return 'Expired ${n}d ago';
  }

  @override
  String get vtExpiresToday => 'Expires today';

  @override
  String get vtExpiringSoon => 'Expiring soon';

  @override
  String vtExpiringSoonCount(String n) {
    return '⏰ Expiring soon ($n)';
  }

  @override
  String get vtExpiryDate => 'Expiry date';

  @override
  String get vtExpiryPrompt => 'Does this document expire?';

  @override
  String get vtFavourite => 'Favourite';

  @override
  String get vtFolder => 'Folder';

  @override
  String get vtFolderBills => 'Bills & Receipts';

  @override
  String get vtFolderEducation => 'Education';

  @override
  String get vtFolderIdentity => 'Identity';

  @override
  String get vtFolderInsurance => 'Insurance';

  @override
  String get vtFolderMedical => 'Medical';

  @override
  String get vtFolderName => 'Folder name';

  @override
  String get vtFolderOptions => 'Folder options';

  @override
  String get vtFolderProperty => 'Property';

  @override
  String get vtFolderVehicles => 'Vehicles';

  @override
  String get vtFolderWork => 'Work';

  @override
  String get vtFolders => 'Folders';

  @override
  String get vtImportFiles => 'Import from files';

  @override
  String get vtIssuer => 'Issuer';

  @override
  String vtLadderAlerts(String list, String next) {
    return 'Alerts: $list\nNext: $next';
  }

  @override
  String vtLadderDayAfter(String n) {
    return '$n day after';
  }

  @override
  String vtLadderDaysBefore(String n) {
    return '$n days before';
  }

  @override
  String get vtLadderExpired => 'Expired — a weekly reminder until renewed';

  @override
  String get vtLadderOnDay => 'on the day';

  @override
  String get vtLast30Days => 'Last 30 days';

  @override
  String get vtLinkedTasks => 'Linked tasks';

  @override
  String get vtMarkRenewed => 'Mark renewed → scan the new one';

  @override
  String get vtMove => 'Move';

  @override
  String get vtMovedToTrash => 'Moved to Trash';

  @override
  String get vtNewFolder => 'New folder';

  @override
  String get vtNo => 'No';

  @override
  String get vtNoMatches => 'No matches';

  @override
  String get vtNoMatchesHint =>
      'Try a title, an issuer like K-Electric, a word from the document, or a tag.';

  @override
  String get vtNoPages => 'No pages stored for this document';

  @override
  String get vtNobody => 'Nobody';

  @override
  String get vtNotSet => 'Not set';

  @override
  String get vtNothingExpiring => 'Nothing expiring';

  @override
  String get vtNothingExpiringMessage =>
      'Documents due to expire in the next 90 days show here.';

  @override
  String get vtOwnProfileProtected => 'Your own profile can\'t be deleted';

  @override
  String vtPageOf(String page, String total) {
    return 'Page $page of $total';
  }

  @override
  String get vtPeople => 'People';

  @override
  String get vtPerson => 'Person';

  @override
  String get vtPersonOptions => 'Person options';

  @override
  String get vtRefNumber => 'Reference / number';

  @override
  String get vtRelationChild => 'Child';

  @override
  String get vtRelationOther => 'Other';

  @override
  String get vtRelationParent => 'Parent';

  @override
  String get vtRelationSpouse => 'Spouse';

  @override
  String get vtRemoveFavourite => 'Remove from favourites';

  @override
  String get vtRemovePerson => 'Remove person';

  @override
  String get vtRemovePersonBody =>
      'Their documents stay in the Vault, unassigned.';

  @override
  String vtRemovePersonTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String vtRemoveTag(String tag) {
    return 'Remove tag $tag';
  }

  @override
  String get vtRename => 'Rename';

  @override
  String get vtRenameFolder => 'Rename folder';

  @override
  String get vtRestore => 'Restore';

  @override
  String get vtSave => 'Save';

  @override
  String get vtScan => 'Scan';

  @override
  String get vtScanAction => '📸 Scan';

  @override
  String get vtSearchHint => 'Search documents…';

  @override
  String get vtSearchUnavailable => 'Search isn\'t available';

  @override
  String get vtSeeAll => 'See all';

  @override
  String get vtSetDate => 'Set date';

  @override
  String get vtShare => 'Share';

  @override
  String get vtSharedFrom => 'Shared from LifeOS';

  @override
  String get vtSystemFolderNoDelete => 'System folders can\'t be deleted';

  @override
  String get vtSystemFolderNoRename => 'System folders can\'t be renamed';

  @override
  String get vtTags => 'Tags';

  @override
  String get vtThisYear => 'This year';

  @override
  String vtTrashDaysLeft(String n) {
    return '$n days left';
  }

  @override
  String get vtTrashEmpty => 'Trash is empty';

  @override
  String vtTrashEmptyMessage(String days) {
    return 'Deleted documents stay here for $days days, then are removed for good.';
  }

  @override
  String get vtTrashUnavailable => 'Trash isn\'t available';

  @override
  String get vtTryAgain => 'Please try again.';

  @override
  String get vtType => 'Type';

  @override
  String get vtTypeAgreement => 'Agreement';

  @override
  String get vtTypeBill => 'Bill';

  @override
  String get vtTypeCertificate => 'Certificate';

  @override
  String get vtTypeCnic => 'CNIC';

  @override
  String get vtTypeDegree => 'Degree';

  @override
  String get vtTypeFeeVoucher => 'Fee voucher';

  @override
  String get vtTypeLicense => 'License';

  @override
  String get vtTypeOther => 'Document';

  @override
  String get vtTypePassport => 'Passport';

  @override
  String get vtTypePolicy => 'Policy';

  @override
  String get vtTypePrescription => 'Prescription';

  @override
  String get vtTypeReceipt => 'Receipt';

  @override
  String get vtTypeReport => 'Report';

  @override
  String get vtTypeVisa => 'Visa';

  @override
  String get vtTypeWarranty => 'Warranty';

  @override
  String get vtUnarchive => 'Unarchive';

  @override
  String get vtUnavailableMessage =>
      'Local data could not be opened on this device.';

  @override
  String get vtUnavailableTitle => 'The Vault isn\'t available';

  @override
  String get vtUndo => 'Undo';

  @override
  String get vtUnfiled => 'Unfiled';

  @override
  String get vtUnfiledTitle => '📥 Unfiled';

  @override
  String get vtVaultTitle => 'Vault';

  @override
  String get wd1 => 'Mon';

  @override
  String get wd2 => 'Tue';

  @override
  String get wd3 => 'Wed';

  @override
  String get wd4 => 'Thu';

  @override
  String get wd5 => 'Fri';

  @override
  String get wd6 => 'Sat';

  @override
  String get wd7 => 'Sun';

  @override
  String get wgAllClear => 'All clear today ✨';

  @override
  String wgDueShort(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n due',
      one: '1 due',
    );
    return '$_temp0';
  }

  @override
  String get wgLockPromptBody =>
      'App Lock is on, but the home-screen widget can still show task titles and amounts. Show only the score and counts instead?';

  @override
  String get wgLockPromptHide => 'Hide details';

  @override
  String get wgLockPromptKeep => 'Keep showing';

  @override
  String get wgLockPromptTitle => 'Hide details on the widget?';

  @override
  String wgMore(String n) {
    return '+$n more';
  }

  @override
  String wgPaymentLine(String title, String amount, String day) {
    return '⚡ $title ~$amount · $day';
  }

  @override
  String wgPaymentLineNoAmount(String title, String day) {
    return '⚡ $title · $day';
  }

  @override
  String wgTasksShort(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n tasks',
      one: '1 task',
      zero: 'No tasks',
    );
    return '$_temp0';
  }

  @override
  String get yesterday => 'Yesterday';

  @override
  String get inboxTitle => 'Inbox';

  @override
  String get inboxEmptyTitle => 'Your inbox is clear';

  @override
  String get inboxEmptyBody =>
      'Capture ideas, tasks, expenses — tap + to add something.';

  @override
  String get inboxCapture => 'Capture';

  @override
  String get inboxCaptureText => 'Text';

  @override
  String get inboxCaptureVoice => 'Voice';

  @override
  String get inboxCapturePhoto => 'Photo';

  @override
  String get inboxCloseCapture => 'Close';

  @override
  String get inboxQuickCapture => 'Quick capture';

  @override
  String get inboxCaptureHint => 'What\'s on your mind?';

  @override
  String get inboxCaptureHelp =>
      'We\'ll help you turn this into a task, expense, or document later.';

  @override
  String get inboxSaveToInbox => 'Save to Inbox';

  @override
  String get inboxCaptured => 'Captured';

  @override
  String get inboxDismissed => 'Dismissed';

  @override
  String get inboxUntitled => 'Untitled capture';

  @override
  String get inboxError => 'Something went wrong';

  @override
  String get inboxClassify => 'What is this?';

  @override
  String get inboxClassifyAs => 'Create as';

  @override
  String get inboxTypeTask => 'Task';

  @override
  String get inboxTypeExpense => 'Expense';

  @override
  String get inboxTypeDocument => 'Document';

  @override
  String get inboxTypeNote => 'Note';

  @override
  String get inboxCreatedTask => 'Task created';

  @override
  String get inboxCreatedExpense => 'Expense logged';

  @override
  String get inboxCreatedDocument => 'Document started';

  @override
  String get inboxCreatedNote => 'Note saved';

  @override
  String inboxBadge(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get briefTitle => 'Your Daily Brief';

  @override
  String get briefButtonTitle => 'Get your brief';

  @override
  String briefButtonSubtitle(int score, int tasks) {
    return 'Score $score · $tasks tasks today';
  }

  @override
  String get briefSpeak => 'Speak';

  @override
  String get briefStop => 'Stop';

  @override
  String get briefError => 'Couldn\'t load your brief';

  @override
  String get briefAiGenerated => 'AI-enhanced';

  @override
  String get briefStatTasks => 'Tasks';

  @override
  String get briefStatOverdue => 'Overdue';

  @override
  String get briefStatExpiring => 'Expiring';

  @override
  String get briefStatBudget => 'Budget';

  @override
  String get briefPremiumTitle => 'AI-powered briefs';

  @override
  String get briefPremiumBody =>
      'Upgrade to Premium for natural, conversational morning briefings powered by AI.';

  @override
  String briefScoreExcellent(int score) {
    return 'Great news! Your Life Score is $score — you\'re doing well.';
  }

  @override
  String briefScoreSteady(int score) {
    return 'Your Life Score is $score. A few things need your attention.';
  }

  @override
  String briefScoreTriage(int score) {
    return 'Your Life Score is $score. Let\'s focus on what matters most today.';
  }

  @override
  String get briefNoTasks => 'No tasks due today.';

  @override
  String briefTasks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'You have $n tasks due today.',
      one: 'You have 1 task due today.',
    );
    return '$_temp0';
  }

  @override
  String briefOverduePayments(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n payments are overdue.',
      one: '1 payment is overdue.',
    );
    return '$_temp0';
  }

  @override
  String briefExpiringDocs(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n documents expire soon.',
      one: '1 document expires soon.',
    );
    return '$_temp0';
  }

  @override
  String briefBudgetWarning(int percent) {
    return 'You\'ve used $percent% of your monthly budget.';
  }

  @override
  String get briefAllClear => 'Enjoy your clear day!';

  @override
  String get briefPreviewClear => 'All clear today ✨';

  @override
  String get briefPreviewUrgent => 'Some things need attention';

  @override
  String briefPreviewNormal(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n tasks today',
      one: '1 task today',
    );
    return '$_temp0';
  }

  @override
  String get briefSettingsTitle => 'Brief Settings';

  @override
  String get briefEnabled => 'Morning brief';

  @override
  String get briefEnabledSub => 'Get a daily voice brief notification';

  @override
  String get briefTime => 'Brief time';

  @override
  String get briefTimeSub => 'When you\'d like your morning brief';

  @override
  String get briefTtsRate => 'Speaking speed';

  @override
  String get briefTtsRateSub => 'How fast the brief is spoken';

  @override
  String get briefTtsSlow => 'Slow';

  @override
  String get briefTtsFast => 'Fast';

  @override
  String get briefTtsTest => 'Test voice';

  @override
  String get briefAiConsent => 'AI-enhanced briefs';

  @override
  String get briefAiConsentSub =>
      'Use AI to generate natural, conversational briefs';

  @override
  String get briefAiReady => 'AI is configured and ready';

  @override
  String get briefNotifTitle => 'Your morning brief';

  @override
  String briefNotifBody(int score, int tasks) {
    return 'Life Score $score · $tasks tasks today';
  }

  @override
  String get accountTitle => 'Account';

  @override
  String get accountCreateTitle => 'Create Account';

  @override
  String get accountCreateDescription =>
      'Create an account to back up your vault and sync across devices.';

  @override
  String get accountRecoveryPhrase => 'Recovery Phrase';

  @override
  String get accountRecoveryPhraseDescription =>
      'A 12-word phrase that lets you recover your account on any device.';

  @override
  String get accountEncryption => 'End-to-End Encryption';

  @override
  String get accountEncryptionDescription =>
      'Your data is encrypted with your recovery phrase. Only you can read it.';

  @override
  String get accountGetStarted => 'Get Started';

  @override
  String get accountNotNow => 'Not Now';

  @override
  String get accountYourRecoveryPhrase => 'Your Recovery Phrase';

  @override
  String get accountWriteDown =>
      'Write down these 12 words in order. You\'ll need them to recover your account.';

  @override
  String get accountCopy => 'Copy to clipboard';

  @override
  String get accountCopied => 'Copied to clipboard';

  @override
  String get accountWarning =>
      'If you lose this phrase, you\'ll lose access to your encrypted data. There is no way to recover it.';

  @override
  String get accountWroteItDown => 'I wrote it down';

  @override
  String get accountVerify => 'Verify Your Phrase';

  @override
  String get accountEnterWords =>
      'Enter these words from your phrase to verify you wrote it down correctly.';

  @override
  String get accountWord => 'Word';

  @override
  String get accountVerifyButton => 'Verify';

  @override
  String get accountVerificationFailed =>
      'Verification failed. Please check the words and try again.';

  @override
  String get accountCreated => 'Account Created!';

  @override
  String get accountCreatedDescription =>
      'Your account is ready. Your vault is now encrypted with your recovery phrase.';

  @override
  String get accountDone => 'Done';

  @override
  String get accountRecover => 'Recover Account';

  @override
  String get accountRecoverDescription =>
      'Enter your 12-word recovery phrase to recover your account.';

  @override
  String get accountRecoverPlaceholder =>
      'Enter your 12-word recovery phrase...';

  @override
  String get accountRecoverButton => 'Recover';

  @override
  String get accountRecoverSuccess => 'Account recovered successfully!';

  @override
  String get accountRecoverFailed =>
      'Invalid recovery phrase. Please check and try again.';

  @override
  String get accountViewPhrase => 'View Recovery Phrase';

  @override
  String get accountViewPhraseDescription =>
      'View your recovery phrase to back it up again.';

  @override
  String get accountNoAccount => 'No account created';

  @override
  String get accountNoAccountDescription =>
      'Create an account to enable backup and sync.';

  @override
  String get inbox => 'Inbox';

  @override
  String get inboxEmpty => 'Inbox is clear';

  @override
  String get inboxEmptyHint =>
      'Tap + to capture a thought, photo, or voice note.';

  @override
  String get inboxHelp => 'About Inbox';

  @override
  String get inboxHelpText =>
      'The inbox holds your quick captures until you\'re ready to sort them into tasks, expenses, documents, or notes.';

  @override
  String get classify => 'Sort';

  @override
  String get classifyAs => 'Sort this as...';

  @override
  String get captureDeleted => 'Capture deleted';

  @override
  String get undo => 'Undo';

  @override
  String get quickCapture => 'Quick Capture';

  @override
  String get captureHint => 'What\'s on your mind?';

  @override
  String get captureHintSubtle => 'We\'ll help you sort it later.';

  @override
  String get captureSaved => 'Captured';

  @override
  String get text => 'Text';

  @override
  String get voice => 'Voice';

  @override
  String get photo => 'Photo';

  @override
  String get task => 'Task';

  @override
  String get expense => 'Expense';

  @override
  String get document => 'Document';

  @override
  String get note => 'Note';

  @override
  String get taskCreated => 'Task created';

  @override
  String get savedAsNote => 'Saved as note';

  @override
  String get textAsDocument => 'Create as document?';

  @override
  String get textAsDocumentHint =>
      'This will save the text as a searchable document in your vault.';

  @override
  String get keepAsNote => 'Keep as note';

  @override
  String get createDocument => 'Create document';

  @override
  String get justNow => 'Just now';

  @override
  String get minutesAgo => 'min ago';

  @override
  String get hoursAgo => 'h ago';

  @override
  String get daysAgo => 'd ago';

  @override
  String get dailyBrief => 'Daily Brief';

  @override
  String get todayAtAGlance => 'Today at a Glance';

  @override
  String get tasks => 'Tasks';

  @override
  String get overdue => 'Overdue';

  @override
  String get expiring => 'Expiring';

  @override
  String get lifeScore => 'Life Score';

  @override
  String get speakBrief => 'Speak Brief';

  @override
  String get stop => 'Stop';

  @override
  String get speechRate => 'Speech Rate';

  @override
  String get briefSettings => 'Brief Settings';

  @override
  String get notifications => 'Notifications';

  @override
  String get heavyWeek => 'Heavy week ahead';

  @override
  String get greatDay => 'Great day ahead!';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get morningBrief => 'Morning brief';

  @override
  String get afternoonBrief => 'Afternoon update';

  @override
  String get eveningBrief => 'Evening summary';

  @override
  String get ok => 'OK';

  @override
  String get acctCreateTitle => 'Create Account';

  @override
  String get acctWhyCreate => 'Why create an account?';

  @override
  String get acctBenefitRecover => 'Recover your data';

  @override
  String get acctBenefitRecoverDesc =>
      'If you lose your phone or reinstall the app, your 12-word recovery phrase brings everything back.';

  @override
  String get acctBenefitSecure => 'Extra security';

  @override
  String get acctBenefitSecureDesc =>
      'Your vault is encrypted with a key derived from your phrase — only you can unlock it.';

  @override
  String get acctBenefitOffline => 'Works offline';

  @override
  String get acctBenefitOfflineDesc =>
      'No internet or server needed. Your phrase is the only backup you need.';

  @override
  String get acctNoServerNote =>
      'LifeOS never stores your phrase or data on any server. Everything stays on your phone.';

  @override
  String get acctCreateButton => 'Create account';

  @override
  String get acctRecoverExisting => 'I have a recovery phrase';

  @override
  String get acctRecoveryPhrase => 'Your Recovery Phrase';

  @override
  String get acctCopyPhrase => 'Copy phrase';

  @override
  String get acctPhraseCopied => 'Phrase copied to clipboard';

  @override
  String get acctPhraseWarning =>
      'Write this phrase down and store it safely. If you lose it, you cannot recover your account.';

  @override
  String get acctPhraseInstruction =>
      'These 12 words are your recovery phrase. Write them down in order and keep them in a safe place.';

  @override
  String get acctPhraseTips => 'Tips for keeping it safe';

  @override
  String get acctPhraseTip1 =>
      'Write it on paper and store it somewhere secure';

  @override
  String get acctPhraseTip2 => 'Never share it with anyone';

  @override
  String get acctPhraseTip3 => 'Don\'t store it in photos or notes apps';

  @override
  String get acctPhraseConfirmLabel => 'I have written down my recovery phrase';

  @override
  String get acctPhraseVerify => 'Verify phrase';

  @override
  String get acctVerifyTitle => 'Verify Phrase';

  @override
  String get acctVerifyInstruction =>
      'Enter the words from your recovery phrase to verify you wrote it down correctly.';

  @override
  String acctVerifyWordN(String n) {
    return 'Word #$n';
  }

  @override
  String get acctVerifyWordHint => 'Enter word';

  @override
  String get acctVerifyFillAll => 'Please fill in all words';

  @override
  String get acctVerifyWrong =>
      'One or more words are incorrect. Check your written phrase and try again.';

  @override
  String get acctVerifyButton => 'Create account';

  @override
  String get acctVerifyGoBack => 'Go back to see phrase';

  @override
  String get acctCreated => 'Account created successfully';

  @override
  String get acctRecoverTitle => 'Recover Account';

  @override
  String get acctRecoverInstruction =>
      'Enter your 12-word recovery phrase to recover your account.';

  @override
  String get acctRecoverFillAll => 'Please enter all 12 words';

  @override
  String get acctRecoverInvalid =>
      'This doesn\'t look like a valid recovery phrase';

  @override
  String get acctRecoverButton => 'Recover account';

  @override
  String get acctRecovered => 'Account recovered successfully';

  @override
  String get acctViewPhraseTitle => 'Recovery Phrase';

  @override
  String get acctViewSecurityNote =>
      'For your security, you need to verify your phrase before viewing it.';

  @override
  String get acctViewInstruction =>
      'Enter your 12-word recovery phrase to confirm you have access.';

  @override
  String get acctViewPhraseHint => 'Enter your 12 words separated by spaces';

  @override
  String get acctViewEnterPhrase => 'Please enter your recovery phrase';

  @override
  String get acctViewWrongPhrase => 'This phrase doesn\'t match the account';

  @override
  String get acctViewVerifyButton => 'Verify';

  @override
  String get acctViewVerified => 'Phrase verified';

  @override
  String get acctViewYourPhrase =>
      'This is your recovery phrase. Keep it safe!';

  @override
  String get acctSettingsTitle => 'Account';

  @override
  String get acctSettingsNoAccount => 'No account created';

  @override
  String get acctSettingsNoAccountSub => 'Create an account to enable recovery';

  @override
  String get acctSettingsHasAccount => 'Account active';

  @override
  String get acctSettingsHasAccountSub =>
      'Your data can be recovered with your phrase';

  @override
  String get acctSettingsViewPhrase => 'View recovery phrase';
}

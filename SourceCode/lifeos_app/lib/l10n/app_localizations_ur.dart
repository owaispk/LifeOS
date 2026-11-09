// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get amount => 'رقم';

  @override
  String get appLock => 'ایپ لاک';

  @override
  String get appLockSub => 'LifeOS کھولنے کے لیے فنگرپرنٹ، چہرہ یا پن';

  @override
  String get atcAdd => 'شامل کریں';

  @override
  String get atcAmountOptional => 'رقم (اختیاری)';

  @override
  String atcCadenceDay(String cycle, String day) {
    return '$cycle · $day';
  }

  @override
  String atcCadenceWindow(String from, String to) {
    return '~$from–$to ماہانہ';
  }

  @override
  String get atcCreateAuto => 'کام خود بخود بنائیں';

  @override
  String atcCreatedThisMonth(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n کام',
      one: '1 کام',
    );
    return '⚡ ATC نے اس ماہ آپ کے لیے $_temp0 بنائے';
  }

  @override
  String atcDays(String n) {
    return '$n دن';
  }

  @override
  String get atcDelete => 'حذف کریں';

  @override
  String get atcDeleteBody =>
      'کوئی نیا کام نہیں بنے گا۔ پہلے سے بنے کام آپ کی فہرست میں رہیں گے۔';

  @override
  String get atcDeleteRule => 'اصول حذف کریں';

  @override
  String atcDeleteTitle(String name) {
    return '\"$name\" حذف کریں؟';
  }

  @override
  String get atcDueDates => 'آخری تاریخیں (اختیاری — ورنہ ہر 6 ماہ)';

  @override
  String get atcDueDay => 'آخری دن';

  @override
  String get atcEmptyAction => '➕ ادائیگی شامل کریں';

  @override
  String get atcEmptyBody =>
      'ایک بار بتا دیں کہ آپ باقاعدگی سے کیا ادا کرتے ہیں — کرایہ، فیس، بل — اور یہ ہر ماہ یاد دہانیاں بنا دے گا۔';

  @override
  String get atcEmptyTitle => 'LifeOS کو اپنی ادائیگیاں یاد رکھنے دیں';

  @override
  String get atcEnded => 'ختم';

  @override
  String get atcEvery6Months => 'ہر 6 ماہ';

  @override
  String get atcFeeChanged => 'فیس بدل گئی';

  @override
  String atcFeeDecreasedMsg(String oldAmount, String newAmount) {
    return 'فیس $oldAmount سے کم ہو کر $newAmount ہو گئی۔ آئندہ کے کام اپ ڈیٹ کریں؟';
  }

  @override
  String get atcFeeIncreased => 'فیس بڑھ گئی';

  @override
  String atcFeeIncreasedMsg(String oldAmount, String newAmount) {
    return 'فیس $oldAmount سے بڑھ کر $newAmount ہو گئی۔ آئندہ کے کام اپ ڈیٹ کریں؟';
  }

  @override
  String get atcFewerDays => 'کم دن';

  @override
  String get atcFor => 'کس کے لیے';

  @override
  String atcFreeLimit(String n) {
    return 'مفت پلان میں $n خودکار اصول ہیں — پریمیم میں کوئی حد نہیں';
  }

  @override
  String get atcGroupAppointments => 'ملاقاتیں';

  @override
  String get atcGroupBills => 'بل';

  @override
  String get atcGroupFees => 'فیس';

  @override
  String get atcGroupFixed => 'مقررہ';

  @override
  String atcHistory(int n, String paid) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n کام',
      one: '1 کام',
    );
    return '$_temp0 بنائے · $paid وقت پر ادا';
  }

  @override
  String get atcHousehold => 'گھرانہ';

  @override
  String get atcHowOften => 'کتنی بار';

  @override
  String get atcIllScan => 'میں اسکین کروں گا';

  @override
  String atcInstallments(String done, String total) {
    return '$total میں سے $done ادا';
  }

  @override
  String get atcInstallmentsTotal => 'کل کتنی اقساط';

  @override
  String get atcKeepAsIs => 'جیسا ہے رہنے دیں';

  @override
  String atcMissedBill(String label) {
    return 'اس ماہ $label کا بل نہیں آیا — کیا یہ رہ گیا، یا یہ یاد دہانی روک دوں؟';
  }

  @override
  String get atcMonthly => 'ماہانہ';

  @override
  String get atcMoreDays => 'زیادہ دن';

  @override
  String get atcNewPattern => 'نیا معمول ملا';

  @override
  String atcNext(String day) {
    return 'اگلا $day';
  }

  @override
  String get atcNoThanks => 'نہیں شکریہ';

  @override
  String get atcNotNow => 'ابھی نہیں';

  @override
  String atcOnSetDates(String dates) {
    return 'مقررہ تاریخوں پر · $dates';
  }

  @override
  String get atcOnce => 'ایک بار';

  @override
  String get atcPause => 'روکیں';

  @override
  String get atcPaused => 'رکا ہوا';

  @override
  String get atcPickDates => 'تاریخیں چنیں';

  @override
  String get atcPresetCustom => 'دیگر';

  @override
  String get atcPresetFees => 'اسکول فیس';

  @override
  String get atcPresetInstallment => 'قسط / کمیٹی';

  @override
  String get atcPresetInternet => 'انٹرنیٹ';

  @override
  String get atcPresetMobile => 'موبائل';

  @override
  String get atcPresetRent => 'کرایہ';

  @override
  String get atcPresetSubscription => 'سبسکرپشن';

  @override
  String get atcPresetUtility => 'یوٹیلیٹی بل';

  @override
  String atcProposalBill(String label, String when) {
    return 'آپ کا $label بل$when۔ ماہانہ یاد دہانی بنائیں؟';
  }

  @override
  String atcProposalDue(String day) {
    return '، آخری تاریخ $day';
  }

  @override
  String atcProposalFee(String who, String amount, String day) {
    return 'فیس کی یاد دہانی بنائیں$who$amount$day؟';
  }

  @override
  String atcProposalFor(String name) {
    return ' ($name کے لیے)';
  }

  @override
  String atcProposalWindow(String from, String to) {
    return ' عموماً $from–$to تاریخ کو آتا ہے';
  }

  @override
  String get atcProposed => 'تجویز شدہ';

  @override
  String get atcQuarterly => 'سہ ماہی';

  @override
  String get atcRemindBefore => 'پہلے یاد دلائیں';

  @override
  String get atcReminderOn => '⚡ خودکار یاد دہانی آن ہے';

  @override
  String get atcRsPrefix => 'Rs ';

  @override
  String get atcRuleGone => 'یہ اصول موجود نہیں';

  @override
  String get atcRuleGoneBody =>
      'یہ حذف ہو گیا۔ اس کے بنائے کام اب بھی کاموں میں ہیں۔';

  @override
  String get atcSaveChanges => 'تبدیلیاں محفوظ کریں';

  @override
  String get atcSavedNewTasks => 'محفوظ — نئے کاموں پر لاگو ہوگا';

  @override
  String get atcSeePremium => 'پریمیم دیکھیں';

  @override
  String get atcSkipMonths => 'یہ مہینے چھوڑ دیں';

  @override
  String get atcStatusOn => 'آن';

  @override
  String get atcStatusPaused => 'رکا ہوا — کوئی نیا کام نہیں';

  @override
  String get atcTitle => 'خودکار کام';

  @override
  String get atcTurnOn => '⚡ خودکار یاد دہانی آن کریں';

  @override
  String get atcUpdateFuture => 'آئندہ کے کام اپ ڈیٹ کریں';

  @override
  String atcUpgradeBody(String n) {
    return 'مفت پلان میں $n خودکار اصول ہیں — پریمیم میں کوئی حد نہیں۔';
  }

  @override
  String get atcUpgradeTitle => 'پریمیم لیں';

  @override
  String get atcUtility => 'یوٹیلیٹی';

  @override
  String get atcWaitingOk => 'آپ کی منظوری کا انتظار';

  @override
  String get atcWhatPay => 'آپ باقاعدگی سے کیا ادا کرتے ہیں؟';

  @override
  String get atcYearly => 'سالانہ';

  @override
  String get atcYesRemind => 'ہاں، یاد دلائیں';

  @override
  String get autoLock => 'پس منظر میں اتنی دیر بعد لاک';

  @override
  String autoLockMinutes(String n) {
    return '$n منٹ';
  }

  @override
  String get autoReminderOn => '⚡ خودکار یاد دہانی آن';

  @override
  String get cancel => 'منسوخ';

  @override
  String get continueLabel => 'جاری رکھیں';

  @override
  String get cpBelongsTo => 'کس کا ہے';

  @override
  String get cpBillTaskUpdated => '⚡ بل کا کام اپ ڈیٹ ہو گیا';

  @override
  String get cpBlurryBody =>
      'تصویر واضح نہیں — بعد میں متن پڑھنا مشکل ہو سکتا ہے۔';

  @override
  String get cpDiscardNew => 'نئی ہٹا دیں';

  @override
  String get cpDiscardThis => 'اسے ہٹا دیں';

  @override
  String cpDuplicateBody(String title) {
    return 'یہ \'$title\' کی دہری کاپی لگتی ہے۔ دونوں رکھیں؟';
  }

  @override
  String get cpDuplicateDiscarded => 'دہری کاپی ہٹا دی گئی';

  @override
  String get cpDuplicateTitle => 'ممکنہ دہری کاپی';

  @override
  String get cpFieldBillingMonth => 'بل کا مہینہ';

  @override
  String get cpFieldDoctor => 'ڈاکٹر';

  @override
  String get cpFieldDueDate => 'آخری تاریخ';

  @override
  String get cpFieldEndDate => 'اختتام کی تاریخ';

  @override
  String get cpFieldExpiryDate => 'میعاد ختم ہونے کی تاریخ';

  @override
  String get cpFieldInstitution => 'ادارہ';

  @override
  String get cpFieldIssueDate => 'اجرا کی تاریخ';

  @override
  String get cpFieldIssuer => 'جاری کنندہ';

  @override
  String get cpFieldNumber => 'نمبر';

  @override
  String get cpFieldProduct => 'پروڈکٹ';

  @override
  String get cpFieldRefNumber => 'حوالہ نمبر';

  @override
  String get cpFieldStartDate => 'شروع کی تاریخ';

  @override
  String get cpFieldStudent => 'طالب علم';

  @override
  String get cpFolder => 'فولڈر';

  @override
  String get cpImportFile => 'فائل شامل کریں';

  @override
  String get cpJpeg => 'JPEG';

  @override
  String get cpKeepAnyway => 'پھر بھی رکھیں';

  @override
  String get cpKeepBoth => 'دونوں رکھیں';

  @override
  String get cpNobody => 'کسی کا نہیں';

  @override
  String get cpNotSure => 'یقین نہیں یہ کیا ہے — براہ کرم قسم منتخب کریں۔';

  @override
  String get cpNothingLeft => 'محفوظ کرنے کو کچھ باقی نہیں';

  @override
  String cpPages(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n صفحات',
      one: '1 صفحہ',
    );
    return '$_temp0';
  }

  @override
  String get cpPdf => 'PDF';

  @override
  String get cpPdfTitle => 'LifeOS اسکین';

  @override
  String get cpPickType => 'قسم منتخب کریں';

  @override
  String get cpReading => 'دستاویز پڑھی جا رہی ہے…';

  @override
  String get cpRetake => 'دوبارہ لیں';

  @override
  String get cpRetakeTitle => 'دوبارہ لیں؟';

  @override
  String get cpRsPrefix => 'Rs ';

  @override
  String get cpSaveAs => 'اس طرح محفوظ کریں';

  @override
  String get cpSaveToVault => 'والٹ میں محفوظ کریں';

  @override
  String cpSaveToVaultOf(String total) {
    return 'والٹ میں محفوظ کریں · $total میں سے 1';
  }

  @override
  String get cpSavedToVault => 'والٹ میں محفوظ ہو گیا';

  @override
  String get cpScanAnother => 'ایک اور اسکین کریں';

  @override
  String get cpScanAnyway => 'پھر بھی اسکین کریں';

  @override
  String cpScanTitle(String date, String year) {
    return 'اسکین · $date $year';
  }

  @override
  String cpStorageFullBody(String mb) {
    return 'صرف $mb MB خالی ہے۔ اسکین شاید محفوظ نہ ہوں — پہلے کچھ جگہ خالی کریں، یا پھر بھی اسکین کریں۔';
  }

  @override
  String get cpStorageFullTitle => 'اسٹوریج تقریباً بھر گئی ہے';

  @override
  String get cpTypeAgreement => 'معاہدہ';

  @override
  String get cpTypeBill => 'بل';

  @override
  String get cpTypeCertificate => 'سرٹیفکیٹ';

  @override
  String get cpTypeCnic => 'شناختی کارڈ';

  @override
  String cpTypeConfidence(String type, String percent) {
    return '$type · $percent%';
  }

  @override
  String get cpTypeDegree => 'ڈگری';

  @override
  String get cpTypeFeeVoucher => 'فیس واؤچر';

  @override
  String get cpTypeLicense => 'ڈرائیونگ لائسنس';

  @override
  String get cpTypeOther => 'دستاویز';

  @override
  String get cpTypePassport => 'پاسپورٹ';

  @override
  String get cpTypePolicy => 'انشورنس پالیسی';

  @override
  String get cpTypePrescription => 'نسخہ';

  @override
  String get cpTypeReceipt => 'رسید';

  @override
  String get cpTypeReport => 'لیب رپورٹ';

  @override
  String get cpTypeVisa => 'ویزا';

  @override
  String get cpTypeWarranty => 'وارنٹی';

  @override
  String get cpUnfiled => '📥 بغیر فولڈر';

  @override
  String get cpUnreadable =>
      'کوئی متن نہیں پڑھا جا سکا — غیر درجہ بند کے طور پر محفوظ ہوگا۔ چاہیں تو قسم منتخب کریں۔';

  @override
  String get cpUnusualBill => 'بل معمول سے زیادہ ہے ⚠';

  @override
  String get create => 'بنائیں';

  @override
  String get dayOfMonth => 'مہینے کا دن';

  @override
  String get deleteAll => 'تمام مقامی ڈیٹا حذف کریں';

  @override
  String get deleteAllBody =>
      'اس فون پر تمام دستاویزات، کام، ادائیگیاں اور چابیاں حذف ہو جائیں گی۔ یہ واپس نہیں ہو سکتا۔';

  @override
  String get deleteAllConfirmHint => 'DELETE';

  @override
  String get deleteAllConfirmTitle => 'تصدیق کے لیے DELETE لکھیں';

  @override
  String get deleteAllSub => 'اس فون سے سب کچھ ہٹا دیتا ہے';

  @override
  String get deleteAllTitle => 'سب کچھ حذف کریں؟';

  @override
  String get deleteForever => 'ہمیشہ کے لیے حذف';

  @override
  String get dgClear => 'لاگز صاف کریں';

  @override
  String get dgCleared => 'لاگز صاف ہو گئے';

  @override
  String dgCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n اندراجات',
      one: '1 اندراج',
    );
    return '$_temp0';
  }

  @override
  String get dgEmpty => 'ابھی کچھ درج نہیں ہوا';

  @override
  String get dgEntry => 'تشخیص اور لاگز';

  @override
  String get dgEntrySub => 'ٹیسٹنگ کے لیے: ایپ کا لاگ دیکھیں اور شیئر کریں';

  @override
  String dgErrorsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n خرابیاں',
      one: '1 خرابی',
      zero: 'کوئی خرابی نہیں',
    );
    return '$_temp0';
  }

  @override
  String get dgErrorsOnly => 'صرف خرابیاں';

  @override
  String get dgPrivacy =>
      'لاگ اسی فون پر رہتا ہے اور اس میں ذاتی معلومات نہیں۔ صرف شیئر دبانے پر بھیجا جاتا ہے۔';

  @override
  String get dgShare => 'لاگز شیئر کریں';

  @override
  String get dgTestError => 'ٹیسٹ خرابی درج کریں';

  @override
  String get dgTestErrorText => 'تشخیص سے ٹیسٹ خرابی درج کی گئی';

  @override
  String get dgTitle => 'تشخیص';

  @override
  String digestBills(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n بل واجب',
      one: '1 بل واجب',
      zero: 'کوئی بل واجب نہیں',
    );
    return '$_temp0';
  }

  @override
  String digestBody(String score, String tasks, String bills) {
    return 'لائف اسکور $score · $tasks · $bills';
  }

  @override
  String digestTasks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n کام',
      one: '1 کام',
      zero: 'کوئی کام نہیں',
    );
    return '$_temp0';
  }

  @override
  String get digestTime => 'صبح کا خلاصہ';

  @override
  String get domainHealth => 'صحت';

  @override
  String get domainMind => 'کام';

  @override
  String get domainMoney => 'پیسے';

  @override
  String get domainPeople => 'لوگ';

  @override
  String get domainSoul => 'روح';

  @override
  String get domainVault => 'دستاویزات';

  @override
  String get domainWork => 'کام کاج';

  @override
  String get exportData => 'سب کچھ ایکسپورٹ کریں';

  @override
  String get exportDataSub => 'دستاویزات اور ڈیٹا کی ZIP فائل';

  @override
  String exportDone(String docs) {
    return 'ایکسپورٹ تیار: $docs دستاویزات';
  }

  @override
  String get exporting => 'ایکسپورٹ تیار ہو رہی ہے…';

  @override
  String get freeLimitReached =>
      'مفت پلان میں 3 خودکار اصول — پریمیم میں کوئی حد نہیں';

  @override
  String get hmAddTask => '➕ کام شامل کریں';

  @override
  String get hmAllClear => 'آج سب ٹھیک ہے ✓';

  @override
  String get hmAttentionSection => '⚠ توجہ طلب';

  @override
  String get hmClearDay => 'آج کا دن خالی ہے۔';

  @override
  String hmDueIn(String n) {
    return '$n دن میں واجب';
  }

  @override
  String get hmDueToday => 'آج واجب';

  @override
  String get hmDueTomorrow => 'کل واجب';

  @override
  String hmExpiredAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n دن پہلے ختم ہو گئی',
      one: '1 دن پہلے ختم ہو گئی',
    );
    return '$_temp0';
  }

  @override
  String hmExpiresIn(String n) {
    return '$n دن میں ختم';
  }

  @override
  String get hmExpiresToday => 'آج ختم ہو رہی ہے';

  @override
  String get hmExpiresTomorrow => 'کل ختم ہو رہی ہے';

  @override
  String get hmNeedsAttention => 'توجہ طلب';

  @override
  String get hmNoPaymentsWeek => 'اس ہفتے کوئی ادائیگی واجب نہیں';

  @override
  String get hmNothingUrgent => 'کچھ فوری نہیں';

  @override
  String get hmNothingUrgentBody =>
      'جلد واجب ادائیگیاں اور ختم ہونے والی دستاویزات یہاں نظر آتی ہیں۔';

  @override
  String get hmNothingUrgentNice => 'کچھ فوری نہیں — زبردست ✓';

  @override
  String get hmPaid => 'ادا ہو گیا';

  @override
  String hmPaymentsWeek(String amount) {
    return 'اس ہفتے $amount کی ادائیگیاں';
  }

  @override
  String get hmProfileMore => 'پروفائل اور مزید';

  @override
  String get hmPromptAtcBody => 'کرایہ، فیس، بل: ہر مہینے خودکار یاد دہانی۔';

  @override
  String get hmPromptAtcTitle => 'باقاعدہ ادائیگیاں شامل کریں ⚡';

  @override
  String get hmPromptScanBody =>
      'شناختی کارڈ، پاسپورٹ، بل — LifeOS اسے محفوظ کرتا ہے اور یاد دلاتا ہے۔';

  @override
  String get hmPromptScanTitle => 'اپنی پہلی دستاویز اسکین کریں 📸';

  @override
  String get hmPromptTaskBody => 'جو بھی ذہن میں ہو، یاد دہانی کے ساتھ۔';

  @override
  String get hmPromptTaskTitle => 'کام شامل کریں ➕';

  @override
  String get hmGreetMorning => 'صبح بخیر ☀️';

  @override
  String hmGreetMorningName(String name) {
    return 'صبح بخیر، $name ☀️';
  }

  @override
  String get hmGreetAfternoon => 'دوپہر بخیر 👋';

  @override
  String hmGreetAfternoonName(String name) {
    return 'دوپہر بخیر، $name 👋';
  }

  @override
  String get hmGreetEvening => 'شام بخیر 🌆';

  @override
  String hmGreetEveningName(String name) {
    return 'شام بخیر، $name 🌆';
  }

  @override
  String get hmGreetNight => 'ابھی تک جاگ رہے ہیں؟ 🌙';

  @override
  String hmGreetNightName(String name) {
    return 'ابھی تک جاگ رہے ہیں، $name؟ 🌙';
  }

  @override
  String get hmGreetSalam => 'السلام علیکم 👋';

  @override
  String hmGreetSalamName(String name) {
    return 'السلام علیکم، $name 👋';
  }

  @override
  String get hmGreetNamaste => 'نمستے 🙏';

  @override
  String hmGreetNamasteName(String name) {
    return 'نمستے، $name 🙏';
  }

  @override
  String get hmGreetHello => 'ہیلو 👋';

  @override
  String hmGreetHelloName(String name) {
    return 'ہیلو، $name 👋';
  }

  @override
  String hmGreetCustom(String greeting) {
    return '$greeting 👋';
  }

  @override
  String hmGreetCustomName(String greeting, String name) {
    return '$greeting، $name 👋';
  }

  @override
  String get setGreeting => 'سلام کا انداز';

  @override
  String get setGreetingAuto => 'خودکار — وقت کے مطابق';

  @override
  String get setGreetingSalam => 'السلام علیکم';

  @override
  String get setGreetingNamaste => 'نمستے';

  @override
  String get setGreetingHello => 'ہیلو';

  @override
  String get setGreetingCustom => 'اپنی مرضی…';

  @override
  String get setGreetingCustomHint => 'آپ کا سلام، مثلاً Shalom';

  @override
  String hmSeeAllCount(String n) {
    return 'سب دیکھیں ($n)';
  }

  @override
  String hmSeeAllN(String n) {
    return 'تمام $n دیکھیں';
  }

  @override
  String get hmSoon => 'جلد';

  @override
  String hmThingsNeedAttention(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n چیزیں توجہ چاہتی ہیں',
      one: '1 چیز توجہ چاہتی ہے',
    );
    return '$_temp0';
  }

  @override
  String hmTodayTasks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n کام',
      one: '1 کام',
    );
    return 'آج · $_temp0';
  }

  @override
  String get hmUrgent => 'فوری';

  @override
  String hmWasDueAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n دن پہلے واجب تھی',
      one: '1 دن پہلے واجب تھی',
    );
    return '$_temp0';
  }

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUrdu => 'اردو';

  @override
  String get lockUnavailable =>
      'اسے استعمال کرنے کے لیے فون پر اسکرین لاک لگائیں';

  @override
  String get lockedTitle => 'LifeOS لاک ہے';

  @override
  String get lookTemplate => 'انداز';

  @override
  String get mnAdd => 'شامل کریں';

  @override
  String get mnAddExpense => 'خرچ شامل کریں';

  @override
  String get mnAddExpenseAction => '💸 خرچ شامل کریں';

  @override
  String get mnAddSalary => 'حصہ دیکھنے کے لیے اپنی تنخواہ درج کریں';

  @override
  String get mnAmountError => '0 سے زیادہ رقم درج کریں';

  @override
  String get mnAmountPaid => 'ادا کی گئی رقم';

  @override
  String get mnAmountPending => 'رقم باقی ہے';

  @override
  String get mnAttachReceipt => '📎 رسید لگائیں؟';

  @override
  String mnBreakdownItem(String name, String amount, String percent) {
    return '$name $amount، $percent فیصد';
  }

  @override
  String mnBreakdownSemantics(String items) {
    return 'زمرہ وار خرچ: $items';
  }

  @override
  String get mnCatFees => 'فیس اور ٹیوشن';

  @override
  String get mnCatInstallment => 'اقساط';

  @override
  String get mnCatInternet => 'انٹرنیٹ';

  @override
  String get mnCatMobile => 'موبائل';

  @override
  String get mnCatOther => 'دیگر';

  @override
  String get mnCatRent => 'کرایہ';

  @override
  String get mnCatSubscription => 'سبسکرپشنز';

  @override
  String get mnCatUtilities => 'یوٹیلٹی بل';

  @override
  String get mnCategory => 'زمرہ';

  @override
  String get mnChangeSalary => 'تنخواہ تبدیل کریں';

  @override
  String get mnDate => 'تاریخ';

  @override
  String get mnDelete => 'حذف کریں';

  @override
  String mnDeltaNew(String month) {
    return 'نیا · $month میں کچھ نہیں';
  }

  @override
  String mnDeltaSame(String month) {
    return '$month جتنا';
  }

  @override
  String mnDeltaVs(String percent, String month) {
    return '$month کے مقابلے میں $percent%';
  }

  @override
  String mnDigest(String month, String total, int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n مدات',
      one: '1 مد',
    );
    return '$month کی مقررہ ادائیگیاں: $total، $_temp0';
  }

  @override
  String get mnEditExpense => 'خرچ میں ترمیم';

  @override
  String mnExpensesCount(String n) {
    return 'اخراجات · $n';
  }

  @override
  String get mnFiledInVault => 'والٹ میں محفوظ';

  @override
  String get mnForecast => 'پیشگوئی';

  @override
  String get mnImport => 'درآمد';

  @override
  String get mnLinkedNote => '⚡ ادائیگی سے درج';

  @override
  String get mnLoggedFromPayment => 'ادائیگی سے درج';

  @override
  String get mnLoggedInMoney => 'پیسوں میں درج';

  @override
  String get mnMarkPaid => 'ادا شدہ کریں';

  @override
  String get mnMonthlySalary => 'ماہانہ تنخواہ';

  @override
  String get mnNextMonth => 'اگلا مہینہ';

  @override
  String get mnNoExpensesBody => 'ادا شدہ بل اور فوری خرچ یہاں جمع ہوں گے۔';

  @override
  String mnNoExpensesIn(String month) {
    return '$month میں کوئی خرچ نہیں';
  }

  @override
  String get mnNoFixedBody =>
      'جو آپ باقاعدگی سے ادا کرتے ہیں وہ مزید → خودکار کام میں شامل کریں، پیشگوئی خود بھر جائے گی۔';

  @override
  String get mnNoFixedTitle => 'اس مہینے کوئی مقررہ ادائیگی نہیں';

  @override
  String get mnNoteHint => 'نوٹ (اختیاری)';

  @override
  String get mnOverview => 'خلاصہ';

  @override
  String mnPaidAmountLine(String title, String amount) {
    return '✓ $title — $amount ادا ہو گئے';
  }

  @override
  String get mnPaidDone => '✓ ادا ہو گیا';

  @override
  String mnPaidHowMuch(String title) {
    return '✓ $title — آپ نے کتنا ادا کیا؟';
  }

  @override
  String get mnPaidOnDay => 'ادائیگی کا دن';

  @override
  String get mnPrevMonth => 'پچھلا مہینہ';

  @override
  String get mnReceiptAttached => 'رسید منسلک ہے';

  @override
  String mnReceiptTitle(String title) {
    return 'رسید — $title';
  }

  @override
  String get mnRsPrefix => 'Rs ';

  @override
  String mnSalaryShare(String percent) {
    return 'آمدنی کا $percent% مقررہ ادائیگیوں میں جاتا ہے';
  }

  @override
  String get mnSave => 'محفوظ کریں';

  @override
  String get mnScan => 'اسکین';

  @override
  String get mnSpendingByCategory => 'زمرہ وار خرچ';

  @override
  String get mnSpent => 'خرچ';

  @override
  String get mnStatusOverdue => 'تاریخ گزر گئی 🔴';

  @override
  String get mnStatusPaid => 'ادا ✓';

  @override
  String get mnStatusUpcoming => 'آنے والی';

  @override
  String get mnStatusUpcomingPlanned => 'آنے والی · منصوبہ';

  @override
  String get mnTitle => 'پیسے';

  @override
  String mnTotals(String total, String paid, String remaining) {
    return 'کل $total · ادا $paid · باقی $remaining';
  }

  @override
  String get mnUnavailableBody => 'اس ڈیوائس پر مقامی ڈیٹا نہیں کھل سکا۔';

  @override
  String get mnUnavailableTitle => 'پیسوں کا حصہ دستیاب نہیں';

  @override
  String get mnUncategorised => 'بغیر زمرہ';

  @override
  String get mnUndo => 'واپس کریں';

  @override
  String get mnYourSalary => 'آپ کی تنخواہ';

  @override
  String get mon1 => 'جنوری';

  @override
  String get mon10 => 'اکتوبر';

  @override
  String get mon11 => 'نومبر';

  @override
  String get mon12 => 'دسمبر';

  @override
  String get mon2 => 'فروری';

  @override
  String get mon3 => 'مارچ';

  @override
  String get mon4 => 'اپریل';

  @override
  String get mon5 => 'مئی';

  @override
  String get mon6 => 'جون';

  @override
  String get mon7 => 'جولائی';

  @override
  String get mon8 => 'اگست';

  @override
  String get mon9 => 'ستمبر';

  @override
  String get month1 => 'جنوری';

  @override
  String get month10 => 'اکتوبر';

  @override
  String get month11 => 'نومبر';

  @override
  String get month12 => 'دسمبر';

  @override
  String get month2 => 'فروری';

  @override
  String get month3 => 'مارچ';

  @override
  String get month4 => 'اپریل';

  @override
  String get month5 => 'مئی';

  @override
  String get month6 => 'جون';

  @override
  String get month7 => 'جولائی';

  @override
  String get month8 => 'اگست';

  @override
  String get month9 => 'ستمبر';

  @override
  String get moreSettings => 'سیٹنگز';

  @override
  String get moreSettingsSub => 'سیکیورٹی، اطلاعات، زبان، ڈیٹا';

  @override
  String get mrAutoTasks => 'خودکار کام';

  @override
  String get mrAutoTasksSub => 'اصول جو آپ کے لیے ادائیگی کے کام بناتے ہیں';

  @override
  String get mrTitle => 'مزید';

  @override
  String get mrTrashSub => 'حذف شدہ دستاویزات، 30 دن تک محفوظ';

  @override
  String get name => 'نام';

  @override
  String get next => 'اگلا';

  @override
  String get notifyAbout => 'مجھے اطلاع دیں';

  @override
  String get obDoneTitle => 'سب تیار ہے';

  @override
  String obForecast(String month, String total) {
    return '$month کی مقررہ ادائیگیاں: $total';
  }

  @override
  String get obForecastNone =>
      'ادائیگیاں کبھی بھی مزید ← خودکار کام سے شامل کریں۔';

  @override
  String get obNotifAsk => 'ہم مقررہ وقت سے پہلے یاد دلائیں گے۔';

  @override
  String get obPayBody =>
      'ایک چنیں، رقم اور دن لکھیں۔ LifeOS ہر مہینے یاد دلائے گا۔';

  @override
  String get obPayTitle => 'آپ ہر مہینے کیا ادا کرتے ہیں؟';

  @override
  String get obRoleQ => 'آپ کس کے لیے ترتیب دے رہے ہیں؟';

  @override
  String get obScanBody =>
      'شناختی کارڈ، پاسپورٹ یا بل۔ LifeOS اسے پڑھ کر خود ترتیب دیتا ہے۔';

  @override
  String get obScanNow => '📸 ابھی اسکین کریں';

  @override
  String get obScanTitle => 'اپنی پہلی دستاویز اسکین کریں';

  @override
  String get obSeeDashboard => 'میرا ڈیش بورڈ دیکھیں';

  @override
  String get obWelcome => 'LifeOS میں خوش آمدید';

  @override
  String get parseHigh => 'اہم';

  @override
  String get payCustom => 'دیگر';

  @override
  String get payElectricity => 'بجلی';

  @override
  String get payGas => 'گیس';

  @override
  String get payInstallment => 'قسط';

  @override
  String get payInternet => 'انٹرنیٹ';

  @override
  String get payMobile => 'موبائل';

  @override
  String get payRent => 'کرایہ';

  @override
  String get paySchoolFee => 'اسکول فیس';

  @override
  String get quietHours => 'خاموش اوقات';

  @override
  String quietHoursValue(String from, String to) {
    return '$from – $to';
  }

  @override
  String removeChip(String what) {
    return '$what ہٹائیں';
  }

  @override
  String get roleBusiness => 'کاروباری';

  @override
  String get roleJustMe => 'صرف میں';

  @override
  String get roleParent => 'والدین';

  @override
  String get roleProfessional => 'پیشہ ور';

  @override
  String get roleStudent => 'طالب علم';

  @override
  String get scCompBalance => 'توازن';

  @override
  String get scCompDocuments => 'دستاویزات';

  @override
  String get scCompHealth => 'صحت';

  @override
  String get scCompPayments => 'ادائیگیاں';

  @override
  String get scCompPeople => 'لوگ';

  @override
  String get scCompTasks => 'کام';

  @override
  String scComponentSemantics(String name, String pct, String weight) {
    return '$name: $pct فیصد، اسکور کا $weight فیصد';
  }

  @override
  String scComponentValue(String pct, String weight) {
    return '$pct% · $weight پوائنٹس';
  }

  @override
  String get scDay1 => 'پ';

  @override
  String get scDay2 => 'م';

  @override
  String get scDay3 => 'ب';

  @override
  String get scDay4 => 'ج';

  @override
  String get scDay5 => 'ج';

  @override
  String get scDay6 => 'ہ';

  @override
  String get scDay7 => 'ا';

  @override
  String get scDoingWell => 'سب اچھا چل رہا ہے';

  @override
  String scDownSince(String n) {
    return 'کل سے $n کم';
  }

  @override
  String scExpiredAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n دن پہلے ختم ہو گئی',
      one: '1 دن پہلے ختم ہو گئی',
    );
    return '$_temp0';
  }

  @override
  String scExpiresIn(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n دن میں ختم',
      one: '1 دن میں ختم',
    );
    return '$_temp0';
  }

  @override
  String get scExpiresToday => 'آج ختم ہو رہی ہے';

  @override
  String get scFewThings => 'کچھ چیزیں آپ کی منتظر ہیں';

  @override
  String get scHeavyWeek => 'مصروف ہفتہ';

  @override
  String get scLast7 => 'پچھلے 7 دن';

  @override
  String get scLifeScore => 'لائف اسکور';

  @override
  String get scMoveToday => 'آج پر لائیں';

  @override
  String get scMovedToday => 'آج پر منتقل ہو گیا';

  @override
  String get scNothingPulling => 'آج کوئی چیز آپ کا اسکور کم نہیں کر رہی ✓';

  @override
  String get scOpen => 'کھولیں';

  @override
  String scRingSemantics(String score, String label) {
    return 'لائف اسکور $score، $label';
  }

  @override
  String get scSameYesterday => 'کل جتنا';

  @override
  String scShowAll(String n) {
    return 'تمام $n دکھائیں';
  }

  @override
  String scSparkSemantics(String values) {
    return 'پچھلے 7 دن: $values';
  }

  @override
  String get scStillOpen => 'کل سے ابھی باقی ہے';

  @override
  String get scTriageTitle => 'مصروف ہفتہ؟ یہ 3 سب سے مؤثر کام ہیں';

  @override
  String scUpSince(String n) {
    return 'کل سے $n زیادہ';
  }

  @override
  String scWasDue(String date) {
    return '$date کو واجب تھی';
  }

  @override
  String get scWhatWouldLift => 'اسکور کیسے بڑھے';

  @override
  String get scWhatsInIt => 'اس میں کیا شامل ہے';

  @override
  String scWhenSorted(String pts) {
    return 'مکمل ہونے پر +$pts';
  }

  @override
  String get screenshotBlock => 'والٹ میں اسکرین شاٹ بند';

  @override
  String get settingsAppearance => 'ظاہری شکل';

  @override
  String get settingsData => 'ڈیٹا';

  @override
  String get settingsLanguage => 'زبان';

  @override
  String get settingsNotifications => 'اطلاعات';

  @override
  String get settingsPremium => 'پریمیم';

  @override
  String get settingsPremiumSub => 'جلد آ رہا ہے';

  @override
  String get settingsSecurity => 'سیکیورٹی';

  @override
  String get settingsTitle => 'سیٹنگز';

  @override
  String get skip => 'چھوڑیں';

  @override
  String get speak => 'بولیں';

  @override
  String get templateClassic => 'کلاسک · بڑا متن';

  @override
  String get templateFlagship => 'فلیگ شپ';

  @override
  String get templateFunky => 'رنگین';

  @override
  String get themeDark => 'گہرا';

  @override
  String get themeLight => 'روشن';

  @override
  String get themeMode => 'تھیم';

  @override
  String get themeSystem => 'سسٹم';

  @override
  String get tkActionDismiss => 'ہٹائیں';

  @override
  String get tkActionDone => 'مکمل ✓';

  @override
  String get tkActionPaid => 'ادا ہو گیا ✓';

  @override
  String get tkActionRenew => 'تجدید کا کام بنائیں';

  @override
  String get tkAdd => 'شامل کریں';

  @override
  String get tkAddAnyway => 'پھر بھی شامل کریں';

  @override
  String get tkAddNotes => 'نوٹس لکھیں';

  @override
  String get tkAddReminder => 'یاد دہانی شامل کریں';

  @override
  String get tkAddSubtask => 'ذیلی کام شامل کریں';

  @override
  String get tkAddTaskAction => '➕ کام شامل کریں';

  @override
  String get tkAllDay => 'سارا دن';

  @override
  String get tkAnytime => 'کسی بھی وقت';

  @override
  String get tkAutoCreated => 'خودکار بنایا گیا';

  @override
  String get tkCantOpen => 'یہ کام نہیں کھل سکا';

  @override
  String get tkChannelDesc => 'کام، ادائیگی اور دستاویز کی یاد دہانیاں';

  @override
  String get tkChannelName => 'یاد دہانیاں';

  @override
  String get tkCloseQuickActions => 'فوری کام بند کریں';

  @override
  String tkComingSoon(String pbi) {
    return 'جلد آ رہا ہے ($pbi)۔';
  }

  @override
  String get tkCreatedAuto => 'خودکار طور پر بنا';

  @override
  String tkCreatedByRule(String name) {
    return 'اصول سے بنا: $name';
  }

  @override
  String tkCreatedFrom(String title) {
    return 'اس سے بنا: $title';
  }

  @override
  String tkDayFull(String day, String load, String capacity) {
    return '$day پہلے ہی بھرا ہوا ہے ($capacity میں سے $load)';
  }

  @override
  String tkDayLoad(String day, String load) {
    return '$day $load';
  }

  @override
  String tkDayLoadOver(String day, String load) {
    return '$day $load، گنجائش سے زیادہ';
  }

  @override
  String get tkDelete => 'حذف کریں';

  @override
  String tkDeleteBody(String title) {
    return '\"$title\" اور اس کے ذیلی کام ہٹا دیے جائیں گے۔';
  }

  @override
  String get tkDeleteTitle => 'یہ کام حذف کریں؟';

  @override
  String tkDocDue(String date) {
    return 'آخری تاریخ: $date';
  }

  @override
  String tkDocIssuer(String issuer) {
    return 'جاری کنندہ: $issuer';
  }

  @override
  String tkDocType(String type) {
    return 'قسم: $type';
  }

  @override
  String get tkDomainMind => 'ذہن';

  @override
  String get tkDomainVault => 'والٹ';

  @override
  String get tkDomains => 'شعبے';

  @override
  String get tkDone => 'مکمل';

  @override
  String get tkDoneNext => 'مکمل — اگلا طے ہو گیا';

  @override
  String tkDoneTitle(String title) {
    return 'مکمل: $title';
  }

  @override
  String get tkDue => 'آخری تاریخ';

  @override
  String get tkEmptyDomainsBody =>
      'یہاں کام زندگی کے شعبوں کے لحاظ سے ترتیب دیے جاتے ہیں۔';

  @override
  String get tkEmptyDomainsTitle => 'کوئی کھلا کام نہیں';

  @override
  String get tkEmptyTodayBody => 'کام شامل کریں، آج کے لیے یہاں نظر آئے گا۔';

  @override
  String get tkEmptyTodayTitle => 'آج کوئی کام نہیں';

  @override
  String get tkEmptyWeekBody => 'اگلے 7 دنوں میں کچھ واجب نہیں۔';

  @override
  String get tkEmptyWeekTitle => 'اگلا ہفتہ خالی ہے';

  @override
  String tkEveryDay(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'ہر $n دن بعد',
      one: 'روزانہ',
    );
    return '$_temp0';
  }

  @override
  String tkEveryMonth(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'ہر $n مہینے بعد',
      one: 'ہر مہینے',
    );
    return '$_temp0';
  }

  @override
  String tkEveryWeek(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'ہر $n ہفتے بعد',
      one: 'ہر ہفتے',
    );
    return '$_temp0';
  }

  @override
  String get tkFewerOptions => 'کم اختیارات';

  @override
  String get tkFor => 'کس کے لیے';

  @override
  String get tkFull => '⚠ بھرا';

  @override
  String get tkGoneBody => 'اسے حذف یا مکمل کر دیا گیا۔';

  @override
  String get tkGoneTitle => 'یہ کام موجود نہیں';

  @override
  String tkHasRoom(String day) {
    return '$day میں گنجائش ہے۔';
  }

  @override
  String tkHeatDay(String day, String percent) {
    return '$day: $percent فیصد';
  }

  @override
  String tkHeatDayFull(String day, String percent) {
    return '$day: $percent فیصد، بھرا ہوا';
  }

  @override
  String get tkHigh => 'زیادہ';

  @override
  String get tkHighChip => '‼ اہم';

  @override
  String tkHours(String n) {
    return '$n گھنٹے';
  }

  @override
  String get tkLifeArea => 'زندگی کا شعبہ';

  @override
  String get tkLow => 'کم';

  @override
  String tkMarkDone(String title) {
    return '\"$title\" مکمل کریں';
  }

  @override
  String get tkMedium => 'درمیانی';

  @override
  String tkMinutes(String n) {
    return '$n منٹ';
  }

  @override
  String get tkMoreOptions => 'مزید اختیارات';

  @override
  String tkMoveTo(String day) {
    return '$day پر منتقل کریں';
  }

  @override
  String get tkMuteRule => 'یہ اصول روکیں';

  @override
  String get tkNever => 'کبھی نہیں';

  @override
  String get tkNewTask => 'نیا کام';

  @override
  String get tkNoDate => 'کوئی تاریخ نہیں';

  @override
  String get tkNoLighterDay =>
      'اگلے دو ہفتوں میں کوئی ہلکا دن نہیں — دن چنیں یا پھر بھی شامل کریں۔';

  @override
  String get tkNotes => 'نوٹس';

  @override
  String tkNotifDue(String date) {
    return 'آخری تاریخ $date';
  }

  @override
  String tkNotifDueLower(String date) {
    return 'آخری تاریخ $date';
  }

  @override
  String get tkNotifExpiryBody => 'دیکھنے اور تجدید کے لیے ٹیپ کریں';

  @override
  String get tkNotifExpiryTitle => 'ایک دستاویز جلد ختم ہو رہی ہے';

  @override
  String get tkNotifHidden => 'تفصیل کے لیے LifeOS کھولیں';

  @override
  String get tkNotifPaymentTitle => 'ایک ادائیگی واجب ہے';

  @override
  String get tkNotifReminder => 'یاد دہانی';

  @override
  String get tkNotifTaskTitle => 'ایک کام کا وقت ہو گیا';

  @override
  String get tkOffset10m => '10 منٹ پہلے';

  @override
  String get tkOffset1d => '1 دن پہلے';

  @override
  String get tkOffset1h => '1 گھنٹہ پہلے';

  @override
  String get tkOffsetAtDue => 'مقررہ وقت پر';

  @override
  String get tkOverdue => 'تاخیر شدہ';

  @override
  String get tkPayments => 'ادائیگیاں ⚡';

  @override
  String get tkPickDate => 'تاریخ چنیں';

  @override
  String get tkPickDateTime => 'تاریخ اور وقت چنیں';

  @override
  String get tkPickDay => 'دن چنیں';

  @override
  String get tkPickTime => 'وقت چنیں…';

  @override
  String get tkPriority => 'ترجیح';

  @override
  String get tkQaExpense => 'خرچ';

  @override
  String get tkQaExpenseTitle => 'خرچ درج کریں';

  @override
  String get tkQaScan => 'اسکین';

  @override
  String get tkQaScanTitle => 'دستاویز اسکین کریں';

  @override
  String get tkQaTask => 'کام';

  @override
  String get tkQaTaskTitle => 'کام شامل کریں';

  @override
  String get tkQaVoice => 'آواز';

  @override
  String get tkQaVoiceTitle => 'کام بول کر بتائیں';

  @override
  String get tkQuickActions => 'فوری کام';

  @override
  String get tkRemoveDueDate => 'آخری تاریخ ہٹائیں';

  @override
  String get tkRemoveReminder => 'یاد دہانی ہٹائیں';

  @override
  String get tkRemoveSubtask => 'ذیلی کام ہٹائیں';

  @override
  String get tkRenewDocument => 'دستاویز';

  @override
  String tkRenewTitle(String what) {
    return '$what کی تجدید';
  }

  @override
  String get tkRepeat => 'دہرائیں';

  @override
  String get tkRulePaused => 'اصول روک دیا گیا — اس سے نئے کام نہیں بنیں گے';

  @override
  String get tkSkipCycle => 'اس بار چھوڑ دیں';

  @override
  String get tkSnooze => 'بعد میں';

  @override
  String tkSubtasks(String done, String total) {
    return 'ذیلی کام ($done/$total)';
  }

  @override
  String get tkTabHome => 'ہوم';

  @override
  String get tkTabMoney => 'پیسے';

  @override
  String get tkTabMore => 'مزید';

  @override
  String get tkTabVault => 'والٹ';

  @override
  String get tkTakesAbout => 'تقریباً وقت';

  @override
  String get tkTask => 'کام';

  @override
  String get tkTasks => 'کام';

  @override
  String get tkTime => 'وقت';

  @override
  String get tkTimed => 'وقت مقررہ';

  @override
  String get tkTomorrowMorning => 'کل صبح';

  @override
  String tkTomorrowOn(String date) {
    return 'کل · $date';
  }

  @override
  String get tkTonight => 'آج رات';

  @override
  String get tkUnavailableBody => 'اس فون پر مقامی ڈیٹا نہیں کھل سکا۔';

  @override
  String get tkUnavailableTitle => 'کام دستیاب نہیں';

  @override
  String get tkUndo => 'واپس لیں';

  @override
  String get tkUpcoming => 'آنے والے';

  @override
  String tkWeekLoad(String days) {
    return 'ہفتے کا بوجھ: $days';
  }

  @override
  String get tkWeekday1 => 'پیر';

  @override
  String get tkWeekday2 => 'منگل';

  @override
  String get tkWeekday3 => 'بدھ';

  @override
  String get tkWeekday4 => 'جمعرات';

  @override
  String get tkWeekday5 => 'جمعہ';

  @override
  String get tkWeekday6 => 'ہفتہ';

  @override
  String get tkWeekday7 => 'اتوار';

  @override
  String get tkWhatNeedsDoing => 'کیا کرنا ہے؟';

  @override
  String get today => 'آج';

  @override
  String get tomorrow => 'کل';

  @override
  String get trash => 'ردی';

  @override
  String get turnOn => 'آن کریں';

  @override
  String get unlock => 'کھولیں';

  @override
  String get unlockReason => 'LifeOS کھولیں';

  @override
  String get unlockVaultReason => 'اپنا والٹ کھولیں';

  @override
  String get vaultLock => 'والٹ لاک';

  @override
  String get vaultLockSub => 'والٹ کھولنے سے پہلے دوبارہ پوچھیں';

  @override
  String get vaultLockedTitle => 'والٹ لاک ہے';

  @override
  String get voiceHint => 'مثال: \"جمعہ شام 5 بجے بجلی کا بل ادا کریں\"';

  @override
  String get voiceListening => 'سن رہے ہیں…';

  @override
  String get voiceTitle => 'اپنا کام بولیں';

  @override
  String get voiceTryAgain => 'دوبارہ کوشش کریں';

  @override
  String get voiceUnavailable => 'اس فون پر آواز دستیاب نہیں — لکھ دیں';

  @override
  String get vtAdd => 'شامل کریں';

  @override
  String get vtAddFavourite => 'پسندیدہ میں شامل کریں';

  @override
  String get vtAddPerson => 'فرد شامل کریں';

  @override
  String get vtAddTag => 'ٹیگ شامل کریں';

  @override
  String get vtAddTagHint => 'ٹیگ شامل کریں';

  @override
  String get vtAdded => 'شامل کردہ';

  @override
  String get vtAmount => 'رقم';

  @override
  String get vtAnyTime => 'کبھی بھی';

  @override
  String get vtAnyType => 'کوئی بھی قسم';

  @override
  String get vtAnyone => 'کوئی بھی';

  @override
  String get vtArchive => 'محفوظ کریں';

  @override
  String get vtArchived => 'محفوظ شدہ';

  @override
  String get vtBelongsTo => 'کس کی ہے';

  @override
  String get vtClear => 'صاف کریں';

  @override
  String vtClearField(String label) {
    return '$label صاف کریں';
  }

  @override
  String get vtClearSearch => 'تلاش صاف کریں';

  @override
  String vtDaysLeftShort(String n) {
    return '$n دن باقی';
  }

  @override
  String get vtDelete => 'حذف کریں';

  @override
  String vtDeleteDocBody(String title) {
    return '\"$title\" ہٹا دی جائے گی۔';
  }

  @override
  String get vtDeleteDocTitle => 'یہ دستاویز حذف کریں؟';

  @override
  String get vtDeleteFolder => 'فولڈر حذف کریں';

  @override
  String get vtDeleteFolderBody =>
      'اس کی دستاویزات غیر ترتیب شدہ میں چلی جائیں گی — کچھ ضائع نہیں ہوگا۔';

  @override
  String vtDeleteFolderTitle(String name) {
    return '\"$name\" حذف کریں؟';
  }

  @override
  String vtDeleteForeverBody(String title) {
    return '\"$title\" اور اس کی فائلیں اس فون سے ہٹا دی جائیں گی۔ یہ واپس نہیں ہو سکتا۔';
  }

  @override
  String get vtDeleteForeverTitle => 'ہمیشہ کے لیے حذف کریں؟';

  @override
  String get vtDetails => 'تفصیلات';

  @override
  String vtDocCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n دستاویزات',
      one: '1 دستاویز',
    );
    return '$_temp0';
  }

  @override
  String get vtDocGoneMessage =>
      'یہ حذف ہو گئی تھی۔ واپس لانے کے لیے والٹ ← ردی دیکھیں۔';

  @override
  String get vtDocGoneTitle => 'یہ دستاویز موجود نہیں';

  @override
  String get vtDueDate => 'آخری تاریخ';

  @override
  String get vtEdit => 'ترمیم';

  @override
  String get vtEditPerson => 'فرد میں ترمیم';

  @override
  String get vtEmptyMessage => 'یہاں رکھنے کے لیے دستاویز اسکین کریں یا لائیں۔';

  @override
  String get vtEmptyTitle => 'ابھی یہاں کچھ نہیں';

  @override
  String vtExpiredAgo(String n) {
    return '$n دن پہلے ختم';
  }

  @override
  String get vtExpiresToday => 'آج ختم';

  @override
  String get vtExpiringSoon => 'جلد ختم ہونے والی';

  @override
  String vtExpiringSoonCount(String n) {
    return '⏰ جلد ختم ہونے والی ($n)';
  }

  @override
  String get vtExpiryDate => 'میعاد ختم ہونے کی تاریخ';

  @override
  String get vtExpiryPrompt => 'کیا اس دستاویز کی میعاد ختم ہوتی ہے؟';

  @override
  String get vtFavourite => 'پسندیدہ';

  @override
  String get vtFolder => 'فولڈر';

  @override
  String get vtFolderBills => 'بل اور رسیدیں';

  @override
  String get vtFolderEducation => 'تعلیم';

  @override
  String get vtFolderIdentity => 'شناخت';

  @override
  String get vtFolderInsurance => 'انشورنس';

  @override
  String get vtFolderMedical => 'طبی';

  @override
  String get vtFolderName => 'فولڈر کا نام';

  @override
  String get vtFolderOptions => 'فولڈر کے اختیارات';

  @override
  String get vtFolderProperty => 'جائیداد';

  @override
  String get vtFolderVehicles => 'گاڑیاں';

  @override
  String get vtFolderWork => 'کام کاج';

  @override
  String get vtFolders => 'فولڈرز';

  @override
  String get vtImportFiles => 'فائلوں سے لائیں';

  @override
  String get vtIssuer => 'جاری کنندہ';

  @override
  String vtLadderAlerts(String list, String next) {
    return 'یاد دہانیاں: $list\nاگلی: $next';
  }

  @override
  String vtLadderDayAfter(String n) {
    return '$n دن بعد';
  }

  @override
  String vtLadderDaysBefore(String n) {
    return '$n دن پہلے';
  }

  @override
  String get vtLadderExpired => 'میعاد ختم — تجدید تک ہر ہفتے یاد دہانی';

  @override
  String get vtLadderOnDay => 'اسی دن';

  @override
  String get vtLast30Days => 'پچھلے 30 دن';

  @override
  String get vtLinkedTasks => 'منسلک کام';

  @override
  String get vtMarkRenewed => 'تجدید شدہ ← نئی اسکین کریں';

  @override
  String get vtMove => 'منتقل کریں';

  @override
  String get vtMovedToTrash => 'ردی میں منتقل';

  @override
  String get vtNewFolder => 'نیا فولڈر';

  @override
  String get vtNo => 'نہیں';

  @override
  String get vtNoMatches => 'کچھ نہیں ملا';

  @override
  String get vtNoMatchesHint =>
      'عنوان، جاری کنندہ جیسے K-Electric، دستاویز کا کوئی لفظ یا ٹیگ آزمائیں۔';

  @override
  String get vtNoPages => 'اس دستاویز کے کوئی صفحات محفوظ نہیں';

  @override
  String get vtNobody => 'کوئی نہیں';

  @override
  String get vtNotSet => 'مقرر نہیں';

  @override
  String get vtNothingExpiring => 'کچھ ختم نہیں ہو رہا';

  @override
  String get vtNothingExpiringMessage =>
      'اگلے 90 دن میں ختم ہونے والی دستاویزات یہاں نظر آتی ہیں۔';

  @override
  String get vtOwnProfileProtected => 'آپ کی اپنی پروفائل حذف نہیں ہو سکتی';

  @override
  String vtPageOf(String page, String total) {
    return 'صفحہ $page از $total';
  }

  @override
  String get vtPeople => 'لوگ';

  @override
  String get vtPerson => 'فرد';

  @override
  String get vtPersonOptions => 'فرد کے اختیارات';

  @override
  String get vtRefNumber => 'حوالہ / نمبر';

  @override
  String get vtRelationChild => 'بچہ';

  @override
  String get vtRelationOther => 'دیگر';

  @override
  String get vtRelationParent => 'والدین';

  @override
  String get vtRelationSpouse => 'شریکِ حیات';

  @override
  String get vtRemoveFavourite => 'پسندیدہ سے ہٹائیں';

  @override
  String get vtRemovePerson => 'فرد کو ہٹائیں';

  @override
  String get vtRemovePersonBody =>
      'ان کی دستاویزات والٹ میں رہیں گی، کسی کے نام نہیں۔';

  @override
  String vtRemovePersonTitle(String name) {
    return '$name کو ہٹائیں؟';
  }

  @override
  String vtRemoveTag(String tag) {
    return 'ٹیگ $tag ہٹائیں';
  }

  @override
  String get vtRename => 'نام بدلیں';

  @override
  String get vtRenameFolder => 'فولڈر کا نام بدلیں';

  @override
  String get vtRestore => 'واپس لائیں';

  @override
  String get vtSave => 'محفوظ کریں';

  @override
  String get vtScan => 'اسکین';

  @override
  String get vtScanAction => '📸 اسکین';

  @override
  String get vtSearchHint => 'دستاویزات تلاش کریں…';

  @override
  String get vtSearchUnavailable => 'تلاش دستیاب نہیں';

  @override
  String get vtSeeAll => 'سب دیکھیں';

  @override
  String get vtSetDate => 'تاریخ لگائیں';

  @override
  String get vtShare => 'شیئر';

  @override
  String get vtSharedFrom => 'LifeOS سے شیئر کیا گیا';

  @override
  String get vtSystemFolderNoDelete => 'سسٹم فولڈرز حذف نہیں ہو سکتے';

  @override
  String get vtSystemFolderNoRename => 'سسٹم فولڈرز کا نام نہیں بدلا جا سکتا';

  @override
  String get vtTags => 'ٹیگز';

  @override
  String get vtThisYear => 'اس سال';

  @override
  String vtTrashDaysLeft(String n) {
    return '$n دن باقی';
  }

  @override
  String get vtTrashEmpty => 'ردی خالی ہے';

  @override
  String vtTrashEmptyMessage(String days) {
    return 'حذف شدہ دستاویزات یہاں $days دن رہتی ہیں، پھر ہمیشہ کے لیے ہٹا دی جاتی ہیں۔';
  }

  @override
  String get vtTrashUnavailable => 'ردی دستیاب نہیں';

  @override
  String get vtTryAgain => 'براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get vtType => 'قسم';

  @override
  String get vtTypeAgreement => 'معاہدہ';

  @override
  String get vtTypeBill => 'بل';

  @override
  String get vtTypeCertificate => 'سرٹیفکیٹ';

  @override
  String get vtTypeCnic => 'شناختی کارڈ';

  @override
  String get vtTypeDegree => 'ڈگری';

  @override
  String get vtTypeFeeVoucher => 'فیس واؤچر';

  @override
  String get vtTypeLicense => 'لائسنس';

  @override
  String get vtTypeOther => 'دستاویز';

  @override
  String get vtTypePassport => 'پاسپورٹ';

  @override
  String get vtTypePolicy => 'پالیسی';

  @override
  String get vtTypePrescription => 'نسخہ';

  @override
  String get vtTypeReceipt => 'رسید';

  @override
  String get vtTypeReport => 'رپورٹ';

  @override
  String get vtTypeVisa => 'ویزا';

  @override
  String get vtTypeWarranty => 'وارنٹی';

  @override
  String get vtUnarchive => 'واپس نکالیں';

  @override
  String get vtUnavailableMessage => 'اس ڈیوائس پر مقامی ڈیٹا نہیں کھل سکا۔';

  @override
  String get vtUnavailableTitle => 'والٹ دستیاب نہیں';

  @override
  String get vtUndo => 'واپس کریں';

  @override
  String get vtUnfiled => 'غیر ترتیب شدہ';

  @override
  String get vtUnfiledTitle => '📥 غیر ترتیب شدہ';

  @override
  String get vtVaultTitle => 'والٹ';

  @override
  String get wd1 => 'پیر';

  @override
  String get wd2 => 'منگل';

  @override
  String get wd3 => 'بدھ';

  @override
  String get wd4 => 'جمعرات';

  @override
  String get wd5 => 'جمعہ';

  @override
  String get wd6 => 'ہفتہ';

  @override
  String get wd7 => 'اتوار';

  @override
  String get yesterday => 'گزشتہ کل';
}

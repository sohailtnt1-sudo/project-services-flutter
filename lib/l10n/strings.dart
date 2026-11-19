// Central UI strings — English + Urdu (proper Urdu script).
//
// Scope of this pass: the core user-facing static strings — app name /
// tagline, auth screen, customer shell tabs + home, booking flow labels,
// provider onboarding + provider dashboard labels, and common words.
// Dynamic content from the database (category / service names, provider
// names, city names) is NOT translated and stays as-is. Chat, tracking
// and map screens keep their English strings for now, except the admin
// review note on the chat screen (chatAdminNote) and the cash-received
// labels (cashReceived*, cashPaid) — a later pass can extend this map;
// every key must exist in both languages (enforced by
// test/language_test.dart).
//
// Usage: `tr('home')` reads the current language from the language
// service; `trf('hello', {'name': 'Ali'})` fills {placeholders}.
import '../services/language_service.dart';

const Map<String, Map<String, String>> _strings = {
  'en': {
    // App
    'appName': 'AsaanKaam',
    'tagline': 'Trusted local professionals, booked in minutes.',
    'language': 'Language',
    // Common
    'save': 'Save',
    'cancel': 'Cancel',
    'back': 'Back',
    'done': 'Done',
    'loading': 'Loading…',
    'tryAgain': 'Try again',
    'city': 'City',
    'search': 'Search',
    'logOut': 'Log out',
    'saving': 'Saving…',
    'pleaseWait': 'Please wait…',
    // Auth
    'logIn': 'Log in',
    'signUp': 'Sign up',
    'fullName': 'Full name',
    'phone': 'Phone (03xx-xxxxxxx)',
    'email': 'Email',
    'password': 'Password',
    'signUpAs': 'I am signing up as',
    'customer': 'Customer',
    'provider': 'Provider',
    'customerHint': 'I want to book services',
    'providerHint': 'I want to offer services',
    'createAccount': 'Create account',
    'codNote': 'Cash on delivery. No payment needed to book.',
    'accountCreated':
        'Account created. Please check your email and click the confirmation link, then log in.',
    // Customer shell tabs
    'home': 'Home',
    'categories': 'Categories',
    'bookings': 'Bookings',
    'messages': 'Messages',
    'profile': 'Profile',
    // Chat
    'chatAdminNote':
        'Chats may be reviewed by the AsaanKaam admin for safety and dispute resolution.',
    // Cash received (migration 010)
    'cashReceived': 'Cash received',
    'cashReceivedTitle': 'Cash received from customer',
    'cashAmountLabel': 'Amount received (Rs.)',
    'cashAmountError': 'Enter an amount greater than 0.',
    'cashReceivedNote':
        'Declare the cash you received — it will be shown to the customer and the admin.',
    'cashPaid': 'Cash paid: {amount}',
    'confirmCompletion': 'Confirm completion',
    // Home
    'hello': 'Hello, {name}',
    'searchHint': 'Search a service — fan repair, plumber…',
    'popularCategories': 'Popular categories',
    'serviceArea': 'Service area',
    'recommendedTechnicians': 'Recommended technicians in {city}',
    'book': 'Book',
    'noCategories': 'No categories yet.',
    'noServices': 'No services available yet.',
    'online': 'Online',
    'offline': 'Offline',
    'within': 'Within: ',
    'myBookings': 'My bookings',
    'noBookings': 'No bookings yet. Pick a service from Home to book your first job.',
    'noBookingsShort': 'No bookings yet.',
    'bookingHistory': 'Booking history',
    'myRatings': 'My ratings',
    'noRatings': 'You have not rated any job yet.',
    // Booking flow
    'bookingConfirmed': 'Booking confirmed',
    'bookingConfirmedMsg': 'Your booking is confirmed!',
    'trackBooking': 'Track my booking',
    'backToHome': 'Back to home',
    'bookTitle': 'Book: {service}',
    'noTechnician': 'No technician chosen — an available technician will be assigned.',
    'describeProblem': 'Describe the problem',
    'fetchProblem': 'What should the rider fetch?',
    'photoProblem': 'Photo of the problem (optional, up to 5)',
    'pickupDetails': 'Pickup details',
    'pickupHint': 'Where should the rider collect the items from?',
    'pickupShopName': 'Pickup shop name',
    'pickupAddress': 'Pickup address',
    'pickPickupOnMap': 'Pick pickup on map',
    'itemCost': 'Estimated item cost (Rs.) — optional',
    'dateTime': 'Date & time',
    'address': 'Address',
    'deliveryAddress': 'Delivery address',
    'pickOnMap': 'Pick on map',
    'jobPrice': 'Job price',
    'platformFee': 'Platform fee (15%)',
    'itemCostCash': 'Estimated item cost (cash)',
    'youPayCod': 'You pay (cash on delivery)',
    'technicianReceives': 'Technician receives',
    'confirmBooking': 'Confirm booking — {price}',
    'codNoteBooking': 'Cash on delivery. You pay the technician after the work is done.',
    'codNoteDelivery':
        'Cash on delivery. Item cost is paid in cash to the rider, plus the delivery fee above.',
    // Provider onboarding
    'registerProvider': 'Register as a provider',
    'updateRegistration': 'Update your registration',
    'onboardingIntro':
        'Tell customers what you do, where you work and what you charge. Our admin team verifies your CNIC and selfie before you can take jobs.',
    'yourDetails': 'Your details & services',
    'cnicSelfieStep': 'CNIC & selfie',
    'cnicNumber': 'CNIC number',
    'mobileNumber': 'Mobile number',
    'cityArea': 'City / area',
    'experienceYears': 'Years of experience',
    'shortBio': 'Short bio',
    'servicesOffer': 'Services you offer — set your own charge for each',
    'yourCharge': 'Your charge (Rs.)',
    'saveContinue': 'Save & continue to documents',
    'saveChangesContinue': 'Save changes & continue to documents',
    'uploadCnicSelfie': 'Upload your CNIC & selfie',
    'uploadCnicSelfieHint':
        'Our admin team checks your CNIC and selfie before approving your account. You can start taking jobs once you are approved.',
    'cnicFront': 'CNIC — front',
    'cnicBack': 'CNIC — back',
    'selfie': 'Selfie',
    'doneDashboard': 'Done — go to my dashboard',
    'backToDetails': 'Back to details',
    'cnicPrivateNote':
        'Your CNIC number is only visible to you and our admin team — never to customers.',
    'docsPrivateNote':
        'Your CNIC photos and selfie are only visible to you and our admin team. They are used only to verify your identity before you can take jobs.',
    'mobileInvalid': 'Please enter a valid mobile number (e.g. 0300-1234567).',
    'cnicSaved': 'CNIC number saved.',
    'itemCostHint':
        'An estimate helps the rider — you pay the actual shop price in cash when the rider arrives.',
    // Provider shell
    'dashboard': 'Dashboard',
    'jobs': 'Jobs',
    'earnings': 'Earnings',
    'providerDashboard': 'Provider dashboard',
    'completeVerification': 'Complete verification',
    'updateVerification': 'Update verification & documents',
    'verified': 'Verified',
    'rejected': 'Rejected',
    'verificationPending': 'Verification pending',
    'availableForJobs': 'Available for jobs',
    'latestJobs': 'Latest jobs',
    'noJobs': 'No jobs yet.',
    'myJobs': 'My jobs',
    'updateMobile': 'Update mobile number',
    'mobileSaved': 'Mobile number saved.',
    'noProviderProfile':
        'No provider profile yet. Complete your verification in the app (CNIC, selfie, services and charges) — then your dashboard appears here.',
    'underReview':
        'Your account is under review. You can take jobs once an admin approves your CNIC, selfie and documents.',
    'onlineNote': 'You are online — customers can book you.',
    'offlineNote': 'You are offline — new booking requests will not come to you.',
    'profileUpdateHint':
        'To update your services, charges, bio, CNIC documents or selfie, use the verification flow in the app. Your verification status and availability are managed here.',
  },
  'ur': {
    // App
    'appName': 'آسان کام',
    'tagline': 'قابلِ اعتماد مقامی ماہرین، چند منٹوں میں بک کریں۔',
    'language': 'زبان',
    // Common
    'save': 'محفوظ کریں',
    'cancel': 'منسوخ کریں',
    'back': 'واپس',
    'done': 'مکمل',
    'loading': 'لوڈ ہو رہا ہے…',
    'tryAgain': 'دوبارہ کوشش کریں',
    'city': 'شہر',
    'search': 'تلاش کریں',
    'logOut': 'لاگ آؤٹ',
    'saving': 'محفوظ ہو رہا ہے…',
    'pleaseWait': 'براہ کرم انتظار کریں…',
    // Auth
    'logIn': 'لاگ ان',
    'signUp': 'سائن اپ',
    'fullName': 'پورا نام',
    'phone': 'فون (03xx-xxxxxxx)',
    'email': 'ای میل',
    'password': 'پاس ورڈ',
    'signUpAs': 'میں سائن اپ کر رہا ہوں بطور',
    'customer': 'گاہک',
    'provider': 'ماہر',
    'customerHint': 'میں سروس بک کرنا چاہتا ہوں',
    'providerHint': 'میں سروس دینا چاہتا ہوں',
    'createAccount': 'اکاؤنٹ بنائیں',
    'codNote': 'کیش آن ڈیلیوری۔ بکنگ کے لیے کوئی ادائیگی درکار نہیں۔',
    'accountCreated':
        'اکاؤنٹ بن گیا ہے۔ براہ کرم اپنی ای میل چیک کریں اور تصدیقی لنک پر کلک کریں، پھر لاگ ان کریں۔',
    // Customer shell tabs
    'home': 'ہوم',
    'categories': 'زمرے',
    'bookings': 'بکنگز',
    'messages': 'پیغامات',
    'profile': 'پروفائل',
    // Chat
    'chatAdminNote':
        'حفاظت اور تنازعات کے حل کے لیے AsaanKaam ایڈمن چیٹس دیکھ سکتا ہے۔',
    // Cash received (migration 010)
    'cashReceived': 'نقد موصول ہوا',
    'cashReceivedTitle': 'گاہک سے نقد رقم موصول ہوئی',
    'cashAmountLabel': 'موصول شدہ رقم (روپے)',
    'cashAmountError': 'صفر سے زیادہ رقم درج کریں۔',
    'cashReceivedNote':
        'موصول شدہ نقد رقم درج کریں — یہ گاہک اور ایڈمن کو دکھائی جائے گی۔',
    'cashPaid': 'نقد ادا کیا گیا: {amount}',
    'confirmCompletion': 'تکمیل کی تصدیق کریں',
    // Home
    'hello': 'السلام علیکم، {name}',
    'searchHint': 'سروس تلاش کریں — پنکھا مرمت، پلمبر…',
    'popularCategories': 'مقبول زمرے',
    'serviceArea': 'سروس کا علاقہ',
    'recommendedTechnicians': '{city} میں تجویز کردہ ماہرین',
    'book': 'بک کریں',
    'noCategories': 'ابھی کوئی زمرہ نہیں۔',
    'noServices': 'ابھی کوئی سروس دستیاب نہیں۔',
    'online': 'آن لائن',
    'offline': 'آف لائن',
    'within': 'فاصلہ: ',
    'myBookings': 'میری بکنگز',
    'noBookings': 'ابھی کوئی بکنگ نہیں۔ پہلا کام بک کرنے کے لیے ہوم سے سروس منتخب کریں۔',
    'noBookingsShort': 'ابھی کوئی بکنگ نہیں۔',
    'bookingHistory': 'بکنگ کی تاریخ',
    'myRatings': 'میری ریٹنگز',
    'noRatings': 'آپ نے ابھی تک کسی کام کو ریٹنگ نہیں دی۔',
    // Booking flow
    'bookingConfirmed': 'بکنگ کی تصدیق ہو گئی',
    'bookingConfirmedMsg': 'آپ کی بکنگ کی تصدیق ہو گئی ہے!',
    'trackBooking': 'میری بکنگ ٹریک کریں',
    'backToHome': 'ہوم پر واپس',
    'bookTitle': 'بک کریں: {service}',
    'noTechnician': 'کوئی ماہر منتخب نہیں ہوا — دستیاب ماہر مقرر کر دیا جائے گا۔',
    'describeProblem': 'مسئلہ بیان کریں',
    'fetchProblem': 'رائیڈر کیا لے کر آئے؟',
    'photoProblem': 'مسئلے کی تصویر (اختیاری، 5 تک)',
    'pickupDetails': 'پک اپ کی تفصیلات',
    'pickupHint': 'رائیڈر سامان کہاں سے اٹھائے؟',
    'pickupShopName': 'پک اپ دکان کا نام',
    'pickupAddress': 'پک اپ کا پتہ',
    'pickPickupOnMap': 'نقشے پر پک اپ منتخب کریں',
    'itemCost': 'سامان کی تخمینی قیمت (روپے) — اختیاری',
    'dateTime': 'تاریخ اور وقت',
    'address': 'پتہ',
    'deliveryAddress': 'ڈیلیوری کا پتہ',
    'pickOnMap': 'نقشے پر منتخب کریں',
    'jobPrice': 'کام کی قیمت',
    'platformFee': 'پلیٹفارم فیس (15٪)',
    'itemCostCash': 'سامان کی تخمینی قیمت (نقد)',
    'youPayCod': 'آپ ادا کریں گے (کیش آن ڈیلیوری)',
    'technicianReceives': 'ماہر کو ملے گا',
    'confirmBooking': 'بکنگ کی تصدیق کریں — {price}',
    'codNoteBooking': 'کیش آن ڈیلیوری۔ کام مکمل ہونے کے بعد آپ ماہر کو ادائیگی کریں۔',
    'codNoteDelivery':
        'کیش آن ڈیلیوری۔ سامان کی قیمت رائیڈر کو نقد ادا کریں، اوپر دی گئی ڈیلیوری فیس کے علاوہ۔',
    // Provider onboarding
    'registerProvider': 'ماہر کے طور پر رجسٹر کریں',
    'updateRegistration': 'اپنی رجسٹریشن اپ ڈیٹ کریں',
    'onboardingIntro':
        'گاہکوں کو بتائیں کہ آپ کیا کرتے ہیں، کہاں کام کرتے ہیں اور کیا قیمت لیتے ہیں۔ ہماری ایڈمن ٹیم آپ کا شناختی کارڈ اور سیلفی تصدیق کرتی ہے، اس کے بعد آپ کام لے سکتے ہیں۔',
    'yourDetails': 'آپ کی تفصیلات اور سروسز',
    'cnicSelfieStep': 'شناختی کارڈ اور سیلفی',
    'cnicNumber': 'شناختی کارڈ نمبر',
    'mobileNumber': 'موبائل نمبر',
    'cityArea': 'شہر / علاقہ',
    'experienceYears': 'تجربے کے سال',
    'shortBio': 'مختصر تعارف',
    'servicesOffer': 'آپ کی پیش کردہ سروسز — ہر ایک کی اپنی قیمت مقرر کریں',
    'yourCharge': 'آپ کی قیمت (روپے)',
    'saveContinue': 'محفوظ کریں اور دستاویزات پر جائیں',
    'saveChangesContinue': 'تبدیلیاں محفوظ کریں اور دستاویزات پر جائیں',
    'uploadCnicSelfie': 'اپنا شناختی کارڈ اور سیلفی اپ لوڈ کریں',
    'uploadCnicSelfieHint':
        'ہماری ایڈمن ٹیم آپ کے شناختی کارڈ اور سیلفی کی جانچ کرتی ہے، پھر آپ کا اکاؤنٹ منظور ہوتا ہے۔ منظوری کے بعد آپ کام لے سکتے ہیں۔',
    'cnicFront': 'شناختی کارڈ — سامنے',
    'cnicBack': 'شناختی کارڈ — پیچھے',
    'selfie': 'سیلفی',
    'doneDashboard': 'مکمل — ڈیش بورڈ پر جائیں',
    'backToDetails': 'تفصیلات پر واپس',
    'cnicPrivateNote':
        'آپ کا شناختی کارڈ نمبر صرف آپ اور ہماری ایڈمن ٹیم کو نظر آتا ہے — گاہکوں کو کبھی نہیں۔',
    'docsPrivateNote':
        'آپ کے شناختی کارڈ کی تصاویر اور سیلفی صرف آپ اور ہماری ایڈمن ٹیم کو نظر آتی ہیں۔ یہ صرف آپ کی شناخت کی تصدیق کے لیے استعمال ہوتی ہیں۔',
    'mobileInvalid': 'براہ کرم درست موبائل نمبر درج کریں (مثلاً 0300-1234567)۔',
    'cnicSaved': 'شناختی کارڈ نمبر محفوظ ہو گیا۔',
    'itemCostHint':
        'تخمینہ رائیڈر کی مدد کرتا ہے — آپ دکان کی اصل قیمت رائیڈر کے آنے پر نقد ادا کرتے ہیں۔',
    // Provider shell
    'dashboard': 'ڈیش بورڈ',
    'jobs': 'کام',
    'earnings': 'آمدنی',
    'providerDashboard': 'ماہر کا ڈیش بورڈ',
    'completeVerification': 'تصدیق مکمل کریں',
    'updateVerification': 'تصدیق اور دستاویزات اپ ڈیٹ کریں',
    'verified': 'تصدیق شدہ',
    'rejected': 'مسترد',
    'verificationPending': 'تصدیق زیر التواء',
    'availableForJobs': 'کام کے لیے دستیاب',
    'latestJobs': 'تازہ ترین کام',
    'noJobs': 'ابھی کوئی کام نہیں۔',
    'myJobs': 'میرے کام',
    'updateMobile': 'موبائل نمبر اپ ڈیٹ کریں',
    'mobileSaved': 'موبائل نمبر محفوظ ہو گیا۔',
    'noProviderProfile':
        'ابھی آپ کی ماہر پروفائل نہیں بنی۔ ایپ میں اپنی تصدیق مکمل کریں (شناختی کارڈ، سیلفی، سروسز اور قیمت) — پھر آپ کا ڈیش بورڈ یہاں نظر آئے گا۔',
    'underReview':
        'آپ کا اکاؤنٹ زیرِ جائزہ ہے۔ ایڈمن آپ کا شناختی کارڈ، سیلفی اور دستاویزات منظور کرے تو آپ کام لے سکیں گے۔',
    'onlineNote': 'آپ آن لائن ہیں — گاہک آپ کو بک کر سکتے ہیں۔',
    'offlineNote': 'آپ آف لائن ہیں — نئی بکنگ کی درخواستیں نہیں آئیں گی۔',
    'profileUpdateHint':
        'اپنی سروسز، قیمت، تعارف، شناختی کارڈ کی دستاویزات یا سیلفی اپ ڈیٹ کرنے کے لیے ایپ میں تصدیق کا عمل استعمال کریں۔ آپ کی تصدیق کی حیثیت اور دستیابی یہیں سے منظم ہوتی ہے۔',
  },
};

/// Look up a string in the current language, falling back to English,
/// then to the key itself when a translation is missing.
String tr(String key) {
  final lang = languageService.language;
  return _strings[lang]?[key] ?? _strings[kLanguageEnglish]?[key] ?? key;
}

/// Like [tr], but fills {placeholders} from [params].
String trf(String key, Map<String, String> params) {
  var out = tr(key);
  params.forEach((k, v) => out = out.replaceAll('{$k}', v));
  return out;
}

/// All English keys — the language test asserts every one of them has a
/// non-empty Urdu value.
List<String> get allStringKeys => _strings[kLanguageEnglish]!.keys.toList();

/// Raw maps, exposed for tests.
Map<String, String> get englishStrings => _strings[kLanguageEnglish]!;
Map<String, String> get urduStrings => _strings[kLanguageUrdu]!;

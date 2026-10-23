// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Sinhala Sinhalese (`si`).
class AppLocalizationsSi extends AppLocalizations {
  AppLocalizationsSi([String locale = 'si']) : super(locale);

  @override
  String get appTitle => 'FamNest';

  @override
  String get welcomeTitle => 'ඔබේ පවුලේ පෞද්ගලික චැට් එක';

  @override
  String get welcomeBody =>
      'ඔබේ නිවසේ Wi-Fi හරහා පවුලේ අය සමඟ කතා කරන්න, ඡායාරූප සහ ගොනු බෙදාගන්න. අන්තර්ජාලය, ගිණුම් හෝ cloud අවශ්‍ය නැත — සියල්ල ඔබේ පවුලේ උපාංගවලම රැඳේ.';

  @override
  String get privacyPoint1 =>
      'අන්තයේ සිට අන්තය දක්වා සංකේතනය කළ පණිවිඩ සහ ගොනු';

  @override
  String get privacyPoint2 => 'අන්තර්ජාලය නොමැතිව නිවසේ Wi-Fi මත ක්‍රියා කරයි';

  @override
  String get privacyPoint3 => 'ඔබේ පවුලේ උපාංගවල පමණක් ගබඩා වේ';

  @override
  String get createFamily => 'නව පවුලක් සකසන්න';

  @override
  String get createFamilyHint => 'මෙම උපාංගය පවුලේ මධ්‍යස්ථානය (hub) කරන්න';

  @override
  String get joinFamily => 'මගේ පවුලට එක්වන්න';

  @override
  String get joinFamilyHint => 'නිවසේ කෙනෙක් දැනටමත් FamNest සකසා ඇත';

  @override
  String get yourName => 'ඔබේ නම';

  @override
  String get yourNameHint => 'උදා: අම්මා, තාත්තා, නිමල්';

  @override
  String get nameRequired => 'කරුණාකර ඔබේ නම ඇතුළත් කරන්න';

  @override
  String get familyName => 'පවුලේ නම';

  @override
  String get familyNameHint => 'උදා: පෙරේරා පවුල';

  @override
  String get familyNameRequired => 'කරුණාකර පවුලේ නමක් ඇතුළත් කරන්න';

  @override
  String get addPhoto => 'ඡායාරූපයක් එක් කරන්න';

  @override
  String get changePhoto => 'ඡායාරූපය වෙනස් කරන්න';

  @override
  String get removePhoto => 'ඡායාරූපය ඉවත් කරන්න';

  @override
  String get takePhoto => 'ඡායාරූපයක් ගන්න';

  @override
  String get chooseFromGallery => 'ගැලරියෙන් තෝරන්න';

  @override
  String get createFamilyTitle => 'ඔබේ පවුල සකසන්න';

  @override
  String get createFamilyBody =>
      'මෙම උපාංගය ඔබේ පවුලේ මධ්‍යස්ථානය බවට පත්වේ. එය නිවසේ, ආරෝපණය වෙමින් සහ Wi-Fi වෙත සම්බන්ධව තබන්න — අමතර දුරකථනයක් හෝ ටැබ්ලටයක් ඉතා හොඳයි.';

  @override
  String get createAction => 'පවුල සාදන්න';

  @override
  String get creating => 'සකසමින්…';

  @override
  String get inviteTitle => 'ඔබේ පවුල ආරාධනා කරන්න';

  @override
  String get inviteBody =>
      'එක් එක් පවුලේ සාමාජිකයාගේ දුරකථනයේ FamNest ස්ථාපනය කර, \"මගේ පවුලට එක්වන්න\" තට්ටු කර මෙම ආරාධනා කේතය ඇතුළත් කරන්න. ඔවුන් එකම Wi-Fi එකේ සිටිය යුතුය.';

  @override
  String get inviteCode => 'ආරාධනා කේතය';

  @override
  String get copy => 'පිටපත් කරන්න';

  @override
  String get copied => 'පිටපත් කළා';

  @override
  String get continueAction => 'ඉදිරියට';

  @override
  String hubAddress(String address) {
    return 'Hub ලිපිනය: $address';
  }

  @override
  String get joinTitle => 'ඔබේ පවුල සොයන්න';

  @override
  String get searching => 'ඔබේ Wi-Fi ජාලයේ පවුල් hub සොයමින්…';

  @override
  String get noHubsFound =>
      'පවුල් hub එකක් හමු නොවීය. ඔබ hub උපාංගය ඇති Wi-Fi එකේම සිටින බවත්, එහි FamNest ක්‍රියාත්මක වන බවත් තහවුරු කරන්න.';

  @override
  String get scanAgain => 'නැවත සොයන්න';

  @override
  String get enterAddressManually => 'Hub ලිපිනය අතින් ඇතුළත් කරන්න';

  @override
  String get hubAddressLabel => 'Hub IP ලිපිනය';

  @override
  String get hubAddressHint => 'උදා: 192.168.1.20';

  @override
  String get connect => 'සම්බන්ධ වන්න';

  @override
  String get couldNotReachHub =>
      'එම ලිපිනයේ පවුල් hub එකක් සම්බන්ධ කර ගත නොහැකි විය.';

  @override
  String joinFamilyNamed(String family) {
    return '$family වෙත එක්වන්න';
  }

  @override
  String get enterInviteCode =>
      'Hub උපාංගයේ පෙන්වන ආරාධනා කේතය ඇතුළත් කරන්න (සැකසුම් → පවුල් hub).';

  @override
  String get inviteCodeInvalid => 'ආරාධනා කේතයක අකුරු සහ ඉලක්කම් 16ක් ඇත';

  @override
  String get joinAction => 'පවුලට එක්වන්න';

  @override
  String get joining => 'එක්වෙමින්…';

  @override
  String get wrongInviteCode =>
      'එම ආරාධනා කේතය නිවැරදි නැත. Hub උපාංගයේ එය පරීක්ෂා කරන්න.';

  @override
  String get removedFromFamily => 'මෙම උපාංගය පවුලෙන් ඉවත් කර ඇත.';

  @override
  String get joinFailed =>
      'පවුල් hub එකට සම්බන්ධ විය නොහැකි විය. ඔබ එකම Wi-Fi එකේ සිටින බව තහවුරු කරන්න.';

  @override
  String get chats => 'චැට්';

  @override
  String get family => 'පවුල';

  @override
  String get settings => 'සැකසුම්';

  @override
  String get noMessagesYet => 'තවම පණිවිඩ නැත';

  @override
  String get newChat => 'නව චැට්';

  @override
  String get newGroup => 'නව කණ්ඩායම';

  @override
  String get everyone => 'පවුලේ සියලු දෙනා';

  @override
  String get noFamilyMembersYet =>
      'තවම වෙන කිසිවෙක් එක්වී නැත. Hub උපාංගයෙන් ආරාධනා කේතය බෙදාගන්න.';

  @override
  String get connecting => 'ඔබේ පවුල් hub එකට සම්බන්ධ වෙමින්…';

  @override
  String get searchingHub => 'මෙම Wi-Fi එකේ ඔබේ පවුල් hub එක සොයමින්…';

  @override
  String get offline =>
      'පවුල් hub එක ළඟා විය නොහැක. ඔබ නැවත නිවසේ Wi-Fi වෙත පැමිණි විට පණිවිඩ යවනු ලැබේ.';

  @override
  String get retry => 'නැවත උත්සාහ කරන්න';

  @override
  String get inviteCodeChanged =>
      'ආරාධනා කේතය වෙනස් කර ඇත. නැවත සම්බන්ධ වීමට නව කේතය ඇතුළත් කරන්න.';

  @override
  String get enterNewCode => 'කේතය ඇතුළත් කරන්න';

  @override
  String get removedBanner => 'මෙම උපාංගය පවුලෙන් ඉවත් කර ඇත.';

  @override
  String get online => 'සබැඳිව';

  @override
  String lastSeen(String time) {
    return 'අවසන් වරට $time';
  }

  @override
  String get offlineStatus => 'නොබැඳිව';

  @override
  String get you => 'ඔබ';

  @override
  String get typing => 'ටයිප් කරමින්…';

  @override
  String typingOne(String name) {
    return '$name ටයිප් කරමින්…';
  }

  @override
  String get typingMany => 'කිහිප දෙනෙක් ටයිප් කරමින්…';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'සාමාජිකයන් $count',
      one: 'සාමාජිකයන් 1',
    );
    return '$_temp0';
  }

  @override
  String get messageHint => 'පණිවිඩය';

  @override
  String get attach => 'අමුණන්න';

  @override
  String get send => 'යවන්න';

  @override
  String get attachPhoto => 'ඡායාරූප';

  @override
  String get attachCamera => 'කැමරාව';

  @override
  String get attachFile => 'ගොනුව';

  @override
  String get today => 'අද';

  @override
  String get yesterday => 'ඊයේ';

  @override
  String get messageDeleted => 'මෙම පණිවිඩය මකා දමා ඇත';

  @override
  String get deleteForEveryone => 'සියලු දෙනාටම මකන්න';

  @override
  String get deleteForMe => 'මට පමණක් මකන්න';

  @override
  String get copyText => 'පෙළ පිටපත් කරන්න';

  @override
  String get cancel => 'අවලංගු කරන්න';

  @override
  String get delete => 'මකන්න';

  @override
  String get save => 'සුරකින්න';

  @override
  String get openFile => 'විවෘත කරන්න';

  @override
  String get fileFailed => 'බාගැනීම අසාර්ථකයි — නැවත උත්සාහ කිරීමට තට්ටු කරන්න';

  @override
  String get couldNotOpenFile => 'මෙම ගොනුව විවෘත කිරීමට යෙදුමක් හමු නොවීය';

  @override
  String get sending => 'යවමින්…';

  @override
  String get failedToSend => 'යැවුණේ නැත — නැවත උත්සාහයට තට්ටු කරන්න';

  @override
  String fileTooLarge(String name) {
    return '$name යැවීමට විශාල වැඩියි (උපරිම 200 MB)';
  }

  @override
  String get notConnectedAction => 'මුලින්ම ඔබේ පවුල් hub එකට සම්බන්ධ වන්න';

  @override
  String get leftGroup => 'ඔබ තවදුරටත් මෙම කණ්ඩායමේ නැත';

  @override
  String get emptyChat => 'ආයුබෝවන් කියන්න 👋';

  @override
  String get groupInfo => 'කණ්ඩායම් තොරතුරු';

  @override
  String get contactInfo => 'සම්බන්ධතා තොරතුරු';

  @override
  String get directEncrypted =>
      'මෙහි පණිවිඩ අන්තයේ සිට අන්තය දක්වා සංකේතනය කර ඇත. පවුල් hub එකටවත් ඒවා කියවිය නොහැක.';

  @override
  String get groupName => 'කණ්ඩායමේ නම';

  @override
  String get groupNameHint => 'උදා: සති අන්ත සැලසුම්';

  @override
  String get groupNameRequired => 'කරුණාකර කණ්ඩායමේ නමක් ඇතුළත් කරන්න';

  @override
  String get chooseMembers => 'සාමාජිකයන් තෝරන්න';

  @override
  String get createGroup => 'සාදන්න';

  @override
  String get editGroup => 'කණ්ඩායම සංස්කරණය';

  @override
  String get leaveGroup => 'කණ්ඩායමෙන් ඉවත් වන්න';

  @override
  String get leaveGroupConfirm =>
      'මෙම කණ්ඩායමෙන් ඉවත් වෙනවාද? ඔබට තවදුරටත් එහි පණිවිඩ නොලැබේ.';

  @override
  String get mute => 'දැනුම්දීම් නිහඬ කරන්න';

  @override
  String get sharedMedia => 'ඡායාරූප සහ ගොනු';

  @override
  String get clearChat => 'මෙම උපාංගයේ චැට් එක හිස් කරන්න';

  @override
  String get clearChatConfirm =>
      'මෙම චැට් එකේ සියලු පණිවිඩ මෙම උපාංගයෙන් මකන්නද? අනෙක් අයගේ පිටපත් රැඳේ.';

  @override
  String get selectAtLeastOne => 'අවම වශයෙන් එක් සාමාජිකයෙකු තෝරන්න';

  @override
  String get editProfile => 'පැතිකඩ සංස්කරණය';

  @override
  String get profileVisibility =>
      'ඔබේ නම සහ ඡායාරූපය සංකේතනය කර ඔබේ පවුල සමඟ පමණක් බෙදා ගැනේ.';

  @override
  String get notificationsSetting => 'පණිවිඩ දැනුම්දීම්';

  @override
  String get keepConnected => 'පසුබිමේ සම්බන්ධව සිටින්න';

  @override
  String get keepConnectedHint =>
      'පණිවිඩ ක්ෂණිකව ලැබීමට කුඩා නොනවතින දැනුම්දීමක් පෙන්වයි.';

  @override
  String get familyHub => 'පවුල් hub';

  @override
  String get hubRunning => 'මෙම උපාංගයේ ක්‍රියාත්මකයි';

  @override
  String get hubStopped => 'නවතා ඇත';

  @override
  String connectedTo(String address) {
    return '$address වෙත සම්බන්ධයි';
  }

  @override
  String get privacy => 'පෞද්ගලිකත්වය සහ ආරක්ෂාව';

  @override
  String get privacySummary => 'FamNest ඔබේ පවුලේ දත්ත පෞද්ගලිකව තබන ආකාරය';

  @override
  String get privacyBody =>
      '• අන්තර්ජාලය හෝ cloud නැත: පණිවිඩ ඔබේ නිවසේ Wi-Fi හරහා පවුලේ උපාංග අතර පමණක් ගමන් කරයි.\n\n• ඔබ දකින සියල්ල මෙම උපාංගයේ පමණක් ගබඩා වේ. චැට් cloud උපස්ථවලින් බැහැර කර ඇත.\n\n• එක්වීමට පවුලේ ආරාධනා කේතය අවශ්‍යයි. උපාංග සහ hub එක එකිනෙකා තහවුරු කරන අතර සියලු දත්ත සංකේතනය කෙරේ (AES-256-GCM).\n\n• පණිවිඩ, ඡායාරූප, ගොනු, නම් සහ පැතිකඩ ඡායාරූප අන්තයේ සිට අන්තය දක්වා සංකේතනය කෙරේ. Hub එක ගබඩා කරන්නේ එයට කියවිය නොහැකි සංකේතිත දත්ත පමණි.\n\n• පුද්ගලික චැට් සඳහා ඔබ දෙදෙනාට පමණක් ඇති යතුරක් භාවිතා වන නිසා පවුලේ අනෙක් අයටද ඒවා කියවිය නොහැක.\n\n• සාමාජිකයෙකු ඉවත් කර නව ආරාධනා කේතයක් නිකුත් කිරීමෙන් ඔවුන්ට ඇතුළු වීම අවහිර වේ.';

  @override
  String get deviceId => 'උපාංග ඇඟිලි සලකුණ';

  @override
  String version(String version) {
    return 'අනුවාදය $version';
  }

  @override
  String get leaveFamily => 'පවුලෙන් ඉවත් වී දත්ත මකන්න';

  @override
  String get leaveFamilyConfirm =>
      'මෙය මෙම උපාංගයෙන් සියලු පණිවිඩ, ඡායාරූප, ගොනු සහ යතුරු ස්ථිරවම මකා දමයි. මෙම උපාංගය පවුල් hub එක නම්, hub එක සහ එහි ඉතිහාසයද මැකෙන අතර සියලු දෙනාට නැවත සැකසීමට සිදුවේ.';

  @override
  String get erase => 'මකන්න';

  @override
  String hubOnlineCount(int online, int total) {
    return 'සාමාජිකයන් $total න් $online ක් සබැඳිව';
  }

  @override
  String get rotateCode => 'නව ආරාධනා කේතයක් නිකුත් කරන්න';

  @override
  String get rotateCodeHint => 'යමෙකු ඉවත් කිරීමෙන් පසු භාවිතා කරන්න';

  @override
  String get rotateCodeConfirm =>
      'සියලු දෙනා විසන්ධි වන අතර නව කේතය එක් වරක් ඇතුළත් කළ යුතුය. පැරණි කේත තවදුරටත් ක්‍රියා නොකරයි.';

  @override
  String get removeMember => 'පවුලෙන් ඉවත් කරන්න';

  @override
  String removeMemberConfirm(String name) {
    return '$name පවුලෙන් ඉවත් කරන්නද? ඔවුන්ගේ උපාංගය විසන්ධි වේ. නැවත එක්වීම වැළැක්වීමට පසුව නව ආරාධනා කේතයක් නිකුත් කරන්න.';
  }

  @override
  String get startHub => 'අරඹන්න';

  @override
  String get stopHub => 'Hub නවත්වන්න';

  @override
  String get stopHubConfirm =>
      'Hub එක නවතා ඇති විට පවුලේ කිසිවෙකුට පණිවිඩ යැවීමට හෝ ලැබීමට නොහැක.';

  @override
  String get hubTips =>
      'මෙම උපාංගය ආරෝපණයට සම්බන්ධ කර නිවසේ Wi-Fi එකේ තබන්න. Hub එක පසුබිමේ ක්‍රියාත්මක වන අතර නැවත ආරම්භ කිරීමෙන් පසු ස්වයංක්‍රීයව ආරම්භ වේ.';

  @override
  String get hubIosNote =>
      'iPhone සහ iPad මත hub එක ක්‍රියා කරන්නේ FamNest විවෘතව ඇති විට පමණි. සැමවිටම ක්‍රියාත්මක hub එකක් සඳහා Android උපාංගයක් හෝ නිවසේ පරිගණකයක් භාවිතා කරන්න.';

  @override
  String get batteryOptimization => 'පසුබිමේ ක්‍රියා කිරීමට ඉඩ දෙන්න';

  @override
  String get batteryOptimizationHint =>
      'බැටරිය ඉතිරි කිරීමට Android විසින් hub එක නැවැත්වීම වළක්වයි';

  @override
  String get renameFamily => 'පවුලේ නම වෙනස් කරන්න';

  @override
  String hubError(String error) {
    return 'පවුල් hub එක ආරම්භ කළ නොහැකි විය: $error';
  }

  @override
  String somethingWentWrong(String error) {
    return 'යමක් වැරදුණා: $error';
  }

  @override
  String get familyActions => 'පවුලේ ක්‍රියා';

  @override
  String get poll => 'ඡන්ද විමසුම';

  @override
  String get callFamily => 'පවුලට කතා කරන්න';

  @override
  String get callFamilyHint =>
      'සියලු දෙනාට දැනුම්දීමක් ලැබෙන අතර එක් තට්ටුවකින් පිළිතුරු දිය හැක.';

  @override
  String get callBreakfast => 'උදේ කෑම ලෑස්තියි!';

  @override
  String get callLunch => 'දවල් කෑම ලෑස්තියි!';

  @override
  String get callTea => 'තේ වෙලාව!';

  @override
  String get callDinner => 'රෑ කෑම ලෑස්තියි!';

  @override
  String get callReady => 'ලෑස්තියි — ඇවිත් ගන්න!';

  @override
  String get callComeHere => 'හැමෝම, කරුණාකර මෙහෙ එන්න';

  @override
  String get callCustom => 'පවුලේ ඇමතුම';

  @override
  String get customCall => 'වෙනත් ඇමතුමක්…';

  @override
  String get customCallHint => 'උදා: විනාඩි 10කින් පන්සල් යනවා';

  @override
  String get answerComing => 'එනවා';

  @override
  String get answerSoon => 'විනාඩි 5කින්';

  @override
  String get answerSkip => 'එන්න බෑ';

  @override
  String get waitingForReplies => 'පිළිතුරු බලාපොරොත්තුවෙන්…';

  @override
  String get createPoll => 'ඡන්ද විමසුමක් සාදන්න';

  @override
  String get createPollHint => 'පවුලට ඡන්දය දීමට ඉඩ දෙන්න';

  @override
  String get pollQuestion => 'ප්‍රශ්නය';

  @override
  String get pollQuestionHint => 'උදා: ඉරිදා මොනවද උයන්නේ?';

  @override
  String pollOption(int number) {
    return 'විකල්පය $number';
  }

  @override
  String get addOption => 'විකල්පයක් එක් කරන්න';

  @override
  String get allowMultiple => 'පිළිතුරු කිහිපයකට ඉඩ දෙන්න';

  @override
  String get sendPoll => 'විමසුම යවන්න';

  @override
  String get pollClosed => 'විමසුම අවසන්';

  @override
  String get pollChooseOne => 'එකක් තෝරන්න';

  @override
  String get pollChooseMany => 'එකක් හෝ කිහිපයක් තෝරන්න';

  @override
  String votesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ඡන්ද $count',
      one: 'ඡන්ද 1',
      zero: 'තවම ඡන්ද නැත',
    );
    return '$_temp0';
  }

  @override
  String get closePoll => 'විමසුම අවසන් කරන්න';

  @override
  String get familyMember => 'පවුලේ සාමාජිකයෙක්';

  @override
  String get notificationChannelMessages => 'පණිවිඩ';

  @override
  String get notificationChannelCalls => 'පවුලේ ඇමතුම්';

  @override
  String get notificationChannelCallsHint =>
      'ඔබේ පවුලෙන් කෑම වේලාවන් සහ \"මෙහෙ එන්න\" ඇමතුම්';

  @override
  String notificationNewPoll(String name) {
    return '$name ගෙන් නව ඡන්ද විමසුමක්';
  }

  @override
  String notificationCallFrom(String name) {
    return '$name පවුලට කතා කරනවා';
  }

  @override
  String get security => 'ආරක්ෂාව';

  @override
  String get appLock => 'යෙදුම් අගුල';

  @override
  String appLockSubtitle(String method) {
    return 'FamNest විවෘත කිරීමට $method අවශ්‍යයි';
  }

  @override
  String get appLockUnavailable =>
      'මුලින්ම මෙම උපාංගයේ Face ID, Touch ID හෝ මුරකේතයක් සකසන්න';

  @override
  String get appLockNotEnabled => 'යෙදුම් අගුල සක්‍රිය කළේ නැත';

  @override
  String get lockWhen => 'අගුළු දමන්න';

  @override
  String get lockImmediately => 'පිටව ගිය වහාම';

  @override
  String get lockAfterOneMinute => 'විනාඩි 1කට පසු';

  @override
  String get lockAfterFifteenMinutes => 'විනාඩි 15කට පසු';

  @override
  String get lockedTitle => 'FamNest අගුළු දමා ඇත';

  @override
  String get lockedBody => 'ඔබේ පවුලේ චැට් ආරක්ෂිතයි.';

  @override
  String unlockWith(String method) {
    return '$method මගින් අගුල අරින්න';
  }

  @override
  String get unlockReason => 'FamNest අගුල අරින්න';

  @override
  String get enableLockReason => 'යෙදුම් අගුල සක්‍රිය කිරීමට තහවුරු කරන්න';

  @override
  String get disableLockReason => 'යෙදුම් අගුල අක්‍රිය කිරීමට තහවුරු කරන්න';

  @override
  String get eraseReason => 'සියලු FamNest දත්ත මැකීමට තහවුරු කරන්න';

  @override
  String get faceId => 'Face ID';

  @override
  String get touchId => 'Touch ID';

  @override
  String get faceUnlock => 'මුහුණෙන් අගුල ඇරීම';

  @override
  String get fingerprint => 'ඇඟිලි සලකුණ';

  @override
  String get biometrics => 'ජෛවමිතික';

  @override
  String get devicePasscode => 'උපාංග මුරකේතය';

  @override
  String get splashTagline => 'පෞද්ගලික පවුල් චැට්';

  @override
  String get splashFooter =>
      'අන්තයේ සිට අන්තය දක්වා සංකේතිත · අන්තර්ජාලය නැතිව ක්‍රියා කරයි';

  @override
  String startupFailed(String error) {
    return 'FamNest ආරම්භ කළ නොහැකි විය: $error';
  }
}

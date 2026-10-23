import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_si.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('si'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'FamNest'**
  String get appTitle;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your family\'s private chat'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Talk and share photos and files with your family over your home Wi-Fi. No internet, no accounts, no cloud — everything stays on your family\'s devices.'**
  String get welcomeBody;

  /// No description provided for @privacyPoint1.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted messages and files'**
  String get privacyPoint1;

  /// No description provided for @privacyPoint2.
  ///
  /// In en, this message translates to:
  /// **'Works on home Wi-Fi without internet'**
  String get privacyPoint2;

  /// No description provided for @privacyPoint3.
  ///
  /// In en, this message translates to:
  /// **'Stored only on your family\'s devices'**
  String get privacyPoint3;

  /// No description provided for @createFamily.
  ///
  /// In en, this message translates to:
  /// **'Set up a new family'**
  String get createFamily;

  /// No description provided for @createFamilyHint.
  ///
  /// In en, this message translates to:
  /// **'Make this device the family hub'**
  String get createFamilyHint;

  /// No description provided for @joinFamily.
  ///
  /// In en, this message translates to:
  /// **'Join my family'**
  String get joinFamily;

  /// No description provided for @joinFamilyHint.
  ///
  /// In en, this message translates to:
  /// **'Someone at home already set up FamNest'**
  String get joinFamilyHint;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @yourNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Mum, Dad, Nimal'**
  String get yourNameHint;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get nameRequired;

  /// No description provided for @familyName.
  ///
  /// In en, this message translates to:
  /// **'Family name'**
  String get familyName;

  /// No description provided for @familyNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. The Perera Family'**
  String get familyNameHint;

  /// No description provided for @familyNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a family name'**
  String get familyNameRequired;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// No description provided for @createFamilyTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your family'**
  String get createFamilyTitle;

  /// No description provided for @createFamilyBody.
  ///
  /// In en, this message translates to:
  /// **'This device becomes your family\'s hub. Keep it at home, charging and on Wi-Fi — a spare phone or tablet works great.'**
  String get createFamilyBody;

  /// No description provided for @createAction.
  ///
  /// In en, this message translates to:
  /// **'Create family'**
  String get createAction;

  /// No description provided for @creating.
  ///
  /// In en, this message translates to:
  /// **'Setting up…'**
  String get creating;

  /// No description provided for @inviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite your family'**
  String get inviteTitle;

  /// No description provided for @inviteBody.
  ///
  /// In en, this message translates to:
  /// **'On each family member\'s phone, install FamNest, tap \"Join my family\" and enter this invite code. They must be on the same Wi-Fi.'**
  String get inviteBody;

  /// No description provided for @inviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get inviteCode;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @hubAddress.
  ///
  /// In en, this message translates to:
  /// **'Hub address: {address}'**
  String hubAddress(String address);

  /// No description provided for @joinTitle.
  ///
  /// In en, this message translates to:
  /// **'Find your family'**
  String get joinTitle;

  /// No description provided for @searching.
  ///
  /// In en, this message translates to:
  /// **'Searching your Wi-Fi for family hubs…'**
  String get searching;

  /// No description provided for @noHubsFound.
  ///
  /// In en, this message translates to:
  /// **'No family hub found. Make sure you\'re on the same Wi-Fi as the hub device and that FamNest is running on it.'**
  String get noHubsFound;

  /// No description provided for @scanAgain.
  ///
  /// In en, this message translates to:
  /// **'Search again'**
  String get scanAgain;

  /// No description provided for @enterAddressManually.
  ///
  /// In en, this message translates to:
  /// **'Enter hub address manually'**
  String get enterAddressManually;

  /// No description provided for @hubAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Hub IP address'**
  String get hubAddressLabel;

  /// No description provided for @hubAddressHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 192.168.1.20'**
  String get hubAddressHint;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @couldNotReachHub.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach a family hub at that address.'**
  String get couldNotReachHub;

  /// No description provided for @joinFamilyNamed.
  ///
  /// In en, this message translates to:
  /// **'Join {family}'**
  String joinFamilyNamed(String family);

  /// No description provided for @enterInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the invite code shown on the hub device (Settings → Family hub).'**
  String get enterInviteCode;

  /// No description provided for @inviteCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invite codes have 16 letters and numbers'**
  String get inviteCodeInvalid;

  /// No description provided for @joinAction.
  ///
  /// In en, this message translates to:
  /// **'Join family'**
  String get joinAction;

  /// No description provided for @joining.
  ///
  /// In en, this message translates to:
  /// **'Joining…'**
  String get joining;

  /// No description provided for @wrongInviteCode.
  ///
  /// In en, this message translates to:
  /// **'That invite code isn\'t right. Check it on the hub device.'**
  String get wrongInviteCode;

  /// No description provided for @removedFromFamily.
  ///
  /// In en, this message translates to:
  /// **'This device was removed from the family.'**
  String get removedFromFamily;

  /// No description provided for @joinFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect to the family hub. Make sure you\'re on the same Wi-Fi.'**
  String get joinFailed;

  /// No description provided for @chats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chats;

  /// No description provided for @family.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get family;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newChat;

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroup;

  /// No description provided for @everyone.
  ///
  /// In en, this message translates to:
  /// **'Everyone in the family'**
  String get everyone;

  /// No description provided for @noFamilyMembersYet.
  ///
  /// In en, this message translates to:
  /// **'No one else has joined yet. Share the invite code from the hub device.'**
  String get noFamilyMembersYet;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to your family hub…'**
  String get connecting;

  /// No description provided for @searchingHub.
  ///
  /// In en, this message translates to:
  /// **'Looking for your family hub on this Wi-Fi…'**
  String get searchingHub;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Family hub not reachable. Messages will be sent when you\'re back on home Wi-Fi.'**
  String get offline;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @inviteCodeChanged.
  ///
  /// In en, this message translates to:
  /// **'The invite code was changed. Enter the new code to reconnect.'**
  String get inviteCodeChanged;

  /// No description provided for @enterNewCode.
  ///
  /// In en, this message translates to:
  /// **'Enter code'**
  String get enterNewCode;

  /// No description provided for @removedBanner.
  ///
  /// In en, this message translates to:
  /// **'This device was removed from the family.'**
  String get removedBanner;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @lastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen {time}'**
  String lastSeen(String time);

  /// No description provided for @offlineStatus.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offlineStatus;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @typing.
  ///
  /// In en, this message translates to:
  /// **'typing…'**
  String get typing;

  /// No description provided for @typingOne.
  ///
  /// In en, this message translates to:
  /// **'{name} is typing…'**
  String typingOne(String name);

  /// No description provided for @typingMany.
  ///
  /// In en, this message translates to:
  /// **'Several people are typing…'**
  String get typingMany;

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String membersCount(int count);

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageHint;

  /// No description provided for @attach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get attach;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @attachPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get attachPhoto;

  /// No description provided for @attachCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get attachCamera;

  /// No description provided for @attachFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get attachFile;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @messageDeleted.
  ///
  /// In en, this message translates to:
  /// **'This message was deleted'**
  String get messageDeleted;

  /// No description provided for @deleteForEveryone.
  ///
  /// In en, this message translates to:
  /// **'Delete for everyone'**
  String get deleteForEveryone;

  /// No description provided for @deleteForMe.
  ///
  /// In en, this message translates to:
  /// **'Delete for me'**
  String get deleteForMe;

  /// No description provided for @copyText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get copyText;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @openFile.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openFile;

  /// No description provided for @fileFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed — tap to retry'**
  String get fileFailed;

  /// No description provided for @couldNotOpenFile.
  ///
  /// In en, this message translates to:
  /// **'No app found to open this file'**
  String get couldNotOpenFile;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sending;

  /// No description provided for @failedToSend.
  ///
  /// In en, this message translates to:
  /// **'Not sent — tap to retry'**
  String get failedToSend;

  /// No description provided for @fileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'{name} is too large to send (max 200 MB)'**
  String fileTooLarge(String name);

  /// No description provided for @notConnectedAction.
  ///
  /// In en, this message translates to:
  /// **'Connect to your family hub first'**
  String get notConnectedAction;

  /// No description provided for @leftGroup.
  ///
  /// In en, this message translates to:
  /// **'You\'re no longer in this group'**
  String get leftGroup;

  /// No description provided for @emptyChat.
  ///
  /// In en, this message translates to:
  /// **'Say hello 👋'**
  String get emptyChat;

  /// No description provided for @groupInfo.
  ///
  /// In en, this message translates to:
  /// **'Group info'**
  String get groupInfo;

  /// No description provided for @contactInfo.
  ///
  /// In en, this message translates to:
  /// **'Contact info'**
  String get contactInfo;

  /// No description provided for @directEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Messages here are end-to-end encrypted. Not even the family hub can read them.'**
  String get directEncrypted;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Weekend plans'**
  String get groupNameHint;

  /// No description provided for @groupNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a group name'**
  String get groupNameRequired;

  /// No description provided for @chooseMembers.
  ///
  /// In en, this message translates to:
  /// **'Choose members'**
  String get chooseMembers;

  /// No description provided for @createGroup.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createGroup;

  /// No description provided for @editGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit group'**
  String get editGroup;

  /// No description provided for @leaveGroup.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get leaveGroup;

  /// No description provided for @leaveGroupConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave this group? You won\'t receive its messages anymore.'**
  String get leaveGroupConfirm;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute notifications'**
  String get mute;

  /// No description provided for @sharedMedia.
  ///
  /// In en, this message translates to:
  /// **'Photos & files'**
  String get sharedMedia;

  /// No description provided for @clearChat.
  ///
  /// In en, this message translates to:
  /// **'Clear chat on this device'**
  String get clearChat;

  /// No description provided for @clearChatConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete all messages in this chat from this device? Others keep their copies.'**
  String get clearChatConfirm;

  /// No description provided for @selectAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Select at least one member'**
  String get selectAtLeastOne;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @profileVisibility.
  ///
  /// In en, this message translates to:
  /// **'Your name and photo are shared only with your family, encrypted.'**
  String get profileVisibility;

  /// No description provided for @notificationsSetting.
  ///
  /// In en, this message translates to:
  /// **'Message notifications'**
  String get notificationsSetting;

  /// No description provided for @keepConnected.
  ///
  /// In en, this message translates to:
  /// **'Stay connected in background'**
  String get keepConnected;

  /// No description provided for @keepConnectedHint.
  ///
  /// In en, this message translates to:
  /// **'Shows a small ongoing notification so messages arrive instantly.'**
  String get keepConnectedHint;

  /// No description provided for @familyHub.
  ///
  /// In en, this message translates to:
  /// **'Family hub'**
  String get familyHub;

  /// No description provided for @hubRunning.
  ///
  /// In en, this message translates to:
  /// **'Running on this device'**
  String get hubRunning;

  /// No description provided for @hubStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get hubStopped;

  /// No description provided for @connectedTo.
  ///
  /// In en, this message translates to:
  /// **'Connected to {address}'**
  String connectedTo(String address);

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy & security'**
  String get privacy;

  /// No description provided for @privacySummary.
  ///
  /// In en, this message translates to:
  /// **'How FamNest keeps your family\'s data private'**
  String get privacySummary;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'• No internet or cloud: messages travel only over your home Wi-Fi between your family\'s devices.\n\n• Everything you see is stored only on this device. Chats are excluded from cloud backups.\n\n• Joining requires the family invite code. Devices and the hub verify each other, and all traffic is encrypted (AES-256-GCM).\n\n• Messages, photos, files, names and profile photos are end-to-end encrypted. The hub stores only encrypted data it cannot read.\n\n• Direct chats use a key only the two of you share, so other family members can\'t read them either.\n\n• Removing a member and issuing a new invite code locks them out.'**
  String get privacyBody;

  /// No description provided for @deviceId.
  ///
  /// In en, this message translates to:
  /// **'Device fingerprint'**
  String get deviceId;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(String version);

  /// No description provided for @leaveFamily.
  ///
  /// In en, this message translates to:
  /// **'Leave family & erase data'**
  String get leaveFamily;

  /// No description provided for @leaveFamilyConfirm.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes all messages, photos, files and keys from this device. If this device is the family hub, the hub and its history are deleted too and everyone will need to set up again.'**
  String get leaveFamilyConfirm;

  /// No description provided for @erase.
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get erase;

  /// No description provided for @hubOnlineCount.
  ///
  /// In en, this message translates to:
  /// **'{online} of {total} members online'**
  String hubOnlineCount(int online, int total);

  /// No description provided for @rotateCode.
  ///
  /// In en, this message translates to:
  /// **'Issue new invite code'**
  String get rotateCode;

  /// No description provided for @rotateCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Use after removing someone'**
  String get rotateCodeHint;

  /// No description provided for @rotateCodeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Everyone will be disconnected and must enter the new code once. Old codes stop working.'**
  String get rotateCodeConfirm;

  /// No description provided for @removeMember.
  ///
  /// In en, this message translates to:
  /// **'Remove from family'**
  String get removeMember;

  /// No description provided for @removeMemberConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from the family? Their device will be disconnected. Issue a new invite code afterwards so it can\'t rejoin.'**
  String removeMemberConfirm(String name);

  /// No description provided for @startHub.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startHub;

  /// No description provided for @stopHub.
  ///
  /// In en, this message translates to:
  /// **'Stop hub'**
  String get stopHub;

  /// No description provided for @stopHubConfirm.
  ///
  /// In en, this message translates to:
  /// **'While the hub is stopped, nobody in the family can send or receive messages.'**
  String get stopHubConfirm;

  /// No description provided for @hubTips.
  ///
  /// In en, this message translates to:
  /// **'Keep this device plugged in and on home Wi-Fi. The hub keeps running in the background and starts again after a restart.'**
  String get hubTips;

  /// No description provided for @hubIosNote.
  ///
  /// In en, this message translates to:
  /// **'On iPhone and iPad the hub only runs while FamNest is open. For an always-on hub, use an Android device or a home computer.'**
  String get hubIosNote;

  /// No description provided for @batteryOptimization.
  ///
  /// In en, this message translates to:
  /// **'Allow running in background'**
  String get batteryOptimization;

  /// No description provided for @batteryOptimizationHint.
  ///
  /// In en, this message translates to:
  /// **'Stops Android from pausing the hub to save battery'**
  String get batteryOptimizationHint;

  /// No description provided for @renameFamily.
  ///
  /// In en, this message translates to:
  /// **'Rename family'**
  String get renameFamily;

  /// No description provided for @hubError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the family hub: {error}'**
  String hubError(String error);

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {error}'**
  String somethingWentWrong(String error);

  /// No description provided for @familyActions.
  ///
  /// In en, this message translates to:
  /// **'Family actions'**
  String get familyActions;

  /// No description provided for @poll.
  ///
  /// In en, this message translates to:
  /// **'Poll'**
  String get poll;

  /// No description provided for @callFamily.
  ///
  /// In en, this message translates to:
  /// **'Call the family'**
  String get callFamily;

  /// No description provided for @callFamilyHint.
  ///
  /// In en, this message translates to:
  /// **'Everyone gets a notification and can answer with one tap.'**
  String get callFamilyHint;

  /// No description provided for @callBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast is ready!'**
  String get callBreakfast;

  /// No description provided for @callLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch is ready!'**
  String get callLunch;

  /// No description provided for @callTea.
  ///
  /// In en, this message translates to:
  /// **'Tea time!'**
  String get callTea;

  /// No description provided for @callDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner is ready!'**
  String get callDinner;

  /// No description provided for @callReady.
  ///
  /// In en, this message translates to:
  /// **'It\'s ready — come and get it!'**
  String get callReady;

  /// No description provided for @callComeHere.
  ///
  /// In en, this message translates to:
  /// **'Everyone, please come here'**
  String get callComeHere;

  /// No description provided for @callCustom.
  ///
  /// In en, this message translates to:
  /// **'Family call'**
  String get callCustom;

  /// No description provided for @customCall.
  ///
  /// In en, this message translates to:
  /// **'Custom call…'**
  String get customCall;

  /// No description provided for @customCallHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Leaving for the temple in 10 minutes'**
  String get customCallHint;

  /// No description provided for @answerComing.
  ///
  /// In en, this message translates to:
  /// **'On my way'**
  String get answerComing;

  /// No description provided for @answerSoon.
  ///
  /// In en, this message translates to:
  /// **'In 5 minutes'**
  String get answerSoon;

  /// No description provided for @answerSkip.
  ///
  /// In en, this message translates to:
  /// **'Can\'t come'**
  String get answerSkip;

  /// No description provided for @waitingForReplies.
  ///
  /// In en, this message translates to:
  /// **'Waiting for replies…'**
  String get waitingForReplies;

  /// No description provided for @createPoll.
  ///
  /// In en, this message translates to:
  /// **'Create a poll'**
  String get createPoll;

  /// No description provided for @createPollHint.
  ///
  /// In en, this message translates to:
  /// **'Let the family vote'**
  String get createPollHint;

  /// No description provided for @pollQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get pollQuestion;

  /// No description provided for @pollQuestionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. What should we cook on Sunday?'**
  String get pollQuestionHint;

  /// No description provided for @pollOption.
  ///
  /// In en, this message translates to:
  /// **'Option {number}'**
  String pollOption(int number);

  /// No description provided for @addOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get addOption;

  /// No description provided for @allowMultiple.
  ///
  /// In en, this message translates to:
  /// **'Allow multiple answers'**
  String get allowMultiple;

  /// No description provided for @sendPoll.
  ///
  /// In en, this message translates to:
  /// **'Send poll'**
  String get sendPoll;

  /// No description provided for @pollClosed.
  ///
  /// In en, this message translates to:
  /// **'Poll closed'**
  String get pollClosed;

  /// No description provided for @pollChooseOne.
  ///
  /// In en, this message translates to:
  /// **'Choose one'**
  String get pollChooseOne;

  /// No description provided for @pollChooseMany.
  ///
  /// In en, this message translates to:
  /// **'Choose one or more'**
  String get pollChooseMany;

  /// No description provided for @votesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No votes yet} =1{1 vote} other{{count} votes}}'**
  String votesCount(int count);

  /// No description provided for @closePoll.
  ///
  /// In en, this message translates to:
  /// **'Close poll'**
  String get closePoll;

  /// No description provided for @familyMember.
  ///
  /// In en, this message translates to:
  /// **'Family member'**
  String get familyMember;

  /// No description provided for @notificationChannelMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get notificationChannelMessages;

  /// No description provided for @notificationChannelCalls.
  ///
  /// In en, this message translates to:
  /// **'Family calls'**
  String get notificationChannelCalls;

  /// No description provided for @notificationChannelCallsHint.
  ///
  /// In en, this message translates to:
  /// **'Meal times and \"come here\" calls from your family'**
  String get notificationChannelCallsHint;

  /// No description provided for @notificationNewPoll.
  ///
  /// In en, this message translates to:
  /// **'New poll from {name}'**
  String notificationNewPoll(String name);

  /// No description provided for @notificationCallFrom.
  ///
  /// In en, this message translates to:
  /// **'{name} is calling the family'**
  String notificationCallFrom(String name);

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @appLock.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get appLock;

  /// No description provided for @appLockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Require {method} to open FamNest'**
  String appLockSubtitle(String method);

  /// No description provided for @appLockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Set up Face ID, Touch ID or a passcode on this device first'**
  String get appLockUnavailable;

  /// No description provided for @appLockNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'App lock was not turned on'**
  String get appLockNotEnabled;

  /// No description provided for @lockWhen.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get lockWhen;

  /// No description provided for @lockImmediately.
  ///
  /// In en, this message translates to:
  /// **'Immediately after leaving'**
  String get lockImmediately;

  /// No description provided for @lockAfterOneMinute.
  ///
  /// In en, this message translates to:
  /// **'After 1 minute'**
  String get lockAfterOneMinute;

  /// No description provided for @lockAfterFifteenMinutes.
  ///
  /// In en, this message translates to:
  /// **'After 15 minutes'**
  String get lockAfterFifteenMinutes;

  /// No description provided for @lockedTitle.
  ///
  /// In en, this message translates to:
  /// **'FamNest is locked'**
  String get lockedTitle;

  /// No description provided for @lockedBody.
  ///
  /// In en, this message translates to:
  /// **'Your family chats are protected.'**
  String get lockedBody;

  /// No description provided for @unlockWith.
  ///
  /// In en, this message translates to:
  /// **'Unlock with {method}'**
  String unlockWith(String method);

  /// No description provided for @unlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock FamNest'**
  String get unlockReason;

  /// No description provided for @enableLockReason.
  ///
  /// In en, this message translates to:
  /// **'Confirm to turn on app lock'**
  String get enableLockReason;

  /// No description provided for @disableLockReason.
  ///
  /// In en, this message translates to:
  /// **'Confirm to turn off app lock'**
  String get disableLockReason;

  /// No description provided for @eraseReason.
  ///
  /// In en, this message translates to:
  /// **'Confirm to erase all FamNest data'**
  String get eraseReason;

  /// No description provided for @faceId.
  ///
  /// In en, this message translates to:
  /// **'Face ID'**
  String get faceId;

  /// No description provided for @touchId.
  ///
  /// In en, this message translates to:
  /// **'Touch ID'**
  String get touchId;

  /// No description provided for @faceUnlock.
  ///
  /// In en, this message translates to:
  /// **'Face unlock'**
  String get faceUnlock;

  /// No description provided for @fingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get fingerprint;

  /// No description provided for @biometrics.
  ///
  /// In en, this message translates to:
  /// **'Biometrics'**
  String get biometrics;

  /// No description provided for @devicePasscode.
  ///
  /// In en, this message translates to:
  /// **'Device passcode'**
  String get devicePasscode;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Private family chat'**
  String get splashTagline;

  /// No description provided for @splashFooter.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted · Works without internet'**
  String get splashFooter;

  /// No description provided for @startupFailed.
  ///
  /// In en, this message translates to:
  /// **'FamNest could not start: {error}'**
  String startupFailed(String error);
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
      <String>['en', 'si'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'si':
      return AppLocalizationsSi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FamNest';

  @override
  String get welcomeTitle => 'Your family\'s private chat';

  @override
  String get welcomeBody =>
      'Talk and share photos and files with your family over your home Wi-Fi. No internet, no accounts, no cloud — everything stays on your family\'s devices.';

  @override
  String get privacyPoint1 => 'End-to-end encrypted messages and files';

  @override
  String get privacyPoint2 => 'Works on home Wi-Fi without internet';

  @override
  String get privacyPoint3 => 'Stored only on your family\'s devices';

  @override
  String get createFamily => 'Set up a new family';

  @override
  String get createFamilyHint => 'Make this device the family hub';

  @override
  String get joinFamily => 'Join my family';

  @override
  String get joinFamilyHint => 'Someone at home already set up FamNest';

  @override
  String get yourName => 'Your name';

  @override
  String get yourNameHint => 'e.g. Mum, Dad, Nimal';

  @override
  String get nameRequired => 'Please enter your name';

  @override
  String get familyName => 'Family name';

  @override
  String get familyNameHint => 'e.g. The Perera Family';

  @override
  String get familyNameRequired => 'Please enter a family name';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get createFamilyTitle => 'Set up your family';

  @override
  String get createFamilyBody =>
      'This device becomes your family\'s hub. Keep it at home, charging and on Wi-Fi — a spare phone or tablet works great.';

  @override
  String get createAction => 'Create family';

  @override
  String get creating => 'Setting up…';

  @override
  String get inviteTitle => 'Invite your family';

  @override
  String get inviteBody =>
      'On each family member\'s phone, install FamNest, tap \"Join my family\" and enter this invite code. They must be on the same Wi-Fi.';

  @override
  String get inviteCode => 'Invite code';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get continueAction => 'Continue';

  @override
  String hubAddress(String address) {
    return 'Hub address: $address';
  }

  @override
  String get joinTitle => 'Find your family';

  @override
  String get searching => 'Searching your Wi-Fi for family hubs…';

  @override
  String get noHubsFound =>
      'No family hub found. Make sure you\'re on the same Wi-Fi as the hub device and that FamNest is running on it.';

  @override
  String get scanAgain => 'Search again';

  @override
  String get enterAddressManually => 'Enter hub address manually';

  @override
  String get hubAddressLabel => 'Hub IP address';

  @override
  String get hubAddressHint => 'e.g. 192.168.1.20';

  @override
  String get connect => 'Connect';

  @override
  String get couldNotReachHub =>
      'Couldn\'t reach a family hub at that address.';

  @override
  String joinFamilyNamed(String family) {
    return 'Join $family';
  }

  @override
  String get enterInviteCode =>
      'Enter the invite code shown on the hub device (Settings → Family hub).';

  @override
  String get inviteCodeInvalid => 'Invite codes have 16 letters and numbers';

  @override
  String get joinAction => 'Join family';

  @override
  String get joining => 'Joining…';

  @override
  String get wrongInviteCode =>
      'That invite code isn\'t right. Check it on the hub device.';

  @override
  String get removedFromFamily => 'This device was removed from the family.';

  @override
  String get joinFailed =>
      'Couldn\'t connect to the family hub. Make sure you\'re on the same Wi-Fi.';

  @override
  String get chats => 'Chats';

  @override
  String get family => 'Family';

  @override
  String get settings => 'Settings';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get newChat => 'New chat';

  @override
  String get newGroup => 'New group';

  @override
  String get everyone => 'Everyone in the family';

  @override
  String get noFamilyMembersYet =>
      'No one else has joined yet. Share the invite code from the hub device.';

  @override
  String get connecting => 'Connecting to your family hub…';

  @override
  String get searchingHub => 'Looking for your family hub on this Wi-Fi…';

  @override
  String get offline =>
      'Family hub not reachable. Messages will be sent when you\'re back on home Wi-Fi.';

  @override
  String get retry => 'Retry';

  @override
  String get inviteCodeChanged =>
      'The invite code was changed. Enter the new code to reconnect.';

  @override
  String get enterNewCode => 'Enter code';

  @override
  String get removedBanner => 'This device was removed from the family.';

  @override
  String get online => 'Online';

  @override
  String lastSeen(String time) {
    return 'Last seen $time';
  }

  @override
  String get offlineStatus => 'Offline';

  @override
  String get you => 'You';

  @override
  String get typing => 'typing…';

  @override
  String typingOne(String name) {
    return '$name is typing…';
  }

  @override
  String get typingMany => 'Several people are typing…';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get messageHint => 'Message';

  @override
  String get attach => 'Attach';

  @override
  String get send => 'Send';

  @override
  String get attachPhoto => 'Photos';

  @override
  String get attachCamera => 'Camera';

  @override
  String get attachFile => 'File';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get messageDeleted => 'This message was deleted';

  @override
  String get deleteForEveryone => 'Delete for everyone';

  @override
  String get deleteForMe => 'Delete for me';

  @override
  String get copyText => 'Copy text';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get openFile => 'Open';

  @override
  String get fileFailed => 'Download failed — tap to retry';

  @override
  String get couldNotOpenFile => 'No app found to open this file';

  @override
  String get sending => 'Sending…';

  @override
  String get failedToSend => 'Not sent — tap to retry';

  @override
  String fileTooLarge(String name) {
    return '$name is too large to send (max 200 MB)';
  }

  @override
  String get notConnectedAction => 'Connect to your family hub first';

  @override
  String get leftGroup => 'You\'re no longer in this group';

  @override
  String get emptyChat => 'Say hello 👋';

  @override
  String get groupInfo => 'Group info';

  @override
  String get contactInfo => 'Contact info';

  @override
  String get directEncrypted =>
      'Messages here are end-to-end encrypted. Not even the family hub can read them.';

  @override
  String get groupName => 'Group name';

  @override
  String get groupNameHint => 'e.g. Weekend plans';

  @override
  String get groupNameRequired => 'Please enter a group name';

  @override
  String get chooseMembers => 'Choose members';

  @override
  String get createGroup => 'Create';

  @override
  String get editGroup => 'Edit group';

  @override
  String get leaveGroup => 'Leave group';

  @override
  String get leaveGroupConfirm =>
      'Leave this group? You won\'t receive its messages anymore.';

  @override
  String get mute => 'Mute notifications';

  @override
  String get sharedMedia => 'Photos & files';

  @override
  String get clearChat => 'Clear chat on this device';

  @override
  String get clearChatConfirm =>
      'Delete all messages in this chat from this device? Others keep their copies.';

  @override
  String get selectAtLeastOne => 'Select at least one member';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get profileVisibility =>
      'Your name and photo are shared only with your family, encrypted.';

  @override
  String get notificationsSetting => 'Message notifications';

  @override
  String get keepConnected => 'Stay connected in background';

  @override
  String get keepConnectedHint =>
      'Shows a small ongoing notification so messages arrive instantly.';

  @override
  String get familyHub => 'Family hub';

  @override
  String get hubRunning => 'Running on this device';

  @override
  String get hubStopped => 'Stopped';

  @override
  String connectedTo(String address) {
    return 'Connected to $address';
  }

  @override
  String get privacy => 'Privacy & security';

  @override
  String get privacySummary => 'How FamNest keeps your family\'s data private';

  @override
  String get privacyBody =>
      '• No internet or cloud: messages travel only over your home Wi-Fi between your family\'s devices.\n\n• Everything you see is stored only on this device. Chats are excluded from cloud backups.\n\n• Joining requires the family invite code. Devices and the hub verify each other, and all traffic is encrypted (AES-256-GCM).\n\n• Messages, photos, files, names and profile photos are end-to-end encrypted. The hub stores only encrypted data it cannot read.\n\n• Direct chats use a key only the two of you share, so other family members can\'t read them either.\n\n• Removing a member and issuing a new invite code locks them out.';

  @override
  String get deviceId => 'Device fingerprint';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get leaveFamily => 'Leave family & erase data';

  @override
  String get leaveFamilyConfirm =>
      'This permanently deletes all messages, photos, files and keys from this device. If this device is the family hub, the hub and its history are deleted too and everyone will need to set up again.';

  @override
  String get erase => 'Erase';

  @override
  String hubOnlineCount(int online, int total) {
    return '$online of $total members online';
  }

  @override
  String get rotateCode => 'Issue new invite code';

  @override
  String get rotateCodeHint => 'Use after removing someone';

  @override
  String get rotateCodeConfirm =>
      'Everyone will be disconnected and must enter the new code once. Old codes stop working.';

  @override
  String get removeMember => 'Remove from family';

  @override
  String removeMemberConfirm(String name) {
    return 'Remove $name from the family? Their device will be disconnected. Issue a new invite code afterwards so it can\'t rejoin.';
  }

  @override
  String get startHub => 'Start';

  @override
  String get stopHub => 'Stop hub';

  @override
  String get stopHubConfirm =>
      'While the hub is stopped, nobody in the family can send or receive messages.';

  @override
  String get hubTips =>
      'Keep this device plugged in and on home Wi-Fi. The hub keeps running in the background and starts again after a restart.';

  @override
  String get hubIosNote =>
      'On iPhone and iPad the hub only runs while FamNest is open. For an always-on hub, use an Android device or a home computer.';

  @override
  String get batteryOptimization => 'Allow running in background';

  @override
  String get batteryOptimizationHint =>
      'Stops Android from pausing the hub to save battery';

  @override
  String get renameFamily => 'Rename family';

  @override
  String hubError(String error) {
    return 'Couldn\'t start the family hub: $error';
  }

  @override
  String somethingWentWrong(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String get familyActions => 'Family actions';

  @override
  String get poll => 'Poll';

  @override
  String get callFamily => 'Call the family';

  @override
  String get callFamilyHint =>
      'Everyone gets a notification and can answer with one tap.';

  @override
  String get callBreakfast => 'Breakfast is ready!';

  @override
  String get callLunch => 'Lunch is ready!';

  @override
  String get callTea => 'Tea time!';

  @override
  String get callDinner => 'Dinner is ready!';

  @override
  String get callReady => 'It\'s ready — come and get it!';

  @override
  String get callComeHere => 'Everyone, please come here';

  @override
  String get callCustom => 'Family call';

  @override
  String get customCall => 'Custom call…';

  @override
  String get customCallHint => 'e.g. Leaving for the temple in 10 minutes';

  @override
  String get answerComing => 'On my way';

  @override
  String get answerSoon => 'In 5 minutes';

  @override
  String get answerSkip => 'Can\'t come';

  @override
  String get waitingForReplies => 'Waiting for replies…';

  @override
  String get createPoll => 'Create a poll';

  @override
  String get createPollHint => 'Let the family vote';

  @override
  String get pollQuestion => 'Question';

  @override
  String get pollQuestionHint => 'e.g. What should we cook on Sunday?';

  @override
  String pollOption(int number) {
    return 'Option $number';
  }

  @override
  String get addOption => 'Add option';

  @override
  String get allowMultiple => 'Allow multiple answers';

  @override
  String get sendPoll => 'Send poll';

  @override
  String get pollClosed => 'Poll closed';

  @override
  String get pollChooseOne => 'Choose one';

  @override
  String get pollChooseMany => 'Choose one or more';

  @override
  String votesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '1 vote',
      zero: 'No votes yet',
    );
    return '$_temp0';
  }

  @override
  String get closePoll => 'Close poll';

  @override
  String get familyMember => 'Family member';

  @override
  String get notificationChannelMessages => 'Messages';

  @override
  String get notificationChannelCalls => 'Family calls';

  @override
  String get notificationChannelCallsHint =>
      'Meal times and \"come here\" calls from your family';

  @override
  String notificationNewPoll(String name) {
    return 'New poll from $name';
  }

  @override
  String notificationCallFrom(String name) {
    return '$name is calling the family';
  }

  @override
  String get security => 'Security';

  @override
  String get appLock => 'App lock';

  @override
  String appLockSubtitle(String method) {
    return 'Require $method to open FamNest';
  }

  @override
  String get appLockUnavailable =>
      'Set up Face ID, Touch ID or a passcode on this device first';

  @override
  String get appLockNotEnabled => 'App lock was not turned on';

  @override
  String get lockWhen => 'Lock';

  @override
  String get lockImmediately => 'Immediately after leaving';

  @override
  String get lockAfterOneMinute => 'After 1 minute';

  @override
  String get lockAfterFifteenMinutes => 'After 15 minutes';

  @override
  String get lockedTitle => 'FamNest is locked';

  @override
  String get lockedBody => 'Your family chats are protected.';

  @override
  String unlockWith(String method) {
    return 'Unlock with $method';
  }

  @override
  String get unlockReason => 'Unlock FamNest';

  @override
  String get enableLockReason => 'Confirm to turn on app lock';

  @override
  String get disableLockReason => 'Confirm to turn off app lock';

  @override
  String get eraseReason => 'Confirm to erase all FamNest data';

  @override
  String get faceId => 'Face ID';

  @override
  String get touchId => 'Touch ID';

  @override
  String get faceUnlock => 'Face unlock';

  @override
  String get fingerprint => 'Fingerprint';

  @override
  String get biometrics => 'Biometrics';

  @override
  String get devicePasscode => 'Device passcode';

  @override
  String get splashTagline => 'Private family chat';

  @override
  String get splashFooter => 'End-to-end encrypted · Works without internet';

  @override
  String startupFailed(String error) {
    return 'FamNest could not start: $error';
  }
}

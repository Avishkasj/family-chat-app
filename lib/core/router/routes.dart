abstract final class Routes {
  static const home = '/';
  static const welcome = '/welcome';
  static const createFamily = '/welcome/create';
  static const joinFamily = '/welcome/join';
  static const joinCode = '/welcome/join/code';
  static const newGroup = '/group/new';
  static const profile = '/profile';
  static const hub = '/hub';
  static const viewer = '/viewer';

  static String chat(String id) => '/chat/${Uri.encodeComponent(id)}';
  static String chatInfo(String id) => '${chat(id)}/info';
  static String editGroup(String id) => '/group/${Uri.encodeComponent(id)}/edit';
}

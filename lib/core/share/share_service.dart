import 'dart:typed_data';

/// Sharing through the system share sheet. The app sends nothing itself: the player picks
/// the target app. Game and UI code depend on this interface only.
abstract class ShareService {
  /// Shares a score; [image] is the share card PNG (may be null).
  Future<void> shareScore({required int score, Uint8List? image});

  Future<void> shareAchievement({required String title, Uint8List? image});

  /// Invites to the game. Does nothing while there is no share link.
  Future<void> shareApp();
}

/// Builds the texts and delegates the actual sending to [send].
abstract class BaseShareService implements ShareService {
  String get gameName;

  /// The link added on a new line under each message; null or empty adds no link.
  String? get link;

  String _withLink(String text) {
    final l = link;
    return l == null || l.isEmpty ? text : '$text\n$l';
  }

  String scoreText(int score) =>
      _withLink('This is my high score in $gameName: $score. Can you beat it?');

  String achievementText(String title) =>
      _withLink('I unlocked "$title" in $gameName! Can you beat it?');

  String appText() => _withLink('Try $gameName!');

  Future<void> send(String text, Uint8List? image);

  @override
  Future<void> shareScore({required int score, Uint8List? image}) =>
      send(scoreText(score), image);

  @override
  Future<void> shareAchievement({required String title, Uint8List? image}) =>
      send(achievementText(title), image);

  @override
  Future<void> shareApp() async {
    final l = link;
    if (l == null || l.isEmpty) return;
    await send(appText(), null);
  }
}

/// Records what would be shared (tests).
class FakeShareService extends BaseShareService {
  FakeShareService({this.gameName = 'Block Fall', this.link});

  @override
  final String gameName;
  @override
  final String? link;

  final List<({String text, Uint8List? image})> sent = [];

  @override
  Future<void> send(String text, Uint8List? image) async =>
      sent.add((text: text, image: image));
}

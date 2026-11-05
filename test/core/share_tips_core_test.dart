import 'dart:io';

import 'package:blockfall/core/config/app_config.dart';
import 'package:blockfall/core/share/share_service.dart';
import 'package:blockfall/core/tips/tip_service.dart';
import 'package:blockfall/game/tips.dart';
import 'package:flutter_test/flutter_test.dart';

AppConfig configWith(String mode, String url) {
  final base = File('app.config.yaml').readAsStringSync();
  final cut = base.indexOf('\nshare:');
  final end = base.indexOf('\n# Retention');
  return AppConfig.fromYamlString(
    '${base.substring(0, cut)}\nshare:\n  link_mode: $mode\n'
    '  internal_test_url: "$url"\n${base.substring(end)}',
  );
}

void main() {
  group('tips', () {
    test('every tip is non-empty, at most 80 characters and unique', () {
      expect(gameTips.length, greaterThanOrEqualTo(15));
      for (final t in gameTips) {
        expect(t.trim(), isNotEmpty);
        expect(t.length, lessThanOrEqualTo(80), reason: t);
      }
      expect(gameTips.toSet().length, gameTips.length);
    });

    test('tip of the day is stable per day and changes by day', () {
      final svc = TipService();
      expect(svc.tipOfTheDay(100), svc.tipOfTheDay(100));
      expect(svc.tipOfTheDay(100), isNot(svc.tipOfTheDay(101)));
    });
  });

  group('share texts', () {
    test('without a link no link is added and Share app is a no-op', () async {
      final f = FakeShareService();
      await f.shareScore(score: 42);
      await f.shareAchievement(title: 'First Row');
      await f.shareApp();
      expect(f.sent.map((e) => e.text), [
        'This is my high score in Block Fall: 42. Can you beat it?',
        'I unlocked "First Row" in Block Fall! Can you beat it?',
      ]);
    });

    test('with a link it follows the message on a new line', () async {
      final f = FakeShareService(link: 'https://example.com/x');
      await f.shareScore(score: 7);
      await f.shareAchievement(title: 'First Row');
      await f.shareApp();
      const link = '\nhttps://example.com/x';
      expect(f.sent.map((e) => e.text), [
        'This is my high score in Block Fall: 7. Can you beat it?$link',
        'I unlocked "First Row" in Block Fall! Can you beat it?$link',
        'Try Block Fall!$link',
      ]);
    });
  });

  group('share link config', () {
    test('default is internal_test with the internal test URL', () {
      final c = AppConfig.fromYamlString(
        File('app.config.yaml').readAsStringSync(),
      );
      expect(c.share.linkMode, ShareLinkMode.internalTest);
      expect(
        c.shareLink,
        'https://play.google.com/apps/internaltest/4700823638704685278',
      );
    });

    test('store mode uses the Play Store page of the package', () {
      final c = configWith('store', 'https://example.com/t');
      expect(
        c.shareLink,
        'https://play.google.com/store/apps/details?id=${c.packageName}',
      );
    });

    test('internal_test with an empty URL, and off, give no link', () {
      expect(configWith('internal_test', '').shareLink, isNull);
      expect(configWith('off', 'https://example.com/t').shareLink, isNull);
    });
  });
}

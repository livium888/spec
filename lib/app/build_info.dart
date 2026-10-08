/// Which build is installed. CI passes these with --dart-define; local runs show "dev".
class BuildInfo {
  const BuildInfo._();
  static const number = String.fromEnvironment('BUILD_NUMBER', defaultValue: 'dev');
  static const commit = String.fromEnvironment('GIT_SHA', defaultValue: '');
  static const builtAt = String.fromEnvironment('BUILD_TIME', defaultValue: '');

  static String get shortCommit => commit.length >= 7 ? commit.substring(0, 7) : commit;

  /// "Build 12 (a1b2c3d)", matching the title of the release it was downloaded from.
  static String get label =>
      number == 'dev' ? 'Local development build' : 'Build $number${shortCommit.isEmpty ? '' : ' ($shortCommit)'}';
}

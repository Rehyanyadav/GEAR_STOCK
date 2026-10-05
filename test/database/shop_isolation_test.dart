import 'package:flutter_test/flutter_test.dart';
import 'package:gearstock/core/providers/database_provider.dart';

void main() {
  test('auth refresh for the same user does not invalidate account state', () {
    expect(authUserChanged('user-a', 'user-a'), isFalse);
  });

  test('changing accounts invalidates account-scoped state', () {
    expect(authUserChanged(null, 'user-a'), isTrue);
    expect(authUserChanged('user-a', 'user-b'), isTrue);
    expect(authUserChanged('user-a', null), isTrue);
  });

  test(
    'local database identity is stable per account and isolated across users',
    () {
      expect(
        localDatabaseNameForUser('user-a'),
        localDatabaseNameForUser('user-a'),
      );
      expect(
        localDatabaseNameForUser('user-a'),
        isNot(localDatabaseNameForUser('user-b')),
      );
      expect(
        localDatabaseNameForUser(null),
        isNot(localDatabaseNameForUser('user-a')),
      );
    },
  );
}

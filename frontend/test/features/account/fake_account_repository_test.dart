import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/account/data/account_repository.dart';

import '../../support/fake_account_repository.dart';

void main() {
  group('FakeAccountRepository', () {
    test('starts signed out', () {
      final repo = FakeAccountRepository();
      expect(repo.currentAccount, isNull);
      expect(repo.sessionToken, isNull);
    });

    test('register rejects a bad email or weak password locally', () async {
      final repo = FakeAccountRepository();
      await expectLater(
        repo.register(email: 'not-an-email', password: 'longenoughpass'),
        throwsA(
          isA<AccountException>().having(
            (e) => e.failure,
            'failure',
            AccountFailure.invalidEmail,
          ),
        ),
      );
      await expectLater(
        repo.register(email: 'sam@example.test', password: 'short'),
        throwsA(
          isA<AccountException>().having(
            (e) => e.failure,
            'failure',
            AccountFailure.weakPassword,
          ),
        ),
      );
      expect(repo.currentAccount, isNull);
    });

    test('register signs in on success', () async {
      final repo = FakeAccountRepository();
      final account = await repo.register(
        email: 'Sam@Example.test',
        password: 'longenoughpass',
      );
      expect(account.email, 'sam@example.test');
      expect(repo.currentAccount, account);
      expect(repo.sessionToken, isNotNull);
    });

    test('register with a taken email fails', () async {
      final repo = FakeAccountRepository();
      await repo.register(email: 'sam@example.test', password: 'longenoughpass');
      await repo.signOut();

      await expectLater(
        repo.register(email: 'sam@example.test', password: 'anotherpass1'),
        throwsA(
          isA<AccountException>().having(
            (e) => e.failure,
            'failure',
            AccountFailure.emailTaken,
          ),
        ),
      );
    });

    test('signIn with the wrong password fails without revealing why', () async {
      final repo = FakeAccountRepository();
      await repo.register(email: 'sam@example.test', password: 'longenoughpass');
      await repo.signOut();

      await expectLater(
        repo.signIn(email: 'sam@example.test', password: 'wrongpassword'),
        throwsA(
          isA<AccountException>().having(
            (e) => e.failure,
            'failure',
            AccountFailure.invalidCredentials,
          ),
        ),
      );
      expect(repo.currentAccount, isNull);
    });

    test('signOut always clears locally', () async {
      final repo = FakeAccountRepository();
      await repo.register(email: 'sam@example.test', password: 'longenoughpass');
      await repo.signOut();

      expect(repo.currentAccount, isNull);
      expect(repo.sessionToken, isNull);
    });

    test('expireSession clears locally without touching accounts', () async {
      final repo = FakeAccountRepository();
      await repo.register(email: 'sam@example.test', password: 'longenoughpass');
      await repo.expireSession();

      expect(repo.currentAccount, isNull);
      final again = await repo.signIn(
        email: 'sam@example.test',
        password: 'longenoughpass',
      );
      expect(again.email, 'sam@example.test');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pawgo/services/role_service.dart';

// ---------------------------------------------------------------------------
// Test doubles. We mock the smallest possible slice of the Supabase client
// chain that `markOnboardingComplete()` touches:
//   client.from('users').update({...}).eq('id', <uid>)
// plus the auth.currentUser lookup.
// ---------------------------------------------------------------------------

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockUser extends Mock implements User {}

class _MockQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class _MockFilterBuilder extends Mock implements PostgrestFilterBuilder<dynamic> {}

void main() {
  setUpAll(() {
    // Mocktail needs fallback values for any() with non-trivial types.
    registerFallbackValue(<String, dynamic>{});
  });

  group('RoleService.markOnboardingComplete', () {
    late RoleService service;
    late _MockSupabaseClient client;
    late _MockGoTrueClient auth;
    late _MockUser user;
    late _MockQueryBuilder usersTable;
    late _MockFilterBuilder updateBuilder;
    late _MockFilterBuilder eqBuilder;

    setUp(() {
      service = RoleService.instance;
      service.resetForTesting();

      client = _MockSupabaseClient();
      auth = _MockGoTrueClient();
      user = _MockUser();
      usersTable = _MockQueryBuilder();
      updateBuilder = _MockFilterBuilder();
      eqBuilder = _MockFilterBuilder();

      when(() => user.id).thenReturn('user-abc');
      when(() => auth.currentUser).thenReturn(user);
      when(() => client.auth).thenReturn(auth);
      // The Postgrest builder hierarchy implements Future, so mocktail wants
      // thenAnswer for every stub in the chain.
      when(() => client.from('users')).thenAnswer((_) => usersTable);
      when(() => usersTable.update(any())).thenAnswer((_) => updateBuilder);
      when(() => updateBuilder.eq(any(), any())).thenAnswer((_) => eqBuilder);
      // `await eqBuilder` calls eqBuilder.then(onValue) under the hood — the
      // mock needs to forward to a completed Future so awaiting it
      // resolves instead of returning null.
      when(() => eqBuilder.then<dynamic>(
            any(),
            onError: any(named: 'onError'),
          )).thenAnswer((invocation) {
        final onValue = invocation.positionalArguments.first as dynamic
            Function(dynamic);
        return Future.value(null).then(onValue);
      });

      service.testClient = client;
    });

    tearDown(() {
      service.resetForTesting();
    });

    test('writes onboarding_completed_at = now() for the current user',
        () async {
      await service.markOnboardingComplete();

      final capturedRaw =
          verify(() => usersTable.update(captureAny())).captured.single;
      final captured = Map<String, dynamic>.from(capturedRaw as Map);
      expect(captured.keys, contains('onboarding_completed_at'));
      // The value is generated as `DateTime.now().toIso8601String()` —
      // assert it's a parseable timestamp instead of an exact value.
      final iso = captured['onboarding_completed_at'] as String;
      expect(DateTime.tryParse(iso), isNotNull,
          reason: 'onboarding_completed_at must be an ISO-8601 string');

      verify(() => updateBuilder.eq('id', 'user-abc')).called(1);
    });

    test('is a no-op when no user is signed in', () async {
      when(() => auth.currentUser).thenReturn(null);

      await service.markOnboardingComplete();

      verifyNever(() => client.from('users'));
    });
  });
}

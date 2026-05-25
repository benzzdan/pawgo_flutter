import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pawgo/services/auth_gate_router.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockQueryBuilder extends Mock implements SupabaseQueryBuilder {}

// `select()` returns PostgrestFilterBuilder<PostgrestList>. We use a
// fully-typed mock so static type checks line up with the real chain.
class _MockSelectBuilder extends Mock
    implements PostgrestFilterBuilder<PostgrestList> {}

class _MockEqBuilder extends Mock
    implements PostgrestFilterBuilder<PostgrestList> {}

class _MockMaybeSingleBuilder extends Mock
    implements PostgrestTransformBuilder<PostgrestMap?> {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  group('AuthGateRouter.destinationFor', () {
    late _MockSupabaseClient client;
    late _MockQueryBuilder usersTable;
    late _MockSelectBuilder selectBuilder;
    late _MockEqBuilder eqBuilder;
    late _MockMaybeSingleBuilder maybeSingleBuilder;
    late AuthGateRouter router;

    setUp(() {
      client = _MockSupabaseClient();
      usersTable = _MockQueryBuilder();
      selectBuilder = _MockSelectBuilder();
      eqBuilder = _MockEqBuilder();
      maybeSingleBuilder = _MockMaybeSingleBuilder();

      when(() => client.from('users')).thenAnswer((_) => usersTable);
      when(() => usersTable.select(any())).thenAnswer((_) => selectBuilder);
      when(() => selectBuilder.eq(any(), any())).thenAnswer((_) => eqBuilder);
      when(() => eqBuilder.maybeSingle())
          .thenAnswer((_) => maybeSingleBuilder);

      router = AuthGateRouter(client: client);
    });

    /// PostgrestTransformBuilder implements Future, so awaiting it routes
    /// through `.then(onValue)`. Stub that path so the awaited result
    /// resolves to [value].
    void stubAwait(Map<String, dynamic>? value) {
      when(() => maybeSingleBuilder.then<dynamic>(
            any(),
            onError: any(named: 'onError'),
          )).thenAnswer((invocation) {
        final onValue = invocation.positionalArguments.first as dynamic
            Function(PostgrestMap?);
        return Future<dynamic>.value(onValue(value));
      });
    }

    test('returns /home when onboarding_completed_at is non-null', () async {
      stubAwait({'onboarding_completed_at': '2026-05-25T10:00:00Z'});

      final dest = await router.destinationFor('user-1');
      expect(dest, '/home');
    });

    test('returns /welcome when onboarding_completed_at is NULL', () async {
      stubAwait({'onboarding_completed_at': null});

      final dest = await router.destinationFor('user-1');
      expect(dest, '/welcome');
    });

    test('returns /welcome when the user row is missing entirely', () async {
      stubAwait(null);

      final dest = await router.destinationFor('user-1');
      expect(dest, '/welcome');
    });

    test('returns /welcome (safe default) when the query throws', () async {
      // Throw synchronously from maybeSingle() — the router's try/catch
      // covers both sync and async failures, and this avoids fighting
      // mocktail's Future.then() error semantics.
      when(() => eqBuilder.maybeSingle())
          .thenThrow(Exception('network down'));

      final dest = await router.destinationFor('user-1');
      expect(dest, '/welcome');
    });
  });
}

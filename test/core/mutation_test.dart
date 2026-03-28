import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_query/src/core/mutation.dart';
import 'package:smart_query/src/models/query_options.dart';
import 'package:smart_query/src/models/query_status.dart';

void main() {
  group('Mutation', () {
    test('starts in idle state', () {
      final mutation = Mutation<String, String>(
        options: MutationOptions<String, String>(
          mutator: (v) async => 'result',
        ),
      );
      expect(mutation.status, MutationStatus.idle);
      expect(mutation.currentResult.isIdle, isTrue);
      mutation.dispose();
    });

    test('transitions to loading then success', () async {
      final completer = Completer<String>();
      final mutation = Mutation<String, String>(
        options: MutationOptions<String, String>(
          mutator: (v) => completer.future,
        ),
      );

      final statuses = <MutationStatus>[];
      mutation.stream.listen((r) => statuses.add(r.status));

      final future = mutation.mutateAsync('input');
      await Future<void>.delayed(Duration.zero);
      expect(mutation.status, MutationStatus.loading);

      completer.complete('result');
      final result = await future;

      expect(result, 'result');
      expect(mutation.status, MutationStatus.success);
      expect(mutation.currentResult.data, 'result');

      mutation.dispose();
    });

    test('transitions to error on failure', () async {
      final mutation = Mutation<String, String>(
        options: MutationOptions<String, String>(
          mutator: (v) async => throw Exception('fail'),
        ),
      );

      expect(
        () => mutation.mutateAsync('input'),
        throwsA(isA<Exception>()),
      );

      await Future<void>.delayed(Duration.zero);
      expect(mutation.status, MutationStatus.error);
      mutation.dispose();
    });

    test('fire-and-forget mutate catches errors in state', () async {
      final mutation = Mutation<String, String>(
        options: MutationOptions<String, String>(
          mutator: (v) async => throw Exception('fail'),
        ),
      );

      mutation.mutate('input');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(mutation.status, MutationStatus.error);
      expect(mutation.currentResult.error, isA<Exception>());
      mutation.dispose();
    });

    test('ignores duplicate mutate calls while loading', () async {
      int count = 0;
      final completer = Completer<String>();
      final mutation = Mutation<String, String>(
        options: MutationOptions<String, String>(
          mutator: (v) {
            count++;
            return completer.future;
          },
        ),
      );

      mutation.mutate('first');
      mutation.mutate('second'); // Should be ignored.
      mutation.mutate('third'); // Should be ignored.

      completer.complete('done');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(count, 1, reason: 'Only 1 call should execute');
      mutation.dispose();
    });

    test('reset returns to idle state', () async {
      final mutation = Mutation<String, String>(
        options: MutationOptions<String, String>(
          mutator: (v) async => 'result',
        ),
      );

      await mutation.mutateAsync('input');
      expect(mutation.status, MutationStatus.success);

      mutation.reset();
      expect(mutation.status, MutationStatus.idle);
      expect(mutation.currentResult.data, isNull);
      mutation.dispose();
    });

    test('onMutate callback receives variables', () async {
      String? mutateVars;
      final mutation = Mutation<String, String>(
        options: MutationOptions<String, String>(
          mutator: (v) async => 'result',
          onMutate: (variables) {
            mutateVars = variables;
            return 'context';
          },
        ),
      );

      await mutation.mutateAsync('input');
      expect(mutateVars, 'input');
      mutation.dispose();
    });

    test('onSuccess receives data, variables, and context', () async {
      String? successData;
      String? successVars;
      dynamic successContext;
      final mutation = Mutation<String, String>(
        options: MutationOptions<String, String>(
          mutator: (v) async => 'result',
          onMutate: (variables) => 'my-context',
          onSuccess: (data, variables, context) {
            successData = data;
            successVars = variables;
            successContext = context;
          },
        ),
      );

      await mutation.mutateAsync('input');
      expect(successData, 'result');
      expect(successVars, 'input');
      expect(successContext, 'my-context');
      mutation.dispose();
    });

    test('onError receives error, variables, and context', () async {
      Object? errorObj;
      final mutation = Mutation<String, String>(
        options: MutationOptions<String, String>(
          mutator: (v) async => throw 'custom error',
          onMutate: (variables) => 'ctx',
          onError: (error, variables, context) {
            errorObj = error;
          },
        ),
      );

      try {
        await mutation.mutateAsync('input');
      } catch (_) {}

      expect(errorObj, 'custom error');
      mutation.dispose();
    });

    test('onSettled is called on success', () async {
      int settledCount = 0;
      final mutation = Mutation<String, String>(
        options: MutationOptions<String, String>(
          mutator: (v) async => 'result',
          onSettled: (data, error, variables, context) => settledCount++,
        ),
      );

      await mutation.mutateAsync('input');
      expect(settledCount, 1);
      mutation.dispose();
    });

    test('onSettled is called on error', () async {
      int settledCount = 0;
      final mutation = Mutation<String, String>(
        options: MutationOptions<String, String>(
          mutator: (v) async => throw 'fail',
          onSettled: (data, error, variables, context) => settledCount++,
        ),
      );

      try {
        await mutation.mutateAsync('input');
      } catch (_) {}
      expect(settledCount, 1);
      mutation.dispose();
    });
  });
}

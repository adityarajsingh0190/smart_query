import 'package:flutter_hooks/flutter_hooks.dart';

import '../core/mutation.dart';
import '../models/query_options.dart';
import '../models/query_result.dart';

/// A hook that returns a mutation object to perform requests and track their state.
MutationResult<TData, TVariables> useMutation<TData, TVariables>({
  required MutatorFn<TData, TVariables> mutator,
  int retry = 0,
  RetryDelayFn? retryDelay,
  RetryWhenFn? retryWhen,
  OnMutateFn<TVariables>? onMutate,
  OnMutationSuccessFn<TData, TVariables>? onSuccess,
  OnMutationErrorFn<TVariables>? onError,
  OnMutationSettledFn<TData, TVariables>? onSettled,
}) {
  final options = useMemoized(
    () => MutationOptions<TData, TVariables>(
      mutator: mutator,
      retry: retry,
      retryDelay: retryDelay,
      retryWhen: retryWhen,
      onMutate: onMutate,
      onSuccess: onSuccess,
      onError: onError,
      onSettled: onSettled,
    ),
    [retry],
  );

  final mutation = useMemoized(
      () => Mutation<TData, TVariables>(options: options), [options]);
  final state =
      useState<MutationResult<TData, TVariables>>(mutation.currentResult);

  useEffect(() {
    final subscription = mutation.stream.listen((result) {
      state.value = result;
    });

    return () {
      subscription.cancel();
      mutation.dispose();
    };
  }, [mutation]);

  return state.value;
}

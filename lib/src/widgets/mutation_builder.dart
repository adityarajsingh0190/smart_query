import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/mutation.dart';
import '../models/query_options.dart';
import '../models/query_result.dart';

/// A widget that manages mutation state and rebuilds when it changes.
///
/// ```dart
/// MutationBuilder<User, UpdateNameParams>(
///   mutator: (params) => api.updateUser(params),
///   builder: (context, result) {
///     return ElevatedButton(
///       onPressed: result.isLoading
///           ? null
///           : () => result.mutate(UpdateNameParams(name: 'New Name')),
///       child: result.isLoading
///           ? CircularProgressIndicator()
///           : Text('Save'),
///     );
///   },
/// )
/// ```
class MutationBuilder<TData, TVariables> extends StatefulWidget {
  /// Creates a [MutationBuilder].
  const MutationBuilder({
    super.key,
    required this.mutator,
    required this.builder,
    this.onMutate,
    this.onSuccess,
    this.onError,
    this.onSettled,
    this.retry = 0,
    this.retryDelay,
    this.retryWhen,
  });

  /// The function that performs the mutation.
  final MutatorFn<TData, TVariables> mutator;

  /// Builder function called with the mutation result.
  final Widget Function(
      BuildContext context, MutationResult<TData, TVariables> result) builder;

  /// Called before the mutation runs.
  final OnMutateFn<TVariables>? onMutate;

  /// Called on successful mutation.
  final OnMutationSuccessFn<TData, TVariables>? onSuccess;

  /// Called on mutation failure.
  final OnMutationErrorFn<TVariables>? onError;

  /// Called after mutation completes (success or failure).
  final OnMutationSettledFn<TData, TVariables>? onSettled;

  /// Number of retries. Default: 0 (mutations don't retry by default).
  final int retry;

  /// Delay between retries.
  final RetryDelayFn? retryDelay;

  /// Predicate for conditional retry.
  final RetryWhenFn? retryWhen;

  @override
  State<MutationBuilder<TData, TVariables>> createState() =>
      _MutationBuilderState<TData, TVariables>();
}

class _MutationBuilderState<TData, TVariables>
    extends State<MutationBuilder<TData, TVariables>> {
  late Mutation<TData, TVariables> _mutation;
  StreamSubscription<MutationResult<TData, TVariables>>? _subscription;
  MutationResult<TData, TVariables>? _result;

  @override
  void initState() {
    super.initState();
    _createMutation();
  }

  @override
  void didUpdateWidget(MutationBuilder<TData, TVariables> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recreate mutation if the mutator function reference changed.
    if (widget.mutator != oldWidget.mutator) {
      _subscription?.cancel();
      _mutation.dispose();
      _createMutation();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _mutation.dispose();
    super.dispose();
  }

  void _createMutation() {
    _mutation = Mutation<TData, TVariables>(
      options: MutationOptions<TData, TVariables>(
        mutator: widget.mutator,
        onMutate: widget.onMutate,
        onSuccess: widget.onSuccess,
        onError: widget.onError,
        onSettled: widget.onSettled,
        retry: widget.retry,
        retryDelay: widget.retryDelay,
        retryWhen: widget.retryWhen,
      ),
    );
    _result = _mutation.currentResult;
    _subscription = _mutation.stream.listen((newResult) {
      if (!mounted) return;
      setState(() {
        _result = newResult;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _result ?? _mutation.currentResult);
  }
}

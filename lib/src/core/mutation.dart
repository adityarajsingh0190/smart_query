import 'dart:async';

import '../models/query_options.dart';
import '../models/query_result.dart';
import '../models/query_status.dart';

/// Manages a single mutation operation.
///
/// Unlike [Query], mutations are NOT cached. Each mutation instance is
/// independent and per-widget. State is not shared between widgets.
class Mutation<TData, TVariables> {
  /// Creates a new mutation.
  Mutation({required MutationOptions<TData, TVariables> options})
      : _options = options;

  final MutationOptions<TData, TVariables> _options;

  // ─── Internal state ───
  MutationStatus _status = MutationStatus.idle;
  TData? _data;
  Object? _error;
  bool _disposed = false;

  final StreamController<MutationResult<TData, TVariables>> _controller =
      StreamController<MutationResult<TData, TVariables>>.broadcast();

  /// Stream of mutation result updates.
  Stream<MutationResult<TData, TVariables>> get stream => _controller.stream;

  /// The current status.
  MutationStatus get status => _status;

  /// Whether a mutation is in progress.
  bool get isLoading => _status == MutationStatus.loading;

  /// Returns the current state as a [MutationResult].
  MutationResult<TData, TVariables> get currentResult =>
      MutationResult<TData, TVariables>(
        status: _status,
        data: _data,
        error: _error,
        mutate: mutate,
        mutateAsync: mutateAsync,
        reset: reset,
      );

  /// Fire-and-forget mutation. Errors are captured in the result state.
  void mutate(TVariables variables) {
    // Ignore duplicate submissions while one is in flight.
    if (_status == MutationStatus.loading) return;
    // Fire-and-forget: errors are captured in mutation state, not thrown.
    // ignore: unawaited_futures
    _executeMutation(variables).then((_) {}, onError: (_) {});
  }

  /// Async mutation that returns the result. Throws on error.
  Future<TData> mutateAsync(TVariables variables) async {
    if (_status == MutationStatus.loading) {
      throw StateError('A mutation is already in progress.');
    }
    return _executeMutation(variables);
  }

  /// Resets the mutation to idle state.
  void reset() {
    _status = MutationStatus.idle;
    _data = null;
    _error = null;
    _emit();
  }

  /// Disposes this mutation, closing the stream.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _controller.close();
  }

  // ─── Private ───

  Future<TData> _executeMutation(TVariables variables) async {
    _status = MutationStatus.loading;
    _error = null;
    _emit();

    dynamic context;

    // Step 1: onMutate — capture context for rollback.
    if (_options.onMutate != null) {
      try {
        context = await _options.onMutate!(variables);
      } catch (e) {
        if (_disposed) rethrow;
        _status = MutationStatus.error;
        _error = e;
        _emit();
        _options.onError?.call(e, variables, null);
        _options.onSettled?.call(null, e, variables, null);
        rethrow;
      }
    }

    // Step 2: Execute the mutation.
    try {
      final result = await _options.mutator(variables);
      if (_disposed) return result;

      _status = MutationStatus.success;
      _data = result;
      _error = null;
      _emit();

      await _options.onSuccess?.call(result, variables, context);
      await _options.onSettled?.call(result, null, variables, context);
      return result;
    } catch (e) {
      if (_disposed) rethrow;

      // Retry logic for mutations.
      var retryCount = 0;
      Object lastError = e;

      while (retryCount < _options.retry) {
        final shouldRetry = _options.retryWhen?.call(lastError) ?? true;
        if (!shouldRetry) break;

        retryCount++;
        final delay = _options.retryDelay(retryCount - 1);
        await Future<void>.delayed(delay);
        if (_disposed) throw lastError;

        try {
          final result = await _options.mutator(variables);
          if (_disposed) return result;

          _status = MutationStatus.success;
          _data = result;
          _error = null;
          _emit();

          await _options.onSuccess?.call(result, variables, context);
          await _options.onSettled?.call(result, null, variables, context);
          return result;
        } catch (retryError) {
          lastError = retryError;
        }
      }

      if (_disposed) throw lastError;

      _status = MutationStatus.error;
      _error = lastError;
      _emit();

      await _options.onError?.call(lastError, variables, context);
      await _options.onSettled?.call(null, lastError, variables, context);
      throw lastError;
    }
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(currentResult);
    }
  }
}

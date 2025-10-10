# Callable Latency Tracker

This helper centralizes latency telemetry for callable Cloud Functions. Use it to instrument any `FirebaseFunctions` invocation with consistent Crashlytics logging and debug output.

## Key behaviors

- Wrap callable invocations with `FirebaseFunctions.instance.callWithLatency('<callableName>', …)` or call `CallableLatencyTracker.run` directly for custom workflows.
- Latency is measured with a high resolution `Stopwatch`, so both fast and long-running calls report accurate durations in milliseconds.
- The optional `onMeasured` callback is triggered for **both** successful and failed invocations, allowing UI layers to react regardless of outcome.
- Crashlytics logging is best-effort. If Crashlytics is unavailable or throws an exception, the tracker falls back to `debugPrint` so telemetry never breaks functional flows.
- Only payload key names are logged (up to 20) to avoid accidentally leaking sensitive data.

## Example

```dart
final functions = FirebaseFunctions.instance;
final result = await functions.callWithLatency<Map<String, dynamic>>(
  'user-ensureProfile',
  payload: {'uid': userId},
  category: 'userAccount',
  onMeasured: (elapsedMs) => debugPrint('callable finished in $elapsedMs ms'),
);
```

Place any shared tweaks (like attaching additional Crashlytics keys) in `CallableLatencyTracker._recordLatency` so every caller benefits automatically.

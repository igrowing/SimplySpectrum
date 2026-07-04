/// Rounds [rawMax] up to a visually "nice" axis maximum - the smallest
/// value of the form `{1,2,5} * 10^n` (or `10 * 10^n`) that is `>=
/// rawMax` - so Y-axis labels read as round numbers (10, 50, 200, ...)
/// instead of an arbitrary per-frame pixel occurrence count. Always
/// returns at least 1, so charts never divide by zero when a histogram
/// is still empty.
int niceAxisMax(int rawMax) {
  if (rawMax <= 1) return 1;

  var magnitude = 1;
  while (magnitude * 10 <= rawMax) {
    magnitude *= 10;
  }

  for (final step in [1, 2, 5, 10]) {
    final candidate = step * magnitude;
    if (candidate >= rawMax) return candidate;
  }
  // Unreachable: step=10 always covers any rawMax within [magnitude,
  // magnitude*10), which is guaranteed by the loop above.
  return 10 * magnitude;
}

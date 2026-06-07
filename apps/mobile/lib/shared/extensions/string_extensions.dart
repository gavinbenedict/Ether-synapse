/// String extension methods used throughout Ether Synapse.
extension StringX on String {
  /// Truncates the string to [maxLength] characters, appending '…' if truncated.
  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}…';
  }

  /// Returns `true` if the string is blank (empty or whitespace only).
  bool get isBlank => trim().isEmpty;

  /// Returns `true` if the string is not blank.
  bool get isNotBlank => !isBlank;

  /// Converts the first character to upper case.
  String get capitalised {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

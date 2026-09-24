import 'digits.dart';

/// Algerian tax identification number (NIF, numéro d'identification
/// fiscale), issued by the Direction Générale des Impôts.
///
/// Only the format is checked: 15 digits for a taxpayer, 20 digits for a
/// secondary establishment. No check-digit algorithm has been published, so
/// a well-formed but unassigned NIF passes.
abstract final class Nif {
  /// The digits of [input] with spaces, dashes, dots and slashes removed, or
  /// null if it is not a well-formed NIF.
  static String? normalize(String input, {bool allowEstablishment = true}) {
    final d = digitsOnly(input);
    if (d == null) return null;
    if (d.length == 15 || (allowEstablishment && d.length == 20)) return d;
    return null;
  }

  /// Whether [input] has the format of a NIF.
  static bool isValid(String input, {bool allowEstablishment = true}) =>
      normalize(input, allowEstablishment: allowEstablishment) != null;
}

/// Algerian statistical identification number (NIS, numéro d'identification
/// statistique), issued by the ONS.
///
/// Only the format is checked: 15 digits, or 18 for a secondary
/// establishment (the 15-digit NIS of the head office plus a 3-digit
/// sequence), per executive decree 97-396, articles 4 and 5. No check-digit
/// algorithm has been published.
abstract final class Nis {
  /// The digits of [input] with separators removed, or null if it is not a
  /// well-formed NIS.
  static String? normalize(String input, {bool allowEstablishment = true}) {
    final d = digitsOnly(input);
    if (d == null) return null;
    if (d.length == 15 || (allowEstablishment && d.length == 18)) return d;
    return null;
  }

  /// Whether [input] has the format of a NIS.
  static bool isValid(String input, {bool allowEstablishment = true}) =>
      normalize(input, allowEstablishment: allowEstablishment) != null;
}

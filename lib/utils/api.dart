import 'package:favouritesub/config/brand.dart';

class Api {
  static String get base => Brand.current.domain;

  static Uri uri(String pathWithLeadingSlash) {
    return Uri.parse('$base$pathWithLeadingSlash');
  }
}

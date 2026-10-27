/// Centralized API base URLs for the Seddo application.
/// Follows Innov & Impact Africa coding guidelines.
abstract class BaseUrl {
  static const String seddoApi = 'https://seddo-api.innov.sn';
  static const String development = seddoApi;
  static const String staging = 'https://staging-api.seddo.africa';
  static const String production = 'https://api.seddo.africa';
  // Transit v2 base URL
  static const String transitApi = 'https://transit.innov.sn';

  static const String current = seddoApi;
}

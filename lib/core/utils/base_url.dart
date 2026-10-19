/// Centralized API base URLs for the Seddo application.
/// Follows Innov & Impact Africa coding guidelines.
abstract class BaseUrl {
  // TODO: Replace with environment-based configuration when backend is ready
  static const String development = 'https://dev-api.seddo.africa';
  static const String staging = 'https://staging-api.seddo.africa';
  static const String production = 'https://api.seddo.africa';

  static const String current = development;
}

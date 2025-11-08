class Config {
  static const String apiBaseUrl = 'https://aarcs-auth-server.onrender.com';

  static const String ambulanceAuthEndpoint = '$apiBaseUrl/authenticate/ambulance';
  static const String healthEndpoint = '$apiBaseUrl/health';
}
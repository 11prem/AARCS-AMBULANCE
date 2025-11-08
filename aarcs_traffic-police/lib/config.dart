class Config {
  static const String apiBaseUrl = 'https://aarcs-auth-server.onrender.com';

  static const String policeAuthEndpoint = '$apiBaseUrl/authenticate/police';
  static const String healthEndpoint = '$apiBaseUrl/health';
}
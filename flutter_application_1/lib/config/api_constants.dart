class ApiConstants {
  static const String baseUrl = 'http://localhost:3000/api';
  
  // Auth endpoints
  static const String login = '$baseUrl/users/login';
  static const String register = '$baseUrl/users/register';
  
  // User endpoints
  static const String users = '$baseUrl/users';
  static String user(String id) => '$baseUrl/users/$id';
  static String toggleUserVisibility(String id) => '$baseUrl/users/$id/toggle-visibility';
  
  // Activity endpoints
  static const String activities = '$baseUrl/activities';
  static String activity(String id) => '$baseUrl/activities/$id';
  static String userActivities(String userId) => '$baseUrl/activities/user/$userId';
  
  // Activity history endpoints
  static const String activityHistory = '$baseUrl/activity-history';
  static String activityHistoryByActivityId(String activityId) => '$baseUrl/activity-history/activity/$activityId';
}
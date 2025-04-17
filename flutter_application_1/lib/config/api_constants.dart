class ApiConstants {
  static const String baseUrl = 'http://localhost:3000/api';
  
  // Auth endpoints
  static const String login = '$baseUrl/users/login';
  static const String register = '$baseUrl/users/register';
  
  // User endpoints
  static const String users = '$baseUrl/users';
  static String user(String id) => '$baseUrl/users/$id';
  static String userByUsername(String username) => '$baseUrl/users/username/$username';
  static String searchUsers(String query) => '$baseUrl/users/search?query=$query';
  static String toggleUserVisibility(String id) => '$baseUrl/users/$id/toggle-visibility';
  
  // Activity endpoints
  static const String activities = '$baseUrl/activities';
  static String activity(String id) => '$baseUrl/activities/$id';
  static String userActivities(String userId) => '$baseUrl/activities/user/$userId';
  
  // Activity history endpoints
  static const String activityHistory = '$baseUrl/activity-history';
  static String activityHistoryByActivityId(String activityId) => '$baseUrl/activity-history/activity/$activityId';
  
  // Chat endpoints
  static const String chat = '$baseUrl/chat';
  static String chatRooms = '$chat/rooms';
  static String userChatRooms(String userId) => '$chat/rooms/user/$userId';
  static String chatRoom(String id) => '$chat/rooms/$id';
  static String chatMessages(String roomId) => '$chat/messages/$roomId';
  static const String sendMessage = '$chat/messages';
  static const String markMessagesRead = '$chat/messages/read';
  
  // Notification endpoints
  static const String notifications = '$baseUrl/notifications';
  static String userNotifications(String userId) => '$notifications/user/$userId';
  static String markNotificationRead(String id) => '$notifications/$id/read';
  static const String markAllNotificationsRead = '$notifications/read-all';
  static String deleteUserNotifications(String userId) => '$notifications/user/$userId';
}
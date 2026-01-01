import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/comment.dart';

class CommentsService {
  static const String _prefKeyComments = 'app_comments';

  static Future<List<Comment>> getComments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final commentsJson = prefs.getString(_prefKeyComments);
      if (commentsJson == null || commentsJson.isEmpty) {
        return [];
      }

      final List<dynamic> decoded = jsonDecode(commentsJson);
      return decoded.map((json) => Comment.fromJson(json as Map<String, dynamic>)).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Most recent first
    } catch (e) {
      print('Error loading comments: $e');
      return [];
    }
  }

  static Future<bool> addComment({
    required String userId,
    required String userName,
    String? userPhotoUrl,
    required String text,
  }) async {
    try {
      if (text.trim().isEmpty) return false;

      final comments = await getComments();
      final newComment = Comment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        userName: userName,
        userPhotoUrl: userPhotoUrl,
        text: text.trim(),
        timestamp: DateTime.now(),
      );

      comments.insert(0, newComment); // Add to beginning

      final prefs = await SharedPreferences.getInstance();
      final commentsJson = jsonEncode(comments.map((c) => c.toJson()).toList());
      await prefs.setString(_prefKeyComments, commentsJson);
      return true;
    } catch (e) {
      print('Error adding comment: $e');
      return false;
    }
  }

  static Future<bool> deleteComment(String commentId, String userId) async {
    try {
      final comments = await getComments();
      comments.removeWhere((comment) => 
        comment.id == commentId && comment.userId == userId
      );

      final prefs = await SharedPreferences.getInstance();
      final commentsJson = jsonEncode(comments.map((c) => c.toJson()).toList());
      await prefs.setString(_prefKeyComments, commentsJson);
      return true;
    } catch (e) {
      print('Error deleting comment: $e');
      return false;
    }
  }
}





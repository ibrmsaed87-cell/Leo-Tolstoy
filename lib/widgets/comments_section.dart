import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/comment.dart';
import '../utils/comments_service.dart';
import '../utils/auth_service.dart';
import 'package:intl/intl.dart';

class CommentsSection extends StatefulWidget {
  final bool isArabic;
  final VoidCallback? onCommentPosted;

  const CommentsSection({
    super.key, 
    required this.isArabic,
    this.onCommentPosted,
  });

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final TextEditingController _commentController = TextEditingController();
  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isPosting = false;
  bool _isSignedIn = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _checkAuthStatus();
    // Add test comment on first load (for testing)
    _addTestCommentIfNeeded();
  }

  Future<void> _addTestCommentIfNeeded() async {
    // Only add test comment if no comments exist
    final comments = await CommentsService.getComments();
    if (comments.isEmpty) {
      // Add a test comment
      await CommentsService.addComment(
        userId: 'test_user_001',
        userName: 'مستخدم تجريبي',
        userPhotoUrl: null,
        text: 'هذا تعليق تجريبي لاختبار نظام التعليقات في التطبيق. التطبيق يعمل بشكل ممتاز! 🎉',
      );
      // Reload comments to show the test comment
      if (mounted) {
        await _loadComments();
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    final signedIn = await AuthService.isSignedIn();
    if (signedIn) {
      _currentUserId = await AuthService.getUserId();
    }
    if (mounted) {
      setState(() {
        _isSignedIn = signedIn;
      });
    }
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    final comments = await CommentsService.getComments();
    if (mounted) {
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    }
  }

  Future<void> _postComment() async {
    if (!_isSignedIn || _commentController.text.trim().isEmpty) return;

    setState(() => _isPosting = true);
    
    final userId = await AuthService.getUserId() ?? '';
    final userName = await AuthService.getUserName() ?? 'User';
    final userPhotoUrl = await AuthService.getUserPhotoUrl();

    final success = await CommentsService.addComment(
      userId: userId,
      userName: userName,
      userPhotoUrl: userPhotoUrl,
      text: _commentController.text,
    );

    if (success) {
      _commentController.clear();
      await _loadComments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isArabic ? 'تم إضافة التعليق' : 'Comment posted'),
            duration: const Duration(seconds: 2),
          ),
        );
        // Trigger rewarded interstitial ad callback
        if (widget.onCommentPosted != null) {
          widget.onCommentPosted!();
        }
      }
    }

    if (mounted) {
      setState(() => _isPosting = false);
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    if (_currentUserId != comment.userId) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.isArabic ? 'حذف التعليق' : 'Delete Comment'),
        content: Text(widget.isArabic 
          ? 'هل أنت متأكد من حذف هذا التعليق؟'
          : 'Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(widget.isArabic ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(widget.isArabic ? 'حذف' : 'Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await CommentsService.deleteComment(comment.id, comment.userId);
      await _loadComments();
    }
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.isArabic ? 'تسجيل الدخول مطلوب' : 'Login Required'),
        content: Text(widget.isArabic
            ? 'يجب عليك تسجيل الدخول للتعليق'
            : 'You need to sign in to comment'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.isArabic ? 'حسناً' : 'OK'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return DateFormat(widget.isArabic ? 'dd/MM/yyyy' : 'MM/dd/yyyy').format(timestamp);
    } else if (difference.inDays > 0) {
      return widget.isArabic 
        ? 'منذ ${difference.inDays} ${difference.inDays == 1 ? 'يوم' : 'أيام'}'
        : '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return widget.isArabic
        ? 'منذ ${difference.inHours} ${difference.inHours == 1 ? 'ساعة' : 'ساعات'}'
        : '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return widget.isArabic
        ? 'منذ ${difference.inMinutes} ${difference.inMinutes == 1 ? 'دقيقة' : 'دقائق'}'
        : '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return widget.isArabic ? 'الآن' : 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.comment_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                widget.isArabic ? 'التعليقات' : 'Comments',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                '${_comments.length}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Comment Input (only if signed in)
          if (_isSignedIn) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: widget.isArabic 
                        ? 'اكتب تعليقك...'
                        : 'Write your comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isPosting ? null : _postComment,
                  icon: _isPosting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  tooltip: widget.isArabic ? 'إرسال' : 'Send',
                ),
              ],
            ),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isArabic
                          ? 'سجل الدخول للتعليق'
                          : 'Sign in to comment',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: _showLoginPrompt,
                    child: Text(widget.isArabic ? 'تسجيل الدخول' : 'Sign In'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Comments List
          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ))
          else if (_comments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  widget.isArabic 
                    ? 'لا توجد تعليقات بعد'
                    : 'No comments yet',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _comments.length,
              separatorBuilder: (context, index) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final comment = _comments[index];
                final canDelete = _currentUserId == comment.userId;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      backgroundImage: comment.userPhotoUrl != null && comment.userPhotoUrl!.isNotEmpty
                          ? NetworkImage(comment.userPhotoUrl!)
                          : null,
                      child: comment.userPhotoUrl == null || comment.userPhotoUrl!.isEmpty
                          ? Text(
                              comment.userName.isNotEmpty 
                                ? comment.userName[0].toUpperCase() 
                                : 'U',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    // Comment content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  comment.userName,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                _formatTimestamp(comment.timestamp),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            comment.text,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    // Delete button
                    if (canDelete)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: theme.colorScheme.error,
                        onPressed: () => _deleteComment(comment),
                        tooltip: widget.isArabic ? 'حذف' : 'Delete',
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}


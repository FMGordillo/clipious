import 'package:clipious/comments/models/comment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Comment parses when authorThumbnails is missing or null', () {
    final base = {
      'author': 'a',
      'authorId': 'id',
      'authorUrl': '/channel/id',
      'isEdited': false,
      'content': 'c',
      'publishedText': 'now',
      'likeCount': 0,
      'commentId': 'cid',
      'authorIsChannelOwner': false,
    };

    expect(Comment.fromJson(base).authorThumbnails, isEmpty);
    expect(
      Comment.fromJson({...base, 'authorThumbnails': null}).authorThumbnails,
      isEmpty,
    );
  });
}

import 'package:clipious/utils/states/thumbnail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('onThumbnailFailed falls back through urls until exhausted', () {
    final cubit = ThumbnailCubit(
      const ThumbnailState(
        urls: ['https://a.test/1.jpg', 'https://a.test/2.jpg'],
      ),
    );
    expect(cubit.state.selected, 'https://a.test/1.jpg');

    cubit.onThumbnailFailed();
    expect(cubit.state.selected, 'https://a.test/2.jpg');

    cubit.onThumbnailFailed();
    expect(cubit.state.selected, isNull);
    expect(cubit.state.urls, isEmpty);

    cubit.close();
  });

  test('onThumbnailFailed does not throw after close', () async {
    final cubit = ThumbnailCubit(
      const ThumbnailState(
        urls: ['https://a.test/1.jpg', 'https://a.test/2.jpg'],
      ),
    );
    await cubit.close();

    expect(() => cubit.onThumbnailFailed(), returnsNormally);
    expect(cubit.state.selected, 'https://a.test/1.jpg');
  });
}

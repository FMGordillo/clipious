import 'dart:async';

import 'package:clipious/settings/models/errors/invidious_service_error.dart';
import 'package:clipious/utils/models/paginated_list.dart';
import 'package:clipious/utils/states/item_list.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingList extends PaginatedList<String> {
  final Object error;

  _FailingList(this.error);

  @override
  Future<List<String>> getItems() async => throw error;

  @override
  Future<List<String>> getMoreItems() async => throw error;

  @override
  Future<List<String>> refresh() async => throw error;

  @override
  bool getHasMore() => false;

  @override
  bool hasRefresh() => true;
}

void main() {
  test('InvidiousServiceError.toString includes its message', () {
    final err = InvidiousServiceError('Invalid scope');
    expect(err.toString(), 'InvidiousServiceError: Invalid scope');
  });

  test(
    'ItemListCubit handles InvidiousServiceError without uncaught throw',
    () async {
      Object? uncaught;
      await runZonedGuarded(() async {
        final cubit = ItemListCubit<String>(
          ItemListState(
            itemList: _FailingList(InvidiousServiceError('Invalid scope')),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.loading, isFalse);
        expect(cubit.state.error, ItemListErrors.invalidScope);
        expect(cubit.state.items, isEmpty);
        await cubit.close();
      }, (error, _) => uncaught = error);

      expect(uncaught, isNull);
    },
  );

  test(
    'ItemListCubit maps generic InvidiousServiceError to couldNotFetchItems',
    () async {
      Object? uncaught;
      await runZonedGuarded(() async {
        final cubit = ItemListCubit<String>(
          ItemListState(
            itemList: _FailingList(InvidiousServiceError('Server down')),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.loading, isFalse);
        expect(cubit.state.error, ItemListErrors.couldNotFetchItems);
        await cubit.close();
      }, (error, _) => uncaught = error);

      expect(uncaught, isNull);
    },
  );
}

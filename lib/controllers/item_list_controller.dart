import 'package:shopping_list/controllers/auth_controller.dart';
import 'package:shopping_list/models/item_model.dart';
import 'package:shopping_list/repositories/custom_exception.dart';
import 'package:shopping_list/repositories/item_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum ItemListFilter {
  all,
  obtained,
}

//For obtain lish
final itemListFilterProvider =
    StateProvider<ItemListFilter>((_) => ItemListFilter.all);

final filteredItemListProvider = Provider<List<Item>>((ref) {
  final itemListFilterState = ref.watch(itemListFilterProvider);
  final itemListState = ref.watch(itemListControllerProvider);
  return itemListState.maybeWhen(
    data: (items) {
      switch (itemListFilterState) {
        case ItemListFilter.obtained:
          return items.where((item) => item.obtained).toList();
        default:
          return items;
      }
    },
    orElse: () => [],
  );
});

final itemListExceptionProvider = StateProvider<CustomException?>((_) => null);

//ItemListController
final itemListControllerProvider =
    StateNotifierProvider<ItemListController, AsyncValue<List<Item>>>(
  (ref) {
    final user = ref.watch(authControllerProvider);
    return ItemListController(ref.read, user?.uid);
  },
);

class ItemListController extends StateNotifier<AsyncValue<List<Item>>> {
  final Reader _read;
  final String? _userId;

  ItemListController(this._read, this._userId) : super(AsyncValue.loading()) {
    if (_userId != null) {
      retrieveItems();
    }
  }

  Future<void> retrieveItems({bool isRefreshing = false}) async {
    if (isRefreshing) state = const AsyncValue.loading();
    try {
      final items =
          await _read(itemRepositoryProvider).retrieveItems(userId: _userId!);
      if (mounted) {
        state = AsyncValue.data(items);
      }
    } on CustomException catch (e, st) {
      state = AsyncValue.error(e, stackTrace: st);
    }
  }

  Future<void> addItem({required String name, bool obtained = false}) async {
    try {
      final item = Item(name: name, obtained: obtained);
      final itemId = await _read(itemRepositoryProvider).createItem(
        userId: _userId!,
        item: item,
      );
      state.whenData((items) =>
          state = AsyncValue.data(items..add(item.copyWith(id: itemId))));
    } on CustomException catch (e) {
      _read(itemListExceptionProvider)!.state = e;
    }
  }

  Future<void> updateItem({required Item updatedItem}) async {
    try {
      await _read(itemRepositoryProvider)
          .updateItem(userId: _userId!, item: updatedItem);
      state.whenData((items) {
        state = AsyncValue.data([
          for (final item in items)
            if (item.id == updatedItem.id) updatedItem else item
        ]);
      });
    } on CustomException catch (e) {
      _read(itemListExceptionProvider)!.state = e;
    }
  }

  Future<void> deleteItem({required String itemId}) async {
    try {
      await _read(itemRepositoryProvider).deleteItem(
        userId: _userId!,
        itemId: itemId,
      );
      state.whenData((items) => state =
          AsyncValue.data(items..removeWhere((item) => item.id == itemId)));
    } on CustomException catch (e) {
      _read(itemListExceptionProvider)!.state = e;
    }
  }
}

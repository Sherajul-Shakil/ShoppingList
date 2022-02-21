# Shopping List App

Flutter Shopping List App with Riverpod, Firebase, Hooks, and Freezed Architecture

## Dependencies:

~~~dart
dependencies:
  firebase_core: ^1.12.0
  firebase_auth: ^3.3.7
  cloud_firestore: ^3.1.8

  flutter_hooks: ^0.18.2+1
  hooks_riverpod: ^1.0.3

  freezed_annotation: ^1.1.0
~~~
~~~dart
dev_dependencies:
  flutter_lints: ^1.0.0
  build_runner: ^2.1.7
  freezed: ^1.1.1
  json_serializable: ^6.1.4
~~~

## Firebase 

>Then create a project in firebase. Enable Annonymous authentication and enable cloud firestore.

# main.dart
> In main.dart we initialize firebase and wrapped myapp in a provider scope to give us the ability to access all of our providers anywhere in the app.
~~~dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: MyApp()));
}
~~~

# auth_repository.dart 

> Let's define an abstract class called base auth repository that contains all the method signatures our auth repository will implement.
~~~dart
abstract class BaseAuthRepository {
  Stream<User?> get authStateChanges; //return user account information
  Future<void> signInAnonymously();
  User? getCurrentUser();
  Future<void> signOut();
}
~~~

>we have four different method signatures:

- authstate changes which return stream user. user is a class from firebase auth that has general user account information. the reason we have a question mark after user is because the value we get from firebase is null if the user is not logged in.

-  sign in anonymously creates an anonymous account for our user and logs them in.

-  getcurrentuser gets and returns the current signed in user which like before is null if the user is not logged in.

- sign out logs the current user out.

>  class auth repository implements base auth repository and takes in a reader from riverpod reader allows the auth repository to read other providers in the app 

# general_providers.dart

> in this case we need to read our firebase auth.instance which we'll get from a provider called firebase auth provider. we'll define firebase auth provider in a separate file called generalproviders.dart. this
provides an instance of firebase auth. we're also going to add our firebase irestore provider for when we write our
item repository to create read update and delete items from firestore. 

~~~dart
final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firebaseFirestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
~~~

# auth_repository.dart
>implements BaseAuthRepository with the help of firebaseAuthProvider.
~~~dart
//Implements abstract class
class AuthRepository implements BaseAuthRepository {
  final Reader _read;

  const AuthRepository(this._read);

  @override
  Stream<User?> get authStateChanges =>
      _read(firebaseAuthProvider).authStateChanges();

  @override
  Future<void> signInAnonymously() async {
    try {
      await _read(firebaseAuthProvider).signInAnonymously();
    } on FirebaseAuthException catch (e) {
      throw CustomException(message: e.message);
    }
  }

  @override
  User? getCurrentUser() {
    try {
      return _read(firebaseAuthProvider).currentUser;
    } on FirebaseAuthException catch (e) {
      throw CustomException(message: e.message);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _read(firebaseAuthProvider).signOut();
      await signInAnonymously();
    } on FirebaseAuthException catch (e) {
      throw CustomException(message: e.message);
    }
  }
}
~~~

> for error handling let's wrap each body in a try catch block and throw a custom exception passing in
the error message from each firebase auth exception 
~~~dart
on FirebaseAuthException catch (e) {
      throw CustomException(message: e.message);
    }
~~~

# custom_exception.dart

> we'll make a class called customexception that implements exception and contains a string message back in authorpository.dart. don't forget to provide the auth repository and pass in ref.read so we can access it across our app to keep track of our users current authentication state in the app.

~~~dart
class CustomException implements Exception {
  final String? message;

  const CustomException({this.message = 'Something went wrong!'});

  set state(CustomException state) {}

  @override
  String toString() => 'CustomException { message: $message }';
}
~~~

# auth_controller.dart

> to keep track of our users current authentication state in the app we're going to create an auth controller
inside of a controller's folder. authcontroller extends a state notifier of type nullable user this means that the state of our auth controller can either be null when the user is not logged in or a firebase user one user is logged in.
auth controller takes in a reader and has a knowable stream subscription of type nullable user called auth state
changes subscription in the constructor we set the initial state of our auth controller to null because no user is signed in. then we subscribe to the auth state changes stream from our auth repository and update our auth controller state. whenever user logs in or logs out we also need a disposed method to cancel our off state changes subscription.

~~~dart
final authControllerProvider = StateNotifierProvider<AuthController, User?>(
  (ref) => AuthController(ref.read)
    ..appStarted(), //as soon as user start app, he will be signed in
);

class AuthController extends StateNotifier<User?> {
  final Reader _read;

  StreamSubscription<User?>? _authStateChangesSubscription;

  AuthController(this._read) : super(null) {
    _authStateChangesSubscription?.cancel();
    _authStateChangesSubscription = _read(authRepositoryProvider)
        .authStateChanges
        .listen((user) => state = user);
  }

  @override
  void dispose() {
    _authStateChangesSubscription?.cancel();
    super.dispose();
  }

  void appStarted() async {
    final user = _read(authRepositoryProvider).getCurrentUser();
    if (user == null) {
      await _read(authRepositoryProvider).signInAnonymously();
    }
  }

  void signOut() async {
    await _read(authRepositoryProvider).signOut();
  }
}

~~~

# main.dart
>If user is loged in, then logout icon will be visible.
~~~dart
leading: authControllerState != null
            ? IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).signOut(),
              )
            : null,
~~~

# item_model.dart

- the freezed.dart file will contain methods like tostring copy with and overrides the double equals operator and hashcode for equality the.

- g.dart file contains our from json and to json methods.
~~~dart
abstract class Item implements _$Item {
  const Item._();

  const factory Item({
    String? id,
    required String name,
    @Default(false) bool obtained,
  }) = _Item;

  factory Item.empty() => Item(name: '');

  factory Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);

  factory Item.fromDocument(DocumentSnapshot doc) {
    final data = doc.data()!;
    return Item.fromJson(data as Map<String, dynamic>).copyWith(id: doc.id);
  }

  Map<String, dynamic> toDocument() => toJson()..remove('id');
}
~~~

- item.empty returns an item with a name and obtained set to false 
-  item.from document is used for converting document snapshots from firebase into item models because our firebase
document contains a name field and obtained field. we can use the generated from json method to convert our document data into an item.we copy the id into the model using copy with as doc.id is our item id we should add a method to convert item
models into type map stream dynamic without the item id 
-  we should add a method to convert item models into type map stream dynamic without the item id so we can add them to firebase in order to add custom methods to a freeze class. 


# item_repository.dart
>  this repository handles all of our crud or create read update delete operations that have to do with items in firestore. we'll have a list collection with documents that have the same ids as our users each user document will have another collection called user list where each document represents an item.

> base item repository will have four
correct operations that all require a
user id
- retrieve items returns a future list of items
- create item returns the id of the created item once it's stored in firestore
- update item updates the item in firestore
- delete item deletes the item from the firestore collection 

~~~dart
abstract class BaseItemRepository {
  Future<List<Item>> retrieveItems({required String userId});
  Future<String> createItem({required String userId, required Item item});
  Future<void> updateItem({required String userId, required Item item});
  Future<void> deleteItem({required String userId, required String itemId});
}
~~~

-  for retrieve items we get the snapshot
at collectionlists.doc
userid dot collection user list and
return a map over the documents
converting each one to an item using
item.fromDocument 
~~~dart
Future<List<Item>> retrieveItems({required String userId}) async {
    try {
      final snap =
          await _read(firebaseFirestoreProvider).usersListRef(userId).get();
      return snap.docs.map((doc) => Item.fromDocument(doc)).toList();
    } on FirebaseException catch (e) {
      throw CustomException(message: e.message);
    }
  }

@override
  Future<String> createItem({
    required String userId,
    required Item item,
  }) async {
    try {
      final docRef = await _read(firebaseFirestoreProvider)
          .usersListRef(userId)
          .add(item.toDocument());
      return docRef.id;
    } on FirebaseException catch (e) {
      throw CustomException(message: e.message);
    }
  }

  @override
  Future<void> updateItem({required String userId, required Item item}) async {
    try {
      await _read(firebaseFirestoreProvider)
          .usersListRef(userId)
          .doc(item.id)
          .update(item.toDocument());
    } on FirebaseException catch (e) {
      throw CustomException(message: e.message);
    }
  }

  @override
  Future<void> deleteItem({
    required String userId,
    required String itemId,
  }) async {
    try {
      await _read(firebaseFirestoreProvider)
          .usersListRef(userId)
          .doc(itemId)
          .delete();
    } on FirebaseException catch (e) {
      throw CustomException(message: e.message);
    }
  }
}
~~~

# firebase_firestore_extension.dart

>usersListRef:
~~~dart
extension FirebaseFirestoreX on FirebaseFirestore {
  CollectionReference usersListRef(String userId) =>
      collection('lists').doc(userId).collection('userList');
}
~~~

# item_list_controller.dart

> when we think about this screen we know
it's going to have three different
states: loading, data, and error 

- loading shows a circular progress indicator
- data shows the list of items and 
- error shows an error message 

~~~dart
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
~~~

> this provider can be declared above our controller provider the purpose of having a separate provider is so we can listen to this
provider in our ui and display error messages using snack
bars if we just set the state to async value.error
then users would see a full screen error message we want users to still be able to view their existing items while notified in a lightweight way that an error occurred.

~~~dart
final itemListExceptionProvider = StateProvider<CustomException?>((_) => null);
~~~

# main.dart

## For add item button
~~~dart
floatingActionButton: FloatingActionButton(
        onPressed: () => AddItemDialog.show(context, Item.empty()),
        child: const Icon(Icons.add),
      ),
~~~

## For add and update item

~~~dart
class AddItemDialog extends HookConsumerWidget {
  static void show(BuildContext context, Item item) {
    showDialog(
      context: context,
      builder: (context) => AddItemDialog(item: item),
    );
  }

  final Item item;

  const AddItemDialog({Key? key, required this.item}) : super(key: key);

  bool get isUpdating => item.id != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textController = useTextEditingController(text: item.name);
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Item name'),
            ),
            const SizedBox(height: 12.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  primary: isUpdating
                      ? Colors.orange
                      : Theme.of(context).primaryColor,
                ),
                onPressed: () {
                  isUpdating
                      ? ref
                          .read(itemListControllerProvider.notifier)
                          .updateItem(
                            updatedItem: item.copyWith(
                              name: textController.text.trim(),
                              obtained: item.obtained,
                            ),
                          )
                      : ref
                          .read(itemListControllerProvider.notifier)
                          .addItem(name: textController.text.trim());
                  Navigator.of(context).pop();
                },
                child: Text(isUpdating ? 'Update' : 'Add'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
~~~

# item_list_controller.dart

> what if we wanted to be able to filter our items and only view the obtained ones? thanks to riverpod this is pretty easy
to do inside of our item list controller. let's define an enum named itemlist filter with two values all and obtained. next we'll make an itemlest filter provider that uses a state provider to let us know the selected itemless filter. we can now create another provider that gives us a list of items based on our current filter and the existing items in our list. we get the current filter and itemless state by using ref.watch. so whenever there are changes to the filter or list
of items this provider will return new items itemlist state has dot maybe one so we can return the correct items based on our filter.

~~~dart
enum ItemListFilter {
  all,
  obtained,
}

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
~~~

## 😍😍😍😍😍This project is complete😍😍😍😍😍
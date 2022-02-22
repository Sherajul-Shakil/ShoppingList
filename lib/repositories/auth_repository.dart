import 'package:firebase_auth/firebase_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shopping_list/general_providers.dart';
import 'package:shopping_list/repositories/custom_exception.dart';

abstract class BaseAuthRepository {
  Stream<User?> get authStateChanges;
  //return user account information
  Future<void> signInAnonymously();
  User? getCurrentUser();
  Future<void> signOut();
}

//Wrap with Provider as we can access this from anywhere of our app
final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.read));

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

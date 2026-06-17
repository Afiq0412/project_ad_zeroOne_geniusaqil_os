import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Login
  Future<UserModel?> loginWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        return await getUserDetails(credential.user!.uid);
      }
      return null;
    } catch (e) {
      throw Exception(_handleFirebaseAuthError(e));
    }
  }

  // Register
  Future<UserModel?> registerWithEmailAndPassword(
      String name, String email, String password, String role) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Create UserModel
        UserModel newUser = UserModel(
          id: credential.user!.uid,
          name: name,
          email: email,
          role: role,
          status: 'Active',
          phone: '',
          leaveBalances: {
            'Annual leave': 8.0,
            'Medical leave (MC)': 14.0,
            'Unpaid leave': 8.0,
            'Maternity leave': 98.0,
            'Marriage leave': 5.0,
            'Compassionate leave': 2.0,
            'Umrah leave': 14.0,
            'Haji leave': 40.0,
            'Birthday leave': 1.0,
            'Half day leave': 2.0,
          },
        );

        // Save to Firestore
        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .set(newUser.toMap());

        return newUser;
      }
      return null;
    } catch (e) {
      throw Exception(_handleFirebaseAuthError(e));
    }
  }

  // Get User Details from Firestore
  Future<UserModel?> getUserDetails(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['leaveBalances'] == null) {
          final defaultBalances = {
            'Annual leave': 8.0,
            'Medical leave (MC)': 14.0,
            'Unpaid leave': 8.0,
            'Maternity leave': 98.0,
            'Marriage leave': 5.0,
            'Compassionate leave': 2.0,
            'Umrah leave': 14.0,
            'Haji leave': 40.0,
            'Birthday leave': 1.0,
            'Half day leave': 2.0,
          };
          await _firestore.collection('users').doc(uid).update({'leaveBalances': defaultBalances});
          data['leaveBalances'] = defaultBalances;
        }
        return UserModel.fromMap(data, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch user details: $e');
    }
  }

  // Logout
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Send Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception(_handleFirebaseAuthError(e));
    }
  }

  // Helper method to translate Firebase errors
  String _handleFirebaseAuthError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No user found for that email.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'email-already-in-use':
          return 'The account already exists for that email.';
        case 'invalid-email':
          return 'The email address is invalid.';
        case 'weak-password':
          return 'The password provided is too weak.';
        case 'configuration-not-found':
        case 'operation-not-allowed':
          return 'Email/Password authentication is not enabled in the Firebase Console. Please enable it under Authentication > Sign-in method.';
        default:
          return e.message ?? 'An unknown authentication error occurred.';
      }
    }
    return e.toString();
  }
}

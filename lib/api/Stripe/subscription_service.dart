import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flourish_web/api/Stripe/stripe_service.dart';

class StripeSubscriptionService extends StripeService {
  late final CollectionReference<Map<String, dynamic>> _collection;
  StripeSubscriptionService() : super() {
        _collection =  FirebaseFirestore.instance
        .collection('customers')
        .doc(user!.uid)
        .collection('subscriptions');
  }

  Future<bool> hasProMembership() async {
    logger.i('Verifying user membership status');
    try {
      final querySnapshot = await _collection.where('status', whereIn: ['trialing', 'active']).get();

      if (querySnapshot.docs.isNotEmpty) {
        logger.i('User is a pro member');
        return true;
      }
      logger.i('User is not a pro member');
      return false;
    } catch (e) {
      logger.e('Unexpected error while checking subscription status. $e');
      rethrow;
    }
  }
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flourish_web/api/Stripe/stripe_service.dart';

class StripeSubscriptionService extends StripeService {
  late final DocumentReference<Map<String, dynamic>> _document;
  StripeSubscriptionService() : super() {
    _document =
        FirebaseFirestore.instance.collection('customers').doc(user!.uid);
  }

  Future<bool> hasProMembership() async {
    logger.i('Verifying user membership status');
    try {
      final querySnapshot = await _document
          .collection('subscriptions')
          .where('status', whereIn: ['trialing', 'active']).get();

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

  Future<String> createCheckoutSession(String price) async {
    logger.i('Creating checkout session');
    try {
      final docRef = await _document.collection('checkout_sessions').add({
        'price': price,
        'success_url': 'https://www.google.com',
        'cancel_url': 'https://www.google.com',
      });

      final Completer<String> completer = Completer<String>();
      docRef.snapshots().listen((DocumentSnapshot snapshot) {
        final data = snapshot.data() as Map<String, dynamic>?;
        if (data != null) {
          final url = data['url'] as String?;
          if (url != null && !completer.isCompleted) {
            completer.complete(url);
          } else if (data['error'] != null && !completer.isCompleted) {
            logger.e(
                'Error while creating checkout session: ${data['error']['message']}');
            completer.completeError(Exception(data['error']['message']));
          }
        } else if (!completer.isCompleted) {
          logger.e(
              'Data returned null. Checkout session was not created correctly');
          completer.completeError(Exception('Data returned null'));
        }
      });

      return completer.future;
    } catch (e) {
      logger.e('Unexpected error while processing checkout. $e');
      rethrow;
    }
  }
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:studybeats/api/Stripe/product_service.dart';
import 'package:studybeats/api/Stripe/stripe_service.dart';

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

  // Gets the active product for the user, if there is not one, it gets the free product from the product directory
  // If there are multiple active products, it will return the first one, and log an error
  Future<StripeDatabaseProduct> getActiveProduct() async {
    logger.i('Getting active product for used id: ${user!.uid}');
    try {
      final querySnapshot = await _document
          .collection('subscriptions')
          .where('status', whereIn: ['trialing', 'active']).get();
      if (querySnapshot.docs.isEmpty) {
        logger.i('No active subscriptions found, getting free product');
        return StripeProductService().getFreeProduct();
      }

      final DocumentReference<Map<String, dynamic>> productRef =
          querySnapshot.docs.first.get('product');

      final productSnapshot = await productRef.get();
      final product = StripeDatabaseProduct.fromJson(
          productSnapshot.data()!, productSnapshot.id);

      logger.i('Found active product: ${product.name}');
      return product;
    } catch (e) {
      logger.e('Unexpected error while getting active product. $e');
      rethrow;
    }
  }

  Future<DateTime> getSubscriptionEndDate() async {
    logger.i('Getting subscription end date');
    try {
      final querySnapshot = await _document
          .collection('subscriptions')
          .where('status', whereIn: ['trialing', 'active']).get();

      if (querySnapshot.docs.isEmpty) {
        logger.i('No active subscriptions found');
        return DateTime.now();
      }

      final subscription = querySnapshot.docs.first;
      final endDate = subscription.get('current_period_end') as Timestamp;

      logger.i('Subscription end date: ${endDate.toDate()}');
      return endDate.toDate();
    } catch (e) {
      logger.e('Unexpected error while getting subscription end date. $e');
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

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flourish_web/api/Stripe/stripe_service.dart';
import 'package:json_annotation/json_annotation.dart';

StripeProduct _$StripeProductFromJson(Map<String, dynamic> json) {
  return StripeProduct(
    description: json['description'] as String?,
    images: (json['images'] as List<dynamic>?)
        ?.map((image) => image as String)
        .toList(), // Handling the list
    name: json['name'] as String?,
    role: json['role'] as String?,
    taxCode: json['tax_code'] as String?,
  );
}

Map<String, dynamic> _$StripeProductToJson(StripeProduct instance) =>
    <String, dynamic>{
      'description': instance.description,
      'images': instance.images,
      'name': instance.name,
      'role': instance.role,
      'tax_code': instance.taxCode,
    };

@JsonSerializable()
class StripeProduct {
  final String? description;
  final List<String>? images;
  final String? name;
  final String? role;
  final String? taxCode;

  const StripeProduct({
    this.description,
    this.images,
    this.name,
    this.role,
    this.taxCode,
  });

  factory StripeProduct.fromJson(Map<String, dynamic> json) =>
      _$StripeProductFromJson(json);
  Map<String, dynamic> toJson() => _$StripeProductToJson(this);

  @override
  String toString() => jsonEncode(toJson());
}

class StripeProductService extends StripeService {
  late final CollectionReference<Map<String, dynamic>> _collection;
  StripeProductService() : super() {
    _collection = FirebaseFirestore.instance.collection('products');
  }

  Future<List<StripeProduct>> getActiveProducts() async {
    logger.i('Getting active products');
    try {
      final querySnapshot =
          await _collection.where('active', isEqualTo: true).get();

      final products = querySnapshot.docs.map((doc) {
        return StripeProduct.fromJson(doc.data());
      }).toList();

      return products;
    } catch (e) {
      logger.e('Unexpected error while checking subscription status. $e');
      rethrow;
    }
  }
}

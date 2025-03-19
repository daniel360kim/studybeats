import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

_$SubscriptionDetailsFromJson(Map<String, dynamic> json) => SubscriptionDetails(
      active: json['status'] == 'active',
      currentPeriodEnd: (json['current_period_end'] as Timestamp).toDate(),
      currentPeriodStart: (json['current_period_start'] as Timestamp).toDate(),
      interval: json['items'][0]['plan']['interval'] as String,
      unitPrice: json['items'][0]['plan']['amount'] as int,
    );

@JsonSerializable()
class SubscriptionDetails {
  bool active;
  DateTime currentPeriodEnd;
  DateTime currentPeriodStart;
  String interval;
  int unitPrice;

  SubscriptionDetails({
    required this.active,
    required this.currentPeriodEnd,
    required this.currentPeriodStart,
    required this.interval,
    required this.unitPrice,
  });

  factory SubscriptionDetails.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionDetailsFromJson(json);
}

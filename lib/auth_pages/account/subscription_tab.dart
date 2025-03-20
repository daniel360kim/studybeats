// tabs/subscription_tab.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/Stripe/objects.dart';
import 'package:studybeats/api/Stripe/subscription_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/router.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SubscriptionTab extends StatefulWidget {
  const SubscriptionTab({
    super.key,
  });

  @override
  State<SubscriptionTab> createState() => _SubscriptionTabState();
}

class _SubscriptionTabState extends State<SubscriptionTab> {
  SubscriptionDetails? _subscriptionDetails;

  bool _loadingCustomerPortalUrl = false;

  bool _isPro = false;

  final StripeSubscriptionService _subscriptionService =
      StripeSubscriptionService();

  @override
  void initState() {
    super.initState();
    fetchSubscriptionDetails();
  }

  void fetchSubscriptionDetails() async {
    final subscriptionDetails =
        await _subscriptionService.getSubscriptionDetails();
    setState(() {
      if (subscriptionDetails.active) {
        _isPro = true;
      }
      _subscriptionDetails = subscriptionDetails;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SizedBox(
        width: MediaQuery.of(context).size.width / 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildMembershipDetails(),
            const SizedBox(height: 20),
            if (_isPro) buildSubscriptionManagementButton(),
          ],
        ),
      ),
    );
  }

  Widget buildMembershipDetails() {
    if (!_isPro) {
      return _upgradeCallout();
    } else {
      return SizedBox(
        width: MediaQuery.of(context).size.width / 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your membership',
              style: GoogleFonts.inter(
                color: kFlourishAliceBlue,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 10),
            if (_subscriptionDetails != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetail('Plan',
                      '${_subscriptionDetails!.interval[0].toUpperCase()}${_subscriptionDetails!.interval.substring(1)}ly'),
                  _buildDetail('Next Payment',
                      '\$${_subscriptionDetails!.unitPrice / 100}'),
                  _buildDetail('Next billing date',
                      _formatDate(_subscriptionDetails!.currentPeriodEnd)),
                  _buildDetail('Member since',
                      _formatDate(_subscriptionDetails!.currentPeriodStart)),
                ],
              )
            else
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(4, (index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Container(
                        width: double.infinity,
                        height: 20.0,
                        decoration: BoxDecoration(
                          color: kFlourishLightBlackish.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    );
                  }),
                ),
              )
          ],
        ),
      );
    }
  }

  Container _upgradeCallout() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kFlourishAdobe.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Acheive more with Pro',
            style: GoogleFonts.inter(
              color: kFlourishAliceBlue,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Upgrade today to get premium study tools designed to help you succeed.',
            style: GoogleFonts.inter(
              color: kFlourishLightBlackish,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: kFlourishCyan,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              context.goNamed(AppRoute.subscriptionPage.name);
            },
            icon: const Icon(Icons.star, color: kFlourishBlackish),
            label: Text(
              'Upgrade',
              style: GoogleFonts.inter(
                color: kFlourishBlackish,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMMM d, yyyy').format(date);
  }

  Widget _buildDetail(String left, String right) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                left,
                style: GoogleFonts.inter(
                  color: kFlourishAliceBlue,
                  fontSize: 16,
                ),
              ),
            ),
            const Spacer(),
            Text(
              right,
              style: GoogleFonts.inter(
                color: kFlourishAliceBlue,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const Divider(
          color: kFlourishLightBlackish,
          thickness: 1,
        ),
      ],
    );
  }

  Widget buildSubscriptionManagementButton() {
    if (_loadingCustomerPortalUrl) {
      return SizedBox(
        width: 20,
        height: 20,
        child: const CircularProgressIndicator(
          color: kFlourishAdobe,
          strokeWidth: 2,
        ),
      );
    }
    return TextButton(
      onPressed: () async {
        setState(() {
          _loadingCustomerPortalUrl = true;
        });
        final url = await _subscriptionService.getCustomerPortal();

        // Launch the url in current tab
        if (await canLaunchUrlString(url)) {
          await launchUrlString(url, webOnlyWindowName: '_self');
          setState(() => _loadingCustomerPortalUrl = false);
        } else {
          setState(() => _loadingCustomerPortalUrl = false);
        }
      },
      child: Text(
        'Manage subscription',
        style: GoogleFonts.inter(
          color: kFlourishAliceBlue,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: kFlourishAliceBlue,
        ),
      ),
    );
  }
}

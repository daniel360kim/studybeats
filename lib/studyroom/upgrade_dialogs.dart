import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/Stripe/product_service.dart';
import 'package:studybeats/api/Stripe/subscription_service.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/router.dart';
import 'package:url_launcher/url_launcher_string.dart';

class PremiumUpgradeDialog extends StatefulWidget {
  const PremiumUpgradeDialog(
      {required this.title, required this.description, super.key});

  final String title;
  final String description;

  @override
  State<PremiumUpgradeDialog> createState() => _PremiumUpgradeDialogState();
}

class _PremiumUpgradeDialogState extends State<PremiumUpgradeDialog> {
  final _stripeProductService = StripeProductService();

  List<Product> _products = [];
  bool _loadingProducts = true;
  final _logger = getLogger('PremiumUpgradeDialog');

  PricingInterval _selectedInterval = PricingInterval.year;

  bool _checkoutSessionLoading = false;
  bool _isUserAnonymous = true;

  @override
  void initState() {
    super.initState();
    _getProducts();
    _initAuth();
  }

  void _initAuth() async {
    final isUserAnonymous = await AuthService().isUserAnonymous();
    setState(() {
      _isUserAnonymous = isUserAnonymous;
    });
  }

  Future<void> _getProducts() async {
    try {
      final products = await _stripeProductService.getPaidProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _loadingProducts = false;
      });
    } catch (e) {
      _logger.e('Error fetching products: $e');
      if (!mounted) return;
      setState(() {
        _loadingProducts = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kFlourishAliceBlue,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Stack(
          children: [
            // Main content wrapped in SingleChildScrollView for scrollability.
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Decide between a single or two-column layout.
                    final isNarrow = constraints.maxWidth < 600;
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLeftSide(context),
                          const SizedBox(height: 16),
                          Divider(color: Colors.grey.shade300, thickness: 1),
                          const SizedBox(height: 16),
                          _buildRightSide(context),
                        ],
                      );
                    } else {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildLeftSide(context),
                          ),
                          VerticalDivider(
                            color: Colors.grey.shade300,
                            thickness: 1,
                            width: 32,
                          ),
                          Expanded(
                            flex: 1,
                            child: _buildRightSide(context),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
            ),
            // Close button positioned in the top-right corner.
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the left-side content with product information.
  Widget _buildLeftSide(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.description,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Billing cycle',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (_loadingProducts)
          Column(
            children: List.generate(
              2,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                      color: kFlourishAliceBlue,
                    ),
                    height: 60.0,
                  ),
                ),
              ),
            ),
          )
        else if (_products.isNotEmpty)
          _buildProductTile(_products.first)
        else
          const Text('No products available.'),
        const SizedBox(height: 12),
        Text(
          'Applicable taxes will be calculated at checkout.',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _checkoutSessionLoading
              ? null
              : () async {
                  setState(() {
                    _checkoutSessionLoading = true;
                  });
                  late final String? price;
                  if (_selectedInterval == PricingInterval.year) {
                    price = _products.first.prices
                        .firstWhere((element) =>
                            element.interval == PricingInterval.year)
                        .docId;
                  } else {
                    price = _products.first.prices
                        .firstWhere((element) =>
                            element.interval == PricingInterval.month)
                        .docId;
                  }
                  if (price == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Something went wrong. Please try again.'),
                      ),
                    );
                  }

                  if (_isUserAnonymous) {
                    // TODO after login, direct to payment
                    context.goNamed(AppRoute.loginPage.name);
                  }
                  try {
                    final String url = await StripeSubscriptionService()
                        .createCheckoutSession(price!);

                    _logger.i(
                        'Checkout url received succesfully! Redirecting to $url');
                    if (await canLaunchUrlString(url)) {
                      await launchUrlString(url, webOnlyWindowName: '_self');
                      setState(() {
                        _checkoutSessionLoading = false;
                      });
                    } else {
                      _logger.e('Could not launch url: $url');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Something went wrong. Please try again.'),
                        ),
                      );
                    }
                  } catch (e) {
                    _logger.e('Error creating checkout session: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Something went wrong. Please try again.'),
                      ),
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: kFlourishAdobe,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Checkout now',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: kFlourishAliceBlue,
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the right-side content with feature highlights.
  Widget _buildRightSide(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Get more with Pro',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingProducts)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              5,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                    width: double.infinity,
                    height: 20.0,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _products.first.product.featureList!.map((featureName) {
              return buildFeatureListItem(featureName!);
            }).toList(),
          ),
        const SizedBox(height: 24),

        // Todo - Add a "Learn more" button to navigate to a page with more details.
        /*
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          style: TextButton.styleFrom(
            foregroundColor: kFlourishAdobe,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Learn more'),
        ),
        */
      ],
    );
  }

  /// Builds a tile for a [Product] safely by checking list lengths.
  Widget _buildProductTile(Product product) {
    final prices = product.prices;
    if (prices.isEmpty) {
      return const Text('No pricing information available.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (prices.length >= 2) ...[
          const SizedBox(height: 8),
          _buildProductPriceTile(prices[1]),
        ],
        const SizedBox(height: 8),
        if (prices.isNotEmpty) _buildProductPriceTile(prices[0]),
      ],
    );
  }

  /// Builds a tile for a [ProductPrice] safely.
  Widget _buildProductPriceTile(ProductPrice price) {
    final displayPrice = (price.unitAmount ?? 0) / 100;
    final monthlyPrice = price.interval == PricingInterval.year
        ? displayPrice / 12
        : displayPrice;
    final isSelected = _selectedInterval == price.interval;
    final textColor = isSelected ? Colors.black : Colors.grey;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedInterval = price.interval!;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? kFlourishAdobe.withOpacity(0.7)
                : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  price.interval == PricingInterval.year ? 'Yearly' : 'Monthly',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '\$${monthlyPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      TextSpan(
                        text: '/month',
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Spacer(),
            if (isSelected)
              const Icon(
                Icons.check,
                size: 24,
                color: kFlourishAdobe,
              )
          ],
        ),
      ),
    );
  }

  Widget buildFeatureListItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            '•  ',
            style: GoogleFonts.inter(
              color: kFlourishLightBlackish,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: kFlourishLightBlackish,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flourish_web/api/Stripe/subscription_service.dart';
import 'package:flourish_web/auth/unknown_error.dart';
import 'package:flourish_web/colors.dart';
import 'package:flourish_web/log_printer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flourish_web/api/Stripe/product_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

enum Interval {
  monthly,
  yearly,
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final List<Product> _monthlyProducts = [];
  final List<Product> _yearlyProducts = [];

  final StripeProductService _stripeProductService = StripeProductService();
  Interval _selectedInterval = Interval.yearly; // Track selected interval

  final _logger = getLogger('Subscription Page');
  final _stripeSubscriptionService = StripeSubscriptionService();

  bool _isPro = false;

  bool _error = false;
  bool _loadingProducts = true;

  @override
  void initState() {
    super.initState();
    _getSubscriptionStatus();
    _getProducts();
  }

  void _getProducts() async {
    final products = await _stripeProductService.getActiveProducts();

    setState(() {
      for (final product in products) {
        for (final price in product.prices) {
          if (price.interval == PricingInterval.month) {
            _monthlyProducts.add(product);
          } else if (price.interval == PricingInterval.year) {
            _yearlyProducts.add(product);
          } else {
            _logger.w(
                'Found an unsupported pricing interval. Products in Stripe must have either monthly or yearly pricing intervals');
          }
        }
      }
      _loadingProducts = false;
    });
    _logger.i(
        'Found ${_monthlyProducts.length} monthly products and ${_yearlyProducts.length} yearly products');
  }

  void _getSubscriptionStatus() async {
    bool status = await _stripeSubscriptionService.hasProMembership();
    setState(() {
      _isPro = status;
    });
  }

  AppBar _buildAppBar() {
    return AppBar(
      toolbarHeight: 70,
      leadingWidth: 500,
      backgroundColor: kFlourishAliceBlue,
      leading: Row(
        children: [
          IconButton(
            iconSize: 20,
            color: kFlourishBlackish,
            icon: const Icon(Icons.arrow_back_outlined),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 5),
          const Text(
            'Flourish',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: kFlourishAdobe),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Your code here
          },
          child: const Text(
            'Action 1',
            style: TextStyle(color: kFlourishBlackish),
          ),
        ),
        TextButton(
          onPressed: () {
            // Your code here
          },
          child: const Text(
            'Action 2',
            style: TextStyle(color: kFlourishBlackish),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: kFlourishAliceBlue,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 15.0,
            vertical: 30.0,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildHeading(),
              const SizedBox(height: 25.0),
              _buildIntervalControls(),
              const SizedBox(height: 25.0),
              if (_error) const SizedBox(width: 300, child: UnknownError()),
              _loadingProducts
                  ? _buildShimmerProductListing()
                  : _buildProductListing(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeading() {
    return const Column(
      children: [
        Text(
          'Maximize Learning, minimize time',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        SizedBox(height: 5.0),
        Text.rich(
          TextSpan(
            text: 'Choose the best plan for you. ',
            style: TextStyle(
                fontSize: 18,
                color: kFlourishBlackish), // Default style for all TextSpans.
            children: <TextSpan>[
              TextSpan(
                text: 'Cancel anytime.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold,
                  color: kFlourishBlackish,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntervalControls() {
    // If there are multiple intervals, show the segmented control
    return SizedBox(
      width: 500,
      child: CupertinoSlidingSegmentedControl<Interval>(
        backgroundColor: Colors.blueGrey.withOpacity(0.3),

        children: const {
          Interval.monthly: Text(
            'Monthly',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
            ),
          ),
          Interval.yearly: Text(
            'Yearly',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
            ),
          ),
        },
        onValueChanged: (Interval? value) {
          setState(() {
            _selectedInterval = value!; // Update the selected interval
          });
        },
        groupValue: _selectedInterval, // Set the currently selected interval
      ),
    );
  }

  Widget _buildShimmerProductListing() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < 2; i++) ...[
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: 350,
              height: 500,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          if (i < 1) const SizedBox(width: 10),
        ],
      ],
    );
  }

  Widget _buildProductListing() {
    late final List<Product> products;
    if (_selectedInterval == Interval.monthly) {
      products = _monthlyProducts;
    } else {
      products = _yearlyProducts;
    }

    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center, // Aligns the products in the row
      children: [
        for (int i = 0; i < products.length; i++) ...[
          ProductDetails(
            product: products[i],
            selectedInterval: _selectedInterval,
            onError: ((value) {
              setState(() => _error = value);
            }),
          ), // Build the product container
          if (i <
              products.length -
                  1) // Check to avoid adding a SizedBox after the last product
            const SizedBox(width: 10), // Add a SizedBox for spacing
        ],
      ],
    );
  }
}

class ProductDetails extends StatefulWidget {
  const ProductDetails(
      {required this.product,
      required this.selectedInterval,
      required this.onError,
      super.key});

  final Product product;
  final Interval selectedInterval;
  final ValueChanged<bool> onError;

  @override
  State<ProductDetails> createState() => _ProductDetailsState();
}

class _ProductDetailsState extends State<ProductDetails> {
  bool _loading = false;
  final _logger = getLogger('Product Details Widget');
  @override
  Widget build(BuildContext context) {
    List<ProductPrice> prices = widget.product.prices;

    // Filter prices based on the selected interval (assumed to be defined elsewhere)
    ProductPrice? selectedPrice;
    if (widget.selectedInterval == Interval.monthly) {
      selectedPrice = prices.firstWhere(
        (price) => price.interval == PricingInterval.month,
      );
    } else if (widget.selectedInterval == Interval.yearly) {
      selectedPrice = prices.firstWhere(
        (price) => price.interval == PricingInterval.year,
      );
    }

    double price = selectedPrice!.unitAmount! / 100;

    if (widget.selectedInterval == Interval.yearly) {
      price /= 12;
    }
    String priceText = '\$$price / month';
    bool isFree = price == 0;

    return Container(
      height: 500,
      width: 350,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.blueGrey.withOpacity(0.3),
          width: 2.0,
        ),
        borderRadius: const BorderRadius.all(
          Radius.circular(10.0),
        ),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.product.product.name ?? 'Unnamed Product',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 35.0,
                  fontWeight: FontWeight.bold,
                  color: widget.product.product.color,
                ),
              ),
              const SizedBox(height: 5.0),
              Text(
                priceText,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 20.0),
              Center(
                child: Container(
                  height: 1,
                  width: 300,
                  color: Colors.blueGrey.withOpacity(0.3),
                ),
              ),
              const SizedBox(height: 20.0),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        widget.product.product.featureList!.map((featureName) {
                      return buildFeatureListItem(featureName!);
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ElevatedButton(
              onPressed: isFree || _loading
                  ? null
                  : () async {
                      try {
                        setState(() {
                          _loading = true;
                          widget.onError(false);
                        });
                        String url = await StripeSubscriptionService()
                            .createCheckoutSession(
                                widget.product.prices.first.docId!);
                        _logger.i(
                            'Checkout url received succesfully! Redirecting to $url');
                        if (await canLaunchUrlString(url)) {
                          await launchUrlString(
                              url); // TODO dont make a new tab
                          setState(() => _loading = false);
                        } else {
                          setState(() => _loading = false);
                          widget.onError(true);
                        }
                      } catch (e) {
                        setState(() => _loading = false);
                        widget.onError(true);
                      }
                    },
              style: ElevatedButton.styleFrom(
                shadowColor: kFlourishAliceBlue,
                overlayColor: Colors.transparent,
                backgroundColor: widget.product.product.color,
                minimumSize: const Size(350, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                isFree ? 'Current Plan' : 'Get ${widget.product.product.name}',
                style: const TextStyle(
                  color: kFlourishBlackish,
                  fontSize: 16.0,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildFeatureListItem(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const Text('•  ',
            style: TextStyle(
                fontFamily: 'Inter', color: kFlourishBlackish, fontSize: 20)),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontFamily: 'Inter',
                    color: kFlourishBlackish,
                    fontSize: 18.0))),
      ],
    );
  }
}

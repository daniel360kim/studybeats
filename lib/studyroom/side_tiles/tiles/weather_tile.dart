import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/side_widgets/objects.dart';
import 'package:studybeats/api/side_widgets/side_widget_service.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/secrets.dart'; // Ensure your OPEN_WEATHER_API_KEY is here
import 'package:studybeats/studyroom/side_tiles/tiles/side_widget_tile.dart';
import 'package:uuid/uuid.dart';
import 'package:weather/weather.dart';

class WeatherTile extends SideWidgetTile {
  const WeatherTile(
      {required this.isPreview, required super.settings, super.key});

  final bool isPreview;

  WeatherTile.withDefaults({required this.isPreview, super.key})
      : super(
          settings: SideWidgetSettings(
            widgetId: const Uuid().v4(),
            title: 'Weather',
            description: 'Displays the current weather',
            type: SideWidgetType.weather,
            size: {'width': 1, 'height': 1},
            data: {
              'theme': 'default',
              'location': 'auto',
              'isCelsius': true, // Default to Celsius
            },
          ),
        );

  @override
  State<WeatherTile> createState() => _WeatherTileState();

  @override
  SideWidgetSettings get defaultSettings {
    return SideWidgetSettings(
      widgetId: const Uuid().v4(),
      title: 'Weather',
      description: 'Displays the current weather',
      type: SideWidgetType.weather,
      size: {'width': 1, 'height': 1},
      data: {
        'theme': 'default',
        'location': 'auto',
        'isCelsius': true,
      },
    );
  }
}

// Add SingleTickerProviderStateMixin for animation
class _WeatherTileState extends State<WeatherTile>
    with SingleTickerProviderStateMixin {
  Weather? _weather;
  bool _isLoading = true;
  String? _errorMessage;
  LocationPermission? _locationPermission;

  // Animation and state for the flip
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isFlipped = false;

  // Setting state
  late bool _isCelsius;

  @override
  void initState() {
    super.initState();
    _isCelsius = widget.settings.data['isCelsius'] ?? true;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);

    _checkLocationPermission();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_isFlipped) {
      _animationController.reverse();
    } else {
      _animationController.forward();
    }
    _isFlipped = !_isFlipped;
  }

  // --- Data Fetching and Permission Logic (no changes) ---
  Future<void> _checkLocationPermission() async {
    setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      setState(() => _locationPermission = permission);
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        _fetchWeatherData();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      getLogger('Weather Tile').e('Error checking location permission: $e');
      setState(() {
        _errorMessage = "Error checking location.";
        _isLoading = false;
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      setState(() => _locationPermission = permission);
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        _fetchWeatherData();
      }
    } catch (e) {
      getLogger('Weather Tile').e('Error requesting location permission: $e');
      setState(() => _errorMessage = "Failed to request permission.");
    }
  }

  Future<void> _fetchWeatherData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final WeatherFactory wf = WeatherFactory(OPEN_WEATHER_API_KEY);
      final Weather weather = await wf.currentWeatherByLocation(
        position.latitude,
        position.longitude,
      );
      setState(() {
        _weather = weather;
        _isLoading = false;
      });
    } catch (e) {
      getLogger('Weather Tile').e('Error fetching weather data: $e');
      setState(() {
        _errorMessage = "Failed to load weather data";
        _isLoading = false;
      });
    }
  }

  LinearGradient _getWeatherGradient({int? code, bool isFront = true}) {
    // Default to a pleasant cloudy day gradient
    if (code == null) {
      return LinearGradient(
        colors: isFront
            ? [Colors.blueGrey.shade200, Colors.blueGrey.shade500]
            : [Colors.blueGrey.shade400, Colors.blueGrey.shade700],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }

    // Thunderstorm
    if (code >= 200 && code < 300) {
      return LinearGradient(
        colors: isFront
            ? [const Color(0xff373B44), const Color(0xff4286f4)]
            : [const Color(0xff232526), const Color(0xff414345)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }
    // Drizzle & Rain
    if (code >= 300 && code < 600) {
      return LinearGradient(
        colors: isFront
            ? [const Color(0xff373B44), const Color(0xff4286f4)]
            : [const Color(0xff232526), const Color(0xff414345)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }
    // Snow
    if (code >= 600 && code < 700) {
      return LinearGradient(
        colors: isFront
            ? [const Color(0xffE6DADA), const Color(0xff274046)]
            : [const Color(0xffC6BABA), const Color(0xff072026)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }
    // Atmosphere (Mist, Fog, etc.)
    if (code >= 700 && code < 800) {
      return LinearGradient(
        colors: isFront
            ? [Colors.grey.shade500, Colors.grey.shade700]
            : [Colors.grey.shade600, Colors.grey.shade800],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }
    // Clear Sky
    if (code == 800) {
      return LinearGradient(
        colors: isFront
            ? [const Color(0xff2980B9), const Color(0xff6DD5FA)]
            : [const Color(0xff096099), const Color(0xff4DADD8)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }
    // Clouds
    if (code > 800 && code <= 804) {
      return LinearGradient(
        colors: isFront
            ? [const Color(0xff606c88), const Color(0xff3f4c6b)]
            : [const Color(0xff404c68), const Color(0xff1f2c4b)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }

    // Default fallback
    return LinearGradient(
      colors: isFront
          ? [Colors.blueGrey.shade200, Colors.blueGrey.shade500]
          : [Colors.blueGrey.shade400, Colors.blueGrey.shade700],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  IconData _getWeatherIcon(int? code) {
    if (code == null) return Icons.wb_sunny_outlined;
    if (code >= 200 && code < 300) return Icons.thunderstorm_outlined;
    if (code >= 300 && code < 400) return Icons.grain_outlined;
    if (code >= 500 && code < 600) return Icons.umbrella_outlined;
    if (code >= 600 && code < 700) return Icons.ac_unit_outlined;
    if (code >= 700 && code < 800) return Icons.foggy;
    if (code == 800) return Icons.wb_sunny_outlined;
    if (code > 800) return Icons.cloud_outlined;
    return Icons.wb_sunny_outlined;
  }

  // --- UI Builder Methods ---

  Widget _buildFront() {
    final temp = _isCelsius
        ? _weather?.temperature?.celsius?.toStringAsFixed(0)
        : _weather?.temperature?.fahrenheit?.toStringAsFixed(0);
    final highTemp = _isCelsius
        ? _weather?.tempMax?.celsius?.toStringAsFixed(0)
        : _weather?.tempMax?.fahrenheit?.toStringAsFixed(0);
    final lowTemp = _isCelsius
        ? _weather?.tempMin?.celsius?.toStringAsFixed(0)
        : _weather?.tempMin?.fahrenheit?.toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getWeatherGradient(
            code: _weather?.weatherConditionCode,
            isFront: true,
          ).colors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Flexible(
              child: Text(_weather?.areaName ?? 'Unknown',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.location_on, size: 14, color: Colors.white),
          ]),
          const SizedBox(height: 8),
          Text('${temp ?? 'N/A'}°',
              style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w300,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Row(children: [
            Icon(_getWeatherIcon(_weather?.weatherConditionCode),
                color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Flexible(
                child: Text(_weather?.weatherDescription ?? 'N/A',
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                    overflow: TextOverflow.ellipsis)),
          ]),
          const Spacer(),
          Text('H:${highTemp ?? 'N/A'}°  L:${lowTemp ?? 'N/A'}°',
              style: const TextStyle(fontSize: 12, color: Colors.white70))
        ],
      ),
    );
  }

  Widget _buildBack() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getWeatherGradient(
            code: _weather?.weatherConditionCode,
            isFront: false,
          ).colors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Unit',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 8),
          ToggleButtons(
            isSelected: [_isCelsius, !_isCelsius],
            onPressed: (index) {
              setState(() {
                _isCelsius = index == 0;
                // In a real app, you would save this to the settings object
                // widget.settings.data['isCelsius'] = _isCelsius;
                // SideWidgetService.updateWidget(widget.settings);
              });
            },
            color: Colors.white70,
            selectedColor: Colors.blueGrey.shade700,
            fillColor: Colors.white,
            splashColor: Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            constraints: const BoxConstraints(minHeight: 36, minWidth: 50),
            children: const [Text('°C'), Text('°F')],
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () async {
              _flipCard();
              final sideWidgetService = SideWidgetService();
              await sideWidgetService.init();
              await sideWidgetService.saveWidgetSettings(
                widget.settings.copyWith(
                  data: {
                    ...widget.settings.data,
                    'isCelsius': _isCelsius,
                  },
                ),
              );
            },
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('Done', style: TextStyle(color: Colors.white)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLocationPermissionUI() {
    // ... (no changes to this method)
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueGrey.shade200, Colors.blueGrey.shade500],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.location_off_outlined,
                color: Colors.white, size: 30),
            const SizedBox(height: 12),
            const Text('Enable location to see local weather.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            OutlinedButton(
                onPressed: _requestLocationPermission,
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6)),
                child: const Text('Enable', style: TextStyle(fontSize: 10)))
          ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPreview) {
      return _buildPreview();
    }
    // Handle loading and error states first
    if (_isLoading) {
      return SizedBox(
          width: kTileUnitWidth,
          height: kTileUnitHeight,
          child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                  decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(16)))));
    }
    if (_locationPermission == LocationPermission.denied ||
        _locationPermission == LocationPermission.deniedForever) {
      return SizedBox(
          width: kTileUnitWidth,
          height: kTileUnitHeight,
          child: _buildLocationPermissionUI());
    }
    if (_errorMessage != null) {
      // ... error UI
    }

    // Main flip animation widget
    return GestureDetector(
      onTap: _weather != null ? _flipCard : null,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * pi;
          final isFront = _animation.value < 0.5;

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isFront
                ? _buildFront()
                : Transform(
                    transform: Matrix4.identity()..rotateY(pi), // flip back
                    alignment: Alignment.center,
                    child: _buildBack(),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      height: kTileUnitHeight,
      width: kTileUnitWidth,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getWeatherGradient(
            code: 800, // Clear sky for preview
            isFront: true,
          ).colors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  'Your City',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.location_on, size: 14, color: Colors.white),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '24°',
            style: TextStyle(
                fontSize: 36, fontWeight: FontWeight.w300, color: Colors.white),
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.wb_sunny_outlined, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Sunny',
                  style: TextStyle(fontSize: 13, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

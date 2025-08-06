import 'package:fl_location/fl_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert' as convert;

void main() {
  runApp(MyApp());
}

class BusStop {
  final double longitude;
  final double latitude;
  final String stopName;
  final String headSign;

  BusStop({
    required this.latitude,
    required this.longitude,
    required this.stopName,
    required this.headSign,
  });

  factory BusStop.fromJson(Map<String, dynamic> json) {
    return BusStop(
      latitude: json['latitude'],
      longitude: json['longitude'],
      stopName: json['stop_name'],
      headSign: json['headsign'],
    );
  }
}

class PointOfInterest {
  final double longitude;
  final double latitude;
  final String stopName;
  final int routeId;
  final String name;

  PointOfInterest({
    required this.latitude,
    required this.longitude,
    required this.stopName,
    required this.routeId,
    required this.name,
  });

  factory PointOfInterest.fromJson(Map<String, dynamic> json) {
    return PointOfInterest(
      latitude: json['latitude'],
      longitude: json['longitude'],
      stopName: json['stop_name'],
      routeId: json['route_id'],
      name: json['name'],
    );
  }
}

class ApiResponse {
  final List<BusStop> stops;
  final List<PointOfInterest> pois;

  ApiResponse({required this.stops, required this.pois});

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      stops: (json['stops'] as List)
          .map((stop) => BusStop.fromJson(stop))
          .toList(),
      pois: (json['pois'] as List)
          .map((poi) => PointOfInterest.fromJson(poi))
          .toList(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Button Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _message = 'Press the button!';
  List<StaticPositionGeoPoint> staticPoints;

  _MyHomePageState()
    : staticPoints = getNearbyStopsAndPois(getLocation()),
      super();

  static Future<Location> getLocation() async {
    // TODO: Update for non-web platforms
    //if (await _requestLocationPermission()) {
    return await FlLocation.getLocation();
    //}
  }

  static List<StaticPositionGeoPoint> getNearbyStopsAndPois(
    Future<Location> currentLocation,
  ) {
    List<StaticPositionGeoPoint> staticPoints = [];
    currentLocation
        .then((currentLocation) {
          print('Current location retrieved');
          GeoPoint geoPointLocation = GeoPoint(
            latitude: currentLocation.latitude,
            longitude: currentLocation.longitude,
          );
          // Invoke API and get back response
          fetchBusStopsAndPois(geoPointLocation).then((ApiResponse response) {
            print(
              'Fetched ${response.stops.length} bus stops and ${response.pois.length} POIs',
            );

            List<GeoPoint> stopGeoPoints = response.stops
                .map(
                  (stop) => GeoPoint(
                    latitude: stop.latitude,
                    longitude: stop.longitude,
                  ),
                )
                .toList();
            List<GeoPoint> poiGeoPoints = response.pois
                .map(
                  (poi) => GeoPoint(
                    latitude: poi.latitude,
                    longitude: poi.longitude,
                  ),
                )
                .toList();

            staticPoints.add(
              StaticPositionGeoPoint(
                'stopGeoPoints',
                MarkerIcon(
                  icon: Icon(Icons.bus_alert, color: Colors.red, size: 28),
                ),
                stopGeoPoints,
              ),
            );
            staticPoints.add(
              StaticPositionGeoPoint(
                'poiGeoPoints',
                MarkerIcon(
                  icon: Icon(Icons.place, color: Colors.orange, size: 28),
                ),
                poiGeoPoints,
              ),
            );
          });
        })
        .catchError((error) {
          print('Error fetching bus stops and POIs: $error');
        });

    return staticPoints;
  }

  static Future<ApiResponse> fetchBusStopsAndPois(
    GeoPoint currentLocation,
  ) async {
    // TODO: Update to support non-local API
    var url = Uri.http('127.0.0.1:8000', 'api/');
    try {
      var response = await http.post(
        url,
        body:
            '{ "latitude": "${currentLocation.latitude}", "longitude": "${currentLocation.longitude}" }',
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        return ApiResponse.fromJson(convert.jsonDecode(response.body));
      } else {
        print('Failed to fetch data: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      print('Socket Exception: ${e.message}');
      if (e.osError != null) {
        print('OS Error Code: ${e.osError!.errorCode}');
        print('OS Error Message: ${e.osError!.message}');
      }
    } on http.ClientException catch (e) {
      print('HTTP Client Exception: ${e.message}');
    }

    throw Exception('Failed to fetch data');
  }

  void _handleButtonPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MapScreen(staticPoints)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Button Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(_message, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 20), // Adds some space
            ElevatedButton(
              onPressed:
                  _handleButtonPressed, // The function called on button press
              child: const Text('Click Me'),
            ),
          ],
        ),
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  List<StaticPositionGeoPoint> staticPoints;

  MapScreen(List<StaticPositionGeoPoint> staticPointList)
    : staticPoints = staticPointList,
      super();

  @override
  _MapScreenState createState() => _MapScreenState(staticPoints);
}

class _MapScreenState extends State<MapScreen> {
  List<StaticPositionGeoPoint> staticPoints;

  _MapScreenState(List<StaticPositionGeoPoint> staticPointsList)
    : staticPoints = staticPointsList,
      super();

  @override
  Widget build(BuildContext context) {
    // init the position using the user location
    final mapController = MapController.withUserPosition(
      trackUserLocation: UserTrackingOption(
        enableTracking: true,
        unFollowUser: false,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text('OneBus')),
      body: OSMFlutter(
        controller: mapController,
        osmOption: OSMOption(
          zoomOption: ZoomOption(initZoom: 13), // Initial zoom level
          userTrackingOption: UserTrackingOption(
            enableTracking: true, // Enable user location tracking
            unFollowUser: false,
          ),
          roadConfiguration: RoadOption(roadColor: Colors.blueAccent),
          userLocationMarker: UserLocationMaker(
            personMarker: const MarkerIcon(
              icon: Icon(
                Icons.location_history_rounded,
                color: Colors.blue,
                size: 36,
              ),
            ),
            directionArrowMarker: const MarkerIcon(
              icon: Icon(Icons.double_arrow, size: 36),
            ),
          ),
          // Need to use static points to avoid icon issue: https://github.com/liodali/osm_flutter/issues/541
          staticPoints: staticPoints,
          //  [StaticPositionGeoPoint('stopGeoPoints', MarkerIcon(icon: Icon(Icons.bus_alert, color: Colors.red, size: 28)), [GeoPoint(latitude: 30.315717, longitude:-97.73635)]),
          //  StaticPositionGeoPoint('poiGeoPoints', MarkerIcon(icon: Icon(Icons.place, color: Colors.orange, size: 28)), [GeoPoint(latitude: 30.325717, longitude:-97.74635)])],
        ),
        onGeoPointClicked: (geoPoint) {
          print(
            'Marker clicked at: ${geoPoint.latitude}, ${geoPoint.longitude}',
          );
        },
        onLocationChanged: (geoPoint) {
          print(
            'User location changed to: ${geoPoint.latitude}, ${geoPoint.longitude}',
          );
        },
      ),
    );
  }
}

import 'package:fl_location/fl_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:http/http.dart' as http;
import 'package:pointer_interceptor/pointer_interceptor.dart';
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
  final String amenity;

  PointOfInterest({
    required this.latitude,
    required this.longitude,
    required this.stopName,
    required this.routeId,
    required this.name,
    required this.amenity,
  });

  factory PointOfInterest.fromJson(Map<String, dynamic> json) {
    return PointOfInterest(
      latitude: json['latitude'],
      longitude: json['longitude'],
      stopName: json['stop_name'],
      routeId: json['route_id'],
      name: json['name'],
      amenity: json['amenity'],
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

class MapContent {
  final List<StaticPositionGeoPoint> staticPoints;
  final Map<GeoPoint, BusStop> stops;
  final Map<GeoPoint, PointOfInterest> pois;

  MapContent({
    required this.staticPoints,
    required this.stops,
    required this.pois,
  });
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
  final MapContent mapContent;

  _MyHomePageState()
    // TODO: We may want to change this to call the API when the button is pressed and
    // display a loading indicator until complete. Right now we're just assuming that the data will
    // be available by the time the map is created.
    : mapContent = getNearbyStopsAndPois(getLocation()),
      super();

  static Future<Location> getLocation() async {
    // TODO: Update for non-web platforms
    //if (await _requestLocationPermission()) {
    return await FlLocation.getLocation();
    //}
  }

  static MapContent getNearbyStopsAndPois(
    Future<Location> currentLocation,
  ) {
    // create staticPoints to store the location of bus stops
    List<StaticPositionGeoPoint> staticPoints = [];
    Map<GeoPoint, BusStop> stops = {};
    Map<GeoPoint, PointOfInterest> pois = {};
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

            List<GeoPoint> stopGeoPoints = [];
            for (var stop in response.stops) {
              GeoPoint geoPoint = GeoPoint(
                latitude: stop.latitude,
                longitude: stop.longitude,
              );
              stops[geoPoint] = stop;
              stopGeoPoints.add(geoPoint);
            }

            List<GeoPoint> poiGeoPoints = [];
            List<GeoPoint> restaurantGeoPoints = [];
            List<GeoPoint> cafeGeoPoints = [];
            List<GeoPoint> barGeoPoints = [];
            List<GeoPoint> worshipGeoPoints = [];
            for (var poi in response.pois) {
              GeoPoint geoPoint = GeoPoint(
                latitude: poi.latitude,
                longitude: poi.longitude,
              );

              if (stops.containsKey(geoPoint)) {
                // If the POI is at the same exact coordinates as a bus stop, skip it
                print('Skipping POI at the same location as bus stop: ${poi.name} at ${geoPoint.latitude}, ${geoPoint.longitude}');
                continue;
              }
              pois[geoPoint] = poi;

              if (poi.amenity == 'restaurant') {
                restaurantGeoPoints.add(geoPoint);
              } else if (poi.amenity == 'cafe') {
                cafeGeoPoints.add(geoPoint);
              } else if (poi.amenity == 'bar') {
                barGeoPoints.add(geoPoint);
              } else if (poi.amenity == 'place_of_worship') {
                worshipGeoPoints.add(geoPoint);
              } else {
                poiGeoPoints.add(geoPoint);
              }
            }


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
            staticPoints.add(
              StaticPositionGeoPoint(
                'restaurantGeoPoints',
                MarkerIcon(
                  icon: Icon(Icons.restaurant, color: Colors.green, size: 28),
                ),
                restaurantGeoPoints,
              ),
            );
            staticPoints.add(
              StaticPositionGeoPoint(
                'cafeGeoPoints',
                MarkerIcon(
                  icon: Icon(Icons.local_cafe, color: Colors.brown, size: 28),
                ),
                cafeGeoPoints,
              ),
            );
            staticPoints.add(
              StaticPositionGeoPoint(
                'barGeoPoints',
                MarkerIcon(
                  icon: Icon(Icons.local_bar, color: Colors.blue, size: 28),
                ),
                barGeoPoints,
              ),
            );
            staticPoints.add(
              StaticPositionGeoPoint(
                'worshipGeoPoints',
                MarkerIcon(
                  // TODO: Replace with a generic place of worship icon
                  icon: Icon(Icons.church, color: Colors.purple, size: 28),
                ),
                worshipGeoPoints,
              ),
            );
          });
        })
        .catchError((error) {
          print('Error fetching bus stops and POIs: $error');
          throw Exception('Failed to fetch bus stops and POIs');
        });

    return MapContent(staticPoints: staticPoints, stops: stops, pois: pois);
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
      MaterialPageRoute(builder: (context) => MapScreen(mapContent)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OneBus')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text("Click here to see nearby bus stops and places you can visit.", style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 20), // Adds some space
            ElevatedButton(
              onPressed:
                  _handleButtonPressed, // The function called on button press
              child: const Text('Show the map!'),
            ),
          ],
        ),
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  final MapContent mapContent;

  MapScreen(this.mapContent);

  @override
  _MapScreenState createState() => _MapScreenState(mapContent);
}

class _MapScreenState extends State<MapScreen> {
  List<StaticPositionGeoPoint> staticPoints;
  late List<GeoPoint> allGeoPoints = [];
  late MapController mapController;

  _MapScreenState(List<StaticPositionGeoPoint> staticPointsList)
      : staticPoints = staticPointsList,
        super() {
    // Extract geo points from staticPoints
    for (var staticPoint in staticPointsList) {
      // Access the points through the geoPoints property
      allGeoPoints.addAll(staticPoint.geoPoints);
    }
  }

  @override
  void initState() {
    super.initState();
    mapController = MapController.withUserPosition(
      trackUserLocation: UserTrackingOption(
        enableTracking: true,
        unFollowUser: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('OneBus')),
      body: Row(
        children: [
          // Map takes 70% of the width
          Expanded(
            flex: 7,
            child: OSMFlutter(
              controller: mapController,
              osmOption: OSMOption(
                zoomOption: ZoomOption(initZoom: 13),
                userTrackingOption: UserTrackingOption(
                  enableTracking: true,
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
                staticPoints: staticPoints,
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
          ),
          // ListView takes 30% of the width
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.grey[200],
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Points of Interest',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: allGeoPoints.length,
                      itemBuilder: (context, index) {
                        final point = allGeoPoints[index];
                        return Card(
                          margin: EdgeInsets.all(8),
                          child: ListTile(
                            title: Text('Point ${index + 1}'),
                            subtitle: Text(
                              'Lat: ${point.latitude.toStringAsFixed(6)}\n'
                              'Lon: ${point.longitude.toStringAsFixed(6)}'
                              
                            ),
                            onTap: () {
                              mapController.moveTo(
                                GeoPoint(
                                  latitude: point.latitude,
                                  longitude: point.longitude,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
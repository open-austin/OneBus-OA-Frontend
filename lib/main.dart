import 'package:fl_location/fl_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:http/http.dart' as http;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'dart:io';
import 'dart:convert' as convert;
import 'package:url_launcher/url_launcher.dart';

void main() {
  print('🎯 MAIN FUNCTION RUNNING'); // 👈 MUST appear
  runApp(MyApp());
}
class BusStop {
  final double longitude;
  final double latitude;
  final String stopName;
  final String headSign;
  final bool originStop;


  BusStop({
    required this.latitude,
    required this.longitude,
    required this.stopName,
    required this.headSign,
    required this.originStop,
  });

  factory BusStop.fromJson(Map<String, dynamic> json) {
    return BusStop(
      latitude: json['latitude'],
      longitude: json['longitude'],
      stopName: json['stop_name'],
      headSign: json['headsign'],
      originStop: json['origin_stop'],
    );
  }
}

class PointOfInterest {
  final double longitude;
  final double latitude;
  final String mapUrl;
  final String stopName;
  final int routeId;
  final int numstopsAway;
  final String name;
  final String amenity;
  final String amenityCategory;

  PointOfInterest({
    required this.latitude,
    required this.longitude,
    required this.mapUrl,
    required this.stopName,
    required this.routeId,
    required this.numstopsAway,
    required this.name,
    required this.amenity,
    required this.amenityCategory,

  });

  factory PointOfInterest.fromJson(Map<String, dynamic> json) {
    return PointOfInterest(
      latitude: json['latitude'],
      longitude: json['longitude'],
      mapUrl: json['map_url'],
      stopName: json['stop_name'],
      routeId: json['route_id'],
      numstopsAway: json['num_stops_away'],
      name: json['name'],
      amenity: json['amenity'],
      amenityCategory: json['amenity_category'],
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
      title: 'OneBus',
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
            List<GeoPoint> originStopPoints = [];
            for (var stop in response.stops) {
              GeoPoint geoPoint = GeoPoint(
                latitude: stop.latitude,
                longitude: stop.longitude,
              );
              stopGeoPoints.add(geoPoint); 
              if (stop.originStop == true) { 
                originStopPoints.add(geoPoint); 
              } else {
                stopGeoPoints.add(geoPoint); 
              }
              stops[geoPoint] = stop;
            }

            List<GeoPoint> poiGeoPoints = [];
            List<GeoPoint> foodServicesGeoPoints = [];
            List<GeoPoint> commercialGeoPoints = [];
            List<GeoPoint> communityServicesGeoPoints = [];
            List<GeoPoint> recreationGeoPoints = [];
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

              if (poi.amenityCategory == 'Food Services') {
                foodServicesGeoPoints.add(geoPoint);
              } else if (poi.amenityCategory == 'Commercial') {
                commercialGeoPoints.add(geoPoint);
              } else if (poi.amenityCategory == 'Community Services') {
                communityServicesGeoPoints.add(geoPoint);
              } else if (poi.amenityCategory == 'Recreation') {
                recreationGeoPoints.add(geoPoint);
              } else {
                poiGeoPoints.add(geoPoint);
              }
            }

            staticPoints.add(
              StaticPositionGeoPoint(
                'stopGeoPoints',
                MarkerIcon(
                  icon: Icon(Icons.bus_alert, color: const Color.fromARGB(255, 22, 18, 18), size: 28),
                ),
                stopGeoPoints,
              ),
            );
            // TODO: Decide if any other features should be added along with origin stops indicator
            staticPoints.add(
              StaticPositionGeoPoint(
                'originStopPoints',
                MarkerIcon(
                  icon: Icon(Icons.bus_alert, color: const Color.fromARGB(255, 22, 18, 18), size: 28),
                ),
                originStopPoints,
              ),
            );
            staticPoints.add(
              StaticPositionGeoPoint(
                'foodServicesGeoPoints',
                MarkerIcon(
                  icon: Icon(Icons.restaurant, color: Colors.green, size: 28),
                ),
                foodServicesGeoPoints,
              ),
            );
            staticPoints.add(
              StaticPositionGeoPoint(
                'commercialGeoPoints',
                MarkerIcon(
                  icon: Icon(Icons.shop, color: Colors.brown, size: 28),
                ),
                commercialGeoPoints,
              ),
            );
            staticPoints.add(
              StaticPositionGeoPoint(
                'communityServicesGeoPoints',
                MarkerIcon(
                  icon: Icon(Icons.people, color: Colors.blue, size: 28),
                ),
                communityServicesGeoPoints,
              ),
            );
            staticPoints.add(
              StaticPositionGeoPoint(
                'recreationGeoPoints',
                MarkerIcon(
                  icon: Icon(Icons.theaters, color: Colors.purple, size: 28),
                ),
                recreationGeoPoints,
              ),
            );
            // This should be empty unless a POI has an unknown amenityCategory
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
          throw Exception('Failed to fetch bus stops and POIs');
        });

    return MapContent(staticPoints: staticPoints, stops: stops, pois: pois);
  }

  static Future<ApiResponse> fetchBusStopsAndPois(
    GeoPoint currentLocation,
  ) async {
    // Swap which URL is commented out depending on whether you're testing locally or using the deployed API
    // var url = Uri.http('127.0.0.1:8000', 'api/');
    var url = Uri.http('onebus.us-east-2.elasticbeanstalk.com', '/api/');

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
  MapContent mapContent;
  
  _MapScreenState(this.mapContent);

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
      body: Column(
        children: [ 
          Expanded( 
            // Map takes 60% of height
            flex: 6,
            child: OSMFlutter(
              controller: mapController,
              osmOption: OSMOption(
                zoomOption: ZoomOption(initZoom: 15), // Initial zoom level
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
                      size: 48,
                    ),
                  ),
                  directionArrowMarker: const MarkerIcon(
                    icon: Icon(Icons.double_arrow, size: 36),
                  ),
                ),
                // Need to use static points to avoid icon issue: https://github.com/liodali/osm_flutter/issues/541
                staticPoints: mapContent.staticPoints,
              ),
              onGeoPointClicked: (geoPoint) {
                String title = '';
                String content = '';
                Uri? mapUrl;
                if (mapContent.stops.containsKey(geoPoint)) {
                  BusStop stop = mapContent.stops[geoPoint]!;
                  title = 'Bus Stop: ${stop.stopName}';
                  content = 'Stop Details: ${stop.headSign}';
                } else if (mapContent.pois.containsKey(geoPoint)) {
                  PointOfInterest poi = mapContent.pois[geoPoint]!;
                  title = poi.name;
                  // Get a title case version of the amenity type
                  String poiType = poi.amenity[0].toUpperCase() +
                      poi.amenity.substring(1).toLowerCase().replaceAll('_', ' ');
                  content = '$poiType on ${poi.routeId} bus route, ${poi.numstopsAway} stops away!';
                  mapUrl = Uri.tryParse(poi.mapUrl);
                } else {
                  title = 'Unknown Location';
                  content = 'No information available for this location.';
                  print('Clicked on an unknown location: $geoPoint');
                }
                // When a marker is clicked, show a popup with PointerInterceptor
                showDialog(
                  context: context,
                  builder: (context) => PointerInterceptor(
                    // The PointerInterceptor is crucial here for web platforms
                    child: AlertDialog(
                      title: Text(title),
                      // If a map URL is available, include a link to Google Maps
                      content: mapUrl != null
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(content),
                                SizedBox(height: 10),
                                GestureDetector(
                                  onTap: () {
                                    launchUrl(mapUrl!, mode: LaunchMode.externalApplication);
                                  },
                                  child: Text(
                                    'View in Google Maps',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Text(content),
                      actions: [
                        TextButton(
                          // This button will work on web thanks to PointerInterceptor
                          onPressed: () => Navigator.pop(context),
                          child: Text('Close'),
                        ),
                      ],
                    ),
                  ),
                );
              },
              onLocationChanged: (geoPoint) {
                print(
                  'User location changed to: ${geoPoint.latitude}, ${geoPoint.longitude}',
                );
              },
            ),
          ),
          
          // ListView takes 40% of height
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Nearby Points of Interest',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: mapContent.pois.length,
                      itemBuilder: (BuildContext context, int index) {
                        final sortedPois = mapContent.pois.values.toList()
                          ..sort((a, b) => a.numstopsAway.compareTo(b.numstopsAway));
                        final item = sortedPois[index];
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: ListTile(
                            title: Text('Point ${index + 1}'),
                            subtitle: Text(item.name, style: TextStyle(fontSize: 16)),
                            trailing: Text('${item.numstopsAway} stops away'),
                          ),
                        );
                      },
                      physics: const ClampingScrollPhysics(), // Android-like
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

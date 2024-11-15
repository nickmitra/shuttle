import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:rider_app/AllScreens/registrationScreen.dart';
import 'package:rider_app/AllScreens/searchScreen.dart';
import 'package:rider_app/Assistants/assistantMethods.dart';
import '../AllWidgets/Divider.dart';
import 'package:rider_app/DataHandler/appData.dart';
import '../AllWidgets/noDriverAvialableDialog.dart';
import '../AllWidgets/progressDialog.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:rider_app/Assistants/geoFireAssistant.dart';
import '../Models/directDetails.dart';
import '../Models/nearbyAvailableDrivers.dart';
import '../configMaps.dart';

class MainScreen extends StatefulWidget {
  static const String idScreen = "mainScreen";

  @override
  _MainScreenState createState() => _MainScreenState();
}

class MyTickerProvider implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  Completer<GoogleMapController> _controllerGoogleMap = Completer();
  late GoogleMapController newGoogleMapController;
  GlobalKey<ScaffoldState> scaffoldKey = new GlobalKey<ScaffoldState>();
  late DirectionDetails tripDirectionDetails = DirectionDetails();

  List<LatLng> pLineCoordinates = [];
  Set<Polyline> polylineSet = {};

  Position? currentPosition;
  var geoLocator = Geolocator();
  double bottomPaddingOfMap = 0;
  Set<Marker> markersSet = {};
  Set<Circle> circlesSet = {};

  double rideDetailsContainerHeight = 0;
  double requestRideContainerHeight = 0;
  double searchContainerHeight = 300.0;
  double driverDetailsContainerHeight = 0;
  get driversRef => null;
  late StreamSubscription<DatabaseEvent> rideStreamSubscription;

  get res => null;

  get carRideType => null;

  var statusRide;

  var driverRequestTimeOut;

  set rideStatus(String rideStatus) {}

  bool drawerOpen = true;
  bool nearbyAvailableDriverKeysLoaded = false;

  Future<BitmapDescriptor> initializeNearbyIcon() async {
    // Load the icon image from the asset
    ImageConfiguration configuration = createLocalImageConfiguration(context);
    BitmapDescriptor icon = await BitmapDescriptor.fromAssetImage(
      configuration,
      'imagez/shuttle.png', // Replace with the actual path to your icon image asset
    );

    return icon;
  }

  late BitmapDescriptor _nearByIcon;

  late DatabaseReference rideRequestRef;
  late List<NearbyAvailableDrivers> availableDrivers;

  String state = "normal";

  //late StreamSubscription<Event> rideStreamSubscription;

  bool isRequestingPositionDetails = false;

  String uName = "";

  late AnimationController _controller;
  final Duration expandDuration = Duration(milliseconds: 160);

  @override
  void initState() {
    super.initState();
    AssistantMethods.getCurrentOnlineUserInfo();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 160),
    );
  }

  void toggleContainerHeight() {
    setState(() {
      searchContainerHeight = (searchContainerHeight == 0.0) ? 100.0 : 0.0;
      if (_controller.isDismissed) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void saveRideRequest() {
    rideRequestRef = FirebaseDatabase.instance.reference().child("Ride Requests").push();

    var pickUp = Provider.of<AppData>(context, listen: false).pickUpLocation;
    var dropOff = Provider.of<AppData>(context, listen: false).dropOffLocation;

    Map pickUpLocMap = {
      "latitude": pickUp.latitude.toString(),
      "longitude": pickUp.longitude.toString(),
    };

    Map dropOffLocMap = {
      "latitude": dropOff.latitude.toString(),
      "longitude": dropOff.longitude.toString(),
    };

    var userCurrentInfo;
    Map rideInfoMap = {
      "driver_id": "waiting",
      "payment_method": "cash",
      "pickup": pickUpLocMap,
      "dropoff": dropOffLocMap,
      "created_at": DateTime.now().toString(),
      "rider_name": userCurrentInfo?.name,
      "rider_phone": userCurrentInfo?.phone,
      "pickup_address": pickUp.placeName,
      "dropoff_address": dropOff.placeName,
      "ride_type": carRideType,
    };

    rideRequestRef.set(rideInfoMap);

    rideStreamSubscription = rideRequestRef.onValue.listen((event) async {
      if (event.snapshot.value == null) {
        return;
      }

      var snapshotValue = event.snapshot.value as Map<String, dynamic>;

      if (snapshotValue["car_details"] != null) {
        setState(() {
          var carDetailsDriver = snapshotValue["car_details"].toString();
        });
      }
      if (snapshotValue["driver_name"] != null) {
        setState(() {
          var driverName = snapshotValue["driver_name"].toString();
        });
      }
      if (snapshotValue["driver_phone"] != null) {
        setState(() {
          var driverphone = snapshotValue["driver_phone"].toString();
        });
      }

      if (snapshotValue["driver_location"] != null) {
        var driverLocation = snapshotValue["driver_location"] as Map<String, dynamic>;
        double driverLat = double.parse(driverLocation["latitude"].toString());
        double driverLng = double.parse(driverLocation["longitude"].toString());
        LatLng driverCurrentLocation = LatLng(driverLat, driverLng);

        if (statusRide == "accepted") {
          updateRideTimeToPickUpLoc(driverCurrentLocation);
        } else if (statusRide == "onride") {
          updateRideTimeToDropOffLoc(driverCurrentLocation);
        } else if (statusRide == "arrived") {
          setState(() {
            rideStatus = "Driver has Arrived.";
          });
        }
      }

      if (snapshotValue["status"] != null) {
        statusRide = snapshotValue["status"].toString();
      }
      if (statusRide == "accepted") {
        displayDriverDetailsContainer();
        Geofire.stopListener();
        deleteGeofileMarkers();
      }
      if (statusRide == "ended") {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) {
          return MainScreen(); // Replace YourNextScreen with the screen you want to navigate to
        }));

        rideRequestRef.onDisconnect();
        rideRequestRef.remove();
        rideStreamSubscription.cancel();
        rideStreamSubscription.cancel();
        resetApp();
      }
    });
  }

  void deleteGeofileMarkers() {
    setState(() {
      markersSet.removeWhere((element) => element.markerId.value.contains("driver"));
    });
  }

  void updateRideTimeToPickUpLoc(LatLng driverCurrentLocation) async {
    if (!isRequestingPositionDetails) {
      isRequestingPositionDetails = true;

      var positionUserLatLng = LatLng(currentPosition!.latitude, currentPosition!.longitude);
      var details = await AssistantMethods.obtainPlaceDirectionDetails(driverCurrentLocation, positionUserLatLng);
      if (details == null) {
        return;
      }
      setState(() {
        rideStatus = "Driver is Coming - " + details.durationText;
      });

      isRequestingPositionDetails = false;
    }
  }

  void updateRideTimeToDropOffLoc(LatLng driverCurrentLocation) async {
    if (!isRequestingPositionDetails) {
      isRequestingPositionDetails = true;

      var dropOff = Provider.of<AppData>(context, listen: false).dropOffLocation;
      double dropOffLat = dropOff.latitude ?? 0.0; // Provide a default value if null
      double dropOffLng = dropOff.longitude ?? 0.0; // Provide a default value if null

       var dropOffUserLatLng = LatLng(dropOffLat, dropOffLng);

      var details = await AssistantMethods.obtainPlaceDirectionDetails(driverCurrentLocation, dropOffUserLatLng);
      if(details == null)
      {
        return;
      }
      setState(() {
        rideStatus = "Going to Destination - " + details.durationText;
      });

      isRequestingPositionDetails = false;
    }
  }
  void cancelRideRequest()

  {
    rideRequestRef.remove();
    setState(() {
      state = "normal";
    });
  }
  void displayRequestRideContainer()
  {
    setState(() {
      requestRideContainerHeight = 250.0;
      rideDetailsContainerHeight = 0;
      bottomPaddingOfMap = 230.0;
      drawerOpen = true;
    });

    saveRideRequest();
  }

  void displayDriverDetailsContainer()
  {
    setState(() {
      requestRideContainerHeight = 0.0;
      rideDetailsContainerHeight = 0.0;
      bottomPaddingOfMap = 295.0;
      driverDetailsContainerHeight = 285.0;
    });
  }

  resetApp()
  {
    setState(() {
      drawerOpen = true;
      searchContainerHeight = 300.0;
      rideDetailsContainerHeight = 0;
      requestRideContainerHeight = 0;
      bottomPaddingOfMap = 230.0;

      polylineSet.clear();
      markersSet.clear();
      circlesSet.clear();
      pLineCoordinates.clear();

      statusRide = "";
      //driverName = "";
      //driverphone = "";
      //carDetailsDriver = "";
      rideStatus = "Driver is Coming";
      driverDetailsContainerHeight = 0.0;
    });

    locatePosition();
  }

  void displayRideDetailsContainer() async
  {
    await getPlaceDirection();

    setState(() {
      searchContainerHeight = 0;
      rideDetailsContainerHeight = 340.0;
      bottomPaddingOfMap = 360.0;
      drawerOpen = false;
    });
  }
  void locatePosition() async{
    Position position = await Geolocator.getCurrentPosition
      (
        desiredAccuracy: LocationAccuracy.high);
    currentPosition = position;

    LatLng latLatPosition = LatLng(position.latitude, position.longitude);

    CameraPosition cameraPosition = new CameraPosition(target: latLatPosition, zoom: 14);
    newGoogleMapController.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));

    String address = await AssistantMethods.searchCoordinateAddress(position, context);
    print("This is your address "+ address);
    initGeoFireListner();
  }
  static final CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );



  @override
  Widget build(BuildContext context) {
    initializeNearbyIcon();
    //createIconMarker();
    return Scaffold(
        key: scaffoldKey,
        appBar: AppBar(
          title: Text("Main Screen"),
        ),
        drawer: Container(
          color: Colors.white,
          width: 255.0,
          child: Drawer(
            child: ListView(
              children: [
                //Drawer Header
                Container(
                  height: 165.0,
                  child: DrawerHeader(
                    decoration: BoxDecoration(color: Colors.white),
                    child: Row(
                      children: [
                        Image.asset("imagez/user_icon.png", height: 65.0, width: 65.0,),
                        SizedBox(width: 16.0,),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Profile Name", style: TextStyle(fontSize: 16.0, fontFamily: "Brand Bold"),),
                            SizedBox(height: 6.0,),

                            Text("Visit Profile")

                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                DividerWidget(),
                SizedBox(height: 12.0,),
                ListTile(
                  leading: Icon(Icons.history),
                  title: Text("History", style: TextStyle(fontSize: 15.0),),
                ),
                ListTile(
                  leading: Icon(Icons.person),
                  title: Text("Visit Profile", style: TextStyle(fontSize: 15.0),),
                ),
                ListTile(
                  leading: Icon(Icons.info),
                  title: Text("About", style: TextStyle(fontSize: 15.0),),
                ),

              ],
            ),
          ),
        ),

        body :Stack(
          children: [
            GoogleMap(
              padding: EdgeInsets.only(bottom: bottomPaddingOfMap, top: 25.0),
              mapType: MapType.normal,
              myLocationButtonEnabled: true,
              initialCameraPosition: _kGooglePlex,
              myLocationEnabled: true,
              zoomGesturesEnabled: true,
              zoomControlsEnabled: true,
              polylines:polylineSet ,
              markers: markersSet,
              circles: circlesSet,

              onMapCreated: (GoogleMapController controller)
              {
                _controllerGoogleMap.complete(controller);
                newGoogleMapController = controller;

                setState(() {
                  bottomPaddingOfMap = 300.0;
                });
                locatePosition();
              },
            ),

            Positioned(
              top : 45.0,
              left: 22.0,

              child: GestureDetector(
                onTap: (){
                  scaffoldKey.currentState?.openDrawer();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black,
                        blurRadius: 6.0,
                        spreadRadius: 0.5,
                        offset: Offset(
                          0.7,
                          0.7,
                        ),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon( Icons.menu , color: Colors.black,),
                    radius: 20.0,
                  ),
                ),
              ),
            ),

            Positioned(
                left: 0.0,
                right: 0.0,
                bottom: 0.0,
                child: GestureDetector(
                    onTap: toggleContainerHeight,
                    child: AnimatedSize(
                      // AnimatedSize widget parameters
                      duration: Duration(milliseconds: 160), // <-- End of duration parameter
                      curve: Curves.bounceIn, // <-- End of curve parameter

                      child: Container(
                        // Container widget parameters
                        height: searchContainerHeight, // <-- End of height parameter
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(18.0),
                            topRight: Radius.circular(18.0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black,
                              blurRadius: 16.0,
                              spreadRadius: 0.5,
                              offset: Offset(0.7, 0.7),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 18.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 6.0),
                              Text("Hi there,", style: TextStyle(fontSize: 12.0),),
                              Text("Where to?", style: TextStyle(fontSize: 20.0, fontFamily: "Brand Bold"),),
                              SizedBox(height: 20.0),
                              GestureDetector(
                                onTap: () async
                                {
                                  var res= await Navigator.push(context, MaterialPageRoute(builder: (context)=> SearchScreen()));
                                  if(res == "obtainDirection")
                                  {
                                    displayRideDetailsContainer();
                                  }

                                },

                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(5.0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black54,
                                        blurRadius: 6.0,
                                        spreadRadius: 0.5,
                                        offset: Offset(0.7, 0.7),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      children: [
                                        Icon(Icons.search, color: Colors.blueAccent,),
                                        SizedBox(width: 10.0,),
                                        Text("Search Drop Off"),
                                      ],
                                    ),
                                  ),
                                ),
                              ),



                              SizedBox(height : 24.0),
                              Row(
                                children: [
                                  Icon(Icons.home, color: Colors.grey,),
                                  SizedBox(width: 12.0,),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        Provider.of<AppData>(context).pickUpLocation?.placeName ?? "Add Home",
                                      )
                                      ,
                                      Text("Your living home address", style: TextStyle(color: Colors.black54, fontSize: 12.0),),
                                    ],
                                  ),
                                ],
                              ),

                              SizedBox(height: 10.0),

                              DividerWidget(),

                              SizedBox(height: 16.0),

                              Row(
                                children: [
                                  Icon(Icons.work, color: Colors.grey,),
                                  SizedBox(width: 12.0,),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Add Work"),
                                      SizedBox(height: 4.0,),
                                      Text("Your office address", style: TextStyle(color: Colors.black54, fontSize: 12.0),),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),

                        ),
                      ),
                    )
                )
            ),
            Positioned(
                bottom: 0.0,
                left: 0.0,
                right: 0.0,

                child: AnimatedSize(
                  //vsync: this,
                  curve: Curves.bounceIn,
                  duration: new Duration(milliseconds: 160),
                  child: Container(
                      height: rideDetailsContainerHeight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(16.0), topRight: Radius.circular(16.0),),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black,
                            blurRadius: 16.0,
                            spreadRadius: 0.5,
                            offset: Offset(0.7, 0.7),
                          ),
                        ],
                      )
                  ),
                )
            ),
            Positioned(
              bottom: 0.0,
              left: 0.0,
              right: 0.0,
              child: AnimatedSize(
                curve: Curves.bounceIn,
                duration: new Duration(milliseconds: 160),
                child: Container(
                  height: rideDetailsContainerHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(16.0), topRight: Radius.circular(16.0),),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black,
                        blurRadius: 16.0,
                        spreadRadius: 0.5,
                        offset: Offset(0.7, 0.7),
                      ),
                    ],
                  ),

                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 17.0),
                    child: Column(
                      children: [

                        GestureDetector(
                          onTap: ()
                          {
                            displayToastMessage("searching shuttle on this route...", context);

                            setState(() {
                              state = "requesting";
                              var carRideType = "shuttle from mh to main gate";
                            });
                            displayRequestRideContainer();
                            availableDrivers = GeoFireAssistant.nearByAvailableDriversList;
                            searchNearestDriver();
                          },
                          child: Container(
                            width: double.infinity,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: Row(
                                children: [
                                  Image.asset("imagez/shuttle_icon.png", height: 70.0, width: 80.0,),
                                  SizedBox(width: 16.0,),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Shuttle from MH to Main Gate", style: TextStyle(fontSize: 18.0, fontFamily: "Brand Bold",),
                                      ),
                                      Text(
                                        ((tripDirectionDetails != null) ? tripDirectionDetails.distanceText : '') , style: TextStyle(fontSize: 16.0, color: Colors.grey,),
                                      ),
                                    ],
                                  ),
                                  Expanded(child: Container()),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 10.0,),
                        Divider(height: 2.0, thickness: 2.0,),
                        SizedBox(height: 10.0,),


                        GestureDetector(
                          onTap: ()
                          {
                            displayToastMessage("searching shuttle on this route...", context);

                            setState(() {
                              state = "requesting";
                              var carRideType = "Shuttle from MainGate to MH";
                            });
                            displayRequestRideContainer();
                            availableDrivers = GeoFireAssistant.nearByAvailableDriversList;
                            searchNearestDriver();
                          },
                          child: Container(
                            width: double.infinity,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: Row(
                                children: [
                                  Image.asset("imagez/shuttle_icon.png", height: 70.0, width: 80.0,),
                                  SizedBox(width: 16.0,),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Shuttle from MainGate to MH", style: TextStyle(fontSize: 18.0, fontFamily: "Brand Bold",),
                                      ),
                                      Text(
                                        ((tripDirectionDetails != null) ? tripDirectionDetails.distanceText : '') , style: TextStyle(fontSize: 16.0, color: Colors.grey,),
                                      ),
                                    ],
                                  ),
                                  Expanded(child: Container()),
                                  Text(
                                    ((tripDirectionDetails != null) ? tripDirectionDetails.distanceText : ''),
                                    style: TextStyle(fontFamily: "Brand Bold"),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 10.0,),
                        Divider(height: 2.0, thickness: 2.0,),
                        SizedBox(height: 10.0,),

                        //uber-x ride
                        GestureDetector(
                          onTap: ()
                          {
                            displayToastMessage("searching shuttle on this route...", context);

                            setState(() {
                              state = "requesting";
                              var carRideType = "Shuttle from MH to PRP";
                            });
                            displayRequestRideContainer();
                            availableDrivers = GeoFireAssistant.nearByAvailableDriversList;
                            searchNearestDriver();
                          },
                          child: Container(
                            width: double.infinity,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: Row(
                                children: [
                                  Image.asset("imagez/shuttle_icon.png", height: 70.0, width: 80.0,),
                                  SizedBox(width: 16.0,),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Shuttle from MH to PRP", style: TextStyle(fontSize: 18.0, fontFamily: "Brand Bold",),
                                      ),
                                      Text(
                                        ((tripDirectionDetails != null) ? tripDirectionDetails.distanceText : '') , style: TextStyle(fontSize: 16.0, color: Colors.grey,),
                                      ),
                                    ],
                                  ),
                                  Expanded(child: Container()),
                                  Text(
                                    ((tripDirectionDetails != null) ? tripDirectionDetails.distanceText : ''),
                                    style: TextStyle(fontFamily: "Brand Bold"),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 10.0,),
                        Divider(height: 2.0, thickness: 2.0,),
                        SizedBox(height: 10.0,),

                        GestureDetector(
                          onTap: ()
                          {
                            displayToastMessage("searching shuttle on this route...", context);

                            setState(() {
                              state = "requesting";
                              var carRideType = "Shuttle from GH to Main Gate";
                            });
                            displayRequestRideContainer();
                            availableDrivers = GeoFireAssistant.nearByAvailableDriversList;
                            searchNearestDriver();
                          },
                          child: Container(
                            width: double.infinity,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: Row(
                                children: [
                                  Image.asset("imagez/shuttle_icon.png", height: 70.0, width: 80.0,),
                                  SizedBox(width: 16.0,),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Shuttle from GH to Main Gate", style: TextStyle(fontSize: 18.0, fontFamily: "Brand Bold",),
                                      ),
                                      Text(
                                        ((tripDirectionDetails != null) ? tripDirectionDetails.distanceText : '') , style: TextStyle(fontSize: 16.0, color: Colors.grey,),
                                      ),
                                    ],
                                  ),
                                  Expanded(child: Container()),
                                  Text(
                                    ((tripDirectionDetails != null) ? tripDirectionDetails.distanceText : ''),
                                    style: TextStyle(fontFamily: "Brand Bold"),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 10.0,),
                        Divider(height: 2.0, thickness: 2.0,),
                        SizedBox(height: 10.0,),

                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.0),
                          child: Row(
                            children: [
                              Icon(FontAwesomeIcons.moneyCheckAlt, size: 18.0, color: Colors.black54,),
                              SizedBox(width: 16.0,),
                              Text("Cash"),
                              SizedBox(width: 6.0,),
                              Icon(Icons.keyboard_arrow_down, color: Colors.black54, size: 16.0,),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),



          ],
        )
    );
  }
  Future<void> getPlaceDirection() async {
    var initialPos = Provider.of<AppData>(context, listen: false).pickUpLocation;
    var finalPos = Provider.of<AppData>(context, listen: false).dropOffLocation;

    var pickUpLatLng = LatLng(
      initialPos.latitude ?? 0.0, // Provide default value if initialPos.latitude is null
      initialPos.longitude ?? 0.0, // Provide default value if initialPos.longitude is null
    );

    var dropOffLatLng = LatLng(
      finalPos.latitude ?? 0.0, // Provide default value if finalPos.latitude is null
      finalPos.longitude ?? 0.0, // Provide default value if finalPos.longitude is null
    );

    showDialog(
      context: context,
      builder: (BuildContext context) => ProgressDialog(
        message: "Please wait...",
      ),
    );

    var details = await AssistantMethods.obtainPlaceDirectionDetails(
        pickUpLatLng, dropOffLatLng);
    setState(() {
      tripDirectionDetails = details!;
    });
    Navigator.pop(context);

    print("This is Encoded Points ::");
    print(details?.encodedPoints);

    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> decodedPolyLinePointsResult = polylinePoints.decodePolyline(details!.encodedPoints);

    pLineCoordinates.clear();

    if(decodedPolyLinePointsResult.isNotEmpty)
    {
      decodedPolyLinePointsResult.forEach((PointLatLng pointLatLng) {
        pLineCoordinates.add(LatLng(pointLatLng.latitude, pointLatLng.longitude));
      });
    }

    polylineSet.clear();
    setState(() {
      Polyline polyline = Polyline(
        color: Colors.pink,
        polylineId: PolylineId("PolylineID"),
        jointType: JointType.round,
        points: pLineCoordinates,
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        geodesic: true,
      );

      polylineSet.add(polyline);
    });

    LatLngBounds latLngBounds;
    if(pickUpLatLng.latitude > dropOffLatLng.latitude  &&  pickUpLatLng.longitude > dropOffLatLng.longitude)
    {
      latLngBounds = LatLngBounds(southwest: dropOffLatLng, northeast: pickUpLatLng);
    }
    else if(pickUpLatLng.longitude > dropOffLatLng.longitude)
    {
      latLngBounds = LatLngBounds(southwest: LatLng(pickUpLatLng.latitude, dropOffLatLng.longitude), northeast: LatLng(dropOffLatLng.latitude, pickUpLatLng.longitude));
    }
    else if(pickUpLatLng.latitude > dropOffLatLng.latitude)
    {
      latLngBounds = LatLngBounds(southwest: LatLng(dropOffLatLng.latitude, pickUpLatLng.longitude), northeast: LatLng(pickUpLatLng.latitude, dropOffLatLng.longitude));
    }
    else
    {
      latLngBounds = LatLngBounds(southwest: pickUpLatLng, northeast: dropOffLatLng);
    }

    newGoogleMapController.animateCamera(CameraUpdate.newLatLngBounds(latLngBounds, 70));


    Marker pickUpLocMarker = Marker(
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      infoWindow: InfoWindow(title: initialPos.placeName, snippet: "my Location"),
      position: pickUpLatLng,
      markerId: MarkerId("pickUpId"),
    );

    Marker dropOffLocMarker = Marker(
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(title: finalPos.placeName, snippet: "DropOff Location"),
      position: dropOffLatLng,
      markerId: MarkerId("dropOffId"),
    );

    setState(() {
      markersSet.add(pickUpLocMarker);
      markersSet.add(dropOffLocMarker);
    });

    Circle pickUpLocCircle = Circle(
      fillColor: Colors.blueAccent,
      center: pickUpLatLng,
      radius: 12,
      strokeWidth: 4,
      strokeColor: Colors.blueAccent,
      circleId: CircleId("pickUpId"),
    );

    Circle dropOffLocCircle = Circle(
      fillColor: Colors.deepPurple,
      center: dropOffLatLng,
      radius: 12,
      strokeWidth: 4,
      strokeColor: Colors.deepPurple,
      circleId: CircleId("dropOffId"),
    );

    setState(() {
      circlesSet.add(pickUpLocCircle);
      circlesSet.add(dropOffLocCircle);
    });

  }
  void initGeoFireListner()
  {
    Geofire.initialize("availableDrivers");
    Geofire.queryAtLocation(currentPosition!.latitude, currentPosition!.longitude, 15)?.listen((map) {
      print(map);
      if (map != null) {
        var callBack = map['callBack'];



        switch (callBack) {
          case Geofire.onKeyEntered:
            NearbyAvailableDrivers nearbyAvailableDrivers = NearbyAvailableDrivers();
            nearbyAvailableDrivers.key = map['key'];
            nearbyAvailableDrivers.latitude = map['latitude'];
            nearbyAvailableDrivers.longitude = map['longitude'];
            GeoFireAssistant.nearByAvailableDriversList.add(nearbyAvailableDrivers);
            if(nearbyAvailableDriverKeysLoaded == true)
            {
              updateAvailableDriversOnMap();
            }
            break;
          case Geofire.onKeyExited:
            GeoFireAssistant.removeDriverFromList(map['key']);
            updateAvailableDriversOnMap();
            break;

          case Geofire.onKeyMoved:
            NearbyAvailableDrivers nearbyAvailableDrivers = NearbyAvailableDrivers();
            nearbyAvailableDrivers.key = map['key'];
            nearbyAvailableDrivers.latitude = map['latitude'];
            nearbyAvailableDrivers.longitude = map['longitude'];
            GeoFireAssistant.updateDriverNearbyLocation(nearbyAvailableDrivers);
            updateAvailableDriversOnMap();
            break;

          case Geofire.onGeoQueryReady:
            updateAvailableDriversOnMap();
            break;

        }
      }

      setState(() {});
    });
  }




  void updateAvailableDriversOnMap()
  {
    setState(() {
      markersSet.clear();
    });

    Set<Marker> tMakers = Set<Marker>();
    for(NearbyAvailableDrivers driver in GeoFireAssistant.nearByAvailableDriversList)
    {
      LatLng driverAvaiablePosition = LatLng(driver.latitude, driver.longitude);

      Marker marker = Marker(
        markerId: MarkerId('driver${driver.key}'),
        position: driverAvaiablePosition
        ,
        icon: _nearByIcon,
        rotation: AssistantMethods.createRandomNumber(360),
      );

      tMakers.add(marker);
    }
    setState(() {
      markersSet = tMakers;
    });
  }
  void createIconMarker()
  {
    if(_nearByIcon == null)
    {
      ImageConfiguration imageConfiguration = createLocalImageConfiguration(context, size: Size(2, 2));
      BitmapDescriptor.fromAssetImage(imageConfiguration, "imagez/shuttle_icon.png")
          .then((value)
      {
        _nearByIcon = value;
      });
    }
  }


  void noDriverFound()
  {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => NoDriverAvailableDialog()
    );
  }


  void searchNearestDriver()
  {
    if(availableDrivers.length == 0)
    {
      cancelRideRequest();
      resetApp();
      noDriverFound();
      return;
    }

    var driver = availableDrivers[0];

    driversRef.child(driver.key).child("car_details").child("type").once().then((DataSnapshot snap) async
    {
      if(await snap.value != null)
      {
        String carType = snap.value.toString();
      }
      else
      {
        displayToastMessage("No car found. Try again.", context);
      }
    });
  }




  void notifyDriver(NearbyAvailableDrivers driver)
  {
    driversRef.child(driver.key).child("newRide").set(rideRequestRef.key);

    driversRef.child(driver.key).child("token").once().then((DataSnapshot snap){
      if(snap.value != null)
      {
        String token = snap.value.toString();
        AssistantMethods.sendNotificationToDriver(token, context, rideRequestRef.key);
      }
      else
      {
        return;
      }

      const oneSecondPassed = Duration(seconds: 1);
      var timer = Timer.periodic(oneSecondPassed, (timer) {
        if(state != "requesting")
        {
          driversRef.child(driver.key).child("newRide").set("cancelled");
          driversRef.child(driver.key).child("newRide").onDisconnect();
           driverRequestTimeOut = 40;
          timer.cancel();
        }

        driverRequestTimeOut = driverRequestTimeOut - 1;

        driversRef.child(driver.key).child("newRide").onValue.listen((event) {
          if(event.snapshot.value.toString() == "accepted")
          {
            driversRef.child(driver.key).child("newRide").onDisconnect();
            driverRequestTimeOut = 40;
            timer.cancel();
          }
        });

        if(driverRequestTimeOut == 0)
        {
          driversRef.child(driver.key).child("newRide").set("timeout");
          driversRef.child(driver.key).child("newRide").onDisconnect();
          driverRequestTimeOut = 40;
          timer.cancel();

          searchNearestDriver();
        }
      });
    });
  }


}
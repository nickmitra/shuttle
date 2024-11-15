import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_app/AllWidgets/Divider.dart';
import 'package:rider_app/AllWidgets/progressDialog.dart';
import 'package:rider_app/Assistants/requestAssistant.dart';
import 'package:rider_app/DataHandler/appData.dart';
import 'package:rider_app/Models/address.dart';
import 'package:rider_app/Models/placePredictions.dart';
import 'package:rider_app/configMaps.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  TextEditingController pickUpTextEditingController = TextEditingController();
  TextEditingController dropOffTextEditingController = TextEditingController();
  List<PlacePredictions> placePredictionList = [];

  @override
  Widget build(BuildContext context) {
    String placeAddress = Provider.of<AppData>(context).pickUpLocation?.placeName ?? "";
    pickUpTextEditingController.text = placeAddress;

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          SizedBox(height: 10.0),
          _buildPlacePredictions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 215.0,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black,
            blurRadius: 6.0,
            spreadRadius: 0.5,
            offset: Offset(0.7, 0.7),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(25.0),
        child: Column(
          children: [
            SizedBox(height: 25.0),
            _buildHeaderContent(),
            SizedBox(height: 16.0),
            _buildLocationInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderContent() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: Icon(Icons.arrow_back),
        ),
        Center(
          child: Text(
            "Set Drop Off",
            style: TextStyle(fontSize: 18.0, fontFamily: "Brand Bold"),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInput() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildTextField(
            controller: pickUpTextEditingController,
            hint: "PickUp Location",
            icon: "imagez/pickicon.png",
          ),
          SizedBox(height: 10.0),
          _buildTextField(
            controller: dropOffTextEditingController,
            hint: "Where to?",
            icon: "imagez/desticon.png",
            onChanged: findPlace,
          ),
        ],
      ),
    );
  }


  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required String icon,
    Function(String)? onChanged,
  }) {
    return Row(
      children: [
        Image.asset(icon, height: 16.0, width: 16.0),
        SizedBox(width: 18.0),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(5.0),
            ),
            child: Padding(
              padding: EdgeInsets.all(3.0),
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hint,
                  fillColor: Colors.grey[200],
                  filled: true,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 11.0, vertical: 8.0),
                ),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlacePredictions() {
    return placePredictionList.isNotEmpty
        ? Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: ListView.separated(
          padding: EdgeInsets.all(0.0),
          itemBuilder: (context, index) {
            return PredictionTile(placePredictions: placePredictionList[index]);
          },
          separatorBuilder: (context, index) => DividerWidget(),
          itemCount: placePredictionList.length,
          shrinkWrap: true,
          physics: ClampingScrollPhysics(),
        ),
      ),
    )
        : Container();
  }

  void findPlace(String placeName) async {
    if (placeName.length > 1) {
      String autoCompleteUrl = "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$placeName&key=$mapkey&sessiontoken=1234567890&components=country:pk";

      var res = await RequestAssistant.getRequest(autoCompleteUrl);

      if (res == "failed") {
        return;
      }

      if (res["status"] == "OK") {
        var predictions = res["predictions"];
        var placesList = (predictions as List).map((e) => PlacePredictions.fromJson(e)).toList();

        setState(() {
          placePredictionList = placesList;
        });
      }
    }
  }
}

class PredictionTile extends StatelessWidget {
  final PlacePredictions placePredictions;

  PredictionTile({required this.placePredictions});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        getPlaceAddressDetails(placePredictions.place_id, context);
      },
      child: Container(
        child: Column(
          children: [
            SizedBox(width: 10.0),
            Row(
              children: [
                Icon(Icons.add_location),
                SizedBox(width: 14.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8.0),
                      Text(
                        placePredictions.main_text ?? "N/A",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16.0),
                      ),
                      SizedBox(height: 2.0),
                      Text(
                        placePredictions.secondary_text ?? "N/A",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.0, color: Colors.grey),
                      ),
                      SizedBox(height: 8.0),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(width: 10.0),
          ],
        ),
      ),
    );
  }

  void getPlaceAddressDetails(String? placeId, BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) => ProgressDialog(message: "Setting Dropoff, Please wait..."),
    );

    String placeDetailsUrl = "https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$mapkey";

    var res = await RequestAssistant.getRequest(placeDetailsUrl);

    Navigator.pop(context);

    if (res == "failed") {
      return;
    }

    if (res["status"] == "OK") {
      Address address = Address();
      address.placeName = res["result"]["name"];
      address.placeId = placeId;
      address.latitude = res["result"]["geometry"]["location"]["lat"];
      address.longitude = res["result"]["geometry"]["location"]["lng"];

      Provider.of<AppData>(context, listen: false).updateDropOffLocationAddress(address);
      print("This is Drop Off Location :: ");
      print(address.placeName);

      Navigator.pop(context, "obtainDirection");
    }
  }
}

class PlacePredictions {
  String? secondary_text;
  String? main_text;
  String? place_id;

  PlacePredictions({this.secondary_text, this.main_text, this.place_id});

  PlacePredictions.fromJson(Map<String, dynamic> json) {
    place_id = json["place_id"];
    main_text = json["structured_formatting"]?["main_text"];
    secondary_text = json["structured_formatting"]?["secondary_text"];
  }
}

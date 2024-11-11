import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:rider_app/AllScreens/mainscreen.dart';
import 'package:rider_app/AllScreens/registrationScreen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rider_app/AllWidgets/progressDialog.dart';
import 'package:rider_app/main.dart';

class LoginScreen extends StatelessWidget {
  static const String idScreen = "login";
  TextEditingController emailTextEditingController = TextEditingController();
  TextEditingController passwordTextEditingController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.limeAccent,
      body: Column(
        children: [
          SizedBox(height: 25.0),
          Image(
            image: AssetImage("imagez/shuttle.png"),
            width: 390.0,
            height: 250.0,
            alignment: Alignment.center,
          ),
          SizedBox(height: 1.0),
          Text(
            "Login as Shuttle Rider",
            style: TextStyle(fontSize: 24.0, fontFamily: "Brand Bold"),
            textAlign: TextAlign.center,
          ),
          Padding(
            padding: EdgeInsets.all(20.8),
            child: Column(
              children: [
                SizedBox(height: 1.0),
                TextField(
                  controller: emailTextEditingController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Email",
                    labelStyle: TextStyle(
                      fontSize: 14.0,
                    ),
                    hintStyle: TextStyle(
                      color: Colors.grey,
                      fontSize: 10.0,
                    ),
                  ),
                  style: TextStyle(fontSize: 14.0),
                ),
                SizedBox(height: 1.0),
                TextField(
                  controller: passwordTextEditingController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Password",
                    labelStyle: TextStyle(
                      fontSize: 14.0,
                    ),
                    hintStyle: TextStyle(
                      color: Colors.grey,
                      fontSize: 10.0,
                    ),
                  ),
                  style: TextStyle(fontSize: 14.0),
                ),
                SizedBox(height: 20.0),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.yellow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.0),
                    ),
                  ),
                  onPressed: () {
                    if (!emailTextEditingController.text.contains("@")) {
                      displayToastMessage("Email address is not valid", context);
                    } else if (passwordTextEditingController.text.length < 6) {
                      displayToastMessage("Password is mandatory", context);
                    } else {
                      loginandAuthenticateUser(context);
                    }
                  },
                  child: Container(
                    height: 50.0,
                    child: Center(
                      child: Text(
                        "Login",
                        style: TextStyle(fontSize: 18.8, fontFamily: "Brand bold"),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(context, RegistrationScreen.idScreen, (route) => false);
                  },
                  child: Text(
                    "Do not have a shuttle user account? Register Here",
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final DatabaseReference usersRef = FirebaseDatabase.instance.reference().child("users");


  void loginandAuthenticateUser(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ProgressDialog(message: "Authenticating, Please wait..");
      },
    );

      final UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: emailTextEditingController.text,
        password: passwordTextEditingController.text,
      );

      User? newUser = userCredential.user;

      if (newUser != null) {
        String uid = newUser.uid;
        try {
          DatabaseEvent event = await usersRef.child(uid).once();

          if (event.snapshot.value != null) {
            Navigator.pushNamedAndRemoveUntil(
                context, MainScreen.idScreen, (route) => false);
            displayToastMessage("You are logged in now ", context);
          } else {
            Navigator.pop(context);
            await _firebaseAuth.signOut();
            displayToastMessage(
                "No record exists for this user. Please create a new account",
                context);
          }
        } catch (error) {
          Navigator.pop(context);
          await _firebaseAuth.signOut();
          print("Error: ${error.toString()}");
          displayToastMessage("Error: ${error.toString()}", context);
        }
      }

  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:rider_app/AllScreens/loginScreen.dart';
import 'package:rider_app/AllScreens/mainscreen.dart';
import 'package:rider_app/main.dart';

import '../AllWidgets/progressDialog.dart';


class RegistrationScreen extends StatelessWidget {
  static const String idScreen = "register";

  TextEditingController nameTextEditingController = TextEditingController();
  TextEditingController emailTextEditingController = TextEditingController();
  TextEditingController phoneTextEditingController = TextEditingController();
  TextEditingController passwordTextEditingController = TextEditingController();


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.limeAccent,
        body: Column(
          children: [
            SizedBox(height: 20.0,),
            Image(
              image: AssetImage("imagez/shuttle.png"),
              width: 390.0,
              height: 250.0,
              alignment: Alignment.center,
            ),
            SizedBox(height: 1.0,),
            Text(
              "Register as Shuttle Rider",
              style: TextStyle(fontSize: 24.0, fontFamily: "Brand Bold"),
              textAlign: TextAlign.center,
            ),
            Padding(
                padding: EdgeInsets.all(20.8),
                child: Column(
                  children: [

                    SizedBox(height: 1.0,),

                    TextField(
                      controller: nameTextEditingController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: "Name",
                        labelStyle: TextStyle(
                          fontSize: 14.0,
                        ), // TextStyle
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: 10.0,
                        ), // TextStyle
                      ), // InputDecoration
                      style: TextStyle(fontSize: 14.0),
                    ),

                    SizedBox(height: 1.0,),

                    TextField(
                      controller: emailTextEditingController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Email",
                        labelStyle: TextStyle(
                          fontSize: 14.0,
                        ), // TextStyle
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: 10.0,
                        ), // TextStyle
                      ), // InputDecoration
                      style: TextStyle(fontSize: 14.0),
                    ),

                    SizedBox(height: 1.0,),

                    TextField(
                      controller: phoneTextEditingController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: "Phone",
                        labelStyle: TextStyle(
                          fontSize: 14.0,
                        ), // TextStyle
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: 10.0,
                        ), // TextStyle
                      ), // InputDecoration
                      style: TextStyle(fontSize: 14.0),
                    ),


                    SizedBox(height: 1.0,),
                    TextField(
                      controller: passwordTextEditingController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Password",
                        labelStyle: TextStyle(
                          fontSize: 14.0,
                        ), // TextStyle
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: 10.0,
                        ), // TextStyle
                      ), // InputDecoration
                      style: TextStyle(fontSize: 14.0),
                    ),
                    SizedBox(height: 20.0,),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white, backgroundColor: Colors.yellow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24.0),
                        ),
                      ),
                      onPressed: () {
                        if (nameTextEditingController.text.length < 3) {

                          displayToastMessage("Name must be atleast 3 characters.",context);
                        }
                        else if(!emailTextEditingController.text.contains("@")){
                          displayToastMessage("Email address is not valid", context);
                        }
                        else if(phoneTextEditingController.text.isEmpty){
                          displayToastMessage("Phone Number is mandatory", context);
                        }
                        else if(passwordTextEditingController.text.length<6){
                          displayToastMessage("Password must be at least 6 characters", context);
                        }
                        else {
                          registerNewUser(context);
                        }
                      },
                      child: Container(
                        height: 50.0,
                        child: Center(
                          child: Text(
                            "Create Account",
                            style: TextStyle(
                                fontSize: 18.8, fontFamily: "Brand bold"),
                          ),
                        ),
                      ),
                    ),
                    // SizedBox for spacing, assuming you want some space between the buttons
                    SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                            context, LoginScreen.idScreen, (route) => false);
                      },
                      child: Text(
                        "Already have a shuttle user account? Login Here",
                      ),
                    ),

                  ],
                )
            )
          ],
        )
    );
  }

  final FirebaseAuth _firebaseAuth=FirebaseAuth.instance;
  void registerNewUser(BuildContext context)async
  {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context){
          return ProgressDialog(message: "Registrating, Please wait..",);

        }
    );
    final UserCredential userCredential = (await FirebaseAuth.instance.
  createUserWithEmailAndPassword(email: emailTextEditingController.text,
      password: passwordTextEditingController.text).catchError((errMsg){displayToastMessage("Error:" + errMsg.toString(), context);}

  ));
  User? newUser = userCredential.user;

  if (newUser != null) { //user created
  String uid =newUser.uid;
  Map userDataMap ={
  "name": nameTextEditingController.text.trim(),
  "email":emailTextEditingController.text.trim(),
  "phone":phoneTextEditingController.text.trim(),
  };
  usersRef.child(uid).set(userDataMap);
  displayToastMessage("Your account has been created.", context);

  Navigator.pushNamedAndRemoveUntil(context,MainScreen.idScreen, (route) => false);


  }
  else {
  displayToastMessage("New user account has not been created", context);
  }
}
}
displayToastMessage(String message, BuildContext context){
  Fluttertoast.showToast(msg: message);

}

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';


class Users {
  String? id;
  String? email;
  String? name;
  String? phone;

  Users({this.id, this.email, this.name, this.phone});

  Users.fromSnapshot(DataSnapshot dataSnapshot) {
    id = dataSnapshot.key!;

    // Explicitly cast dataSnapshot.value to Map<String, dynamic>
    Map<String, dynamic>? data = dataSnapshot.value as Map<String, dynamic>?;

    // Check if data is not null before accessing its properties
    if (data != null) {
      email = data["email"];
      name = data["name"];
      phone = data["phone"];
    }
  }
}


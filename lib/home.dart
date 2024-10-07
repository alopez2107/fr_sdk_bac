import 'package:flutter/material.dart';
import "package:fr_sdk_bac/login.dart";
import "package:fr_sdk_bac/register.dart";

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  final _pageOptions = [
    const MyHomePage(),
    const LoginPage(),
    const RegisterPage()
  ];

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return const Center(
      // Center is a layout widget. It takes a single child and positions it
      // in the middle of the parent.
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            'Welcome to BAC Credomatic Secure Mobile App Demo.',
            style: TextStyle(
                color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          Text(
            ' Please login or register a new account.',
            style: TextStyle(color: Colors.black, fontSize: 14),
          )
        ],
      ),
    );
  }
}

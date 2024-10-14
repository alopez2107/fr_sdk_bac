import 'dart:convert';
import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fr_sdk_bac/register.dart';
import 'FRNode.dart';
import 'home.dart';
import 'login.dart';

class TransferPage extends StatefulWidget {
  const TransferPage({super.key});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final int _selectedIndex = 0;
  final _pageOptions = [
    const MyHomePage(),
    const LoginPage(),
    RegisterPage()
  ];

  late List<TextField> _fields = [];
  late List<TextEditingController> _controllers = [];
  late FRNode currentNode;
  late String srcAccount = "";
  late String destAccount = "";
  late double amount = 0.0;

  static const platform = MethodChannel('forgerock.com/SampleBridge'); //Method channel as defined in the native Bridge code


  Future<void> _startTransaction(String authnType) async {
    try {
      srcAccount = _controllers[0].text;
      destAccount = _controllers[1].text;
      amount = double.parse(_controllers[2].text);
      //Call the default login tree.
      final String result = await platform.invokeMethod('callEndpoint', ["https://alexsm.encore.forgerock.com/ig/transfer?authType=${authnType}",'POST', '{"srcAcct": $srcAccount, "destAcct": $destAccount, "amount": $amount}', "true"]);
      debugPrint("Final response $result");
      /*Map<String, dynamic> frNodeMap = jsonDecode(result);
      var frNode = FRNode.fromJson(frNodeMap);
      currentNode = frNode;
      _handleNode(frNode);*/
    } on PlatformException catch (e) {
      debugPrint('SDK: $e');
      Navigator.pop(context);
    }
  }

  // Method used to capture the user inputs from the UI, populate the Node and submit to AM
  Future<void> _next() async {
    //G through the node callback inputs and use the input name to match it with the UI element. Populate the value to the callback and then submit the node.
    var callbackIndex = 0;
    while (callbackIndex < currentNode.callbacks.length) {
      var frCallback = currentNode.callbacks[callbackIndex];
      if (frCallback.type == "WebAuthnRegistrationCallback" || frCallback.type == "HiddenValueCallback") {
        // Do nothing - no input required.
      }
      else {
        // Report error
      }
      callbackIndex++;
    }
    String jsonResponse = jsonEncode(currentNode);

    try {
      //Submitting the node. This will return either a new node or a success/failure message
      String result = await platform.invokeMethod('next', jsonResponse);
      Map<String, dynamic> response = jsonDecode(result);
      if (response["type"] == "LoginSuccess") {
        //_navigateToNextScreen(context);
        //process the results
        debugPrint("Transaction successful");
      } else  {
        Map<String, dynamic> frNodeMap = jsonDecode(result);
        /*Map<String, dynamic> callback = frNodeMap["frCallbacks"][0];
        if ( callback["type"] == "WebAuthnRegistrationCallback") {
          _webAuthentication(callback);
        }
        else {*/
        var frNode = FRNode.fromJson(frNodeMap);
        currentNode = frNode;
        _handleNode(frNode);
        //}
      }
    } catch (e) {
      debugPrint('SDK Error: $e');
      Navigator.pop(context);
    }
  }

  // Helper/Handler methods
  void _handleNode(FRNode frNode) {
    bool webAuthn = false;
    for (var frCallback in frNode.callbacks) {
      if (frCallback.type == "WebAuthnRegistrationCallback") {
        // We can implement a Device Name collection screen - later
        webAuthn = true;
        break;
      }
    }
    if (webAuthn) { // Break the cycle and make sure we only call _next() once as soon as WebAuthnCallbacks are detected.
      _next();
    }
  }


  void _onItemTapped(int index) {

  }

  // Widgets
  Widget _listView(BuildContext context) {
    setState(() {
      _fields = [];
      _controllers = [];
    });
    final srcAcctController = TextEditingController();
    final srcAcctField = TextField(
      controller: srcAcctController,
      enableSuggestions: false,
      autocorrect: false,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: "Origin Account",
      ),
    );
    _fields.add(srcAcctField);
    _controllers.add(srcAcctController);
    final destAcctController = TextEditingController();
    final destAcctField = TextField(
      controller: destAcctController,
      enableSuggestions: false,
      autocorrect: false,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: "Destination Account",
      ),
    );
    _fields.add(destAcctField);
    _controllers.add(destAcctController);
    final amtController = TextEditingController();
    final amtField = TextField(
      controller: amtController,
      enableSuggestions: false,
      autocorrect: false,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: "Transfer Amount",
      ),
    );
    _fields.add(amtField);
    _controllers.add(amtController);
    int fieldQty = _fields.length;
    print("How many fields: $fieldQty");
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _fields.length,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.all(15.0),
          child: _fields[index],
        );
      },
    );
  }

  Widget _okWithVerify(BuildContext context) {
    return Container(
      color: Colors.transparent,
      width: MediaQuery.of(context).size.width,
      margin: const EdgeInsets.all(15.0),
      height: 60,
      child: TextButton(
        style: ButtonStyle(backgroundColor: MaterialStateProperty.all(Colors.red)),
        onPressed: () async {
          _startTransaction("verify");
        },
        child: const Text(
          "Not registered? Create an account now.",
          style: TextStyle(color: Colors.blueAccent),
        ),
      ),
    );
  }

  Widget _okWithFido(BuildContext context) {
    return Container(
      color: Colors.transparent,
      width: MediaQuery.of(context).size.width,
      margin: const EdgeInsets.all(15.0),
      height: 60,
      child:  TextButton(
        style: ButtonStyle(backgroundColor: MaterialStateProperty.all(Colors.red)),
        onPressed: () async {
          _startTransaction("fido");
        },
        child:
        const Text(
          "Register with Fido",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  // Build the transfer form to initiate transactional authorization
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Title(color: Colors.red, child: const Text("BAC PoC Demo - Transfers")),
          centerTitle: true,
          shadowColor: Colors.black,
          elevation: 3,
          titleTextStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red
          ),
        ),
        backgroundColor: Colors.white,
        body: SingleChildScrollView (
          child: Column(
            children: [
              _listView(context),
              _okWithFido(context),
              _okWithVerify(context)
            ],
          ),
        ),
      ),
    );
  }
}

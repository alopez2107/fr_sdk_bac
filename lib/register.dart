import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:fr_sdk_bac/transfer.dart';

import 'fr_node.dart';

//Helper Classes
sealed class HelperCompoment {}

class WidgetHelper extends HelperCompoment {
  WidgetHelper(this.widget);

  final Widget widget;
}

class CheckBox extends HelperCompoment {
  CheckBox({required this.name, required this.checked});

  final String name;
  bool checked;
}

class DropDownItems extends HelperCompoment {
  DropDownItems({required this.name, required this.items});
  final String name;
  final List<dynamic> items;
  String selectedOption = '';
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const platform = MethodChannel(
      'forgerock.com/SampleBridge'); //Method channel as defined in the native Bridge code
  final _fields = <HelperCompoment>[];
  final _controllers = <String, TextEditingController>{};
  late FRNode currentNode;

  //Lifecycle Methods
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _startSDK();
    });
  }

  // SDK Calls -  Note the promise type responses. Handle errors on the UI layer as required
  Future<void> _startSDK() async {
    String response;
    try {
      //Start the SDK. Call the frAuthStart channel method to initialise the native SDKs
      final String result = await platform.invokeMethod('frAuthStart');
      response = 'SDK Started';
      _register();
    } on PlatformException catch (e) {
      response = "SDK Start Failed: '${e.message}'.";
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  // SDK Calls -  Note the promise type responses. Handle errors on the UI layer as required
  Future<void> _register() async {
    try {
      // Call the default register tree/journey
      final String result = await platform.invokeMethod('register');
      Map<String, dynamic> frNodeMap = jsonDecode(result);
      var frNode = FRNode.fromJson(frNodeMap);
      currentNode = frNode;
      _handleNode(frNode);
    } on PlatformException catch (e) {
      debugPrint('SDK: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  // Method used to capture the user inputs from the UI, populate the Node and submit to AM
  Future<void> _next() async {
    //G through the node callback inputs and use the input name to match it with the UI element. Populate the value to the callback and then submit the node.
    var callbackIndex = 0;
    while (callbackIndex < currentNode.callbacks.length) {
      var frCallback = currentNode.callbacks[callbackIndex];
      if (frCallback.type == "BooleanAttributeInputCallback") {
        TextEditingController controller =
            _controllers[frCallback.input[0].name]!;
        frCallback.input[0].value = controller.text == 'true';
      } else if (frCallback.type == "KbaCreateCallback") {
        TextEditingController controller =
            _controllers[frCallback.input[0].name]!;
        frCallback.input[0].value = controller.text;
        TextEditingController answerController =
            _controllers[frCallback.input[1].name]!;
        frCallback.input[1].value = answerController.text;
      } else if (frCallback.type == "TermsAndConditionsCallback") {
        TextEditingController controller =
            _controllers[frCallback.input[0].name]!;
        frCallback.input[0].value = controller.text == 'true';
      } else if (frCallback.type == "WebAuthnRegistrationCallback" ||
          frCallback.type == "HiddenValueCallback") {
        // Do nothing - no input required.
      } else {
        TextEditingController controller =
            _controllers[frCallback.input[0].name]!;
        frCallback.input[0].value = controller.text;
      }
      callbackIndex++;
    }
    String jsonResponse = jsonEncode(currentNode);

    try {
      //Submitting the node. This will return either a new node or a success/failure message
      String result = await platform.invokeMethod('next', jsonResponse);
      Map<String, dynamic> response = jsonDecode(result);
      if (response["type"] == "LoginSuccess") {
        if (mounted) _navigateToNextScreen(context);
      } else {
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
      if (mounted) Navigator.pop(context);
    }
  }

  // Helper/Handler methods
  void _handleNode(FRNode frNode) {
    bool webAuthn = false;
    for (final frCallback in frNode.callbacks) {
      final controller = TextEditingController();
      if (frCallback.type == "ValidatedCreateUsernameCallback" ||
          frCallback.type == "StringAttributeInputCallback" ||
          frCallback.type == "ValidatedCreatePasswordCallback") {
        // Note that a ot of callbacks, despite being of different types can be handled in the UI by the same elements like textfields.
        String prompt = "";
        for (var element in frCallback.output) {
          if (element.name == "prompt") {
            prompt = element.value;
          }
        }

        final field = TextField(
          controller: controller,
          obscureText: frCallback.type ==
              "ValidatedCreatePasswordCallback", // If the callback type is 'ValidatedCreatePasswordCallback', make this a 'secure' textField.
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: prompt,
          ),
        );
        setState(() {
          _controllers[frCallback.input[0].name] = controller;
          _fields.add(WidgetHelper(field));
        });
      } else if (frCallback.type == "BooleanAttributeInputCallback") {
        String prompt = "";
        for (var element in frCallback.output) {
          if (element.name == "prompt") {
            prompt = element.value;
          }
        }
        _controllers[frCallback.input[0].name] = controller;
        CheckBox checkBoxObject = CheckBox(name: prompt, checked: false);
        _fields.add(checkBoxObject);
      } else if (frCallback.type == "TermsAndConditionsCallback") {
        // The TermsAndConditionsCallback also contains the actual T&Cs sent by AM.
        // This gives the developer the option to present them to the user, if needed, without hardcoding those in the app.
        controller.text = 'true';
        _controllers[frCallback.input[0].name] = controller;
        final checkBoxObject = CheckBox(
          name: "Accept the Terms & Conditions",
          checked: true,
        );
        _fields.add(checkBoxObject);
      } else if (frCallback.type == "KbaCreateCallback") {
        // The KbaCreateCallback, contains 2 elements that need to be presented and handled.
        // The "Question" and the "Answer". The node, might contain multiple questions and the answers provided, need to match the question selected by the user.
        String prompt = "";
        List<dynamic> predefinedQuestions = [];
        for (final element in frCallback.output) {
          if (element.name == "prompt") {
            prompt = element.value;
          }
          if (element.name == "predefinedQuestions") {
            predefinedQuestions = element.value;
          }
        }

        _fields.add(DropDownItems(name: prompt, items: predefinedQuestions));
        _controllers[frCallback.input[0].name] = controller;
        final kbaController = TextEditingController();
        final field = TextField(
          controller: kbaController,
          enableSuggestions: false,
          autocorrect: false,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: "Answer",
          ),
        );
        _fields.add(WidgetHelper(field));
        _controllers[frCallback.input[1].name] = kbaController;
      } else if (frCallback.type == "WebAuthnRegistrationCallback") {
        // We can implement a Device Name collection screen - later
        webAuthn = true;
        break;
      }
    }
    if (webAuthn) {
      // Break the cycle and make sure we only call _next() once as soon as WebAuthnCallbacks are detected.
      _next();
    }
  }

  void showAlertDialog(BuildContext context) {
    AlertDialog alert = AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          Container(
              margin: const EdgeInsets.only(left: 5),
              child: const Text("Loading")),
        ],
      ),
    );
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  void _navigateToNextScreen(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const TransferPage()),
    );
  }

  // Widgets
  Widget _okButton() {
    return Container(
      color: Colors.transparent,
      width: MediaQuery.of(context).size.width,
      margin: const EdgeInsets.all(15.0),
      height: 60,
      child: TextButton(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(Colors.blue),
        ),
        onPressed: () async {
          _next();
        },
        child: const Text(
          "Register",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _dropDownView(DropDownItems component) {
    List<String> items = [];
    items.add("Select security question");
    for (var i = 0; i < component.items.length; i++) {
      items.add(component.items[i]);
    }
    if (component.selectedOption == "") {
      component.selectedOption = items.first;
    }

    return DropdownButton(
      value: component.selectedOption,
      hint: const Text('Select security question'),
      items: items.map((String item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          component.selectedOption = value!;

          /// MUJAJAJA
          //var frCallback = currentNode.callbacks[index];
          //_controllers[frCallback.input[0].name]!.text = value.toString();
        });
      },
    );
  }

  Widget _listView() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _fields.length,
      itemBuilder: (context, index) {
        final component = _fields[index];
        switch (component) {
          case WidgetHelper(:final widget):
            return Container(
              margin: const EdgeInsets.all(15.0),
              child: widget,
            );
          case CheckBox():
            return CheckboxListTile(
              value: component.checked,
              title: Text(component.name),
              onChanged: (bool? selected) {
                setState(() {
                  component.checked = selected ?? false;
                  var frCallback = currentNode.callbacks[index];
                  _controllers[frCallback.input[0].name]!.text =
                      component.checked.toString();
                });
              },
            );
          case DropDownItems():
            return Padding(
              // Even Padding On All Sides
              padding: const EdgeInsets.all(15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _dropDownView(component),
                ],
              ),
            );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme: const IconThemeData(
            color: Colors.blueAccent, //change your color here
          ),
          title: Text(
            "Register",
            style: TextStyle(color: Colors.grey[800]),
          ),
          backgroundColor: Colors.grey[200],
        ),
        backgroundColor: Colors.grey[100],
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_listView(), _okButton()],
          ),
        ));
  }
}

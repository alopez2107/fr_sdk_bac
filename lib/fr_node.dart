//  Copyright (c) 2022 ForgeRock. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.

/*
The FRNode class is native Dart class replicating the structure of the SDKs Node objects.
This is used in order to natively parse and encode/decode the JSON objects returned from the SDKs.
*/

import 'fn_callback.dart';

class FRNode {
  String? header;
  String? authServiceId;
  String? stage;
  String? authId;
  String? description;
  List<FRCallback> callbacks;

  FRNode({
    required this.header,
    required this.authServiceId,
    required this.stage,
    required this.authId,
    required this.description,
    required this.callbacks,
  });

  factory FRNode.fromJson(Map<String, dynamic> parsedJson) {
    var list = parsedJson['callbacks'] as List;
    var frList = parsedJson['frCallbacks'] as List;
    int index = 0;

    List<FRCallback> frCallbackList = [];
    while (index < list.length) {
      Map<String, dynamic> callback = list[index];
      String callbackTypeName = frList[index]['type'];
      FRCallback callbackObj = FRCallback.fromJson(callback, callbackTypeName);
      frCallbackList.add(callbackObj);
      ++index;
    }

    return FRNode(
        header: parsedJson['header'],
        authServiceId: parsedJson['authServiceId'],
        stage: parsedJson['stage'],
        authId: parsedJson['authId'],
        description: parsedJson['description'],
        callbacks: frCallbackList);
  }

  Map<String, dynamic> toJson() => {
        'header': header,
        'authServiceId': authServiceId,
        'stage': stage,
        'authId': authId,
        'description': description,
        'callbacks': callbacks,
      };
}

import 'package:flutter/material.dart';

SizedBox createBaseInputbox(TextEditingController inputController, bool shouldAutofocus) {
  return SizedBox(
    width: double.infinity,
    height: 60,
    child: TextField(
      controller: inputController,
      autofocus: shouldAutofocus,
      onTapOutside: (event) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
    ),
  );
}
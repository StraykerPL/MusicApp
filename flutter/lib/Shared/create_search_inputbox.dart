import 'package:flutter/material.dart';

SizedBox createBaseInputbox(TextEditingController inputController, bool shouldAutofocus) {
  return SizedBox(
    width: double.infinity,
    child: TextField(
      controller: inputController,
      autofocus: shouldAutofocus,
      onTapOutside: (event) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
    ),
  );
}
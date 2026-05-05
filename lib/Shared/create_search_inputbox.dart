import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:strayker_music/Shared/input_security.dart';

SizedBox createBaseInputbox(
    TextEditingController inputController, bool shouldAutofocus) {
  return SizedBox(
    width: double.infinity,
    height: 60,
    child: TextField(
      controller: inputController,
      autofocus: shouldAutofocus,
      inputFormatters: [
        const SecureTextInputFormatter(),
        LengthLimitingTextInputFormatter(InputSecurity.maxTextLength),
      ],
      onTapOutside: (event) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
    ),
  );
}

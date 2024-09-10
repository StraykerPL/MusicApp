import 'package:flutter/material.dart';

SizedBox createSearchInputbox(TextEditingController inputController) {
  return SizedBox(
    width: double.infinity,
    child: TextField(
      controller: inputController,
      autofocus: true,
      onTapOutside: (event) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
    ),
  );
}
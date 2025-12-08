import 'package:flutter/material.dart';
import 'package:locker/themes/app_colors.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ToastUtils {
  static const Color _toastBg = AppColors.primaryBackground;
  static const Color _lightText = AppColors.primaryText;

  static void showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: _toastBg,
      textColor: _lightText,
      fontSize: 16,
    );
  }

  static void showSuccess(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 2,
      backgroundColor: AppColors.success,
      textColor: Colors.white,
      fontSize: 16,
    );
  }

  static void showError(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 3,
      backgroundColor: AppColors.error,
      textColor: Colors.white,
      fontSize: 16,
    );
  }

  static void showInfo(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 2,
      backgroundColor: AppColors.info,
      textColor: Colors.white,
      fontSize: 16,
    );
  }

  static void showWarning(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 2,
      backgroundColor: AppColors.warning,
      textColor: Colors.white,
      fontSize: 16,
    );
  }
}

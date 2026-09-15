import 'package:flutter/material.dart';

class LichProvider extends ChangeNotifier {
  DateTime _selectedDate = DateTime.now();

  DateTime get selectedDate => _selectedDate;

  void chonNgay(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }
}
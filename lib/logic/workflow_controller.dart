import 'package:flutter/material.dart';

enum StepStatus { locked, waiting, processing, error, done }
enum DocType { unknown, offer, order }

class WorkflowController extends ChangeNotifier {
  // 1. Soukromý konstruktor
  WorkflowController._internal();

  // 2. Statická instance
  static final WorkflowController _instance = WorkflowController._internal();

  // 3. Factory konstruktor, který vždy vrátí tu samou instanci
  factory WorkflowController() => _instance;

  // --- STAV ---
  bool _isIngestionDone = false;
  DocType _docType = DocType.unknown;
  
  bool get isIngestionDone => _isIngestionDone;
  DocType get docType => _docType;

  // --- AKCE ---
  void unlockWorkflow(DocType type) {
    _isIngestionDone = true;
    _docType = type;
    notifyListeners(); // Způsobí překreslení všech ListenableBuilderů
  }

  void setDocType(DocType type) {
  _docType = type;
  notifyListeners(); // Tohle překreslí Sidebar i Editor
}

  void reset() {
    _isIngestionDone = false;
    _docType = DocType.unknown;
    notifyListeners();
  }
}
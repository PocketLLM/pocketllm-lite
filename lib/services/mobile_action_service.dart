import 'dart:async';

class MobileActionRequest {
  final String id;
  final String actionType; // 'reminder', 'note', 'email', 'clipboard'
  final String title;
  final String details;
  final DateTime? scheduledTime;
  bool userConfirmed;

  MobileActionRequest({
    required this.id,
    required this.actionType,
    required this.title,
    required this.details,
    this.scheduledTime,
    this.userConfirmed = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'actionType': actionType,
        'title': title,
        'details': details,
        'scheduledTime': scheduledTime?.toIso8601String(),
        'userConfirmed': userConfirmed,
      };
}

class MobileActionService {
  static final MobileActionService _instance = MobileActionService._internal();
  factory MobileActionService() => _instance;
  MobileActionService._internal();

  final List<MobileActionRequest> _pendingActions = [];
  final List<MobileActionRequest> _executedActions = [];

  List<MobileActionRequest> get pendingActions =>
      List.unmodifiable(_pendingActions);
  List<MobileActionRequest> get executedActions =>
      List.unmodifiable(_executedActions);

  MobileActionRequest createReminderRequest({
    required String title,
    required String details,
    required DateTime scheduledTime,
  }) {
    final req = MobileActionRequest(
      id: 'act_${DateTime.now().millisecondsSinceEpoch}',
      actionType: 'reminder',
      title: title,
      details: details,
      scheduledTime: scheduledTime,
    );
    _pendingActions.add(req);
    return req;
  }

  MobileActionRequest createNoteRequest({
    required String title,
    required String details,
  }) {
    final req = MobileActionRequest(
      id: 'act_${DateTime.now().millisecondsSinceEpoch}',
      actionType: 'note',
      title: title,
      details: details,
    );
    _pendingActions.add(req);
    return req;
  }

  Future<bool> confirmAndExecuteAction(String actionId) async {
    final idx = _pendingActions.indexWhere((a) => a.id == actionId);
    if (idx < 0) return false;

    final req = _pendingActions.removeAt(idx);
    req.userConfirmed = true;
    _executedActions.add(req);
    return true;
  }

  void cancelAction(String actionId) {
    _pendingActions.removeWhere((a) => a.id == actionId);
  }
}

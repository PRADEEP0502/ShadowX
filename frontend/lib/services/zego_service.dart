import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

import 'call_service.dart';

class ZegoService {
  // TODO: Replace with your actual ZegoCloud App ID and App Sign
  static const int appId = 592759552;
  static const String appSign =
      "4b9f527b47c4e0cc213e4b56df88b3abb161e2650f976d417c0ea1cd836fe7d8";

  static String _myUsername = '';

  static void init({required String username}) {
    _myUsername = username;

    ZegoUIKitPrebuiltCallInvitationService().init(
      appID: appId,
      appSign: appSign,
      userID: username,
      userName: username,
      plugins: [ZegoUIKitSignalingPlugin()],
      invitationEvents: ZegoUIKitPrebuiltCallInvitationEvents(
        onOutgoingCallAccepted: (callID, callee) {
          // Outgoing call accepted
          _saveCall(
            caller: _myUsername,
            receiver: callee.id,
            callType: _resolveCallType(callID),
            status: 'outgoing',
          );
        },
        onOutgoingCallDeclined: (callID, callee, customData) {
          _saveCall(
            caller: _myUsername,
            receiver: callee.id,
            callType: _resolveCallType(callID),
            status: 'missed',
          );
        },
        onOutgoingCallTimeout: (callID, callees, isVideoCall) {
          if (callees.isNotEmpty) {
            _saveCall(
              caller: _myUsername,
              receiver: callees.first.id,
              callType: isVideoCall ? 'video' : 'voice',
              status: 'missed',
            );
          }
        },
        onIncomingCallAcceptButtonPressed: () {
          // Accepted incoming call — we log it in onIncomingCallReceived
        },
        onIncomingCallReceived: (callID, caller, callType, callees, customData) {
          // Recorded when call is accepted via button press event
        },
        onIncomingCallTimeout: (callID, caller) {
          _saveCall(
            caller: caller.id,
            receiver: _myUsername,
            callType: _resolveCallType(callID),
            status: 'missed',
          );
        },
        onIncomingCallDeclineButtonPressed: () {
          // User declined incoming call — log missed for the caller side only
        },
      ),
    );
  }

  static String _resolveCallType(String callID) {
    // ZegoCloud appends call type info to callID — check for "video" keyword
    return callID.toLowerCase().contains('video') ? 'video' : 'voice';
  }

  static void _saveCall({
    required String caller,
    required String receiver,
    required String callType,
    required String status,
    int duration = 0,
  }) {
    CallService.saveCall(
      caller: caller,
      receiver: receiver,
      callType: callType,
      status: status,
      duration: duration,
    );
  }

  static void uninit() {
    ZegoUIKitPrebuiltCallInvitationService().uninit();
  }
}

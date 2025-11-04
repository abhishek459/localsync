import 'package:flutter/material.dart';

enum ShowMyInfoStatus { unauthenticated, authenticating, success, error }

@immutable
class ShowMyInfoState {
  const ShowMyInfoState({
    this.status = ShowMyInfoStatus.unauthenticated,
    this.errorMessage,
  });

  final ShowMyInfoStatus status;
  final String? errorMessage;

  ShowMyInfoState copyWith({ShowMyInfoStatus? status, String? errorMessage}) {
    return ShowMyInfoState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

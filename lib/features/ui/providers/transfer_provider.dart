import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/transfer_service.dart';

enum TransferStatus { idle, searching, connected, transferring, error }

class TransferState {
  final TransferStatus status;
  final String? localIp;
  final List<File> selectedFiles;
  final String? errorMessage;
  final bool isServerRunning;

  TransferState({
    this.status = TransferStatus.idle,
    this.localIp,
    this.selectedFiles = const [],
    this.errorMessage,
    this.isServerRunning = false,
  });

  TransferState copyWith({
    TransferStatus? status,
    String? localIp,
    List<File>? selectedFiles,
    String? errorMessage,
    bool? isServerRunning,
  }) {
    return TransferState(
      status: status ?? this.status,
      localIp: localIp ?? this.localIp,
      selectedFiles: selectedFiles ?? this.selectedFiles,
      errorMessage: errorMessage ?? this.errorMessage,
      isServerRunning: isServerRunning ?? this.isServerRunning,
    );
  }
}

class TransferNotifier extends StateNotifier<TransferState> {
  final TransferService _service = TransferService();

  TransferNotifier() : super(TransferState());

  Future<void> startReceive() async {
    state = state.copyWith(status: TransferStatus.searching);
    final ip = await _service.getLocalIp();
    if (ip != null) {
      state = state.copyWith(
        status: TransferStatus.connected,
        localIp: ip,
        isServerRunning: true,
      );
      // In a real app, we'd start a listener or server here
    } else {
      state = state.copyWith(
        status: TransferStatus.error,
        errorMessage: 'Could not detect local network.',
      );
    }
  }

  Future<void> startSend(List<File> files) async {
    state = state.copyWith(
      status: TransferStatus.transferring,
      selectedFiles: files,
    );
    await _service.startServer(files);
    final ip = await _service.getLocalIp();
    state = state.copyWith(localIp: ip, isServerRunning: true);
  }

  Future<void> stopAll() async {
    await _service.stopServer();
    state = TransferState();
  }
}

final transferProvider = StateNotifierProvider<TransferNotifier, TransferState>(
  (ref) {
    return TransferNotifier();
  },
);

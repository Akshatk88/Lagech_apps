import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:food_user_application/config/constants/app_constants.dart';
import 'package:food_user_application/core/providers/core_providers.dart';

/// Thin wrapper around the Socket.IO connection used for live restaurant
/// events (`new_order`, `order_status_update`, ...). The server auto-joins
/// the `restaurant:<id>` room on connect based on the JWT role/id — see
/// `Backend/src/config/socket.js`.
class SocketService {
  SocketService(this._ref);

  final Ref _ref;
  io.Socket? _socket;

  Future<void> connect() async {
    if (_socket != null) return;
    final token = await _ref.read(tokenStorageProvider).accessToken;
    if (token == null || token.isEmpty) return;

    _socket = io.io(
      AppConstants.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket?.connect();

    Future<void> joinRoom() async {
      final restaurantId = await _ref.read(tokenStorageProvider).restaurantId;
      if (restaurantId != null && restaurantId.isNotEmpty) {
        _socket?.emit('join-restaurant', restaurantId);
      }
    }

    _socket?.onConnect((_) {
      joinRoom();
    });

    _socket?.onReconnect((_) {
      joinRoom();
    });

    _socket?.onDisconnect((_) {
      if (kDebugMode) debugPrint('Socket disconnected. Attempting to reconnect...');
      _socket?.connect();
    });
  }

  void on(String event, void Function(dynamic data) handler) {
    _socket?.on(event, handler);
  }

  void off(String event) {
    _socket?.off(event);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService(ref);
  ref.onDispose(service.disconnect);
  return service;
});

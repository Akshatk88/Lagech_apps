import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/features/chat/presentation/screens/chat_screen.dart';
import 'package:food_user_application/features/orders/application/orders_controller.dart';
import 'package:food_user_application/features/orders/application/orders_state.dart';
import 'package:food_user_application/features/orders/data/models/delivery_order.dart';
import 'package:food_user_application/features/orders/data/orders_repository.dart';

/// Opens the customer chat for an order given only its id.
///
/// [ChatScreen] needs a whole [DeliveryOrder], but a chat push notification
/// carries just the order id. The order is taken from the rider's active orders
/// when it is there, and fetched otherwise, so tapping the notification works
/// even right after a cold start.
class ChatOrderLoader extends ConsumerStatefulWidget {
  const ChatOrderLoader({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<ChatOrderLoader> createState() => _ChatOrderLoaderState();
}

class _ChatOrderLoaderState extends ConsumerState<ChatOrderLoader> {
  DeliveryOrder? _order;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = ref.read(ordersControllerProvider);
    var order = state is OrdersLoaded ? state.activeOrderById(widget.orderId) : null;

    if (order == null) {
      final result =
          await ref.read(ordersRepositoryProvider).getOrderDetails(widget.orderId);
      order = result.when(success: (o) => o, failure: (_) => null);
    }

    if (!mounted) return;
    setState(() {
      _order = order;
      _failed = order == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    if (order != null) return ChatScreen(order: order);

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Center(
        child: _failed
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Couldn't open this chat.",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        setState(() => _failed = false);
                        _load();
                      },
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

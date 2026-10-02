import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeScrollToTopProvider = NotifierProvider<HomeScrollToTopNotifier, int>(() {
  return HomeScrollToTopNotifier();
});

class HomeScrollToTopNotifier extends Notifier<int> {
  @override
  int build() => 0;
  
  void increment() {
    state++;
  }
}

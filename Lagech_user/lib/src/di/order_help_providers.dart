import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/order_help_remote_datasource.dart';
import 'network_providers.dart';

final orderHelpRemoteDataSourceProvider = Provider<OrderHelpRemoteDataSource>((ref) {
  return OrderHelpRemoteDataSource(ref.watch(apiClientProvider));
});

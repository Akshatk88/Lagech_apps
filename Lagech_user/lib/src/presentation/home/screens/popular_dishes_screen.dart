import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/back_navigation.dart';
import '../../../core/utils/haptics.dart';
import '../../branding/app_colors.dart';
import '../../cart/widgets/floating_view_cart_bar.dart';
import '../../common_widgets/empty_state_widget.dart';
import '../../common_widgets/skeleton_loading.dart';
import '../../home/viewmodels/home_viewmodel.dart';
import '../../navigation/route_names.dart';
import '../../restaurant/widgets/food_item_card.dart';

class PopularDishesScreen extends ConsumerStatefulWidget {
  const PopularDishesScreen({super.key});

  @override
  ConsumerState<PopularDishesScreen> createState() => _PopularDishesScreenState();
}

class _PopularDishesScreenState extends ConsumerState<PopularDishesScreen> {
  final GlobalKey<FloatingViewCartBarState> _cartBarKey =
      GlobalKey<FloatingViewCartBarState>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final foodsAsync = ref.watch(homeViewModelProvider).popularFoods;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => context.backOr(),
        ),
        title: Text(
          'Popular Dishes',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          foodsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: SkeletonRestaurantList(count: 3),
            ),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (foods) {
              if (foods.isEmpty) {
                return const EmptyStateWidget(
                  title: 'No popular dishes available right now.',
                  subtitle: 'Check back soon for trending and delicious meals.',
                  icon: Icons.local_fire_department_rounded,
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                itemCount: foods.length,
                itemBuilder: (context, index) {
                  final food = foods[index];
                  return GestureDetector(
                    onTap: () {
                      Haptics.light();
                      context.push(RouteNames.foodDetail, extra: food);
                    },
                    child: FoodItemCard(food: food, cartBarKey: _cartBarKey),
                  );
                },
              );
            },
          ),

          FloatingViewCartBar(
            key: _cartBarKey,
            onTap: () {
              Haptics.light();
              context.go(RouteNames.cart);
            },
          ),
        ],
      ),
    );
  }
}

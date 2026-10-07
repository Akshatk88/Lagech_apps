import 'package:flutter/material.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/features/orders/domain/order_model.dart';

/// The restaurant's side of an order: item total, packaging, commission, the
/// discount it funds, and what it receives ([OrderFinanceModel.netPayout]).
///
/// The customer's delivery fee, platform fee, rider tip and grand total are
/// deliberately left out — they are not the restaurant's money. Until the
/// server's `finance` block is known only the item total is shown, never the
/// customer's bill.
class OrderEarningsBreakdown extends StatelessWidget {
  const OrderEarningsBreakdown({
    super.key,
    required this.order,
    this.fontSize = 14,
  });

  final OrderModel order;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final finance = order.finance;

    Widget row(String label, double amount, {String sign = ''}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(color: Colors.grey, fontSize: fontSize),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$sign₹${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: fontSize,
                color: sign == '− ' ? AppColors.error : null,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row('Item total', order.itemTotal),
        if (finance != null) ...[
          if (finance.packagingFee > 0)
            row('Packaging', finance.packagingFee, sign: '+ '),
          row('Commission', finance.commission, sign: '− '),
          if (finance.restaurantDiscountShare > 0)
            row(
              'Discount you fund',
              finance.restaurantDiscountShare,
              sign: '− ',
            ),
          const SizedBox(height: 4),
          OrderEarningHighlight(amount: finance.netPayout),
          if (finance.totalCustomerPaid > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Customer paid ₹${finance.totalCustomerPaid.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ],
      ],
    );
  }
}

/// The highlighted "You'll receive ₹…" line.
class OrderEarningHighlight extends StatelessWidget {
  const OrderEarningHighlight({super.key, required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_balance_wallet,
            color: AppColors.primaryDark,
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "You'll receive",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: AppColors.primaryDeep,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/design_system/components/dealgo_image_cache.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../driver_card/domain/driver_card.dart';
import '../../../driver_card/presentation/contact_phone_line.dart';
import 'driver_widgets.dart';

/// The real customer on an assigned job (`GET /v1/rides/:id/customer` or
/// `/v1/food/orders/:id/customer`): avatar, full name, an optional rating line
/// and — while the job is running — their phone with a dial button. Falls back
/// to the generic "Khách hàng" while loading, offline, or without a name.
class JobCustomerTile extends StatefulWidget {
  const JobCustomerTile({
    required this.jobId,
    this.isFood = false,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String jobId;
  final bool isFood;
  final String? subtitle;
  final Widget? trailing;

  @override
  State<JobCustomerTile> createState() => _JobCustomerTileState();
}

class _JobCustomerTileState extends State<JobCustomerTile> {
  CustomerCard? _customer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(JobCustomerTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.jobId != widget.jobId) {
      _load();
    }
  }

  Future<void> _load() async {
    final token = driverAccessToken(context);
    if (token == null || token.isEmpty || widget.jobId.isEmpty) {
      return;
    }
    try {
      final customer = await context.read<DriverCardRepository>().fetchCustomer(
        accessToken: token,
        jobId: widget.jobId,
        isFood: widget.isFood,
      );
      if (mounted) {
        setState(() => _customer = customer);
      }
    } on ApiException {
      // Keep the generic label.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final subtitle = widget.subtitle;
    final customer = _customer;
    final name = customer == null || customer.displayName.isEmpty
        ? l10n.driverPassenger
        : customer.displayName;
    final avatar = resolveMediaUrl(customer?.avatarUrl);
    final phone = customer?.phone;
    final trailing = widget.trailing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          key: const Key('job-customer-avatar'),
          radius: 24,
          backgroundColor: DealGoColors.subtlePurple,
          foregroundImage: avatar == null
              ? null
              : DealGoImageCache.provider(avatar, decodeWidth: 240),
          child: const Icon(DealGoIcons.user, color: DealGoColors.primary),
        ),
        const SizedBox(width: DealGoSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                key: const Key('job-customer-name'),
                style: textTheme.titleMedium,
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: DealGoColors.textSecondary,
                  ),
                ),
              if (phone != null) ...[
                const SizedBox(height: DealGoSpacing.s8),
                ContactPhoneLine(phone: phone),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: DealGoSpacing.s8),
          trailing,
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../driver_card/domain/driver_card.dart';
import 'driver_widgets.dart';

/// The real customer name on an assigned job (`GET /v1/rides/:id/customer`),
/// with an optional rating line. Falls back to the generic "Khách hàng" while
/// loading, offline, or when the customer has no profile name.
class JobCustomerName extends StatefulWidget {
  const JobCustomerName({
    required this.jobId,
    this.isFood = false,
    this.subtitle,
    super.key,
  });

  final String jobId;
  final bool isFood;
  final String? subtitle;

  @override
  State<JobCustomerName> createState() => _JobCustomerNameState();
}

class _JobCustomerNameState extends State<JobCustomerName> {
  String? _name;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(JobCustomerName oldWidget) {
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
      final name = await context.read<DriverCardRepository>().fetchCustomerName(
        accessToken: token,
        jobId: widget.jobId,
        isFood: widget.isFood,
      );
      if (mounted && name.isNotEmpty) {
        setState(() => _name = name);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _name ?? l10n.driverPassenger,
          key: const Key('job-customer-name'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium,
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: DealGoColors.textSecondary,
            ),
          ),
      ],
    );
  }
}

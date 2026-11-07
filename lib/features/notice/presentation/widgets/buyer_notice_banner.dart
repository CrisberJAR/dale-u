import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:dale_u/features/notice/domain/vendor_notice.dart';
import 'package:dale_u/features/notice/presentation/viewmodels/buyer_notice_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BuyerNoticeBanner extends StatelessWidget {
  const BuyerNoticeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final notices = context.watch<BuyerNoticeViewModel>().notices;
    if (notices.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final notice in notices) ...[
          _NoticeCard(notice: notice),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice});

  final VendorNotice notice;

  @override
  Widget build(BuildContext context) {
    return VendorSurface(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(notice.headline, style: BuyerLook.subtitle),
          const SizedBox(height: 4),
          Text(
            notice.body,
            style: BuyerLook.title.copyWith(fontSize: 16),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                context.read<BuyerNoticeViewModel>().markSeen(notice);
              },
              child: Text('Entendido', style: BuyerLook.subtitle),
            ),
          ),
        ],
      ),
    );
  }
}

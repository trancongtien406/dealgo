enum PartnerApplicationStatus { draft, pending, rejected, active }

PartnerApplicationStatus partnerStatusFromServer(String status) {
  return switch (status.toUpperCase()) {
    'APPROVED' => PartnerApplicationStatus.active,
    'SUBMITTED' => PartnerApplicationStatus.pending,
    'REJECTED' => PartnerApplicationStatus.rejected,
    'DRAFT' => PartnerApplicationStatus.draft,
    _ => PartnerApplicationStatus.pending,
  };
}

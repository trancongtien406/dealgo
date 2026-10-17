import React from "react";
import { StatusChip } from "@/components/ui/admin-list-ui";
import type { NotificationCampaignStatus } from "../types";
import {
  notificationCampaignStatusLabel,
  notificationCampaignStatusTone,
} from "../mappers";

export function NotificationCampaignStatusChip({
  status,
}: {
  status: NotificationCampaignStatus;
}) {
  const label = notificationCampaignStatusLabel(status);
  const tone = notificationCampaignStatusTone(status);

  if (tone === "quiet") {
    return (
      <span className="inline-flex items-center rounded-full bg-canvas px-2.5 py-1 text-xs font-semibold whitespace-nowrap text-muted">
        {label}
      </span>
    );
  }

  return <StatusChip tone={tone}>{label}</StatusChip>;
}

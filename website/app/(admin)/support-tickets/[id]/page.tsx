import { notFound } from "next/navigation";
import { SupportTicketDetail } from "@/features/support-tickets/components/support-ticket-detail";
import { AdminDetailPage } from "@/lib/admin-detail-page";

type PageProps = {
  params: Promise<{ id: string }>;
};

export default async function SupportTicketDetailPage({ params }: PageProps) {
  const { id } = await params;
  if (!id) {
    notFound();
  }
  return (
    <AdminDetailPage>
      <SupportTicketDetail id={id} />
    </AdminDetailPage>
  );
}

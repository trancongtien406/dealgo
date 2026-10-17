import { notFound } from "next/navigation";
import { NegotiationDetail } from "@/features/negotiations/components/negotiation-detail";
import { AdminDetailPage } from "@/lib/admin-detail-page";

type PageProps = {
  params: Promise<{ code: string }>;
};

export default async function NegotiationDetailPage({ params }: PageProps) {
  const resolvedParams = await params;
  const code = resolvedParams?.code;
  if (!code) {
    notFound();
  }
  return (
    <AdminDetailPage>
      <NegotiationDetail code={code} />
    </AdminDetailPage>
  );
}

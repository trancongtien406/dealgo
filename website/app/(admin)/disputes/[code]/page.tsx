import { notFound } from "next/navigation";
import { DisputeDetail } from "@/features/disputes/components/dispute-detail";
import { AdminDetailPage } from "@/lib/admin-detail-page";

type PageProps = {
  params: Promise<{ code: string }>;
};

export default async function DisputeDetailPage({ params }: PageProps) {
  const resolvedParams = await params;
  const code = resolvedParams?.code;
  if (!code) {
    notFound();
  }
  return (
    <AdminDetailPage>
      <DisputeDetail code={code} />
    </AdminDetailPage>
  );
}

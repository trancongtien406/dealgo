import { notFound } from "next/navigation";
import { RideDetail } from "@/features/rides/components/ride-detail";
import { AdminDetailPage } from "@/lib/admin-detail-page";

type PageProps = {
  params: Promise<{ code: string }>;
};

export default async function RideDetailPage({ params }: PageProps) {
  const resolvedParams = await params;
  const code = resolvedParams?.code;
  if (!code) {
    notFound();
  }
  return (
    <AdminDetailPage>
      <RideDetail code={code} />
    </AdminDetailPage>
  );
}

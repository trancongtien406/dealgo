import { notFound } from "next/navigation";
import { DriverDetail } from "@/features/drivers/components/driver-detail";
import { AdminDetailPage } from "@/lib/admin-detail-page";

type PageProps = {
  params: Promise<{ code: string }>;
};

export default async function DriverDetailPage({ params }: PageProps) {
  const resolvedParams = await params;
  const code = resolvedParams?.code;
  if (!code) {
    notFound();
  }
  return (
    <AdminDetailPage>
      <DriverDetail code={code} />
    </AdminDetailPage>
  );
}

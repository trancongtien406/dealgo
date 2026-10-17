import { notFound } from "next/navigation";
import { DeliveryDetail } from "@/features/deliveries/components/delivery-detail";
import { AdminDetailPage } from "@/lib/admin-detail-page";

type PageProps = {
  params: Promise<{ code: string }>;
};

export default async function DeliveryDetailPage({ params }: PageProps) {
  const resolvedParams = await params;
  const code = resolvedParams?.code;
  if (!code) {
    notFound();
  }
  return (
    <AdminDetailPage>
      <DeliveryDetail code={code} />
    </AdminDetailPage>
  );
}

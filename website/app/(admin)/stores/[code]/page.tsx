import { notFound } from "next/navigation";
import { StoreDetail } from "@/features/stores/components/store-detail";
import { AdminDetailPage } from "@/lib/admin-detail-page";

type PageProps = {
  params: Promise<{ code: string }>;
};

export default async function StoreDetailPage({ params }: PageProps) {
  const resolvedParams = await params;
  const code = resolvedParams?.code;
  if (!code) {
    notFound();
  }
  return (
    <AdminDetailPage>
      <StoreDetail code={code} />
    </AdminDetailPage>
  );
}

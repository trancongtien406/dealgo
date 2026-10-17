import { notFound } from "next/navigation";
import { CustomerDetail } from "@/features/customers/components/customer-detail";
import { AdminDetailPage } from "@/lib/admin-detail-page";

type PageProps = {
  params: Promise<{ code: string }>;
};

export default async function CustomerDetailPage({ params }: PageProps) {
  const resolvedParams = await params;
  const code = resolvedParams?.code;
  if (!code) {
    notFound();
  }
  return (
    <AdminDetailPage>
      <CustomerDetail code={code} />
    </AdminDetailPage>
  );
}

import { notFound } from "next/navigation";
import { KycCaseDetail } from "@/features/kyc/components/kyc-case-detail";
import { AdminDetailPage } from "@/lib/admin-detail-page";

type PageProps = {
  params: Promise<{ code: string }>;
};

export default async function DriversKycDetailPage({ params }: PageProps) {
  const resolvedParams = await params;
  const code = resolvedParams?.code;
  if (!code) {
    notFound();
  }
  return (
    <AdminDetailPage>
      <KycCaseDetail code={code} />
    </AdminDetailPage>
  );
}

import { notFound } from "next/navigation";
import { FoodOrderDetail } from "@/features/food-orders/components/food-order-detail";
import { AdminDetailPage } from "@/lib/admin-detail-page";

type PageProps = {
  params: Promise<{ code: string }>;
};

export default async function FoodOrderDetailPage({ params }: PageProps) {
  const resolvedParams = await params;
  const code = resolvedParams?.code;
  if (!code) {
    notFound();
  }
  return (
    <AdminDetailPage>
      <FoodOrderDetail code={code} />
    </AdminDetailPage>
  );
}

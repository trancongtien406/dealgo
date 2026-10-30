import { ParcelDetail } from "@/features/parcels/components/parcel-detail";

export default async function ParcelDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <ParcelDetail id={id} />;
}

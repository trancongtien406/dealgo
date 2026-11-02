import { permanentRedirect } from "next/navigation";

type Props = { searchParams: Promise<{ lang?: string | string[] }> };

/** pt5u: the partner policy became the admin-managed "Quy chế sử dụng" at /regulations. */
export default async function PartnerPolicyPage({ searchParams }: Props) {
  const lang = (await searchParams).lang;
  permanentRedirect(lang === "en" ? "/regulations?lang=en" : "/regulations");
}

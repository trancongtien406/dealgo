export default function Home() {
  return (
    <main className="flex flex-1 flex-col items-start justify-center px-8 py-16 sm:px-16">
      <p className="text-sm font-medium tracking-wide text-zinc-500">
        DealGo
      </p>
      <h1 className="mt-3 max-w-xl text-3xl font-semibold tracking-tight text-zinc-900 sm:text-4xl">
        Admin Web
      </h1>
      <p className="mt-4 max-w-lg text-base leading-7 text-zinc-600">
        Kênh vận hành nội bộ cho kiểm duyệt, giám sát Ride/Food và xử lý sự cố.
        Scaffold sẵn sàng — nối API theo hợp đồng trong docs và backend.
      </p>
    </main>
  );
}

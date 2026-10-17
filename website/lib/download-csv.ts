/** Build a UTF-8 CSV (BOM) and trigger a browser download. */

function escapeCell(value: string): string {
  if (/[",\n\r]/.test(value)) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
}

export function downloadCsv(
  filename: string,
  headers: readonly string[],
  rows: readonly (readonly string[])[],
): void {
  const lines = [
    headers.map(escapeCell).join(","),
    ...rows.map((row) => row.map((cell) => escapeCell(cell)).join(",")),
  ];
  const blob = new Blob(["\uFEFF" + lines.join("\n")], {
    type: "text/csv;charset=utf-8",
  });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename.endsWith(".csv") ? filename : `${filename}.csv`;
  anchor.rel = "noopener";
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  URL.revokeObjectURL(url);
}

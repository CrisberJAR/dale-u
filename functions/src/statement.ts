/**
 * Página del estado de cuenta que abre el cliente desde el WhatsApp.
 * HTML simple, letra grande, sin scripts ni recursos externos.
 */

export interface StatementMovement {
  kind: "fiado" | "pago";
  amountCents: number;
  occurredAt: number;
}

export interface StatementView {
  vendorName: string;
  clientName: string;
  balanceCents: number;
  movements: StatementMovement[];
  generatedAt: Date;
}

export const TOKEN_PATTERN = /^[A-Za-z0-9]{32,64}$/;

/** El token viene al final de la ruta (/e/TOKEN) o en ?t=TOKEN. */
export function tokenFrom(path: string, query: unknown): string | null {
  const fromQuery =
    typeof query === "object" && query !== null && typeof (query as Record<string, unknown>).t === "string"
      ? ((query as Record<string, unknown>).t as string)
      : "";
  const last = path.split("/").filter(Boolean).pop() ?? "";
  const candidate = fromQuery || last;
  return TOKEN_PATTERN.test(candidate) ? candidate : null;
}

export function balanceFrom(movements: Array<{ kind: string; amountCents: number; voided?: boolean }>): number {
  let total = 0;
  for (const movement of movements) {
    if (movement.voided === true) continue;
    if (movement.kind === "fiado") total += movement.amountCents;
    if (movement.kind === "pago") total -= movement.amountCents;
  }
  return total;
}

export function formatSoles(cents: number): string {
  const sign = cents < 0 ? "-" : "";
  const abs = Math.abs(Math.round(cents));
  const soles = Math.floor(abs / 100)
    .toString()
    .replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  const rest = (abs % 100).toString().padStart(2, "0");
  return `${sign}${soles}.${rest}`;
}

export function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

const dateFormat = new Intl.DateTimeFormat("es-PE", {
  timeZone: "America/Lima",
  day: "2-digit",
  month: "2-digit",
  year: "numeric",
});
const timeFormat = new Intl.DateTimeFormat("es-PE", {
  timeZone: "America/Lima",
  hour: "2-digit",
  minute: "2-digit",
  hour12: false,
});

function balanceLine(cents: number): string {
  if (cents > 0) return `Debes S/ ${formatSoles(cents)}`;
  if (cents < 0) return `Tienes S/ ${formatSoles(-cents)} a favor`;
  return "Estás al día";
}

const STYLE = `
:root{--bg:#FDFBF7;--card:#FFFFFF;--ink:#2B1D0E;--muted:#6B5A45;--line:#E8DCC8;--debt:#B71C1C;--ok:#1B5E20}
@media (prefers-color-scheme:dark){:root{--bg:#17120C;--card:#221A11;--ink:#F5ECDD;--muted:#C9B79C;--line:#3A2E20;--debt:#FF8A80;--ok:#A5D6A7}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:18px/1.45 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
main{max-width:560px;margin:0 auto;padding:24px 16px 40px}
h1{font-size:26px;margin:0 0 4px}
.muted{color:var(--muted);font-size:15px;margin:0}
.card{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:18px;margin:20px 0}
.name{font-size:20px;font-weight:700;margin:0 0 6px}
.balance{font-size:30px;font-weight:800;margin:0}
.debt{color:var(--debt)}.ok{color:var(--ok)}
h2{font-size:18px;margin:24px 0 8px}
ul{list-style:none;margin:0;padding:0}
li{display:flex;justify-content:space-between;gap:12px;padding:12px 0;border-bottom:1px solid var(--line)}
.kind{font-weight:700}.when{color:var(--muted);font-size:15px}
.amount{font-weight:700;white-space:nowrap;font-variant-numeric:tabular-nums}
footer{color:var(--muted);font-size:14px;margin-top:24px}
`;

function page(title: string, body: string): string {
  return `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>${escapeHtml(title)}</title>
<style>${STYLE}</style>
</head>
<body><main>${body}</main></body>
</html>`;
}

export function renderStatement(view: StatementView): string {
  const vendor = view.vendorName.trim() || "Tu panadero";
  const tone = view.balanceCents > 0 ? "debt" : "ok";
  const rows = view.movements
    .map((movement) => {
      const at = new Date(movement.occurredAt);
      const label = movement.kind === "fiado" ? "Fiado" : "Pago";
      const sign = movement.kind === "pago" ? "-" : "";
      return `<li><div><div class="kind">${label}</div><div class="when">${dateFormat.format(at)} · ${timeFormat.format(at)}</div></div><div class="amount">${sign}S/ ${formatSoles(movement.amountCents)}</div></li>`;
    })
    .join("");
  const list = rows
    ? `<ul>${rows}</ul>`
    : `<p class="muted">Aún no hay fiados ni pagos.</p>`;
  const body = `
<h1>Estado de cuenta</h1>
<p class="muted">${escapeHtml(vendor)}</p>
<section class="card">
  <p class="name">${escapeHtml(view.clientName)}</p>
  <p class="balance ${tone}">${balanceLine(view.balanceCents)}</p>
</section>
<h2>Últimos movimientos</h2>
${list}
<footer>Actualizado el ${dateFormat.format(view.generatedAt)} a las ${timeFormat.format(view.generatedAt)}. Fiado suma a la deuda; pago la resta.</footer>`;
  return page(`Estado de cuenta · ${view.clientName}`, body);
}

export function renderNotFound(): string {
  return page(
    "Enlace no válido",
    `<h1>Este enlace no es válido</h1><p class="muted">Pide a tu panadero que te mande uno nuevo.</p>`,
  );
}

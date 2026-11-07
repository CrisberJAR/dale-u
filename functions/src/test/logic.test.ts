import { strict as assert } from "node:assert";
import { test } from "node:test";

import { HERE_METERS, limaDay, messageFor, metersBetween, nextStage } from "../proximity";
import { balanceFrom, escapeHtml, formatSoles, renderStatement, tokenFrom } from "../statement";

test("a 200 m avisa una vez; a 40 m avisa otra; luego nada", () => {
  assert.equal(nextStage(350, undefined), null);
  assert.equal(nextStage(190, undefined), "near");
  assert.equal(nextStage(150, "near"), null);
  assert.equal(nextStage(35, "near"), "here");
  assert.equal(nextStage(10, "here"), null);
  assert.equal(nextStage(120, "here"), null);
});

test("si aparece directo a 40 m, solo llega el aviso de llegada", () => {
  assert.equal(nextStage(HERE_METERS, undefined), "here");
});

test("distancia: ~111 m por milésima de grado de latitud", () => {
  const meters = metersBetween(
    { latitude: -12.046, longitude: -77.0428 },
    { latitude: -12.047, longitude: -77.0428 },
  );
  assert.ok(meters > 105 && meters < 117, `fue ${meters}`);
});

test("el día se cuenta en hora de Lima", () => {
  // 03:00 UTC del 2 de setiembre = 22:00 del 1 en Lima.
  assert.equal(limaDay(new Date("2026-09-02T03:00:00Z")), "2026-09-01");
});

test("los textos de aviso usan el nombre del panadero", () => {
  assert.match(messageFor("near", "Don Pan").body, /Don Pan.*200 metros/);
  assert.equal(messageFor("here", "").title, "Tu panadero llegó");
});

test("saldo: fiado suma, pago resta, anulado no cuenta", () => {
  assert.equal(
    balanceFrom([
      { kind: "fiado", amountCents: 1000 },
      { kind: "pago", amountCents: 250 },
      { kind: "fiado", amountCents: 9999, voided: true },
    ]),
    750,
  );
});

test("token: solo largos y alfanuméricos", () => {
  const token = "A".repeat(40);
  assert.equal(tokenFrom(`/e/${token}`, {}), token);
  assert.equal(tokenFrom("/e/corto", {}), null);
  assert.equal(tokenFrom("/e/../../etc", {}), null);
  assert.equal(tokenFrom("/", { t: token }), token);
});

test("formato de soles con miles", () => {
  assert.equal(formatSoles(150), "1.50");
  assert.equal(formatSoles(500000), "5,000.00");
});

test("la página escapa el nombre del cliente", () => {
  assert.equal(escapeHtml("<b>&"), "&lt;b&gt;&amp;");
  const html = renderStatement({
    vendorName: "Don Pan",
    clientName: "<script>x</script>",
    balanceCents: 1250,
    movements: [{ kind: "fiado", amountCents: 1250, occurredAt: Date.UTC(2026, 8, 1, 15) }],
    generatedAt: new Date(Date.UTC(2026, 8, 2)),
  });
  assert.ok(!html.includes("<script>"));
  assert.ok(html.includes("Debes S/ 12.50"));
});

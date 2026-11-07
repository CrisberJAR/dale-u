// Pruebas de firestore.rules. Correr con: npm test (levanta el emulador).
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { after, before, beforeEach, describe, test } from "node:test";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  collectionGroup,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from "firebase/firestore";

const VENDOR = "vendor_uid_1";
const BUYER = "buyer_uid_1";
const STRANGER = "stranger_uid";
const CLIENT = "client-0001-aaaa";
const CODE = "ABCD23";

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-dale-u",
    firestore: { rules: readFileSync(fileURLToPath(new URL("../firestore.rules", import.meta.url)), "utf8") },
  });
});

after(async () => {
  await env.cleanup();
});

/** Datos base: un vendedor, un comprador, una ficha y su invitación. */
async function seed({ linkedUid = "", active = true, withMarker = false } = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const now = Date.now();
    await setDoc(doc(db, `users/${VENDOR}`), {
      role: "vendedor", email: "v@x.com", displayName: "Don Pan", createdAt: now, updatedAt: now,
    });
    await setDoc(doc(db, `users/${BUYER}`), {
      role: "cliente", email: "b@x.com", displayName: "María", createdAt: now, updatedAt: now,
    });
    await setDoc(doc(db, `vendors/${VENDOR}/clients/${CLIENT}`), {
      vendorUid: VENDOR, name: "María", phone: "", createdAt: now, updatedAt: now,
      active, inviteCode: CODE, linkedUid,
    });
    await setDoc(doc(db, `invites/${CODE}`), {
      vendorUid: VENDOR, clientId: CLIENT, active, linkedUid, vendorName: "Don Pan",
    });
    if (withMarker) {
      await setDoc(doc(db, `buyers/${BUYER}/vendors/${VENDOR}`), { clientId: CLIENT });
    }
  });
}

const as = (uid) => env.authenticatedContext(uid).firestore();

function clientPayload(extra = {}) {
  const now = Date.now();
  return {
    vendorUid: VENDOR, name: "María", phone: "987654321", createdAt: now, updatedAt: now,
    active: true, inviteCode: CODE, ...extra,
  };
}

beforeEach(async () => {
  await env.clearFirestore();
});

describe("fichas de clientes", () => {
  test("el vendedor crea una ficha sin linkedUid", async () => {
    await seed();
    await assertSucceeds(
      setDoc(doc(as(VENDOR), `vendors/${VENDOR}/clients/client-0002-bbbb`), clientPayload()),
    );
  });

  test("el vendedor no puede vincular la ficha a otra persona", async () => {
    await seed();
    await assertFails(
      setDoc(
        doc(as(VENDOR), `vendors/${VENDOR}/clients/client-0002-bbbb`),
        clientPayload({ linkedUid: STRANGER }),
      ),
    );
  });

  test("editar la ficha (merge) no borra la vinculación del comprador", async () => {
    await seed({ linkedUid: BUYER });
    const ref = doc(as(VENDOR), `vendors/${VENDOR}/clients/${CLIENT}`);
    await assertSucceeds(setDoc(ref, clientPayload({ name: "María López" }), { merge: true }));
    let linked;
    await env.withSecurityRulesDisabled(async (ctx) => {
      const snap = await getDoc(doc(ctx.firestore(), `vendors/${VENDOR}/clients/${CLIENT}`));
      linked = snap.get("linkedUid");
    });
    if (linked !== BUYER) throw new Error("se perdió la vinculación");
  });

  test("el vendedor no puede desvincular ni tocar el saldo de la nube", async () => {
    await seed({ linkedUid: BUYER });
    const ref = doc(as(VENDOR), `vendors/${VENDOR}/clients/${CLIENT}`);
    await assertFails(setDoc(ref, clientPayload({ linkedUid: "" }), { merge: true }));
    await assertFails(setDoc(ref, clientPayload({ balanceCents: 0 }), { merge: true }));
  });

  test("un comprador cualquiera no lee fichas ajenas", async () => {
    await seed();
    await assertFails(getDoc(doc(as(STRANGER), `vendors/${VENDOR}/clients/${CLIENT}`)));
  });
});

describe("vincular con código", () => {
  test("el lote atómico (invitación + ficha + libreta + marcador) pasa", async () => {
    await seed();
    const db = as(BUYER);
    const batch = writeBatch(db);
    batch.update(doc(db, `invites/${CODE}`), { linkedUid: BUYER });
    batch.update(doc(db, `vendors/${VENDOR}/clients/${CLIENT}`), {
      linkedUid: BUYER, updatedAt: Date.now(),
    });
    batch.set(doc(db, `buyers/${BUYER}/links/${VENDOR}_${CLIENT}`), {
      vendorUid: VENDOR, clientId: CLIENT, vendorName: "Don Pan", linkedAt: Date.now(),
    });
    batch.set(doc(db, `buyers/${BUYER}/vendors/${VENDOR}`), { clientId: CLIENT });
    await assertSucceeds(batch.commit());
  });

  test("solo la ficha, sin tomar el código, no pasa", async () => {
    await seed();
    await assertFails(
      updateDoc(doc(as(BUYER), `vendors/${VENDOR}/clients/${CLIENT}`), {
        linkedUid: BUYER, updatedAt: Date.now(),
      }),
    );
  });

  test("un código ya tomado no lo toma otro", async () => {
    await seed({ linkedUid: BUYER });
    await assertFails(updateDoc(doc(as(STRANGER), `invites/${CODE}`), { linkedUid: STRANGER }));
  });
});

describe("movimientos", () => {
  const movement = (extra = {}) => ({
    vendorUid: VENDOR, clientId: CLIENT, kind: "fiado", amountCents: 500,
    occurredAt: Date.now(), createdAt: Date.now(), voided: false,
    updatedAt: serverTimestamp(), ...extra,
  });

  test("con hora del servidor se guarda", async () => {
    await seed();
    await assertSucceeds(
      setDoc(doc(as(VENDOR), `vendors/${VENDOR}/clients/${CLIENT}/movements/mov-0001-aaaa`), movement()),
    );
  });

  test("con hora inventada del teléfono no", async () => {
    await seed();
    await assertFails(
      setDoc(
        doc(as(VENDOR), `vendors/${VENDOR}/clients/${CLIENT}/movements/mov-0001-aaaa`),
        movement({ updatedAt: Date.now() }),
      ),
    );
  });

  test("bajada incremental: el vendedor lee solo lo suyo", async () => {
    await seed();
    await assertSucceeds(
      getDocs(query(collectionGroup(as(VENDOR), "movements"), where("vendorUid", "==", VENDOR))),
    );
    await assertFails(
      getDocs(query(collectionGroup(as(STRANGER), "movements"), where("vendorUid", "==", VENDOR))),
    );
  });
});

describe("ruta del panadero", () => {
  test("cualquiera con sesión ve la ruta, deba o no", async () => {
    await seed();
    await assertSucceeds(getDoc(doc(as(STRANGER), `vendors/${VENDOR}/presence/current`)));
    await assertSucceeds(getDocs(collectionGroup(as(STRANGER), "presence")));
  });

  test("sin sesión no", async () => {
    await seed();
    const anon = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(anon, `vendors/${VENDOR}/presence/current`)));
  });

  test("solo el vendedor publica su punto", async () => {
    await seed();
    const point = { onRoute: true, latitude: -12.05, longitude: -77.04, updatedAt: Date.now() };
    await assertSucceeds(setDoc(doc(as(VENDOR), `vendors/${VENDOR}/presence/current`), point));
    await assertFails(setDoc(doc(as(STRANGER), `vendors/${VENDOR}/presence/current`), point));
  });
});

describe("avisos y pedidos con ficha viva", () => {
  const alert = () => ({
    vendorUid: VENDOR, vendorName: "Don Pan", body: "Hoy paso tarde", createdAt: Date.now(), seen: false,
  });

  test("con ficha vinculada, el vendedor avisa", async () => {
    await seed({ linkedUid: BUYER, withMarker: true });
    await assertSucceeds(setDoc(doc(as(VENDOR), `buyers/${BUYER}/alerts/${VENDOR}`), alert()));
  });

  test("con la ficha desactivada, el marcador viejo ya no vale", async () => {
    await seed({ linkedUid: BUYER, withMarker: true, active: false });
    await assertFails(setDoc(doc(as(VENDOR), `buyers/${BUYER}/alerts/${VENDOR}`), alert()));
  });
});

describe("enlace del estado de cuenta y teléfonos", () => {
  const token = "Ab3".repeat(13) + "x";

  test("el vendedor crea el enlace; nadie lo lee desde la app", async () => {
    await seed();
    await assertSucceeds(
      setDoc(doc(as(VENDOR), `statementLinks/${token}`), {
        vendorUid: VENDOR, clientId: CLIENT, createdAt: Date.now(),
      }),
    );
    await assertFails(getDoc(doc(as(VENDOR), `statementLinks/${token}`)));
  });

  test("no se crea un enlace a la ficha de otro vendedor", async () => {
    await seed();
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), `users/${STRANGER}`), {
        role: "vendedor", email: "s@x.com", displayName: "Otro", createdAt: 1, updatedAt: 1,
      }),
    );
    await assertFails(
      setDoc(doc(as(STRANGER), `statementLinks/${token}`), {
        vendorUid: VENDOR, clientId: CLIENT, createdAt: Date.now(),
      }),
    );
  });

  test("cada quien guarda solo su teléfono para avisos", async () => {
    await seed();
    const device = { token: "x".repeat(40), platform: "android", updatedAt: Date.now() };
    await assertSucceeds(setDoc(doc(as(BUYER), `users/${BUYER}/devices/install-0001`), device));
    await assertFails(setDoc(doc(as(STRANGER), `users/${BUYER}/devices/install-0002`), device));
  });
});

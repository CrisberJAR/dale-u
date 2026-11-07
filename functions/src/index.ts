/**
 * Cloud Functions de Dale U.
 *
 * - recalcularSaldo: mantiene `balanceCents` en cada ficha de cliente. El
 *   comprador lee su saldo con una sola lectura.
 * - avisarPanaderoCerca: con cada punto del panadero en ruta, avisa a los
 *   compradores vinculados con casa marcada: a 200 m y a 40 m. Nada más.
 * - estadoCuenta: la página del enlace que el vendedor manda por WhatsApp.
 *
 * Región: debe coincidir con la ubicación de tu base Firestore. Cámbiala
 * en REGION si tu base no está en nam5 / us-central1.
 */
import { initializeApp } from "firebase-admin/app";
import {
  AggregateField,
  FieldValue,
  getFirestore,
  type DocumentData,
  type Firestore,
} from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { setGlobalOptions, logger } from "firebase-functions/v2";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";

import {
  limaDay,
  messageFor,
  metersBetween,
  nextStage,
  NEAR_METERS,
  type Stage,
} from "./proximity";
import {
  balanceFrom,
  renderNotFound,
  renderStatement,
  tokenFrom,
  type StatementMovement,
} from "./statement";

const REGION = "us-central1";
setGlobalOptions({ region: REGION, maxInstances: 10 });

initializeApp();
const db: Firestore = getFirestore();

/** Un punto con más de 2 minutos ya no sirve para decir "está cerca". */
const PRESENCE_MAX_AGE_MS = 2 * 60 * 1000;
/** Fichas con casa marcada: se reusan unos minutos entre puntos. */
const CLIENT_CACHE_MS = 5 * 60 * 1000;

// ---------------------------------------------------------------------------
// Saldo en la nube
// ---------------------------------------------------------------------------

export const recalcularSaldo = onDocumentWritten(
  "vendors/{vendorId}/clients/{clientId}/movements/{movementId}",
  async (event) => {
    const { vendorId, clientId } = event.params;
    const clientRef = db.doc(`vendors/${vendorId}/clients/${clientId}`);
    const movements = clientRef.collection("movements");

    let balance: number;
    try {
      // Suma en el servidor: cuesta 1 lectura por cada 1000 movimientos.
      const [fiado, pago] = await Promise.all([
        movements
          .where("kind", "==", "fiado")
          .where("voided", "==", false)
          .aggregate({ total: AggregateField.sum("amountCents") })
          .get(),
        movements
          .where("kind", "==", "pago")
          .where("voided", "==", false)
          .aggregate({ total: AggregateField.sum("amountCents") })
          .get(),
      ]);
      balance = (fiado.data().total ?? 0) - (pago.data().total ?? 0);
    } catch (error) {
      // Sin el índice desplegado: se suma leyendo todo (siempre funciona).
      logger.warn("Aggregate sum unavailable, scanning movements", { error: String(error) });
      const snapshot = await movements.get();
      balance = balanceFrom(
        snapshot.docs.map((doc) => {
          const data = doc.data();
          return {
            kind: String(data.kind ?? ""),
            amountCents: Number(data.amountCents ?? 0),
            voided: data.voided === true,
          };
        }),
      );
    }

    try {
      await clientRef.update({
        balanceCents: Math.round(balance),
        balanceUpdatedAt: FieldValue.serverTimestamp(),
      });
    } catch (error) {
      // La ficha aún no subió (o se purgó): se recalcula en el próximo cambio.
      logger.info("Client doc missing for balance", { vendorId, clientId, error: String(error) });
    }
  },
);

// ---------------------------------------------------------------------------
// Aviso de panadero cerca
// ---------------------------------------------------------------------------

interface HouseStop {
  clientId: string;
  buyerUid: string;
  latitude: number;
  longitude: number;
}

const stopsCache = new Map<string, { at: number; stops: HouseStop[] }>();
const nameCache = new Map<string, { at: number; name: string }>();

async function housesOf(vendorId: string): Promise<HouseStop[]> {
  const cached = stopsCache.get(vendorId);
  if (cached && Date.now() - cached.at < CLIENT_CACHE_MS) return cached.stops;
  const snapshot = await db
    .collection(`vendors/${vendorId}/clients`)
    .where("active", "==", true)
    .get();
  const stops: HouseStop[] = [];
  for (const doc of snapshot.docs) {
    const data = doc.data();
    const buyerUid = typeof data.linkedUid === "string" ? data.linkedUid : "";
    if (!buyerUid) continue;
    if (typeof data.latitude !== "number" || typeof data.longitude !== "number") continue;
    stops.push({ clientId: doc.id, buyerUid, latitude: data.latitude, longitude: data.longitude });
  }
  stopsCache.set(vendorId, { at: Date.now(), stops });
  return stops;
}

async function vendorNameOf(vendorId: string): Promise<string> {
  const cached = nameCache.get(vendorId);
  if (cached && Date.now() - cached.at < CLIENT_CACHE_MS) return cached.name;
  const snapshot = await db.doc(`vendors/${vendorId}`).get();
  const name = typeof snapshot.get("displayName") === "string" ? (snapshot.get("displayName") as string) : "";
  nameCache.set(vendorId, { at: Date.now(), name });
  return name;
}

async function tokensOf(uid: string): Promise<Array<{ ref: FirebaseFirestore.DocumentReference; token: string }>> {
  const snapshot = await db.collection(`users/${uid}/devices`).get();
  return snapshot.docs
    .map((doc) => ({ ref: doc.ref, token: String(doc.get("token") ?? "") }))
    .filter((item) => item.token.length >= 20);
}

async function notify(uid: string, vendorId: string, stage: Stage, vendorName: string): Promise<void> {
  const devices = await tokensOf(uid);
  if (devices.length === 0) return;
  const { title, body } = messageFor(stage, vendorName);
  const response = await getMessaging().sendEachForMulticast({
    tokens: devices.map((item) => item.token),
    notification: { title, body },
    data: { type: "panadero_cerca", stage, vendorUid: vendorId },
    android: {
      priority: "high",
      // Mismo tag: el aviso de 40 m reemplaza al de 200 m en la bandeja.
      notification: { channelId: "panadero_cerca", tag: `panadero-${vendorId}` },
    },
    apns: { payload: { aps: { sound: "default", threadId: `panadero-${vendorId}` } } },
  });
  // Tokens viejos (app desinstalada): se borran para no reintentar.
  const stale: Promise<unknown>[] = [];
  response.responses.forEach((result, index) => {
    const code = result.error?.code ?? "";
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token" ||
      code === "messaging/invalid-argument"
    ) {
      stale.push(devices[index].ref.delete());
    }
  });
  await Promise.all(stale);
}

export const avisarPanaderoCerca = onDocumentWritten(
  "vendors/{vendorId}/presence/{docId}",
  async (event) => {
    const { vendorId, docId } = event.params;
    if (docId !== "current") return;
    const after = event.data?.after?.data() as DocumentData | undefined;
    if (!after || after.onRoute !== true) return;
    if (typeof after.latitude !== "number" || typeof after.longitude !== "number") return;
    const updatedAt = Number(after.updatedAt ?? 0);
    if (!updatedAt || Date.now() - updatedAt > PRESENCE_MAX_AGE_MS) return;

    const here = { latitude: after.latitude, longitude: after.longitude };
    const houses = await housesOf(vendorId);
    const nearby = houses
      .map((stop) => ({ stop, meters: metersBetween(here, stop) }))
      .filter((item) => item.meters <= NEAR_METERS);
    if (nearby.length === 0) return;

    // Estado por día: qué aviso ya recibió cada casa. En transacción para
    // que dos puntos seguidos no manden el mismo aviso dos veces.
    const stateRef = db.doc(`vendors/${vendorId}/private/proximity`);
    const today = limaDay(new Date());
    const toSend = await db.runTransaction(async (tx) => {
      const snapshot = await tx.get(stateRef);
      const sameDay = snapshot.get("day") === today;
      const sent: Record<string, Stage> = sameDay ? { ...(snapshot.get("sent") ?? {}) } : {};
      const pending: Array<{ stop: HouseStop; stage: Stage }> = [];
      for (const { stop, meters } of nearby) {
        const stage = nextStage(meters, sent[stop.clientId]);
        if (!stage) continue;
        sent[stop.clientId] = stage;
        pending.push({ stop, stage });
      }
      if (pending.length > 0) {
        tx.set(stateRef, { day: today, sent, updatedAt: FieldValue.serverTimestamp() });
      }
      return pending;
    });
    if (toSend.length === 0) return;

    const vendorName = await vendorNameOf(vendorId);
    await Promise.all(
      toSend.map(async ({ stop, stage }) => {
        try {
          await notify(stop.buyerUid, vendorId, stage, vendorName);
        } catch (error) {
          logger.error("Proximity push failed", { vendorId, clientId: stop.clientId, error: String(error) });
        }
      }),
    );
  },
);

// ---------------------------------------------------------------------------
// Página del estado de cuenta
// ---------------------------------------------------------------------------

const MAX_ROWS = 60;

export const estadoCuenta = onRequest({ invoker: "public", cors: false }, async (req, res) => {
  res.set("Content-Type", "text/html; charset=utf-8");
  res.set("Cache-Control", "private, no-store");
  res.set("X-Content-Type-Options", "nosniff");
  res.set("Referrer-Policy", "no-referrer");
  res.set("X-Robots-Tag", "noindex, nofollow");
  res.set(
    "Content-Security-Policy",
    "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
  );

  if (req.method !== "GET" && req.method !== "HEAD") {
    res.status(405).send(renderNotFound());
    return;
  }
  const token = tokenFrom(req.path, req.query);
  if (!token) {
    res.status(404).send(renderNotFound());
    return;
  }

  try {
    const link = await db.doc(`statementLinks/${token}`).get();
    const vendorUid = link.get("vendorUid");
    const clientId = link.get("clientId");
    if (!link.exists || typeof vendorUid !== "string" || typeof clientId !== "string") {
      res.status(404).send(renderNotFound());
      return;
    }
    const clientRef = db.doc(`vendors/${vendorUid}/clients/${clientId}`);
    const [client, vendorName, recent] = await Promise.all([
      clientRef.get(),
      vendorNameOf(vendorUid),
      clientRef.collection("movements").orderBy("occurredAt", "desc").limit(MAX_ROWS * 2).get(),
    ]);
    if (!client.exists) {
      res.status(404).send(renderNotFound());
      return;
    }

    const movements: StatementMovement[] = recent.docs
      .map((doc) => doc.data())
      .filter((data) => data.voided !== true && (data.kind === "fiado" || data.kind === "pago"))
      .slice(0, MAX_ROWS)
      .map((data) => ({
        kind: data.kind as "fiado" | "pago",
        amountCents: Number(data.amountCents ?? 0),
        occurredAt: Number(data.occurredAt ?? 0),
      }));

    let balance = client.get("balanceCents");
    if (typeof balance !== "number") {
      const all = await clientRef.collection("movements").get();
      balance = balanceFrom(
        all.docs.map((doc) => ({
          kind: String(doc.get("kind") ?? ""),
          amountCents: Number(doc.get("amountCents") ?? 0),
          voided: doc.get("voided") === true,
        })),
      );
    }

    res.status(200).send(
      renderStatement({
        vendorName,
        clientName: String(client.get("name") ?? "Cliente"),
        balanceCents: Number(balance),
        movements,
        generatedAt: new Date(),
      }),
    );
  } catch (error) {
    logger.error("Statement page failed", { error: String(error) });
    res.status(500).send(renderNotFound());
  }
});

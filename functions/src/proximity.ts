/**
 * Aviso "Tu panadero está cerca". Pocas notificaciones a propósito: el
 * comprador recibe como mucho DOS por día y por panadero:
 *   1. al entrar a 200 m de su casa, y
 *   2. al estar a 40 m o menos.
 * Si el panadero aparece ya a 40 m, solo llega el segundo.
 */

export const NEAR_METERS = 200;
export const HERE_METERS = 40;

export type Stage = "near" | "here";

/** Qué aviso toca mandar ahora, o null si ya se mandó o está lejos. */
export function nextStage(distanceMeters: number, sent: Stage | undefined): Stage | null {
  if (!Number.isFinite(distanceMeters) || distanceMeters < 0) return null;
  if (distanceMeters <= HERE_METERS) {
    return sent === "here" ? null : "here";
  }
  if (distanceMeters <= NEAR_METERS) {
    return sent === undefined ? "near" : null;
  }
  return null;
}

/** Distancia en metros entre dos puntos (fórmula del haversine). */
export function metersBetween(
  a: { latitude: number; longitude: number },
  b: { latitude: number; longitude: number },
): number {
  const earth = 6371000;
  const rad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = rad(b.latitude - a.latitude);
  const dLng = rad(b.longitude - a.longitude);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(a.latitude)) * Math.cos(rad(b.latitude)) * Math.sin(dLng / 2) ** 2;
  return 2 * earth * Math.asin(Math.min(1, Math.sqrt(h)));
}

/** "2026-09-01" en hora de Lima: el contador de avisos vuelve a cero cada día. */
export function limaDay(at: Date): string {
  const lima = new Date(at.getTime() - 5 * 60 * 60 * 1000);
  return lima.toISOString().slice(0, 10);
}

export function messageFor(stage: Stage, vendorName: string): { title: string; body: string } {
  const who = vendorName.trim() || "Tu panadero";
  if (stage === "here") {
    return {
      title: "Tu panadero llegó",
      body: `${who} está a unos pasos de tu casa.`,
    };
  }
  return {
    title: "Tu panadero está cerca",
    body: `${who} está a unos 200 metros de tu casa.`,
  };
}

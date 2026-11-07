# Dale U

App de ruta de venta de pan. El vendedor anota fiados y pagos con la voz,
sin señal, y sus clientes ven su deuda y por dónde va el panadero.

- **Vendedor:** voz local (sin internet), clientes y saldos en el teléfono
  (SQLite), ruta con GPS (también con la pantalla apagada), radar de
  deudores, cobro por WhatsApp con enlace al estado de cuenta, PDF.
- **Comprador:** su saldo y movimientos, mapa del panadero (cualquiera con
  sesión lo ve), "Déjame pan", aviso **"Tu panadero está cerca"** (a 200 m y
  a 40 m de su casa, como mucho dos avisos por día) y su estado de cuenta en PDF.

## Estructura

| Carpeta | Qué hay |
|---|---|
| `lib/` | App Flutter (Clean Architecture por función: `domain`, `data`, `presentation`) |
| `test/` | Pruebas de la app (`flutter test`) |
| `functions/` | Cloud Functions: saldo en la nube, aviso de cercanía, página del estado de cuenta |
| `firestore.rules` | Reglas de seguridad de Firestore |
| `firestore-tests/` | Pruebas de las reglas con el emulador |
| `firestore.indexes.json` | Índices (bajada incremental y suma del saldo) |
| `hosting/` | Página base de Firebase Hosting (el enlace `/e/...` lo atiende la función) |

## Arranque local

```bash
cp .env.example .env        # y completa los valores de tu proyecto Firebase
flutter pub get
flutter run --dart-define-from-file=.env
```

`android/app/google-services.json` debe ser del mismo proyecto que `.env`.

## Pruebas

```bash
flutter analyze && flutter test                 # app
cd functions && npm ci && npm test              # Cloud Functions
cd firestore-tests && npm ci && npm test        # reglas (necesita Java 21)
```

GitHub Actions corre las tres en cada cambio (`.github/workflows/ci.yml`).

## Desplegar el backend (una vez y tras cada cambio)

Requiere el plan **Blaze** de Firebase (las Cloud Functions no van en el plan
gratuito; el uso de esta app cabe holgado en la cuota gratis del Blaze).

```bash
npm install -g firebase-tools
firebase login
firebase deploy --only firestore:rules,firestore:indexes
cd functions && npm ci && cd ..
firebase deploy --only functions,hosting
```

- **Región:** las funciones usan `us-central1`. Si tu Firestore está en otra
  ubicación, cambia `REGION` en `functions/src/index.ts` y la región del
  rewrite en `firebase.json`.
- Los índices tardan unos minutos en construirse. Mientras tanto la app baja
  todo como antes y la función del saldo suma leyendo los movimientos.

## App Check (recomendado)

1. Firebase Console → App Check → registra la app Android con **Play
   Integrity** (necesita la huella SHA-256 de la firma de Play).
2. Instala una versión nueva y espera a que casi todas las peticiones lleguen
   "verificadas" en las métricas.
3. Recién ahí pulsa **Exigir** para Firestore. Antes de eso, solo mide.

En modo debug la app usa el proveedor de depuración: el token aparece en la
consola de Android Studio y se registra en App Check → Administrar tokens.

## Entregar una versión

1. Sube `version:` en `pubspec.yaml` (por ejemplo `1.0.1+2`).
2. `.\scripts\build_apk.ps1` → deja `dist/DaleU-x.y.z.apk` y `.aab`.
3. Sube el `.aab` a Play Console (prueba interna primero).
4. Guarda `build/symbols/<versión>`: sirve para leer los errores ofuscados.

**Respalda `android/keystore/dale-u-release.jks` y `android/key.properties`
fuera de esta computadora** (gestor de contraseñas). Sin ellos no se puede
actualizar la app en Play Store. Activa también *Play App Signing*.

## Datos y privacidad

- El vendedor puede editar o anular movimientos; el comprador solo ve los
  vigentes (lo anulado no aparece).
- Un cliente **con saldo** no se puede desactivar ni se borra solo. Uno al día,
  desactivado y sin movimientos por 30 días se borra de la nube y del teléfono.
- El enlace del estado de cuenta es privado por ser imposible de adivinar
  (40 caracteres al azar): quien lo tenga ve ese saldo. Por eso solo se manda
  al WhatsApp del cliente.

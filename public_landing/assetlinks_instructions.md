Pasos para publicar `assetlinks.json` para Android App Links

1) Obtener la huella SHA-256 del certificado de firma

- Debug keystore (Windows):

  keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android

- Release keystore (reemplaza ruta y alias):

  keytool -list -v -keystore path/to/your/keystore.jks -alias yourKeyAlias

Copia la línea `SHA256:` mostrada y pégala en `public_landing/.well-known/assetlinks.json` reemplazando `REPLACE_WITH_SHA256_FINGERPRINT`.

2) Colocar `assetlinks.json` en https://www.luia.app/.well-known/assetlinks.json

- Si el sitio está generado desde `public_landing`, asegúrate de que el archivo se despliegue en la ruta `/.well-known/assetlinks.json`.

3) Verificar App Link en Android

- Instala la app firmada con el mismo certificado cuya huella añadiste.
- En un dispositivo Android, usa: `adb shell am start -a android.intent.action.VIEW -d "https://www.luia.app/" com.luia`
- Revisa `adb logcat` para comprobar la verificación o usa la sección "App links" en las settings de la app para ver estado.

Notas:
- Mantén el `package_name` en `assetlinks.json` como `com.luia` (o actualiza si cambia).
- Si usas varias firmas, añade todas las huellas en el array `sha256_cert_fingerprints`.

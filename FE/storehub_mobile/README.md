# KhoMini mobile

## Development

The default API URL is `http://10.0.2.2:8080/api/v1` for the Android emulator.
Debug builds allow a local HTTP server. The login screen can also save a custom
server URL; that URL is loaded before session restoration.

## Android release

Release builds require an HTTPS backend and a private signing key. Set these
environment variables before building:

- `STOREHUB_KEYSTORE_PATH`: absolute path to the Android keystore
- `STOREHUB_KEYSTORE_PASSWORD`: keystore password
- `STOREHUB_KEY_ALIAS`: signing key alias
- `STOREHUB_KEY_PASSWORD`: signing key password

Then run `flutter build appbundle --release --dart-define=API_BASE_URL=https://your-domain.example/api/v1`.
The app ID is `com.huy39quoc.khomini`; confirm it matches your store listing
before the first public release. Do not commit the keystore or passwords.

# Firebase online multiplayer setup

The online mode uses anonymous Firebase Authentication and Firebase Realtime
Database. The match host is authoritative: clients write input commands and the
host publishes throttled state snapshots.

1. Install the Firebase CLI and FlutterFire CLI.
2. Sign in with `firebase login`.
3. From this project, run `flutterfire configure` and select Android, iOS, web,
   macOS, and Windows as required.
4. In Firebase Console, enable **Authentication → Sign-in method → Anonymous**.
5. Create a Realtime Database in the region closest to the expected players.
6. Deploy the checked-in rules with `firebase deploy --only database`.
7. Rebuild the app. Do not commit private service-account credentials.

For local development, prefer the Firebase Emulator Suite. Production room
cleanup should eventually be supplemented by a scheduled Cloud Function that
deletes closed or abandoned rooms after a short retention period.

Web builds may alternatively receive configuration through these dart defines:
`FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`,
`FIREBASE_PROJECT_ID`, `FIREBASE_DATABASE_URL`, `FIREBASE_AUTH_DOMAIN`, and
`FIREBASE_STORAGE_BUCKET`.

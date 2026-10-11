/**
 * Castelle — Tek seferlik KVKK / güvenlik veri taşıma betiği
 *
 * users/{uid} kök belgelerinde kalmış hassas alanları (telefon, e-posta,
 * doğum tarihi, veli bilgileri, IBAN vb.) users/{uid}/private/contact alt
 * belgesine taşır ve kök belgeden siler. Uygulama bunu her kullanıcı giriş
 * yaptığında zaten yapar; bu betik, uzun süredir giriş yapmamış
 * kullanıcıların verilerini de hemen korumaya almak içindir.
 *
 * ÇALIŞTIRMA (bir kez):
 *   1. Firebase Console → Proje Ayarları → Hizmet Hesapları →
 *      "Yeni özel anahtar oluştur" ile JSON indirin (paylaşmayın, repoya koymayın).
 *   2. cd functions && npm install
 *   3. Windows PowerShell:
 *        $env:GOOGLE_APPLICATION_CREDENTIALS="C:\yol\servis-hesabi.json"
 *        node scripts/migrate_private_fields.js
 *
 * Önce sadece rapor almak için:  node scripts/migrate_private_fields.js --dry-run
 */

const {initializeApp, applicationDefault} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

// lib/core/services/private_profile_fields.dart ile aynı liste
const PRIVATE_FIELDS = [
  "phone",
  "guardianPhone",
  "bankIban",
  "bankAccountHolder",
  "email",
  "birthDate",
  "guardianName",
  "emergencyPhone",
  "recoveryEmail",
  "consents",
];

const dryRun = process.argv.includes("--dry-run");

initializeApp({credential: applicationDefault(), projectId: "castelle-ce64b"});
const db = getFirestore();

(async () => {
  const users = await db.collection("users").get();
  let moved = 0;
  for (const doc of users.docs) {
    const data = doc.data();
    const legacy = {};
    for (const key of PRIVATE_FIELDS) {
      const v = data[key];
      if (v !== undefined && v !== null && v !== "") legacy[key] = v;
    }
    if (Object.keys(legacy).length === 0) continue;

    moved++;
    console.log(`${doc.id}: ${Object.keys(legacy).join(", ")}`);
    if (dryRun) continue;

    await doc.ref.collection("private").doc("contact").set(legacy, {merge: true});
    const removal = {};
    for (const key of Object.keys(legacy)) removal[key] = FieldValue.delete();
    await doc.ref.update(removal);
  }
  console.log(`${dryRun ? "[DRY RUN] " : ""}${moved} kullanıcı belgesi ${dryRun ? "taşınacak" : "taşındı"}.`);

  // Projeler: isPrivate alanı olmayanlara false yaz, eski casting davetlerini
  // invitedActorIds listesine işle (gizli projeleri davetli oyuncular açabilsin).
  const invites = await db.collection("notifications").where("type", "==", "casting_invite").get();
  const invitedByProject = {};
  for (const n of invites.docs) {
    const d = n.data();
    const pid = d.projectId;
    const rid = d.recipientId || d.userId;
    if (!pid || !rid) continue;
    (invitedByProject[pid] = invitedByProject[pid] || new Set()).add(rid);
  }
  const projects = await db.collection("projects").get();
  let projUpdated = 0;
  for (const p of projects.docs) {
    const update = {};
    if (p.data().isPrivate === undefined) update.isPrivate = false;
    const invited = invitedByProject[p.id];
    if (invited && invited.size) update.invitedActorIds = FieldValue.arrayUnion(...invited);
    if (Object.keys(update).length === 0) continue;
    projUpdated++;
    if (!dryRun) await p.ref.update(update);
  }
  console.log(`${dryRun ? "[DRY RUN] " : ""}${projUpdated} proje belgesi güncellendi.`);
})().catch((err) => {
  console.error(err);
  process.exit(1);
});

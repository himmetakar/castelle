/**
 * Castelle - Cloud Functions
 *
 * Firestore'daki "notifications" koleksiyonuna yeni bir doküman eklendiğinde
 * (bkz. lib/core/services/notification_service.dart), ilgili kullanıcının
 * cihazına gerçek bir FCM push bildirimi gönderir — telefonun üstünde
 * WhatsApp benzeri sesli/banner bildirim olarak görünür.
 *
 * Flutter tarafı sadece Firestore'a yazıyor (uygulama içi bildirim listesi
 * için); asıl push'un GÖNDERİLMESİ bu fonksiyon tarafından yapılır, çünkü
 * cihazlara push göndermek bir sunucu kimlik bilgisi (Admin SDK) gerektirir.
 *
 * DEPLOY: proje kök dizininden çalıştırın:
 *   cd functions && npm install && cd ..
 *   firebase deploy --only functions
 *
 * NOT: Cloud Functions kullanabilmek için Firebase projenizin Blaze
 * (kullandıkça öde) planında olması gerekir. Spark (ücretsiz) planda
 * fonksiyonlar deploy edilemez.
 */

const {onDocumentCreated, onDocumentWritten} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {getStorage} = require("firebase-admin/storage");
const {FieldValue} = require("firebase-admin/firestore");
// Auth silme tetikleyicisi yalnızca 1. nesil (v1) API'de mevcut.
const functionsV1 = require("firebase-functions/v1");

initializeApp();
setGlobalOptions({region: "us-central1", maxInstances: 10});

const db = getFirestore();
const messaging = getMessaging();

// AndroidManifest.xml + push_notification_service.dart ile aynı kanal id'si
const ANDROID_CHANNEL_ID = "castelle_high_importance";

exports.sendPushOnNotificationCreate = onDocumentCreated(
    "notifications/{notificationId}",
    async (event) => {
      const snap = event.data;
      if (!snap) return;
      const data = snap.data() || {};

      const recipientId = data.recipientId || data.userId;
      if (!recipientId) {
        console.log("Bildirimde recipientId/userId yok, atlanıyor.");
        return;
      }

      const title = data.title || "Castelle";
      const body = data.body || "";

      try {
        const userDoc = await db.collection("users").doc(recipientId).get();
        const fcmToken = userDoc.exists ? userDoc.get("fcmToken") : null;

        if (!fcmToken) {
          console.log(`Kullanıcı ${recipientId} için fcmToken yok, push atlanıyor.`);
          return;
        }

        await messaging.send({
          token: fcmToken,
          notification: {title, body},
          data: {
            type: String(data.type || ""),
            notificationId: event.params.notificationId,
            projectId: String(data.projectId || ""),
          },
          android: {
            priority: "high",
            notification: {
              channelId: ANDROID_CHANNEL_ID,
              sound: "default",
              defaultSound: true,
              priority: "max",
              visibility: "public",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
                "content-available": 1,
              },
            },
          },
        });

        console.log(`Push gönderildi -> ${recipientId}`);
      } catch (err) {
        // Token geçersiz/eskimiş olabilir (kullanıcı çıkış yaptı, uygulamayı
        // kaldırdı vb.) — bu normal bir durumdur, fonksiyonu hata ile
        // sonlandırmadan sadece logluyoruz.
        console.error(`Push gönderim hatası (${recipientId}):`, err);
      }
    },
);

// ═══════════════════════════════════════════════════════════════════════════
// OYUNCU HAVUZU GİZLİLİĞİ (02.10.2026)
//
// Mağazadaki uygulama Oyuncu Havuzu'nu `users where role == 'actor'`
// sorgusuyla listeler. Gizli profillerin (18 yaş altı / veli onayı bekleyen /
// yaş doğrulamasını bitirmemiş / kendini gizleyen) bu listede çıkmaması için
// gizli oyuncuların rolü "actor_hidden" olarak tutulur. Uygulama tanımadığı
// rolü "Oyuncu" olarak okur (UserRole.fromString → orElse: actor), yani
// kullanıcının kendisi için hiçbir şey değişmez.
//
// Kural: role == 'actor'  ⇔  isHidden == false
// ═══════════════════════════════════════════════════════════════════════════

const ACTOR_ROLES = ["actor", "actor_hidden"];

exports.syncActorVisibility = onDocumentWritten("users/{uid}", async (event) => {
  const after = event.data && event.data.after;
  if (!after || !after.exists) return;
  const data = after.data() || {};
  if (!ACTOR_ROLES.includes(data.role)) return;

  const wanted = data.isHidden === false ? "actor" : "actor_hidden";
  if (data.role === wanted) return; // zaten doğru → döngü yok

  await after.ref.update({role: wanted});
  console.log(`users/${event.params.uid}: role ${data.role} -> ${wanted}`);
});

/**
 * KVKK — Hesap silindiğinde kişisel verilerin sunucu tarafında silinmesi
 * ("unutulma hakkı").
 *
 * Kullanıcı uygulamadan hesabını sildiğinde (Firebase Auth hesabı silinir)
 * bu fonksiyon çalışır ve:
 *  1. users/{uid} belgesini ve private alt belgesini siler,
 *  2. Storage'daki profiles/{uid}/ klasörünü (foto, video, CV) siler,
 *  3. Oyuncunun audition videolarını (revize öncesi yedekler dahil) siler ve
 *     başvuru kayıtlarını anonimleştirir (istatistik için isim/iletişim
 *     içermeyen kayıt kalır),
 *  4. Kullanıcıya gelen bildirimleri, takvim kayıtlarını ve sohbetlerini
 *     (mesajlarıyla birlikte) siler.
 *
 * Bu işlemler istemciden yapılamaz, çünkü güvenlik kuralları başvuru ve
 * sohbet silmeyi yalnızca admin'e izin verir; ayrıca Auth hesabı silindikten
 * sonra istemcinin veritabanı erişimi kalmaz.
 */
exports.purgeDeletedUserData = functionsV1
    .region("us-central1")
    .auth.user()
    .onDelete(async (user) => {
      const uid = user.uid;
      const bucket = getStorage().bucket();

      const storagePathFromUrl = (url) => {
        if (typeof url !== "string" || !url.includes("/o/")) return null;
        try {
          const start = url.indexOf("/o/") + 3;
          const end = url.indexOf("?", start);
          const raw = end === -1 ? url.substring(start) : url.substring(start, end);
          return decodeURIComponent(raw);
        } catch (_) {
          return null;
        }
      };

      const deleteFileByUrl = async (url) => {
        const path = storagePathFromUrl(url);
        if (!path) return;
        try {
          await bucket.file(path).delete({ignoreNotFound: true});
        } catch (err) {
          console.error(`Dosya silinemedi (${path}):`, err.message);
        }
      };

      // 1. Profil medyası
      try {
        await bucket.deleteFiles({prefix: `profiles/${uid}/`});
      } catch (err) {
        console.error("Profil medyası silinemedi:", err.message);
      }

      // 2. Audition'lar: videoları sil, kaydı anonimleştir
      const auditions = await db.collection("auditions").where("actorId", "==", uid).get();
      for (const doc of auditions.docs) {
        const data = doc.data();
        await deleteFileByUrl(data.videoUrl);
        for (const v of (data.previousVersions || [])) {
          await deleteFileByUrl(v && v.videoUrl);
        }
        await doc.ref.update({
          actorId: "deleted_user",
          actorName: "Silinmiş Kullanıcı",
          videoUrl: FieldValue.delete(),
          thumbnailUrl: FieldValue.delete(),
          previousVersions: FieldValue.delete(),
          note: FieldValue.delete(),
          optionAnswers: FieldValue.delete(),
          optionExplanation: FieldValue.delete(),
          actorDeleted: true,
          actorDeletedAt: FieldValue.serverTimestamp(),
        });
      }

      // 3. Bildirimler (alıcısı olduğu), takvim kayıtları
      const deleteQuery = async (query) => {
        const snap = await query.get();
        let batch = db.batch();
        let count = 0;
        for (const d of snap.docs) {
          batch.delete(d.ref);
          count++;
          if (count % 400 === 0) {
            await batch.commit();
            batch = db.batch();
          }
        }
        await batch.commit();
      };
      await deleteQuery(db.collection("notifications").where("recipientId", "==", uid));
      await deleteQuery(db.collection("calendar_events").where("recipientId", "==", uid));

      // 4. Sohbetler (mesajlarıyla birlikte)
      const chatsAsActor = await db.collection("chats").where("actorId", "==", uid).get();
      const chatsAsAdmin = await db.collection("chats").where("adminId", "==", uid).get();
      for (const chat of [...chatsAsActor.docs, ...chatsAsAdmin.docs]) {
        await db.recursiveDelete(chat.ref);
      }

      // 5. Kullanıcı belgesi + private alt koleksiyonu
      await db.recursiveDelete(db.collection("users").doc(uid));

      console.log(`KVKK: ${uid} kullanıcısının verileri silindi/anonimleştirildi.`);
    });

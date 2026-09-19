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

const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

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

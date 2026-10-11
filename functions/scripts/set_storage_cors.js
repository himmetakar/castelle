/**
 * Castelle — Firebase Storage bucket'ına CORS ayarını uygular.
 *
 * `gcloud` CLI kurulu olmayan makinelerde (ör. Windows'ta Google Cloud SDK
 * yüklü değilse) `gcloud storage buckets update ... --cors-file=` komutunu
 * çalıştıramazsınız. Bu script aynı işi Firebase Admin SDK üzerinden yapar
 * (firebase-admin zaten @google-cloud/storage'ı içerir, ek paket gerekmez).
 *
 * Kullanım:
 *   1) Firebase Console → Proje Ayarları (⚙️) → Hizmet Hesapları
 *      → "Yeni özel anahtar oluştur" → indirilen JSON dosyasını bu klasöre
 *      (functions/scripts) `serviceAccountKey.json` adıyla kaydedin.
 *      ÖNEMLİ: Bu dosyayı asla git'e eklemeyin / paylaşmayın.
 *   2) Aşağıdaki BUCKET_NAME değerinin doğru olduğunu kontrol edin
 *      (Firebase Console → Storage sayfasının üstünde "gs://..." olarak
 *      görünür).
 *   3) functions klasöründe çalıştırın:
 *        node scripts/set_storage_cors.js
 */
const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Firebase Console → Storage sayfasında üstte görünen gs://BUCKET_ADI
// değeriyle aynı olmalı (gs:// olmadan).
const BUCKET_NAME = 'castelle-ce64b.firebasestorage.app';

const keyPath = path.join(__dirname, 'serviceAccountKey.json');
if (!fs.existsSync(keyPath)) {
  console.error(
    'serviceAccountKey.json bulunamadı.\n' +
      'Firebase Console > Proje Ayarları > Hizmet Hesapları > "Yeni özel ' +
      'anahtar oluştur" ile indirip bu klasöre (functions/scripts) o adla kaydedin.'
  );
  process.exit(1);
}

const corsPath = path.join(__dirname, '..', '..', 'storage_cors.json');
const corsConfig = JSON.parse(fs.readFileSync(corsPath, 'utf8'));

const serviceAccount = require(keyPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: BUCKET_NAME,
});

async function main() {
  const bucket = admin.storage().bucket();
  await bucket.setMetadata({ cors: corsConfig });
  console.log(`✅ CORS ayarı uygulandı: gs://${bucket.name}`);
  const [metadata] = await bucket.getMetadata();
  console.log('Güncel CORS yapılandırması:');
  console.log(JSON.stringify(metadata.cors, null, 2));
  console.log(
    '\nflutter run -d chrome komutunu TAMAMEN yeniden başlatın (hot reload değil), ' +
      'tarayıcıda hard refresh (Ctrl+Shift+R) yapın.'
  );
}

main().catch((e) => {
  console.error('❌ Hata:', e.message);
  if (e.message.includes('does not exist')) {
    console.error(
      'BUCKET_NAME yanlış olabilir. Firebase Console > Storage sayfasındaki gs://... adresini kontrol edin.'
    );
  }
  process.exit(1);
});

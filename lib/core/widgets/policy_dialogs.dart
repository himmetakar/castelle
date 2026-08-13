import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:castelle/core/theme/app_theme.dart';

/// Castelle - Yasal Politikalar Dialogları
/// Gizlilik Politikası, Kullanım Koşulları, KVKK ve Çerez Politikası metinlerini içerir.
class PolicyDialogs {
  
  static void _showPolicyDialog({
    required BuildContext context,
    required String title,
    required List<Widget> content,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: const BorderSide(color: AppTheme.border, width: 0.5),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.accent,
            fontSize: 18,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: content,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Kapat',
              style: GoogleFonts.inter(
                color: AppTheme.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
          fontSize: 14.5,
        ),
      ),
    );
  }

  static Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: AppTheme.textSecondary,
          fontSize: 12.5,
          height: 1.5,
        ),
      ),
    );
  }

  static Widget _buildBulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Gizlilik Politikası
  static void showPrivacyPolicy(BuildContext context) {
    _showPolicyDialog(
      context: context,
      title: 'Gizlilik Politikası',
      content: [
        _buildParagraph('Son Güncelleme: 31 Temmuz 2026'),
        _buildParagraph('Castelle mobil uygulaması ("Uygulama") olarak, kullanıcılarımızın gizliliğine ve kişisel verilerinin korunmasına büyük önem veriyoruz. Bu Gizlilik Politikası, uygulamamızı kullandığınızda hangi verileri topladığımızı, bu verileri nasıl kullandığımızı ve verilerinizin güvenliğini nasıl sağladığımızı açıklamaktadır.'),
        
        _buildSectionTitle('1. Toplanan Veriler'),
        _buildParagraph('Uygulamamızı kullanırken aşağıdaki kategorilerdeki kişisel verileri toplayabiliriz:'),
        _buildBulletItem('Hesap ve Profil Bilgileri: Ad-soyad, e-posta adresi, telefon numarası, profil resmi, kullanıcı rolü ve şifre.'),
        _buildBulletItem('Oyuncu Profil Bilgileri: Fiziksel özellikler (yaş, boy, kilo, göz/saç rengi vb.), yetenekler (skills), deneyimler, fotoğraflar ve başvuru videoları (audition kayıtları).'),
        _buildBulletItem('İletişim ve Sohbet Verileri: Uygulama içi sohbet özelliği aracılığıyla gönderilen mesajlar, takvim planları ve bildirimler.'),
        
        _buildSectionTitle('2. Verilerin Kullanım Amaçları'),
        _buildParagraph('Topladığımız kişisel verileri aşağıdaki amaçlar doğrultusunda kullanıyoruz:'),
        _buildBulletItem('Uygulama hizmetlerimizin ve temel fonksiyonlarının (profil oluşturma, audition başvurusu, iş atamaları vb.) sağlanması.'),
        _buildBulletItem('Oyuncular ile iş veren/yönetmenlerin uygulama içinde iletişim kurabilmesi (sohbet ve takvim entegrasyonu).'),
        _buildBulletItem('Uygulama içi bildirimlerin iletilmesi.'),
        
        _buildSectionTitle('3. Veri Paylaşımı ve Aktarımı'),
        _buildParagraph('Kişisel verileriniz, yasal zorunluluklar veya açık rızanız haricinde üçüncü şahıslarla paylaşılmaz. Uygulamamızın altyapısı güvenli bulut servis sağlayıcısı olan Google Firebase (Firestore, Authentication, Storage, Hosting) üzerinde barındırılmaktadır.'),
        
        _buildSectionTitle('4. Veri Güvenliği'),
        _buildParagraph('Kişisel verilerinizin güvenliğini sağlamak için endüstri standardı şifreleme yöntemleri, yetkilendirme kuralları (Firestore Security Rules) ve güvenlik protokolleri uygulamaktayız.'),
      ],
    );
  }

  /// Kullanım Koşulları
  static void showTermsOfUse(BuildContext context) {
    _showPolicyDialog(
      context: context,
      title: 'Kullanım Koşulları',
      content: [
        _buildParagraph('Son Güncelleme: 31 Temmuz 2026'),
        _buildParagraph('Bu Kullanım Koşulları, Castelle mobil uygulamasını kullanan tüm kullanıcılar ile Castelle Yönetimi arasında yasal olarak bağlayıcı bir anlaşmadır. Platformu indirerek, kaydolarak veya kullanarak bu koşulları kabul etmiş olursunuz.'),
        
        _buildSectionTitle('1. Üyelik ve Hesap Güvenliği'),
        _buildParagraph('Platforma üye olurken doğru, eksiksiz ve güncel bilgiler vermeyi taahhüt edersiniz. Hesabınızın güvenliğini sağlamak ve şifrenizi gizli tutmak sizin sorumluluğunuzdadır.'),
        
        _buildSectionTitle('2. Hizmet ve Kullanım Esasları'),
        _buildBulletItem('Oyuncu Hesapları: Oyuncular profillerini eksiksiz doldurmalı, yükledikleri medya içeriklerinin telif haklarına sahip olmalıdır.'),
        _buildBulletItem('Yönetmen / İş Veren Hesapları: Proje ve audition daveti gönderirken dürüst davranmalı, oyuncu verilerini sadece casting amaçları doğrultusunda kullanmalıdır.'),
        _buildBulletItem('Ortak Kurallar: Platform içinde taciz edici, hakaret içeren veya yasa dışı paylaşımlar yapmak kesinlikle yasaktır ve hesabın kapatılmasına sebep olur.'),
        
        _buildSectionTitle('3. Sorumluluk Sınırları'),
        _buildParagraph('Castelle, oyuncular ile iş verenler arasındaki anlaşmaların veya çekim süreçlerinin garantörü değildir. Platform yalnızca bir aracı konumundadır.'),
      ],
    );
  }

  /// KVKK Aydınlatma Metni
  static void showKvkk(BuildContext context) {
    _showPolicyDialog(
      context: context,
      title: 'KVKK Aydınlatma Metni',
      content: [
        _buildParagraph('Son Güncelleme Tarihi: 13 Ağustos 2026'),
        _buildSectionTitle('1. Veri Sorumlusu'),
        _buildParagraph('6698 sayılı KVKK kapsamında veri sorumlusu: Castel TV Medya Creative Ajans Hizmetleri Ltd. Şti.\nAdres: Cemal Sururi Sokak, Gülbahar Mah. Halim Meriç İş Merkezi No: 15E, K: 5, D: 28, Mecidiyeköy, İstanbul\nE-posta: alicokartal@castelmedya.tv | Tel: 0533 817 03 79'),
        
        _buildSectionTitle('2. Castelle Nedir?'),
        _buildParagraph('Castelle; oyuncuların projeleri görüntüleyebildiği, profillerini oluşturup başvurabildiği ve deneme çekimlerine katılabildiği dijital bir platformdur.'),
        
        _buildSectionTitle('3. İşlenen Kişisel Veriler'),
        _buildBulletItem('Kimlik & İletişim: Ad-soyad, doğum tarihi, tel, e-posta, şehir.'),
        _buildBulletItem('Oyunculuk & Mesleki: Deneyim, eğitim, yetenekler, dil, fiziksel özellikler, CV, showreel, fotoğraflar, videolar.'),
        _buildBulletItem('Görüntü & Ses: Deneme çekimleri, video içerikleri, ses kayıtları.'),
        _buildBulletItem('Platform & Proje: Başvurular, deneme çekimleri, yönetmen görüşmeleri, opsiyon ve takvim bilgileri.'),
        _buildBulletItem('Teknik & Konum: IP, cihaz, log, oturum ve izinli konum verileri.'),

        _buildSectionTitle('4. Kişisel Verilerin İşlenme Amaçları'),
        _buildParagraph('Hesap yönetimi, oyuncu profil/portföyü oluşturma, projelere başvuru sağlama, audition değerlendirmesi, yapımcı/yönetmen erişimi sağlama, bilgi güvenliği ve yasal yükümlülüklerin yerine getirilmesi amaçlarıyla işlenir.'),

        _buildSectionTitle('5. Hukuki Sebepler'),
        _buildParagraph('Kanunlarda öngörülmesi, sözleşmenin ifası, veri sorumlusunun hukuki yükümlülüğü ve meşru menfaati ile açık rızanız doğrultusunda işlenmektedir.'),

        _buildSectionTitle('6. Fotoğraf, Video ve Deneme Çekimleri'),
        _buildParagraph('Yüklenen fotoğraf, video, showreel ve deneme çekimleri başvurulan projelerin değerlendirilmesi amacıyla yapımcı ve yönetmenlerle paylaşılabilir.'),

        _buildSectionTitle('7. Kamera, Mikrofon ve Konum İzinleri'),
        _buildParagraph('Deneme çekimleri ve konum tabanlı özellikler için cihaz izinleri talep edilir; işletim sisteminizden yönetilebilir.'),

        _buildSectionTitle('8. Kişisel Verilerin Aktarılması'),
        _buildParagraph('Proje sahipleri, yapımcılar, yönetmenler, teknik hizmet sağlayıcılar ve Google Firebase altyapısı (yurt dışı aktarımı dahil) ile KVKK\'ya uygun olarak paylaşılabilir.'),

        _buildSectionTitle('9. Saklama Süresi & Güvenlik'),
        _buildParagraph('Verileriniz işleme amaçlarının ve yasal sürelerin gerektirdiği süre boyunca teknik ve idari tedbirlerle muhafaza edilir.'),

        _buildSectionTitle('10. Haklarınız'),
        _buildParagraph('KVKK Madde 11 kapsamındaki haklarınız için alicokartal@castelmedya.tv adresine başvurabilirsiniz.'),
      ],
    );
  }

  /// Açık Rıza Metni
  static void showExplicitConsent(BuildContext context) {
    _showPolicyDialog(
      context: context,
      title: 'Açık Rıza Metni',
      content: [
        _buildParagraph('Son Güncelleme Tarihi: 13 Ağustos 2026'),
        _buildParagraph('Castelle tarafından sunulan Aydınlatma Metni\'ni okuduğumu ve bilgilendirildiğimi kabul ediyorum.'),

        _buildSectionTitle('1. Fotoğraf ve Görsel İçeriklerin Kullanılması'),
        _buildParagraph('Yüklediğim fotoğraf, portre, tanıtım videosu, showreel ve benzeri içeriklerin oyunculuk projelerinde değerlendirilmek üzere yapımcı, yönetmen ve yetkili sektör profesyonelleriyle paylaşılmasına açık rıza veriyorum.'),

        _buildSectionTitle('2. Deneme Çekimlerinin Paylaşılması'),
        _buildParagraph('Gerçekleştirdiğim deneme çekimlerinin başvurduğum projelerin oyuncu seçme süreçlerinde kullanılmak ve ilgili yetkili kişilerle paylaşılmak üzere işlenmesine açık rıza veriyorum.'),

        _buildSectionTitle('3. Tanıtım ve Pazarlama Amaçlı Kullanım (İsteğe Bağlı)'),
        _buildParagraph('Castelle tarafından hazırlanan tanıtım, reklam, sosyal medya ve pazarlama çalışmalarında fotoğraf, video veya profil bilgilerimin kullanılmasına açık rıza veriyorum.'),

        _buildSectionTitle('Rızanın Geri Alınması'),
        _buildParagraph('Verdiğim açık rızayı dilediğim zaman geri çekebileceğimi biliyorum.'),
      ],
    );
  }

  /// Çerez Politikası
  static void showCookiePolicy(BuildContext context) {
    _showPolicyDialog(
      context: context,
      title: 'Çerez Politikası',
      content: [
        _buildParagraph('Son Güncelleme: 31 Temmuz 2026'),
        _buildParagraph('Çerezler (Cookies), bir internet sitesini veya mobil uygulamayı ziyaret ettiğinizde cihazınıza kaydedilen küçük metin dosyalarıdır. Mobil uygulamalar ve web siteleri bu dosyaları oturum takibi ve kişiselleştirilmiş ayarlar için kullanır.'),
        
        _buildSectionTitle('1. Çerez Kullanım Amaçlarımız'),
        _buildBulletItem('Zorunlu Çerezler: Giriş yapmış olan kullanıcı oturumunuzun aktif kalmasını sağlamak ve temel güvenlik fonksiyonlarını çalıştırmak amacıyla kullanılır.'),
        _buildBulletItem('İşlevsel Çerezler: Dil tercihi, bildirim izin durumları gibi kişisel ayarlarınızı cihazınızda hatırlamak amacıyla kullanılır.'),
        _buildBulletItem('Performans Çerezleri: Uygulamanın çalışma performansını analiz etmek ve hata raporlarını (Crashlytics vb.) toplamak amacıyla kullanılır.'),
        
        _buildSectionTitle('2. Çerez Yönetimi'),
        _buildParagraph('Uygulama içi işlevlerin çalışabilmesi için oturum çerezleri zorunludur. Bunları silmeniz durumunda uygulamadan çıkış yapmış olursunuz. Reklam veya pazarlama amaçlı izleme çerezleri platformumuzda kullanılmamaktadır.'),
      ],
    );
  }
}

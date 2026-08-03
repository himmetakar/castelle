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
        _buildParagraph('Son Güncelleme: 31 Temmuz 2026'),
        _buildParagraph('6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") uyarınca, kişisel verileriniz veri sorumlusu sıfatıyla Castelle tarafından aşağıda açıklanan kapsamda işlenebilecektir.'),
        
        _buildSectionTitle('1. Kişisel Verilerinizin İşlenme Amacı'),
        _buildParagraph('Kişisel verileriniz, Castelle tarafından sunulan casting platform hizmetlerinin yürütülmesi, oyuncular ile iş veren/yönetmenlerin buluşturulması, audition kayıtlarının alınması, sözleşme süreçlerinin takibi ve yasal yükümlülüklerin yerine getirilmesi amacıyla işlenmektedir.'),
        
        _buildSectionTitle('2. İşlenen Kişisel Veriler'),
        _buildBulletItem('Kimlik ve iletişim bilgileri (Ad-soyad, telefon, e-posta)'),
        _buildBulletItem('Mesleki ve fiziksel nitelik bilgileri (yaş, boy, kilo, yetenekler, eğitim vb.)'),
        _buildBulletItem('Görsel ve işitsel kayıtlar (fotoğraflar, tanıtım ve audition videoları)'),
        
        _buildSectionTitle('3. İşlenen Kişisel Verilerin Aktarılması'),
        _buildParagraph('Kişisel verileriniz, yalnızca casting süreçlerinin yürütülmesi amacıyla platformdaki kayıtlı ve onaylı İş Veren/Yönetmen kullanıcılar ile ve bulut hizmet sağlayıcımız olan Google Firebase sunucularıyla paylaşılabilmektedir.'),
        
        _buildSectionTitle('4. KVKK Kapsamındaki Haklarınız'),
        _buildParagraph('Kanun\'un 11. maddesi uyarınca veri sahipleri kişisel verilerinin silinmesini veya düzeltilmesini talep etme hakkına sahiptir. Bu taleplerinizi casttelleyazilim@gmail.com adresine iletebilirsiniz.'),
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

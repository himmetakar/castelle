import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/features/actor/providers/actor_profile_provider.dart';

/// Castelle - Gizlilik Taahhütnamesi (NDA) Onay Dialogu
class NdaAgreementDialog extends StatefulWidget {
  final String projectId;
  final String projectTitle;

  const NdaAgreementDialog({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  /// Dialogu gösterir, onaylandıysa `true` döner
  static Future<bool> show(
    BuildContext context, {
    required String projectId,
    required String projectTitle,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (context) => NdaAgreementDialog(
        projectId: projectId,
        projectTitle: projectTitle,
      ),
    );
    return result ?? false;
  }

  @override
  State<NdaAgreementDialog> createState() => _NdaAgreementDialogState();
}

class _NdaAgreementDialogState extends State<NdaAgreementDialog> {
  bool _isAccepted = false;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst Sürükleme Çubuğu
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Başlık
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.gavel, color: AppTheme.warning, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gizlilik Taahhütnamesi',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          widget.projectTitle,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Sözleşme Metni
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
                  ),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Text(
                        '🎬 PROJE GİZLİLİK VE TAAHHÜT SÖZLEŞMESİ',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      _buildNdaParagraph(
                        '1. Taraflar ve Konu:\n'
                        'İşbu Gizlilik Taahhütnamesi, Castelle platformu üzerinden tarafıma iletilen ve detayları paylaşılan projeye (Proje) ilişkin gizli bilgilerin korunmasını taahhüt eder.',
                      ),
                      _buildNdaParagraph(
                        '2. Gizli Bilgilerin Tanımı:\n'
                        'Proje kapsamında paylaşılan senaryo, rol detayları, karakter analizleri, yapımcı/yönetmen bilgileri, çekim mekanları, bütçe, proje görselleri ve her türlü yazılı/sözlü bilgi "Gizli Bilgi" olarak kabul edilir.',
                      ),
                      _buildNdaParagraph(
                        '3. Yükümlülükler:\n'
                        '• Projeye ait hiçbir gizli bilgiyi üçüncü şahıslarla, sosyal medya mecralarında veya herhangi bir dijital/basılı platformda paylaşmamayı,\n'
                        '• Rol deneme çekimleri (audition) için hazırlanan videoları, metinleri veya diğer materyalleri yetkisiz kişilerle paylaşmamayı ve Castelle dışındaki mecralara yüklememeyi,\n'
                        '• Projenin gizliliğini ihlal edecek her türlü sızıntıyı engellemek için gerekli azami özeni göstermeyi kabul ve taahhüt ederim.',
                      ),
                      _buildNdaParagraph(
                        '4. İhlal Durumu:\n'
                        'Gizlilik yükümlülüklerinin ihlal edilmesi durumunda, projenin yapımcısı, iş veren veya Castelle yönetiminin uğrayacağı her türlü maddi ve manevi zararı tazmin etmekle yükümlü olacağımı, hakkımda yasal işlem başlatılabileceğini kabul ederim.',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Yukarıda yer alan gizlilik hükümlerini okuduğumu, anladığımı ve projeye erişebilmek için bu koşulları kayıtsız şartsız kabul ettiğimi beyan ederim.',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Onay Kutusu
              CheckboxListTile(
                value: _isAccepted,
                onChanged: _isSaving ? null : (val) => setState(() => _isAccepted = val ?? false),
                activeColor: AppTheme.accent,
                checkColor: AppTheme.textOnAccent,
                title: Text(
                  'Okudum, anladım ve gizlilik koşullarını kabul ediyorum.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 16),

              // Butonlar
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.border),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      child: Text(
                        'İptal Et',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (!_isAccepted || _isSaving) ? null : _handleAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: AppTheme.textOnAccent,
                        disabledBackgroundColor: AppTheme.surfaceElevated,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.textOnAccent,
                              ),
                            )
                          : Text(
                              'Onaylıyorum',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNdaParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: AppTheme.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }

  Future<void> _handleAccept() async {
    setState(() => _isSaving = true);
    try {
      final success = await context.read<ActorProfileProvider>().acceptNda(widget.projectId);
      if (success) {
        if (mounted) Navigator.pop(context, true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Onay kaydedilirken bir hata oluştu.'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
        setState(() => _isSaving = false);
      }
    } catch (_) {
      setState(() => _isSaving = false);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/core/theme/app_theme.dart';

/// Castelle - Hesap Silme
/// App Store 5.1.1(v) ve Google Play gereği uygulama içi kalıcı hesap silme.

void showDeleteAccountDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _DeleteAccountDialog(),
  );
}

/// Profil ekranlarına konulan "Hesabımı Sil" butonu
class DeleteAccountButton extends StatelessWidget {
  const DeleteAccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => showDeleteAccountDialog(context),
        icon: const Icon(Icons.delete_forever_outlined,
            color: AppTheme.error, size: 20),
        label: Text(
          'Hesabımı Sil',
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.error,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppTheme.error.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  bool _isDeleting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _error = 'Şifrenizi girin.');
      return;
    }

    setState(() {
      _isDeleting = true;
      _error = null;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.deleteAccount(password);

    if (!mounted) return;

    if (success) {
      // Router, auth durumu değişince giriş ekranına yönlendirir.
      Navigator.pop(context);
    } else {
      setState(() {
        _isDeleting = false;
        _error = authProvider.errorMessage ?? 'Hesap silinemedi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hesabı Kalıcı Olarak Sil'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profiliniz, fotoğraf ve videolarınız, casting başvurularınız ve '
            'bildirimleriniz kalıcı olarak silinir. Bu işlem geri alınamaz.',
            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            enabled: !_isDeleting,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(
              labelText: 'Şifreniz',
              helperText: 'Güvenlik için şifrenizi tekrar girin.',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        ElevatedButton(
          onPressed: _isDeleting ? null : _delete,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
          child: _isDeleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Hesabı Sil'),
        ),
      ],
    );
  }
}

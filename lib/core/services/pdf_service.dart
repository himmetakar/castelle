import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:castelle/core/models/actor_profile_model.dart';

class PdfService {
  static bool _useFallback = false;

  static Future<void> generateProfilePdf(ActorProfileModel actor, String path) async {
    final pdf = pw.Document();
    
    _useFallback = false;
    // Load Turkish-supporting fonts from assets
    final regularFont = await _loadFont();
    final boldFont = await _loadBoldFont();
    
    // Load profile photo bytes if available
    pw.MemoryImage? profileImage;
    if (actor.profilePhotoUrl != null && actor.profilePhotoUrl!.isNotEmpty) {
      try {
        final isLocal = !actor.profilePhotoUrl!.startsWith('http://') &&
            !actor.profilePhotoUrl!.startsWith('https://');
        if (isLocal) {
          String cleanLocalPath = actor.profilePhotoUrl!;
          if (cleanLocalPath.startsWith('file://')) {
            cleanLocalPath = Uri.parse(cleanLocalPath).toFilePath();
          }
          final file = File(cleanLocalPath);
          if (file.existsSync()) {
            profileImage = pw.MemoryImage(file.readAsBytesSync());
          }
        } else {
          final response = await http.get(Uri.parse(actor.profilePhotoUrl!)).timeout(const Duration(seconds: 4));
          if (response.statusCode == 200) {
            profileImage = pw.MemoryImage(response.bodyBytes);
          }
        }
      } catch (e) {
        debugPrint('Error loading profile image for PDF: $e');
      }
    }
    
    String cleanText(String? text) {
      if (text == null) return '';
      if (!_useFallback) return text;
      return text
          .replaceAll('ş', 's')
          .replaceAll('Ş', 'S')
          .replaceAll('ğ', 'g')
          .replaceAll('Ğ', 'G')
          .replaceAll('ı', 'i')
          .replaceAll('İ', 'I')
          .replaceAll('ç', 'c')
          .replaceAll('Ç', 'C')
          .replaceAll('ö', 'o')
          .replaceAll('Ö', 'O')
          .replaceAll('ü', 'u')
          .replaceAll('Ü', 'U');
    }

    final isBioLocked = actor.lockedSections['bio'] == true;
    final isPhysicalLocked = actor.lockedSections['physical'] == true;
    final isSkillsLocked = actor.lockedSections['skills'] == true;
    final isHobbiesLocked = actor.lockedSections['hobbies'] == true;
    final isFilmographyLocked = actor.lockedSections['filmography'] == true;
    final isSocialLocked = actor.lockedSections['social'] == true;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
        ),
        build: (pw.Context context) {
          return [
            // Header: Profile Image + Name & Location + Contact Info
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 12),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                ),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Profil Resmi
                  if (profileImage != null) ...[
                    pw.Container(
                      width: 80,
                      height: 80,
                      decoration: pw.BoxDecoration(
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                        border: pw.Border.all(color: PdfColors.amber800, width: 1.5),
                      ),
                      child: pw.ClipRRect(
                        horizontalRadius: 6,
                        verticalRadius: 6,
                        child: pw.Image(profileImage, fit: pw.BoxFit.cover),
                      ),
                    ),
                    pw.SizedBox(width: 16),
                  ],
                  // İsim ve Lokasyon + İletişim Bilgileri
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          cleanText(actor.fullName),
                          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          cleanText('${actor.city ?? "Belirtilmedi"} / ${actor.country ?? "Turkiye"}'),
                          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                        ),
                        pw.SizedBox(height: 8),
                        if (!isBioLocked) ...[
                          pw.Text(
                            'E-posta: ${cleanText(actor.email)}',
                            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Castelle Logo / Başlık
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'CASTELLE',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.amber800),
                      ),
                      pw.Text(
                        'Oyuncu Profil Karti',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 16),

            // Hakkımda / Bio
            if (!isBioLocked && actor.bio != null && actor.bio!.isNotEmpty) ...[
              pw.Text(
                'Hakkinda',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                cleanText(actor.bio!),
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.4),
              ),
              pw.SizedBox(height: 16),
            ],

            // Fiziksel Özellikler
            if (!isPhysicalLocked) ...[
              pw.Text(
                'Fiziksel Ozellikler',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                border: null,
                headers: ['Ozellik', 'Deger'],
                data: [
                  ['Yas', actor.age?.toString() ?? 'Belirtilmedi'],
                  ['Boy', actor.heightCm != null ? '${actor.heightCm} cm' : 'Belirtilmedi'],
                  ['Kilo', actor.weightKg != null ? '${actor.weightKg} kg' : 'Belirtilmedi'],
                  ['Cinsiyet', cleanText(actor.gender?.displayName) ?? 'Belirtilmedi'],
                  ['Goz Rengi', cleanText(actor.eyeColor?.displayName) ?? 'Belirtilmedi'],
                  ['Sac Rengi', cleanText(actor.hairColor?.displayName) ?? 'Belirtilmedi'],
                ].map((row) => [cleanText(row[0]), cleanText(row[1])]).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.SizedBox(height: 16),
            ],



            // Filmografi
            if (!isFilmographyLocked && actor.filmography.isNotEmpty) ...[
              pw.Text(
                'Filmografi / Deneyim',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                border: const pw.TableBorder(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                ),
                headers: ['Yil', 'Proje', 'Tur', 'Yonetmen'],
                data: actor.filmography.map((f) => [
                  cleanText(f['year']?.toString()),
                  cleanText(f['projectTitle']?.toString()),
                  cleanText(f['projectType']?.toString()),
                  cleanText(f['director']?.toString()),
                ]).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.SizedBox(height: 16),
            ],

            // Sosyal Medya
            if (!isSocialLocked && (actor.instagramHandle != null || actor.tiktokHandle != null || actor.xHandle != null || actor.youtubeChannel != null || actor.imdbLink != null)) ...[
              pw.Text(
                'Sosyal Medya Linkleri',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900),
              ),
              pw.SizedBox(height: 6),
              if (actor.instagramHandle != null && actor.instagramHandle!.isNotEmpty)
                pw.Bullet(text: 'Instagram: ${cleanText(actor.instagramHandle)}'),
              if (actor.tiktokHandle != null && actor.tiktokHandle!.isNotEmpty)
                pw.Bullet(text: 'TikTok: ${cleanText(actor.tiktokHandle)}'),
              if (actor.xHandle != null && actor.xHandle!.isNotEmpty)
                pw.Bullet(text: 'X (Twitter): ${cleanText(actor.xHandle)}'),
              if (actor.youtubeChannel != null && actor.youtubeChannel!.isNotEmpty)
                pw.Bullet(text: 'YouTube: ${cleanText(actor.youtubeChannel)}'),
              if (actor.imdbLink != null && actor.imdbLink!.isNotEmpty)
                pw.Bullet(text: 'IMDb: ${cleanText(actor.imdbLink)}'),
            ],
          ];
        },
      ),
    );

    final file = File(path);
    await file.writeAsBytes(await pdf.save());
  }

  static Future<pw.Font> _loadFont() async {
    try {
      final bytes = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      return pw.Font.ttf(bytes);
    } catch (e) {
      debugPrint('Error loading regular font: $e');
    }
    _useFallback = true;
    return pw.Font.helvetica();
  }

  static Future<pw.Font> _loadBoldFont() async {
    try {
      final bytes = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      return pw.Font.ttf(bytes);
    } catch (e) {
      debugPrint('Error loading bold font: $e');
    }
    _useFallback = true;
    return pw.Font.helveticaBold();
  }
}

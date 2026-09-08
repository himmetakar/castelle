# App Review Reply — Submission e7d83d09-5d3b-49d5-a752-8b88ab8d9c9f

Paste into App Store Connect → Resolution Center.

---

Hello,

Thank you for the detailed review. We have addressed both issues in the new build.

**Guideline 5.1.1(v) — Phone number required**

The phone number field at registration is no longer required. It is now an optional field, labeled "Telefon (isteğe bağlı)" ("Phone (optional)") with helper text explaining that it is only used so the casting team can contact the user about a role. Registration completes successfully with the field left empty, and no other part of the app blocks access when it is missing.

No other personal information is required to create an account. Registration asks only for full name, email address, and password.

**Guideline 5.1.1(v) — Account deletion**

In-app account deletion has been added. It is a permanent deletion, not a deactivation.

Path to the option:

1. Sign in.
2. Open the **Profil** tab in the bottom navigation bar.
3. Scroll to the bottom of the profile screen.
4. Tap **"Hesabımı Sil"** ("Delete My Account").
5. A confirmation dialog explains exactly what will be deleted and asks the user to re-enter their password.
6. Tap **"Hesabı Sil"** ("Delete Account"). The account is deleted and the app returns to the sign-in screen.

What the flow deletes:

- The Firebase Authentication account (the user can no longer sign in, and the email address is released for reuse)
- The user's profile document, including all personal details, physical attributes, and bank information
- All uploaded photos and videos in Firebase Storage
- All casting audition submissions made by the user
- All notifications addressed to the user

No customer service contact, email, phone call, or website visit is required at any point. The password prompt is only there to prevent accidental deletion on an unattended device, as permitted by the guideline.

**Demo account**

Email: actor@castelle.com
Password: Castelle2024!

Please note: this shared demo account is re-provisioned automatically so that it stays available for future reviews. To see the deletion flow end to end without that interfering, we recommend registering a new account with any email address and deleting that one — registration takes only a few seconds and requires no email verification.

A screen recording captured on a physical device, showing account creation, navigation to the deletion option, and the complete deletion flow through to confirmation, is available here:

https://drive.google.com/file/d/1BtESWmUEflkGoZinX_y2XKzJFUJJD5uo/view?usp=sharing

The same link has been added to the Notes field in App Review Information.

Thank you,
Castelle Team

---

## Before sending — checklist

- [ ] `firebase deploy --only firestore:rules` (deletion fails with permission-denied without this)
- [ ] **Kaydı yeniden çek.** Linkteki mevcut video (47 sn) admin panelini geziyor: admin girişi → Kullanıcı Yönetimi → Demo Admin profili → Oyuncu Havuzu → Oyuncu Profili. Hesap silme akışı hiç yok, hatta admin profil ekranındaki Ayarlar listesinde "Hesabımı Sil" görünmüyor (güncelleme öncesi build). Bu haliyle gönderilirse Apple aynı maddeden tekrar reddeder.
- [ ] Yeni kaydı **fiziksel** iPhone/iPad'de çek — Apple açıkça cihaz kaydı istiyor, simulator kaydı reddedilir
- [ ] Drive linkinin erişimi "bağlantıya sahip olan herkes" olmalı — inceleme ekibi Google hesabıyla giriş yapmaz
- [ ] Recording must show, in one take: register a new account → navigate to Profil → tap Hesabımı Sil → password → confirm → returned to sign-in
- [ ] Paste the recording (or its link) into App Store Connect → App Review Information → Notes
- [ ] Confirm registration succeeds with the phone field left blank
- [ ] Test on iPad — Apple reviewed on iPad Air 11-inch (M3)

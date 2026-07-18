import 'package:flutter/material.dart';
import 'package:castelle/core/models/actor_profile_model.dart';
import 'package:castelle/features/actor/screens/actor_cv_view_screen.dart';

/// Castelle - Oyuncu Detay Ekranı
/// Admin/Moderatör/Yönetmen/İş Veren için oyuncu profili detay görünümü
class ActorDetailScreen extends StatelessWidget {
  final ActorProfileModel actor;

  const ActorDetailScreen({super.key, required this.actor});

  @override
  Widget build(BuildContext context) {
    return ActorCvViewScreen(isOwner: false, actor: actor);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/theme/extension.dart';
import '../data/models.dart';

/// Picks a stable, pleasant colour for a member without a photo.
Color avatarColor(String id, ColorScheme scheme) {
  const hues = [12.0, 35.0, 95.0, 160.0, 195.0, 220.0, 265.0, 320.0];
  final hue = hues[id.hashCode.abs() % hues.length];
  final dark = scheme.brightness == Brightness.dark;
  return HSLColor.fromAHSL(1, hue, 0.45, dark ? 0.35 : 0.55).toColor();
}

class MemberAvatar extends ConsumerWidget {
  const MemberAvatar({
    required this.memberId,
    super.key,
    this.radius = 22,
    this.showPresence = false,
  });

  final String memberId;
  final double radius;
  final bool showPresence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(memberProvider(memberId));
    final online = showPresence && ref.watch(onlineProvider).contains(memberId);
    return PresenceBadge(
      online: online,
      radius: radius,
      child: AvatarCircle(member: member, id: memberId, radius: radius),
    );
  }
}

class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    required this.member,
    required this.id,
    super.key,
    this.radius = 22,
  });

  final Member? member;
  final String id;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final avatar = member?.avatar;
    if (avatar != null) {
      return CircleAvatar(radius: radius, backgroundImage: MemoryImage(avatar));
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: avatarColor(id, context.colorScheme),
      child: Text(
        member?.initials ?? '?',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}

class PresenceBadge extends StatelessWidget {
  const PresenceBadge({
    required this.online,
    required this.radius,
    required this.child,
    super.key,
  });

  final bool online;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!online) return child;
    final size = radius * 0.55;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFF2EB872),
              shape: BoxShape.circle,
              border: Border.all(color: context.colorScheme.surface, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Avatar for any conversation: the family / group icon or the peer's photo.
class ConversationAvatar extends ConsumerWidget {
  const ConversationAvatar({
    required this.conversation,
    super.key,
    this.radius = 26,
  });

  final Conversation conversation;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    switch (conversation.type) {
      case ConversationType.direct:
        final peer = conversation.peerOf(ref.watch(myIdProvider));
        return MemberAvatar(
          memberId: peer ?? '',
          radius: radius,
          showPresence: true,
        );
      case ConversationType.family:
      case ConversationType.group:
        final family = conversation.type == ConversationType.family;
        return CircleAvatar(
          radius: radius,
          backgroundColor: family
              ? scheme.primaryContainer
              : scheme.tertiaryContainer,
          child: Icon(
            family ? Icons.home_rounded : Icons.groups_rounded,
            size: radius,
            color: family
                ? scheme.onPrimaryContainer
                : scheme.onTertiaryContainer,
          ),
        );
    }
  }
}

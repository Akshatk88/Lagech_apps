import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/result.dart';
import '../../../../core/services/app_messenger.dart';
import '../../../auth/application/auth_controller.dart';
import '../../data/profile_repository.dart';

/// Profile picture with a pencil badge: tap to pick from camera/gallery and
/// upload it as the partner's profile photo.
class EditableProfileAvatar extends ConsumerStatefulWidget {
  const EditableProfileAvatar({super.key, required this.photoUrl, this.radius = 30});

  final String? photoUrl;
  final double radius;

  @override
  ConsumerState<EditableProfileAvatar> createState() => _EditableProfileAvatarState();
}

class _EditableProfileAvatarState extends ConsumerState<EditableProfileAvatar> {
  final _picker = ImagePicker();
  bool _uploading = false;
  File? _localPreview;

  Future<void> _choose() async {
    if (_uploading) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 45,
        maxWidth: 400,
        maxHeight: 400,
      );
      if (picked == null || !mounted) return;

      final file = File(picked.path);
      setState(() {
        _localPreview = file;
        _uploading = true;
      });

      final bytes = await file.readAsBytes();
      final result = await ref
          .read(profileRepositoryProvider)
          .uploadProfilePhotoBase64(base64Encode(bytes));
      if (!mounted) return;

      result.when(
        success: (_) {
          ref.read(authControllerProvider.notifier).checkAuthStatus();
          showAppMessage('Profile photo updated.');
        },
        failure: (error) {
          setState(() => _localPreview = null);
          showAppMessage(error.message);
        },
      );
    } catch (_) {
      if (mounted) setState(() => _localPreview = null);
      showAppMessage('Could not update the photo. Please try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.photoUrl;
    final hasUrl = url != null && url.isNotEmpty;
    final ImageProvider? image = _localPreview != null
        ? FileImage(_localPreview!)
        : (hasUrl ? NetworkImage(AppConstants.resolveMediaUrl(url)) : null);

    return GestureDetector(
      onTap: _choose,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: widget.radius.r,
            backgroundColor: Colors.grey[200],
            backgroundImage: image,
            child: image == null ? Icon(Icons.person, color: Colors.grey[500]) : null,
          ),
          if (_uploading)
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black38,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(18),
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.edit, size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

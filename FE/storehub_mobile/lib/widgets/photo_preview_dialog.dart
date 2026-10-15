import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/constants/app_colors.dart';

/// Shows a full-screen or enlarged preview of a photo.
void showPhotoPreview(BuildContext context, String imageUrl, {String? title}) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          InteractiveViewer(
            clipBehavior: Clip.none,
            maxScale: 4.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 300,
                    width: double.infinity,
                    color: Colors.black45,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  width: double.infinity,
                  color: Colors.black54,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, color: Colors.white70, size: 48),
                      SizedBox(height: 8),
                      Text('Could not load image',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
          if (title != null && title.isNotEmpty)
            Positioned(
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Displays a row/wrap of image URLs as clickable thumbnails with photo preview.
class PhotoThumbnailGrid extends StatelessWidget {
  final List<String> photos;
  final double size;

  const PhotoThumbnailGrid({
    super.key,
    required this.photos,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: photos.map((url) {
        return GestureDetector(
          onTap: () => showPhotoPreview(context, url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.outline.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: AppColors.surfaceContainerLow,
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.surfaceContainerLow,
                  child: const Icon(Icons.broken_image,
                      size: 24, color: AppColors.onSurfaceVariant),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// A picker widget that lets users snap a photo with Camera or pick from Gallery,
/// displaying selected local photos with delete buttons.
class EvidencePhotoPicker extends StatelessWidget {
  final List<File> selectedFiles;
  final ValueChanged<List<File>> onFilesChanged;
  final bool enabled;

  const EvidencePhotoPicker({
    super.key,
    required this.selectedFiles,
    required this.onFilesChanged,
    this.enabled = true,
  });

  Future<void> _pickFromCamera(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked != null) {
        final updated = List<File>.from(selectedFiles)..add(File(picked.path));
        onFilesChanged(updated);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access camera: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final pickedList = await picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (pickedList.isNotEmpty) {
        final updated = List<File>.from(selectedFiles);
        for (final item in pickedList) {
          updated.add(File(item.path));
        }
        onFilesChanged(updated);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access gallery: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: enabled ? () => _pickFromCamera(context) : null,
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Take Photo'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: enabled ? () => _pickFromGallery(context) : null,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Gallery'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        if (selectedFiles.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: selectedFiles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final file = selectedFiles[index];
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.outline.withValues(alpha: 0.4),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Image.file(
                          file,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    if (enabled)
                      Positioned(
                        top: -6,
                        right: -6,
                        child: GestureDetector(
                          onTap: () {
                            final updated = List<File>.from(selectedFiles)
                              ..removeAt(index);
                            onFilesChanged(updated);
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';

class Artwork {
  const Artwork({
    required this.id,
    required this.title,
    required this.category,
    required this.imageUrl,
    required this.ageGroup,
    required this.progressId,
    required this.sortOrder,
    this.isPremium = false,
    this.isNew = false,
  });

  final String id;
  final String title;
  final String category;
  final String imageUrl;
  final String ageGroup;
  final String progressId;
  final int sortOrder;
  final bool isPremium;
  final bool isNew;

  factory Artwork.fromJson(Map<String, dynamic> json, {required Uri manifestUri}) {
    final rawImage = (json['image_url'] ?? json['image'] ?? '').toString().trim();
    final resolvedImage = rawImage.isEmpty ? '' : manifestUri.resolve(rawImage).toString();
    final id = (json['id'] ?? json['progress_id'] ?? '').toString().trim();
    return Artwork(
      id: id,
      title: (json['title'] ?? id).toString(),
      category: (json['category'] ?? 'Other').toString(),
      imageUrl: resolvedImage,
      ageGroup: _normalizeAgeGroup((json['age_group'] ?? 'Kids').toString()),
      progressId: (json['progress_id'] ?? id).toString(),
      sortOrder: _asInt(json['sort_order']),
      isPremium: _asBool(json['premium']),
      isNew: _asBool(json['new']),
    );
  }

  static String _normalizeAgeGroup(String value) {
    switch (value.trim().toLowerCase()) {
      case 'kid':
      case 'kids':
      case 'child':
      case 'children':
        return 'Kids';
      case 'teen':
      case 'teens':
        return 'Teens';
      case 'adult':
      case 'adults':
        return 'Adults';
      default:
        return value.trim().isEmpty ? 'Kids' : value.trim();
    }
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

const Color huePopPurple = Color(0xFF6D45D8);
const Color huePopPink = Color(0xFFFF4FA3);
const Color huePopTeal = Color(0xFF16B8B1);
const Color huePopGold = Color(0xFFFFBE3D);

import 'package:flutter/material.dart';

class Artwork {
  const Artwork({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.collection,
    required this.ageGroup,
    required this.progressId,
    required this.sortOrder,
    this.isPremium = false,
    this.isNew = false,
  });

  final String id;
  final String title;
  final String imageUrl;
  final String collection;
  final String ageGroup;
  final String progressId;
  final int sortOrder;
  final bool isPremium;
  final bool isNew;

  factory Artwork.fromJson(Map<String, dynamic> json, {required Uri catalogUri}) {
    final rawImage = (json['image_url'] ?? '').toString().trim();
    final resolved = catalogUri.resolve(rawImage).toString();
    final rawAge = (json['age_group'] ?? 'All').toString().trim();
    final age = rawAge.isEmpty
        ? 'All'
        : '${rawAge[0].toUpperCase()}${rawAge.substring(1).toLowerCase()}';
    return Artwork(
      id: (json['id'] ?? json['progress_id'] ?? resolved).toString(),
      title: (json['title'] ?? 'Untitled Artwork').toString(),
      imageUrl: resolved,
      collection: (json['category'] ?? 'Other').toString(),
      ageGroup: age,
      progressId: (json['progress_id'] ?? json['id'] ?? '').toString(),
      sortOrder: (json['sort_order'] is num) ? (json['sort_order'] as num).toInt() : 0,
      isPremium: json['premium'] == true || json['premium']?.toString().toLowerCase() == 'true',
      isNew: json['new'] == true || json['new']?.toString().toLowerCase() == 'true',
    );
  }
}

const Color huePopPurple = Color(0xFF6D45D8);
const Color huePopPink = Color(0xFFFF4FA3);
const Color huePopTeal = Color(0xFF16B8B1);
const Color huePopGold = Color(0xFFFFBE3D);

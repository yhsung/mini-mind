/// Color and FontWeight converters for JSON serialization
///
/// Converts Flutter Color and FontWeight objects to/from JSON-serializable values.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

/// JSON converter for Color objects
class ColorConverter implements JsonConverter<Color, int> {
  const ColorConverter();

  @override
  Color fromJson(int json) => Color(json);

  @override
  int toJson(Color object) => object.value;
}

/// JSON converter for nullable Color objects
class ColorConverterNullable implements JsonConverter<Color?, int?> {
  const ColorConverterNullable();

  @override
  Color? fromJson(int? json) => json != null ? Color(json) : null;

  @override
  int? toJson(Color? object) => object?.value;
}

/// JSON converter for FontWeight objects
class FontWeightConverter implements JsonConverter<FontWeight, int> {
  const FontWeightConverter();

  @override
  FontWeight fromJson(int json) {
    switch (json) {
      case 100: return FontWeight.w100;
      case 200: return FontWeight.w200;
      case 300: return FontWeight.w300;
      case 400: return FontWeight.w400;
      case 500: return FontWeight.w500;
      case 600: return FontWeight.w600;
      case 700: return FontWeight.w700;
      case 800: return FontWeight.w800;
      case 900: return FontWeight.w900;
      default: return FontWeight.w400;
    }
  }

  @override
  int toJson(FontWeight object) => object.value;
}

/// JSON converter for EdgeInsets objects
class EdgeInsetsConverter implements JsonConverter<EdgeInsets, Map<String, double>> {
  const EdgeInsetsConverter();

  @override
  EdgeInsets fromJson(Map<String, double> json) => EdgeInsets.only(
    left: json['left'] ?? 0.0,
    top: json['top'] ?? 0.0,
    right: json['right'] ?? 0.0,
    bottom: json['bottom'] ?? 0.0,
  );

  @override
  Map<String, double> toJson(EdgeInsets object) => {
    'left': object.left,
    'top': object.top,
    'right': object.right,
    'bottom': object.bottom,
  };
}
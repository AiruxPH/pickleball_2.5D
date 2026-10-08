import 'package:flutter/material.dart';

/// Represents 1 or 2 rectangle slices for rendering a 360-degree panorama
/// with horizontal boundary wrapping.
class PanoramaSlice {
  final Rect firstSrc;
  final Rect firstDst;
  final Rect? wrapSrc;
  final Rect? wrapDst;

  const PanoramaSlice({
    required this.firstSrc,
    required this.firstDst,
    this.wrapSrc,
    this.wrapDst,
  });

  bool get hasWrap => wrapSrc != null && wrapDst != null;
}

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

Uint8List createWavHeader({
  required int sampleRate,
  required int numChannels,
  required int bitsPerSample,
  required int dataLength,
}) {
  final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
  final blockAlign = numChannels * (bitsPerSample ~/ 8);
  final buffer = ByteData(44);

  // "RIFF"
  buffer.setUint8(0, 0x52);
  buffer.setUint8(1, 0x49);
  buffer.setUint8(2, 0x46);
  buffer.setUint8(3, 0x46);
  buffer.setUint32(4, 36 + dataLength, Endian.little);
  // "WAVE"
  buffer.setUint8(8, 0x57);
  buffer.setUint8(9, 0x41);
  buffer.setUint8(10, 0x56);
  buffer.setUint8(11, 0x45);
  // "fmt "
  buffer.setUint8(12, 0x66);
  buffer.setUint8(13, 0x6D);
  buffer.setUint8(14, 0x74);
  buffer.setUint8(15, 0x20);
  buffer.setUint32(16, 16, Endian.little); // Subchunk1Size
  buffer.setUint16(20, 1, Endian.little);  // AudioFormat (PCM)
  buffer.setUint16(22, numChannels, Endian.little);
  buffer.setUint32(24, sampleRate, Endian.little);
  buffer.setUint32(28, byteRate, Endian.little);
  buffer.setUint16(32, blockAlign, Endian.little);
  buffer.setUint16(34, bitsPerSample, Endian.little);
  // "data"
  buffer.setUint8(36, 0x64);
  buffer.setUint8(37, 0x61);
  buffer.setUint8(38, 0x74);
  buffer.setUint8(39, 0x61);
  buffer.setUint32(40, dataLength, Endian.little);

  return buffer.buffer.asUint8List();
}

Uint8List generatePaddleHitWav() {
  const sampleRate = 44100;
  const duration = 0.10; // 100ms
  final numSamples = (sampleRate * duration).toInt();
  final data = ByteData(numSamples * 2);
  final rng = math.Random(42);

  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    // Frequency sweep from 980Hz down to 260Hz
    final freq = 260.0 + 720.0 * math.exp(-t * 60.0);
    final tone = math.sin(2 * math.pi * freq * t);
    // Hollow body resonance at 420Hz
    final resonance = math.sin(2 * math.pi * 420.0 * t) * 0.4;
    // Transient contact click/noise in first 10ms
    final noise = (t < 0.012 ? (rng.nextDouble() * 2 - 1) * math.exp(-t * 300) : 0.0);
    // Fast exponential decay envelope
    final env = math.exp(-t * 42.0);
    final sample = (tone * 0.65 + resonance * 0.35 + noise * 0.5) * env;
    final clamped = (sample.clamp(-1.0, 1.0) * 32767).toInt();
    data.setInt16(i * 2, clamped, Endian.little);
  }

  final header = createWavHeader(
    sampleRate: sampleRate,
    numChannels: 1,
    bitsPerSample: 16,
    dataLength: data.lengthInBytes,
  );

  final out = Uint8List(header.length + data.lengthInBytes);
  out.setRange(0, header.length, header);
  out.setRange(header.length, out.length, data.buffer.asUint8List());
  return out;
}

Uint8List generateSmashWav() {
  const sampleRate = 44100;
  const duration = 0.18; // 180ms
  final numSamples = (sampleRate * duration).toInt();
  final data = ByteData(numSamples * 2);
  final rng = math.Random(1337);

  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    // Heavy downward pitch dive from 1400Hz to 120Hz
    final freq = 120.0 + 1280.0 * math.exp(-t * 40.0);
    final tone = math.sin(2 * math.pi * freq * t);
    // Sub-bass impact thud
    final sub = math.sin(2 * math.pi * 95.0 * t) * 0.6;
    // Crack burst
    final crack = (t < 0.02 ? (rng.nextDouble() * 2 - 1) * math.exp(-t * 200) : 0.0);
    final env = math.exp(-t * 25.0);
    final sample = (tone * 0.6 + sub * 0.4 + crack * 0.7) * env;
    final clamped = (sample.clamp(-1.0, 1.0) * 32767).toInt();
    data.setInt16(i * 2, clamped, Endian.little);
  }

  final header = createWavHeader(
    sampleRate: sampleRate,
    numChannels: 1,
    bitsPerSample: 16,
    dataLength: data.lengthInBytes,
  );

  final out = Uint8List(header.length + data.lengthInBytes);
  out.setRange(0, header.length, header);
  out.setRange(header.length, out.length, data.buffer.asUint8List());
  return out;
}

Uint8List generateBounceWav() {
  const sampleRate = 44100;
  const duration = 0.065; // 65ms
  final numSamples = (sampleRate * duration).toInt();
  final data = ByteData(numSamples * 2);

  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    final freq = 380.0 + 320.0 * math.exp(-t * 80.0);
    final tone = math.sin(2 * math.pi * freq * t);
    final env = math.exp(-t * 65.0);
    final sample = tone * env;
    final clamped = (sample.clamp(-1.0, 1.0) * 32767).toInt();
    data.setInt16(i * 2, clamped, Endian.little);
  }

  final header = createWavHeader(
    sampleRate: sampleRate,
    numChannels: 1,
    bitsPerSample: 16,
    dataLength: data.lengthInBytes,
  );

  final out = Uint8List(header.length + data.lengthInBytes);
  out.setRange(0, header.length, header);
  out.setRange(header.length, out.length, data.buffer.asUint8List());
  return out;
}

Uint8List generateButtonClickWav() {
  const sampleRate = 44100;
  const duration = 0.035; // 35ms
  final numSamples = (sampleRate * duration).toInt();
  final data = ByteData(numSamples * 2);

  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    final freq = 1200.0 + 1000.0 * math.exp(-t * 120.0);
    final tone = math.sin(2 * math.pi * freq * t);
    final env = math.exp(-t * 110.0);
    final sample = tone * env;
    final clamped = (sample.clamp(-1.0, 1.0) * 32767).toInt();
    data.setInt16(i * 2, clamped, Endian.little);
  }

  final header = createWavHeader(
    sampleRate: sampleRate,
    numChannels: 1,
    bitsPerSample: 16,
    dataLength: data.lengthInBytes,
  );

  final out = Uint8List(header.length + data.lengthInBytes);
  out.setRange(0, header.length, header);
  out.setRange(header.length, out.length, data.buffer.asUint8List());
  return out;
}

void main() {
  final audioDir = Directory('assets/audio');
  if (!audioDir.existsSync()) {
    audioDir.createSync(recursive: true);
  }

  File('assets/audio/hit.wav').writeAsBytesSync(generatePaddleHitWav());
  File('assets/audio/smash.wav').writeAsBytesSync(generateSmashWav());
  File('assets/audio/bounce.wav').writeAsBytesSync(generateBounceWav());
  File('assets/audio/button_click.wav').writeAsBytesSync(generateButtonClickWav());

  // Also write .mp3 versions for fallback compatibility
  File('assets/audio/hit.mp3').writeAsBytesSync(generatePaddleHitWav());
  File('assets/audio/smash.mp3').writeAsBytesSync(generateSmashWav());
  File('assets/audio/bounce.mp3').writeAsBytesSync(generateBounceWav());
  File('assets/audio/button_click.mp3').writeAsBytesSync(generateButtonClickWav());

  // ignore: avoid_print
  print('Successfully generated audio assets in assets/audio/!');
}


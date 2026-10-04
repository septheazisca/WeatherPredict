// Widget test untuk WeatherPredict.
//
// Menguji tampilan awal aplikasi: form input harus muncul dengan
// dua field (kecepatan angin dan kelembapan) serta tombol prediksi.
//
// Catatan: tidak memakai pumpAndSettle karena aplikasi memakai animasi
// `_floatController.repeat()`, yang tidak pernah "diam". Selalu pakai
// pump(Duration) eksplisit.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:weather_predict/main.dart';

void main() {
  Future<void> tapPredict(WidgetTester tester) async {
    final button = find.text('PREDIKSI CUACA');
    await tester.ensureVisible(button);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('Tampilan awal menampilkan form input',
      (WidgetTester tester) async {
    await tester.pumpWidget(const WeatherPredictApp());

    expect(find.text('WeatherPredict'), findsOneWidget);
    expect(find.text('Kecepatan Angin'), findsOneWidget);
    expect(find.text('Kelembapan'), findsOneWidget);
    expect(find.text('PREDIKSI CUACA'), findsOneWidget);
  });

  testWidgets('Input kosong menampilkan pesan error',
      (WidgetTester tester) async {
    await tester.pumpWidget(const WeatherPredictApp());

    await tapPredict(tester);

    expect(find.textContaining('harus diisi'), findsOneWidget);
  });

  testWidgets('Kelembapan di atas 100 ditolak sebelum memanggil API',
      (WidgetTester tester) async {
    await tester.pumpWidget(const WeatherPredictApp());

    await tester.enterText(
        find.widgetWithText(TextField, 'Kecepatan Angin'), '10');
    await tester.enterText(
        find.widgetWithText(TextField, 'Kelembapan'), '120');
    await tapPredict(tester);

    expect(find.textContaining('0-100'), findsOneWidget);
  });

  testWidgets('Angin negatif ditolak sebelum memanggil API',
      (WidgetTester tester) async {
    await tester.pumpWidget(const WeatherPredictApp());

    await tester.enterText(
        find.widgetWithText(TextField, 'Kecepatan Angin'), '-5');
    await tester.enterText(
        find.widgetWithText(TextField, 'Kelembapan'), '70');
    await tapPredict(tester);

    expect(find.textContaining('tidak boleh kurang dari 0'), findsOneWidget);
  });

  testWidgets('Animasi loading tampil minimal 1 detik',
      (WidgetTester tester) async {
    await tester.pumpWidget(const WeatherPredictApp());

    await tester.enterText(
        find.widgetWithText(TextField, 'Kecepatan Angin'), '10');
    await tester.enterText(
        find.widgetWithText(TextField, 'Kelembapan'), '50');

    // Tekan tombol tanpa menunggu, supaya waktu loading terukur bersih.
    final button = find.text('PREDIKSI CUACA');
    await tester.ensureVisible(button);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(button);
    await tester.pump();

    // Spinner dan teks MEMPROSES langsung tampil setelah tombol ditekan.
    expect(find.text('MEMPROSES'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Pada detik ke-0.9 masih loading.
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('MEMPROSES'), findsOneWidget);

    // Pada detik ke-1.3 selesai, spinner hilang dan tombol kembali normal.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('MEMPROSES'), findsNothing);
    expect(find.text('PREDIKSI CUACA'), findsOneWidget);
  });
}
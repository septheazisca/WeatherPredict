import 'package:flutter/material.dart';
import 'api_service.dart';

void main() {
  runApp(const WeatherPredictApp());
}

/// Status tampilan aplikasi
enum WeatherStatus { initial, cerah, berawan, berpotensiHujan, hujan, error }

/// Tema visual untuk tiap status
class WeatherTheme {
  final List<Color> gradient;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color accent;

  const WeatherTheme({
    required this.gradient,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.accent,
  });
}

const Map<WeatherStatus, WeatherTheme> weatherThemes = {
  // Tampilan awal (belum ada input)
  WeatherStatus.initial: WeatherTheme(
    gradient: [Color(0xFF4FACFE), Color(0xFF3A7BD5), Color(0xFF2B5CB8)],
    icon: Icons.cloud_queue_rounded,
    iconColor: Colors.white,
    title: 'Prediksi Kondisi Cuaca',
    subtitle:
        'Masukkan kecepatan angin dan kelembapan untuk mendapatkan prediksi cuaca.',
    accent: Color(0xFF2B5CB8),
  ),
  // Cerah
  WeatherStatus.cerah: WeatherTheme(
    gradient: [Color(0xFFFFD452), Color(0xFFFF9A44), Color(0xFFFC6076)],
    icon: Icons.wb_sunny_rounded,
    iconColor: Color(0xFFFFF59D),
    title: 'Cerah',
    subtitle: 'Kondisi cuaca cenderung cerah.',
    accent: Color(0xFFE8590C),
  ),
  // Berawan
  WeatherStatus.berawan: WeatherTheme(
    gradient: [Color(0xFF9CB5CC), Color(0xFF6E8CA8), Color(0xFF4A6580)],
    icon: Icons.cloud_rounded,
    iconColor: Colors.white,
    title: 'Berawan',
    subtitle: 'Kondisi cuaca cenderung berawan.',
    accent: Color(0xFF4A6580),
  ),
  // Berpotensi hujan
  WeatherStatus.berpotensiHujan: WeatherTheme(
    gradient: [Color(0xFF7F8FA9), Color(0xFF55678A), Color(0xFF354564)],
    icon: Icons.grain_rounded,
    iconColor: Color(0xFFB3E5FC),
    title: 'Berpotensi Hujan',
    subtitle: 'Kondisi cuaca berpotensi mengalami hujan.',
    accent: Color(0xFF354564),
  ),
  // Hujan
  WeatherStatus.hujan: WeatherTheme(
    gradient: [Color(0xFF1E3C72), Color(0xFF1A2A55), Color(0xFF0F1735)],
    icon: Icons.thunderstorm_rounded,
    iconColor: Color(0xFF81D4FA),
    title: 'Hujan',
    subtitle: 'Kondisi cuaca diprediksi hujan.',
    accent: Color(0xFF1E3C72),
  ),
  // Error
  WeatherStatus.error: WeatherTheme(
    gradient: [Color(0xFFFF6B6B), Color(0xFFC62E4D), Color(0xFF6D1A36)],
    icon: Icons.error_outline_rounded,
    iconColor: Colors.white,
    title: 'Terjadi Kesalahan',
    subtitle: '',
    accent: Color(0xFFC62E4D),
  ),
};

class WeatherPredictApp extends StatelessWidget {
  const WeatherPredictApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WeatherPredict',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const WeatherHomePage(),
    );
  }
}

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController windController = TextEditingController();
  final TextEditingController humidityController = TextEditingController();

  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;

  bool isLoading = false;

  WeatherStatus status = WeatherStatus.initial;
  String? condition;
  String? description;
  double? lastWind;
  double? lastHumidity;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    // Animasi ikon naik-turun pelan
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  WeatherStatus _statusFromCondition(String? c) {
    switch (c) {
      case 'Cerah':
        return WeatherStatus.cerah;
      case 'Berawan':
        return WeatherStatus.berawan;
      case 'Berpotensi Hujan':
        return WeatherStatus.berpotensiHujan;
      case 'Hujan':
        return WeatherStatus.hujan;
      default:
        return WeatherStatus.berawan;
    }
  }

  void _showError(String message) {
    setState(() {
      status = WeatherStatus.error;
      errorMessage = message;
      condition = null;
      description = null;
      isLoading = false;
    });
  }

  void resetForm() {
    FocusScope.of(context).unfocus();
    windController.clear();
    humidityController.clear();
    setState(() {
      status = WeatherStatus.initial;
      condition = null;
      description = null;
      errorMessage = null;
      lastWind = null;
      lastHumidity = null;
    });
  }

  Future<void> predictWeather() async {
    FocusScope.of(context).unfocus();

    final windText = windController.text.trim();
    final humidityText = humidityController.text.trim();

    if (windText.isEmpty || humidityText.isEmpty) {
      _showError('Kecepatan angin dan kelembapan harus diisi.');
      return;
    }

    final wind = double.tryParse(windText);
    final humidity = double.tryParse(humidityText);

    if (wind == null || humidity == null) {
      _showError('Masukkan angka yang valid.');
      return;
    }

    if (wind < 0) {
      _showError('Kecepatan angin tidak boleh kurang dari 0.');
      return;
    }

    if (humidity < 0 || humidity > 100) {
      _showError('Kelembapan harus berada di antara 0-100%.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final result = await ApiService.predictWeather(
        windSpeed: wind,
        humidity: humidity,
      );

      setState(() {
        condition = result['condition'];
        description = result['description'];
        status = _statusFromCondition(result['condition']);
        lastWind = wind;
        lastHumidity = humidity;
        errorMessage = null;
        isLoading = false;
      });
    } catch (e) {
      _showError('Tidak dapat terhubung ke server.');
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    windController.dispose();
    humidityController.dispose();
    super.dispose();
  }

  // ---------- UI ----------

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required String suffix,
    required IconData icon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.35)),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffix,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white.withOpacity(0.15),
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
      floatingLabelStyle: const TextStyle(color: Colors.white),
      suffixStyle: const TextStyle(color: Colors.white70),
      prefixIconColor: Colors.white70,
      enabledBorder: border,
      border: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white, width: 2),
      ),
    );
  }

  Widget _buildHeader(WeatherTheme theme) {
    final isError = status == WeatherStatus.error;
    final isInitial = status == WeatherStatus.initial;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: Column(
        key: ValueKey(status),
        children: [
          AnimatedBuilder(
            animation: _floatAnimation,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, isError ? 0 : _floatAnimation.value),
              child: child,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
                boxShadow: [
                  BoxShadow(
                    color: theme.iconColor.withOpacity(0.35),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                theme.icon,
                size: isInitial ? 80 : 96,
                color: theme.iconColor,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            theme.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isInitial ? 24 : 34,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isError ? (errorMessage ?? '') : (description ?? theme.subtitle),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultInfo() {
    final show = status != WeatherStatus.initial &&
        status != WeatherStatus.error &&
        lastWind != null &&
        lastHumidity != null;

    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      child: show
          ? Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Row(
                children: [
                  _buildInfoChip(
                    Icons.air,
                    'Kecepatan Angin',
                    '${lastWind!.toStringAsFixed(lastWind! % 1 == 0 ? 0 : 1)} km/jam',
                  ),
                  const SizedBox(width: 12),
                  _buildInfoChip(
                    Icons.water_drop,
                    'Kelembapan',
                    '${lastHumidity!.toStringAsFixed(lastHumidity! % 1 == 0 ? 0 : 1)} %',
                  ),
                ],
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = weatherThemes[status]!;
    final hasResult = status != WeatherStatus.initial;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'WeatherPredict',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (hasResult)
            IconButton(
              tooltip: 'Reset',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: resetForm,
            ),
        ],
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: theme.gradient,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),

                // Header: ikon + judul + deskripsi (berubah sesuai hasil)
                _buildHeader(theme),

                // Info angin & kelembapan dari hasil prediksi
                _buildResultInfo(),

                const SizedBox(height: 32),

                // Form input
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: windController,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.white,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDecoration(
                          label: 'Kecepatan Angin',
                          hint: 'Contoh: 15',
                          suffix: 'km/jam',
                          icon: Icons.air,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: humidityController,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.white,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDecoration(
                          label: 'Kelembapan',
                          hint: 'Contoh: 80',
                          suffix: '%',
                          icon: Icons.water_drop,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : predictWeather,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: theme.accent,
                            disabledBackgroundColor:
                                Colors.white.withOpacity(0.7),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: isLoading
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: theme.accent,
                                  ),
                                )
                              : const Text(
                                  'PREDIKSI CUACA',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
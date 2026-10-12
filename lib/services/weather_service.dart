// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/services/weather_service.dart
//
// WO-P0-PRIVACY — Weather request service with capability gating.
// Open-Meteo API requests are strictly forbidden unless affirmative
// user consent for PrivacyCapability.remoteWeather has been granted.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/privacy/privacy_capability.dart';

enum WeatherStatus {
  disabled, // Blocked by privacy policy / unknown or denied consent
  unavailable, // Network error, timeout, or server error
  success, // Forecast received successfully
}

class WeatherResult {
  final WeatherStatus status;
  final double? temperatureF;
  final int? weatherCode;
  final String? formattedChip;
  final String? summary;
  final String? reason;

  const WeatherResult._({
    required this.status,
    this.temperatureF,
    this.weatherCode,
    this.formattedChip,
    this.summary,
    this.reason,
  });

  const WeatherResult.disabled({
    String summary = 'Weather disabled',
    String reason = 'Disabled in privacy settings',
  }) : this._(
          status: WeatherStatus.disabled,
          summary: summary,
          reason: reason,
        );

  const WeatherResult.unavailable({
    String summary = 'Weather unavailable',
    String reason = 'Network or provider error',
  }) : this._(
          status: WeatherStatus.unavailable,
          summary: summary,
          reason: reason,
        );

  const WeatherResult.success({
    required double temperatureF,
    required int weatherCode,
    required String formattedChip,
    required String summary,
  }) : this._(
          status: WeatherStatus.success,
          temperatureF: temperatureF,
          weatherCode: weatherCode,
          formattedChip: formattedChip,
          summary: summary,
        );

  bool get isSuccess => status == WeatherStatus.success;
  bool get isAvailable => status == WeatherStatus.success;
  bool get isDisabled => status == WeatherStatus.disabled;

  String get weatherEmoji => WeatherService.weatherEmoji(weatherCode ?? 0);
}

class WeatherService {
  final http.Client? client;

  WeatherService({this.client});

  @visibleForTesting
  static Future<bool> Function()? consentEvaluatorForTesting;

  /// Converts an Open-Meteo WMO weather code to a representative emoji.
  static String weatherEmoji(int code) {
    if (code == 0) return '☀️';
    if (code <= 3) return '⛅';
    if (code <= 48) return '🌫️';
    if (code <= 67) return '🌧️';
    if (code <= 77) return '❄️';
    if (code <= 82) return '🌦️';
    return '⛈️';
  }

  /// Converts an Open-Meteo WMO weather code to human-readable condition text.
  static String weatherSummary(int code) {
    if (code == 0) return 'Clear sky';
    if (code <= 3) return 'Partly cloudy';
    if (code <= 48) return 'Foggy';
    if (code <= 67) return 'Rain';
    if (code <= 77) return 'Snow';
    if (code <= 82) return 'Rain showers';
    return 'Thunderstorm';
  }

  /// Fetches weather for [lat] and [lng] from Open-Meteo.
  ///
  /// CRITICAL PRIVACY GATE: Independently verifies affirmative consent for
  /// [PrivacyCapability.remoteWeather]. Caller-supplied [isConsented] is checked,
  /// but can NEVER bypass an ungranted capability state.
  static Future<WeatherResult> fetchWeather({
    required double lat,
    required double lng,
    bool? isConsented,
    http.Client? client,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final bool allowed;
    if (consentEvaluatorForTesting != null) {
      allowed = await consentEvaluatorForTesting!();
    } else {
      allowed = await PrivacyCapabilityService.isGranted(PrivacyCapability.remoteWeather);
    }

    if (!allowed || isConsented == false) {
      return const WeatherResult.disabled();
    }

    final httpClient = client ?? http.Client();
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m,weather_code&temperature_unit=fahrenheit',
      );
      final res = await httpClient
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(timeout);

      if (res.statusCode != 200) {
        return const WeatherResult.unavailable();
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>;
      final temp = (current['temperature_2m'] as num).toDouble();
      final code = current['weather_code'] as int? ?? 0;
      final summary = weatherSummary(code);
      final chip = '${weatherEmoji(code)} ${temp.round()}°F';

      return WeatherResult.success(
        temperatureF: temp,
        weatherCode: code,
        formattedChip: chip,
        summary: summary,
      );
    } catch (_) {
      return const WeatherResult.unavailable();
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }
}

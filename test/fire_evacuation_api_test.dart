import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fire_evacuation_app/core/fire_evacuation_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default API URL uses the local FastAPI backend origin', () {
    final uri = Uri.parse(FireEvacuationApi.defaultBaseUrl);

    expect(uri.origin, 'http://127.0.0.1:8000');
    expect(uri.host, '127.0.0.1');
    expect(uri.queryParameters.containsKey('_vercel_share'), isFalse);
  });

  test('removes Vercel share query when supplied as API_BASE_URL', () {
    final api = FireEvacuationApi(
      baseUrl: 'https://fireevacuationsystem.vercel.app?_vercel_share=token',
    );

    expect(api.baseUrl, 'https://fireevacuationsystem.vercel.app/');
  });

  test('device ingestion requests send the device token header', () async {
    final adapter = _CaptureAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test.invalid'))
      ..httpClientAdapter = adapter;

    await FireEvacuationApi(dio: dio).postSensorReadings(
      deviceToken: 'device-secret',
      deviceUid: 'ESP 32 A',
      readings: {'BLOCK A': 230},
    );

    expect(adapter.requestOptions?.path, '/sensor_readings');
    expect(adapter.requestOptions?.headers['X-Device-Token'], 'device-secret');
  });

  test('dashboard request sends the Supabase session bearer token', () async {
    final adapter = _CaptureAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test.invalid'))
      ..httpClientAdapter = adapter;

    await FireEvacuationApi(
      dio: dio,
    ).getDashboardSnapshot(accessToken: 'signed-in-user-token');

    expect(
      adapter.requestOptions?.headers['Authorization'],
      'Bearer signed-in-user-token',
    );
    expect(adapter.requestOptions?.path, '/dashboard');
  });
}

class _CaptureAdapter implements HttpClientAdapter {
  RequestOptions? requestOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestOptions = options;
    return ResponseBody.fromString(
      jsonEncode({
        'zones': [],
        'devices': [],
        'sensors': [],
        'sensor_readings': [],
        'occupancy_readings': [],
        'zone_risks': [],
        'incidents': [],
        'alerts': [],
        'routes': [],
        'user_profile': null,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

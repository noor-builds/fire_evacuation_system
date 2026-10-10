import 'package:dio/dio.dart';

class FireEvacuationApi {
  FireEvacuationApi({Dio? dio, String? baseUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: _cleanBaseUrl(baseUrl ?? defaultBaseUrl),
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 8),
            ),
          );

  static const defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://fireevacuationsystem.vercel.app/',
  );

  static String _cleanBaseUrl(String value) {
    final trimmed = value.trim();
    final uri = Uri.parse(trimmed);
    if (!uri.queryParameters.containsKey('_vercel_share')) {
      return uri.hasAuthority && uri.path.isEmpty
          ? uri.replace(path: '/').toString()
          : trimmed;
    }

    final queryParameters = Map<String, String>.from(uri.queryParameters)
      ..remove('_vercel_share');
    return Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path.isEmpty ? '/' : uri.path,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    ).toString();
  }

  final Dio _dio;
  String get baseUrl => _dio.options.baseUrl;

  Future<Map<String, dynamic>> getStatus() =>
      _requestMap(_dio.get<Map<String, dynamic>>('/status'));

  Future<Map<String, dynamic>> getDashboardSnapshot({
    required String accessToken,
  }) => _requestMap(
    _dio.get<Map<String, dynamic>>(
      '/dashboard',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    ),
  );

  Future<Object?> getStudentCount({
    required String key,
    required String place,
  }) async => (await _dio.get<Object>(
    '/student',
    queryParameters: {'key': key, 'place': place},
  )).data;

  Future<Map<String, dynamic>> postSmokeDensity({
    required String deviceToken,
    required String deviceUid,
    required String room,
    required int smokeVal,
  }) => _requestMap(
    _dio.post<Map<String, dynamic>>(
      '/smoke_density',
      queryParameters: {'key': deviceUid, 'room': room, 'smokeVal': smokeVal},
      options: _deviceOptions(deviceToken),
    ),
  );

  Future<Map<String, dynamic>> postCafeTemperature({
    required String deviceToken,
    required String deviceUid,
    required double temp,
  }) => _requestMap(
    _dio.post<Map<String, dynamic>>(
      '/cafe_temperature',
      queryParameters: {'key': deviceUid, 'temp': temp},
      options: _deviceOptions(deviceToken),
    ),
  );

  Future<Map<String, dynamic>> postEvacuationLights({
    required String deviceToken,
    required String deviceUid,
    required String dangerZone,
  }) => _requestMap(
    _dio.post<Map<String, dynamic>>(
      '/evacuation_lights',
      queryParameters: {'key': deviceUid, 'danger_zone': dangerZone},
      options: _deviceOptions(deviceToken),
    ),
  );

  Future<Map<String, dynamic>> postSensorReadings({
    required String deviceToken,
    required String deviceUid,
    required Map<String, int> readings,
    double? temp,
  }) {
    final payload = <String, dynamic>{'key': deviceUid, 'readings': readings};
    if (temp != null) payload['temp'] = temp;
    return _requestMap(
      _dio.post<Map<String, dynamic>>(
        '/sensor_readings',
        data: payload,
        options: _deviceOptions(deviceToken),
      ),
    );
  }

  Future<Map<String, dynamic>> postPotentialFire({
    required String deviceToken,
    required String deviceUid,
    required String room,
    required int smokeVal,
    double? temp,
  }) {
    final parameters = <String, dynamic>{
      'key': deviceUid,
      'room': room,
      'smokeVal': smokeVal,
    };
    if (temp != null) parameters['temp'] = temp;
    return _requestMap(
      _dio.post<Map<String, dynamic>>(
        '/potential_fire',
        queryParameters: parameters,
        options: _deviceOptions(deviceToken),
      ),
    );
  }

  Options _deviceOptions(String deviceToken) =>
      Options(headers: {'X-Device-Token': deviceToken});

  Future<Map<String, dynamic>> _requestMap(
    Future<Response<Map<String, dynamic>>> response,
  ) async {
    final data = (await response).data;
    if (data == null) {
      throw const FormatException(
        'The fire server returned an empty response.',
      );
    }
    return data;
  }
}

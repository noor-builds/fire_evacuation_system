import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fire_evacuation_app/core/fire_evacuation_api.dart';
import 'package:fire_evacuation_app/core/supabase_service.dart';
import 'package:fire_evacuation_app/features/dashboard/data/dashboard_snapshot.dart';
import 'package:fire_evacuation_app/features/dashboard/presentation/widgets/dashboard_overview.dart';
import 'package:fire_evacuation_app/features/dashboard/presentation/widgets/dashboard_sidebar.dart';
import 'package:fire_evacuation_app/features/dashboard/presentation/widgets/dashboard_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final _api = FireEvacuationApi();
  int _selectedSection = 0;
  DashboardSnapshot? _snapshot;
  Map<String, dynamic>? _apiStatus;
  String? _databaseError;
  String? _apiError;
  bool _isLoading = true;
  bool _refreshInProgress = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshData();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshData(showLoading: false),
    );
  }

  Future<void> _refreshData({bool showLoading = true}) async {
    if (_refreshInProgress) return;
    _refreshInProgress = true;
    if (mounted) {
      setState(() {
        if (showLoading) _isLoading = true;
        _databaseError = null;
        _apiError = null;
      });
    }
    try {
      await _loadApiStatus();
      await _loadDashboardData();
    } finally {
      _refreshInProgress = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acknowledgeAlert(String alertId) async {
    try {
      await SupabaseService.acknowledgeAlert(alertId);
      await _refreshData(showLoading: false);
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not acknowledge alert: $error')),
      );
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    try {
      final accessToken =
          Supabase.instance.client.auth.currentSession?.accessToken;
      if (accessToken == null) {
        throw StateError('Sign in to load dashboard data.');
      }
      final response = await _api.getDashboardSnapshot(
        accessToken: accessToken,
      );
      final snapshot = DashboardSnapshot.fromJson(response);
      if (mounted) setState(() => _snapshot = snapshot);
    } on DioException catch (error) {
      if (mounted) {
        setState(() => _databaseError = _apiErrorMessage(error));
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _databaseError = error.message);
    } on Exception catch (error) {
      if (mounted) setState(() => _databaseError = error.toString());
    }
  }

  Future<void> _loadApiStatus() async {
    try {
      final status = await _api.getStatus();
      final missingSettings = <String>[
        if (status['dashboard_configured'] == false)
          'Dashboard reads need SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY '
              '(or a server key) configured in Vercel.',
        if (status['sensor_database_configured'] == false ||
            (status['sensor_database_configured'] == null &&
                status['database_configured'] == false))
          'ESP32 readings need a server-only SUPABASE_SECRET_KEY (or '
              'SUPABASE_SERVICE_ROLE_KEY) in the backend; a publishable key '
              'cannot write sensor data.',
        if (status['device_ingestion_configured'] != true)
          'Set DEVICE_API_TOKEN in the backend.',
      ];
      if (mounted) {
        setState(() {
          _apiStatus = status;
          _apiError = missingSettings.isEmpty
              ? null
              : 'Backend is reachable, but setup is incomplete. '
                    '${missingSettings.join(' ')}';
        });
      }
    } on DioException catch (error) {
      if (mounted) {
        setState(() => _apiError = _apiErrorMessage(error));
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _apiError = error.message);
    }
  }

  String _apiErrorMessage(DioException error) {
    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic> &&
        responseData['detail'] != null) {
      return responseData['detail'].toString();
    }
    if (error.response == null) {
      return 'Cannot reach the backend at ${_api.baseUrl}. Open '
          '${_api.baseUrl}/status in a browser. If it is deployed on Vercel, '
          'confirm the FastAPI app is the deployed project and the Vercel '
          'environment variables are set. For local testing, start '
          '`python -m backend.main` and pass API_BASE_URL to Flutter.';
    }
    return error.message ?? 'The backend request failed.';
  }

  Future<void> _signOut() async {
    try {
      await SupabaseService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } on AuthException catch (error) {
      _showError(error.message);
    } on Exception catch (error) {
      _showError(error.toString());
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Unable to sign out: $message')));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 850;
        return Scaffold(
          drawer: isWide
              ? null
              : Drawer(
                  child: SafeArea(
                    child: DashboardSidebar(
                      selectedIndex: _selectedSection,
                      isOnline:
                          _apiStatus?['status'] == 'ok' &&
                          _databaseError == null,
                      isChecking: _isLoading && _apiStatus == null,
                      onDestinationSelected: (index) {
                        setState(() => _selectedSection = index);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ),
          body: SafeArea(
            child: Row(
              children: [
                if (isWide)
                  DashboardSidebar(
                    selectedIndex: _selectedSection,
                    isOnline:
                        _apiStatus?['status'] == 'ok' && _databaseError == null,
                    isChecking: _isLoading && _apiStatus == null,
                    onDestinationSelected: (index) {
                      setState(() => _selectedSection = index);
                    },
                  ),
                Expanded(
                  child: Column(
                    children: [
                      DashboardTopBar(
                        showMenuIcon: !isWide,
                        onRefresh: _refreshData,
                        onSignOut: _signOut,
                      ),
                      Expanded(
                        child: DashboardOverview(
                          selectedSection: _selectedSection,
                          snapshot: _snapshot,
                          isLoading: _isLoading,
                          databaseError: _databaseError,
                          apiError: _apiError,
                          apiStatus: _apiStatus,
                          onRefresh: _refreshData,
                          onAcknowledgeAlert: _acknowledgeAlert,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'dart:async';

import 'package:flutter/services.dart';

class MyIdService {
  MyIdService._internal() {
    _channel.setMethodCallHandler(_handleNativeCallback);
  }

  static final MyIdService _instance = MyIdService._internal();

  factory MyIdService() => _instance;

  static const MethodChannel _channel = MethodChannel('com.isell.myid/sdk');

  static final StreamController<MyIdSdkEvent> _eventController =
      StreamController<MyIdSdkEvent>.broadcast();

  Stream<MyIdSdkEvent> get events => _eventController.stream;

  Future<MyIdFlowResult> start(MyIdConfig config) async {
    final payload = await _channel.invokeMethod<dynamic>(
      'startMyId',
      config.toJson(),
    );

    if (payload is! Map) {
      throw PlatformException(
        code: 'unexpected_response',
        message: 'MyID SDK returned an unexpected response',
        details: payload,
      );
    }

    final data = payload.map((key, value) => MapEntry(key.toString(), value));

    final status = _parseStatus(data['status']);


    return MyIdFlowResult(
      status: status,
      code: data['code']?.toString(),
      reuid: data['reuid']?.toString(),
      comparisonValue: data['comparisonValue'],
      imageBase64: data['imageBase64']?.toString(),
      errorCode: status == MyIdFlowStatus.error
          ? data['code']?.toString()
          : null,
      errorMessage: status == MyIdFlowStatus.error
          ? data['message']?.toString()
          : null,
      raw: Map<String, dynamic>.from(data),
    );
  }

  Future<void> _handleNativeCallback(MethodCall call) async {
    if (call.method == 'myIdEvent') {
      final args = call.arguments;
      if (args is Map) {
        final data = args.map((key, value) => MapEntry(key.toString(), value));
        _eventController.add(
          MyIdSdkEvent(name: data['event']?.toString() ?? '', payload: data),
        );
      }
      return;
    }

    throw MissingPluginException(
      'MyIdService: unhandled callback ${call.method}',
    );
  }

  MyIdFlowStatus _parseStatus(dynamic value) {
    switch (value?.toString().toLowerCase()) {
      case 'success':
        return MyIdFlowStatus.success;
      case 'error':
        return MyIdFlowStatus.error;
      case 'cancelled':
        return MyIdFlowStatus.cancelled;
      default:
        return MyIdFlowStatus.unknown;
    }
  }

  void dispose() {
    _eventController.close();
  }
}

class MyIdConfig {
  MyIdConfig({
    required this.sessionId,
    required this.clientHash,
    required this.clientHashId,
    this.minAge,
    this.environment = MyIdEnvironment.production,
    this.entryType = MyIdEntryType.identification,
    this.residency = MyIdResidency.resident,
    this.locale = MyIdLocale.uz,
    this.cameraShape = MyIdCameraShape.circle,
    this.showErrorScreen = true,
    this.organizationDetails,
    this.appearance,
  });

  final String sessionId;
  final String clientHash;
  final String clientHashId;
  final int? minAge;
  final MyIdEnvironment environment;
  final MyIdEntryType entryType;
  final MyIdResidency residency;
  final MyIdLocale locale;
  final MyIdCameraShape cameraShape;
  final bool showErrorScreen;
  final MyIdOrganizationDetails? organizationDetails;
  final MyIdAppearance? appearance;

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'clientHash': clientHash,
      'clientHashId': clientHashId,
      if (minAge != null) 'minAge': minAge,
      'environment': environment.name,
      'entryType': entryType.name,
      'residency': residency.name,
      'locale': locale.code,
      'cameraShape': cameraShape.name,
      'showErrorScreen': showErrorScreen,
      if (organizationDetails != null)
        'organizationDetails': organizationDetails!.toJson(),
      if (appearance != null) 'appearance': appearance!.toJson(),
    };
  }
}

class MyIdAppearance {
  MyIdAppearance({
    this.colorPrimary,
    this.colorOnPrimary,
    this.colorError,
    this.colorOnError,
    this.colorOutline,
    this.colorDivider,
    this.colorSuccess,
    this.colorButtonContainer,
    this.colorButtonContainerDisabled,
    this.colorButtonContent,
    this.colorButtonContentDisabled,
    this.buttonCornerRadius,
  });

  final String? colorPrimary;
  final String? colorOnPrimary;
  final String? colorError;
  final String? colorOnError;
  final String? colorOutline;
  final String? colorDivider;
  final String? colorSuccess;
  final String? colorButtonContainer;
  final String? colorButtonContainerDisabled;
  final String? colorButtonContent;
  final String? colorButtonContentDisabled;
  final double? buttonCornerRadius;

  Map<String, dynamic> toJson() {
    return {
      if (colorPrimary != null) 'colorPrimary': colorPrimary,
      if (colorOnPrimary != null) 'colorOnPrimary': colorOnPrimary,
      if (colorError != null) 'colorError': colorError,
      if (colorOnError != null) 'colorOnError': colorOnError,
      if (colorOutline != null) 'colorOutline': colorOutline,
      if (colorDivider != null) 'colorDivider': colorDivider,
      if (colorSuccess != null) 'colorSuccess': colorSuccess,
      if (colorButtonContainer != null)
        'colorButtonContainer': colorButtonContainer,
      if (colorButtonContainerDisabled != null)
        'colorButtonContainerDisabled': colorButtonContainerDisabled,
      if (colorButtonContent != null) 'colorButtonContent': colorButtonContent,
      if (colorButtonContentDisabled != null)
        'colorButtonContentDisabled': colorButtonContentDisabled,
      if (buttonCornerRadius != null) 'buttonCornerRadius': buttonCornerRadius,
    };
  }
}

class MyIdOrganizationDetails {
  MyIdOrganizationDetails({this.phoneNumber, this.logoAsset, this.logoBase64});

  final String? phoneNumber;
  final String? logoAsset;
  final String? logoBase64;

  Map<String, dynamic> toJson() {
    return {
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (logoAsset != null) 'logoAsset': logoAsset,
      if (logoBase64 != null) 'logoBase64': logoBase64,
    };
  }
}

class MyIdFlowResult {
  MyIdFlowResult({
    required this.status,
    this.code,
    this.reuid,
    this.comparisonValue,
    this.imageBase64,
    this.errorCode,
    this.errorMessage,
    this.raw,
  });

  final MyIdFlowStatus status;
  final String? code;
  final String? reuid;
  final dynamic comparisonValue;
  final String? imageBase64;
  final String? errorCode;
  final String? errorMessage;
  final Map<String, dynamic>? raw;

  bool get isSuccess => status == MyIdFlowStatus.success;
  bool get isCancelled => status == MyIdFlowStatus.cancelled;
  bool get isError => status == MyIdFlowStatus.error;
}

class MyIdSdkEvent {
  MyIdSdkEvent({required this.name, required this.payload});

  final String name;
  final Map<String, dynamic> payload;
}

enum MyIdFlowStatus { success, error, cancelled, unknown }

enum MyIdEnvironment { production, debug }

extension _MyIdEnvironmentName on MyIdEnvironment {
  String get name => switch (this) {
    MyIdEnvironment.production => 'production',
    MyIdEnvironment.debug => 'debug',
  };
}

enum MyIdEntryType { identification, faceDetection }

extension _MyIdEntryTypeName on MyIdEntryType {
  String get name => switch (this) {
    MyIdEntryType.identification => 'identification',
    MyIdEntryType.faceDetection => 'faceDetection',
  };
}

enum MyIdResidency { resident, nonResident, userDefined }

extension _MyIdResidencyName on MyIdResidency {
  String get name => switch (this) {
    MyIdResidency.resident => 'resident',
    MyIdResidency.nonResident => 'nonResident',
    MyIdResidency.userDefined => 'userDefined',
  };
}

enum MyIdLocale { uz, en, ru }

extension _MyIdLocaleCode on MyIdLocale {
  String get code => switch (this) {
    MyIdLocale.uz => 'uz',
    MyIdLocale.en => 'en',
    MyIdLocale.ru => 'ru',
  };
}

enum MyIdCameraShape { circle, ellipse }

extension _MyIdCameraShapeName on MyIdCameraShape {
  String get name => switch (this) {
    MyIdCameraShape.circle => 'circle',
    MyIdCameraShape.ellipse => 'ellipse',
  };
}

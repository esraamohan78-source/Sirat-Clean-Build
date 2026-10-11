import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

import '../../error/error_code.dart';
import '../../error/exceptions.dart';
import '../../error/failures.dart';
import '../../keys.dart';
import '../model/geocoding.dart';

/// Function to get current position of user
Future<Either<LocalFailure, Position>> getCurrentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    return Left(
      LocalFailure(
        message: kLocationDisable['message'],
        error: kLocationDisable['errorCode'] as int,
      ),
    );
  }

  final LocationPermission permission = await Geolocator.checkPermission();
  LocationPermission newPermission = LocationPermission.denied;

  if (permission == LocationPermission.denied && Platform.isAndroid) {
    newPermission = await Geolocator.requestPermission();

    if (newPermission == LocationPermission.deniedForever) {
      return Left(
        LocalFailure(
          message: kLocationDisableForever['message'],
          error: kLocationDisableForever['errorCode'] as int,
        ),
      );
    }
  }

  if (permission == LocationPermission.denied &&
      newPermission == LocationPermission.denied &&
      Platform.isAndroid) {
    return Left(
      LocalFailure(
        message: kLocationDisable['message'],
        error: kLocationDisable['errorCode'] as int,
      ),
    );
  }

  if (permission == LocationPermission.denied && Platform.isIOS) {
    newPermission = await Geolocator.requestPermission();

    if (newPermission == LocationPermission.deniedForever) {
      return Left(
        LocalFailure(
          message: kLocationDisableForever['message'],
          error: kLocationDisableForever['errorCode'] as int,
        ),
      );
    }
  }

  if (permission == LocationPermission.deniedForever && Platform.isIOS) {
    return Left(
      LocalFailure(
        message: kLocationDisableForever['message'],
        error: kLocationDisableForever['errorCode'] as int,
      ),
    );
  }

  final Position position = await Geolocator.getCurrentPosition(
    locationSettings: LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 100,
    ),
  );

  return Right(position);
}

Future<void> openLocationSetting() async {
  await Geolocator.openLocationSettings();
}

Future<Either<Failure, Geocoding>> getAddress(
  double latitude,
  double longitude,
) async {
  final Dio dio = Dio();
  try {
    final response = await dio.get(
      'https://nominatim.openstreetmap.org/reverse',
      queryParameters: {
        'lat': latitude,
        'lon': longitude,
        'format': 'json',
      },
      options: Options(
        headers: {
          'User-Agent': 'SiratEMustaqeemApp/1.0',
        },
      ),
    );

    if (response.statusCode == 200 && response.data != null) {
      final String displayName = response.data['display_name'] ?? 'Unknown Location';
      final Map<String, dynamic> mockGoogleFormat = {
        'results': [
          {
            'formatted_address': displayName,
            'address_components': [],
          }
        ],
        'status': 'OK'
      };
      final Geocoding geocoding = Geocoding.fromJson(mockGoogleFormat);
      return Right(geocoding);
    } else {
      return Left(
        RemoteFailure(
            message: response.statusCode,
            errorType: DioExceptionType.badResponse),
      );
    }
  } catch (e) {
    return Left(
      RemoteFailure(
        message: e.toString(),
        errorType: DioExceptionType.unknown,
      ),
    );
  }
}

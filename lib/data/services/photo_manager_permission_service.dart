import 'package:photo_manager/photo_manager.dart';

import '../../application/services/permission_service.dart';
import '../../domain/models/photo_permission_status.dart';

class PhotoManagerPermissionService implements PermissionService {
  const PhotoManagerPermissionService();

  static const PermissionRequestOption _requestOption = PermissionRequestOption(
    iosAccessLevel: IosAccessLevel.readWrite,
  );

  @override
  Future<PhotoPermissionStatus> getPhotoPermissionStatus() async {
    final nativeStatus = await PhotoManager.getPermissionState(
      requestOption: _requestOption,
    );

    return _mapStatus(nativeStatus);
  }

  @override
  Future<void> openPhotoSettings() {
    return PhotoManager.openSetting();
  }

  @override
  Future<PhotoPermissionStatus> presentLimitedPhotoPicker() async {
    await PhotoManager.presentLimited();
    return getPhotoPermissionStatus();
  }

  @override
  Future<PhotoPermissionStatus> requestPhotoPermission() async {
    final nativeStatus = await PhotoManager.requestPermissionExtend(
      requestOption: _requestOption,
    );

    return _mapStatus(nativeStatus);
  }

  PhotoPermissionStatus _mapStatus(PermissionState state) {
    return switch (state) {
      PermissionState.notDetermined => PhotoPermissionStatus.notRequested,
      PermissionState.denied ||
      PermissionState.restricted => PhotoPermissionStatus.denied,
      PermissionState.limited => PhotoPermissionStatus.limited,
      PermissionState.authorized => PhotoPermissionStatus.fullAccess,
    };
  }
}

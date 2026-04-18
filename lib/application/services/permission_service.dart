import '../../domain/models/photo_permission_status.dart';

abstract interface class PermissionService {
  Future<PhotoPermissionStatus> getPhotoPermissionStatus();

  Future<PhotoPermissionStatus> requestPhotoPermission();

  Future<PhotoPermissionStatus> presentLimitedPhotoPicker();

  Future<void> openPhotoSettings();
}

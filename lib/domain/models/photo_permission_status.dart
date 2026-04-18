enum PhotoPermissionStatus {
  notRequested,
  denied,
  limited,
  fullAccess;

  bool get hasAccess =>
      this == PhotoPermissionStatus.limited ||
      this == PhotoPermissionStatus.fullAccess;
}

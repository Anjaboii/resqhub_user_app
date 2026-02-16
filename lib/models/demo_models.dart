class DemoVehicle {
  final String name;
  final String plate;
  final String meta;
  final bool isDefault;

  const DemoVehicle({
    required this.name,
    required this.plate,
    required this.meta,
    this.isDefault = false,
  });
}

enum ServiceType {
  battery,
  flatTire,
  fuel,
  towing,
  lockout,
  engine,
  accident,
  other,
}

String serviceTitle(ServiceType t) {
  switch (t) {
    case ServiceType.battery: return "Battery issue";
    case ServiceType.flatTire: return "Flat Tire";
    case ServiceType.fuel: return "Out of Fuel";
    case ServiceType.towing: return "Towing";
    case ServiceType.lockout: return "Lockout";
    case ServiceType.engine: return "Engine Problem";
    case ServiceType.accident: return "Accident";
    case ServiceType.other: return "Other issue";
  }
}

String serviceSubtitle(ServiceType t) {
  switch (t) {
    case ServiceType.battery: return "Jump start or replacement";
    case ServiceType.flatTire: return "Tire change or repair";
    case ServiceType.fuel: return "Emergency fuel delivery";
    case ServiceType.towing: return "Vehicle towing service";
    case ServiceType.lockout: return "Locked out of vehicle";
    case ServiceType.engine: return "Engine won't start / overheating";
    case ServiceType.accident: return "Post-accident assistance";
    case ServiceType.other: return "Other roadside help";
  }
}

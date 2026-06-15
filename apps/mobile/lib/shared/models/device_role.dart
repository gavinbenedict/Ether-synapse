/// The operational role chosen by the user for this session.
///
/// - [sender]: Scans for nearby receivers. Does NOT advertise.
/// - [receiver]: Advertises itself. Does NOT scan.
enum DeviceRole {
  sender,
  receiver;

  String get label => switch (this) {
        DeviceRole.sender => 'Send Files',
        DeviceRole.receiver => 'Receive Files',
      };

  String get description => switch (this) {
        DeviceRole.sender =>
          'Find a nearby device that is ready to receive.',
        DeviceRole.receiver =>
          'Make this device discoverable so others can send files to it.',
      };
}

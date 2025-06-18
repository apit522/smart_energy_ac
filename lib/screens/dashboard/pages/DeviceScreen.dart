import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../models/device_model.dart';
import '../../../services/device_service.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  final DeviceService _deviceService = DeviceService();
  late Future<List<Device>> _devicesFuture;

  @override
  void initState() {
    super.initState();
    _refreshDevices();
  }

  void _refreshDevices() {
    setState(() {
      _devicesFuture = _deviceService.getDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header & Tombol Sync
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Perangkat Terdaftar',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.sync, size: 28),
                  tooltip: "Sync Perangkat",
                  onPressed: _refreshDevices,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Device>>(
                future: _devicesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final devices = snapshot.data ?? [];
                  return _buildDeviceGrid(devices);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceGrid(List<Device> devices) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 800) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 500) {
          crossAxisCount = 2;
        }

        return GridView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: devices.length + 1,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 3 / 2,
          ),
          itemBuilder: (context, index) {
            if (index == devices.length) {
              return _buildAddDeviceCard();
            }
            return _buildDeviceCard(devices[index]);
          },
        );
      },
    );
  }

  Widget _buildAddDeviceCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      color: Colors.grey[100],
      child: InkWell(
        onTap: () => _showDeviceDialog(),
        borderRadius: BorderRadius.circular(12.0),
        child: Center(
          child: Icon(Icons.add, size: 50, color: Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _buildDeviceCard(Device device) {
    bool isConnected = false;
    String lastSeenText = "Tidak diketahui";

    if (device.lastSeenAt != null) {
      try {
        final lastSeen = DateTime.parse(device.lastSeenAt!).toLocal();
        lastSeenText = timeago.format(lastSeen, locale: 'en_short');
        isConnected = DateTime.now().difference(lastSeen).inSeconds < 33;
      } catch (_) {}
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: () {}, // Bisa tambahkan detail perangkat di sini jika perlu
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Judul + Status
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          device.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildStatusChip(isConnected),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.memory_outlined,
                    'Unique ID',
                    device.uniqueId,
                  ),
                  const SizedBox(height: 6),
                  _buildInfoRow(
                    Icons.ac_unit_outlined,
                    'BTU/jam',
                    device.btu?.toString() ?? 'N/A',
                  ),
                  const SizedBox(height: 6),
                  _buildInfoRow(
                    Icons.access_time,
                    'Terakhir terlihat',
                    lastSeenText,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: Icon(
                      Icons.edit_outlined,
                      color: Colors.amber.shade800,
                    ),
                    label: Text(
                      'Edit',
                      style: TextStyle(color: Colors.amber.shade800),
                    ),
                    onPressed: () => _showDeviceDialog(device: device),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade700,
                    ),
                    label: Text(
                      'Hapus',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                    onPressed: () => _confirmDelete(device),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 18),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: Colors.grey[700])),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(bool isConnected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isConnected ? 'Terhubung' : 'Tidak terhubung',
        style: TextStyle(
          color: isConnected ? Colors.green.shade800 : Colors.red.shade800,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showDeviceDialog({Device? device}) {
    final isEditing = device != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: device?.name ?? '');
    final uniqueIdController = TextEditingController(
      text: device?.uniqueId ?? '',
    );
    final btuController = TextEditingController(
      text: device?.btu?.toString() ?? '',
    );
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                isEditing ? 'Edit Perangkat' : 'Tambah Perangkat Baru',
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Nama AC'),
                        validator: (v) =>
                            v!.isEmpty ? 'Nama tidak boleh kosong' : null,
                      ),
                      TextFormField(
                        controller: uniqueIdController,
                        decoration: const InputDecoration(
                          labelText: 'Unique ID Perangkat',
                        ),
                        validator: (v) =>
                            v!.isEmpty ? 'Unique ID tidak boleh kosong' : null,
                      ),
                      TextFormField(
                        controller: btuController,
                        decoration: const InputDecoration(
                          labelText: 'BTU/jam (Opsional)',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setState(() => isSaving = true);
                            try {
                              final name = nameController.text;
                              final uniqueId = uniqueIdController.text;
                              final btu = int.tryParse(btuController.text);

                              if (isEditing) {
                                await _deviceService.updateDevice(
                                  device!.id,
                                  name,
                                  uniqueId,
                                  btu,
                                );
                              } else {
                                await _deviceService.addDevice(
                                  name,
                                  uniqueId,
                                  btu,
                                );
                              }

                              if (context.mounted) Navigator.of(context).pop();
                              _refreshDevices();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } finally {
                              setState(() => isSaving = false);
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(Device device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Perangkat'),
        content: Text('Anda yakin ingin menghapus perangkat "${device.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _deviceService.deleteDevice(device.id);
                if (context.mounted) Navigator.of(context).pop();
                _refreshDevices();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../models/device_model.dart';
import '../../../models/device_data_model.dart';
import '../../../services/device_service.dart';
import '../../../utils/app_colors.dart';

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
    // Mengatur locale untuk timeago ke Bahasa Indonesia
    timeago.setLocaleMessages('id', timeago.IdMessages());
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
                  icon: const Icon(
                    Icons.sync,
                    size: 28,
                    color: AppColors.primaryColor,
                  ),
                  tooltip: "Refresh Daftar Perangkat",
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
          crossAxisCount = 2;
        } else if (constraints.maxWidth > 500) {
          crossAxisCount = 1;
        }

        return GridView.builder(
          padding: const EdgeInsets.only(
            top: 8,
            bottom: 24,
          ), // Tambah padding bawah
          itemCount: devices.length + 1, // +1 untuk kartu "Tambah"
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio:
                5 / 4, // Sesuaikan rasio agar kartu sedikit lebih tinggi
          ),
          itemBuilder: (context, index) {
            if (index == devices.length) {
              return _buildAddDeviceCard(); // Kartu terakhir adalah tombol tambah
            }
            return _buildDeviceCard(devices[index]); // Kartu data perangkat
          },
        );
      },
    );
  }

  // Kartu untuk menambah perangkat baru
  Widget _buildAddDeviceCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      color: Colors.grey[50],
      child: InkWell(
        onTap: () => _showDeviceDialog(),
        borderRadius: BorderRadius.circular(12.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, size: 40, color: Colors.grey[600]),
              const SizedBox(height: 8),
              Text(
                "Tambah Perangkat",
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Kartu untuk menampilkan detail satu perangkat
  Widget _buildDeviceCard(Device device) {
    return FutureBuilder<DeviceData?>(
      future: _deviceService.getLatestData(device.id),
      builder: (context, snapshot) {
        bool isConnected = false;
        String lastSeenText = "Tidak pernah terhubung";

        if (snapshot.connectionState == ConnectionState.waiting) {
          // Sementara loading, tampilkan shimmer atau loading kecil
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.white,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final latestData = snapshot.data!;
          try {
            // print(
            //   '[DEBUG] latestData: $latestData, timestamp: ${latestData.timestamp}',
            // );
            lastSeenText = timeago.format(latestData.timestamp, locale: 'id');
            isConnected =
                DateTime.now().difference(latestData.timestamp).inSeconds < 33;
          } catch (e) {
            // print('[DEBUG] Error parsing latestData.timestamp: $e');
          }
        }

        final currencyFormatter = NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp ',
          decimalDigits: 2,
        );

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Bagian Atas: Nama dan Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.location_on_outlined,
                      'Lokasi',
                      device.location ?? 'N/A',
                    ),
                    const SizedBox(height: 6),
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
                      Icons.flash_on_outlined,
                      'Daya Listrik',
                      '${device.dayaVa?.toString() ?? 'N/A'} VA',
                    ),
                    const SizedBox(height: 6),
                    _buildInfoRow(
                      Icons.attach_money,
                      'Tarif',
                      '${currencyFormatter.format(device.tarifPerKwh ?? 0)}/kWh',
                    ),
                    const SizedBox(height: 6),
                    _buildInfoRow(
                      Icons.access_time,
                      'Terakhir Terhubung',
                      lastSeenText,
                    ),
                  ],
                ),
                // Bagian Bawah: Tombol Aksi
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _showDeviceDialog(device: device),
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            color: Colors.amber.shade800,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Edit',
                            style: TextStyle(color: Colors.amber.shade800),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _confirmDelete(device),
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: Colors.red.shade700,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Hapus',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- WIDGET HELPER ---
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 16),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey[700], fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(bool isConnected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isConnected ? 'Terhubung' : 'Tidak terhubung',
        style: TextStyle(
          color: isConnected ? Colors.green.shade800 : Colors.red.shade800,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  // --- DIALOGS (TAMPILAN BARU) ---

  /// 🎨 Dialog untuk Tambah atau Edit Perangkat dengan UI yang lebih baik
  void _showDeviceDialog({Device? device}) {
    final isEditing = device != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: device?.name);
    final locationController = TextEditingController(text: device?.location);
    final uniqueIdController = TextEditingController(text: device?.uniqueId);
    final btuController = TextEditingController(text: device?.btu?.toString());
    int? selectedDayaVa = device?.dayaVa;

    final List<Map<String, Object>> dayaOptions = [
      {'text': '900 VA', 'value': 900},
      {'text': '1.300 VA', 'value': 1300},
      {'text': '2.200 VA', 'value': 2200},
      {'text': '3.500 VA', 'value': 3500},
      {'text': '4.400 VA', 'value': 4400},
      {'text': '5.500 VA', 'value': 5500},
      {'text': '6.600 VA ke atas', 'value': 6600},
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              // Tampilan lebih modern dengan sudut membulat
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              // Judul dengan icon untuk hierarki visual
              title: Row(
                children: [
                  Icon(
                    isEditing
                        ? Icons.edit_note_outlined
                        : Icons.add_circle_outline,
                    color: AppColors.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(isEditing ? 'Edit Perangkat' : 'Tambah Perangkat'),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Nama Perangkat',
                          prefixIcon: const Icon(Icons.devices_other_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) =>
                            v!.isEmpty ? 'Nama tidak boleh kosong' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: locationController,
                        decoration: InputDecoration(
                          labelText: 'Lokasi',
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: uniqueIdController,
                        decoration: InputDecoration(
                          labelText: 'Unique ID',
                          prefixIcon: const Icon(Icons.memory_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) =>
                            v!.isEmpty ? 'Unique ID tidak boleh kosong' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: btuController,
                        decoration: InputDecoration(
                          labelText: 'BTU/jam',
                          prefixIcon: const Icon(Icons.ac_unit_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: selectedDayaVa,
                        hint: const Text('Pilih Daya Listrik'),
                        decoration: InputDecoration(
                          labelText: 'Daya Listrik',
                          prefixIcon: const Icon(Icons.flash_on_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: dayaOptions.map((option) {
                          return DropdownMenuItem<int>(
                            value: option['value'] as int?,
                            child: Text(option['text']! as String),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setStateDialog(() {
                            selectedDayaVa = value;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Daya harus dipilih' : null,
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
                // Tombol aksi utama lebih menonjol
                ElevatedButton.icon(
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Simpan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: null,
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 🗑️ Dialog Konfirmasi Hapus dengan UI yang lebih aman dan jelas
  void _confirmDelete(Device device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // Sudut membulat
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        // Judul dengan icon peringatan
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
            const SizedBox(width: 8),
            const Text('Hapus Perangkat'),
          ],
        ),
        // Konten yang lebih jelas dengan RichText
        content: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: <TextSpan>[
              const TextSpan(text: 'Anda yakin ingin menghapus perangkat '),
              TextSpan(
                text: '"${device.name}"',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '? Tindakan ini tidak dapat dibatalkan.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          // Tombol hapus yang lebih menonjol (destructive action)
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Hapus'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: null,
          ),
        ],
      ),
    );
  }
}

// lib/screens/dashboard/pages/edit_profile_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/auth_service.dart';
import '../../../utils/app_colors.dart';

class EditProfileScreen extends StatefulWidget {
  final Future<void> Function() onProfileUpdated;

  const EditProfileScreen({super.key, required this.onProfileUpdated});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _newPasswordConfirmationController = TextEditingController();

  String? _currentPhotoUrl;
  Uint8List? _selectedImageBytes;
  String? _selectedImageFileName;
  File? _selectedImageFile_io;

  bool _isLoading = false;
  String _currentName = '';
  String _currentEmail = ''; // Email saat ini untuk perbandingan

  bool _isCurrentPasswordObscured = true;
  bool _isNewPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  @override
  void initState() {
    super.initState();
    _loadInitialUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _newPasswordConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialUserData() async {
    setState(() { _isLoading = true; });
    final userDetails = await _authService.getUserDetails();
    if (mounted) {
      setState(() {
        _currentName = userDetails['name'] ?? '';
        _currentEmail = userDetails['email'] ?? ''; // Simpan email saat ini
        _nameController.text = _currentName;
        _emailController.text = _currentEmail; // Set email ke controller
        _currentPhotoUrl = userDetails['photo_url'];
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageFileName = pickedFile.name;
          _selectedImageFile_io = null;
        });
      } else {
        setState(() {
          _selectedImageFile_io = File(pickedFile.path);
          _selectedImageBytes = null;
          _selectedImageFileName = null;
        });
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isLoading = true; });

    List<String> successMessages = [];
    List<String> errorMessages = [];

    String? newName = (_nameController.text.trim() != _currentName && _nameController.text.trim().isNotEmpty)
        ? _nameController.text.trim()
        : null;
    String? newEmail = (_emailController.text.trim() != _currentEmail && _emailController.text.trim().isNotEmpty)
        ? _emailController.text.trim()
        : null;
    bool photoChanged = _selectedImageBytes != null || _selectedImageFile_io != null;

    if (newName != null || newEmail != null || photoChanged) {
      final profileResult = await _authService.updateProfile(
        currentName: _currentName, // Untuk perbandingan di service jika perlu
        newName: newName,
        currentEmail: _currentEmail, // Kirim email saat ini untuk perbandingan
        newEmail: newEmail, // Kirim email baru jika ada perubahan
        profileImageBytes: _selectedImageBytes,
        profileImageFileName: _selectedImageFileName,
        profileImage_io: _selectedImageFile_io,
      );

      if (profileResult.containsKey('user')) {
        successMessages.add('Profile updated successfully!');
        setState(() {
          _currentName = profileResult['user']['name'] ?? _currentName;
          _currentEmail = profileResult['user']['email'] ?? _currentEmail; // Update email lokal
          _emailController.text = _currentEmail; // Update controller email juga
          _currentPhotoUrl = profileResult['user']['profile_photo_url'] ?? _currentPhotoUrl;
          _selectedImageBytes = null;
          _selectedImageFileName = null;
          _selectedImageFile_io = null;
        });
        await widget.onProfileUpdated();
      } else {
        String profileErrMsg = 'Failed to update profile.';
        if (profileResult.containsKey('errors') && profileResult['errors'] is Map) {
          var errors = profileResult['errors'] as Map;
          profileErrMsg = errors.entries.map((e) => '${e.key}: ${ (e.value as List).join(', ') }').join('\n');
        } else if (profileResult.containsKey('message')) {
          profileErrMsg = profileResult['message'];
        } else if (profileResult.containsKey('error')) {
          profileErrMsg = profileResult['error'];
        }
        errorMessages.add(profileErrMsg);
      }
    }

    if (_newPasswordController.text.isNotEmpty) {
      if (_currentPasswordController.text.isEmpty) { // Pastikan password saat ini diisi jika mau ganti password
        errorMessages.add('Current password is required to change to a new password.');
      } else if (_newPasswordController.text != _newPasswordConfirmationController.text) {
        errorMessages.add('New password and confirmation do not match.');
      } else {
        final passwordResult = await _authService.changePassword(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
          newPasswordConfirmation: _newPasswordConfirmationController.text,
        );

        if (passwordResult.containsKey('message') && (passwordResult['statusCode'] == null || passwordResult['statusCode'] < 400) ) {
          successMessages.add(passwordResult['message'] ?? 'Password changed successfully!');
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _newPasswordConfirmationController.clear();
        } else {
          String errMsg = 'Failed to change password.';
          if (passwordResult.containsKey('errors') && passwordResult['errors'] is Map) {
            var errors = passwordResult['errors'] as Map;
            errMsg = errors.entries.map((e) => '${e.key}: ${ (e.value as List).join(', ') }').join('\n');
          } else if (passwordResult.containsKey('message')) {
            errMsg = passwordResult['message'];
          } else if (passwordResult.containsKey('error')) {
            errMsg = passwordResult['error'];
          }
          errorMessages.add(errMsg);
        }
      }
    }


    if (mounted) { // Selalu cek mounted sebelum setState
      setState(() { _isLoading = false; });

      String overallMessage;
      if (errorMessages.isNotEmpty) {
        overallMessage = errorMessages.join('\n');
      } else if (successMessages.isNotEmpty) {
        overallMessage = successMessages.join('\n');
      } else {
        overallMessage = 'No changes were made.'; // Jika tidak ada nama, email, foto, atau password yang diubah
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(overallMessage)),
      );
    }
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 16.0), // Adjusted padding
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryColor, size: 22),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordTextField({
    required TextEditingController controller,
    required String labelText,
    required bool isObscured,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isObscured,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: onToggleVisibility,
        ),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? displayImage;
    if (_selectedImageBytes != null && kIsWeb) {
      displayImage = MemoryImage(_selectedImageBytes!);
    } else if (_selectedImageFile_io != null && !kIsWeb) {
      displayImage = FileImage(_selectedImageFile_io!);
    } else if (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty) {
      displayImage = NetworkImage(_currentPhotoUrl!);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,color: Colors.white,),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      // DIBUNGKUS DENGAN SAFEAREA DI SINI
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: displayImage,
                          child: displayImage == null
                              ? Icon(Icons.camera_alt, color: Colors.grey[600], size: 40)
                              : null,
                        ),
                      ),
                      TextButton(
                        onPressed: _pickImage,
                        child: const Text('Change Profile Photo', style: TextStyle(color: AppColors.primaryColor)),
                      ),
                      const SizedBox(height: 16),
                      if (_currentName.isNotEmpty)
                        Text(
                          _currentName,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 4),
                      if (_currentEmail.isNotEmpty)
                        Text(
                          _currentEmail,
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 24),
                      Card(
                        color: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              _buildSectionHeader(Icons.person_pin_outlined, 'Informasi Pribadi'),
                              TextFormField( // Name
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: 'Name',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  prefixIcon: const Icon(Icons.person_outline),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Name cannot be empty';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  prefixIcon: const Icon(Icons.email_outlined),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Email cannot be empty';
                                  }
                                  final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
                                  if (!emailRegex.hasMatch(value)) {
                                    return 'Enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              _buildSectionHeader(Icons.lock_person_outlined, 'Ubah Password'),
                              _buildPasswordTextField(
                                controller: _currentPasswordController,
                                labelText: 'Password Saat Ini',
                                isObscured: _isCurrentPasswordObscured,
                                onToggleVisibility: () => setState(() => _isCurrentPasswordObscured = !_isCurrentPasswordObscured),
                                validator: (value) {
                                  if (_newPasswordController.text.isNotEmpty && (value == null || value.isEmpty)) {
                                    return 'Password saat ini diperlukan untuk mengubah password';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              _buildPasswordTextField(
                                controller: _newPasswordController,
                                labelText: 'Password Baru',
                                isObscured: _isNewPasswordObscured,
                                onToggleVisibility: () => setState(() => _isNewPasswordObscured = !_isNewPasswordObscured),
                                validator: (value) {
                                  if (value != null && value.isNotEmpty && value.length < 8) {
                                    return 'Password baru minimal 8 karakter';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              _buildPasswordTextField(
                                controller: _newPasswordConfirmationController,
                                labelText: 'Konfirmasi Password Baru',
                                isObscured: _isConfirmPasswordObscured,
                                onToggleVisibility: () => setState(() => _isConfirmPasswordObscured = !_isConfirmPasswordObscured),
                                validator: (value) {
                                  if (_newPasswordController.text.isNotEmpty && (value == null || value.isEmpty)) {
                                    return 'Konfirmasi password baru tidak boleh kosong';
                                  }
                                  if (_newPasswordController.text.isNotEmpty && value != _newPasswordController.text) {
                                    return 'Konfirmasi password tidak cocok dengan password baru';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                            child: const Text('Discard', style: TextStyle(color: Colors.white, fontSize: 16)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _isLoading ? null : _saveChanges,
                            child: _isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16)),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
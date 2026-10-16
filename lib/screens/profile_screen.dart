import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme.dart';
import '../core/utils.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _age = 25;
  double _weight = 68;
  double _height = 172;
  // ใช้ค่าภาษาไทยเป็นค่าหลักในระบบ (Backend) เพื่อไม่ให้ข้อมูลเดิมใน Firebase พัง
  String _gender = 'ชาย'; 
  String _statusType = 'บุคคลทั่วไป'; 
  String _statusDetail = 'ไตรมาสที่ 2'; 
  String _name = 'สมชาย ใจดี'; 
  String? _imagePath; 
  String _profileIcon = 'person';
  String _selectedLanguage = 'th';

  double _dailyTarget = 2400;

  final TextEditingController _nameController = TextEditingController(); 
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  StreamSubscription<DatabaseEvent>? _subscription;

  // 🌟 พจนานุกรมแปลภาษาหน้าโปรไฟล์
  final Map<String, Map<String, String>> _localizedTexts = {
    'th': {
      'title': 'โปรไฟล์ของฉัน',
      'subtitle': 'จัดการข้อมูลส่วนตัวและการตั้งค่า',
      'target': 'เป้าหมายการดื่มน้ำต่อวัน',
      'target_hint': 'แสดงเป้าหมายปัจจุบัน (จะอัปเดตเมื่อกดปุ่มบันทึกข้อมูล)',
      'personal_info': 'ข้อมูลส่วนตัว',
      'gender': 'เพศ',
      'male': 'ชาย',
      'female': 'หญิง',
      'special_status': 'สถานะพิเศษ',
      'general': 'บุคคลทั่วไป',
      'pregnant': 'หญิงตั้งครรภ์',
      'breastfeeding': 'หญิงให้นมบุตร',
      'pregnancy_term': 'ระยะตั้งครรภ์',
      'trimester_1': 'ไตรมาสที่ 1',
      'trimester_2': 'ไตรมาสที่ 2',
      'trimester_3': 'ไตรมาสที่ 3',
      'child_age': 'ช่วงอายุของบุตร',
      'month_0_5': '0-5 เดือน',
      'month_6_11': '6-11 เดือน',
      'age': 'อายุ',
      'weight': 'น้ำหนัก',
      'height': 'ส่วนสูง',
      'info_notice': 'ข้อมูลทั้งหมดรวมถึงภาษา รูปโปรไฟล์ และชื่อจะบันทึกเมื่อกดปุ่ม "บันทึกข้อมูล" ด้านล่าง',
      'save': 'บันทึกข้อมูล',
      'saved_success': 'บันทึกข้อมูลเรียบร้อยแล้ว',
    },
    'en': {
      'title': 'My Profile',
      'subtitle': 'Manage personal info and settings',
      'target': 'Daily Water Intake Goal',
      'target_hint': 'Current goal (updates when you press save)',
      'personal_info': 'Personal Information',
      'gender': 'Gender',
      'male': 'Male',
      'female': 'Female',
      'special_status': 'Special Status',
      'general': 'General',
      'pregnant': 'Pregnant',
      'breastfeeding': 'Breastfeeding',
      'pregnancy_term': 'Pregnancy Trimester',
      'trimester_1': '1st Trimester',
      'trimester_2': '2nd Trimester',
      'trimester_3': '3rd Trimester',
      'child_age': 'Child\'s Age',
      'month_0_5': '0-5 Months',
      'month_6_11': '6-11 Months',
      'age': 'Age',
      'weight': 'Weight',
      'height': 'Height',
      'info_notice': 'All info including language, picture, and name will update when you press "Save Profile" below.',
      'save': 'Save Profile',
      'saved_success': 'Profile saved successfully',
    }
  };

  String _t(String key) {
    return _localizedTexts[_selectedLanguage]?[key] ?? key;
  }

  @override
  void initState() {
    super.initState();
    _nameController.text = _name;
    _ageController.text = '$_age';
    _weightController.text = '$_weight';
    _heightController.text = '$_height';

    _dailyTarget = _calculateHybridTarget(_age, _gender, _weight, _statusType, _statusDetail);
    _listenFirebase();
  }

  double _calculateHybridTarget(int age, String gender, double currentWeight, String statusType, String statusDetail) {
    double baseTarget = 2400;
    double standardWeight = 60;

    if (gender == 'ชาย') {
      if (age <= 0) { baseTarget = 1000; standardWeight = 5.7; }
      else if (age <= 1) { baseTarget = 1000; standardWeight = 8.7; }
      else if (age <= 3) { baseTarget = 1250; standardWeight = 13.1; }
      else if (age <= 5) { baseTarget = 1625; standardWeight = 18.3; }
      else if (age <= 8) { baseTarget = 1750; standardWeight = 23.0; }
      else if (age <= 12) { baseTarget = 2125; standardWeight = 35.6; }
      else if (age <= 15) { baseTarget = 2525; standardWeight = 51.5; }
      else if (age <= 18) { baseTarget = 2812; standardWeight = 58.3; }
      else if (age <= 30) { baseTarget = 2687; standardWeight = 61.3; }
      else if (age <= 70) { baseTarget = 2625; standardWeight = 58.7; }
      else { baseTarget = 2187; standardWeight = 56.2; }
    } else {
      if (age <= 0) { baseTarget = 1000; standardWeight = 5.3; }
      else if (age <= 1) { baseTarget = 1000; standardWeight = 8.0; }
      else if (age <= 3) { baseTarget = 1250; standardWeight = 12.5; }
      else if (age <= 5) { baseTarget = 1625; standardWeight = 18.1; }
      else if (age <= 8) { baseTarget = 1750; standardWeight = 22.5; }
      else if (age <= 12) { baseTarget = 2000; standardWeight = 36.5; }
      else if (age <= 15) { baseTarget = 2175; standardWeight = 47.7; }
      else if (age <= 18) { baseTarget = 2312; standardWeight = 48.9; }
      else if (age <= 70) { baseTarget = 2187; standardWeight = 52.2; }
      else { baseTarget = 1937; standardWeight = 48.5; }
    }

    double ratio = baseTarget / standardWeight;
    double calculated = ratio * currentWeight;

    if (gender == 'หญิง') {
      if (statusType == 'หญิงตั้งครรภ์') {
        if (statusDetail == 'ไตรมาสที่ 2' || statusDetail == 'ไตรมาสที่ 3') {
          calculated += 300; 
        }
      } else if (statusType == 'หญิงให้นมบุตร') {
        calculated += 500; 
      }
    }

    return calculated.clamp(1000.0, 5000.0);
  }

  void _listenFirebase() {
    if (!isFirebaseReady()) return;

    try {
      _subscription = smartCupRef('profile').onValue.listen((event) {
        final data = event.snapshot.value;
        if (data == null) return;

        Map<dynamic, dynamic> mapData;
        try {
          mapData = Map<dynamic, dynamic>.from(data as dynamic);
        } catch (_) { return; }

        if (!mounted) return;

        final name = mapData['name']?.toString() ?? _name;
        final imagePath = mapData['image_path']?.toString();
        final profileIcon = mapData['profile_icon']?.toString() ?? _profileIcon;
        final language = mapData['language']?.toString() ?? _selectedLanguage;
        final age = int.tryParse('${mapData['age'] ?? _age}') ?? _age;
        final weight = double.tryParse('${mapData['weight'] ?? _weight}') ?? _weight;
        final height = double.tryParse('${mapData['height'] ?? _height}') ?? _height;
        final gender = mapData['gender']?.toString() ?? _gender;
        final statusType = mapData['status_type']?.toString() ?? _statusType;
        final statusDetail = mapData['status_detail']?.toString() ?? _statusDetail;

        final target = double.tryParse(
              '${mapData['daily_target'] ?? _calculateHybridTarget(age, gender, weight, statusType, statusDetail)}',
            ) ?? _calculateHybridTarget(age, gender, weight, statusType, statusDetail);

        setState(() {
          _name = name;
          _imagePath = imagePath;
          _profileIcon = profileIcon;
          _selectedLanguage = language;
          _age = age;
          _weight = weight;
          _height = height;
          _gender = gender;
          _statusType = statusType;
          _statusDetail = statusDetail;
          _dailyTarget = target;

          _nameController.text = _name;
          _ageController.text = '$_age';
          _weightController.text = '$_weight';
          _heightController.text = '$_height';
        });
      });
    } catch (e) {
      debugPrint('Profile Firebase error: $e');
    }
  }

  void _changeLanguage(String lang) {
    setState(() {
      _selectedLanguage = lang;
    });
    if (isFirebaseReady()) {
      smartCupRef('profile').update({'language': lang});
    }
  }

  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imagePath = image.path;
      });
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('จัดการรูปโปรไฟล์', style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold, fontSize: 18)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF3949AB)),
                title: const Text('อัปโหลดรูปจากเครื่อง'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.emoji_emotions, color: Color(0xFF3949AB)),
                title: const Text('เลือกไอคอนสำเร็จรูป'),
                onTap: () {
                  Navigator.pop(context);
                  _showIconPicker();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ไม่เปลี่ยนแล้ว (กลับหน้าโปรไฟล์)', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showIconPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final icons = ['person', 'face', 'sentiment_satisfied', 'emoji_emotions', 'pets', 'local_fire_department'];
        return AlertDialog(
          title: const Text('เลือกไอคอน', style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold)),
          content: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: icons.map((iconName) {
              IconData iconData;
              switch (iconName) {
                case 'face': iconData = Icons.face; break;
                case 'sentiment_satisfied': iconData = Icons.sentiment_satisfied; break;
                case 'emoji_emotions': iconData = Icons.emoji_emotions; break;
                case 'pets': iconData = Icons.pets; break;
                case 'local_fire_department': iconData = Icons.local_fire_department; break;
                default: iconData = Icons.person;
              }
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _imagePath = null;
                    _profileIcon = iconName;
                  });
                  Navigator.pop(context);
                },
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: _profileIcon == iconName ? const Color(0xFF3949AB) : const Color(0xFFEEF2F9),
                  child: Icon(iconData, color: _profileIcon == iconName ? Colors.white : const Color(0xFF3949AB), size: 30),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  IconData _getProfileIconData(String name) {
    switch (name) {
      case 'face': return Icons.face;
      case 'sentiment_satisfied': return Icons.sentiment_satisfied;
      case 'emoji_emotions': return Icons.emoji_emotions;
      case 'pets': return Icons.pets;
      case 'local_fire_department': return Icons.local_fire_department;
      default: return Icons.person;
    }
  }

  void _showEditNameDialog() {
    _nameController.text = _name;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('แก้ไขชื่อโปรไฟล์', style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold)),
          content: TextField(
            controller: _nameController,
            autofocus: true,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
            decoration: InputDecoration(
              hintText: 'กรอกชื่อของคุณ',
              filled: true,
              fillColor: const Color(0xFFEEF2F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  if (_nameController.text.trim().isNotEmpty) {
                    _name = _nameController.text.trim();
                  }
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3949AB), foregroundColor: Colors.white),
              child: const Text('ตกลง'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    final age = int.tryParse(_ageController.text) ?? _age;
    final weight = double.tryParse(_weightController.text) ?? _weight;
    final height = double.tryParse(_heightController.text) ?? _height;
    
    final target = _calculateHybridTarget(age, _gender, weight, _statusType, _statusDetail);

    setState(() {
      _age = age;
      _weight = weight;
      _height = height;
      _dailyTarget = target;
    });

    if (!isFirebaseReady()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกในเครื่องแล้ว (Firebase ยังไม่ได้เชื่อมต่อ)')),
      );
      return;
    }

    try {
      await smartCupRef('profile').update({
        'name': _name,
        'image_path': _imagePath ?? '',
        'profile_icon': _profileIcon,
        'language': _selectedLanguage,
        'age': age,
        'weight': weight,
        'height': height,
        'gender': _gender,
        'status_type': _statusType,
        'status_detail': _statusDetail,
        'daily_target': target,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('saved_success'))),
      );
    } catch (e) {
      debugPrint('Profile save error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถบันทึกข้อมูลได้')));
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t('title'),
                            style: const TextStyle(
                              color: Color(0xFF1A237E),
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _t('subtitle'),
                            style: const TextStyle(color: textGrey, fontSize: 14),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _changeLanguage('th'),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _selectedLanguage == 'th' ? const Color(0xFF3949AB).withValues(alpha: 0.2) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedLanguage == 'th' ? const Color(0xFF3949AB) : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: const Text('🇹🇭', style: TextStyle(fontSize: 24)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _changeLanguage('en'),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _selectedLanguage == 'en' ? const Color(0xFF3949AB).withValues(alpha: 0.2) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedLanguage == 'en' ? const Color(0xFF3949AB) : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: const Text('🇬🇧', style: TextStyle(fontSize: 24)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  _buildProfileHeader(),
                  const SizedBox(height: 24),
                  
                  _buildTargetCard(),
                  const SizedBox(height: 24),
                  
                  _buildPersonalInfo(),
                  const SizedBox(height: 30),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveProfile,
                      icon: const Icon(Icons.save),
                      label: Text(_t('save'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3949AB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3949AB), Color(0xFF1A237E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withValues(alpha: 0.3),
            blurRadius: 25,
            offset: const Offset(0, 12),
          )
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showImageSourceDialog,
            child: Stack(
              children: [
                Container(
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 3),
                    image: (_imagePath != null && _imagePath!.isNotEmpty)
                        ? DecorationImage(
                            image: FileImage(File(_imagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: (_imagePath == null || _imagePath!.isEmpty)
                      ? Icon(_getProfileIconData(_profileIcon), color: const Color(0xFF3949AB), size: 40)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, size: 14, color: Color(0xFF1A237E)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _showEditNameDialog,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit, color: Colors.amberAccent, size: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'SmartCup User',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3949AB).withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EAF6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.water_drop, color: Color(0xFF3949AB), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                _t('target'),
                style: const TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '${_dailyTarget.toInt()} ml',
            style: const TextStyle(
              color: Color(0xFF3949AB),
              fontSize: 36,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _t('target_hint'),
            style: const TextStyle(color: textGrey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3949AB).withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('personal_info'),
            style: const TextStyle(color: Color(0xFF1A237E), fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          Text(_t('gender'), style: const TextStyle(color: textGrey, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: ['ชาย', 'หญิง'].map((genderKey) {
              final isSelected = _gender == genderKey;
              String labelText = genderKey == 'ชาย' ? _t('male') : _t('female');
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: genderKey == 'ชาย' ? 8.0 : 0.0),
                  child: ChoiceChip(
                    label: Center(
                      child: Text(
                        labelText,
                        style: TextStyle(
                          color: isSelected ? Colors.white : textGrey,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _gender = genderKey;
                        if (_gender == 'ชาย') {
                          _statusType = 'บุคคลทั่วไป';
                        }
                      });
                    },
                    backgroundColor: const Color(0xFFEEF2F9),
                    selectedColor: const Color(0xFF3949AB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide.none,
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              );
            }).toList(),
          ),

          // 🌟 ฟื้นฟูระบบตั้งครรภ์/ให้นมบุตร สำหรับเพศหญิง
          if (_gender == 'หญิง') ...[
            const SizedBox(height: 16),
            Text(_t('special_status'), style: const TextStyle(color: textGrey, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _statusType,
              dropdownColor: Colors.white,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFEEF2F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: ['บุคคลทั่วไป', 'หญิงตั้งครรภ์', 'หญิงให้นมบุตร'].map((String value) {
                String translatedValue = value;
                if (value == 'บุคคลทั่วไป') translatedValue = _t('general');
                if (value == 'หญิงตั้งครรภ์') translatedValue = _t('pregnant');
                if (value == 'หญิงให้นมบุตร') translatedValue = _t('breastfeeding');

                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(translatedValue, style: const TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.w500)),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _statusType = newValue;
                    if (_statusType == 'หญิงตั้งครรภ์') {
                      _statusDetail = 'ไตรมาสที่ 2';
                    } else if (_statusType == 'หญิงให้นมบุตร') {
                      _statusDetail = '0-5 เดือน';
                    }
                  });
                }
              },
            ),

            if (_statusType == 'หญิงตั้งครรภ์') ...[
              const SizedBox(height: 12),
              Text(_t('pregnancy_term'), style: const TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Row(
                children: ['ไตรมาสที่ 1', 'ไตรมาสที่ 2', 'ไตรมาสที่ 3'].map((trimester) {
                  final isSelected = _statusDetail == trimester;
                  String labelText = trimester;
                  if (trimester == 'ไตรมาสที่ 1') labelText = _t('trimester_1');
                  if (trimester == 'ไตรมาสที่ 2') labelText = _t('trimester_2');
                  if (trimester == 'ไตรมาสที่ 3') labelText = _t('trimester_3');

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ChoiceChip(
                        label: Center(
                          child: Text(
                            labelText,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white : textGrey,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _statusDetail = trimester;
                          });
                        },
                        backgroundColor: const Color(0xFFEEF2F9),
                        selectedColor: const Color(0xFF3949AB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide.none,
                        ),
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            if (_statusType == 'หญิงให้นมบุตร') ...[
              const SizedBox(height: 12),
              Text(_t('child_age'), style: const TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Row(
                children: ['0-5 เดือน', '6-11 เดือน'].map((period) {
                  final isSelected = _statusDetail == period;
                  String labelText = period;
                  if (period == '0-5 เดือน') labelText = _t('month_0_5');
                  if (period == '6-11 เดือน') labelText = _t('month_6_11');

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ChoiceChip(
                        label: Center(
                          child: Text(
                            labelText,
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected ? Colors.white : textGrey,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _statusDetail = period;
                          });
                        },
                        backgroundColor: const Color(0xFFEEF2F9),
                        selectedColor: const Color(0xFF3949AB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide.none,
                        ),
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],

          const SizedBox(height: 16),
          _numberField(controller: _ageController, label: _t('age'), suffix: _selectedLanguage == 'th' ? 'ปี' : 'yrs', icon: Icons.cake_outlined),
          const SizedBox(height: 16),
          _numberField(controller: _weightController, label: _t('weight'), suffix: 'kg', icon: Icons.monitor_weight_outlined),
          const SizedBox(height: 16),
          _numberField(controller: _heightController, label: _t('height'), suffix: 'cm', icon: Icons.height_outlined),
          const SizedBox(height: 20),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF3949AB), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _t('info_notice'),
                    style: const TextStyle(color: Color(0xFF1A237E), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: textGrey, fontWeight: FontWeight.normal),
        suffixText: suffix,
        suffixStyle: const TextStyle(color: textGrey, fontWeight: FontWeight.bold),
        prefixIcon: Icon(icon, color: const Color(0xFF3949AB)),
        filled: true,
        fillColor: const Color(0xFFEEF2F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF3949AB), width: 1.5),
        ),
      ),
    );
  }
}
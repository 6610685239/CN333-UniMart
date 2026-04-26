const authService = require('../services/auth.service');
const { supabase } = require('../models');

const AVATAR_BUCKET = 'product-images'; // reuse existing public bucket

async function verify(req, res) {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ success: false, message: 'กรุณากรอกรหัสนักศึกษาและรหัสผ่าน' });
  }

  try {
    const tuData = await authService.verifyTuApi(username, password);

    if (tuData.status === false) {
      return res.status(401).json({
        success: false,
        message: 'รหัสนักศึกษาหรือรหัสผ่านไม่ถูกต้อง กรุณาใช้รหัสเดียวกับระบบ reg.tu.ac.th'
      });
    }

    const existingUser = await authService.findUserByUsername(tuData.username);

    if (existingUser) {
      // ถ้ามีบัญชีแต่ยังไม่มีรหัสผ่าน UniMart → ให้ตั้งรหัสผ่านก่อน
      if (!existingUser.password_hash) {
        const tuProfile = authService.buildTuProfile(tuData);
        return res.json({ success: true, action: 'GO_TO_REGISTER', tuProfile, statusWarning: null });
      }
      return res.json({ success: true, action: 'LOGIN_EXISTS', message: 'รหัสนักศึกษานี้ลงทะเบียนแล้ว กรุณาเข้าสู่ระบบ' });
    }

    const tuProfile = authService.buildTuProfile(tuData);

    let statusWarning = null;
    const status = tuProfile.tu_status;
    if (status && status !== 'ปกติ' && status !== '1') {
      statusWarning = `สถานะปัจจุบันของคุณ: ${status}`;
    }

    return res.json({ success: true, action: 'GO_TO_REGISTER', tuProfile, statusWarning });

  } catch (err) {
    if (err.code === 'ECONNABORTED' || err.code === 'ETIMEDOUT' || err.code === 'ENOTFOUND') {
      return res.status(503).json({ success: false, message: 'ไม่สามารถเชื่อมต่อระบบยืนยันตัวตนได้ กรุณาลองใหม่อีกครั้ง' });
    }
    if (err.response && err.response.status === 429) {
      return res.status(429).json({ success: false, message: 'ระบบยืนยันตัวตนมีผู้ใช้งานมาก กรุณาลองใหม่ภายหลัง' });
    }
    console.error('Auth Verify Error:', err.message);
    res.status(500).json({ success: false, message: 'เกิดข้อผิดพลาด กรุณาลองใหม่', error: err.message });
  }
}

async function register(req, res) {
  const {
    username, phone_number, personal_email,
    tu_email, display_name_th, display_name_en,
    faculty, department, user_type, organization,
    tu_status, status_id, dormitory_zone,
    app_password
  } = req.body;

  if (!username || !app_password) {
    return res.status(400).json({ success: false, message: 'กรุณากรอกข้อมูลให้ครบถ้วน' });
  }

  try {
    const result = await authService.registerUser({
      username, phone_number, personal_email,
      tu_email, display_name_th, display_name_en,
      faculty, department, user_type, organization,
      tu_status, status_id, dormitory_zone,
      app_password
    });

    if (result.conflict) {
      return res.status(409).json({ success: false, message: 'รหัสนักศึกษานี้ลงทะเบียนแล้ว กรุณาเข้าสู่ระบบ' });
    }

    res.json({ success: true, message: 'ลงทะเบียนสำเร็จ!', user: result.user, token: result.token });
  } catch (err) {
    console.error('Register Error:', err.message);
    res.status(500).json({ success: false, message: 'บันทึกข้อมูลไม่สำเร็จ', error: err.message });
  }
}

async function login(req, res) {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ success: false, message: 'กรุณากรอกรหัสนักศึกษาและรหัสผ่าน' });
  }

  try {
    const result = await authService.loginUser(username, password);

    if (result.error === 'WRONG_PASSWORD') {
      return res.status(401).json({ success: false, message: 'รหัสนักศึกษาหรือรหัสผ่านไม่ถูกต้อง กรุณาใช้รหัสเดียวกับระบบ reg.tu.ac.th' });
    }
    if (result.error === 'TU_UNAVAILABLE') {
      return res.status(503).json({ success: false, message: 'ไม่สามารถเชื่อมต่อระบบยืนยันตัวตนได้ กรุณาลองใหม่อีกครั้ง' });
    }
    if (result.error === 'TU_RATE_LIMIT') {
      return res.status(429).json({ success: false, message: 'ระบบยืนยันตัวตนมีผู้ใช้งานมาก กรุณาลองใหม่ภายหลัง' });
    }

    res.json({ success: true, user: result.user, token: result.token });
  } catch (err) {
    console.error('Login Error:', err.message);
    res.status(500).json({ success: false, message: 'เกิดข้อผิดพลาด กรุณาลองใหม่', error: err.message });
  }
}

async function uploadAvatar(req, res) {
  const { userId } = req.params;

  if (!req.file) {
    return res.status(400).json({ success: false, message: 'กรุณาเลือกรูปภาพ' });
  }

  console.log('[uploadAvatar] userId:', userId);
  console.log('[uploadAvatar] file:', req.file.originalname, req.file.mimetype, req.file.size, 'buffer length:', req.file.buffer?.length);

  try {
    // Fixed filename per user → upsert will overwrite old avatar (no space accumulation)
    const fileName = `avatars/avatar-${userId}`;

    // Normalize content type (fallback if client sends octet-stream)
    const contentType = req.file.mimetype === 'application/octet-stream'
      ? 'image/jpeg'
      : req.file.mimetype;

    console.log('[uploadAvatar] uploading to bucket:', AVATAR_BUCKET, 'path:', fileName, 'contentType:', contentType);

    // Upload buffer to Supabase Storage
    const { data: uploadData, error: uploadError } = await supabase.storage
      .from(AVATAR_BUCKET)
      .upload(fileName, req.file.buffer, {
        contentType,
        upsert: true,
      });

    console.log('[uploadAvatar] upload result:', JSON.stringify(uploadData), 'error:', JSON.stringify(uploadError));

    if (uploadError) {
      return res.status(500).json({ success: false, message: 'อัปโหลดรูปไม่สำเร็จ', detail: uploadError.message });
    }

    // Get public URL
    const { data: urlData } = supabase.storage
      .from(AVATAR_BUCKET)
      .getPublicUrl(fileName);

    const publicUrl = urlData.publicUrl;
    console.log('[uploadAvatar] publicUrl:', publicUrl);

    // Save full URL to database
    const { error: dbError } = await supabase
      .from('users')
      .update({ avatar: publicUrl })
      .eq('id', userId);

    if (dbError) {
      console.error('[uploadAvatar] DB error:', dbError.message);
      return res.status(500).json({ success: false, message: 'บันทึก URL ไม่สำเร็จ', detail: dbError.message });
    }

    res.json({ success: true, avatar: publicUrl });
  } catch (err) {
    console.error('[uploadAvatar] catch error:', err.message);
    res.status(500).json({ success: false, message: 'อัปโหลดรูปไม่สำเร็จ', detail: err.message });
  }
}

async function getUserProfile(req, res) {
  const { userId } = req.params;

  try {
    const user = await authService.getUserProfile(userId);
    if (!user) {
      return res.status(404).json({ success: false, message: 'ไม่พบผู้ใช้' });
    }
    res.json({ success: true, user });
  } catch (err) {
    console.error('Get User Profile Error:', err.message);
    res.status(500).json({ success: false, message: 'เกิดข้อผิดพลาด' });
  }
}

async function updateUserProfile(req, res) {
  const { userId } = req.params;
  const { phone_number, personal_email, dormitory_zone } = req.body;

  try {
    const user = await authService.updateUserProfile(userId, { phone_number, personal_email, dormitory_zone });
    const { password_hash: _, ...safeUser } = user;
    res.json({ success: true, user: safeUser });
  } catch (err) {
    console.error('Update Profile Error:', err.message);
    res.status(500).json({ success: false, message: 'อัปเดตข้อมูลไม่สำเร็จ', error: err.message });
  }
}

module.exports = { verify, register, login, uploadAvatar, getUserProfile, updateUserProfile };

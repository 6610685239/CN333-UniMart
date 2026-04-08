const axios = require('axios');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { supabase, JWT_SECRET, SALT_ROUNDS } = require('../models');

async function verifyTuApi(username, password) {
  const tuResponse = await axios.post(
    'https://restapi.tu.ac.th/api/v1/auth/Ad/verify',
    { UserName: username, PassWord: password },
    {
      headers: {
        'Content-Type': 'application/json',
        'Application-Key': process.env.TU_API_KEY
      },
      timeout: 10000
    }
  );
  return tuResponse.data;
}

async function findUserByUsername(username) {
  const { data: existingUser } = await supabase
    .from('users')
    .select('*')
    .eq('username', username)
    .single();
  return existingUser;
}

function buildTuProfile(tuData) {
  return {
    username: tuData.username,
    display_name_th: tuData.displayname_th,
    display_name_en: tuData.displayname_en,
    email: tuData.email,
    department: tuData.department,
    faculty: tuData.faculty,
    type: tuData.type,
    tu_status: tuData.tu_status || tuData.StatusEmp || null,
    status_id: tuData.statusid || tuData.StatusWork || null,
    organization: tuData.organization || null
  };
}

async function registerUser(userData) {
  const { username, app_password, ...rest } = userData;

  // ตรวจสอบ username ซ้ำ
  const { data: existing } = await supabase
    .from('users')
    .select('id, password_hash')
    .eq('username', username)
    .single();

  // Hash รหัสผ่าน UniMart (ไม่เก็บรหัสผ่าน TU)
  const password_hash = await bcrypt.hash(app_password, SALT_ROUNDS);

  if (existing) {
    // ถ้ามีบัญชีแล้วและมี password_hash → conflict จริง
    if (existing.password_hash) {
      return { conflict: true };
    }
    // ถ้ามีบัญชีแต่ยังไม่มีรหัสผ่าน (บัญชีเก่า Iteration 1) → update password_hash
    const { data, error } = await supabase
      .from('users')
      .update({ password_hash, ...rest })
      .eq('username', username)
      .select();

    if (error) throw error;

    const token = jwt.sign(
      { userId: data[0].id, username: data[0].username },
      JWT_SECRET,
      { expiresIn: '30d' }
    );

    return { user: data[0], token };
  }

  const { data, error } = await supabase
    .from('users')
    .insert([{ username, password_hash, ...rest }])
    .select();

  if (error) throw error;

  const token = jwt.sign(
    { userId: data[0].id, username: data[0].username },
    JWT_SECRET,
    { expiresIn: '30d' }
  );

  return { user: data[0], token };
}

async function loginUser(username, password) {
  const { data: user } = await supabase
    .from('users')
    .select('*')
    .eq('username', username)
    .single();

  if (!user) {
    return { error: 'NOT_FOUND' };
  }

  if (!user.password_hash) {
    return { error: 'NO_PASSWORD' };
  }

  const isMatch = await bcrypt.compare(password, user.password_hash);
  if (!isMatch) {
    return { error: 'WRONG_PASSWORD' };
  }

  const token = jwt.sign(
    { userId: user.id, username: user.username },
    JWT_SECRET,
    { expiresIn: '30d' }
  );

  const { password_hash: _, ...safeUser } = user;
  return { user: safeUser, token };
}

async function changePassword(userId, currentPassword, newPassword) {
  console.log('changePassword called for userId:', userId);
  
  const { data: user, error: fetchError } = await supabase
    .from('users')
    .select('id, password_hash')
    .eq('id', userId)
    .single();

  if (fetchError) {
    console.error('changePassword fetch error:', fetchError.message);
    return { error: 'NOT_FOUND' };
  }

  if (!user) return { error: 'NOT_FOUND' };
  if (!user.password_hash) return { error: 'NO_PASSWORD' };

  const isMatch = await bcrypt.compare(currentPassword, user.password_hash);
  console.log('Password match:', isMatch);
  if (!isMatch) return { error: 'WRONG_PASSWORD' };

  const newHash = await bcrypt.hash(newPassword, SALT_ROUNDS);
  const { error: updateError } = await supabase
    .from('users')
    .update({ password_hash: newHash })
    .eq('id', userId);

  if (updateError) {
    console.error('changePassword update error:', updateError.message);
    throw new Error(updateError.message);
  }

  return { success: true };
}

async function getUserProfile(userId) {
  const { data: user, error } = await supabase
    .from('users')
    .select('id, display_name_th, display_name_en, username, faculty, department, tu_status, avatar')
    .eq('id', userId)
    .single();

  if (error || !user) return null;
  return user;
}

module.exports = {
  verifyTuApi,
  findUserByUsername,
  buildTuProfile,
  registerUser,
  loginUser,
  changePassword,
  getUserProfile
};

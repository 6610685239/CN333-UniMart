const { supabase } = require('../models');

async function sendFcmNotification(fcmToken, title, body, data) {
  // Placeholder/mock FCM sending — จะเชื่อมต่อ Firebase Admin SDK จริงในอนาคต
  console.log(`[FCM Mock] Sending to token=${fcmToken}, title="${title}", body="${body}"`);
  return { success: true, messageId: 'mock-message-id-' + Date.now() };
}

async function createNotification(userId, type, title, body, data = {}) {
  // 1. บันทึก notification ลงตารางเสมอ (แม้ปิด push)
  const { data: notification, error: insertError } = await supabase
    .from('notifications')
    .insert([{
      user_id: userId,
      type,
      title,
      body,
      data,
      is_read: false
    }])
    .select()
    .single();

  if (insertError) {
    console.error('Create Notification Error:', insertError.message);
    throw insertError;
  }

  // 2. ตรวจสอบ notification_settings ของ user
  const { data: settings } = await supabase
    .from('notification_settings')
    .select('*')
    .eq('user_id', userId)
    .single();

  // 3. ถ้า push_enabled → ส่ง FCM (placeholder)
  const pushEnabled = settings ? settings.push_enabled : true;
  const fcmToken = settings ? settings.fcm_token : null;

  // ตรวจสอบ type-specific settings
  let shouldSendPush = pushEnabled && fcmToken;
  if (shouldSendPush && settings) {
    if (type === 'chat_message' && settings.chat_notifications === false) {
      shouldSendPush = false;
    }
    if (type === 'transaction_update' && settings.transaction_notifications === false) {
      shouldSendPush = false;
    }
  }

  if (shouldSendPush) {
    // Retry up to 3 times
    let retries = 0;
    const maxRetries = 3;
    while (retries < maxRetries) {
      try {
        await sendFcmNotification(fcmToken, title, body, data);
        break;
      } catch (fcmError) {
        retries++;
        console.error(`[FCM Error] Attempt ${retries}/${maxRetries}:`, fcmError.message);
        if (retries >= maxRetries) {
          console.error('[FCM Error] Max retries reached. Notification saved but push not sent.');
        }
      }
    }
  }

  return notification;
}

async function getUnreadCount(userId) {
  const { count, error } = await supabase
    .from('notifications')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('is_read', false);

  if (error) throw error;
  return count || 0;
}

async function updateSettings(userId, settingsData) {
  const { push_enabled, chat_notifications, transaction_notifications, fcm_token } = settingsData;

  const { data: existing } = await supabase
    .from('notification_settings')
    .select('id')
    .eq('user_id', userId)
    .single();

  const updateData = {};
  if (push_enabled !== undefined) updateData.push_enabled = push_enabled;
  if (chat_notifications !== undefined) updateData.chat_notifications = chat_notifications;
  if (transaction_notifications !== undefined) updateData.transaction_notifications = transaction_notifications;
  if (fcm_token !== undefined) updateData.fcm_token = fcm_token;
  updateData.updated_at = new Date().toISOString();

  let result;
  if (existing) {
    const { data, error } = await supabase
      .from('notification_settings')
      .update(updateData)
      .eq('user_id', userId)
      .select()
      .single();

    if (error) throw error;
    result = data;
  } else {
    const { data, error } = await supabase
      .from('notification_settings')
      .insert([{ user_id: userId, ...updateData }])
      .select()
      .single();

    if (error) throw error;
    result = data;
  }

  return result;
}

async function getUserNotifications(userId) {
  const { data: notifications, error } = await supabase
    .from('notifications')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false });

  if (error) throw error;

  return (notifications || []).map(n => ({
    id: n.id,
    userId: n.user_id,
    type: n.type,
    title: n.title,
    body: n.body,
    data: n.data,
    isRead: n.is_read,
    createdAt: n.created_at
  }));
}

async function markAsRead(id) {
  const { data: notification, error } = await supabase
    .from('notifications')
    .update({ is_read: true })
    .eq('id', id)
    .select()
    .single();

  if (error) {
    if (error.code === 'PGRST116') {
      return { notFound: true };
    }
    throw error;
  }

  return {
    id: notification.id,
    userId: notification.user_id,
    type: notification.type,
    title: notification.title,
    body: notification.body,
    data: notification.data,
    isRead: notification.is_read,
    createdAt: notification.created_at
  };
}

module.exports = {
  sendFcmNotification,
  createNotification,
  getUnreadCount,
  updateSettings,
  getUserNotifications,
  markAsRead
};

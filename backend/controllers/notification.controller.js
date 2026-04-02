const notificationService = require('../services/notification.service');

async function getUnreadCount(req, res) {
  const { userId } = req.params;

  try {
    const unreadCount = await notificationService.getUnreadCount(userId);
    res.json({ unreadCount });
  } catch (err) {
    console.error('Get Unread Count Error:', err.message);
    res.status(500).json({ success: false, message: 'ไม่สามารถดึงจำนวนแจ้งเตือนที่ยังไม่อ่านได้', error: err.message });
  }
}

async function updateSettings(req, res) {
  const { userId } = req.params;

  try {
    const result = await notificationService.updateSettings(userId, req.body);
    res.json(result);
  } catch (err) {
    console.error('Update Notification Settings Error:', err.message);
    res.status(500).json({ success: false, message: 'ไม่สามารถอัปเดตการตั้งค่าแจ้งเตือนได้', error: err.message });
  }
}

async function getUserNotifications(req, res) {
  const { userId } = req.params;

  try {
    const result = await notificationService.getUserNotifications(userId);
    res.json(result);
  } catch (err) {
    console.error('Get Notifications Error:', err.message);
    res.status(500).json({ success: false, message: 'ไม่สามารถดึงรายการแจ้งเตือนได้', error: err.message });
  }
}

async function markAsRead(req, res) {
  const { id } = req.params;

  try {
    const result = await notificationService.markAsRead(id);

    if (result.notFound) {
      return res.status(404).json({ success: false, message: 'ไม่พบแจ้งเตือน' });
    }

    res.json(result);
  } catch (err) {
    console.error('Mark Notification Read Error:', err.message);
    res.status(500).json({ success: false, message: 'ไม่สามารถอัปเดตสถานะแจ้งเตือนได้', error: err.message });
  }
}

module.exports = { getUnreadCount, updateSettings, getUserNotifications, markAsRead };

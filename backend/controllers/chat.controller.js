const chatService = require('../services/chat.service');
const notificationService = require('../services/notification.service');

async function createRoom(req, res) {
  const { buyerId, sellerId, productId } = req.body;

  if (!buyerId || !sellerId || !productId) {
    return res.status(400).json({ success: false, message: 'กรุณาระบุ buyerId, sellerId, และ productId' });
  }

  try {
    const { room, created } = await chatService.createOrGetRoom(buyerId, sellerId, productId);
    res.status(created ? 201 : 200).json(room);
  } catch (err) {
    console.error('Create Chat Room Error:', err.message);
    res.status(500).json({ success: false, message: 'ไม่สามารถสร้างห้องสนทนาได้', error: err.message });
  }
}

async function getUserRooms(req, res) {
  const { userId } = req.params;

  if (!userId) {
    return res.status(400).json({ success: false, message: 'กรุณาระบุ userId' });
  }

  try {
    const result = await chatService.getUserRooms(userId);
    res.json(result);
  } catch (err) {
    console.error('Get Chat Rooms Error:', err.message);
    res.status(500).json({ success: false, message: 'ไม่สามารถดึงรายการห้องสนทนาได้', error: err.message });
  }
}

async function getMessages(req, res) {
  const { roomId } = req.params;
  const limit = parseInt(req.query.limit) || 50;
  const offset = parseInt(req.query.offset) || 0;

  try {
    const result = await chatService.getRoomMessages(roomId, limit, offset);

    if (result.notFound) {
      return res.status(404).json({ success: false, message: 'ไม่พบห้องสนทนา' });
    }

    res.json(result.messages);
  } catch (err) {
    console.error('Get Chat Messages Error:', err.message);
    res.status(500).json({ success: false, message: 'ไม่สามารถดึงข้อความได้', error: err.message });
  }
}

async function sendMessage(req, res) {
  const { roomId, senderId, content, imageUrl, type } = req.body;
  const msgType = type || 'text';

  if (!roomId || !senderId) {
    return res.status(400).json({ success: false, message: 'กรุณาระบุ roomId และ senderId' });
  }

  if (msgType === 'text' && (!content || content.trim() === '')) {
    return res.status(400).json({ success: false, message: 'กรุณากรอกข้อความ' });
  }

  if (msgType === 'image' && (!imageUrl || imageUrl.trim() === '')) {
    return res.status(400).json({ success: false, message: 'กรุณาระบุ URL รูปภาพ' });
  }

  try {
    const result = await chatService.sendMessage(roomId, senderId, content, imageUrl, type);

    if (result.notFound) {
      return res.status(404).json({ success: false, message: 'ไม่พบห้องสนทนา' });
    }

    res.status(201).json(result.message);
    const io = req.app.get('io');
    if (io) {
      io.to(roomId).emit('new_message', result.message);
    }

    // Fire-and-forget notification
    try {
      const { room } = result;
      const recipientId = senderId === room.buyer_id ? room.seller_id : room.buyer_id;
      await notificationService.createNotification(
        recipientId,
        'chat_message',
        'ข้อความใหม่',
        content?.substring(0, 100) || 'ส่งรูปภาพ',
        { roomId }
      );
    } catch (notifErr) {
      console.error('Chat Notification Error:', notifErr.message);
    }
  } catch (err) {
    console.error('Send Chat Message Error:', err.message);
    res.status(500).json({ success: false, message: 'ไม่สามารถส่งข้อความได้', error: err.message });
  }
}

async function createReport(req, res) {
  const { roomId, reporterId, reportedUserId, reason } = req.body;

  if (!roomId || !reporterId || !reportedUserId || !reason) {
    return res.status(400).json({ success: false, message: 'กรุณาระบุ roomId, reporterId, reportedUserId, และ reason' });
  }

  try {
    const report = await chatService.createReport(roomId, reporterId, reportedUserId, reason);
    res.status(201).json(report);
  } catch (err) {
    console.error('Create Chat Report Error:', err.message);
    res.status(500).json({ success: false, message: 'ไม่สามารถบันทึกรายงานได้', error: err.message });
  }
}


async function pinRoom(req, res) {
  const { roomId } = req.params;
  const { userId, isPinned } = req.body;
  try {
    await chatService.setChatRoomPinned(roomId, userId, isPinned);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
}

async function deleteRoom(req, res) {
  const { roomId } = req.params;
  const { userId, isDeleted } = req.body;
  try {
    await chatService.setChatRoomDeleted(roomId, userId, isDeleted !== false);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
}

module.exports = {
  pinRoom, deleteRoom, createRoom, getUserRooms, getMessages, sendMessage, createReport };

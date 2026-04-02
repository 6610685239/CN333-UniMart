const { supabase, prisma } = require('../models');

async function createOrGetRoom(buyerId, sellerId, productId) {
  // ตรวจสอบ room ที่มีอยู่แล้ว
  const { data: existingRoom, error: selectError } = await supabase
    .from('chat_rooms')
    .select('*')
    .eq('buyer_id', buyerId)
    .eq('seller_id', sellerId)
    .eq('product_id', productId)
    .single();

  if (selectError && selectError.code !== 'PGRST116') {
    throw selectError;
  }

  if (existingRoom) {
    return {
      room: {
        id: existingRoom.id,
        buyerId: existingRoom.buyer_id,
        sellerId: existingRoom.seller_id,
        productId: existingRoom.product_id,
        createdAt: existingRoom.created_at
      },
      created: false
    };
  }

  // สร้าง room ใหม่
  const { data: newRoom, error: insertError } = await supabase
    .from('chat_rooms')
    .insert([{
      buyer_id: buyerId,
      seller_id: sellerId,
      product_id: productId
    }])
    .select()
    .single();

  if (insertError) throw insertError;

  return {
    room: {
      id: newRoom.id,
      buyerId: newRoom.buyer_id,
      sellerId: newRoom.seller_id,
      productId: newRoom.product_id,
      createdAt: newRoom.created_at
    },
    created: true
  };
}

async function getUserRooms(userId) {
  // 1. ดึง rooms ที่ user เป็น buyer หรือ seller
  const { data: buyerRooms, error: buyerError } = await supabase
    .from('chat_rooms')
    .select('*')
    .eq('buyer_id', userId);

  if (buyerError) throw buyerError;

  const { data: sellerRooms, error: sellerError } = await supabase
    .from('chat_rooms')
    .select('*')
    .eq('seller_id', userId);

  if (sellerError) throw sellerError;

  // รวม rooms ทั้งหมด (ไม่ซ้ำ)
  const roomMap = new Map();
  for (const room of [...buyerRooms, ...sellerRooms]) {
    roomMap.set(room.id, room);
  }
  const allRooms = Array.from(roomMap.values());

  // 2. สำหรับแต่ละ room ดึงข้อมูลเพิ่มเติม
  const result = await Promise.all(allRooms.map(async (room) => {
    const otherUserId = room.buyer_id === userId ? room.seller_id : room.buyer_id;

    const otherUser = await prisma.users.findUnique({
      where: { id: otherUserId },
      select: { display_name_th: true, username: true }
    });

    const product = await prisma.product.findUnique({
      where: { id: room.product_id },
      select: { title: true }
    });

    const { data: lastMessages, error: msgError } = await supabase
      .from('chat_messages')
      .select('content, created_at, type')
      .eq('room_id', room.id)
      .order('created_at', { ascending: false })
      .limit(1);

    if (msgError) throw msgError;

    const lastMessage = lastMessages && lastMessages.length > 0
      ? { content: lastMessages[0].content, createdAt: lastMessages[0].created_at, type: lastMessages[0].type }
      : null;

    const { count: unreadCount, error: countError } = await supabase
      .from('chat_messages')
      .select('*', { count: 'exact', head: true })
      .eq('room_id', room.id)
      .eq('is_read', false)
      .neq('sender_id', userId);

    if (countError) throw countError;

    return {
      id: room.id,
      productTitle: product ? product.title : null,
      otherUser: {
        displayName: otherUser ? otherUser.display_name_th : null,
        username: otherUser ? otherUser.username : null
      },
      lastMessage,
      unreadCount: unreadCount || 0
    };
  }));

  // 3. เรียงตามข้อความล่าสุด (ใหม่สุดก่อน)
  result.sort((a, b) => {
    const timeA = a.lastMessage ? new Date(a.lastMessage.createdAt).getTime() : 0;
    const timeB = b.lastMessage ? new Date(b.lastMessage.createdAt).getTime() : 0;
    return timeB - timeA;
  });

  return result;
}

async function getRoomMessages(roomId, limit, offset) {
  // ตรวจสอบว่า room มีอยู่จริง
  const { data: room, error: roomError } = await supabase
    .from('chat_rooms')
    .select('id')
    .eq('id', roomId)
    .single();

  if (roomError && roomError.code === 'PGRST116') {
    return { notFound: true };
  }
  if (roomError) throw roomError;

  const { data: messages, error: msgError } = await supabase
    .from('chat_messages')
    .select('id, room_id, sender_id, content, image_url, type, is_read, created_at')
    .eq('room_id', roomId)
    .order('created_at', { ascending: true })
    .range(offset, offset + limit - 1);

  if (msgError) throw msgError;

  return {
    messages: (messages || []).map(msg => ({
      id: msg.id,
      roomId: msg.room_id,
      senderId: msg.sender_id,
      content: msg.content,
      imageUrl: msg.image_url,
      type: msg.type,
      isRead: msg.is_read,
      createdAt: msg.created_at
    }))
  };
}

async function sendMessage(roomId, senderId, content, imageUrl, type) {
  const msgType = type || 'text';

  // ตรวจสอบว่า room มีอยู่จริง
  const { data: room, error: roomError } = await supabase
    .from('chat_rooms')
    .select('id, buyer_id, seller_id')
    .eq('id', roomId)
    .single();

  if (roomError && roomError.code === 'PGRST116') {
    return { notFound: true };
  }
  if (roomError) throw roomError;

  const insertData = {
    room_id: roomId,
    sender_id: senderId,
    type: msgType
  };

  if (msgType === 'text') {
    insertData.content = content;
  } else if (msgType === 'image') {
    insertData.image_url = imageUrl;
  }

  const { data: newMessage, error: insertError } = await supabase
    .from('chat_messages')
    .insert([insertData])
    .select()
    .single();

  if (insertError) throw insertError;

  return {
    message: {
      id: newMessage.id,
      roomId: newMessage.room_id,
      senderId: newMessage.sender_id,
      content: newMessage.content || null,
      imageUrl: newMessage.image_url || null,
      type: newMessage.type,
      createdAt: newMessage.created_at
    },
    room: {
      id: room.id,
      buyer_id: room.buyer_id,
      seller_id: room.seller_id
    }
  };
}

async function createReport(roomId, reporterId, reportedUserId, reason) {
  const { data: report, error } = await supabase
    .from('chat_reports')
    .insert([{
      room_id: roomId,
      reporter_id: reporterId,
      reported_user_id: reportedUserId,
      reason,
      status: 'pending'
    }])
    .select()
    .single();

  if (error) throw error;

  return {
    id: report.id,
    roomId: report.room_id,
    reporterId: report.reporter_id,
    reportedUserId: report.reported_user_id,
    reason: report.reason,
    status: report.status,
    createdAt: report.created_at
  };
}

module.exports = {
  createOrGetRoom,
  getUserRooms,
  getRoomMessages,
  sendMessage,
  createReport
};

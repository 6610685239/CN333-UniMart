const { supabase, prisma } = require('../models');

// =============================================
// Room CRUD
// =============================================

async function createOrGetRoom(buyerId, sellerId, productId) {
  const { data: existingRoom, error: selectError } = await supabase
    .from('chat_rooms')
    .select('*')
    .eq('buyer_id', buyerId)
    .eq('seller_id', sellerId)
    .eq('product_id', productId)
    .single();

  if (selectError && selectError.code !== 'PGRST116') throw selectError;

  if (existingRoom) {
    // Un-delete if previously soft-deleted by this user
    const isBuyer = existingRoom.buyer_id === buyerId;
    const delCol = isBuyer ? 'deleted_by_buyer' : 'deleted_by_seller';
    if (existingRoom[delCol]) {
      await supabase.from('chat_rooms').update({ [delCol]: false }).eq('id', existingRoom.id);
    }
    return { room: _mapRoom(existingRoom), created: false };
  }

  const { data: newRoom, error: insertError } = await supabase
    .from('chat_rooms')
    .insert([{ buyer_id: buyerId, seller_id: sellerId, product_id: productId }])
    .select()
    .single();

  if (insertError) throw insertError;
  return { room: _mapRoom(newRoom), created: true };
}

function _mapRoom(r) {
  return {
    id: r.id,
    buyerId: r.buyer_id,
    sellerId: r.seller_id,
    productId: r.product_id,
    createdAt: r.created_at,
  };
}

// =============================================
// Unified room list  (returns product info for tags)
// =============================================

async function getUserRooms(userId) {
  // 1. Fetch rooms where the user participates
  const { data: buyerRooms, error: bErr } = await supabase
    .from('chat_rooms').select('*').eq('buyer_id', userId);
  if (bErr) throw bErr;

  const { data: sellerRooms, error: sErr } = await supabase
    .from('chat_rooms').select('*').eq('seller_id', userId);
  if (sErr) throw sErr;

  const roomMap = new Map();
  for (const r of [...buyerRooms, ...sellerRooms]) roomMap.set(r.id, r);
  const allRooms = Array.from(roomMap.values());

  // 2. Enrich each room
  const result = await Promise.all(allRooms.map(async (room) => {
    const otherUserId = room.buyer_id === userId ? room.seller_id : room.buyer_id;

    // Other user info
    const otherUser = await prisma.users.findUnique({
      where: { id: otherUserId },
      select: { display_name_th: true, display_name_en: true, username: true, avatar: true },
    });

    // Product info — include images, price, type, ownerId for tag logic
    const product = await prisma.product.findUnique({
      where: { id: room.product_id },
      select: { id: true, title: true, images: true, price: true, rentPrice: true, type: true, ownerId: true, status: true },
    });

    // Last message
    const { data: lastMsgs, error: msgErr } = await supabase
      .from('chat_messages')
      .select('content, created_at, type, sender_id')
      .eq('room_id', room.id)
      .order('created_at', { ascending: false })
      .limit(1);
    if (msgErr) throw msgErr;

    const lastMessage = lastMsgs && lastMsgs.length > 0
      ? { content: lastMsgs[0].content, createdAt: lastMsgs[0].created_at, type: lastMsgs[0].type }
      : null;

    // Unread count
    const { count: unreadCount, error: cErr } = await supabase
      .from('chat_messages')
      .select('*', { count: 'exact', head: true })
      .eq('room_id', room.id)
      .eq('is_read', false)
      .neq('sender_id', userId);
    if (cErr) throw cErr;

    const isBuyer = room.buyer_id === userId;
    const isPinned = isBuyer ? room.pinned_by_buyer : room.pinned_by_seller;
    const isDeleted = isBuyer ? room.deleted_by_buyer : room.deleted_by_seller;

    // Lock check via transaction
    let isLocked = false;
    try {
      const txn = await prisma.transaction.findFirst({
        where: { productId: room.product_id, buyerId: room.buyer_id, sellerId: room.seller_id },
      });
      isLocked = !!txn && (txn.status === 'COMPLETED' || txn.status === 'CANCELED');
    } catch (_) { /* prisma not ready or table missing — ignore */ }

    return {
      id: room.id,
      buyerId: room.buyer_id,
      sellerId: room.seller_id,
      isBuyer,
      isPinned: isPinned || false,
      isDeleted: isDeleted || false,
      isLocked: isLocked || false,
      otherUserId,
      otherUserAvatar: otherUser?.avatar || null,
      otherUser: {
        displayName: otherUser?.display_name_th || otherUser?.display_name_en || null,
        username: otherUser?.username || null,
      },
      productTitle: product?.title || null,
      productImages: product?.images || [],
      productPrice: product?.price || 0,
      productRentPrice: product?.rentPrice || 0,
      productType: product?.type || 'SALE',
      productOwnerId: product?.ownerId || '',
      productStatus: product?.status || 'AVAILABLE',
      product: product ? {
        id: product.id,
        title: product.title,
        images: product.images || [],
        price: product.price,
        rentPrice: product.rentPrice,
        type: product.type,       // SALE | RENT
        ownerId: product.ownerId, // for tag logic on client
        status: product.status,
      } : null,
      lastMessage,
      unreadCount: unreadCount || 0,
    };
  }));

  // Filter out soft-deleted rooms
  const visible = result.filter(r => !r.isDeleted);

  // Sort: pinned first, then by latest message time desc
  visible.sort((a, b) => {
    if (a.isPinned && !b.isPinned) return -1;
    if (!a.isPinned && b.isPinned) return 1;
    const tA = a.lastMessage ? new Date(a.lastMessage.createdAt).getTime() : 0;
    const tB = b.lastMessage ? new Date(b.lastMessage.createdAt).getTime() : 0;
    return tB - tA;
  });

  return visible;
}

// =============================================
// Room detail  (for chat room header)
// =============================================

async function getRoomDetail(roomId) {
  const { data: room, error: rErr } = await supabase
    .from('chat_rooms')
    .select('*')
    .eq('id', roomId)
    .single();

  if (rErr && rErr.code === 'PGRST116') return { notFound: true };
  if (rErr) throw rErr;

  const product = await prisma.product.findUnique({
    where: { id: room.product_id },
    select: { id: true, title: true, images: true, price: true, rentPrice: true, type: true, ownerId: true, status: true },
  });

  const buyer = await prisma.users.findUnique({
    where: { id: room.buyer_id },
    select: { display_name_th: true, display_name_en: true, username: true, avatar: true },
  });

  const seller = await prisma.users.findUnique({
    where: { id: room.seller_id },
    select: { display_name_th: true, display_name_en: true, username: true, avatar: true },
  });

  return {
    id: room.id,
    buyerId: room.buyer_id,
    sellerId: room.seller_id,
    productId: room.product_id,
    createdAt: room.created_at,
    product: product ? {
      id: product.id,
      title: product.title,
      images: product.images || [],
      price: product.price,
      rentPrice: product.rentPrice,
      type: product.type,
      ownerId: product.ownerId,
      status: product.status,
    } : null,
    buyer: {
      id: room.buyer_id,
      displayName: buyer?.display_name_th || buyer?.display_name_en || null,
      username: buyer?.username || null,
      avatar: buyer?.avatar || null,
    },
    seller: {
      id: room.seller_id,
      displayName: seller?.display_name_th || seller?.display_name_en || null,
      username: seller?.username || null,
      avatar: seller?.avatar || null,
    },
  };
}

// =============================================
// Messages
// =============================================

async function getRoomMessages(roomId, limit, offset) {
  const { data: room, error: roomError } = await supabase
    .from('chat_rooms').select('id').eq('id', roomId).single();

  if (roomError && roomError.code === 'PGRST116') return { notFound: true };
  if (roomError) throw roomError;

  const safeOffset = typeof offset === 'number' && !Number.isNaN(offset) ? offset : 0;
  const safeLimit = typeof limit === 'number' && !Number.isNaN(limit) ? limit : 100000;

  const { data: messages, error: msgError } = await supabase
    .from('chat_messages')
    .select('id, room_id, sender_id, content, image_url, type, is_read, created_at')
    .eq('room_id', roomId)
    .order('created_at', { ascending: true })
    .range(safeOffset, safeOffset + safeLimit - 1);

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
      createdAt: msg.created_at,
    })),
  };
}

async function sendMessage(roomId, senderId, content, imageUrl, type) {
  const msgType = type || 'text';

  const { data: room, error: roomError } = await supabase
    .from('chat_rooms').select('id, buyer_id, seller_id').eq('id', roomId).single();

  if (roomError && roomError.code === 'PGRST116') return { notFound: true };
  if (roomError) throw roomError;

  const insertData = { room_id: roomId, sender_id: senderId, type: msgType };
  if (msgType === 'text') insertData.content = content;
  else if (msgType === 'image') insertData.image_url = imageUrl;

  const { data: newMessage, error: insertError } = await supabase
    .from('chat_messages').insert([insertData]).select().single();
  if (insertError) throw insertError;

  return {
    message: {
      id: newMessage.id,
      roomId: newMessage.room_id,
      senderId: newMessage.sender_id,
      content: newMessage.content || null,
      imageUrl: newMessage.image_url || null,
      type: newMessage.type,
      createdAt: newMessage.created_at,
    },
    room: { id: room.id, buyer_id: room.buyer_id, seller_id: room.seller_id },
  };
}

// =============================================
// Reports
// =============================================

async function createReport(roomId, reporterId, reportedUserId, reason) {
  const { data: report, error } = await supabase
    .from('chat_reports')
    .insert([{ room_id: roomId, reporter_id: reporterId, reported_user_id: reportedUserId, reason, status: 'pending' }])
    .select().single();
  if (error) throw error;

  return {
    id: report.id,
    roomId: report.room_id,
    reporterId: report.reporter_id,
    reportedUserId: report.reported_user_id,
    reason: report.reason,
    status: report.status,
    createdAt: report.created_at,
  };
}

// =============================================
// Pin / Delete / Read
// =============================================

async function setChatRoomPinned(roomId, userId, isPinned) {
  const { data: room, error: rErr } = await supabase.from('chat_rooms').select('buyer_id, seller_id').eq('id', roomId).single();
  if (rErr) throw rErr;
  const col = room.buyer_id === userId ? 'pinned_by_buyer' : 'pinned_by_seller';
  const { data, error } = await supabase.from('chat_rooms').update({ [col]: isPinned }).eq('id', roomId).select();
  if (error) throw error;
  return data;
}

async function setChatRoomDeleted(roomId, userId, isDeleted) {
  const { data: room, error: rErr } = await supabase.from('chat_rooms').select('buyer_id, seller_id').eq('id', roomId).single();
  if (rErr) throw rErr;
  const col = room.buyer_id === userId ? 'deleted_by_buyer' : 'deleted_by_seller';
  const { data, error } = await supabase.from('chat_rooms').update({ [col]: isDeleted }).eq('id', roomId).select();
  if (error) throw error;
  return data;
}

async function markMessagesAsRead(roomId, userId) {
  const { data, error } = await supabase
    .from('chat_messages')
    .update({ is_read: true })
    .eq('room_id', roomId)
    .neq('sender_id', userId)
    .eq('is_read', false)
    .select();
  if (error) throw error;
  return { count: data ? data.length : 0 };
}

module.exports = {
  createOrGetRoom,
  getUserRooms,
  getRoomDetail,
  getRoomMessages,
  sendMessage,
  createReport,
  setChatRoomPinned,
  setChatRoomDeleted,
  markMessagesAsRead,
};

const transactionService = require('../services/transaction.service');
const notificationService = require('../services/notification.service');

async function create(req, res) {
  const { buyerId, productId, type } = req.body;

  if (!buyerId || !productId || !type) {
    return res.status(400).json({ success: false, message: 'กรุณาระบุ buyerId, productId, และ type' });
  }

  if (!['SALE', 'RENT'].includes(type)) {
    return res.status(400).json({ success: false, message: 'type ต้องเป็น SALE หรือ RENT' });
  }

  try {
    const result = await transactionService.createTransaction(buyerId, productId, type);

    if (result.error === 'NOT_FOUND') {
      return res.status(404).json({ success: false, message: 'ไม่พบสินค้า' });
    }
    if (result.error === 'RESERVED') {
      return res.status(409).json({ success: false, message: 'สินค้านี้ถูกจองแล้ว' });
    }
    if (result.error === 'OUT_OF_STOCK') {
      return res.status(409).json({ success: false, message: 'สินค้าหมด' });
    }

    res.status(201).json(result.transaction);

    // Fire-and-forget notification to seller
    try {
      await notificationService.createNotification(
        result.transaction.sellerId,
        'transaction_update',
        'New order!',
        `Someone wants to buy your item`,
        { transactionId: result.transaction.id }
      );
    } catch (_) {}
  } catch (err) {
    console.error('Create Transaction Error:', err.message);
    res.status(500).json({ success: false, message: 'ไม่สามารถสร้างธุรกรรมได้', error: err.message });
  }
}

async function confirm(req, res) {
  try {
    const result = await transactionService.confirmTransaction(req.params.id);

    if (result.error === 'NOT_FOUND') {
      return res.status(404).json({ success: false, message: 'ไม่พบธุรกรรม' });
    }
    if (result.error === 'INVALID_STATUS') {
      return res.status(400).json({ success: false, message: 'ไม่สามารถเปลี่ยนสถานะจาก ' + result.currentStatus + ' เป็น PROCESSING ได้' });
    }

    res.json(result.transaction);

    // Fire-and-forget notification to buyer
    try {
      await notificationService.createNotification(
        result.transaction.buyerId,
        'transaction_update',
        'ธุรกรรมถูกยืนยัน',
        'ผู้ขายยืนยันธุรกรรมของคุณแล้ว',
        { transactionId: result.transaction.id }
      );
    } catch (notifErr) {
      console.error('Notification Error (confirm):', notifErr.message);
    }
  } catch (err) {
    console.error('Confirm Transaction Error:', err.message);
    res.status(500).json({ success: false, message: 'ไม่สามารถยืนยันธุรกรรมได้', error: err.message });
  }
}

async function ship(req, res) {
  try {
    const result = await transactionService.shipTransaction(req.params.id);

    if (result.error === 'NOT_FOUND') {
      return res.status(404).json({ success: false, message: 'ไม่พบธุรกรรม' });
    }
    if (result.error === 'INVALID_STATUS') {
      return res.status(400).json({ success: false, message: 'ไม่สามารถเปลี่ยนสถานะจาก ' + result.currentStatus + ' เป็น SHIPPING ได้' });
    }

    res.json(result.transaction);

    // Fire-and-forget notification to buyer
    try {
      await notificationService.createNotification(
        result.transaction.buyerId,
        'transaction_update',
        'สินค้าถูกส่งมอบ',
        'ผู้ขายส่งมอบสินค้าแล้ว',
        { transactionId: result.transaction.id }
      );
    } catch (notifErr) {
      console.error('Notification Error (ship):', notifErr.message);
    }
  } catch (err) {
    console.error('Ship Transaction Error:', err.message);
    res.status(500).json({ success: false, message: 'ไม่สามารถอัปเดตสถานะการส่งมอบได้', error: err.message });
  }
}

async function complete(req, res) {
  try {
    const result = await transactionService.completeTransaction(req.params.id);

    if (result.error === 'NOT_FOUND') {
      return res.status(404).json({ success: false, message: 'ไม่พบธุรกรรม' });
    }
    if (result.error === 'INVALID_STATUS') {
      return res.status(400).json({ success: false, message: 'ไม่สามารถเปลี่ยนสถานะจาก ' + result.currentStatus + ' เป็น COMPLETED ได้' });
    }

    res.json(result.transaction);

    // Fire-and-forget notification to seller
    try {
      await notificationService.createNotification(
        result.transaction.sellerId,
        'transaction_update',
        'ธุรกรรมเสร็จสิ้น',
        'ผู้ซื้อยืนยันรับสินค้าแล้ว',
        { transactionId: result.transaction.id }
      );
    } catch (notifErr) {
      console.error('Notification Error (complete):', notifErr.message);
    }
  } catch (err) {
    console.error('Complete Transaction Error:', err.message);
    res.status(500).json({ success: false, message: 'ไม่สามารถยืนยันการรับสินค้าได้', error: err.message });
  }
}

async function cancel(req, res) {
  const { canceledBy, cancelReason } = req.body;

  try {
    const result = await transactionService.cancelTransaction(req.params.id, canceledBy, cancelReason);

    if (result.error === 'NOT_FOUND') {
      return res.status(404).json({ success: false, message: 'ไม่พบธุรกรรม' });
    }
    if (result.error === 'INVALID_STATUS') {
      return res.status(400).json({ success: false, message: 'ไม่สามารถยกเลิกธุรกรรมที่อยู่ในสถานะ ' + result.currentStatus + ' ได้' });
    }

    res.json(result.transaction);

    // Fire-and-forget notification to the other party
    try {
      const tx = result.transaction;
      const recipientId = tx.canceledBy === tx.buyerId ? tx.sellerId : tx.buyerId;
      const bodyText = tx.canceledBy === tx.buyerId ? 'ผู้ซื้อยกเลิกธุรกรรม' : 'ผู้ขายยกเลิกธุรกรรม';
      await notificationService.createNotification(
        recipientId,
        'transaction_update',
        'ธุรกรรมถูกยกเลิก',
        bodyText,
        { transactionId: tx.id }
      );
    } catch (notifErr) {
      console.error('Notification Error (cancel):', notifErr.message);
    }
  } catch (err) {
    console.error('Cancel Transaction Error:', err.message);
    res.status(500).json({ success: false, message: 'ไม่สามารถยกเลิกธุรกรรมได้', error: err.message });
  }
}

async function getUserTransactions(req, res) {
  const { userId } = req.params;

  try {
    const grouped = await transactionService.getUserTransactions(userId);
    res.json(grouped);
  } catch (err) {
    console.error('Get User Transactions Error:', err.message);
    res.status(500).json({ success: false, message: 'ไม่สามารถดึงรายการธุรกรรมได้', error: err.message });
  }
}

async function returnItem(req, res) {
  try {
    const result = await transactionService.returnTransaction(req.params.id);

    if (result.error === 'NOT_FOUND') {
      return res.status(404).json({ success: false, message: 'ไม่พบธุรกรรม' });
    }
    if (result.error === 'NOT_RENT') {
      return res.status(400).json({ success: false, message: 'ใช้ได้เฉพาะธุรกรรมประเภทเช่า' });
    }
    if (result.error === 'INVALID_STATUS') {
      return res.status(400).json({ success: false, message: 'ไม่สามารถเปลี่ยนสถานะได้' });
    }

    res.json(result.transaction);

    // Notify owner (seller) that item is being returned
    try {
      await notificationService.createNotification(
        result.transaction.sellerId,
        'transaction_update',
        'Item being returned',
        'The renter is returning your item',
        { transactionId: result.transaction.id }
      );
    } catch (_) {}
  } catch (err) {
    console.error('Return Transaction Error:', err.message);
    res.status(500).json({ success: false, message: 'ไม่สามารถอัปเดตสถานะได้', error: err.message });
  }
}

async function getById(req, res) {
  try {
    const transaction = await transactionService.getTransactionById(req.params.id);
    if (!transaction) {
      return res.status(404).json({ success: false, message: 'ไม่พบธุรกรรม' });
    }
    res.json(transaction);
  } catch (err) {
    res.status(500).json({ success: false, message: 'ไม่สามารถโหลดธุรกรรมได้', error: err.message });
  }
}

module.exports = { create, confirm, ship, returnItem, complete, cancel, getUserTransactions, getById };

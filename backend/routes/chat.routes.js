const express = require('express');
const router = express.Router();
const chatController = require('../controllers/chat.controller');

// Room CRUD
router.post('/rooms', chatController.createRoom);
router.get('/rooms/:userId', chatController.getUserRooms);
router.get('/rooms/:roomId/detail', chatController.getRoomDetail);
router.get('/rooms/:roomId/messages', chatController.getMessages);

// Messages
router.post('/messages', chatController.sendMessage);

// Reports
router.post('/reports', chatController.createReport);

// Pin / Delete / Read
router.put('/:roomId/pin', chatController.pinRoom);
router.delete('/:roomId', chatController.deleteRoom);
router.put('/:roomId/read', chatController.markAsRead);

module.exports = router;


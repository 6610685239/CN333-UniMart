const express = require('express');
const router = express.Router();
const chatController = require('../controllers/chat.controller');

router.post('/rooms', chatController.createRoom);
router.get('/rooms/:userId', chatController.getUserRooms);
router.get('/rooms/:roomId/messages', chatController.getMessages);
router.post('/messages', chatController.sendMessage);
router.post('/reports', chatController.createReport);

module.exports = router;

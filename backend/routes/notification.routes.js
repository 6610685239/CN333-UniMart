const express = require('express');
const router = express.Router();
const notificationController = require('../controllers/notification.controller');

// IMPORTANT: More specific routes MUST come before parameterized routes
router.get('/:userId/unread-count', notificationController.getUnreadCount);
router.patch('/:userId/settings', notificationController.updateSettings);
router.get('/:userId', notificationController.getUserNotifications);
router.patch('/:id/read', notificationController.markAsRead);

module.exports = router;

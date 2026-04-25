const express = require('express');
const multer = require('multer');
const router = express.Router();
const authController = require('../controllers/auth.controller');

// Use memory storage so the buffer can be forwarded to Supabase Storage
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'application/octet-stream'];
    cb(null, allowed.includes(file.mimetype));
  }
});

router.post('/verify', authController.verify);
router.post('/register', authController.register);
router.post('/login', authController.login);
router.post('/change-password', authController.changePassword);
router.post('/:userId/avatar', upload.single('avatar'), authController.uploadAvatar);
router.get('/:userId/profile', authController.getUserProfile);
router.patch('/:userId/profile', authController.updateUserProfile);

module.exports = router;

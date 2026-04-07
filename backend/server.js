const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
require('dotenv').config();

const { prisma, supabase } = require('./models');
const { createNotification, sendFcmNotification } = require('./services/notification.service');

// Route imports
const authRoutes = require('./routes/auth.routes');
const chatRoutes = require('./routes/chat.routes');
const transactionRoutes = require('./routes/transaction.routes');
const reviewRoutes = require('./routes/review.routes');
const filterRoutes = require('./routes/filter.routes');
const notificationRoutes = require('./routes/notification.routes');
const createProductRoutes = require('./routes/product.routes');

const app = express();
const PORT = process.env.PORT || 3000;

// ==========================================
// Middleware
// ==========================================
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Application-Key', 'Authorization'],
  preflightContinue: false,
  optionsSuccessStatus: 204
}));
app.use(express.json());
app.use('/uploads', express.static('uploads'));

// ตรวจสอบว่ามีโฟลเดอร์ uploads ไหม ถ้าไม่มีให้สร้าง
if (!fs.existsSync('./uploads')) {
  fs.mkdirSync('./uploads');
}

// Config Multer สำหรับอัปโหลดรูป
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, 'uploads/'),
  filename: (req, file, cb) => cb(null, Date.now() + '-' + Math.round(Math.random() * 1E9) + path.extname(file.originalname))
});
const upload = multer({ storage: storage });

// ==========================================
// Mount Routes
// ==========================================
app.use('/api/auth', authRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/transactions', transactionRoutes);
app.use('/api/reviews', reviewRoutes);

// Filter routes: /api/products/filter, /api/meeting-points, /api/dormitory-zones
// Must be mounted BEFORE product routes so /api/products/filter matches before /api/products/:id
app.use('/api', filterRoutes);

app.use('/api/notifications', notificationRoutes);

// Product routes: /api/categories, /api/products, /api/my-products/:userId, /api/products/:id
app.use('/api', createProductRoutes(upload));

// ==========================================
// Start Server
// ==========================================
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

io.on('connection', (socket) => {
  console.log('✅ User connected to socket:', socket.id);

  socket.on('join_room', (roomId) => {
    socket.join(roomId);
    console.log(`User ${socket.id} joined room ${roomId}`);
  });

  socket.on('join_user', (userId) => {
    socket.join(`user_${userId}`);
    console.log(`User ${socket.id} joined user channel user_${userId}`);
  });

  socket.on('leave_room', (roomId) => {
    socket.leave(roomId);
    console.log(`User ${socket.id} left room ${roomId}`);
  });

  // Real-time read receipt: client emits this when viewing a room
  socket.on('mark_as_read', async ({ roomId, userId }) => {
    try {
      const chatService = require('./services/chat.service');
      const result = await chatService.markMessagesAsRead(roomId, userId);
      if (result.count > 0) {
        io.to(roomId).emit('messages_read', { roomId, readByUserId: userId, count: result.count });
      }
    } catch (err) {
      console.error('Socket mark_as_read error:', err.message);
    }
  });

  socket.on('disconnect', () => {
    console.log('User disconnected from socket:', socket.id);
  });
});

// We can attach 'io' to app so controllers can use it
app.set('io', io);

if (require.main === module) {
  server.listen(PORT, () => {
    console.log(`✅ Server is running on port ${PORT}`);
  });
}

// export server too
module.exports = { app, server, io, supabase, prisma, createNotification, sendFcmNotification };



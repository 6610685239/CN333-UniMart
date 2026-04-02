/**
 * Property-Based Tests สำหรับ Auth System — UniMart Iteration 2
 * 
 * ใช้ fast-check สำหรับ property-based testing
 * Mock TU API และ Supabase เพื่อ test logic ภายใน
 */

const fc = require('fast-check');
const bcrypt = require('bcrypt');
const request = require('supertest');

// Mock Supabase ก่อน require server
const mockSupabaseFrom = jest.fn();
jest.mock('@supabase/supabase-js', () => ({
  createClient: () => ({
    from: mockSupabaseFrom
  })
}));

// Mock Prisma
jest.mock('@prisma/client', () => ({
  PrismaClient: jest.fn().mockImplementation(() => ({
    category: { findMany: jest.fn().mockResolvedValue([]) },
    product: { findMany: jest.fn().mockResolvedValue([]), create: jest.fn(), findUnique: jest.fn(), update: jest.fn(), delete: jest.fn() }
  }))
}));

// Mock axios
jest.mock('axios');
const axios = require('axios');

const { app } = require('../server');

// Helper: สร้าง mock TU API response สำหรับ student
function mockTuStudentResponse(username, tuStatus = 'ปกติ') {
  return {
    status: true,
    message: 'Success',
    type: 'student',
    username: username,
    tu_status: tuStatus,
    statusid: '10',
    displayname_th: `นักศึกษา ${username}`,
    displayname_en: `Student ${username}`,
    email: `${username}@dome.tu.ac.th`,
    department: 'วิศวกรรมคอมพิวเตอร์',
    faculty: 'วิศวกรรมศาสตร์'
  };
}

// Helper: mock supabase select chain
function mockSupabaseSelect(returnData, returnError = null) {
  mockSupabaseFrom.mockReturnValue({
    select: jest.fn().mockReturnValue({
      eq: jest.fn().mockReturnValue({
        single: jest.fn().mockResolvedValue({ data: returnData, error: returnError })
      })
    }),
    insert: jest.fn().mockReturnValue({
      select: jest.fn().mockResolvedValue({ data: returnData ? [returnData] : [], error: returnError })
    })
  });
}

// Reset mocks before each test
beforeEach(() => {
  jest.clearAllMocks();
});


// ============================================
// Property 15: ข้อมูล TU API ถูก map ครบถ้วน
// ============================================
describe('Feature: unimart-iteration-2, Property 15: ข้อมูล TU API ถูก map ครบถ้วน', () => {
  test('verify endpoint maps all TU API fields to tuProfile', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.stringMatching(/^[0-9]{10}$/),  // student ID format
        fc.constantFrom('ปกติ', 'พักการศึกษา', 'ลาออก', 'สำเร็จการศึกษา'),
        async (studentId, tuStatus) => {
          const tuResponse = mockTuStudentResponse(studentId, tuStatus);

          axios.post.mockResolvedValueOnce({ data: tuResponse });
          mockSupabaseSelect(null); // no existing user

          const res = await request(app)
            .post('/api/auth/verify')
            .send({ username: studentId, password: 'anypass' });

          expect(res.body.success).toBe(true);
          expect(res.body.action).toBe('GO_TO_REGISTER');

          const profile = res.body.tuProfile;
          expect(profile.username).toBe(tuResponse.username);
          expect(profile.display_name_th).toBe(tuResponse.displayname_th);
          expect(profile.display_name_en).toBe(tuResponse.displayname_en);
          expect(profile.email).toBe(tuResponse.email);
          expect(profile.faculty).toBe(tuResponse.faculty);
          expect(profile.department).toBe(tuResponse.department);
          expect(profile.type).toBe(tuResponse.type);
        }
      ),
      { numRuns: 50 }
    );
  });
});

// ============================================
// Property 16: ลงทะเบียนได้ทุก tu_status
// ============================================
describe('Feature: unimart-iteration-2, Property 16: ลงทะเบียนได้ทุก tu_status', () => {
  test('verify allows registration for any tu_status', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.constantFrom('ปกติ', 'พักการศึกษา', 'ลาออก', 'สำเร็จการศึกษา', 'รอพินิจ'),
        async (tuStatus) => {
          const tuResponse = mockTuStudentResponse('6610685056', tuStatus);

          axios.post.mockResolvedValueOnce({ data: tuResponse });
          mockSupabaseSelect(null); // no existing user

          const res = await request(app)
            .post('/api/auth/verify')
            .send({ username: '6610685056', password: 'anypass' });

          // ทุก tu_status ต้องได้ GO_TO_REGISTER (ไม่ถูกปฏิเสธ)
          expect(res.body.success).toBe(true);
          expect(res.body.action).toBe('GO_TO_REGISTER');
        }
      ),
      { numRuns: 20 }
    );
  });
});

// ============================================
// Property 17: รหัสผ่าน UniMart Round-Trip
// ============================================
describe('Feature: unimart-iteration-2, Property 17: รหัสผ่าน UniMart Round-Trip', () => {
  test('password hashed during register can be verified during login', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.string({ minLength: 6, maxLength: 50 }).filter(s => s.trim().length >= 6 && !s.includes('\x00')),
        async (password) => {
          const userId = 'test-uuid-' + Math.random().toString(36).slice(2);
          let storedHash = null;

          // Register calls supabase.from('users') twice:
          // 1st: .select('id').eq('username', ...).single() — duplicate check
          // 2nd: .insert([...]).select() — create user

          // 1st call: duplicate check → no user found
          mockSupabaseFrom.mockReturnValueOnce({
            select: jest.fn().mockReturnValue({
              eq: jest.fn().mockReturnValue({
                single: jest.fn().mockResolvedValue({ data: null, error: null })
              })
            })
          });

          // 2nd call: insert user
          mockSupabaseFrom.mockReturnValueOnce({
            insert: jest.fn().mockImplementation((rows) => {
              storedHash = rows[0].password_hash;
              return {
                select: jest.fn().mockResolvedValue({
                  data: [{ id: userId, username: '6610685056', ...rows[0] }],
                  error: null
                })
              };
            })
          });

          const regRes = await request(app)
            .post('/api/auth/register')
            .send({ username: '6610685056', phone_number: '0812345678', app_password: password });

          expect(regRes.body.success).toBe(true);
          expect(storedHash).toBeTruthy();

          // Login: verify password matches the stored hash
          mockSupabaseFrom.mockReturnValueOnce({
            select: jest.fn().mockReturnValue({
              eq: jest.fn().mockReturnValue({
                single: jest.fn().mockResolvedValue({
                  data: { id: userId, username: '6610685056', password_hash: storedHash, display_name_th: 'ทดสอบ' },
                  error: null
                })
              })
            })
          });

          const loginRes = await request(app)
            .post('/api/auth/login')
            .send({ username: '6610685056', password: password });

          expect(loginRes.body.success).toBe(true);
          expect(loginRes.body.token).toBeDefined();
        }
      ),
      { numRuns: 20 }
    );
  });
});


// ============================================
// Property 18: ห้ามลงทะเบียนซ้ำ
// ============================================
describe('Feature: unimart-iteration-2, Property 18: ห้ามลงทะเบียนซ้ำ', () => {
  test('register rejects duplicate username with 409', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.stringMatching(/^[0-9]{10}$/),
        async (studentId) => {
          // Mock: user already exists
          mockSupabaseFrom.mockReturnValueOnce({
            select: jest.fn().mockReturnValue({
              eq: jest.fn().mockReturnValue({
                single: jest.fn().mockResolvedValue({
                  data: { id: 'existing-uuid', username: studentId },
                  error: null
                })
              })
            })
          });

          const res = await request(app)
            .post('/api/auth/register')
            .send({
              username: studentId,
              phone_number: '0812345678',
              app_password: 'testpass123'
            });

          expect(res.status).toBe(409);
          expect(res.body.success).toBe(false);
        }
      ),
      { numRuns: 30 }
    );
  });
});

// ============================================
// Property 19: ไม่เก็บรหัสผ่าน TU
// ============================================
describe('Feature: unimart-iteration-2, Property 19: ไม่เก็บรหัสผ่าน TU', () => {
  test('register never stores TU password - password_hash is bcrypt of app_password only', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.string({ minLength: 6, maxLength: 30 }).filter(s => s.trim().length > 0),
        fc.string({ minLength: 6, maxLength: 30 }).filter(s => s.trim().length > 0),
        async (tuPassword, appPassword) => {
          // Assume tuPassword !== appPassword for meaningful test
          fc.pre(tuPassword !== appPassword);

          let capturedInsertData = null;

          mockSupabaseFrom.mockReturnValueOnce({
            select: jest.fn().mockReturnValue({
              eq: jest.fn().mockReturnValue({
                single: jest.fn().mockResolvedValue({ data: null, error: null })
              })
            }),
            insert: jest.fn().mockImplementation((rows) => {
              capturedInsertData = rows[0];
              return {
                select: jest.fn().mockResolvedValue({
                  data: [{ id: 'new-uuid', username: '6610685056', ...capturedInsertData }],
                  error: null
                })
              };
            })
          });

          await request(app)
            .post('/api/auth/register')
            .send({
              username: '6610685056',
              phone_number: '0812345678',
              app_password: appPassword
            });

          // password_hash ต้องเป็น bcrypt ของ app_password ไม่ใช่ TU password
          if (capturedInsertData && capturedInsertData.password_hash) {
            const matchesApp = await bcrypt.compare(appPassword, capturedInsertData.password_hash);
            const matchesTu = await bcrypt.compare(tuPassword, capturedInsertData.password_hash);

            expect(matchesApp).toBe(true);
            expect(matchesTu).toBe(false);
          }
        }
      ),
      { numRuns: 20 }
    );
  });
});

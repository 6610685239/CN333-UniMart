const filterService = require('../services/filter.service');

async function filterProducts(req, res) {
  const { faculty, dormitoryZone, meetingPoint, minCredit, categoryId } = req.query;

  try {
    const result = await filterService.filterProducts({ faculty, dormitoryZone, meetingPoint, minCredit, categoryId });
    res.json(result);
  } catch (err) {
    console.error('Filter Products Error:', err.message);
    res.status(500).json({ success: false, message: 'ไม่สามารถกรองสินค้าได้', error: err.message });
  }
}

async function getMeetingPoints(req, res) {
  try {
    const meetingPoints = await filterService.getMeetingPoints();
    res.json(meetingPoints);
  } catch (err) {
    console.error('Get Meeting Points Error:', err.message);
    res.status(500).json({ success: false, message: 'ไม่สามารถดึงรายการจุดนัดพบได้', error: err.message });
  }
}

function getDormitoryZones(req, res) {
  const zones = filterService.getDormitoryZones();
  res.json(zones);
}

module.exports = { filterProducts, getMeetingPoints, getDormitoryZones };

function requireAuth(req, res, next) {
  if (!req.session.user) {
    return res.status(401).json({ error: 'Please log in.' });
  }
  next();
}

function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.session.user) {
      return res.status(401).json({ error: 'Please log in.' });
    }
    if (!roles.includes(req.session.user.role)) {
      return res.status(403).json({ error: 'You do not have access to this resource.' });
    }
    next();
  };
}

module.exports = { requireAuth, requireRole };

// Backend Fix: Add company_id filtering to sync endpoints
// File: src/routes/sync.ts (or similar)

// ============================================================
// 1. MIDDLEWARE: Validate X-Company-Id header
// ============================================================
function validateCompanyAccess(req, res, next) {
  const requestedCompanyId = parseInt(req.headers['x-company-id']);
  const allowedCompanyIds = req.user.company_ids || [];
  
  console.log('DEBUG: X-Company-Id header =', requestedCompanyId);
  console.log('DEBUG: JWT company_ids =', allowedCompanyIds);
  
  if (!requestedCompanyId) {
    return res.status(400).json({ error: 'X-Company-Id header required' });
  }
  
  if (!allowedCompanyIds.includes(requestedCompanyId)) {
    console.log('DEBUG: Company access denied. User not in company:', requestedCompanyId);
    return res.status(403).json({ error: 'Access denied to this company' });
  }
  
  req.companyId = requestedCompanyId;
  next();
}

// ============================================================
// 2. processOperations: Insert with company_id
// ============================================================
async function processOperations(req, res) {
  const operations = req.body.operations;
  const companyId = req.companyId; // From middleware
  const tenantId = req.user.tenant_id;
  
  console.log('DEBUG processOperations: companyId =', companyId);
  console.log('DEBUG processOperations: tenantId =', tenantId);
  
  for (const op of operations) {
    // Determine company_id from operation or fall back to JWT
    const opCompanyId = op.payload?.new?.company_id 
      || op.payload?.old?.company_id 
      || companyId;
    
    await db('operations_log').insert({
      tenant_id: tenantId,
      company_id: opCompanyId,  // <-- ADD THIS
      entity: op.entity,
      entity_id: op.entityId,
      operation: op.operation,
      data: JSON.stringify(op.payload),
      created_at: new Date(),
    });
  }
  
  res.json({ success: true });
}

// ============================================================
// 3. getServerChanges: Filter by company_id
// ============================================================
async function getServerChanges(req, res) {
  const companyId = req.companyId;  // From middleware
  const tenantId = req.user.tenant_id;
  const lastSyncTime = req.body.lastSyncTime;
  
  console.log('DEBUG getServerChanges: companyId =', companyId);
  console.log('DEBUG getServerChanges: tenantId =', tenantId);
  console.log('DEBUG getServerChanges: lastSyncTime =', lastSyncTime);
  
  // Filter by BOTH tenant_id AND company_id
  let query = db('operations_log')
    .where('tenant_id', tenantId)
    .andWhere('company_id', companyId);  // <-- ADD THIS FILTER
  
  if (lastSyncTime) {
    query = query.andWhere('created_at', '>', new Date(lastSyncTime));
  }
  
  const changes = await query.orderBy('created_at', 'asc').limit(1000);
  
  console.log('DEBUG getServerChanges: changes found =', changes.length);
  
  res.json({
    cursor: changes.length,
    server_changes: changes,
    has_more: changes.length >= 1000,
  });
}

// ============================================================
// 4. Main sync route handler
// ============================================================
app.post('/api/sync', validateCompanyAccess, async (req, res) => {
  const { operations, lastSyncTime } = req.body;
  
  // Process outgoing operations first
  if (operations && operations.length > 0) {
    await processOperations(req, res);
  }
  
  // Then get server changes (filtered by company)
  const response = await getServerChanges(req, res);
  
  res.json(response);
});